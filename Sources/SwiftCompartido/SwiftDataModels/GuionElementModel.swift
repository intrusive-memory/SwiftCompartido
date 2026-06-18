//
//  GuionElementModel.swift
//  SwiftCompartido
//
//  SwiftData model for screenplay elements
//

import Foundation
@preconcurrency import SwiftData

/// Local, wire-compatible mirror of GlosaCore's `PausePointDTO`.
///
/// `GuionElementModel` stores compiled glosa pause data as encoded JSON in
/// ``GuionElementModel/glosaPausePoints``. To keep the persistence layer
/// decoupled from glosa-av's concrete type system, this struct mirrors the
/// field names and types of `GlosaCore.PausePointDTO` exactly, so JSON encoded
/// by either type round-trips identically.
///
/// A single timed-silence seam point inside a dialogue line. The offset is a
/// `unicodeScalars.count` index into the line's spoken text (semantics
/// identical to ``GuionElementModel/glosaBreathOffsets``).
public struct PausePointDTO: Codable, Sendable, Equatable {
  /// Unicode-scalar boundary offset in the spoken text where the silence is placed.
  public let offset: Int

  /// Target audible silence in milliseconds.
  public let lengthMs: Int

  /// Wire-format name token for named presets; `nil` for explicit durations.
  ///
  /// One of: `"comma"`, `"semicolon"`, `"period"`, `"em-dash"`, `"beat"`, or `nil`.
  public let named: String?

  public init(offset: Int, lengthMs: Int, named: String?) {
    self.offset = offset
    self.lengthMs = lengthMs
    self.named = named
  }
}

/// SwiftData model representing a single screenplay element.
///
/// This persistent model stores screenplay elements with automatic scene location
/// caching for improved performance and explicit ordering support.
///
/// ## Overview
///
/// `GuionElementModel` extends ``GuionElementProtocol`` with SwiftData persistence
/// and intelligent location caching. When a scene heading is created or modified,
/// the location is automatically parsed and cached for quick access.
///
/// ## Ordering
///
/// Elements use `orderIndex` to maintain screenplay sequence. This field ensures
/// elements always appear in their original order, with special support for
/// chapter-based spacing (Chapter 1 starts at 100, Chapter 2 at 200, etc.).
///
/// ## Example
///
/// ```swift
/// let element = GuionElementModel(
///     elementText: "INT. COFFEE SHOP - DAY",
///     elementType: .sceneHeading,
///     orderIndex: 150  // In Chapter 2
/// )
///
/// // Location is automatically parsed and cached
/// if let location = element.cachedSceneLocation {
///     print(location.scene) // "COFFEE SHOP"
///     print(location.lighting) // .interior
/// }
/// ```
///
/// ## Topics
///
/// ### Creating Elements
/// - ``init(elementText:elementType:isCentered:isDualDialogue:sceneNumber:sectionDepth:summary:sceneId:orderIndex:)``
/// - ``init(from:summary:orderIndex:)``
///
/// ### Element Properties
/// - ``elementText``
/// - ``elementType``
/// - ``isCentered``
/// - ``isDualDialogue``
/// - ``sceneNumber``
/// - ``sectionDepth``
/// - ``sceneId``
/// - ``summary``
/// - ``orderIndex``
///
/// ### Location Caching
/// - ``cachedSceneLocation``
/// - ``reparseLocation()``
///
/// ### Updating Elements
/// - ``updateText(_:)``
/// - ``updateType(_:)``
@Model
public final class GuionElementModel: GuionElementProtocol {
  /// Stable UUID for this element
  ///
  /// This UUID is used for reliable element identification across app intents,
  /// shortcuts, and other external integrations. Unlike SwiftData's PersistentIdentifier,
  /// this UUID has a stable string representation that can be safely serialized.
  ///
  /// **Use Cases**:
  /// - App Intents: Pass element UUID as parameter
  /// - Shortcuts: Reference specific elements
  /// - External APIs: Stable element identification
  ///
  /// **Important**: Use `uuid.uuidString` for string comparisons, never PersistentIdentifier
  ///
  /// ## Example
  ///
  /// ```swift
  /// // CORRECT - Use stable UUID
  /// let foundElement = document.elements.first { $0.uuid.uuidString == elementID }
  ///
  /// // WRONG - Don't use PersistentIdentifier string representation
  /// let badElement = document.elements.first { String(describing: $0.id).contains(elementID) }
  /// ```
  @Attribute(.unique) public var uuid: UUID

