//
//  GitAttributesParser.swift
//  SwiftCompartido
//
//  Parser for .gitattributes files to manage Git LFS tracking.
//  Reads and writes LFS patterns for large file management.
//

import Foundation

/// Parser for `.gitattributes` files used in Git LFS configuration.
///
/// `GitAttributesParser` provides utilities for reading and writing `.gitattributes` files,
/// which specify which file patterns should be tracked with Git Large File Storage (LFS).
///
/// ## Overview
///
/// Git LFS uses `.gitattributes` to mark file patterns for LFS tracking. Each line in the file
/// specifies a pattern and its attributes:
///
/// ```
/// *.mp3 filter=lfs diff=lfs merge=lfs -text
/// *.wav filter=lfs diff=lfs merge=lfs -text
/// ```
///
/// ## Features
///
/// - **Parse existing files**: Extract LFS patterns from `.gitattributes`
/// - **Write new patterns**: Add LFS tracking for file types
/// - **Merge patterns**: Combine existing and new patterns safely
/// - **Comment preservation**: Maintain comments and formatting
/// - **Validation**: Ensure patterns are valid before writing
///
/// ## Example - Read LFS Patterns
///
/// ```swift
/// let parser = GitAttributesParser()
/// let patterns = try parser.parseFile(at: repoURL.appendingPathComponent(".gitattributes"))
///
/// print("LFS-tracked patterns:")
/// for pattern in patterns {
///     print("  \(pattern.pattern) -> \(pattern.attributes)")
/// }
/// ```
///
/// ## Example - Add LFS Tracking
///
/// ```swift
/// let parser = GitAttributesParser()
/// let attributesURL = repoURL.appendingPathComponent(".gitattributes")
///
/// // Add audio files to LFS
/// try parser.addLFSPattern("*.mp3", to: attributesURL)
/// try parser.addLFSPattern("*.wav", to: attributesURL)
/// ```
///
/// ## Example - Write Default LFS Patterns
///
/// ```swift
/// let parser = GitAttributesParser()
/// try parser.writeDefaultLFSPatterns(to: repoURL.appendingPathComponent(".gitattributes"))
/// ```
public final class GitAttributesParser {

    // MARK: - Types

    /// A parsed line from a `.gitattributes` file
    public struct AttributeLine: Sendable, Equatable {
        /// The file pattern (e.g., "*.mp3", "*.wav")
        public let pattern: String

        /// The attributes string (e.g., "filter=lfs diff=lfs merge=lfs -text")
        public let attributes: String

        /// Whether this line represents an LFS-tracked pattern
        public var isLFS: Bool {
            attributes.contains("filter=lfs")
        }

        public init(pattern: String, attributes: String) {
            self.pattern = pattern
            self.attributes = attributes
        }
    }

    /// Errors that can occur during parsing or writing
    public enum ParsingError: LocalizedError, Sendable, Equatable {
        case fileNotFound(path: String)
        case invalidFormat(line: String)
        case writeFailed(reason: String)
        case invalidPattern(pattern: String)

