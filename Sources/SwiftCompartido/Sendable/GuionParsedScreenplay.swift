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

public enum ParserType {
    case fast
    case regex
}

public final class GuionParsedScreenplay {
    public let filename: String?
    public let elements: [GuionElement]
    public let titlePage: [[String: [String]]]
    public let suppressSceneNumbers: Bool

    /// Initialize with parsed screenplay data
    /// - Parameters:
    ///   - filename: Optional filename for the screenplay
    ///   - elements: Array of GuionElements
    ///   - titlePage: Title page metadata
    ///   - suppressSceneNumbers: Whether to suppress scene numbers
    public init(
        filename: String? = nil,
        elements: [GuionElement] = [],
        titlePage: [[String: [String]]] = [],
        suppressSceneNumbers: Bool = false
    ) {
        self.filename = filename
        self.elements = elements
        self.titlePage = titlePage
        self.suppressSceneNumbers = suppressSceneNumbers
    }

    /// Convenience initializer that parses from a file
    /// - Parameters:
    ///   - path: File path to parse
    ///   - parser: Parser type to use (default: .fast)
    public convenience init(file path: String, parser: ParserType = .fast) throws {
        let filename = URL(fileURLWithPath: path).lastPathComponent

        switch parser {
        case .fast, .regex:
            let fountainParser = try FountainParser(file: path)
            self.init(
                filename: filename,
                elements: fountainParser.elements,
                titlePage: fountainParser.titlePage
            )
        }
    }

    /// Convenience initializer that parses from a string
    /// - Parameters:
    ///   - string: Fountain screenplay text
    ///   - parser: Parser type to use (default: .fast)
    public convenience init(string: String, parser: ParserType = .fast) throws {
        switch parser {
        case .fast, .regex:
            let fountainParser = FountainParser(string: string)
            self.init(
                filename: nil,
                elements: fountainParser.elements,
                titlePage: fountainParser.titlePage
            )
        }
    }

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
    }

    public func write(to url: URL) throws {
        let document = FountainWriter.document(from: self)
        try document.write(to: url, atomically: true, encoding: .utf8)
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

extension GuionParsedScreenplay: Sendable {}

extension GuionParsedScreenplay: CustomStringConvertible {
    public var description: String {
        return FountainWriter.document(from: self)
    }
}

// MARK: - Error Types

public enum FountainScriptError: Error {
    case unsupportedFileType
    case noContentToParse
}
