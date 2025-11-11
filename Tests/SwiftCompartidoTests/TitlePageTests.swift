//
//  TitlePageTests.swift
//  SwiftCompartidoTests
//
//  Tests for title page functionality including case-insensitive key normalization
//  and the synthetic title property on GuionDocumentModel.
//

import Foundation
import Testing
import SwiftData
@testable import SwiftCompartido

@MainActor
@Suite("Title Page Tests")
struct TitlePageTests {

    // MARK: - Test Case Normalization

    @Test("Title page keys are normalized to uppercase")
    func testKeyNormalization() async throws {
        // Test various case combinations
        let testCases = [
            ("title", "TITLE"),
            ("TITLE", "TITLE"),
            ("Title", "TITLE"),
            ("TiTlE", "TITLE"),
            ("author", "AUTHOR"),
            ("Author", "AUTHOR"),
            ("AUTHOR", "AUTHOR")
        ]

        for (input, expected) in testCases {
            let entry = TitlePageEntryModel(key: input, values: ["Test Value"])
            #expect(entry.key == expected, "Key '\(input)' should be normalized to '\(expected)', got '\(entry.key)'")
        }
    }

    @Test("Multiple values are preserved during normalization")
    func testMultipleValuesPreserved() async throws {
        let values = ["John Doe", "Jane Smith", "Bob Johnson"]
        let entry = TitlePageEntryModel(key: "author", values: values)

        #expect(entry.key == "AUTHOR")
        #expect(entry.values.count == 3)
        #expect(entry.values == values)
    }

    // MARK: - Test Synthetic Title Property

    @Test("Document title property returns title from title page")
    func testDocumentTitleProperty() async throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        let document = GuionDocumentModel(filename: "test.guion")

        // Add title entry with lowercase key
        let titleEntry = TitlePageEntryModel(key: "title", values: ["The Great Screenplay"])
        titleEntry.document = document
        document.titlePage.append(titleEntry)

        modelContext.insert(document)

