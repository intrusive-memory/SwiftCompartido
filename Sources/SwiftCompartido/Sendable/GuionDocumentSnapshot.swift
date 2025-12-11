//
//  GuionDocumentSnapshot.swift
//  SwiftCompartido
//
//  Codable snapshot type for screenplay documents (Phase 1: .guion JSON format)
//  This is the file-based representation that replaces SwiftData persistence
//

import Foundation
import os.log

/// Codable snapshot representing a complete screenplay document.
///
/// This is the root snapshot type for the .guion JSON file format. It contains
/// all screenplay content, metadata, and generated AI content in a plain Codable
/// structure suitable for JSON serialization.
///
/// ## Overview
///
/// `GuionDocumentSnapshot` is designed for the NSDocument/UIDocument architecture:
/// - **Codable**: Serializes to/from JSON .guion files
/// - **Sendable**: Safe for concurrent access across actors
/// - **NO @Model**: Plain struct, not a SwiftData model
///
/// ## Features
///
/// - **Screenplay Storage**: Complete element tree with title page metadata
/// - **JSON Serialization**: Pretty-printed, human-readable .guion files
/// - **Source File Tracking**: Track and detect changes to imported files
/// - **Voice Casting**: Character → voice mappings for audio generation
/// - **Generated Content**: AI-generated audio, text, images, embeddings
///
/// ## Example - Basic Usage
///
/// ```swift
/// var snapshot = GuionDocumentSnapshot()
/// snapshot.filename = "MyScript.guion"
/// snapshot.elements = [
///     GuionElementSnapshot(
///         elementText: "INT. COFFEE SHOP - DAY",
///         elementType: .sceneHeading
///     )
/// ]
///
/// // Serialize to JSON
/// let data = try JSONEncoder().encode(snapshot)
/// try data.write(to: url)
/// ```
///
/// ## Example - Voice Casting
///
/// ```swift
/// snapshot.casting = [
///     "JANE": CharacterVoiceMappingSnapshot(
///         voiceURI: "elevenlabs://voice-id-123",
///         voiceName: "Rachel",
///         providerID: "elevenlabs"
///     )
/// ]
/// ```
///
/// ## Topics
///
/// ### Creating Documents
/// - ``init(id:filename:title:created:modified:suppressSceneNumbers:elements:titlePage:customPages:generatedContent:casting:sourceFileBookmark:lastImportDate:sourceFileModificationDate:lastOpenedDate:)``
///
/// ### Document Properties
/// - ``id``
/// - ``filename``
/// - ``title``
/// - ``created``
/// - ``modified``
/// - ``suppressSceneNumbers``
///
/// ### Content
/// - ``elements``
/// - ``titlePage``
/// - ``customPages``
///
/// ### Voice Casting
/// - ``casting``
/// - ``characters``
/// - ``voiceMapping(for:)``
/// - ``setVoiceMapping(_:for:)``
///
/// ### Generated Content
/// - ``generatedContent``
///
/// ### Source File Tracking
/// - ``sourceFileBookmark``
/// - ``lastImportDate``
/// - ``sourceFileModificationDate``
/// - ``lastOpenedDate``
public struct GuionDocumentSnapshot: Codable, Identifiable, Sendable {

    // MARK: - Identity

    /// Unique identifier for this document
    public var id: UUID

    // MARK: - Document Metadata

    /// Filename without extension (e.g., "MyScript" for "MyScript.guion")
    public var filename: String?

    /// The title of the screenplay (from title page or filename)
    public var title: String?

    /// Date when this document was created
    public var created: Date?

    /// Date when this document was last modified
    public var modified: Date?

    /// Whether to suppress scene numbers in formatted output
    public var suppressSceneNumbers: Bool

    // MARK: - Content

    /// All screenplay elements (scene headings, action, dialogue, etc.)
    ///
    /// **Important**: Elements are sorted by (chapterIndex, orderIndex) before serialization
    /// to maintain screenplay sequence order.
    public var elements: [GuionElementSnapshot]

    /// Title page entries (Title, Author, Contact, etc.)
    public var titlePage: [TitlePageEntrySnapshot]

