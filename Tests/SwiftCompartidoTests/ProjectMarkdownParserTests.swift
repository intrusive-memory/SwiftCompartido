//
//  ProjectMarkdownParserTests.swift
//  SwiftCompartidoTests
//
//  Copyright (c) 2025
//

import XCTest
@testable import SwiftCompartido

final class ProjectMarkdownParserTests: XCTestCase {

    var parser: ProjectMarkdownParser!

    override func setUp() {
        super.setUp()
        parser = ProjectMarkdownParser()
    }

    // MARK: - Parsing Tests

    func testParseValidProjectMD() throws {
        let markdown = """
        ---
        type: project
        title: My Series
        author: Jane Showrunner
        created: 2025-11-17T10:30:00Z
        description: A multi-episode series
        season: 1
        episodes: 12
        genre: Science Fiction
        tags: [sci-fi, drama]
        ---

        # Project Notes

        This is a test project with production notes.
        """

        let (frontMatter, body) = try parser.parse(markdown: markdown)

        XCTAssertEqual(frontMatter.type, "project")
        XCTAssertEqual(frontMatter.title, "My Series")
        XCTAssertEqual(frontMatter.author, "Jane Showrunner")
        XCTAssertEqual(frontMatter.description, "A multi-episode series")
        XCTAssertEqual(frontMatter.season, 1)
        XCTAssertEqual(frontMatter.episodes, 12)
        XCTAssertEqual(frontMatter.genre, "Science Fiction")
        XCTAssertEqual(frontMatter.tags, ["sci-fi", "drama"])
        XCTAssertTrue(frontMatter.isValid)

        // Check body
        XCTAssertTrue(body.contains("Project Notes"))
        XCTAssertTrue(body.contains("production notes"))
    }

    func testParseMinimalProjectMD() throws {
        let markdown = """
        ---
        type: project
        title: Simple Project
        author: John Doe
        created: 2025-11-17T10:00:00Z
        ---

        # Notes

        Minimal project file.
        """

        let (frontMatter, body) = try parser.parse(markdown: markdown)

        XCTAssertEqual(frontMatter.type, "project")
        XCTAssertEqual(frontMatter.title, "Simple Project")
        XCTAssertEqual(frontMatter.author, "John Doe")
        XCTAssertNil(frontMatter.description)
        XCTAssertNil(frontMatter.season)
        XCTAssertNil(frontMatter.episodes)
        XCTAssertNil(frontMatter.genre)
        XCTAssertNil(frontMatter.tags)
        XCTAssertTrue(frontMatter.isValid)
    }

    func testParseMissingType() {
        let markdown = """
        ---
        title: My Project
        author: John Doe
        created: 2025-11-17T10:00:00Z
        ---

        # Notes
        """

        XCTAssertThrowsError(try parser.parse(markdown: markdown)) { error in
            guard case ProjectMarkdownParser.ProjectMarkdownError.invalidType = error else {
                XCTFail("Expected invalidType error, got \(error)")
                return
            }
        }
    }

    func testParseInvalidType() {
        let markdown = """
        ---
        type: screenplay
        title: My Project
        author: John Doe
        created: 2025-11-17T10:00:00Z
        ---

        # Notes
        """

        XCTAssertThrowsError(try parser.parse(markdown: markdown)) { error in
            guard case ProjectMarkdownParser.ProjectMarkdownError.invalidType(let type) = error else {
                XCTFail("Expected invalidType error, got \(error)")
                return
            }
            XCTAssertEqual(type, "screenplay")
        }
    }

    func testParseMissingTitle() {
        let markdown = """
        ---
        type: project
        author: John Doe
        created: 2025-11-17T10:00:00Z
        ---

        # Notes
        """

        XCTAssertThrowsError(try parser.parse(markdown: markdown)) { error in
            guard case ProjectMarkdownParser.ProjectMarkdownError.missingRequiredField(let field) = error else {
                XCTFail("Expected missingRequiredField error, got \(error)")
                return
            }
            XCTAssertEqual(field, "title")
        }
    }

    func testParseMissingAuthor() {
        let markdown = """
        ---
        type: project
        title: My Project
        created: 2025-11-17T10:00:00Z
        ---

        # Notes
        """

        XCTAssertThrowsError(try parser.parse(markdown: markdown)) { error in
            guard case ProjectMarkdownParser.ProjectMarkdownError.missingRequiredField(let field) = error else {
                XCTFail("Expected missingRequiredField error, got \(error)")
                return
            }
            XCTAssertEqual(field, "author")
        }
    }

    func testParseInvalidDateFormat() {
        let markdown = """
        ---
        type: project
        title: My Project
        author: John Doe
        created: not-a-date
        ---

        # Notes
        """

        XCTAssertThrowsError(try parser.parse(markdown: markdown)) { error in
            guard case ProjectMarkdownParser.ProjectMarkdownError.invalidDateFormat = error else {
                XCTFail("Expected invalidDateFormat error, got \(error)")
                return
            }
        }
    }

