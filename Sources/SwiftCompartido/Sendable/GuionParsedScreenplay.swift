//
//  FountainScript.swift
//  SwiftFountain
//
//  Copyright (c) 2012-2013 Nima Yousefi & John August
//  Swift conversion (c) 2025
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation
import ZIPFoundation

/// Main screenplay element collection that handles parsing from multiple formats with progress tracking.
///
/// ## Overview
///
/// **GuionParsedElementCollection** is the recommended entry point for screenplay parsing.
/// It provides a unified interface for parsing Fountain format files and strings,
/// with comprehensive progress reporting support.
///
/// ## Why Use GuionParsedElementCollection Instead of Direct Parsers?
///
/// ✅ **Unified API**: Single type handles all parsing operations
/// ✅ **Progress Support**: Built-in progress reporting for all parsing methods
/// ✅ **Format Flexibility**: Supports multiple screenplay formats
/// ✅ **Future-Proof**: New format support added here first
///
/// ## Recommended Usage
///
/// ### ✅ DO: Use GuionParsedElementCollection
///
/// ```swift
/// // Parse with progress reporting
/// let progress = OperationProgress(totalUnits: nil) { update in
///     print(update.description)
/// }
/// let screenplay = try await GuionParsedElementCollection(
///     file: "/path/to/script.fountain",
///     progress: progress
/// )
/// ```
///
/// ### ❌ DON'T: Use parsers directly
///
/// ```swift
/// // Avoid this - use GuionParsedElementCollection instead
/// let parser = try await FountainParser(file: path, progress: progress)
/// // Then manually extract elements...
/// ```
///
/// ## Topics
///
/// ### Creating from Files
/// - ``init(file:parser:progress:)`` - Async with progress (recommended)
/// - ``init(file:parser:)`` - Synchronous (backward compatible)
///
/// ### Creating from Strings
/// - ``init(string:parser:progress:)`` - Async with progress (recommended)
/// - ``init(string:parser:)`` - Synchronous (backward compatible)
///
/// ### Creating from Parsed Data
/// - ``init(filename:elements:titlePage:suppressSceneNumbers:)``
///
/// ### Exporting
/// - ``write(toFile:)``
/// - ``write(to:)``
/// - ``stringFromDocument()``
///
public final class GuionParsedElementCollection {
    public let filename: String?
    public let elements: [GuionElement]
    public let titlePage: [[String: [String]]]
    public let suppressSceneNumbers: Bool
    public let customPages: [CustomPageContainer]

    /// Initialize with parsed screenplay data
    /// - Parameters:
    ///   - filename: Optional filename for the screenplay
    ///   - elements: Array of GuionElements
    ///   - titlePage: Title page metadata
    ///   - suppressSceneNumbers: Whether to suppress scene numbers
    ///   - customPages: Custom pages (Cast Lists, Production Notes, etc.)
    public init(
        filename: String? = nil,
        elements: [GuionElement] = [],
        titlePage: [[String: [String]]] = [],
        suppressSceneNumbers: Bool = false,
        customPages: [CustomPageContainer] = []
    ) {
        self.filename = filename
        self.elements = elements
        self.titlePage = titlePage
        self.suppressSceneNumbers = suppressSceneNumbers
        self.customPages = customPages
    }

    /// Convenience initializer that parses from a file
    ///
    /// Automatically detects file format based on extension:
    /// - `.md` or `.markdown` → Markdown parser (supports YAML front matter)
    /// - `.docx`, `.odt`, `.rtf` → Pandoc parser (macOS only)
    /// - `.fountain` or other → Fountain parser
    ///
    /// - Parameters:
    ///   - path: File path to parse
    public convenience init(file path: String) throws {
        let url = URL(fileURLWithPath: path)
        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        // Detect markdown files
        if ext == "md" || ext == "markdown" {
            let contents = try String(contentsOfFile: path, encoding: .utf8)
            let (elements, titlePage, customPages) = try MarkdownParser.parse(contents)
            self.init(
                filename: filename,
                elements: elements,
                titlePage: titlePage,
                suppressSceneNumbers: false,
                customPages: customPages
            )
        } else if ext == "docx" || ext == "odt" || ext == "rtf" {
            // Parse Pandoc-supported document formats
            #if os(macOS)
            let (elements, titlePage) = try PandocDocumentParser.parse(url: url)
            self.init(
                filename: filename,
                elements: elements,
                titlePage: titlePage,
                suppressSceneNumbers: false
            )
            #else
            throw NSError(
                domain: "SwiftCompartido",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Pandoc formats (.docx, .odt, .rtf) are only supported on macOS"]
            )
            #endif
        } else {
            // Default to Fountain parser
            let fountainParser = try FountainParser(file: path)
            // REMOVED: Automatic sidecar loading - customPages must be loaded manually if needed
            self.init(
                filename: filename,
                elements: fountainParser.elements,
                titlePage: fountainParser.titlePage,
                suppressSceneNumbers: false,
                customPages: []
            )
        }
    }