    /// Custom pages (Cast Lists, Production Notes, etc.)
    ///
    /// **Note**: Custom pages are stored as raw JSON data for Codable compatibility.
    /// Use `customPages` computed property for type-safe access.
    private var customPagesData: [Data]?

    /// Custom pages as typed snapshots
    ///
    /// This computed property converts raw JSON to/from `CustomPageContainer`.
    ///
    /// **Warning**: If deserialization fails for any custom page, a warning will be logged.
    /// This helps detect data corruption or incompatible formats during development.
    public var customPages: [CustomPageSnapshot]? {
        get {
            guard let data = customPagesData else { return nil }

            let logger = Logger(subsystem: "com.swiftcompartido", category: "GuionDocumentSnapshot")
            var deserializedPages: [CustomPageSnapshot] = []

            for (index, rawJSON) in data.enumerated() {
                // Attempt JSON deserialization
                guard let dict = try? JSONSerialization.jsonObject(with: rawJSON) as? [String: Any] else {
                    logger.warning("Failed to deserialize custom page at index \(index): Invalid JSON data (size: \(rawJSON.count) bytes). This page will be lost if the document is saved.")
                    continue
                }

                // Attempt CustomPageContainer initialization
                do {
                    let container = try CustomPageContainer(from: dict)
                    deserializedPages.append(container)
                } catch {
                    logger.warning("Failed to deserialize custom page at index \(index): \(error.localizedDescription). This page will be lost if the document is saved.")
                }
            }

            return deserializedPages.isEmpty ? nil : deserializedPages
        }
        set {
            if let pages = newValue {
                customPagesData = pages.map { $0.rawJSON }
            } else {
                customPagesData = nil
            }
        }
    }

    /// Generated AI content associated with this document
    ///
    /// Examples:
    /// - Document-level embeddings for semantic search
    /// - Auto-generated summaries
    /// - Generated cover images
    ///
    /// **Note**: Element-level audio is stored in `generatedContent` of each element,
    /// not at the document level.
    public var generatedContent: [UUID: TypedDataStorageSnapshot]?

    // MARK: - Voice Casting (NEW for SwiftHablare integration)

    /// Character voice mappings for audio generation
    ///
    /// Maps character names (e.g., "JANE") to voice configurations.
    /// Used by SwiftHablare to generate dialogue audio with assigned voices.
    ///
    /// ## Example
    ///
    /// ```swift
    /// snapshot.casting = [
    ///     "JANE": CharacterVoiceMappingSnapshot(
    ///         voiceURI: "macos://Samantha",
    ///         voiceName: "Samantha",
    ///         providerID: "macos"
    ///     ),
    ///     "JOHN": CharacterVoiceMappingSnapshot(
    ///         voiceURI: "elevenlabs://voice-123",
    ///         voiceName: "Adam",
    ///         providerID: "elevenlabs"
    ///     )
    /// ]
    /// ```
    public var casting: [String: CharacterVoiceMappingSnapshot]?

    // MARK: - Source File Tracking

    /// Security-scoped bookmark to the original source file
    ///
    /// This bookmark maintains access to the file across app launches, even in sandboxed applications.
    /// Created when importing a screenplay from .fountain, .fdx, etc.
    public var sourceFileBookmark: Data?

    /// Date when this document was last imported from source
    public var lastImportDate: Date?

    /// Modification date of source file at time of import
    ///
    /// Used to detect if the source file has been modified since import.
    public var sourceFileModificationDate: Date?

    /// Date when this document was last opened by the user
    ///
    /// Used to display recent items in welcome screens and "Open Recent" menus.
    public var lastOpenedDate: Date?

    // MARK: - Initialization

