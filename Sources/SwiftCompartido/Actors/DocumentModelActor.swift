//
//  DocumentModelActor.swift
//  SwiftCompartido
//
//  SwiftData actor for safe concurrent database operations
//
//  This actor provides isolated access to SwiftData for operations that don't need MainActor,
//  preventing data races and concurrency conflicts during parsing and batch operations.
//

import Foundation
@preconcurrency import SwiftData

/// Actor for safe SwiftData operations off the main thread
///
/// ## Purpose
/// Isolates database writes/reads to prevent concurrent access conflicts.
/// Particularly important for:
/// - Document parsing and import (avoiding forced-sync warnings)
/// - Heavy queries that would block UI
/// - Background operations
///
/// ## Usage Pattern
/// ```swift
/// let actor = DocumentModelActor(modelContainer: sharedModelContainer)
///
/// // Parse and save document in background
/// let documentID = try await actor.parseAndSaveDocument(
///     from: url,
///     progress: progress
/// )
///
/// // Fetch on MainActor for display
/// await MainActor.run {
///     let document = modelContext.model(for: documentID)
///     // Update UI with document
/// }
/// ```
///
/// ## Key Principles
/// - Never pass Model instances between actors (use PersistentIdentifier)
/// - Each actor has its own ModelContext from shared ModelContainer
/// - Return plain data types (Bool, String, PersistentIdentifier, etc.) not model objects
/// - UI updates happen on MainActor after actor operations complete
@ModelActor
public actor DocumentModelActor {

    // MARK: - Document Operations

    /// Parse and save a screenplay document from a file
    /// - Parameters:
    ///   - url: URL of the screenplay file to parse
    ///   - progress: Optional progress tracker
    /// - Returns: Persistent identifier of the created document
    public func parseAndSaveDocument(
        from url: URL,
        progress: OperationProgress? = nil
    ) async throws -> PersistentIdentifier {
        // Parse the screenplay
        let screenplay = try await GuionParsedElementCollection(file: url.path, progress: progress)

        // Convert to SwiftData model (use GuionDocumentModel.from directly to avoid actor isolation issues)
        let document = await GuionDocumentModel.from(
            screenplay,
            in: modelContext,
            generateSummaries: false,
            progress: progress
        )

        // Insert and save
        modelContext.insert(document)
        try modelContext.save()

        return document.persistentModelID
    }

    /// Parse and save a screenplay document from a string
    /// - Parameters:
    ///   - string: Fountain screenplay text
    ///   - title: Optional title for the document
    ///   - progress: Optional progress tracker
    /// - Returns: Persistent identifier of the created document
    public func parseAndSaveDocument(
        from string: String,
        title: String? = nil,
        progress: OperationProgress? = nil
    ) async throws -> PersistentIdentifier {
        // Parse the screenplay
        let screenplay = try await GuionParsedElementCollection(string: string, progress: progress)

        // Convert to SwiftData model (use GuionDocumentModel.from directly to avoid actor isolation issues)
        let document = await GuionDocumentModel.from(
            screenplay,
            in: modelContext,
            generateSummaries: false,
            progress: progress
        )

        // Set title if provided
        if let title = title {
            document.title = title
        }

        // Insert and save
        modelContext.insert(document)
        try modelContext.save()

        return document.persistentModelID
    }

    /// Get document basic info (Sendable DTO)
    /// - Parameter documentID: Persistent identifier of the document
    /// - Returns: DocumentInfo struct or nil if not found
    public func getDocumentInfo(documentID: PersistentIdentifier) -> DocumentInfo? {
        guard let document = modelContext.model(for: documentID) as? GuionDocumentModel else {
            return nil
        }

        return DocumentInfo(
            id: document.persistentModelID,
            title: document.title,
            elementCount: document.elements.count
        )
    }

    /// Delete a document
    /// - Parameter documentID: Persistent identifier of the document
    public func deleteDocument(documentID: PersistentIdentifier) throws {
        guard let document = modelContext.model(for: documentID) as? GuionDocumentModel else {
            throw DocumentModelActorError.documentNotFound
        }

        modelContext.delete(document)
        try modelContext.save()
    }

    // MARK: - Element Operations

    /// Get elements for a document (as Sendable DTOs)
    /// - Parameters:
    ///   - documentID: Persistent identifier of the document
    ///   - limit: Optional limit on number of elements to return
    /// - Returns: Array of ElementInfo structs
    public func getElements(
        for documentID: PersistentIdentifier,
        limit: Int? = nil
    ) throws -> [ElementInfo] {
        guard let document = modelContext.model(for: documentID) as? GuionDocumentModel else {
            throw DocumentModelActorError.documentNotFound
        }

        // Get elements in sorted order (by chapterIndex, then orderIndex)
        let elements = document.sortedElements
        let limitedElements = limit.map { Array(elements.prefix($0)) } ?? elements

        // Convert to DTOs, preserving sort order
        let elementInfos = limitedElements.map { element in
            ElementInfo(
                id: element.persistentModelID,
                elementType: element.elementType,
                elementText: element.elementText,
                chapterIndex: element.chapterIndex,
                orderIndex: element.orderIndex
            )
        }

        // Ensure elements are sorted by composite key (chapterIndex, orderIndex)
        // This guarantees document order even if SwiftData relationship order changes
        return elementInfos.sorted { lhs, rhs in
            if lhs.chapterIndex != rhs.chapterIndex {
                return lhs.chapterIndex < rhs.chapterIndex
            }
            return lhs.orderIndex < rhs.orderIndex
        }
    }

    /// Check if a document exists
    /// - Parameter documentID: Persistent identifier of the document
    /// - Returns: True if document exists, false otherwise
    public func documentExists(documentID: PersistentIdentifier) -> Bool {
        return (modelContext.model(for: documentID) as? GuionDocumentModel) != nil
    }

    // MARK: - Helper Types

    /// Sendable DTO for document information
    public struct DocumentInfo: Sendable, Identifiable {
        public let id: PersistentIdentifier
        public let title: String?
        public let elementCount: Int
    }

    /// Sendable DTO for element information
    public struct ElementInfo: Sendable, Identifiable {
        public let id: PersistentIdentifier
        public let elementType: ElementType
        public let elementText: String
        public let chapterIndex: Int
        public let orderIndex: Int
    }
}

// MARK: - DisplayableElement Conformance

@available(iOS 26.0, macOS 26.0, *)
extension DocumentModelActor.ElementInfo: DisplayableElement {
    /// DTOs don't pre-compute formatted text
    /// Views will format at runtime using FountainTextFormatter
    public var formattedText: AttributedString? {
        return nil
    }
}

// MARK: - Errors

public enum DocumentModelActorError: LocalizedError {
    case documentNotFound
    case elementNotFound
    case invalidData
    case parseError(String)

    public var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "Document not found in database"
        case .elementNotFound:
            return "Element not found in database"
        case .invalidData:
            return "Invalid data provided for operation"
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}
