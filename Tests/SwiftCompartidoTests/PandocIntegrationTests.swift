//
//  PandocIntegrationTests.swift
//  SwiftCompartido
//
//  Integration tests for Pandoc document parsing (DOCX, ODT, RTF)
//

import Testing
import Foundation
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

    // MARK: - DOCX Conversion Tests

    @Test("Parse simple DOCX with heading and paragraphs", .tags(.requiresPandoc))
    func testSimpleDocxParsing() throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return // Skip if Pandoc not available
        }

        // Get test fixture
        let fixtureURL = URL(fileURLWithPath: "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/simple.docx")
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
        #expect(heading?.elementText.contains("Simple Document") == true, "Heading should contain 'Simple Document'")

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

        let fixtureURL = URL(fileURLWithPath: "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/formatted.docx")
        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            Issue.record("Test fixture not found: \(fixtureURL.path)")
            return
        }

        let (elements, _) = try PandocDocumentParser.parse(url: fixtureURL)

        // Find paragraph with formatting
        let formattedParagraph = elements.first { element in
            element.elementType == .action && element.elementText.contains("**bold")
        }

        #expect(formattedParagraph != nil, "Should have paragraph with formatting markers")
        #expect(formattedParagraph?.elementText.contains("**bold text**") == true, "Should preserve bold markers")
        #expect(formattedParagraph?.elementText.contains("*italic text*") == true, "Should preserve italic markers")
        #endif
    }

    @Test("Parse DOCX with lists preserves structure", .tags(.requiresPandoc))
    func testListsDocxParsing() throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let fixtureURL = URL(fileURLWithPath: "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/lists.docx")
        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            Issue.record("Test fixture not found: \(fixtureURL.path)")
            return
        }

        let (elements, _) = try PandocDocumentParser.parse(url: fixtureURL)

        // Find list items
        let listItems = elements.filter { element in
            element.elementType == .action && (
                element.elementText.hasPrefix("-") ||
                element.elementText.first?.isNumber == true
            )
        }

        #expect(listItems.count >= 3, "Should have at least 3 list items")

        // Verify bulleted list
        let bulletItem = listItems.first { $0.elementText.hasPrefix("- ") }
        #expect(bulletItem != nil, "Should have bulleted list item")

        // Verify numbered list
        let numberedItem = listItems.first { $0.elementText.contains("1. ") }
        #expect(numberedItem != nil, "Should have numbered list item")
        #endif
    }

    // MARK: - ODT Conversion Tests

    @Test("Parse ODT file produces same elements as DOCX", .tags(.requiresPandoc))
    func testODTConversion() throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let odtURL = URL(fileURLWithPath: "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/simple.odt")
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

        let rtfURL = URL(fileURLWithPath: "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/simple.rtf")
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
