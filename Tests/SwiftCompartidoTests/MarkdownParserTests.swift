//
//  MarkdownParserTests.swift
//  SwiftCompartidoTests
//
//  Tests for MarkdownParser including YAML front matter parsing
//

import Foundation
import Testing

@testable import SwiftCompartido

@Suite("Markdown Parser Tests")
struct MarkdownParserTests {

  // MARK: - Basic Parsing Tests

  @Test("Parse simple markdown without front matter")
  func testBasicMarkdownParsing() throws {
    let markdown = """
      # Scene One

      This is some action text.

      More action here.
      """

    let (elements, titlePage, _) = try MarkdownParser.parse(markdown)

    #expect(elements.count >= 2)
    #expect(titlePage.isEmpty)

    // Check that heading was parsed
    let headings = elements.filter { $0.elementType.isSectionHeading }
    #expect(headings.count == 1)
    #expect(headings.first?.elementText == "Scene One")
  }

  @Test("Parse markdown with lists")
  func testMarkdownListParsing() throws {
    let markdown = """
      # My Scene

      Some items:

      - First item
      - Second item
      - Third item
      """

    let (elements, _, _) = try MarkdownParser.parse(markdown)

    // List items should now be parsed as unorderedListItem elements
    let listItems = elements.filter {
      if case .unorderedListItem = $0.elementType {
        return true
      }
      return false
    }
    #expect(listItems.count == 3)

    // Check list item text content
    #expect(listItems[0].elementText == "First item")
    #expect(listItems[1].elementText == "Second item")
    #expect(listItems[2].elementText == "Third item")
  }

  // MARK: - YAML Front Matter Tests

  @Test("Parse YAML front matter with single values")
  func testYAMLFrontMatterSingleValues() throws {
    let markdown = """
      ---
      title: My Screenplay
      author: John Doe
      draft: First Draft
      ---

      # Act One

      Some content here.
      """

    let (elements, titlePage, _) = try MarkdownParser.parse(markdown)

    #expect(titlePage.count == 3)

    // Check title
    let titleDict = titlePage.first(where: { $0.keys.contains("title") })
    #expect(titleDict != nil)
    #expect(titleDict?["title"]?.first == "My Screenplay")

    // Check author (should be normalized to "authors")
    let authorDict = titlePage.first(where: { $0.keys.contains("authors") })
    #expect(authorDict != nil)
    #expect(authorDict?["authors"]?.first == "John Doe")

    // Check draft
    let draftDict = titlePage.first(where: { $0.keys.contains("draft") })
    #expect(draftDict != nil)
    #expect(draftDict?["draft"]?.first == "First Draft")

    // Ensure content was parsed
    #expect(elements.count > 0)
    let headings = elements.filter { $0.elementType.isSectionHeading }
    #expect(headings.first?.elementText == "Act One")
  }

  @Test("Parse YAML front matter with multiple authors")
  func testYAMLFrontMatterMultipleAuthors() throws {
    let markdown = """
      ---
      title: Collaborative Script
      authors:
        - Jane Smith
        - Bob Johnson
        - Alice Williams
      draft: Second Draft
      ---

      # Opening Scene
      """

    let (elements, titlePage, _) = try MarkdownParser.parse(markdown)

    // Check authors
    let authorDict = titlePage.first(where: { $0.keys.contains("authors") })
    #expect(authorDict != nil)
    #expect(authorDict?["authors"]?.count == 3)
    #expect(authorDict?["authors"]?.contains("Jane Smith") == true)
    #expect(authorDict?["authors"]?.contains("Bob Johnson") == true)
    #expect(authorDict?["authors"]?.contains("Alice Williams") == true)

    // Ensure content was parsed
    #expect(elements.count > 0)
  }

  @Test("Parse YAML front matter with empty values")
  func testYAMLFrontMatterEmptyValues() throws {
    let markdown = """
      ---
      title: My Script
      contact:
      notes:
      ---

      # Scene
      """

    let (elements, titlePage, _) = try MarkdownParser.parse(markdown)

    // Title should have value
    let titleDict = titlePage.first(where: { $0.keys.contains("title") })
    #expect(titleDict != nil)
    #expect(titleDict?["title"]?.first == "My Script")

    // Contact and notes should have empty arrays
    let contactDict = titlePage.first(where: { $0.keys.contains("contact") })
    #expect(contactDict != nil)
    #expect(contactDict?["contact"]?.isEmpty == true)

    #expect(elements.count > 0)
  }

