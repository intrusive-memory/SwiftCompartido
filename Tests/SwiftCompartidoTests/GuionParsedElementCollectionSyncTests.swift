//
//  GuionParsedElementCollectionSyncTests.swift
//  SwiftCompartido
//
//  Tests for synchronous GuionParsedElementCollection initialization
//

import Testing
import Foundation
@testable import SwiftCompartido

/// Tests for synchronous GuionParsedElementCollection initialization
///
/// Verifies that all supported formats work with the synchronous init(file:) method.
@Suite("GuionParsedElementCollection - Synchronous Init")
struct GuionParsedElementCollectionSyncTests {

    @Test("Synchronous init supports DOCX files", .tags(.requiresPandoc))
    func testSyncInitDocx() throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return // Skip if Pandoc not available
        }

        let fixturePath = "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/simple.docx"
        guard FileManager.default.fileExists(atPath: fixturePath) else {
            Issue.record("Test fixture not found: \(fixturePath)")
            return
        }

        // Use synchronous init
        let screenplay = try GuionParsedElementCollection(file: fixturePath)

        // Verify file loaded
        #expect(screenplay.filename == "simple.docx")
        #expect(screenplay.elements.count >= 1)

        // Verify heading
        let heading = screenplay.elements.first { $0.elementType == .sectionHeading(level: 1) }
        #expect(heading != nil)
        #expect(heading?.text.contains("Simple Document") == true)
        #endif
    }

    @Test("Synchronous init supports ODT files", .tags(.requiresPandoc))
    func testSyncInitOdt() throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let fixturePath = "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/simple.odt"
        guard FileManager.default.fileExists(atPath: fixturePath) else {
            Issue.record("Test fixture not found: \(fixturePath)")
            return
        }

        let screenplay = try GuionParsedElementCollection(file: fixturePath)

        #expect(screenplay.filename == "simple.odt")
        #expect(screenplay.elements.count >= 1)
        #endif
    }

    @Test("Synchronous init supports RTF files", .tags(.requiresPandoc))
    func testSyncInitRtf() throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return
        }

        let fixturePath = "/Users/stovak/Projects/SwiftCompartido/Fixtures/pandoc-documents/simple.rtf"
        guard FileManager.default.fileExists(atPath: fixturePath) else {
            Issue.record("Test fixture not found: \(fixturePath)")
            return
        }

        let screenplay = try GuionParsedElementCollection(file: fixturePath)

        #expect(screenplay.filename == "simple.rtf")
        #expect(screenplay.elements.count >= 1)
        #endif
    }

    @Test("Synchronous init throws helpful error for PDF files")
    func testSyncInitPdfThrowsError() throws {
        // Create a temporary .pdf file path (doesn't need to exist for error check)
        let tempPath = "/tmp/test.pdf"

        #expect(throws: GuionParserError.self) {
            _ = try GuionParsedElementCollection(file: tempPath)
        }
    }

    @Test("Synchronous init still supports Fountain files")
    func testSyncInitFountain() throws {
        // Create a temporary Fountain file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test.fountain")
        let fountainContent = """
        Title: Test Screenplay

        INT. TEST LOCATION - DAY

        This is action text.
        """
        try fountainContent.write(to: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let screenplay = try GuionParsedElementCollection(file: testFile.path)

        #expect(screenplay.filename == "test.fountain")
        #expect(screenplay.elements.count >= 1)
    }

    @Test("Synchronous init still supports Markdown files")
    func testSyncInitMarkdown() throws {
        // Create a temporary Markdown file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test.md")
        let mdContent = """
        # Test Document

        This is a paragraph.
        """
        try mdContent.write(to: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let screenplay = try GuionParsedElementCollection(file: testFile.path)

        #expect(screenplay.filename == "test.md")
        #expect(screenplay.elements.count >= 1)
    }
}