    func testParseNoFrontMatter() {
        let markdown = """
        # Project Notes

        This file has no front matter.
        """

        XCTAssertThrowsError(try parser.parse(markdown: markdown)) { error in
            guard case ProjectMarkdownParser.ProjectMarkdownError.invalidType = error else {
                XCTFail("Expected invalidType error, got \(error)")
                return
            }
        }
    }

    // MARK: - Generation Tests

    func testGenerateProjectMD() {
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: "2025-11-17T10:30:00Z")!

        let frontMatter = ProjectFrontMatter(
            title: "Test Project",
            author: "Test Author",
            created: date,
            description: "A test project",
            season: 2,
            episodes: 10,
            genre: "Drama",
            tags: ["test", "example"]
        )

        let body = "# Project Notes\n\nTest project body content."
        let generated = parser.generate(frontMatter: frontMatter, body: body)

        // Verify structure
        XCTAssertTrue(generated.hasPrefix("---\n"))
        XCTAssertTrue(generated.contains("type: project"))
        XCTAssertTrue(generated.contains("title: Test Project"))
        XCTAssertTrue(generated.contains("author: Test Author"))
        XCTAssertTrue(generated.contains("created: 2025-11-17T10:30:00Z"))
        XCTAssertTrue(generated.contains("description: A test project"))
        XCTAssertTrue(generated.contains("season: 2"))
        XCTAssertTrue(generated.contains("episodes: 10"))
        XCTAssertTrue(generated.contains("genre: Drama"))
        XCTAssertTrue(generated.contains("tags: [test, example]"))
        XCTAssertTrue(generated.contains("# Project Notes"))
        XCTAssertTrue(generated.contains("Test project body content"))
    }

    func testGenerateMinimalProjectMD() {
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: "2025-11-17T10:00:00Z")!

        let frontMatter = ProjectFrontMatter(
            title: "Minimal Project",
            author: "John Doe",
            created: date
        )

        let body = "# Notes\n\nMinimal content."
        let generated = parser.generate(frontMatter: frontMatter, body: body)

        // Verify required fields
        XCTAssertTrue(generated.contains("type: project"))
        XCTAssertTrue(generated.contains("title: Minimal Project"))
        XCTAssertTrue(generated.contains("author: John Doe"))
        XCTAssertTrue(generated.contains("created: 2025-11-17T10:00:00Z"))

        // Verify optional fields are NOT present
        XCTAssertFalse(generated.contains("description:"))
        XCTAssertFalse(generated.contains("season:"))
        XCTAssertFalse(generated.contains("episodes:"))
        XCTAssertFalse(generated.contains("genre:"))
        XCTAssertFalse(generated.contains("tags:"))
    }

    func testRoundTrip() throws {
        let original = """
        ---
        type: project
        title: Roundtrip Test
        author: Test User
        created: 2025-11-17T12:00:00Z
        description: Testing roundtrip
        season: 3
        episodes: 8
        genre: Comedy
        tags: [test, roundtrip]
        ---

        # Test Notes

        This is a roundtrip test.
        """

        // Parse
        let (frontMatter, body) = try parser.parse(markdown: original)

        // Generate
        let generated = parser.generate(frontMatter: frontMatter, body: body)

        // Parse again
        let (frontMatter2, body2) = try parser.parse(markdown: generated)

        // Verify equality
        XCTAssertEqual(frontMatter.type, frontMatter2.type)
        XCTAssertEqual(frontMatter.title, frontMatter2.title)
        XCTAssertEqual(frontMatter.author, frontMatter2.author)
        XCTAssertEqual(frontMatter.created.timeIntervalSince1970,
                       frontMatter2.created.timeIntervalSince1970,
                       accuracy: 1.0)
        XCTAssertEqual(frontMatter.description, frontMatter2.description)
        XCTAssertEqual(frontMatter.season, frontMatter2.season)
        XCTAssertEqual(frontMatter.episodes, frontMatter2.episodes)
        XCTAssertEqual(frontMatter.genre, frontMatter2.genre)
        XCTAssertEqual(frontMatter.tags, frontMatter2.tags)
    }

    // MARK: - Validation Tests

    func testIsValid() {
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: "2025-11-17T10:00:00Z")!

        // Valid project
        let valid = ProjectFrontMatter(
            title: "Valid Project",
            author: "Author",
            created: date
        )
        XCTAssertTrue(valid.isValid)

        // Invalid type
        let invalidType = ProjectFrontMatter(
            type: "screenplay",
            title: "Invalid",
            author: "Author",
            created: date
        )
        XCTAssertFalse(invalidType.isValid)

        // Empty title
        let emptyTitle = ProjectFrontMatter(
            title: "",
            author: "Author",
            created: date
        )
        XCTAssertFalse(emptyTitle.isValid)

        // Empty author
        let emptyAuthor = ProjectFrontMatter(
            title: "Title",
            author: "",
            created: date
        )
        XCTAssertFalse(emptyAuthor.isValid)
    }
}