  @Test("Parse markdown without YAML front matter")
  func testMarkdownWithoutFrontMatter() throws {
    let markdown = """
      # My Scene

      This markdown doesn't have front matter.
      """

    let (elements, titlePage, _) = try MarkdownParser.parse(markdown)

    #expect(titlePage.isEmpty)
    #expect(elements.count > 0)
  }

  @Test("Parse YAML front matter with special characters")
  func testYAMLFrontMatterSpecialCharacters() throws {
    let markdown = """
      ---
      title: A Story: The Beginning
      author: O'Brien, John
      contact: john@example.com
      ---

      # Scene
      """

    let (elements, titlePage, _) = try MarkdownParser.parse(markdown)

    let titleDict = titlePage.first(where: { $0.keys.contains("title") })
    #expect(titleDict?["title"]?.first == "A Story: The Beginning")

    let authorDict = titlePage.first(where: { $0.keys.contains("authors") })
    #expect(authorDict?["authors"]?.first == "O'Brien, John")
  }

  @Test("Handle markdown with incomplete front matter")
  func testIncompleteYAMLFrontMatter() throws {
    let markdown = """
      ---
      title: My Script
      author: John

      # Scene without closing front matter delimiter
      """

    let (elements, _, _) = try MarkdownParser.parse(markdown)

    // Without closing ---, it should be treated as regular content
    // The parser should handle this gracefully
    #expect(elements.count > 0)
  }

  @Test("Parse YAML front matter case insensitivity")
  func testYAMLFrontMatterCaseInsensitivity() throws {
    let markdown = """
      ---
      Title: My Screenplay
      AUTHOR: Jane Doe
      Draft: First
      ---

      # Scene
      """

    let (elements, titlePage, _) = try MarkdownParser.parse(markdown)

    // Keys should be normalized to lowercase
    let titleDict = titlePage.first(where: { $0.keys.contains("title") })
    #expect(titleDict != nil)

    let authorDict = titlePage.first(where: { $0.keys.contains("authors") })
    #expect(authorDict != nil)

    let draftDict = titlePage.first(where: { $0.keys.contains("draft") })
    #expect(draftDict != nil)
  }

  @Test("Author normalized to authors")
  func testAuthorNormalization() throws {
    let markdown = """
      ---
      title: Test
      author: Single Author
      ---

      # Scene
      """

    let (_, titlePage, _) = try MarkdownParser.parse(markdown)

    // "author" should be normalized to "authors"
    let authorDict = titlePage.first(where: { $0.keys.contains("authors") })
    #expect(authorDict != nil)
    #expect(authorDict?["authors"]?.first == "Single Author")

    // There should be no "author" key (only "authors")
    let oldAuthorDict = titlePage.first(where: { $0.keys.contains("author") })
    #expect(oldAuthorDict == nil)
  }

  // MARK: - Integration with GuionParsedElementCollection

  @Test("Integration: Parse markdown file via GuionParsedElementCollection")
  func testGuionParsedElementCollectionIntegration() async throws {
    let markdown = """
      ---
      title: Integration Test
      author: Test Author
      ---

      # Act One

      INT. COFFEE SHOP - DAY

      Sarah enters nervously.
      """

    let screenplay = try await GuionParsedElementCollection(string: markdown)

    #expect(screenplay.elements.count > 0)
    #expect(screenplay.titlePage.count > 0)

    // Check that title page was parsed
    let titleDict = screenplay.titlePage.first(where: { $0.keys.contains("title") })
    #expect(titleDict?["title"]?.first == "Integration Test")
  }

  @Test("Complex YAML front matter with multiple fields")
  func testComplexYAMLFrontMatter() throws {
    let markdown = """
      ---
      title: The Great Adventure
      author: John Doe
      draft: Third Draft
      date: 2025-01-15
      contact: john@example.com
      copyright: (c) 2025 John Doe
      notes: This is a test screenplay
      ---

      # Prologue

      The story begins...
      """

    let (elements, titlePage, _) = try MarkdownParser.parse(markdown)

    #expect(titlePage.count == 7)  // All 7 fields

    let titleDict = titlePage.first(where: { $0.keys.contains("title") })
    #expect(titleDict?["title"]?.first == "The Great Adventure")

    let dateDict = titlePage.first(where: { $0.keys.contains("date") })
    #expect(dateDict?["date"]?.first == "2025-01-15")

    let copyrightDict = titlePage.first(where: { $0.keys.contains("copyright") })
    #expect(copyrightDict?["copyright"]?.first == "(c) 2025 John Doe")

    #expect(elements.count > 0)
  }
}