        #expect(document.title == "The Great Screenplay")
    }

    @Test("Document title property is case-insensitive via normalization")
    func testDocumentTitleCaseInsensitive() async throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        // Test various case combinations
        let testCases = [
            ("title", "Lowercase Title"),
            ("TITLE", "Uppercase Title"),
            ("Title", "Title Case Title"),
            ("TiTlE", "Mixed Case Title")
        ]

        for (keyVariant, expectedTitle) in testCases {
            let document = GuionDocumentModel(filename: "test-\(keyVariant).guion")
            let titleEntry = TitlePageEntryModel(key: keyVariant, values: [expectedTitle])
            titleEntry.document = document
            document.titlePage.append(titleEntry)

            modelContext.insert(document)

            #expect(document.title == expectedTitle, "Title should be '\(expectedTitle)' for key variant '\(keyVariant)'")
        }
    }

    @Test("Document title falls back to filename when no title page entry exists")
    func testDocumentTitleFallsBackToFilename() async throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        let document = GuionDocumentModel(filename: "MyScript.guion")
        modelContext.insert(document)

        // With no title page entry and no level-1 headings, should fall back to filename
        #expect(document.title == "MyScript")
    }

    @Test("Document title falls back to filename when title value is empty")
    func testDocumentTitleFallsBackWhenEmpty() async throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        let document = GuionDocumentModel(filename: "test.guion")
        let titleEntry = TitlePageEntryModel(key: "title", values: [])
        titleEntry.document = document
        document.titlePage.append(titleEntry)

        modelContext.insert(document)

        // With empty title value, should fall back to filename
        #expect(document.title == "test")
    }

    @Test("Document title returns first value when multiple values exist")
    func testDocumentTitleFirstValue() async throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        let document = GuionDocumentModel(filename: "test.guion")
        let titleEntry = TitlePageEntryModel(key: "title", values: ["First Title", "Second Title", "Third Title"])
        titleEntry.document = document
        document.titlePage.append(titleEntry)

        modelContext.insert(document)

        #expect(document.title == "First Title")
    }

    @Test("Document title ignores non-title keys and falls back to filename")
    func testDocumentTitleIgnoresOtherKeys() async throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        let document = GuionDocumentModel(filename: "test.guion")

        // Add various non-title entries
        let authorEntry = TitlePageEntryModel(key: "author", values: ["John Doe"])
        authorEntry.document = document
        document.titlePage.append(authorEntry)

        let contactEntry = TitlePageEntryModel(key: "contact", values: ["john@example.com"])
        contactEntry.document = document
        document.titlePage.append(contactEntry)

        modelContext.insert(document)

        // With no title entry, should fall back to filename
        #expect(document.title == "test")

        // Now add title
        let titleEntry = TitlePageEntryModel(key: "title", values: ["The Screenplay"])
        titleEntry.document = document
        document.titlePage.append(titleEntry)

        #expect(document.title == "The Screenplay")
    }

    @Test("Create document with title programmatically")
    func testProgrammaticTitleCreation() async throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        // Create a document with title page
        let document = GuionDocumentModel(filename: "MyScript.guion")

        // Add title (lowercase to test normalization)
        let titleEntry = TitlePageEntryModel(key: "title", values: ["My Amazing Screenplay"])
        titleEntry.document = document
        document.titlePage.append(titleEntry)

        // Add author
        let authorEntry = TitlePageEntryModel(key: "author", values: ["Jane Doe", "John Smith"])
        authorEntry.document = document
        document.titlePage.append(authorEntry)

        // Add contact
        let contactEntry = TitlePageEntryModel(key: "contact", values: ["jane@example.com"])
        contactEntry.document = document
        document.titlePage.append(contactEntry)

        modelContext.insert(document)
        try modelContext.save()

        // Verify
        #expect(document.title == "My Amazing Screenplay")
        #expect(document.titlePage.count == 3)

        // Verify all keys are normalized
        let keys = document.titlePage.map { $0.key }.sorted()
        #expect(keys == ["AUTHOR", "CONTACT", "TITLE"])
    }

    // MARK: - Title Fallback Logic Tests

    @Test("Title fallback: Priority 1 - Front matter TITLE used first")
    func testTitleFallbackPriority1FrontMatter() async throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        let document = GuionDocumentModel(filename: "FileBasedTitle.guion")

        // Add title to front matter
        let titleEntry = TitlePageEntryModel(key: "title", values: ["Front Matter Title"])
        titleEntry.document = document
        document.titlePage.append(titleEntry)

        modelContext.insert(document)

        // Should use front matter title (priority 1), ignoring filename
        #expect(document.title == "Front Matter Title")
    }

    @Test("Title fallback: Priority 2 - Filename without extension used when no front matter")
    func testTitleFallbackPriority2Filename() async throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        let document = GuionDocumentModel(filename: "MyAwesomeScript.fountain")
        modelContext.insert(document)

        // Should fall back to filename without extension (priority 2)
        #expect(document.title == "MyAwesomeScript")
    }

    @Test("Title fallback: Returns nil when no title or filename available")
    func testTitleFallbackReturnsNilWhenNoOptions() async throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        let document = GuionDocumentModel(filename: nil)
        modelContext.insert(document)

        // With no filename, no title page, and no elements, should return nil
        #expect(document.title == nil)
    }

    @Test("Title fallback: Handles empty filename gracefully")
    func testTitleFallbackHandlesEmptyFilename() async throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        let document = GuionDocumentModel(filename: "")
        modelContext.insert(document)

        // Empty filename should not be used as title
        #expect(document.title == nil)
    }

    @Test("Title fallback: Handles filename with multiple extensions")
    func testTitleFallbackMultipleExtensions() async throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        let document = GuionDocumentModel(filename: "MyScript.backup.fountain")
        modelContext.insert(document)

        // Should remove only the last extension
        #expect(document.title == "MyScript.backup")
    }

    @Test("Title fallback: Integration with markdown parsing without front matter")
    func testTitleFallbackMarkdownIntegration() async throws {
        let markdown = """
        # The First Heading

        This is some content.

        ## A Subheading

        More content here.
        """

        let screenplay = try await GuionParsedElementCollection(string: markdown)

        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        // Parse to SwiftData document
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: modelContext)

        // Without front matter and no filename, should return nil
        #expect(document.title == nil)
    }

    @Test("Title fallback: Integration with markdown front matter")
    func testTitleFallbackMarkdownFrontMatter() async throws {
        let markdown = """
        ---
        title: Front Matter Title
        author: John Doe
        ---

        # The First Heading

        This is some content.
        """

        let screenplay = try await GuionParsedElementCollection(string: markdown)

        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        // Parse to SwiftData document
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: modelContext)

        // Should use front matter title (priority 1), not the heading
        #expect(document.title == "Front Matter Title")
    }
}
