//
//  ExportDocument.swift
//  GuionDocumentApp
//
//  Created for Phase 4: Export Functionality Separation
//

import SwiftUI
import UniformTypeIdentifiers

/// Wrapper for exporting a GuionDocumentModel to Fountain format
struct FountainExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [] }
    static var writableContentTypes: [UTType] { [.fountainDocument] }

    let sourceDocument: GuionDocumentModel

    init(sourceDocument: GuionDocumentModel) {
        self.sourceDocument = sourceDocument
    }

    init(configuration: ReadConfiguration) throws {
        // Not used for export-only documents
        throw ExportError.readNotSupported
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Convert to GuionParsedScreenplay and serialize
        let script = GuionDocumentParserSwiftData.toFountainScript(from: sourceDocument)
        let fountainText = script.stringFromDocument()
        let data = Data(fountainText.utf8)

        return FileWrapper(regularFileWithContents: data)
    }
}

/// Wrapper for exporting a GuionDocumentModel to FDX format
struct FDXExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [] }
    static var writableContentTypes: [UTType] { [.fdxDocument] }

    let sourceDocument: GuionDocumentModel

    init(sourceDocument: GuionDocumentModel) {
        self.sourceDocument = sourceDocument
    }

    init(configuration: ReadConfiguration) throws {
        // Not used for export-only documents
        throw ExportError.readNotSupported
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Convert to FDX XML format
        let data = GuionDocumentParserSwiftData.toFDXData(from: sourceDocument)
        return FileWrapper(regularFileWithContents: data)
    }
}

/// Export format enum for state management
enum ExportFormat: String, CaseIterable {
    case fountain
    case fdx

    var displayName: String {
        switch self {
        case .fountain: return "Fountain Format"
        case .fdx: return "Final Draft Format"
        }
    }

    var fileExtension: String {
        switch self {
        case .fountain: return "fountain"
        case .fdx: return "fdx"
        }
    }

    var contentType: UTType {
        switch self {
        case .fountain: return .fountainDocument
        case .fdx: return .fdxDocument
        }
    }
}

/// Error types for export operations
enum ExportError: LocalizedError {
    case readNotSupported
    case invalidDocument
    case conversionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .readNotSupported:
            return "Export documents cannot be opened"
        case .invalidDocument:
            return "The document is invalid or empty"
        case .conversionFailed(let error):
            return "Failed to convert document: \(error.localizedDescription)"
        }
    }
}