        public var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "File not found: \(path)"
            case .invalidFormat(let line):
                return "Invalid .gitattributes format: \(line)"
            case .writeFailed(let reason):
                return "Failed to write .gitattributes: \(reason)"
            case .invalidPattern(let pattern):
                return "Invalid file pattern: \(pattern)"
            }
        }
    }

    // MARK: - Constants

    /// Standard LFS attributes string
    public static let lfsAttributes = "filter=lfs diff=lfs merge=lfs -text"

    /// Default LFS patterns for multimedia files
    public static let defaultLFSPatterns: [String] = [
        // Audio files
        "*.mp3",
        "*.wav",
        "*.m4a",
        "*.aac",
        "*.flac",
        "*.ogg",

        // Video files
        "*.mp4",
        "*.mov",
        "*.avi",
        "*.mkv",
        "*.webm",

        // Image files
        "*.png",
        "*.jpg",
        "*.jpeg",
        "*.gif",
        "*.bmp",
        "*.tiff",
        "*.webp",

        // PDF files
        "*.pdf"
    ]

    // MARK: - Initialization

    public init() {}

    // MARK: - Parsing

    /// Parse a `.gitattributes` file and extract all attribute lines.
    ///
    /// - Parameter url: URL to the `.gitattributes` file
    /// - Returns: Array of parsed attribute lines
    /// - Throws: `ParsingError` if file cannot be read or parsed
    public func parseFile(at url: URL) throws -> [AttributeLine] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ParsingError.fileNotFound(path: url.path)
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        return try parseContent(content)
    }

    /// Parse `.gitattributes` content from a string.
    ///
    /// - Parameter content: The file content as a string
    /// - Returns: Array of parsed attribute lines
    /// - Throws: `ParsingError` if content is invalid
    public func parseContent(_ content: String) throws -> [AttributeLine] {
        var lines: [AttributeLine] = []

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Split line into pattern and attributes
            let parts = trimmed.components(separatedBy: .whitespaces)
            guard parts.count >= 2 else {
                // Skip invalid lines instead of throwing
                continue
            }

            let pattern = parts[0]
            let attributes = parts[1...].joined(separator: " ")

            lines.append(AttributeLine(pattern: pattern, attributes: attributes))
        }

        return lines
    }

    /// Get only LFS-tracked patterns from a `.gitattributes` file.
    ///
    /// - Parameter url: URL to the `.gitattributes` file
    /// - Returns: Array of LFS patterns (e.g., ["*.mp3", "*.wav"])
    /// - Throws: `ParsingError` if file cannot be read
    public func getLFSPatterns(from url: URL) throws -> [String] {
        let lines = try parseFile(at: url)
        return lines.filter { $0.isLFS }.map { $0.pattern }
    }

    // MARK: - Writing

    /// Write default LFS patterns to a `.gitattributes` file.
    ///
    /// - Parameter url: URL to the `.gitattributes` file
    /// - Throws: `ParsingError` if write fails
    ///
    /// This creates a new `.gitattributes` file with all default multimedia patterns
    /// configured for LFS tracking. If the file exists, it will be overwritten.
    public func writeDefaultLFSPatterns(to url: URL) throws {
        var content = "# Git LFS Configuration\n"
        content.append("# Automatically generated by SwiftCompartido\n\n")

        content.append("# Audio files\n")
        for pattern in Self.defaultLFSPatterns.filter({ $0.contains("mp3") || $0.contains("wav") || $0.contains("m4a") || $0.contains("aac") || $0.contains("flac") || $0.contains("ogg") }) {
            content.append("\(pattern) \(Self.lfsAttributes)\n")
        }

        content.append("\n# Video files\n")
        for pattern in Self.defaultLFSPatterns.filter({ $0.contains("mp4") || $0.contains("mov") || $0.contains("avi") || $0.contains("mkv") || $0.contains("webm") }) {
            content.append("\(pattern) \(Self.lfsAttributes)\n")
        }

        content.append("\n# Image files\n")
        for pattern in Self.defaultLFSPatterns.filter({ $0.contains("png") || $0.contains("jpg") || $0.contains("jpeg") || $0.contains("gif") || $0.contains("bmp") || $0.contains("tiff") || $0.contains("webp") }) {
            content.append("\(pattern) \(Self.lfsAttributes)\n")
        }

        content.append("\n# PDF files\n")
        for pattern in Self.defaultLFSPatterns.filter({ $0.contains("pdf") }) {
            content.append("\(pattern) \(Self.lfsAttributes)\n")
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ParsingError.writeFailed(reason: error.localizedDescription)
        }
    }

    /// Add an LFS pattern to an existing `.gitattributes` file.
    ///
    /// - Parameters:
    ///   - pattern: The file pattern to track (e.g., "*.mp3")
    ///   - url: URL to the `.gitattributes` file
    /// - Throws: `ParsingError` if pattern is invalid or write fails
    ///
    /// If the pattern already exists, this method does nothing.
    /// If the file doesn't exist, it will be created.
    public func addLFSPattern(_ pattern: String, to url: URL) throws {
        // Validate pattern
        guard !pattern.isEmpty else {
            throw ParsingError.invalidPattern(pattern: pattern)
        }

        var existingLines: [AttributeLine] = []

        // Read existing file if it exists
        if FileManager.default.fileExists(atPath: url.path) {
            existingLines = try parseFile(at: url)

            // Check if pattern already exists
            if existingLines.contains(where: { $0.pattern == pattern && $0.isLFS }) {
                return // Pattern already tracked
            }
        }

        // Read full content to preserve comments
        var content = ""
        if FileManager.default.fileExists(atPath: url.path) {
            content = try String(contentsOf: url, encoding: .utf8)
            if !content.hasSuffix("\n") {
                content.append("\n")
            }
        }

        // Add new pattern
        content.append("\(pattern) \(Self.lfsAttributes)\n")

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ParsingError.writeFailed(reason: error.localizedDescription)
        }
    }

    /// Remove an LFS pattern from a `.gitattributes` file.
    ///
    /// - Parameters:
    ///   - pattern: The file pattern to untrack (e.g., "*.mp3")
    ///   - url: URL to the `.gitattributes` file
    /// - Throws: `ParsingError` if write fails
    ///
    /// This removes the line containing the pattern from the file.
    /// Comments and other patterns are preserved.
    public func removeLFSPattern(_ pattern: String, from url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return // Nothing to remove
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        var newLines: [String] = []

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Keep empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                newLines.append(line)
                continue
            }

            // Check if line matches pattern
            if trimmed.hasPrefix(pattern + " ") {
                // Skip this line (remove it)
                continue
            }

            newLines.append(line)
        }

        let newContent = newLines.joined(separator: "\n")

        do {
            try newContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ParsingError.writeFailed(reason: error.localizedDescription)
        }
    }

    /// Check if a specific pattern is tracked in `.gitattributes`.
    ///
    /// - Parameters:
    ///   - pattern: The file pattern to check (e.g., "*.mp3")
    ///   - url: URL to the `.gitattributes` file
    /// - Returns: `true` if pattern is tracked with LFS, `false` otherwise
    public func isPatternTracked(_ pattern: String, in url: URL) throws -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        let lines = try parseFile(at: url)
        return lines.contains(where: { $0.pattern == pattern && $0.isLFS })
    }
}
