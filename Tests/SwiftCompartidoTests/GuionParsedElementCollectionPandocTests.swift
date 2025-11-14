//
//  GuionParsedElementCollectionPandocTests.swift
//  SwiftCompartido
//
//  Integration tests for GuionParsedElementCollection with Pandoc document formats
//

import Testing
import Foundation
@testable import SwiftCompartido

/// Integration tests for GuionParsedElementCollection with Pandoc formats
///
/// These tests verify that DOCX, ODT, and RTF files can be loaded through
/// the GuionParsedElementCollection API with automatic format detection.
///
/// Test fixtures: Fixtures/pandoc-documents/
@Suite("GuionParsedElementCollection - Pandoc Format Integration")
struct GuionParsedElementCollectionPandocTests {

    // MARK: - DOCX Integration Tests

    @Test("Load simple DOCX through GuionParsedElementCollection", .tags(.requiresPandoc))
    func testLoadSimpleDocx() async throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return // Skip if Pandoc not available
        }

        let fixturePath = "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/simple.docx"
        guard FileManager.default.fileExists(atPath: fixturePath) else {
            Issue.record("Test fixture not found: \(fixturePath)")
            return
        }

        let screenplay = try await GuionParsedElementCollection(file: fixturePath)

        // Verify file loaded
        #expect(screenplay.filename == "simple.docx")

        // Verify content parsed
        #expect(screenplay.elements.count >= 1, "Should have at least 1 element")

        // Verify heading
        let heading = screenplay.elements.first { $0.elementType == .sectionHeading(level: 1) }
        #expect(heading != nil, "Should have H1 heading")
        #expect(heading?.text.contains("Simple Document") == true)
        #endif
    }

    @Test("Load formatted DOCX with bold and italic", .tags(.requiresPandoc))
    func testLoadFormattedDocx() async throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let fixturePath = "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/formatted.docx"
        guard FileManager.default.fileExists(atPath: fixturePath) else {
            Issue.record("Test fixture not found: \(fixturePath)")
            return
        }

        let screenplay = try await GuionParsedElementCollection(file: fixturePath)

        #expect(screenplay.filename == "formatted.docx")
        #expect(screenplay.elements.count >= 1)

        // Find paragraph with formatting
        let formattedParagraph = screenplay.elements.first { element in
            element.elementType == .action && element.text.contains("**bold")
        }

        #expect(formattedParagraph != nil, "Should have formatted paragraph")
        #expect(formattedParagraph?.text.contains("**bold text**") == true)
        #expect(formattedParagraph?.text.contains("*italic text*") == true)
        #endif
    }

    @Test("Load DOCX with lists", .tags(.requiresPandoc))
    func testLoadListsDocx() async throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let fixturePath = "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/lists.docx"
        guard FileManager.default.fileExists(atPath: fixturePath) else {
            Issue.record("Test fixture not found: \(fixturePath)")
            return
        }

        let screenplay = try await GuionParsedElementCollection(file: fixturePath)

        #expect(screenplay.filename == "lists.docx")

        // Verify list items parsed
        let listItems = screenplay.elements.filter { element in
            element.elementType == .action && (
                element.text.hasPrefix("-") ||
                element.text.first?.isNumber == true
            )
        }

        #expect(listItems.count >= 3, "Should have at least 3 list items")
        #endif
    }

    @Test("Load DOCX with metadata extracts title page", .tags(.requiresPandoc))
    func testLoadDocxWithMetadata() async throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let fixturePath = "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/metadata-full.docx"
        guard FileManager.default.fileExists(atPath: fixturePath) else {
            Issue.record("Test fixture not found: \(fixturePath)")
            return
        }

        let screenplay = try await GuionParsedElementCollection(file: fixturePath)

        #expect(screenplay.filename == "metadata-full.docx")

        // Verify metadata extracted to title page
        #expect(screenplay.titlePage.count > 0, "Should have title page metadata")

        // Check for title in metadata
        let hasTitle = screenplay.titlePage.contains { entry in
            entry.keys.contains("title") || entry.keys.contains("Title")
        }

        #expect(hasTitle, "Should have title in metadata")
        #endif
    }

    @Test("Load DOCX with nested lists", .tags(.requiresPandoc))
    func testLoadNestedListsDocx() async throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let fixturePath = "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/nested-lists.docx"
        guard FileManager.default.fileExists(atPath: fixturePath) else {
            Issue.record("Test fixture not found: \(fixturePath)")
            return
        }

        let screenplay = try await GuionParsedElementCollection(file: fixturePath)

        #expect(screenplay.filename == "nested-lists.docx")
        #expect(screenplay.elements.count >= 1)

        // Verify nested structure preserved (indentation)
        let nestedItems = screenplay.elements.filter { element in
            element.elementType == .action && element.text.contains("  -")
        }

        #expect(nestedItems.count >= 1, "Should have nested list items with indentation")
        #endif
    }

    // MARK: - ODT Integration Tests

    @Test("Load ODT through GuionParsedElementCollection", .tags(.requiresPandoc))
    func testLoadODT() async throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let fixturePath = "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/simple.odt"
        guard FileManager.default.fileExists(atPath: fixturePath) else {
            Issue.record("Test fixture not found: \(fixturePath)")
            return
        }

        let screenplay = try await GuionParsedElementCollection(file: fixturePath)

        #expect(screenplay.filename == "simple.odt")
        #expect(screenplay.elements.count >= 1)

        // Verify same structure as DOCX
        let heading = screenplay.elements.first { $0.elementType == .sectionHeading(level: 1) }
        #expect(heading != nil, "Should have H1 heading")
        #expect(heading?.text.contains("Simple Document") == true)
        #endif
    }

    // MARK: - RTF Integration Tests

    @Test("Load RTF through GuionParsedElementCollection", .tags(.requiresPandoc))
    func testLoadRTF() async throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let fixturePath = "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/simple.rtf"
        guard FileManager.default.fileExists(atPath: fixturePath) else {
            Issue.record("Test fixture not found: \(fixturePath)")
            return
        }

        let screenplay = try await GuionParsedElementCollection(file: fixturePath)

        #expect(screenplay.filename == "simple.rtf")
        #expect(screenplay.elements.count >= 1)

        // Verify same structure as DOCX
        let heading = screenplay.elements.first { $0.elementType == .sectionHeading(level: 1) }
        #expect(heading != nil, "Should have H1 heading")
        #expect(heading?.text.contains("Simple Document") == true)
        #endif
    }

    // MARK: - Error Handling Tests

    @Test("Throw error for non-existent DOCX file")
    func testNonExistentDocxFile() async {
        #if os(macOS)
        let nonExistentPath = "/tmp/does-not-exist.docx"

        await #expect(throws: Error.self) {
            try await GuionParsedElementCollection(file: nonExistentPath)
        }
        #endif
    }
}
