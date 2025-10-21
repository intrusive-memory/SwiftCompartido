//
//  FountainScript+Highland.swift
//  SwiftFountain
//
//  Copyright (c) 2025
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

extension GuionParsedElementCollection {

    /// Initialize GuionParsedElementCollection from a Highland file (.highland)
    /// Highland files are ZIP archives containing a TextBundle
    /// - Parameters:
    ///   - highland: URL to the .highland file
    ///   - parser: The parser type to use (default: .fast)
    /// - Throws: Highland import errors
    public convenience init(highland url: URL, parser: ParserType = .fast) throws {
        let fileManager = FileManager.default

        // First, check if this is actually a plain Fountain file with .highland extension
        // by reading the first few bytes to see if it's a ZIP archive
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }

        let headerData = fileHandle.readData(ofLength: 4)
        let isZipFile = headerData.count >= 2 && headerData[0] == 0x50 && headerData[1] == 0x4B  // "PK" signature

        if !isZipFile {
            // This is a plain text Fountain file with .highland extension
            // Treat it as a regular Fountain file
            try self.init(file: url.path, parser: parser)
            return
        }

        // Create a temporary directory to extract the highland file
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Extract the highland (zip) file
        try fileManager.unzipItem(at: url, to: tempDir)

        // Find the .textbundle directory inside
        let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        guard let textBundleURL = contents.first(where: { $0.pathExtension == "textbundle" }) else {
            throw HighlandError.noTextBundleFound
        }

        // Use the shared getContentURL logic to find .fountain or .md files
        let contentURL = try GuionParsedElementCollection.getContentURL(from: textBundleURL)

        // Parse the content
        try self.init(file: contentURL.path, parser: parser)
    }

    /// Write the current GuionParsedElementCollection to a Highland file (.highland)
    /// Highland files are ZIP archives containing a TextBundle with resources
    /// - Parameters:
    ///   - destinationURL: The directory where the Highland file should be created
    ///   - name: The base name for the Highland file (without extension)
    ///   - includeResources: Whether to include characters.json and outline.json in resources
    /// - Returns: The URL of the created Highland file
    /// - Throws: Writing errors
    @discardableResult
    public func writeToHighland(
        destinationURL: URL,
        name: String,
        includeResources: Bool = true
    ) throws -> URL {
        let fileManager = FileManager.default

        // Create a temporary directory for the textbundle
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Create the textbundle with resources
        let textBundleURL = try createTextBundleWithResources(
            destinationURL: tempDir,
            name: name,
            includeResources: includeResources
        )

        // Create the highland (zip) file
        let highlandFileName = "\(name).highland"
        let highlandURL = destinationURL.appendingPathComponent(highlandFileName)

        // Remove existing file if present
        try? fileManager.removeItem(at: highlandURL)

        // Zip the textbundle into a .highland file
        try fileManager.zipItem(at: textBundleURL, to: highlandURL)

        return highlandURL
    }
}

// MARK: - Error Types

public enum HighlandError: Error {
    case noTextBundleFound
    case extractionFailed
}
