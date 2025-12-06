//
//  QueryScreenplayElementsIntent.swift
//  SwiftCompartido
//
//  App Intent for querying elements from an existing parsed screenplay document.
//

import AppIntents
import Foundation
import SwiftData

/// Query elements from an existing screenplay document.
///
/// This intent enables Shortcuts workflows to filter and retrieve elements from
/// documents that have already been parsed and stored in SwiftData.
///
/// **Key Features**:
/// - Query by document ID (PersistentIdentifier)
/// - Optional filtering by element type, chapter, character, or search text
/// - Returns complete element data for chaining
///
/// **Example Workflow**:
/// ```
/// Query Screenplay Elements (documentID: <id>, filter: dialogue, character: "EDWARD")
/// → ScreenplayElementsReference
/// → Generate Voice (for each element)
/// ```
///
/// **Use Case**: Re-process or re-query an existing document without re-parsing the file.
@available(iOS 26.0, macOS 26.0, *)
public struct QueryScreenplayElementsIntent: AppIntent {

    public static let title: LocalizedStringResource = "Query Screenplay Elements"

    public static let description = IntentDescription(
        "Retrieve elements from an existing screenplay document with optional filtering."
    )

    public static let openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(
        title: "Document ID",
        description: "The persistent identifier of the screenplay document to query (as JSON-encoded string)"
    )
    public var documentIDString: String

    @Parameter(
        title: "Filter Element Types",
        description: "Optional: Filter to specific element types (e.g., dialogue only)"
    )
    public var elementTypes: [ElementTypeEntity]?

    @Parameter(
        title: "Filter by Chapter",
        description: "Optional: Filter to specific chapter index (0-based)"
    )
    public var chapterIndex: Int?

    @Parameter(
        title: "Filter by Character",
        description: "Optional: Filter to dialogue from a specific character"
    )
    public var characterName: String?

    @Parameter(
        title: "Search Text",
        description: "Optional: Filter to elements containing this text"
    )
    public var searchText: String?

    // MARK: - Initializer

    public init() {
        self.documentIDString = ""
    }

    public init(
        documentIDString: String,
        elementTypes: [ElementTypeEntity]? = nil,
        chapterIndex: Int? = nil,
        characterName: String? = nil,
        searchText: String? = nil
    ) {
        self.documentIDString = documentIDString
        self.elementTypes = elementTypes
        self.chapterIndex = chapterIndex
        self.characterName = characterName
        self.searchText = searchText
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<ScreenplayElementsReference> {
        // Use unified service (single code path)
        let service = ParsedFileService.shared

        // Step 1: Parse documentID from string
        // Note: We receive a String because PersistentIdentifier isn't directly Transferable
        // The string should be the JSON-encoded representation of the PersistentIdentifier
        guard let documentID = try? parsePersistentIdentifier(from: documentIDString) else {
            throw QueryError.invalidDocumentID
        }

        // Step 2: Verify document exists
        _ = try await service.document(id: documentID)

        // Step 3: Build filter from parameters
        let filter: ElementFilter? = {
            // If no filter parameters provided, return nil
            guard elementTypes != nil || chapterIndex != nil || characterName != nil || searchText != nil else {
                return nil
            }

            return ElementFilter(
                elementTypes: elementTypes?.map { $0.elementType },
                chapterIndex: chapterIndex,
                characterName: characterName,
                searchText: searchText
            )
        }()

        // Step 4: Query elements with filter
        let elements = try await service.elements(documentID: documentID, filter: filter)

        // Step 5: Get document for metadata
        let document = try await service.document(id: documentID)

        // Step 6: Create reference
        let reference = ScreenplayElementsReference(
            from: document,
            elements: elements
        )

        // Step 7: Return via IntentResult
        return .result(value: reference)
    }

    // MARK: - Helper

    /// Parse a PersistentIdentifier from its JSON-encoded string representation.
    ///
    /// PersistentIdentifier conforms to Codable, so we can decode it from JSON.
    private func parsePersistentIdentifier(from string: String) throws -> PersistentIdentifier {
        guard let data = string.data(using: .utf8) else {
            throw QueryError.invalidDocumentID
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(PersistentIdentifier.self, from: data)
        } catch {
            throw QueryError.invalidDocumentID
        }
    }
}

// MARK: - Errors

@available(iOS 26.0, macOS 26.0, *)
extension QueryScreenplayElementsIntent {
    enum QueryError: LocalizedError {
        case invalidDocumentID

        var errorDescription: String? {
            switch self {
            case .invalidDocumentID:
                return "The provided document ID is invalid or cannot be parsed."
            }
        }
    }
}
