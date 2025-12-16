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
public struct GuionDocumentConfiguration: FileDocument {
    public static var readableContentTypes: [UTType] {
        [.guionDocument, .fountainDocument, .fdxDocument, .highlandDocument]
    }

    public var document: GuionDocumentModel

    public init(document: GuionDocumentModel = GuionDocumentModel()) {
        self.document = document
    }

    public init(configuration: ReadConfiguration) throws {
        // Try to load as .guion JSON file (Phase 1 format)
        if configuration.contentType == .guionDocument,
           let data = configuration.file.regularFileContents {
            do {
                // Attempt to decode as JSON
                let snapshot = try GuionJSONSerializer.decode(data)

                // Store a temporary document with the JSON data as rawContent
                // The actual snapshot-to-model conversion will happen in parseContent()
                // when we have a proper ModelContext
                self.document = GuionDocumentModel()
                document.filename = configuration.file.filename
                // Store the JSON data for later parsing
                document.rawContent = String(data: data, encoding: .utf8)
                #if DEBUG
                print("📄 JSON .guion file loaded: \(configuration.file.filename ?? "unknown"), \(snapshot.elements.count) elements")
                #endif
                return
            } catch {
                #if DEBUG
                print("⚠️ Failed to decode as JSON, trying TextPack fallback: \(error.localizedDescription)")
                #endif
                // Fall through to TextPack fallback
            }
        }

        // Backward compatibility: Check if this is a legacy .guion TextPack bundle
        if configuration.file.isDirectory,
           configuration.contentType == .guionDocument || configuration.file.filename?.hasSuffix(".guion") == true {
            // Load as legacy TextPack bundle (backward compatibility)
            // Extract the screenplay.fountain content for later parsing
            if let resourceWrapper = configuration.file.fileWrappers?["screenplay.fountain"],
               let data = resourceWrapper.regularFileContents,
               let content = String(data: data, encoding: .utf8) {
                self.document = GuionDocumentModel()
                document.rawContent = content
                document.filename = configuration.file.filename
                #if DEBUG
                print("📦 Legacy TextPack bundle loaded: \(configuration.file.filename ?? "unknown")")
                #endif
                return
            }
        }

        // Create a temporary document - will be populated in the view
        self.document = GuionDocumentModel()

        // Store the file wrapper for later processing
        let content = Self.extractContent(from: configuration.file, filename: configuration.file.filename)
        #if DEBUG
        print("📥 Document loaded: \(configuration.file.filename ?? "unknown"), content length: \(content?.count ?? 0)")
        #endif
        document.rawContent = content
        document.filename = configuration.file.filename
        #if DEBUG
        print("📄 GuionDocument initialized with rawContent: \(document.rawContent?.count ?? 0) chars")
        #endif
    }

    /// Extract content from FileWrapper, handling both regular files and packages
    private static func extractContent(from fileWrapper: FileWrapper, filename: String?) -> String? {
        guard let data = fileWrapper.regularFileContents else {
            #if DEBUG
            print("⚠️ No regular file contents")
            #endif
            return nil
        }

        // Check if it's a Highland file
        // Highland files can be EITHER:
        // 1. ZIP archives (Highland 2 format with .textbundle inside)
        // 2. Plain Fountain text (exported or newer format)
        let ext = (filename as NSString?)?.pathExtension.lowercased()
        if ext == "highland" {
            #if DEBUG
            print("📦 Highland file detected, attempting ZIP extraction...")
            #endif

            // Try ZIP extraction first (Highland 2 format)
            if let content = extractHighlandContent(from: data) {
                return content
            }

            #if DEBUG
            print("⚠️ ZIP extraction failed, trying plain text fallback...")
            #endif

            // Fall back to plain text (Highland might be a Fountain text file)
            if let content = String(data: data, encoding: .utf8) {
                #if DEBUG
                print("✅ Highland file loaded as plain Fountain text")
                #endif
                return content
            }

            #if DEBUG
            print("❌ Highland file could not be loaded as ZIP or plain text")
            #endif
            return nil
        }

        // For other files, try to decode as UTF-8
        if let content = String(data: data, encoding: .utf8) {
            return content
        }

        #if DEBUG
        print("⚠️ Could not decode file as UTF-8")
        #endif
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
                #if DEBUG
                print("⚠️ No .textbundle found in Highland file")
                #endif
                return nil
            }

