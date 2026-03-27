//
//  TitlePageTests.swift
//  SwiftCompartidoTests
//
//  Tests for title page functionality including case-insensitive key normalization
//  and the synthetic title property on GuionDocumentModel.
//

import Foundation
import SwiftData
import Testing

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
      ("AUTHOR", "AUTHOR"),
    ]

    for (input, expected) in testCases {
      let entry = TitlePageEntryModel(key: input, values: ["Test Value"])
      #expect(
        entry.key == expected,
        "Key '\(input)' should be normalized to '\(expected)', got '\(entry.key)'")
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

  @Test("Document title property stores title value")
  func testDocumentTitleProperty() async throws {
    let schema = Schema([
      GuionDocumentModel.self,
      GuionElementModel.self,
      TitlePageEntryModel.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
    let modelContext = modelContainer.mainContext

    let document = GuionDocumentModel(filename: "test.guion", title: "The Great Screenplay")

    // Add title entry with lowercase key
    let titleEntry = TitlePageEntryModel(key: "title", values: ["The Great Screenplay"])
    titleEntry.document = document
    document.titlePage.append(titleEntry)

    modelContext.insert(document)

    #expect(document.title == "The Great Screenplay")
  }

  @Test("Document title can be set explicitly")
  func testDocumentTitleExplicitSetting() async throws {
    let schema = Schema([
      GuionDocumentModel.self,
      GuionElementModel.self,
      TitlePageEntryModel.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
    let modelContext = modelContainer.mainContext

    // Test various titles
    let testCases = [
      ("Lowercase Title", "Lowercase Title"),
      ("UPPERCASE TITLE", "UPPERCASE TITLE"),
      ("Title Case Title", "Title Case Title"),
      ("Mixed Case TiTlE", "Mixed Case TiTlE"),
    ]

    for (title, expectedTitle) in testCases {
      let document = GuionDocumentModel(filename: "test.guion", title: title)
      modelContext.insert(document)

      #expect(document.title == expectedTitle, "Title should be '\(expectedTitle)'")
    }
  }

  @Test("Document title defaults to nil when not set")
  func testDocumentTitleDefaultsToNil() async throws {
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

    // When title not set, should be nil
    #expect(document.title == nil)
  }

  @Test("Document title can be changed after creation")
  func testDocumentTitleCanBeChanged() async throws {
    let schema = Schema([
      GuionDocumentModel.self,
      GuionElementModel.self,
      TitlePageEntryModel.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
    let modelContext = modelContainer.mainContext

    let document = GuionDocumentModel(filename: "test.guion", title: "Original Title")
    modelContext.insert(document)

    #expect(document.title == "Original Title")

    // Change the title
    document.title = "Updated Title"
    #expect(document.title == "Updated Title")
  }

  @Test("Document stores title independently of titlePage entries")
  func testDocumentTitleIndependentOfTitlePage() async throws {
    let schema = Schema([
      GuionDocumentModel.self,
      GuionElementModel.self,
      TitlePageEntryModel.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
    let modelContext = modelContainer.mainContext

    // Title is stored independently
    let document = GuionDocumentModel(filename: "test.guion", title: "Stored Title")

    // titlePage entries don't affect the stored title
    let titleEntry = TitlePageEntryModel(key: "title", values: ["Different Title"])
    titleEntry.document = document
    document.titlePage.append(titleEntry)

    modelContext.insert(document)

    // Title remains as originally set
    #expect(document.title == "Stored Title")
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

    // Verify - note that title is now stored independently and must be set explicitly
    // In real usage, parsing sets the title automatically
    document.title = "My Amazing Screenplay"
    #expect(document.title == "My Amazing Screenplay")
    #expect(document.titlePage.count == 3)

    // Verify all keys are normalized
    let keys = document.titlePage.map { $0.key }.sorted()
    #expect(keys == ["AUTHOR", "CONTACT", "TITLE"])
  }

  // MARK: - Title Extraction During Parsing Tests

  @Test("Parsing extracts title from front matter")
  func testParsingExtractsTitleFromFrontMatter() async throws {
    let markdown = """
      ---
      title: My Screenplay Title
      author: Jane Doe
      ---

      # Act One

      This is the content.
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

    // Parse to SwiftData document - title should be extracted automatically
    let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: modelContext)

    // Should extract title from front matter
    #expect(document.title == "My Screenplay Title")
  }

  @Test("Parsing falls back to filename when no front matter title")
  func testParsingFallsBackToFilename() async throws {
    let markdown = """
      # Act One

      This is the content.
      """

    let elements = try await GuionParsedElementCollection(string: markdown).elements
    // Create screenplay with filename
    let screenplay = GuionParsedElementCollection(
      filename: "TestScript.md",
      elements: elements,
      titlePage: [],
      suppressSceneNumbers: false
    )

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

    // Should fall back to filename without extension
    #expect(document.title == "TestScript")
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

  @Test("Parsing handles filename with multiple extensions")
  func testParsingHandlesMultipleExtensions() async throws {
    let elements = try await GuionParsedElementCollection(string: "Content").elements
    let screenplay = GuionParsedElementCollection(
      filename: "MyScript.backup.fountain",
      elements: elements,
      titlePage: [],
      suppressSceneNumbers: false
    )

    let schema = Schema([
      GuionDocumentModel.self,
      GuionElementModel.self,
      TitlePageEntryModel.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
    let modelContext = modelContainer.mainContext

    let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: modelContext)

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
