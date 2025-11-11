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

    @Test("Document title returns nil when no title page entry exists")
    func testDocumentTitleNilWhenNoEntry() async throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = modelContainer.mainContext

        let document = GuionDocumentModel(filename: "test.guion")
        modelContext.insert(document)

        #expect(document.title == nil)
    }

    @Test("Document title returns nil when title value is empty")
    func testDocumentTitleNilWhenEmpty() async throws {
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

        #expect(document.title == nil)
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

    @Test("Document title ignores non-title keys")
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

        #expect(document.title == nil)

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
}
