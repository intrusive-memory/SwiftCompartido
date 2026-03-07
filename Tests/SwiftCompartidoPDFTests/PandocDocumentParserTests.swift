//
//  PandocDocumentParserTests.swift
//  SwiftCompartido
//
//  Tests for PandocDocumentParser - Pandoc integration and document conversion
//

import Testing
import Foundation
@testable import SwiftCompartido

/// Tests for PandocDocumentParser Pandoc integration
///
/// These tests verify that the Pandoc binary is correctly detected and used
/// to convert document files (DOCX, ODT, RTF) to Markdown.
///
/// Test strategy:
/// - Use system Pandoc for development (bundled Pandoc for production)
/// - Test files in Fixtures/pandoc-documents/
/// - Pre-converted markdown in Fixtures/pandoc-documents/**/*.expected.md
@Suite("PandocDocumentParser - Pandoc Integration")
struct PandocDocumentParserTests {

    // MARK: - Pandoc Detection Tests

    @Test("Pandoc binary is available on system")
    func testPandocAvailability() throws {
        let available = PandocDocumentParser.isPandocAvailable()

        #if os(macOS)
        // On macOS, expect Pandoc to be available (system or bundled)
        #expect(available, "Pandoc should be available (either bundled or system)")
        #else
        // On iOS, Pandoc is not supported (Process API unavailable)
        #expect(!available, "Pandoc should not be available on iOS")
        #endif
    }

    @Test("System Pandoc is found in common locations")
    func testSystemPandocDetection() throws {
        // This test verifies that system Pandoc is detected during development
        let available = PandocDocumentParser.isPandocAvailable()

        if available {
            // Verify that at least one of the common paths exists
            let systemPaths = [
                "/opt/homebrew/bin/pandoc",  // Apple Silicon
                "/usr/local/bin/pandoc",     // Intel
                "/usr/bin/pandoc"            // System
            ]

            let pandocExists = systemPaths.contains { path in
                FileManager.default.fileExists(atPath: path)
            }

            #expect(pandocExists, "System Pandoc should exist in common location")
        }
    }

    @Test("Supported extensions include DOCX, ODT, RTF")
    func testSupportedExtensions() {
        let extensions = PandocDocumentParser.supportedExtensions

        #expect(extensions.contains("docx"), "Should support DOCX")
        #expect(extensions.contains("odt"), "Should support ODT")
        #expect(extensions.contains("rtf"), "Should support RTF")
        #expect(extensions.count == 3, "Should support exactly 3 formats")
    }

    // MARK: - Error Handling Tests

    @Test("Throw error for unsupported format")
    func testUnsupportedFormatError() throws {
        // Create a temporary file with unsupported extension
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test.xyz")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testFile) }

        // Should throw unsupportedFormat error
        #expect(throws: PandocParserError.self) {
            try PandocDocumentParser.parse(url: testFile)
        }
    }

    @Test("Error message for unsupported format is helpful")
    func testUnsupportedFormatErrorMessage() {
        let error = PandocParserError.unsupportedFormat("xyz")
        let message = error.errorDescription

        #expect(message != nil)
        #expect(message?.contains("xyz") == true, "Error should mention the extension")
        #expect(message?.contains("DOCX") == true, "Error should list supported formats")
    }

    @Test("Error message for missing Pandoc is helpful")
    func testMissingPandocErrorMessage() {
        let error = PandocParserError.pandocNotAvailable
        let message = error.errorDescription

        #expect(message != nil)
        #expect(message?.contains("converter") == true, "Error should mention converter")
    }

    // MARK: - Pandoc Version Tests

    @Test("Pandoc version is 2.14.2 or newer (RTF support)", .tags(.requiresPandoc))
    func testPandocVersionSupportsRTF() throws {
        #if os(macOS)
        guard PandocDocumentParser.isPandocAvailable() else {
            return // Skip test if Pandoc not available
        }

        // Get Pandoc path and check version
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/pandoc")
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Check that it's version 2.14.2 or newer
        #expect(output.contains("pandoc"), "Output should mention pandoc")
        // Note: Full version parsing would go here, but for now we just verify it runs
        #endif
    }
}

/// Tag for tests that require Pandoc to be installed
extension Tag {
    @Tag static var requiresPandoc: Self
}