    /// Convenience initializer that parses from a string
    /// - Parameters:
    ///   - string: Fountain screenplay text
    public convenience init(string: String) throws {
        let fountainParser = FountainParser(string: string)
        self.init(
            filename: nil,
            elements: fountainParser.elements,
            titlePage: fountainParser.titlePage
        )
    }

    // MARK: - Async Convenience Initializers with Progress Support

    /// Async convenience initializer that parses from a file with optional progress reporting
    ///
    /// **This is the recommended way to parse screenplay files.**
    ///
    /// Automatically detects file format based on extension:
    /// - `.md` or `.markdown` → Markdown parser (supports YAML front matter)
    /// - `.highland` → Highland bundle parser (ZIP containing TextBundle)
    /// - `.textbundle` → TextBundle parser
    /// - `.fdx` → Final Draft FDX parser
    /// - `.pdf` → PDF parser (requires iOS 26.0+)
    /// - `.docx` → Microsoft Word document (via Pandoc)
    /// - `.odt` → OpenDocument Text (via Pandoc)
    /// - `.rtf` → Rich Text Format (via Pandoc)
    /// - `.fountain` or other → Fountain parser
    ///
    /// - Parameters:
    ///   - path: File path to parse
    ///   - progress: Optional progress tracker for monitoring parsing progress
    ///
    /// ## Example
    ///
    /// ```swift
    /// // With progress
    /// let progress = OperationProgress(totalUnits: nil) { update in
    ///     print("\(update.description): \(Int((update.fractionCompleted ?? 0) * 100))%")
    /// }
    ///
    /// let screenplay = try await GuionParsedElementCollection(
    ///     file: "/path/to/script.fountain",
    ///     progress: progress
    /// )
    ///
    /// // Without progress (backward compatible)
    /// let screenplay = try await GuionParsedElementCollection(
    ///     file: "/path/to/script.fountain"
    /// )
    /// ```
    ///
    /// ## Progress Stages
    ///
    /// The progress handler receives updates for:
    /// - Preparing to parse
    /// - Parsing title page
    /// - Processing elements (batched every 10 elements)
    /// - Finalizing screenplay
    ///
    /// - Note: When `progress` is `nil`, parsing runs without progress updates
    ///
    /// - SeeAlso: ``init(string:progress:)``
    public convenience init(
        file path: String,
        progress: OperationProgress? = nil
    ) async throws {
        let url = URL(fileURLWithPath: path)
        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "md", "markdown":
            // Parse markdown files
            let contents = try String(contentsOfFile: path, encoding: .utf8)
            let (elements, titlePage, customPages) = try MarkdownParser.parse(contents)
            self.init(
                filename: filename,
                elements: elements,
                titlePage: titlePage,
                suppressSceneNumbers: false,
                customPages: customPages
            )

        case "highland":
            // Parse Highland files (ZIP archives containing TextBundle)
            // Use the synchronous convenience init which handles extraction
            try self.init(highland: url)

        case "textbundle":
            // Parse TextBundle files
            try self.init(textBundle: url)

        case "fdx":
            // Parse Final Draft FDX files
            let data = try Data(contentsOf: url)
            let fdxParser = FDXParser()
            let parsed = try fdxParser.parse(data: data, filename: filename)

            // Convert FDX parsed document to GuionParsedElementCollection
            let elements = parsed.elements.map { GuionElement(from: $0) }

            // Convert title page entries to the expected format
            var titlePageDict: [String: [String]] = [:]
            for entry in parsed.titlePageEntries {
                titlePageDict[entry.key] = entry.values
            }
            let titlePage = titlePageDict.isEmpty ? [] : [titlePageDict]

            self.init(
                filename: parsed.filename,
                elements: elements,
                titlePage: titlePage,
                suppressSceneNumbers: parsed.suppressSceneNumbers
            )

        case "pdf":
            // Parse PDF files using PDFScreenplayParser
            #if canImport(FoundationModels)
            if #available(iOS 26.0, macCatalyst 26.0, macOS 26.0, *) {
                let screenplay = try await PDFScreenplayParser.parse(from: url, progress: progress)
                self.init(
                    filename: filename,
                    elements: screenplay.elements,
                    titlePage: screenplay.titlePage,
                    suppressSceneNumbers: screenplay.suppressSceneNumbers
                )
            } else {
                throw PDFScreenplayParserError.foundationModelsUnavailable
            }
            #else
            throw PDFScreenplayParserError.foundationModelsUnavailable
            #endif

