//
//  ProjectMarkdownParser.swift
//  SwiftCompartido
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

/// Parser for PROJECT.md files with YAML front matter.
///
/// ProjectMarkdownParser extracts structured metadata from PROJECT.md files,
/// which serve as manifests for screenplay projects. It leverages the existing
/// MarkdownParser YAML front matter support.
///
/// ## PROJECT.md Format
///
/// ```markdown
/// ---
/// type: project
/// title: My Series
/// author: Jane Showrunner
/// created: 2025-11-17T10:30:00Z
/// description: A multi-episode series
/// season: 1
/// episodes: 12
/// genre: Science Fiction
/// tags: [sci-fi, drama]
/// ---
///
/// # Project Notes
///
/// Production notes and information go here...
/// ```
///
/// ## Usage
///
/// ```swift
/// let parser = ProjectMarkdownParser()
/// let (frontMatter, body) = try parser.parse(fileURL: url)
///
/// guard frontMatter.isValid else {
///     throw ProjectMarkdownError.invalidFrontMatter
/// }
///
/// print("Project: \(frontMatter.title)")
/// print("Notes: \(body)")
/// ```
///
public struct ProjectMarkdownParser {

    /// Errors that can occur during PROJECT.md parsing
    public enum ProjectMarkdownError: LocalizedError {
        case fileNotFound
        case invalidFrontMatter
        case missingRequiredField(String)
        case invalidDateFormat
        case invalidType(String)