            #if DEBUG
            print("✅ Found textbundle: \(textBundleURL.lastPathComponent)")
            #endif

            // Look for content files in priority order
            let textBundleContents = try fileManager.contentsOfDirectory(at: textBundleURL, includingPropertiesForKeys: nil)

            // 1. Try text.md (Highland 2 standard)
            if let textMdURL = textBundleContents.first(where: { $0.lastPathComponent == "text.md" }) {
                #if DEBUG
                print("✅ Found text.md")
                #endif
                let content = try String(contentsOf: textMdURL, encoding: .utf8)
                try? fileManager.removeItem(at: tempDir)
                return content
            }

            // 2. Try any .fountain file
            if let fountainURL = textBundleContents.first(where: { $0.pathExtension.lowercased() == "fountain" }) {
                #if DEBUG
                print("✅ Found fountain file: \(fountainURL.lastPathComponent)")
                #endif
                let content = try String(contentsOf: fountainURL, encoding: .utf8)
                try? fileManager.removeItem(at: tempDir)
                return content
            }

            // 3. Try any .md file
            if let mdURL = textBundleContents.first(where: { $0.pathExtension.lowercased() == "md" }) {
                #if DEBUG
                print("✅ Found markdown file: \(mdURL.lastPathComponent)")
                #endif
                let content = try String(contentsOf: mdURL, encoding: .utf8)
                try? fileManager.removeItem(at: tempDir)
                return content
            }

            #if DEBUG
            print("⚠️ No content files found in textbundle")
            #endif
            try? fileManager.removeItem(at: tempDir)
            return nil

        } catch {
            #if DEBUG
            print("❌ Error extracting Highland content: \(error)")
            #endif
            try? fileManager.removeItem(at: tempDir)
            return nil
        }
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Determine output format based on content type
        if configuration.contentType == .guionDocument {
            // Export as .guion JSON file (Phase 1: replaces TextPack bundle)
            let snapshot = document.toSnapshot()
            let data = try GuionJSONSerializer.encode(snapshot)
            return FileWrapper(regularFileWithContents: data)
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
public extension GuionDocumentModel {
    /// Parse screenplay from raw content and file type
    /// Returns a new parsed document instead of modifying self
    @MainActor
    static func parseContent(
        rawContent: String,
        filename: String?,
        contentType: UTType,
        modelContext: ModelContext
    ) async throws -> GuionDocumentModel {
        // Handle JSON .guion files (Phase 1 format)
        if contentType == .guionDocument, let data = rawContent.data(using: .utf8) {
            do {
                // Try to decode as JSON snapshot
                let snapshot = try GuionJSONSerializer.decode(data)
                let document = GuionDocumentModel.from(snapshot, in: modelContext)
                // Store original raw content
                document.rawContent = rawContent
                return document
            } catch {
                #if DEBUG
                print("⚠️ Failed to parse as JSON .guion, falling back to Fountain parsing: \(error.localizedDescription)")
                #endif
                // Fall through to legacy parsing (TextPack bundles stored Fountain content)
            }
        }

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

public extension UTType {
    public static var guionDocument: UTType {
        UTType(importedAs: "io.intrusive-memory.produciesta.screenplay")
    }

    public static var fdxDocument: UTType {
        UTType(importedAs: "com.finaldraft.fdx")
    }

    public static var fountainDocument: UTType {
        UTType(importedAs: "com.fountain.screenplay")
    }

    public static var highlandDocument: UTType {
        UTType(importedAs: "com.quoteunquoteapps.highland")
    }
}