        case "docx", "odt", "rtf":
            // Parse document files (DOCX, ODT, RTF) using Pandoc
            let (elements, titlePage) = try PandocDocumentParser.parse(url: url)
            self.init(
                filename: filename,
                elements: elements,
                titlePage: titlePage,
                suppressSceneNumbers: false
            )

        default:
            // Default to Fountain parser
            // Read file contents
            let contents = try String(contentsOfFile: path, encoding: .utf8)

            // Parse with progress
            let fountainParser = try await FountainParser(string: contents, progress: progress)
            self.init(
                filename: filename,
                elements: fountainParser.elements,
                titlePage: fountainParser.titlePage
            )
        }
    }

    /// Async convenience initializer that parses from a string with optional progress reporting
    ///
    /// **This is the recommended way to parse screenplay strings.**
    ///
    /// - Parameters:
    ///   - string: Fountain screenplay text
    ///   - progress: Optional progress tracker for monitoring parsing progress
    ///
    /// ## Example
    ///
    /// ```swift
    /// let fountainText = """
    /// Title: My Script
    /// Author: Jane Doe
    ///
    /// INT. OFFICE - DAY
    ///
    /// JOHN types at his computer.
    /// """
    ///
    /// // With progress
    /// let progress = OperationProgress(totalUnits: nil) { update in
    ///     Task { @MainActor in
    ///         self.statusLabel.text = update.description
    ///         self.progressBar.doubleValue = update.fractionCompleted ?? 0.0
    ///     }
    /// }
    ///
    /// let screenplay = try await GuionParsedElementCollection(
    ///     string: fountainText,
    ///     progress: progress
    /// )
    ///
    /// // Without progress (backward compatible)
    /// let screenplay = try await GuionParsedElementCollection(string: fountainText)
    /// ```
    ///
    /// ## Progress Stages
    ///
    /// The progress handler receives updates for:
    /// - Preparing to parse
    /// - Parsing title page
    /// - Processing elements (batched every 10 elements)
    /// - Finalizing screenplay
    ///
    /// ## SwiftUI Integration
    ///
    /// ```swift
    /// @MainActor
    /// class ParserViewModel: ObservableObject {
    ///     @Published var progressMessage = ""
    ///     @Published var progressFraction = 0.0
    ///
    ///     func parse(_ text: String) async throws -> GuionParsedElementCollection {
    ///         let progress = OperationProgress(totalUnits: nil) { update in
    ///             Task { @MainActor in
    ///                 self.progressMessage = update.description
    ///                 self.progressFraction = update.fractionCompleted ?? 0.0
    ///             }
    ///         }
    ///
    ///         return try await GuionParsedElementCollection(
    ///             string: text,
    ///             progress: progress
    ///         )
    ///     }
    /// }
    /// ```
    ///
    /// - Note: When `progress` is `nil`, parsing runs without progress updates
    ///
    /// - SeeAlso: ``init(file:progress:)``
    public convenience init(
        string: String,
        progress: OperationProgress? = nil
    ) async throws {
        let fountainParser = try await FountainParser(string: string, progress: progress)
        self.init(
            filename: nil,
            elements: fountainParser.elements,
            titlePage: fountainParser.titlePage
        )
    }

    // MARK: - Export Methods

    public func stringFromDocument() -> String {
        return FountainWriter.document(from: self)
    }

    public func stringFromTitlePage() -> String {
        return FountainWriter.titlePage(from: self)
    }

    public func stringFromBody() -> String {
        return FountainWriter.body(from: self)
    }

    public func write(toFile path: String) throws {
        let document = FountainWriter.document(from: self)
        try document.write(toFile: path, atomically: true, encoding: .utf8)

        // REMOVED: Automatic sidecar writing - write customPages manually if needed
    }

    public func write(to url: URL) throws {
        let document = FountainWriter.document(from: self)
        try document.write(to: url, atomically: true, encoding: .utf8)

        // REMOVED: Automatic sidecar writing - write customPages manually if needed
    }

    /// Get guión elements from this screenplay
    /// - Returns: Array of GuionElement objects
    /// - Note: This method simply returns the elements array. For parsing from files, use the init methods.
    public func getGuionElements() -> [GuionElement] {
        return elements
    }

    /// Get the content URL for a Fountain file
    /// - Parameter fileURL: URL to a .fountain, .highland, or .textbundle file
    /// - Returns: URL to the content file
    /// - Throws: Errors if the file type is unsupported or content cannot be found
    public func getContentUrl(from fileURL: URL) throws -> URL {
        let fileExtension = fileURL.pathExtension.lowercased()

        switch fileExtension {
        case "fountain":
            // For .fountain files, return the URL as-is
            return fileURL

        case "highland":
            // For .highland files, extract and find the content file
            return try getContentUrlFromHighland(fileURL)

        case "textbundle":
            // For .textbundle files, find the content file in the bundle
            return try Self.getContentURL(from: fileURL)

        default:
            throw FountainScriptError.unsupportedFileType
        }
    }

    /// Get content from a Fountain file
    /// - Parameter fileURL: URL to a .fountain, .highland, or .textbundle file
    /// - Returns: Content string (for .fountain files, this excludes the front matter)
    /// - Throws: Errors if the file cannot be read
    public func getContent(from fileURL: URL) throws -> String {
        let fileExtension = fileURL.pathExtension.lowercased()

        switch fileExtension {
        case "fountain":
            // For .fountain files, return content without front matter
            let fullContent = try String(contentsOf: fileURL, encoding: .utf8)
            return bodyContent(ofString: fullContent)

        case "textbundle":
            // For .textbundle, get the content file URL and read it
            let contentURL = try Self.getContentURL(from: fileURL)
            return try String(contentsOf: contentURL, encoding: .utf8)

        case "highland":
            // For .highland files, we need to extract and read before cleanup
            return try getContentFromHighland(fileURL)

        default:
            throw FountainScriptError.unsupportedFileType
        }
    }

    // MARK: - Private Helpers

    private func bodyContent(ofString string: String) -> String {
        var body = string
        body = body.replacingOccurrences(of: "^\\n+", with: "", options: .regularExpression)

        // Find title page by looking for the first blank line
        if let firstBlankLine = body.range(of: "\n\n") {
            let beforeBlankRange = body.startIndex..<body.index(after: firstBlankLine.lowerBound)
            let documentTop = String(body[beforeBlankRange]) + "\n"

            // Check if this is a title page using a simple pattern
            // Title pages have key:value pairs
            let titlePagePattern = "^[^\\t\\s][^:]+:\\s*"
            if let regex = try? NSRegularExpression(pattern: titlePagePattern, options: []) {
                let nsDocumentTop = documentTop as NSString
                if regex.firstMatch(in: documentTop, options: [], range: NSRange(location: 0, length: nsDocumentTop.length)) != nil {
                    body.removeSubrange(beforeBlankRange)
                }
            }
        }

        return body.trimmingCharacters(in: .newlines)
    }

    private func getContentUrlFromHighland(_ highlandURL: URL) throws -> URL {
        let fileManager = FileManager.default

        // Check if this is actually a plain Fountain file with .highland extension
        let fileHandle = try FileHandle(forReadingFrom: highlandURL)
        defer { try? fileHandle.close() }

        let headerData = fileHandle.readData(ofLength: 4)
        let isZipFile = headerData.count >= 2 && headerData[0] == 0x50 && headerData[1] == 0x4B  // "PK" signature

        if !isZipFile {
            // This is a plain text Fountain file with .highland extension
            return highlandURL
        }

        // Create a temporary directory to extract the highland file
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Extract the highland (zip) file
        try fileManager.unzipItem(at: highlandURL, to: tempDir)

        // Find the .textbundle directory inside
        let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        guard let textBundleURL = contents.first(where: { $0.pathExtension == "textbundle" }) else {
            throw HighlandError.noTextBundleFound
        }

        // Use the shared getContentURL logic to find .fountain or .md files
        return try Self.getContentURL(from: textBundleURL)
    }

    private func getContentFromHighland(_ highlandURL: URL) throws -> String {
        let fileManager = FileManager.default

        // Check if this is actually a plain Fountain file with .highland extension
        let fileHandle = try FileHandle(forReadingFrom: highlandURL)
        defer { try? fileHandle.close() }

        let headerData = fileHandle.readData(ofLength: 4)
        let isZipFile = headerData.count >= 2 && headerData[0] == 0x50 && headerData[1] == 0x4B  // "PK" signature

        if !isZipFile {
            // This is a plain text Fountain file with .highland extension
            return try String(contentsOf: highlandURL, encoding: .utf8)
        }

        // Create a temporary directory to extract the highland file
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Extract the highland (zip) file
        try fileManager.unzipItem(at: highlandURL, to: tempDir)

        // Find the .textbundle directory inside
        let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        guard let textBundleURL = contents.first(where: { $0.pathExtension == "textbundle" }) else {
            throw HighlandError.noTextBundleFound
        }

        // Use the shared getContentURL logic to find .fountain or .md files
        let contentURL = try Self.getContentURL(from: textBundleURL)

        // Read the content before the temp directory is cleaned up
        return try String(contentsOf: contentURL, encoding: .utf8)
    }
}

