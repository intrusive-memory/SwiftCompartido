//
//  GuionElementSnapshot.swift
//  SwiftCompartido
//
//  Codable snapshot type for screenplay elements (Phase 1: .guion JSON format)
//

import Foundation

/// Codable snapshot representing a single screenplay element.
///
/// This is the element-level snapshot type for the .guion JSON file format.
/// It represents individual screenplay elements like scene headings, action,
/// dialogue, transitions, etc.
///
/// ## Overview
///
/// `GuionElementSnapshot` is designed for JSON serialization:
/// - **Codable**: Serializes to/from JSON
/// - **Sendable**: Safe for concurrent access across actors
/// - **NO @Model**: Plain struct, not a SwiftData model
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
/// let element = GuionElementSnapshot(
///     id: UUID(),
///     elementText: "INT. COFFEE SHOP - DAY",
///     elementType: .sceneHeading,
///     chapterIndex: 0,
///     orderIndex: 1
/// )
/// ```
///
/// ## Topics
///
/// ### Creating Elements
/// - ``init(id:chapterIndex:orderIndex:elementText:elementType:isCentered:isDualDialogue:sceneNumber:sectionDepth:sceneId:summary:cachedSceneLocation:generatedContent:)``
///
/// ### Element Properties
/// - ``id``
/// - ``elementText``
/// - ``elementType``
/// - ``chapterIndex``
/// - ``orderIndex``
/// - ``isCentered``
/// - ``isDualDialogue``
/// - ``sceneNumber``
/// - ``sectionDepth``
/// - ``sceneId``
/// - ``summary``
///
/// ### Voice Generation
/// - ``characterName``
/// - ``speakableText``
///
/// ### Generated Content
/// - ``generatedContent``
public struct GuionElementSnapshot: Codable, Identifiable, Sendable {

    // MARK: - Identity

    /// Stable UUID for this element
    ///
    /// This UUID is used for reliable element identification across app intents,
    /// shortcuts, and other external integrations.
    public var id: UUID

    // MARK: - Ordering

    /// Chapter index for multi-chapter screenplays
    ///
    /// - 0: Elements before the first chapter (title page, opening scenes)
    /// - 1: Elements in Chapter 1
    /// - 2: Elements in Chapter 2
    /// - etc.
    public var chapterIndex: Int

    /// Order index within the current chapter
    ///
    /// Sequential position starting from 1 within each chapter. Combined with `chapterIndex`,
    /// this provides the complete ordering key for screenplay elements.
    public var orderIndex: Int

    // MARK: - Element Properties

    /// The text content of this element
    public var elementText: String

    /// The type of screenplay element
    ///
    /// Stored as ElementType enum which encodes to JSON as a string.
    public var elementType: ElementType

    /// Whether this element is centered (used for transitions, lyrics, etc.)
    public var isCentered: Bool

    /// Whether this dialogue is in dual-dialogue format
    public var isDualDialogue: Bool

    /// Scene number (e.g., "1", "2A", "3")
    public var sceneNumber: String?

    /// Section depth for section headings (1-6)
    ///
    /// **Deprecated**: Use `elementType.level` instead
    @available(*, deprecated, message: "Use elementType.level instead")
    public var sectionDepth: Int

    /// Scene identifier for tracking scenes across revisions
    public var sceneId: String?

    /// Optional summary or notes for this element
    public var summary: String?

    // MARK: - Location Caching

    /// Cached scene location
    ///
    /// For scene headings, this stores the parsed location information
    /// (scene, lighting, time of day) to avoid re-parsing.
    ///
    /// **Note**: SceneLocation is Codable, so it serializes directly to JSON.
    public var cachedSceneLocation: SceneLocation?

    // MARK: - Generated Content

    /// Generated AI content associated with this element
    ///
    /// Examples:
    /// - Dialogue audio (generated from character speech)
    /// - Action scene summaries
    /// - Character emotion analysis
    ///
    /// Keyed by content UUID for efficient lookup.
    public var generatedContent: [UUID: TypedDataStorageSnapshot]?

    // MARK: - Initialization

    /// Initialize a new screenplay element snapshot
    public init(
        id: UUID = UUID(),
        chapterIndex: Int = 0,
        orderIndex: Int = 0,
        elementText: String,
        elementType: ElementType,
        isCentered: Bool = false,
        isDualDialogue: Bool = false,
        sceneNumber: String? = nil,
        sectionDepth: Int = 0,
        sceneId: String? = nil,
        summary: String? = nil,
        cachedSceneLocation: SceneLocation? = nil,
        generatedContent: [UUID: TypedDataStorageSnapshot]? = nil
    ) {
        self.id = id
        self.chapterIndex = chapterIndex
        self.orderIndex = orderIndex
        self.elementText = elementText
        self.elementType = elementType
        self.isCentered = isCentered
        self.isDualDialogue = isDualDialogue
        self.sceneNumber = sceneNumber
        self.sectionDepth = sectionDepth
        self.sceneId = sceneId
        self.summary = summary
        self.cachedSceneLocation = cachedSceneLocation
        self.generatedContent = generatedContent
    }

    // MARK: - Voice Generation Helpers (for SwiftHablare integration)

    /// Extract speakable text (filters out {{stage directions}})
    ///
    /// Removes stage directions enclosed in double curly braces, which should
    /// not be spoken in audio generation.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let element = GuionElementSnapshot(
    ///     elementText: "Hello {{whispers}} world",
    ///     elementType: .dialogue
    /// )
    /// print(element.speakableText) // "Hello  world"
    /// ```
    public var speakableText: String {
        // Remove {{stage directions}} from text
        var text = elementText
        while let startRange = text.range(of: "{{"),
              let endRange = text.range(of: "}}", range: startRange.upperBound..<text.endIndex) {
            text.removeSubrange(startRange.lowerBound..<endRange.upperBound)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get character name for voice assignment (if dialogue/lyrics)
    ///
    /// Extracts the character name from character elements or returns nil
    /// for non-character elements.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let character = GuionElementSnapshot(elementText: "JANE", elementType: .character)
    /// print(character.characterName) // "JANE"
    ///
    /// let dialogue = GuionElementSnapshot(elementText: "Hello", elementType: .dialogue)
    /// print(dialogue.characterName) // nil (dialogue doesn't have character name)
    /// ```
    public var characterName: String? {
        guard elementType == .character else {
            return nil
        }
        return elementText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}

// MARK: - Conversion from GuionElement (DTO)

extension GuionElementSnapshot {
    /// Create snapshot from a GuionElement (parsing result)
    ///
    /// Converts from the parsing DTO (`GuionElement`) to a snapshot suitable
    /// for JSON serialization.
    ///
    /// - Parameters:
    ///   - element: Parsed element from GuionParsedElementCollection
    ///   - orderIndex: Order index within chapter
    /// - Returns: Snapshot ready for JSON serialization
    public init(from element: GuionElement, orderIndex: Int) {
        self.id = UUID()
        self.chapterIndex = 0 // Set by parser based on section headings
        self.orderIndex = orderIndex
        self.elementText = element.elementText
        self.elementType = element.elementType
        self.isCentered = element.isCentered
        self.isDualDialogue = element.isDualDialogue
        self.sceneNumber = element.sceneNumber
        self.sectionDepth = element.elementType.level
        self.sceneId = element.sceneId
        self.summary = nil
        self.cachedSceneLocation = nil
        self.generatedContent = nil
    }
}
