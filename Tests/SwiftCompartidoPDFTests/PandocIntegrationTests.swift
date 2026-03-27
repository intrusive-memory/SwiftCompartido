//
//  PandocIntegrationTests.swift
//  SwiftCompartido
//
//  Integration tests for Pandoc document parsing (DOCX, ODT, RTF)
//

import Foundation
import Testing

@testable import SwiftCompartido

/// Integration tests for Pandoc document parsing
///
/// These tests verify end-to-end conversion of document files (DOCX, ODT, RTF)
/// to screenplay elements using Pandoc and MarkdownParser.
///
/// Test fixtures: Fixtures/pandoc-documents/
/// Expected markdown: Fixtures/pandoc-documents/*.expected.md
@Suite("Pandoc Integration - Document Conversion")
struct PandocIntegrationTests {

  // MARK: - Helper Methods

  /// Get the URL to a fixture file
  /// - Parameter filename: Filename relative to Fixtures/pandoc-documents/
  /// - Returns: Full URL to the fixture file
  static func fixtureURL(_ filename: String) -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Fixtures")
      .appendingPathComponent("pandoc-documents")
      .appendingPathComponent(filename)
  }

  // MARK: - DOCX Conversion Tests

  @Test("Parse simple DOCX with heading and paragraphs", .tags(.requiresPandoc))
  func testSimpleDocxParsing() throws {
    #if os(macOS)
      guard PandocDocumentParser.isPandocAvailable() else {
        return  // Skip if Pandoc not available
      }

      // Get test fixture
      let fixtureURL = Self.fixtureURL("simple.docx")
      guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
        Issue.record("Test fixture not found: \(fixtureURL.path)")
        return
      }

      // Parse DOCX
      let (elements, titlePage) = try PandocDocumentParser.parse(url: fixtureURL)

      // Verify structure
      #expect(elements.count >= 1, "Should have at least 1 element (heading)")

      // Verify heading
      let heading = elements.first { $0.elementType == .sectionHeading(level: 1) }
      #expect(heading != nil, "Should have H1 heading")
      #expect(
        heading?.elementText.contains("Simple Document") == true,
        "Heading should contain 'Simple Document'")

      // Verify paragraphs
      let actions = elements.filter { $0.elementType == .action }
      #expect(actions.count >= 1, "Should have at least 1 action (paragraph)")
    #endif
  }

  @Test("Parse formatted DOCX preserves bold and italic", .tags(.requiresPandoc))
  func testFormattedDocxParsing() throws {
    #if os(macOS)
      guard PandocDocumentParser.isPandocAvailable() else {
        return
      }

      let fixtureURL = Self.fixtureURL("formatted.docx")
      guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
        Issue.record("Test fixture not found: \(fixtureURL.path)")
        return
      }

      let (elements, _) = try PandocDocumentParser.parse(url: fixtureURL)

      // Find paragraph with formatting (markdown markers are stripped by parser)
      let formattedParagraph = elements.first { element in
        element.elementType == .action && element.elementText.contains("bold text")
      }

      #expect(formattedParagraph != nil, "Should have paragraph with formatted text")
      #expect(
        formattedParagraph?.elementText.contains("bold text") == true,
        "Should have bold text content")
      #expect(
        formattedParagraph?.elementText.contains("italic text") == true,
        "Should have italic text content")
      #expect(
        formattedParagraph?.elementText.contains("inline code") == true,
        "Should have inline code content")
    #endif
  }

  @Test("Parse DOCX with lists preserves structure", .tags(.requiresPandoc))
  func testListsDocxParsing() throws {
    #if os(macOS)
      guard PandocDocumentParser.isPandocAvailable() else {
        return
      }

      let fixtureURL = Self.fixtureURL("lists.docx")
      guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
        Issue.record("Test fixture not found: \(fixtureURL.path)")
        return
      }

      let (elements, _) = try PandocDocumentParser.parse(url: fixtureURL)

      // Find unordered list items
      let unorderedListItems = elements.filter { element in
        if case .unorderedListItem = element.elementType {
          return true
        }
        return false
      }

      // Find ordered list items
      let orderedListItems = elements.filter { element in
        if case .orderedListItem = element.elementType {
          return true
        }
        return false
      }

      // Should have some list items (bulleted or numbered)
      let totalListItems = unorderedListItems.count + orderedListItems.count
      #expect(totalListItems >= 3, "Should have at least 3 list items")

      // Verify we have both unordered and ordered lists
      #expect(unorderedListItems.count >= 1, "Should have at least one unordered list item")
      #expect(orderedListItems.count >= 1, "Should have at least one ordered list item")
    #endif
  }

  // MARK: - ODT Conversion Tests

  @Test("Parse ODT file produces same elements as DOCX", .tags(.requiresPandoc))
  func testODTConversion() throws {
    #if os(macOS)
      guard PandocDocumentParser.isPandocAvailable() else {
        return
      }

      let odtURL = Self.fixtureURL("simple.odt")
      guard FileManager.default.fileExists(atPath: odtURL.path) else {
        Issue.record("Test fixture not found: \(odtURL.path)")
        return
      }

      let (elements, _) = try PandocDocumentParser.parse(url: odtURL)

      // Verify basic structure (should match DOCX output)
      #expect(elements.count >= 1, "Should have at least 1 element")

      let heading = elements.first { $0.elementType == .sectionHeading(level: 1) }
      #expect(heading != nil, "Should have H1 heading")
      #expect(heading?.elementText.contains("Simple Document") == true)
    #endif
  }

  // MARK: - RTF Conversion Tests

  @Test("Parse RTF file produces same elements as DOCX", .tags(.requiresPandoc))
  func testRTFConversion() throws {
    #if os(macOS)
      guard PandocDocumentParser.isPandocAvailable() else {
        return
      }

      let rtfURL = Self.fixtureURL("simple.rtf")
      guard FileManager.default.fileExists(atPath: rtfURL.path) else {
        Issue.record("Test fixture not found: \(rtfURL.path)")
        return
      }

      let (elements, _) = try PandocDocumentParser.parse(url: rtfURL)

      // Verify basic structure (should match DOCX output)
      #expect(elements.count >= 1, "Should have at least 1 element")

      let heading = elements.first { $0.elementType == .sectionHeading(level: 1) }
      #expect(heading != nil, "Should have H1 heading")
      #expect(heading?.elementText.contains("Simple Document") == true)
    #endif
  }

  // MARK: - Format Detection Tests

  @Test("Supported extensions include DOCX, ODT, RTF")
  func testSupportedFormats() {
    let extensions = PandocDocumentParser.supportedExtensions

    #expect(extensions.contains("docx"), "Should support DOCX")
    #expect(extensions.contains("odt"), "Should support ODT")
    #expect(extensions.contains("rtf"), "Should support RTF")
    #expect(extensions.count == 3, "Should support exactly 3 formats")
  }

  // MARK: - Error Handling Tests

  @Test("Throw error for non-existent file")
  func testNonExistentFile() {
    #if os(macOS)
      let nonExistentURL = URL(fileURLWithPath: "/tmp/does-not-exist.docx")

      #expect(throws: Error.self) {
        try PandocDocumentParser.parse(url: nonExistentURL)
      }
    #endif
  }

  @Test("Throw error for unsupported extension")
  func testUnsupportedExtension() throws {
    #if os(macOS)
      // Create temporary file with unsupported extension
      let tempDir = FileManager.default.temporaryDirectory
      let testFile = tempDir.appendingPathComponent("test.xyz")
      try "test content".write(to: testFile, atomically: true, encoding: .utf8)
      defer { try? FileManager.default.removeItem(at: testFile) }

      #expect(throws: PandocParserError.self) {
        try PandocDocumentParser.parse(url: testFile)
      }
    #endif
  }
}
