//
//  ScreenplayElementsReference.swift
//  SwiftCompartido
//
//  Transferable reference struct for screenplay elements (App Intents integration).
//

import Foundation
import SwiftData
import CoreTransferable
import AppIntents

/// A transferable reference to screenplay elements for use in App Intents and Shortcuts.
///
/// This struct serves as a bridge between SwiftData models (non-Sendable) and App Intents
/// (requires Sendable, Codable, Transferable). It contains complete element data to enable
/// single-shot workflows in Shortcuts without requiring multiple intent calls.
///
/// **Use Case**: Voice generation workflow
/// ```
/// Parse File (filter: dialogue) → ScreenplayElementsReference
/// Generate Voice (input: reference) → Audio files
/// ```
///
/// **Key Design**:
/// - Contains element data (not just IDs) for direct chaining
/// - Codable for cross-process serialization
/// - Sendable for safe concurrent access
/// - Transferable for Shortcuts integration
///
/// Example:
/// ```swift
/// let reference = ScreenplayElementsReference(
///     documentID: documentID,
///     documentTitle: "My Script",
///     elements: elementRefs
/// )
///
/// // Use in voice generation
/// for element in reference.elements where element.isDialogue {
///     generateVoice(for: element.elementText, character: element.characterName)
/// }
/// ```
@available(iOS 26.0, macOS 26.0, *)
public struct ScreenplayElementsReference: Codable, Sendable, Hashable, Transferable, Identifiable {

    // MARK: - Document Metadata

    /// Unique identifier for AppEntity conformance (using documentID's string representation).
    public var id: String { String(describing: documentID) }

    /// The persistent identifier of the source document.
    public let documentID: PersistentIdentifier

    /// The title of the screenplay document.
    public let documentTitle: String?

    /// The filename of the source document.
    public let documentFilename: String?

    // MARK: - Element Data

    /// Array of element references for downstream processing.
    public let elements: [ElementReference]

    // MARK: - Computed Properties

    /// Total number of elements in this reference.
    public var elementCount: Int {
        elements.count
    }

    /// Unique character names (sorted alphabetically).
    ///
    /// Useful for voice assignment workflows - get all characters in the screenplay
    /// to assign voices before batch generation.
    public var characterNames: [String] {
        Set(elements.compactMap { $0.characterName }).sorted()
    }

    /// Count of dialogue elements.
    public var dialogueCount: Int {
        elements.filter { $0.isDialogue }.count
    }

    /// Count of scene heading elements.
    public var sceneCount: Int {
        elements.filter { $0.isSceneHeading }.count
    }

    // MARK: - Initializer

    /// Creates a new screenplay elements reference.
    ///
    /// - Parameters:
    ///   - documentID: The persistent identifier of the source document
    ///   - documentTitle: The title of the screenplay
    ///   - documentFilename: The filename of the source file
    ///   - elements: Array of element references
    public init(
        documentID: PersistentIdentifier,
        documentTitle: String?,
        documentFilename: String?,
        elements: [ElementReference]
    ) {
        self.documentID = documentID
        self.documentTitle = documentTitle
        self.documentFilename = documentFilename
        self.elements = elements
    }

    // MARK: - Query Methods

    /// Count dialogue lines for a specific character (case-insensitive).
    ///
    /// - Parameter character: The character name to count
    /// - Returns: Number of dialogue elements for that character
    public func dialogueCount(for character: String) -> Int {
        elements.filter {
            $0.characterName?.uppercased() == character.uppercased() && $0.isDialogue
        }.count
    }

    /// Filter elements by type.
    ///
    /// - Parameter types: Element types to filter by
    /// - Returns: Array of elements matching the types
    public func elements(ofTypes types: [ElementType]) -> [ElementReference] {
        elements.filter { types.contains($0.elementType) }
    }

    /// Filter elements by chapter.
    ///
    /// - Parameter chapterIndex: The chapter index (0-based)
    /// - Returns: Array of elements in that chapter
    public func elements(inChapter chapterIndex: Int) -> [ElementReference] {
        elements.filter { $0.chapterIndex == chapterIndex }
    }

    // MARK: - Transferable Conformance

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

// MARK: - AppEntity Conformance

@available(iOS 26.0, macOS 26.0, *)
extension ScreenplayElementsReference: AppEntity {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Screenplay Elements")
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(documentTitle ?? "Untitled Screenplay")",
            subtitle: "\(elementCount) elements"
        )
    }

    public static var defaultQuery: ScreenplayElementsReferenceQuery {
        ScreenplayElementsReferenceQuery()
    }
}