    /// Initialize a new screenplay document snapshot
    public init(
        id: UUID = UUID(),
        filename: String? = nil,
        title: String? = nil,
        created: Date? = nil,
        modified: Date? = nil,
        suppressSceneNumbers: Bool = false,
        elements: [GuionElementSnapshot] = [],
        titlePage: [TitlePageEntrySnapshot] = [],
        customPages: [CustomPageSnapshot]? = nil,
        generatedContent: [UUID: TypedDataStorageSnapshot]? = nil,
        casting: [String: CharacterVoiceMappingSnapshot]? = nil,
        sourceFileBookmark: Data? = nil,
        lastImportDate: Date? = nil,
        sourceFileModificationDate: Date? = nil,
        lastOpenedDate: Date? = nil
    ) {
        self.id = id
        self.filename = filename
        self.title = title
        self.created = created
        self.modified = modified
        self.suppressSceneNumbers = suppressSceneNumbers
        self.elements = elements
        self.titlePage = titlePage
        self.customPages = customPages
        self.generatedContent = generatedContent
        self.casting = casting
        self.sourceFileBookmark = sourceFileBookmark
        self.lastImportDate = lastImportDate
        self.sourceFileModificationDate = sourceFileModificationDate
        self.lastOpenedDate = lastOpenedDate
    }

    // MARK: - Voice Casting Helpers

    /// Get all unique characters for casting
    ///
    /// Extracts character names from dialogue and character elements.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let characters = snapshot.characters
    /// // ["JANE", "JOHN", "NARRATOR"]
    /// ```
    public var characters: [String] {
        elements
            .compactMap { $0.characterName }
            .uniqued()
            .sorted()
    }

    /// Get voice mapping for a character
    ///
    /// - Parameter character: Character name (e.g., "JANE")
    /// - Returns: Voice mapping if assigned, nil otherwise
    public func voiceMapping(for character: String) -> CharacterVoiceMappingSnapshot? {
        casting?[character]
    }

    /// Set voice mapping for a character
    ///
    /// - Parameters:
    ///   - mapping: Voice configuration
    ///   - character: Character name (e.g., "JANE")
    public mutating func setVoiceMapping(_ mapping: CharacterVoiceMappingSnapshot, for character: String) {
        if casting == nil {
            casting = [:]
        }
        casting?[character] = mapping
    }
}

// MARK: - Conversion from GuionParsedElementCollection

extension GuionDocumentSnapshot {
    /// Create snapshot from parsed screenplay (P1.3: Import Pipeline Integration)
    ///
    /// Converts a `GuionParsedElementCollection` (the result of parsing .fountain, .fdx, .pdf, etc.)
    /// into a `GuionDocumentSnapshot` suitable for JSON serialization.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Parse screenplay from file
    /// let screenplay = try await GuionParsedElementCollection(file: path)
    ///
    /// // Convert to snapshot
    /// let snapshot = GuionDocumentSnapshot(from: screenplay)
    ///
    /// // Serialize to .guion JSON
    /// let data = try GuionJSONSerializer.encode(snapshot)
    /// try data.write(to: guionURL)
    /// ```
    ///
    /// - Parameter screenplay: Parsed screenplay from any supported format
    /// - Returns: Document snapshot ready for JSON serialization
    public init(from screenplay: GuionParsedElementCollection) {
        // Convert elements with proper ordering
        let elements = screenplay.elements.enumerated().map { (index, element) in
            GuionElementSnapshot(from: element, orderIndex: index)
        }

        // Convert title page from [[String: [String]]] to [TitlePageEntrySnapshot]
        let titlePage = screenplay.titlePage.flatMap { dict in
            dict.map { (key, values) in
                TitlePageEntrySnapshot(key: key, values: values)
            }
        }

        // Convert custom pages (already CustomPageContainer/CustomPageSnapshot)
        let customPages = screenplay.customPages.isEmpty ? nil : screenplay.customPages

        self.init(
            id: UUID(),
            filename: screenplay.filename,
            title: nil, // Extract from titlePage if needed
            created: Date(),
            modified: Date(),
            suppressSceneNumbers: screenplay.suppressSceneNumbers,
            elements: elements,
            titlePage: titlePage,
            customPages: customPages,
            generatedContent: nil,
            casting: nil,
            sourceFileBookmark: nil,
            lastImportDate: Date(),
            sourceFileModificationDate: nil,
            lastOpenedDate: nil
        )
    }
}

// MARK: - Helpers

extension Array where Element: Hashable {
    /// Return unique elements preserving order
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
