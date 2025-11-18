//
//  ProjectFrontMatter.swift
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

/// Metadata extracted from PROJECT.md front matter.
///
/// PROJECT.md files use YAML front matter to store project metadata. This struct
/// provides a strongly-typed representation of that metadata.
///
/// ## Example PROJECT.md
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
/// Additional production notes go here...
/// ```
///
/// ## Usage
///
/// ```swift
/// let parser = ProjectMarkdownParser()
/// let (frontMatter, body) = try parser.parse(fileURL: projectMDURL)
///
/// print("Project: \(frontMatter.title)")
/// print("Author: \(frontMatter.author)")
/// ```
///
public struct ProjectFrontMatter: Codable, Sendable, Equatable {
    /// Type identifier - must be "project"
    public let type: String

    /// Project title (required)
    public let title: String

    /// Project author (required)
    public let author: String

    /// Creation date (required)
    public let created: Date

    /// Optional project description
    public let description: String?

    /// Optional season number
    public let season: Int?

    /// Optional episode count
    public let episodes: Int?

    /// Optional genre
    public let genre: String?

    /// Optional tags
    public let tags: [String]?

    /// Create a new ProjectFrontMatter instance.
    ///
    /// - Parameters:
    ///   - type: Type identifier (should always be "project")
    ///   - title: Project title
    ///   - author: Project author
    ///   - created: Creation date
    ///   - description: Optional project description
    ///   - season: Optional season number
    ///   - episodes: Optional episode count
    ///   - genre: Optional genre
    ///   - tags: Optional tags
    public init(
        type: String = "project",
        title: String,
        author: String,
        created: Date = Date(),
        description: String? = nil,
        season: Int? = nil,
        episodes: Int? = nil,
        genre: String? = nil,
        tags: [String]? = nil
    ) {
        self.type = type
        self.title = title
        self.author = author
        self.created = created
        self.description = description
        self.season = season
        self.episodes = episodes
        self.genre = genre
        self.tags = tags
    }
}

// MARK: - Validation

public extension ProjectFrontMatter {
    /// Validate that this front matter represents a valid project.
    ///
    /// - Returns: `true` if type is "project" and required fields are present
    var isValid: Bool {
        return type.lowercased() == "project"
            && !title.isEmpty
            && !author.isEmpty
    }
}
