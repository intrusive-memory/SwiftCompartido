//
//  GuionDocument.swift
//  GuionDocumentApp
//
//  Created by TOM STOVALL on 10/9/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ZIPFoundation

/// Document configuration for GuionDocumentModel
struct GuionDocumentConfiguration: FileDocument {
    static var readableContentTypes: [UTType] {
        [.guionDocument, .fountainDocument, .fdxDocument, .highlandDocument]
    }

    var document: GuionDocumentModel

    init(document: GuionDocumentModel = GuionDocumentModel()) {
        self.document = document
    }

    init(configuration: ReadConfiguration) throws {
        // Check if this is a .guion TextPack bundle
        if configuration.file.isDirectory,
           configuration.contentType == .guionDocument || configuration.file.filename?.hasSuffix(".guion") == true {
            // Load as TextPack bundle
            // For now, extract the screenplay.fountain content for later parsing
            // (Full TextPack loading happens in parseContent with ModelContext)
            if let resourceWrapper = configuration.file.fileWrappers?["screenplay.fountain"],
               let data = resourceWrapper.regularFileContents,
               let content = String(data: data, encoding: .utf8) {
                self.document = GuionDocumentModel()
                document.rawContent = content
                document.filename = configuration.file.filename
                print("📦 TextPack bundle loaded: \(configuration.file.filename ?? "unknown")")
                return
            }
        }

        // Create a temporary document - will be populated in the view
        self.document = GuionDocumentModel()

        // Store the file wrapper for later processing
        let content = Self.extractContent(from: configuration.file, filename: configuration.file.filename)
        print("📥 Document loaded: \(configuration.file.filename ?? "unknown"), content length: \(content?.count ?? 0)")
        document.rawContent = content
        document.filename = configuration.file.filename
        print("📄 GuionDocument initialized with rawContent: \(document.rawContent?.count ?? 0) chars")
    }

    /// Extract content from FileWrapper, handling both regular files and packages
    private static func extractContent(from fileWrapper: FileWrapper, filename: String?) -> String? {
        guard let data = fileWrapper.regularFileContents else {
            print("⚠️ No regular file contents")
            return nil
        }

        // Check if it's a Highland file (ZIP archive)
        let ext = (filename as NSString?)?.pathExtension.lowercased()
        if ext == "highland" {
            print("📦 Highland ZIP file detected, extracting...")
            return extractHighlandContent(from: data)
        }

        // For other files, try to decode as UTF-8
        if let content = String(data: data, encoding: .utf8) {
            return content
        }

        print("⚠️ Could not decode file as UTF-8")
        return nil
    }

    /// Extract Fountain content from Highland ZIP data
    private static func extractHighlandContent(from zipData: Data) -> String? {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            // Write ZIP data to temp file
            let tempZipURL = tempDir.appendingPathComponent("highland.zip")
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try zipData.write(to: tempZipURL)

            // Extract ZIP
            let extractDir = tempDir.appendingPathComponent("extracted")
            try fileManager.unzipItem(at: tempZipURL, to: extractDir)

            // Find .textbundle directory
            let contents = try fileManager.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
            guard let textBundleURL = contents.first(where: { $0.pathExtension == "textbundle" }) else {
                print("⚠️ No .textbundle found in Highland file")
                return nil
            }

            print("✅ Found textbundle: \(textBundleURL.lastPathComponent)")

            // Look for content files in priority order
            let textBundleContents = try fileManager.contentsOfDirectory(at: textBundleURL, includingPropertiesForKeys: nil)

            // 1. Try text.md (Highland 2 standard)
            if let textMdURL = textBundleContents.first(where: { $0.lastPathComponent == "text.md" }) {
                print("✅ Found text.md")
                let content = try String(contentsOf: textMdURL, encoding: .utf8)
                try? fileManager.removeItem(at: tempDir)
                return content
            }

            // 2. Try any .fountain file
            if let fountainURL = textBundleContents.first(where: { $0.pathExtension.lowercased() == "fountain" }) {
                print("✅ Found fountain file: \(fountainURL.lastPathComponent)")
                let content = try String(contentsOf: fountainURL, encoding: .utf8)
                try? fileManager.removeItem(at: tempDir)
                return content
            }

            // 3. Try any .md file
            if let mdURL = textBundleContents.first(where: { $0.pathExtension.lowercased() == "md" }) {
                print("✅ Found markdown file: \(mdURL.lastPathComponent)")
                let content = try String(contentsOf: mdURL, encoding: .utf8)
                try? fileManager.removeItem(at: tempDir)
                return content
            }

            print("⚠️ No content files found in textbundle")
            try? fileManager.removeItem(at: tempDir)
            return nil

        } catch {
            print("❌ Error extracting Highland content: \(error)")
            try? fileManager.removeItem(at: tempDir)
            return nil
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Determine output format based on content type
        if configuration.contentType == .guionDocument {
            // Export as .guion TextPack bundle
            return try TextPackWriter.createTextPack(from: document)
        } else if configuration.contentType == .fdxDocument {
            // Export as FDX
            let data = GuionDocumentParserSwiftData.toFDXData(from: document)
            return FileWrapper(regularFileWithContents: data)
        } else {
            // Default to Fountain format
            let script = GuionDocumentParserSwiftData.toFountainScript(from: document)
            let fountainText = script.stringFromDocument()
            let data = Data(fountainText.utf8)
            return FileWrapper(regularFileWithContents: data)
        }
    }
}

/// Helper to parse screenplay data into SwiftData models
extension GuionDocumentModel {
    /// Parse screenplay from raw content and file type
    /// Returns a new parsed document instead of modifying self
    @MainActor
    static func parseContent(
        rawContent: String,
        filename: String?,
        contentType: UTType,
        modelContext: ModelContext
    ) async throws -> GuionDocumentModel {
        // Create temporary file for parsing
        let tempDir = FileManager.default.temporaryDirectory

        // For Highland files, the rawContent is already extracted Fountain text
        // So we should parse it as a .fountain file, not .highland
        let ext: String
        if contentType == .highlandDocument {
            ext = "fountain"
        } else {
            ext = fileExtension(for: contentType)
        }

        let tempURL = tempDir.appendingPathComponent("temp_screenplay.\(ext)")

        try rawContent.write(to: tempURL, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Use the unified parser
        let parsedDocument = try await GuionDocumentParserSwiftData.loadAndParse(
            from: tempURL,
            in: modelContext,
            generateSummaries: false
        )

        // Store original raw content
        parsedDocument.rawContent = rawContent

        return parsedDocument
    }

    private static func fileExtension(for contentType: UTType) -> String {
        switch contentType {
        case .fdxDocument:
            return "fdx"
        case .fountainDocument:
            return "fountain"
        default:
            return "fountain"
        }
    }

    /// Extract character information from the document
    /// - Returns: A dictionary mapping character names to their information
    func extractCharacters() -> CharacterList {
        // Convert to GuionParsedElementCollection and use its character extraction
        let script = GuionDocumentParserSwiftData.toFountainScript(from: self)
        return script.extractCharacters()
    }
}

extension UTType {
    static var guionDocument: UTType {
        UTType(importedAs: "com.swiftguion.screenplay")
    }

    static var fdxDocument: UTType {
        UTType(importedAs: "com.finaldraft.fdx")
    }

    static var fountainDocument: UTType {
        UTType(importedAs: "com.fountain")
    }

    static var highlandDocument: UTType {
        UTType(importedAs: "com.highland")
    }
}
