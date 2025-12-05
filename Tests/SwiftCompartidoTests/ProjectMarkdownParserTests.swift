//
//  ProjectMarkdownParserTests.swift
//  SwiftCompartidoTests
//
//  Copyright (c) 2025
//

import Foundation
import Testing
@testable import SwiftCompartido

struct ProjectMarkdownParserTests {

    let parser = ProjectMarkdownParser()

    // MARK: - Parsing Tests

    @Test func testParseValidProjectMD() throws {
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

        #expect(frontMatter.type == "project")
        #expect(frontMatter.title == "My Series")
        #expect(frontMatter.author == "Jane Showrunner")
        #expect(frontMatter.description == "A multi-episode series")
        #expect(frontMatter.season == 1)
        #expect(frontMatter.episodes == 12)
        #expect(frontMatter.genre == "Science Fiction")
        #expect(frontMatter.tags == ["sci-fi", "drama"])
        #expect(frontMatter.isValid)

        // Check body
        #expect(body.contains("Project Notes"))
        #expect(body.contains("production notes"))
    }

    @Test func testParseMinimalProjectMD() throws {
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

        #expect(frontMatter.type == "project")
        #expect(frontMatter.title == "Simple Project")
        #expect(frontMatter.author == "John Doe")
        #expect(frontMatter.description == nil)
        #expect(frontMatter.season == nil)
        #expect(frontMatter.episodes == nil)
        #expect(frontMatter.genre == nil)
        #expect(frontMatter.tags == nil)
        #expect(frontMatter.isValid)
    }

    @Test func testParseMissingType() {
        let markdown = """
        ---
        title: My Project
        author: John Doe
        created: 2025-11-17T10:00:00Z
        ---

        # Notes
        """

        do { _ = try parser.parse(markdown: markdown); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testParseInvalidType() {
        let markdown = """
        ---
        type: screenplay
        title: My Project
        author: John Doe
        created: 2025-11-17T10:00:00Z
        ---

        # Notes
        """

        do { _ = try parser.parse(markdown: markdown); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testParseMissingTitle() {
        let markdown = """
        ---
        type: project
        author: John Doe
        created: 2025-11-17T10:00:00Z
        ---

        # Notes
        """

        do { _ = try parser.parse(markdown: markdown); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testParseMissingAuthor() {
        let markdown = """
        ---
        type: project
        title: My Project
        created: 2025-11-17T10:00:00Z
        ---

        # Notes
        """

        do { _ = try parser.parse(markdown: markdown); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testParseInvalidDateFormat() {
        let markdown = """
        ---
        type: project
        title: My Project
        author: John Doe
        created: not-a-date
        ---

        # Notes
        """

        do { _ = try parser.parse(markdown: markdown); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testParseNoFrontMatter() {
        let markdown = """
        # Project Notes

        This file has no front matter.
        """

        do { _ = try parser.parse(markdown: markdown); Issue.record("Expected error") } catch { /* Expected */ }
    }

    // MARK: - Generation Tests

    @Test func testGenerateProjectMD() {
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
        #expect(generated.hasPrefix("---\n"))
        #expect(generated.contains("type: project"))
        #expect(generated.contains("title: Test Project"))
        #expect(generated.contains("author: Test Author"))
        #expect(generated.contains("created: 2025-11-17T10:30:00Z"))
        #expect(generated.contains("description: A test project"))
        #expect(generated.contains("season: 2"))
        #expect(generated.contains("episodes: 10"))
        #expect(generated.contains("genre: Drama"))
        #expect(generated.contains("tags: [test, example]"))
        #expect(generated.contains("# Project Notes"))
        #expect(generated.contains("Test project body content"))
    }

    @Test func testGenerateMinimalProjectMD() {
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
        #expect(generated.contains("type: project"))
        #expect(generated.contains("title: Minimal Project"))
        #expect(generated.contains("author: John Doe"))
        #expect(generated.contains("created: 2025-11-17T10:00:00Z"))

        // Verify optional fields are NOT present
        #expect(!generated.contains("description:"))
        #expect(!generated.contains("season:"))
        #expect(!generated.contains("episodes:"))
        #expect(!generated.contains("genre:"))
        #expect(!generated.contains("tags:"))
    }

    @Test func testRoundTrip() throws {
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
        #expect(frontMatter.type == frontMatter2.type)
        #expect(frontMatter.title == frontMatter2.title)
        #expect(frontMatter.author == frontMatter2.author)
        #expect(abs(frontMatter.created.timeIntervalSince1970 - frontMatter2.created.timeIntervalSince1970) < 1.0)
        #expect(frontMatter.description == frontMatter2.description)
        #expect(frontMatter.season == frontMatter2.season)
        #expect(frontMatter.episodes == frontMatter2.episodes)
        #expect(frontMatter.genre == frontMatter2.genre)
        #expect(frontMatter.tags == frontMatter2.tags)
    }

    // MARK: - Validation Tests

    @Test func testIsValid() {
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: "2025-11-17T10:00:00Z")!

        // Valid project
        let valid = ProjectFrontMatter(
            title: "Valid Project",
            author: "Author",
            created: date
        )
        #expect(valid.isValid)

        // Invalid type
        let invalidType = ProjectFrontMatter(
            type: "screenplay",
            title: "Invalid",
            author: "Author",
            created: date
        )
        #expect(!invalidType.isValid)

        // Empty title
        let emptyTitle = ProjectFrontMatter(
            title: "",
            author: "Author",
            created: date
        )
        #expect(!emptyTitle.isValid)

        // Empty author
        let emptyAuthor = ProjectFrontMatter(
            title: "Title",
            author: "",
            created: date
        )
        #expect(!emptyAuthor.isValid)
    }
}
