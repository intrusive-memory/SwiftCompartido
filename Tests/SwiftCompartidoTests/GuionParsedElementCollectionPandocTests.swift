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

    // MARK: - Helper Methods

    /// Get the path to a fixture file
    /// - Parameter filename: Filename relative to Fixtures/pandoc-documents/
    /// - Returns: Full path to the fixture file
    static func fixturePath(_ filename: String) -> String {
        let bundle: Bundle
        #if SWIFT_PACKAGE
        bundle = Bundle.module
        #else
        bundle = Bundle(for: GuionParsedElementCollectionPandocTests.self as! AnyClass)
        #endif

        guard let resourcePath = bundle.resourcePath else {
            fatalError("Could not find resource path")
        }

        return URL(fileURLWithPath: resourcePath)
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("pandoc-documents")
            .appendingPathComponent(filename)
            .path
    }

    // MARK: - DOCX Integration Tests

    @Test("Load simple DOCX through GuionParsedElementCollection", .tags(.requiresPandoc))
    func testLoadSimpleDocx() async throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return // Skip if Pandoc not available
        }

        let fixturePath = Self.fixturePath("simple.docx")
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
        #expect(heading?.elementText.contains("Simple Document") == true)
        #endif
    }

    @Test("Load formatted DOCX with bold and italic", .tags(.requiresPandoc))
    func testLoadFormattedDocx() async throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let fixturePath = Self.fixturePath("formatted.docx")
        guard FileManager.default.fileExists(atPath: fixturePath) else {
            Issue.record("Test fixture not found: \(fixturePath)")
            return
        }

        let screenplay = try await GuionParsedElementCollection(file: fixturePath)

        #expect(screenplay.filename == "formatted.docx")
        #expect(screenplay.elements.count >= 1)

        // Find paragraph with formatting (markdown markers are stripped by parser, check plain text)
        let formattedParagraph = screenplay.elements.first { element in
            element.elementType == .action && element.elementText.contains("bold text")
        }

        #expect(formattedParagraph != nil, "Should have formatted paragraph")
        #expect(formattedParagraph?.elementText.contains("bold text") == true)
        #expect(formattedParagraph?.elementText.contains("italic text") == true)
        #expect(formattedParagraph?.elementText.contains("inline code") == true)
        #endif
    }

    @Test("Load DOCX with lists", .tags(.requiresPandoc))
    func testLoadListsDocx() async throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let fixturePath = Self.fixturePath("lists.docx")
        guard FileManager.default.fileExists(atPath: fixturePath) else {
            Issue.record("Test fixture not found: \(fixturePath)")
            return
        }

        let screenplay = try await GuionParsedElementCollection(file: fixturePath)

        #expect(screenplay.filename == "lists.docx")

        // Verify list items parsed as unordered or ordered list elements
        let unorderedListItems = screenplay.elements.filter { element in
            if case .unorderedListItem = element.elementType {
                return true
            }
            return false
        }

        let orderedListItems = screenplay.elements.filter { element in
            if case .orderedListItem = element.elementType {
                return true
            }
            return false
        }

        let totalListItems = unorderedListItems.count + orderedListItems.count
        #expect(totalListItems >= 3, "Should have at least 3 list items")
        #endif
    }

    @Test("Load DOCX with metadata extracts title page", .tags(.requiresPandoc))
    func testLoadDocxWithMetadata() async throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let fixturePath = Self.fixturePath("metadata-full.docx")
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

        let fixturePath = Self.fixturePath("nested-lists.docx")
        guard FileManager.default.fileExists(atPath: fixturePath) else {
            Issue.record("Test fixture not found: \(fixturePath)")
            return
        }

        let screenplay = try await GuionParsedElementCollection(file: fixturePath)

        #expect(screenplay.filename == "nested-lists.docx")
        #expect(screenplay.elements.count >= 1)

        // Verify document loaded successfully and has list items (unordered or ordered)
        let listItems = screenplay.elements.filter { element in
            let isListItem: Bool
            switch element.elementType {
            case .unorderedListItem, .orderedListItem:
                isListItem = true
            default:
                isListItem = false
            }

            return isListItem &&
                (element.elementText.contains("First item") ||
                 element.elementText.contains("Nested item") ||
                 element.elementText.contains("Second item"))
        }

        #expect(listItems.count >= 1, "Should have parsed list items")
        #endif
    }

    // MARK: - ODT Integration Tests

    @Test("Load ODT through GuionParsedElementCollection", .tags(.requiresPandoc))
    func testLoadODT() async throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let fixturePath = Self.fixturePath("simple.odt")
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
        #expect(heading?.elementText.contains("Simple Document") == true)
        #endif
    }

    // MARK: - RTF Integration Tests

    @Test("Load RTF through GuionParsedElementCollection", .tags(.requiresPandoc))
    func testLoadRTF() async throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let fixturePath = Self.fixturePath("simple.rtf")
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
        #expect(heading?.elementText.contains("Simple Document") == true)
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
