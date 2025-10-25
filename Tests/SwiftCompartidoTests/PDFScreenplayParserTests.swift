//
//  PDFScreenplayParserTests.swift
//  SwiftCompartidoTests
//
//  Tests for PDF screenplay parsing functionality
//

import Testing
import Foundation
@testable import SwiftCompartido

/// Tests for PDF Screenplay Parser functionality
///
/// Uses real PDF screenplay files from Fixtures directory to validate:
/// - PDF text extraction
/// - Fountain conversion
/// - Error handling
/// - Progress reporting
/// - Full workflow (PDF → Screenplay → SwiftData)
@Suite("PDF Screenplay Parser Tests")
struct PDFScreenplayParserTests {

    // MARK: - Test Fixtures

    /// Get a test fixture PDF by filename
    private func getFixture(_ filename: String) -> URL {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: type(of: self))
        #endif

        guard let resourcePath = bundle.resourcePath else {
            fatalError("Could not find resource path")
        }

        return URL(fileURLWithPath: resourcePath)
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(filename)
    }

    /// Verify a fixture file exists
    private func fixtureExists(_ filename: String) -> Bool {
        let url = getFixture(filename)
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Basic PDF Opening Tests

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Open simple PDF file")
    func testOpenPDFFile() async throws {
        // Use a smaller PDF for quick test
        let url = getFixture("ATTACK-THE-BLOCK.pdf")

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: url.path))

        // Should be able to parse
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Should have elements
        #expect(screenplay.elements.count > 0)

        print("✅ Parsed ATTACK-THE-BLOCK.pdf - \(screenplay.elements.count) elements")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Open larger PDF file")
    func testOpenLargerPDF() async throws {
        // Test with a larger file
        let url = getFixture("Eternal Sunshine of the Spotless Mind.pdf")

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: url.path))

        // Should be able to parse
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Should have many elements
        #expect(screenplay.elements.count > 50)

        print("✅ Parsed Eternal Sunshine - \(screenplay.elements.count) elements")
    }

    // MARK: - Text Extraction Tests

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Extract text from PDF")
    func testTextExtraction() async throws {
        let url = getFixture("BULLITT.pdf")

        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Should have scene headings
        let sceneHeadings = screenplay.elements.filter { $0.elementType == .sceneHeading }
        #expect(sceneHeadings.count > 0, "Should extract scene headings")

        // Should have dialogue
        let dialogue = screenplay.elements.filter { $0.elementType == .dialogue }
        #expect(dialogue.count > 0, "Should extract dialogue")

        // Should have action
        let action = screenplay.elements.filter { $0.elementType == .action }
        #expect(action.count > 0, "Should extract action")

        print("✅ BULLITT.pdf - Scenes: \(sceneHeadings.count), Dialogue: \(dialogue.count), Action: \(action.count)")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Extract from TV pilot script")
    func testTVPilotExtraction() async throws {
        // TV scripts have different formatting
        let url = getFixture("Legion_1x01_-_Chapter_One.pdf")

        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Should extract content
        #expect(screenplay.elements.count > 20)

        // Should have various element types
        let elementTypes = Set(screenplay.elements.map { $0.elementType })
        #expect(elementTypes.count > 1, "Should have multiple element types")

        print("✅ Legion pilot - \(screenplay.elements.count) elements, \(elementTypes.count) types")
    }

    // MARK: - Error Handling Tests

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Handle missing PDF file")
    func testMissingFile() async throws {
        let url = URL(fileURLWithPath: "/nonexistent/file.pdf")

        await #expect(throws: PDFScreenplayParserError.self) {
            try await PDFScreenplayParser.parse(from: url)
        }
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Handle invalid file path")
    func testInvalidPath() async throws {
        // Try to open a non-PDF file as PDF
        let url = getFixture("test.fountain")

        // Should throw an error (either unableToOpenPDF or file not found)
        await #expect(throws: Error.self) {
            try await PDFScreenplayParser.parse(from: url)
        }
    }

    // MARK: - Progress Reporting Tests

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Progress reporting works")
    func testProgressReporting() async throws {
        actor ProgressCollector {
            var updates: [ProgressUpdate] = []

            func add(_ update: ProgressUpdate) {
                updates.append(update)
            }

            func getUpdates() -> [ProgressUpdate] {
                return updates
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: 100) { update in
            Task { await collector.add(update) }
        }

        let url = getFixture("ATTACK-THE-BLOCK.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url, progress: progress)

        // Wait a bit for async updates
        try await Task.sleep(for: .milliseconds(100))

        let updates = await collector.getUpdates()

        // Should have progress updates
        #expect(updates.count > 0, "Should report progress")

        // Should have updates from all phases
        let descriptions = updates.map { $0.description }
        let hasExtraction = descriptions.contains { $0.contains("Extracting") || $0.contains("Reading") }
        let hasConversion = descriptions.contains { $0.contains("Converting") || $0.contains("formatting") }
        let hasParsing = descriptions.contains { $0.contains("Parsing") }

        #expect(hasExtraction, "Should report extraction progress")
        #expect(hasConversion, "Should report conversion progress")
        #expect(hasParsing, "Should report parsing progress")

        print("✅ Progress updates: \(updates.count)")
        print("   Phases - Extraction: \(hasExtraction), Conversion: \(hasConversion), Parsing: \(hasParsing)")
    }

    // MARK: - Element Type Detection Tests

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Detect scene headings")
    func testSceneHeadingDetection() async throws {
        let url = getFixture("BULLITT.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        let sceneHeadings = screenplay.elements.filter { $0.elementType == .sceneHeading }

        // Should have multiple scene headings
        #expect(sceneHeadings.count > 5, "Should detect multiple scene headings")

        // Scene headings should contain INT or EXT
        let hasIntOrExt = sceneHeadings.contains { heading in
            heading.elementText.uppercased().contains("INT") ||
            heading.elementText.uppercased().contains("EXT")
        }
        #expect(hasIntOrExt, "Scene headings should contain INT/EXT")

        print("✅ Detected \(sceneHeadings.count) scene headings")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Detect character names")
    func testCharacterNameDetection() async throws {
        let url = getFixture("Heathers_1x01_-_Pilot.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        let characters = screenplay.elements.filter { $0.elementType == .character }

        // Should detect character names
        #expect(characters.count > 0, "Should detect character names")

        // Character names should be relatively short (not paragraphs)
        let allReasonableLength = characters.allSatisfy { $0.elementText.count < 50 }
        #expect(allReasonableLength, "Character names should be short")

        print("✅ Detected \(characters.count) character names")
    }

    // MARK: - Multiple PDF Tests

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Parse multiple screenplay PDFs")
    func testMultiplePDFs() async throws {
        let testFiles = [
            "ATTACK-THE-BLOCK.pdf",
            "BULLITT.pdf",
            "Heathers_1x01_-_Pilot.pdf"
        ]

        for filename in testFiles {
            let url = getFixture(filename)
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("⚠️  Skipping \(filename) - file not found")
                continue
            }

            let screenplay = try await PDFScreenplayParser.parse(from: url)

            #expect(screenplay.elements.count > 0, "\(filename) should have elements")

            print("✅ \(filename) - \(screenplay.elements.count) elements")
        }
    }

    // MARK: - Performance Tests

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Parse PDF in reasonable time")
    func testParsingPerformance() async throws {
        let url = getFixture("ATTACK-THE-BLOCK.pdf")

        let start = Date()
        let screenplay = try await PDFScreenplayParser.parse(from: url)
        let duration = Date().timeIntervalSince(start)

        // Should complete in under 30 seconds for a small PDF
        #expect(duration < 30.0, "Should parse in reasonable time")

        print("✅ Parsed in \(String(format: "%.2f", duration))s - \(screenplay.elements.count) elements")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Large PDF performance", .disabled("Large file - only run manually"))
    func testLargePDFPerformance() async throws {
        // Test with the largest file
        let url = getFixture("angels-with-dirty-faces-1938.pdf")

        let start = Date()
        let screenplay = try await PDFScreenplayParser.parse(from: url)
        let duration = Date().timeIntervalSince(start)

        // Should complete in under 2 minutes
        #expect(duration < 120.0, "Should parse large PDF in under 2 minutes")

        print("✅ Large PDF parsed in \(String(format: "%.2f", duration))s - \(screenplay.elements.count) elements")
    }

    // MARK: - Content Validation Tests

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Preserve screenplay content")
    func testContentPreservation() async throws {
        let url = getFixture("Legion_1x01_-_Chapter_One.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Should have reasonable content
        #expect(screenplay.elements.count > 10, "Should have substantial content")

        // Should not have empty elements
        let emptyElements = screenplay.elements.filter { $0.elementText.trimmingCharacters(in: .whitespaces).isEmpty }
        let emptyPercentage = Double(emptyElements.count) / Double(screenplay.elements.count)

        // Less than 10% of elements should be empty
        #expect(emptyPercentage < 0.1, "Should have minimal empty elements")

        print("✅ Content validation - \(screenplay.elements.count) elements, \(emptyElements.count) empty (\(String(format: "%.1f", emptyPercentage * 100))%)")
    }

    // MARK: - Format-Specific Tests

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Parse classic screenplay format")
    func testClassicFormat() async throws {
        // Older screenplay format
        let url = getFixture("angels-with-dirty-faces-1938.pdf")

        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Should extract content from classic format
        #expect(screenplay.elements.count > 0)

        print("✅ Classic format (1938) - \(screenplay.elements.count) elements")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Parse modern screenplay format")
    func testModernFormat() async throws {
        // Modern screenplay
        let url = getFixture("The Banshees of Inisherin.pdf")

        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Should extract content from modern format
        #expect(screenplay.elements.count > 0)

        print("✅ Modern format - \(screenplay.elements.count) elements")
    }
}