/// Query for ScreenplayElementsReference entities.
///
/// Note: This query doesn't support lookup by ID since these references are
/// transient values returned from intents, not queryable persistent entities.
@available(iOS 26.0, macOS 26.0, *)
public struct ScreenplayElementsReferenceQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [ScreenplayElementsReference] {
        // Not supported - these are transient intent results, not queryable entities
        return []
    }

    public func suggestedEntities() async throws -> [ScreenplayElementsReference] {
        // Not supported - these are transient intent results
        return []
    }
}

// MARK: - Helper Extensions
// NOTE: PersistentIdentifier cannot be easily serialized to/from JSON because it uses
// NSSecureCoding internally. In Shortcuts workflows, the documentID will be passed
// directly from one intent to another via the Shortcuts runtime, not via manual encoding.

/// A lightweight reference to a single screenplay element.
///
/// Contains essential data for downstream processing without holding SwiftData model references.
/// Designed to be serializable across process boundaries for Shortcuts integration.
@available(iOS 26.0, macOS 26.0, *)
public struct ElementReference: Codable, Sendable, Hashable, Identifiable {

    // MARK: - Identification

    /// The persistent identifier of the source element.
    public let id: PersistentIdentifier

    // MARK: - Element Data

    /// The type of this element (dialogue, action, scene heading, etc.).
    public let elementType: ElementType

    /// The text content of this element.
    public let elementText: String

    /// The chapter index (0-based) containing this element.
    public let chapterIndex: Int

    /// The order index within the chapter (0-based).
    public let orderIndex: Int

    /// The character name for dialogue elements (nil for non-dialogue).
    public let characterName: String?

    // MARK: - Computed Properties

    /// Returns true if this element is a dialogue type.
    public var isDialogue: Bool {
        elementType == .dialogue
    }

    /// Returns true if this element is a scene heading.
    public var isSceneHeading: Bool {
        elementType == .sceneHeading
    }

    /// Returns true if this element is action.
    public var isAction: Bool {
        elementType == .action
    }

    /// Returns true if this element is a character name.
    public var isCharacter: Bool {
        elementType == .character
    }

    // MARK: - Initializer

    /// Creates a new element reference.
    ///
    /// - Parameters:
    ///   - id: The persistent identifier of the source element
    ///   - elementType: The type of this element
    ///   - elementText: The text content
    ///   - chapterIndex: The chapter index (0-based)
    ///   - orderIndex: The order index within the chapter
    ///   - characterName: The character name for dialogue elements
    public init(
        id: PersistentIdentifier,
        elementType: ElementType,
        elementText: String,
        chapterIndex: Int,
        orderIndex: Int,
        characterName: String?
    ) {
        self.id = id
        self.elementType = elementType
        self.elementText = elementText
        self.chapterIndex = chapterIndex
        self.orderIndex = orderIndex
        self.characterName = characterName
    }
}

// MARK: - GuionElementModel Extensions

@available(iOS 26.0, macOS 26.0, *)
extension ElementReference {
    /// Creates an ElementReference from a GuionElementModel.
    ///
    /// - Parameter element: The source element model
    /// - Returns: A new ElementReference
    public init(from element: GuionElementModel) {
        self.init(
            id: element.persistentModelID,
            elementType: element.elementType,
            elementText: element.elementText,
            chapterIndex: element.chapterIndex,
            orderIndex: element.orderIndex,
            characterName: nil // TODO: Extract from preceding CHARACTER element
        )
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension ScreenplayElementsReference {
    /// Creates a ScreenplayElementsReference from a GuionDocumentModel and its elements.
    ///
    /// - Parameters:
    ///   - document: The source document model
    ///   - elements: The elements to include (defaults to all sorted elements)
    /// - Returns: A new ScreenplayElementsReference
    public init(from document: GuionDocumentModel, elements: [GuionElementModel]? = nil) {
        let sourceElements = elements ?? document.sortedElements

        self.init(
            documentID: document.persistentModelID,
            documentTitle: document.title,
            documentFilename: document.filename,
            elements: sourceElements.map { ElementReference(from: $0) }
        )
    }
}