  /// Chapter index for multi-chapter screenplays
  ///
  /// - 0: Elements before the first chapter (title page, opening scenes)
  /// - 1: Elements in Chapter 1
  /// - 2: Elements in Chapter 2
  /// - etc.
  ///
  /// Chapters are detected via section heading level 2. If no chapters are used,
  /// all elements have chapterIndex = 0.
  ///
  /// **Critical**: Always sort by (chapterIndex, orderIndex) to maintain screenplay sequence:
  /// ```swift
  /// @Query(sort: [
  ///     SortDescriptor(\GuionElementModel.chapterIndex),
  ///     SortDescriptor(\GuionElementModel.orderIndex)
  /// ]) var elements: [GuionElementModel]
  /// ```
  public var chapterIndex: Int

  /// Order index within the current chapter
  ///
  /// Sequential position starting from 1 within each chapter. Combined with `chapterIndex`,
  /// this provides the complete ordering key for screenplay elements.
  ///
  /// - Chapter heading: receives orderIndex 1
  /// - First element after heading: orderIndex 2
  /// - Second element: orderIndex 3
  /// - etc.
  ///
  /// Elements are always sorted by (chapterIndex, orderIndex) to maintain screenplay sequence.
  public var orderIndex: Int

  public var elementText: String

  /// Internal storage for element type as string (required for SwiftData)
  private var _elementTypeString: String

  /// The type of screenplay element
  public var elementType: ElementType {
    get {
      // Convert from stored string to enum
      var type = ElementType(string: _elementTypeString)
      // If section heading, use stored depth
      if case .sectionHeading = type {
        type = .sectionHeading(level: _sectionDepth)
      }
      return type
    }
    set {
      // Track previous type for location handling
      let wasSceneHeading = elementType == .sceneHeading
      let isSceneHeading = newValue == .sceneHeading

      // Store enum as string
      _elementTypeString = newValue.description
      // Update section depth if applicable
      if case .sectionHeading(let level) = newValue {
        _sectionDepth = level
      }

      // Update location data if scene heading status changed
      if isSceneHeading && !wasSceneHeading {
        // Became a scene heading - parse location
        parseAndStoreLocation()
      } else if !isSceneHeading && wasSceneHeading {
        // Was a scene heading, no longer is - clear location
        parseAndStoreLocation()
      }
    }
  }

  public var isCentered: Bool
  public var isDualDialogue: Bool
  public var sceneNumber: String?

  /// Internal storage for section depth (required for SwiftData persistence)
  private var _sectionDepth: Int

  /// The depth level for section headings (deprecated, use elementType.level instead)
  @available(*, deprecated, message: "Use elementType.level instead")
  public var sectionDepth: Int {
    get { elementType.level }
    set {
      if case .sectionHeading = elementType {
        _sectionDepth = newValue
        // Need to update the element type to reflect new level
        elementType = .sectionHeading(level: newValue)
      }
    }
  }

  public var sceneId: String?

  // SwiftData-specific properties
  public var summary: String?

  /// Reference to the parent document
  ///
  /// **Delete Rule**: `.nullify` - When an element is deleted, the parent document
  /// is not affected (only documents delete their elements, not vice versa).
  @Relationship(deleteRule: .nullify)
  public var document: GuionDocumentModel?

  /// Generated AI content associated with this element
  ///
  /// Examples:
  /// - Generated audio for dialogue (text-to-speech)
  /// - Generated images for scene descriptions
  /// - Generated embeddings for semantic search
  ///
  /// **Delete Rule**: `.cascade` - When the element is deleted,
  /// all associated generated content is automatically deleted.
  @Relationship(deleteRule: .cascade)
  public var generatedContent: [TypedDataStorage]?

  /// Custom outline elements attached to this screenplay element
  ///
  /// Custom elements allow users to attach media (audio, images, video, documents)
  /// to scenes/sections for reference, production notes, or creative purposes.
  ///
  /// Examples:
  /// - Music cues for soundtrack planning
  /// - Sound effects for audio design reference
  /// - Production notes with attached reference materials
  /// - Generic media containers for flexible use
  ///
  /// **Delete Rule**: `.cascade` - When the element is deleted,
  /// all attached custom elements are automatically deleted.
  ///
  /// **Inverse Relationship**: `CustomOutlineElement.parentElement`
  @Relationship(deleteRule: .cascade)
  public var customElements: [CustomOutlineElement]?