        public var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "PROJECT.md file not found"
            case .invalidFrontMatter:
                return "Invalid or missing YAML front matter in PROJECT.md"
            case .missingRequiredField(let field):
                return "Missing required field: \(field)"
            case .invalidDateFormat:
                return "Invalid date format in 'created' field (expected ISO 8601)"
            case .invalidType(let type):
                return "Invalid type '\(type)' (expected 'project')"
            }
        }
    }

    /// Create a new ProjectMarkdownParser instance
    public init() {}

    /// Parse a PROJECT.md file from a URL.
    ///
    /// - Parameter fileURL: URL to the PROJECT.md file
    /// - Returns: Tuple containing:
    ///   - frontMatter: Structured project metadata
    ///   - body: Markdown body content (without front matter)
    /// - Throws: `ProjectMarkdownError` if file cannot be read or parsed
    ///
    /// ## Example
    ///
    /// ```swift
    /// let url = URL(fileURLWithPath: "/path/to/PROJECT.md")
    /// let (frontMatter, body) = try parser.parse(fileURL: url)
    /// ```
    public func parse(fileURL: URL) throws -> (frontMatter: ProjectFrontMatter, body: String) {
        // Read file contents
        guard let markdown = try? String(contentsOf: fileURL, encoding: .utf8) else {
            throw ProjectMarkdownError.fileNotFound
        }

        return try parse(markdown: markdown)
    }

    /// Parse PROJECT.md content from a string.
    ///
    /// - Parameter markdown: Markdown content with YAML front matter
    /// - Returns: Tuple containing:
    ///   - frontMatter: Structured project metadata
    ///   - body: Markdown body content (without front matter)
    /// - Throws: `ProjectMarkdownError` if content cannot be parsed
    ///
    /// ## Example
    ///
    /// ```swift
    /// let content = """
    /// ---
    /// type: project
    /// title: My Project
    /// author: John Doe
    /// created: 2025-11-17T10:00:00Z
    /// ---
    ///
    /// # Notes
    /// ...
    /// """
    /// let (frontMatter, body) = try parser.parse(markdown: content)
    /// ```
    public func parse(markdown: String) throws -> (frontMatter: ProjectFrontMatter, body: String) {
        // Use existing MarkdownParser to extract YAML front matter
        let (elements, titlePageData, _) = try MarkdownParser.parse(markdown)

        // Extract body content from elements
        let body = elements.map { $0.elementText }.joined(separator: "\n\n")

        // Convert titlePageData to ProjectFrontMatter
        let frontMatter = try parseFrontMatter(from: titlePageData)

        return (frontMatter, body)
    }

    /// Generate PROJECT.md content from front matter and body.
    ///
    /// - Parameters:
    ///   - frontMatter: Project metadata
    ///   - body: Markdown body content
    /// - Returns: Complete PROJECT.md file content with YAML front matter
    ///
    /// ## Example
    ///
    /// ```swift
    /// let frontMatter = ProjectFrontMatter(
    ///     title: "My Project",
    ///     author: "John Doe"
    /// )
    /// let body = "# Notes\n\nProduction information..."
    /// let content = parser.generate(frontMatter: frontMatter, body: body)
    /// ```
    public func generate(frontMatter: ProjectFrontMatter, body: String) -> String {
        var yaml = "---\n"
        yaml += "type: \(frontMatter.type)\n"
        yaml += "title: \(frontMatter.title)\n"
        yaml += "author: \(frontMatter.author)\n"

        // Format date as ISO 8601
        let dateFormatter = ISO8601DateFormatter()
        yaml += "created: \(dateFormatter.string(from: frontMatter.created))\n"

        // Add optional fields
        if let description = frontMatter.description {
            yaml += "description: \(description)\n"
        }
        if let season = frontMatter.season {
            yaml += "season: \(season)\n"
        }
        if let episodes = frontMatter.episodes {
            yaml += "episodes: \(episodes)\n"
        }
        if let genre = frontMatter.genre {
            yaml += "genre: \(genre)\n"
        }
        if let tags = frontMatter.tags, !tags.isEmpty {
            yaml += "tags: [\(tags.joined(separator: ", "))]\n"
        }

        yaml += "---\n\n"
        yaml += body

        return yaml
    }

    // MARK: - Private Helpers

    /// Parse ProjectFrontMatter from MarkdownParser titlePageData.
    ///
    /// - Parameter titlePageData: Array of dictionaries from MarkdownParser
    /// - Returns: Structured ProjectFrontMatter instance
    /// - Throws: ProjectMarkdownError if required fields are missing or invalid
    private func parseFrontMatter(from titlePageData: [[String: [String]]]) throws -> ProjectFrontMatter {
        // Extract values from titlePageData
        var type: String?
        var title: String?
        var author: String?
        var created: Date?
        var description: String?
        var season: Int?
        var episodes: Int?
        var genre: String?
        var tags: [String]?

        for dict in titlePageData {
            for (key, values) in dict {
                let lowercaseKey = key.lowercased()
                let value = values.first ?? ""

                switch lowercaseKey {
                case "type":
                    type = value
                case "title":
                    title = value
                case "author", "authors":
                    author = value
                case "created":
                    // Parse ISO 8601 date
                    let dateFormatter = ISO8601DateFormatter()
                    created = dateFormatter.date(from: value)
                case "description":
                    description = value
                case "season":
                    season = Int(value)
                case "episodes":
                    episodes = Int(value)
                case "genre":
                    genre = value
                case "tags":
                    // Parse tags (handle both array format and comma-separated)
                    if values.count > 1 {
                        tags = values
                    } else {
                        // Try to parse as comma-separated or bracketed list
                        let cleaned = value
                            .replacingOccurrences(of: "[", with: "")
                            .replacingOccurrences(of: "]", with: "")
                        tags = cleaned.split(separator: ",").map {
                            $0.trimmingCharacters(in: .whitespaces)
                        }
                    }
                default:
                    break
                }
            }
        }

        // Validate required fields
        guard let type = type, type.lowercased() == "project" else {
            throw ProjectMarkdownError.invalidType(type ?? "missing")
        }
        guard let title = title, !title.isEmpty else {
            throw ProjectMarkdownError.missingRequiredField("title")
        }
        guard let author = author, !author.isEmpty else {
            throw ProjectMarkdownError.missingRequiredField("author")
        }
        guard let created = created else {
            throw ProjectMarkdownError.invalidDateFormat
        }

        return ProjectFrontMatter(
            type: type,
            title: title,
            author: author,
            created: created,
            description: description,
            season: season,
            episodes: episodes,
            genre: genre,
            tags: tags
        )
    }
}
