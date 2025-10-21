//
//  GuionElementModel.swift
//  SwiftCompartido
//
//  SwiftData model for screenplay elements
//

import Foundation
import SwiftData

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
    public var document: GuionDocumentModel?

    // Cached parsed location data
    public var locationLighting: String?      // Raw value of SceneLighting enum
    public var locationScene: String?         // Primary location name
    public var locationSetup: String?         // Optional sub-location
    public var locationTimeOfDay: String?     // Time of day
    public var locationModifiers: [String]?   // Additional modifiers

    public init(elementText: String, elementType: ElementType, isCentered: Bool = false, isDualDialogue: Bool = false, sceneNumber: String? = nil, sectionDepth: Int = 0, summary: String? = nil, sceneId: String? = nil, chapterIndex: Int = 0, orderIndex: Int = 0) {
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
    public convenience init<T: GuionElementProtocol>(from element: T, summary: String? = nil, chapterIndex: Int = 0, orderIndex: Int = 0) {
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
              let scene = locationScene else {
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