  // Cached parsed location data
  public var locationLighting: String?  // Raw value of SceneLighting enum
  public var locationScene: String?  // Primary location name
  public var locationSetup: String?  // Optional sub-location
  public var locationTimeOfDay: String?  // Time of day
  public var locationModifiers: [String]?  // Additional modifiers

  // MARK: - Performance Optimization (NEW in 5.4.0)

  /// Pre-computed formatted text with Fountain formatting applied
  ///
  /// This property stores the AttributedString with bold, italic, and underline
  /// formatting already applied. When set during parsing, it eliminates the need
  /// for runtime text formatting, improving rendering performance by 3-5x.
  ///
  /// **Performance Impact**:
  /// - Without pre-formatting: 3 regex passes per render
  /// - With pre-formatting: Zero formatting overhead
  ///
  /// **Migration**:
  /// - Existing elements without `formattedText` will fall back to runtime formatting
  /// - New elements automatically populate this during parsing
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Formatted text is set during parsing
  /// let element = GuionElementModel(
  ///     elementText: "This has **bold** and *italic* text",
  ///     elementType: .action
  /// )
  /// element.formattedText = FountainTextFormatter.format(element.elementText)
  ///
  /// // Views use pre-computed formatting
  /// Text(element.formattedText ?? AttributedString(element.elementText))
  /// ```
  ///
  /// - SeeAlso: ``FountainTextFormatter``
  /// - Since: 5.4.0
  ///
  /// ## Storage Implementation
  ///
  /// Stored as binary Data using AttributedString's built-in encoding.
  /// This avoids the __SwiftValue serialization issue with NSSecureUnarchiveFromDataTransformer.
  private var formattedTextData: Data?

  /// Computed property for accessing the formatted text
  public var formattedText: AttributedString? {
    get {
      guard let data = formattedTextData else { return nil }
      let decoder = PropertyListDecoder()
      return try? decoder.decode(AttributedString.self, from: data)
    }
    set {
      guard let value = newValue else {
        formattedTextData = nil
        return
      }
      let encoder = PropertyListEncoder()
      formattedTextData = try? encoder.encode(value)
    }
  }

  // MARK: - Glosa Annotation Storage (NEW in 7.0.5)

  /// Notes-stripped spoken prose for this element.
  ///
  /// When glosa annotation has run, this holds the dialogue text with every
  /// inline `[[<breath …/>]]` / `[[<pause …/>]]` note removed — the prose an
  /// actor or TTS pipeline actually speaks. ``elementText`` is preserved raw
  /// (markers intact) for lossless export; consumers fall back to it when this
  /// is `nil`.
  ///
  /// Offsets in ``glosaBreathOffsets`` and the encoded ``glosaPausePoints``
  /// index into this string's `unicodeScalars`.
  public var glosaSpokenText: String? = nil

  /// Unicode-scalar boundary offsets in ``glosaSpokenText`` where the chunker
  /// should consider inserting a phrasing seam (breath hint).
  ///
  /// Sorted ascending. `nil` when glosa has not run; empty when no `<breath/>`
  /// markers were present.
  public var glosaBreathOffsets: [Int]? = nil

  /// Raw `BreathStrength` values parallel to ``glosaBreathOffsets``.
  ///
  /// `glosaBreathStrengths[i]` is the `.rawValue` of the breath at
  /// `glosaBreathOffsets[i]`: one of `"weak"`, `"medium"`, or `"strong"`.
  /// Same count as ``glosaBreathOffsets``.
  public var glosaBreathStrengths: [String]? = nil

  /// Composed LLM performance-direction string for this line, if any.
  ///
  /// `nil` when no active GLOSA directive covered this line.
  public var glosaInstruct: String? = nil

  /// Encoded `[PausePointDTO]` timed-silence seam points for this line.
  ///
  /// Stored as JSON-encoded `Data` of ``PausePointDTO`` values. `nil` when
  /// glosa has not run or no `<pause/>` markers were present.
  public var glosaPausePoints: Data? = nil