extension GuionParsedElementCollection: Sendable {}

extension GuionParsedElementCollection: CustomStringConvertible {
    public var description: String {
        return FountainWriter.document(from: self)
    }
}

// MARK: - Deprecated Type Alias

/// Deprecated: Use `GuionParsedElementCollection` instead.
///
/// This type alias provides backward compatibility for code using the old name.
/// New code should use `GuionParsedElementCollection` directly.
///
/// ## Migration
///
/// ```swift
/// // Old (deprecated):
/// let screenplay: GuionParsedScreenplay = try await GuionParsedScreenplay(string: text)
///
/// // New (recommended):
/// let screenplay: GuionParsedElementCollection = try await GuionParsedElementCollection(string: text)
/// ```
@available(*, deprecated, renamed: "GuionParsedElementCollection", message: "Use GuionParsedElementCollection instead. GuionParsedScreenplay is deprecated.")
public typealias GuionParsedScreenplay = GuionParsedElementCollection

// MARK: - Custom Pages Helpers

extension GuionParsedElementCollection {
    /// Load custom pages from a sidecar JSON file
    ///
    /// Searches for custom pages JSON in the following order:
    /// 1. `{basename}-custom-pages.json` (document-specific)
    /// 2. `custom-pages.json` (shared)
    ///
    /// For example, for `script.fountain`:
    /// - First tries: `script-custom-pages.json`
    /// - Then tries: `custom-pages.json`
    ///
    /// - Parameter url: URL to the screenplay file
    /// - Returns: Array of CustomPageContainer objects
    static func loadCustomPagesForFile(url: URL) -> [CustomPageContainer] {
        // DISABLED: Sidecar JSON file loading is temporarily disabled
        // Will be re-implemented with a different approach
        return []

        /* DISABLED CODE:
        let directory = url.deletingLastPathComponent()
        let basename = url.deletingPathExtension().lastPathComponent

        // Try document-specific file first
        let specificURL = directory.appendingPathComponent("\(basename)-custom-pages.json")
        #if DEBUG
        print("🔍 Looking for custom pages at: \(specificURL.path(percentEncoded: false))")
        #endif
        if let pages = tryLoadCustomPagesJSON(from: specificURL) {
            return pages
        }

        // Fall back to shared file
        let sharedURL = directory.appendingPathComponent("custom-pages.json")
        #if DEBUG
        print("🔍 Looking for shared custom pages at: \(sharedURL.path(percentEncoded: false))")
        #endif
        if let pages = tryLoadCustomPagesJSON(from: sharedURL) {
            return pages
        }

        return []
        */
    }

