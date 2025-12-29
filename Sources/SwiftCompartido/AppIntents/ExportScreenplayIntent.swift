//
//  ExportScreenplayIntent.swift
//  SwiftCompartido
//
//  App Intent for exporting screenplay documents to various formats.
//

import AppIntents
import Foundation
@preconcurrency import SwiftData
import UniformTypeIdentifiers

/// Export a screenplay document to Fountain, FDX, or .guion JSON format.
///
/// This intent enables Shortcuts workflows to export parsed screenplays to
/// different file formats for sharing, archiving, or import into other tools.
///
/// **Key Features**:
/// - Export to Fountain (plain text screenplay format)
/// - Export to FDX (Final Draft XML format)
/// - Export to .guion (JSON format with metadata)
/// - Returns file URL for downstream processing
///
/// **Example Workflow**:
/// ```
/// Parse Screenplay File (input.fountain)
/// → Export Screenplay (format: FDX)
/// → Save File (output.fdx)
/// ```
@available(iOS 26.0, macOS 26.0, *)
public struct ExportScreenplayIntent: AppIntent {

    public static let title: LocalizedStringResource = "Export Screenplay"

    public static let description = IntentDescription(
        "Export a screenplay document to Fountain, FDX, or .guion JSON format."
    )

    public static let openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(
        title: "Document ID",
        description: "The persistent identifier of the screenplay document to export (as JSON-encoded string)"
    )
    public var documentIDString: String

    @Parameter(
        title: "Export Format",
        description: "The target format for export (Fountain, FDX, or .guion JSON)"
    )
    public var exportFormat: ExportFormatEntity

    @Parameter(
        title: "Output Filename",
        description: "Optional: The filename for the exported file (without extension)"
    )
    public var outputFilename: String?

    // MARK: - Initializer

    public init() {
        self.documentIDString = ""
        self.exportFormat = ExportFormatEntity(format: .fountain)
    }

    public init(
        documentIDString: String,
        exportFormat: ExportFormatEntity,
        outputFilename: String? = nil
    ) {
        self.documentIDString = documentIDString
        self.exportFormat = exportFormat
        self.outputFilename = outputFilename
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        // Step 1: Parse documentID from string
        guard let documentID = try? parsePersistentIdentifier(from: documentIDString) else {
            throw ExportError.invalidDocumentID
        }

        // Step 2: Retrieve document
        let service = ParsedFileService.shared
        let document = try await service.document(id: documentID)

        // Step 3: Determine output filename
        let filename = outputFilename ?? document.filename ?? "screenplay"
        let filenameWithExtension = "\(filename).\(exportFormat.format.fileExtension)"

        // Step 4: Export based on format
        let data: Data
        switch exportFormat.format {
        case .fountain:
            data = try exportToFountain(document: document)
        case .fdx:
            data = try exportToFDX(document: document)
        case .guion:
            data = try exportToGuionJSON(document: document)
        }

        // Step 5: Write to temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(filenameWithExtension)

        try data.write(to: tempURL)

        // Step 6: Create IntentFile for return
        let intentFile = IntentFile(
            fileURL: tempURL,
            filename: filenameWithExtension,
            type: exportFormat.format.utType
        )

        return .result(value: intentFile)
    }

    // MARK: - Export Helpers

    /// Export document to Fountain format
    private func exportToFountain(document: GuionDocumentModel) throws -> Data {
        let script = GuionDocumentParserSwiftData.toFountainScript(from: document)
        let fountainText = script.stringFromDocument()
        return Data(fountainText.utf8)
    }

    /// Export document to FDX (Final Draft XML) format
    private func exportToFDX(document: GuionDocumentModel) throws -> Data {
        return GuionDocumentParserSwiftData.toFDXData(from: document)
    }

    /// Export document to .guion JSON format
    private func exportToGuionJSON(document: GuionDocumentModel) throws -> Data {
        let snapshot = document.toSnapshot()
        return try GuionJSONSerializer.encode(snapshot)
    }

    // MARK: - Helper

    /// Parse a PersistentIdentifier from its JSON-encoded string representation
    private func parsePersistentIdentifier(from string: String) throws -> PersistentIdentifier {
        guard let data = string.data(using: .utf8) else {
            throw ExportError.invalidDocumentID
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(PersistentIdentifier.self, from: data)
        } catch {
            throw ExportError.invalidDocumentID
        }
    }
}

// MARK: - Export Format Entity

/// Entity for export format selection in Shortcuts
@available(iOS 26.0, macOS 26.0, *)
public struct ExportFormatEntity: AppEntity {

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Export Format"
    )

    public let id: String
    public let format: ExportFormatType

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(format.displayName)",
            subtitle: ".\(format.fileExtension)"
        )
    }

    public init(id: String, format: ExportFormatType) {
        self.id = id
        self.format = format
    }

    public init(format: ExportFormatType) {
        self.id = format.rawValue
        self.format = format
    }

    public static var defaultQuery: ExportFormatQuery {
        ExportFormatQuery()
    }
}

/// Query for export format entities
@available(iOS 26.0, macOS 26.0, *)
public struct ExportFormatQuery: EntityQuery {

    public init() {}

    public func entities(for identifiers: [String]) async throws -> [ExportFormatEntity] {
        identifiers.compactMap { id in
            Self.allFormats.first { $0.id == id }
        }
    }

    public func suggestedEntities() async throws -> [ExportFormatEntity] {
        Self.allFormats
    }

    private static let allFormats: [ExportFormatEntity] = [
        ExportFormatEntity(format: .fountain),
        ExportFormatEntity(format: .fdx),
        ExportFormatEntity(format: .guion)
    ]
}

/// Export format types
@available(iOS 26.0, macOS 26.0, *)
public enum ExportFormatType: String, Codable, Sendable {
    case fountain
    case fdx
    case guion

    var displayName: String {
        switch self {
        case .fountain: return "Fountain"
        case .fdx: return "Final Draft (FDX)"
        case .guion: return ".guion JSON"
        }
    }

    var fileExtension: String {
        switch self {
        case .fountain: return "fountain"
        case .fdx: return "fdx"
        case .guion: return "guion"
        }
    }

    var utType: UTType {
        switch self {
        case .fountain: return .fountainDocument
        case .fdx: return .fdxDocument
        case .guion: return .guionDocument
        }
    }
}

// MARK: - Errors

@available(iOS 26.0, macOS 26.0, *)
extension ExportScreenplayIntent {
    enum ExportError: LocalizedError {
        case invalidDocumentID
        case exportFailed(Error)

        var errorDescription: String? {
            switch self {
            case .invalidDocumentID:
                return "The provided document ID is invalid or cannot be parsed."
            case .exportFailed(let error):
                return "Failed to export screenplay: \(error.localizedDescription)"
            }
        }
    }
}