  public init(
    elementText: String, elementType: ElementType, isCentered: Bool = false,
    isDualDialogue: Bool = false, sceneNumber: String? = nil, sectionDepth: Int = 0,
    summary: String? = nil, sceneId: String? = nil, chapterIndex: Int = 0, orderIndex: Int = 0,
    uuid: UUID = UUID()
  ) {
    self.uuid = uuid
    self.chapterIndex = chapterIndex
    self.orderIndex = orderIndex
    self.elementText = elementText
    self._elementTypeString = elementType.description
    self.isCentered = isCentered
    self.isDualDialogue = isDualDialogue
    self.sceneNumber = sceneNumber
    // Set section depth from enum if provided
    self._sectionDepth = elementType.level > 0 ? elementType.level : sectionDepth
    self.summary = summary
    self.sceneId = sceneId

    // Parse location if this is a scene heading
    if elementType == .sceneHeading {
      self.parseAndStoreLocation()
    }
  }

  /// Initialize from any GuionElementProtocol conforming type
  public convenience init<T: GuionElementProtocol>(
    from element: T, summary: String? = nil, chapterIndex: Int = 0, orderIndex: Int = 0
  ) {
    self.init(
      elementText: element.elementText,
      elementType: element.elementType,
      isCentered: element.isCentered,
      isDualDialogue: element.isDualDialogue,
      sceneNumber: element.sceneNumber,
      sectionDepth: element.elementType.level,
      summary: summary,
      sceneId: element.sceneId,
      chapterIndex: chapterIndex,
      orderIndex: orderIndex
    )
  }

  /// Parse and store location data from elementText
  private func parseAndStoreLocation() {
    guard elementType == .sceneHeading else {
      // Clear location data if not a scene heading
      locationLighting = nil
      locationScene = nil
      locationSetup = nil
      locationTimeOfDay = nil
      locationModifiers = nil
      return
    }

    let location = SceneLocation.parse(elementText)

    // Store parsed components
    locationLighting = location.lighting.rawValue
    locationScene = location.scene
    locationSetup = location.setup
    locationTimeOfDay = location.timeOfDay
    locationModifiers = location.modifiers.isEmpty ? nil : location.modifiers
  }

  /// Get the cached scene location (reconstructed from stored properties)
  /// Returns nil if this is not a scene heading or location hasn't been parsed
  public var cachedSceneLocation: SceneLocation? {
    guard elementType == .sceneHeading,
      let lightingRaw = locationLighting,
      let scene = locationScene
    else {
      return nil
    }

    let lighting = SceneLighting(rawValue: lightingRaw) ?? .unknown

    return SceneLocation(
      lighting: lighting,
      scene: scene,
      setup: locationSetup,
      timeOfDay: locationTimeOfDay,
      modifiers: locationModifiers ?? [],
      originalText: elementText
    )
  }

  /// Force reparse the location (useful for migration or manual updates)
  public func reparseLocation() {
    parseAndStoreLocation()
  }

  /// Update element text and automatically reparse location if needed
  public func updateText(_ newText: String) {
    guard newText != elementText else { return }
    elementText = newText
    if elementType == .sceneHeading {
      parseAndStoreLocation()
    }
  }

  /// Update element type and automatically reparse location if needed
  public func updateType(_ newType: ElementType) {
    guard newType != elementType else { return }
    let wasSceneHeading = elementType == .sceneHeading
    let isSceneHeading = newType == .sceneHeading

    elementType = newType

    if isSceneHeading && !wasSceneHeading {
      // Became a scene heading - parse location
      parseAndStoreLocation()
    } else if !isSceneHeading && wasSceneHeading {
      // Was a scene heading, no longer is - clear location
      parseAndStoreLocation()
    }
  }
}

// MARK: - SpeakableElement Conformance

@available(iOS 26.0, macOS 26.0, *)
extension GuionElementModel: SpeakableElement {
  /// The spoken prose for this element, with inline glosa notes stripped.
  ///
  /// Falls back to raw `elementText` when glosa annotation has not run.
  public var spokenText: String {
    glosaSpokenText ?? elementText
  }

  /// Unicode-scalar boundary offsets in `spokenText` where breath hints are located.
  ///
  /// Returns empty array when glosa annotation has not run or no breath markers were present.
  public var breathOffsets: [Int] {
    glosaBreathOffsets ?? []
  }

  /// Composed LLM performance-direction string for this line, if any.
  ///
  /// Returns `nil` when no active GLOSA directive covered this line.
  public var instruct: String? {
    glosaInstruct
  }

  /// Breath/pause offsets for display overlay rendering.
  ///
  /// Exposes the same data as `breathOffsets` for UI components that need to
  /// visualize breath points or pause markers in screenplay views.
  public var displayBreathOffsets: [Int] {
    breathOffsets
  }
}
