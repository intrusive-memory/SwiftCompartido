//
//  FountainScript+TextBundle.swift
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
import TextBundle

extension GuionParsedScreenplay {


    /// Initialize GuionParsedScreenplay from a TextBundle file URL
    /// - Parameters:
    ///   - textBundle: URL to the .textbundle or .textpack file
    ///   - parser: The parser type to use (default: .fast)
    /// - Throws: FountainTextBundleError or TextBundle errors
    public convenience init(textBundle url: URL, parser: ParserType = .fast) throws {
        let contentURL = try Self.getContentURL(from: url)
        try self.init(file: contentURL.path, parser: parser)
    }

    /// Get the content file URL from a TextBundle
    /// Looks for .fountain or .md files in the bundle's root directory
    /// - Parameter bundleURL: URL to the .textbundle or .textpack file
    /// - Returns: URL to the content file (.fountain or .md)
    /// - Throws: FountainTextBundleError if no valid content file is found
    internal static func getContentURL(from bundleURL: URL) throws -> URL {
        let fileManager = FileManager.default

        let contents = try fileManager.contentsOfDirectory(
            at: bundleURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )

        // First, try to find a .fountain file
        for fileURL in contents {
            if fileURL.pathExtension.lowercased() == "fountain" {
                return fileURL
            }
        }

        // If no .fountain file, look for .md files
        for fileURL in contents {
            if fileURL.pathExtension.lowercased() == "md" {
                return fileURL
            }
        }

        throw FountainTextBundleError.noContentFileFound
    }

    /// Write the current GuionParsedScreenplay to a TextBundle
    /// - Parameters:
    ///   - destinationURL: The URL where the TextBundle should be created
    ///   - fountainFilename: Optional custom filename for the .fountain file (default: uses script's filename or "script.fountain")
    /// - Returns: The URL of the created TextBundle
    /// - Throws: Writing errors
    @discardableResult
    public func writeToTextBundle(destinationURL: URL, fountainFilename: String? = nil) throws -> URL {
        let fountainContent = FountainWriter.document(from: self)
        let name = fountainFilename ?? filename ?? "script.fountain"
        let bundleName = name.replacingOccurrences(of: ".fountain", with: "")

        // Create the TextBundle with the fountain content as text
        let textBundle = TextBundle(name: bundleName, contents: fountainContent, assetURLs: nil)

        var bundleURL: URL?
        try textBundle.bundle(destinationURL: destinationURL) { url in
            bundleURL = url
        }

        guard let finalURL = bundleURL else {
            throw FountainTextBundleError.failedToCreateBundle
        }

        // Rename text.markdown to .fountain file
        let fileManager = FileManager.default
        let textMarkdownURL = finalURL.appendingPathComponent("text.markdown")
        let fountainURL = finalURL.appendingPathComponent(name)

        if fileManager.fileExists(atPath: textMarkdownURL.path) {
            try fileManager.moveItem(at: textMarkdownURL, to: fountainURL)
        }

        return finalURL
    }

    /// Write the current GuionParsedScreenplay to a TextBundle with resources (characters.json, outline.json)
    /// - Parameters:
    ///   - destinationURL: The URL where the TextBundle should be created
    ///   - name: The base name for the TextBundle (without extension)
    ///   - includeResources: Whether to include characters.json and outline.json in resources folder
    /// - Returns: The URL of the created TextBundle
    /// - Throws: Writing errors
    @discardableResult
    public func writeToTextBundleWithResources(
        destinationURL: URL,
        name: String,
        includeResources: Bool = true
    ) throws -> URL {
        return try createTextBundleWithResources(
            destinationURL: destinationURL,
            name: name,
            includeResources: includeResources
        )
    }

    /// Internal helper to create a TextBundle with resources
    internal func createTextBundleWithResources(
        destinationURL: URL,
        name: String,
        includeResources: Bool
    ) throws -> URL {
        let fileManager = FileManager.default

        // First create the basic textbundle
        let bundleDirectoryName = "\(name).textbundle"
        let existingBundleURL = destinationURL.appendingPathComponent(bundleDirectoryName)
        if fileManager.fileExists(atPath: existingBundleURL.path) {
            try fileManager.removeItem(at: existingBundleURL)
        }

        let textBundleURL = try writeToTextBundle(
            destinationURL: destinationURL,
            fountainFilename: "\(name).fountain"
        )

        // Add resources if requested
        if includeResources {
            let resourcesDir = textBundleURL.appendingPathComponent("resources")

            // Create resources directory if it doesn't exist
            if !fileManager.fileExists(atPath: resourcesDir.path) {
                try fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
            }

            // Write characters.json
            let charactersURL = resourcesDir.appendingPathComponent("characters.json")
            try writeCharactersJSON(to: charactersURL)

            // Write outline.json
            let outlineURL = resourcesDir.appendingPathComponent("outline.json")
            try writeOutlineJSON(to: outlineURL)
        }

        return textBundleURL
    }
}

// MARK: - Error Types

public enum FountainTextBundleError: Error {
    case noFountainFileFound
    case noContentFileFound
    case cannotEnumerateBundle
    case failedToCreateBundle
}
