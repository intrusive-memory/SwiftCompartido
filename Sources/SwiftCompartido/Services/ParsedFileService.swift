//
//  ParsedFileService.swift
//  SwiftCompartido
//
//  Unified API for parsing and querying screenplays (used by both UI and App Intents).
//

import Foundation
@preconcurrency import SwiftData

/// Unified service for parsing screenplay files and querying elements.
///
/// This class provides @MainActor-isolated access to screenplay parsing and database operations.
/// It serves as the single source of truth for both UI code and App Intents.
///
/// All methods run on the main actor to align with SwiftData's isolation requirements.
/// SwiftData models (`GuionDocumentModel`, `GuionElementModel`) are not Sendable and must
/// remain on a single isolation domain.
///
/// **Architecture**: Thin wrapper around existing SwiftCompartido APIs
/// - Delegates to `GuionParsedElementCollection` for parsing (automatic format detection)
/// - Delegates to `GuionDocumentModel.from()` for SwiftData conversion
/// - Uses `document.sortedElements` for ordered element access
///
/// Example:
/// ```swift
/// let container = try ModelContainer(for: GuionDocumentModel.self)
/// let service = ParsedFileService(modelContainer: container)
///
/// // Parse file
/// let documentID = try await service.parseFile(at: fileURL)
///
/// // Query elements
/// let filter = ElementFilter(elementTypes: [.dialogue])
/// let elements = try await service.elements(documentID: documentID, filter: filter)
/// ```
@available(iOS 26.0, macOS 26.0, *)
@MainActor
public final class ParsedFileService {

    /// The ModelContainer for SwiftData persistence.
    private let modelContainer: ModelContainer

    /// Creates a new ParsedFileService with the specified ModelContainer.
    ///
    /// - Parameter modelContainer: The SwiftData container for persisting documents
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Parses a screenplay file and inserts it into the database.
    ///
    /// This method uses the existing `GuionParsedElementCollection` API for parsing
    /// (which automatically detects file format) and `GuionDocumentModel.from()` for
    /// SwiftData conversion.
    ///
    /// - Parameters:
    ///   - url: The URL of the screenplay file to parse
    ///   - progress: Optional progress tracker for monitoring parsing progress
    /// - Returns: The persistent identifier of the created document
    /// - Throws: `ParsedFileServiceError` if parsing fails or file is invalid
    public func parseFile(
        at url: URL,
        progress: OperationProgress? = nil
    ) async throws -> PersistentIdentifier {
        let modelContext = ModelContext(modelContainer)

        // Step 1: Use existing parser (automatic format detection)
        let screenplay: GuionParsedElementCollection
        do {
            screenplay = try await GuionParsedElementCollection(file: url.path, progress: progress)
        } catch {
            throw ParsedFileServiceError.parsingFailed(url: url, underlyingError: error)
        }

        // Step 2: Use existing SwiftData conversion (main actor isolated)
        let document = await GuionDocumentModel.from(
            screenplay,
            in: modelContext,
            generateSummaries: false,
            progress: progress
        )

        modelContext.insert(document)

        do {
            try modelContext.save()
        } catch {
            throw ParsedFileServiceError.databaseSaveFailed(underlyingError: error)
        }

        return document.persistentModelID
    }

    /// Retrieves a document by its persistent identifier.
    ///
    /// - Parameter id: The persistent identifier of the document
    /// - Returns: The document model
    /// - Throws: `ParsedFileServiceError.documentNotFound` if document doesn't exist
    public func document(id: PersistentIdentifier) async throws -> GuionDocumentModel {
        let modelContext = ModelContext(modelContainer)

        guard let document = modelContext.model(for: id) as? GuionDocumentModel else {
            throw ParsedFileServiceError.documentNotFound(id: id)
        }

        return document
    }

    /// Queries elements from a document with optional filtering.
    ///
    /// This method uses the existing `sortedElements` property for correct ordering
    /// and applies filters using the `ElementFilter.matches()` method.
    ///
    /// - Parameters:
    ///   - documentID: The persistent identifier of the document
    ///   - filter: Optional filter criteria
    /// - Returns: Array of elements matching the filter (or all elements if no filter)
    /// - Throws: `ParsedFileServiceError.documentNotFound` if document doesn't exist
    public func elements(
        documentID: PersistentIdentifier,
        filter: ElementFilter? = nil
    ) async throws -> [GuionElementModel] {
        let document = try await self.document(id: documentID)

        // Use existing sortedElements property (composite key ordering)
        let elements = document.sortedElements

        // Apply filter if provided
        if let filter = filter, !filter.isEmpty {
            // Use filter(elements:) instead of matches() to support character name filtering
            return filter.filter(elements: elements)
        }

        return elements
    }

    /// Shared instance for production use with default model container.
    ///
    /// This instance uses a persistent (non-in-memory) model container.
    /// For testing, create a separate instance with an in-memory container.
    public static let shared: ParsedFileService = {
        do {
            let container = try ModelContainer(
                for: GuionDocumentModel.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
            return ParsedFileService(modelContainer: container)
        } catch {
            fatalError("Failed to create shared ParsedFileService: \(error)")
        }
    }()
}

/// Errors that can occur when using ParsedFileService.
@available(iOS 26.0, macOS 26.0, *)
public enum ParsedFileServiceError: Error, LocalizedError {

    /// The screenplay file could not be parsed.
    case parsingFailed(url: URL, underlyingError: Error)

    /// The document was not found in the database.
    case documentNotFound(id: PersistentIdentifier)

    /// Failed to save to the database.
    case databaseSaveFailed(underlyingError: Error)

    public var errorDescription: String? {
        switch self {
        case .parsingFailed(let url, let underlyingError):
            return "Failed to parse screenplay at \(url.lastPathComponent): \(underlyingError.localizedDescription)"

        case .documentNotFound(let id):
            return "Document with ID \(id) not found in database"

        case .databaseSaveFailed(let underlyingError):
            return "Failed to save document to database: \(underlyingError.localizedDescription)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .parsingFailed:
            return "Ensure the file is a valid screenplay format (Fountain, FDX, PDF, Markdown, Highland, or TextBundle)"

        case .documentNotFound:
            return "The document may have been deleted or the database may be corrupted"

        case .databaseSaveFailed:
            return "Check disk space and database permissions"
        }
    }
}