    /// Try to load custom pages from a JSON file
    private static func tryLoadCustomPagesJSON(from url: URL) -> [CustomPageContainer]? {
        // Use path(percentEncoded:) for better compatibility
        let filePath = url.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: filePath) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            let containers = try jsonArray.compactMap { try CustomPageContainer(from: $0) }
            return containers.isEmpty ? nil : containers
        } catch {
            // Log error for debugging - this should be visible in CI logs
            print("⚠️ CustomPages load error for \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    /// Write custom pages to a sidecar JSON file
    ///
    /// Writes to `{basename}-custom-pages.json` in the same directory as the screenplay file.
    ///
    /// - Parameters:
    ///   - url: URL to the screenplay file (e.g., `script.fountain`)
    func writeCustomPagesSidecar(for url: URL) throws {
        // DISABLED: Sidecar JSON file writing is temporarily disabled
        // Will be re-implemented with a different approach
        return

        /* DISABLED CODE:
        guard !customPages.isEmpty else { return }

        let directory = url.deletingLastPathComponent()
        let basename = url.deletingPathExtension().lastPathComponent
        let sidecarURL = directory.appendingPathComponent("\(basename)-custom-pages.json")

        let jsonArray = try customPages.map { try $0.toDictionary() }
        let jsonData = try JSONSerialization.data(withJSONObject: jsonArray, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: sidecarURL)
        */
    }
}

// MARK: - Error Types

public enum FountainScriptError: Error {
    case unsupportedFileType
    case noContentToParse
}
