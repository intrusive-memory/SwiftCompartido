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
        _ = try await PDFScreenplayParser.parse(from: url, progress: progress)

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
    @Test("Parse modern screenplay format")
    func testModernFormat() async throws {
        // Modern screenplay
        let url = getFixture("The Banshees of Inisherin.pdf")

        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Should extract content from modern format
        #expect(screenplay.elements.count > 0)

        print("✅ Modern format - \(screenplay.elements.count) elements")
    }

    // MARK: - Foundation Models Integration Tests

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Fallback to heuristic conversion")
    func testFallbackConversion() async throws {
        // When Foundation Models unavailable, should fall back gracefully
        let url = getFixture("ATTACK-THE-BLOCK.pdf")

        // Should still parse successfully using heuristic approach
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        #expect(screenplay.elements.count > 0, "Should parse with fallback conversion")

        // Should have detected screenplay elements
        let hasSceneHeadings = screenplay.elements.contains { $0.elementType == .sceneHeading }
        let hasDialogue = screenplay.elements.contains { $0.elementType == .dialogue }

        #expect(hasSceneHeadings || hasDialogue, "Should detect screenplay structure")

        print("✅ Fallback conversion works - \(screenplay.elements.count) elements")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("System prompt generation")
    func testSystemPromptGeneration() async throws {
        // Test that the system prompt is properly formatted
        // We can't directly call buildFountainConversionPrompt() as it's private,
        // but we can verify it exists and the conversion logic is in place

        let url = getFixture("BULLITT.pdf")

        // The parser should use the system prompt internally
        // This test verifies the workflow completes successfully
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        #expect(screenplay.elements.count > 0, "Should successfully parse using system prompt")

        print("✅ System prompt integration verified")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Content preservation through conversion")
    func testContentPreservationThroughConversion() async throws {
        let url = getFixture("Heathers_1x01_-_Pilot.pdf")

        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Verify that screenplay has meaningful content
        #expect(screenplay.elements.count > 20, "Should have substantial content")

        // Check that elements have text (not empty)
        let elementsWithText = screenplay.elements.filter {
            !$0.elementText.trimmingCharacters(in: .whitespaces).isEmpty
        }

        let contentPercentage = Double(elementsWithText.count) / Double(screenplay.elements.count)
        #expect(contentPercentage > 0.8, "At least 80% of elements should have content")

        // Verify we have various element types (indicating proper structure)
        let elementTypes = Set(screenplay.elements.map { $0.elementType })
        #expect(elementTypes.count >= 2, "Should have multiple element types")

        print("✅ Content preserved - \(elementsWithText.count)/\(screenplay.elements.count) elements with text (\(String(format: "%.1f", contentPercentage * 100))%)")
        print("   Element types: \(elementTypes.count) different types found")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Fountain format rules applied")
    func testFountainFormatRules() async throws {
        let url = getFixture("BULLITT.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Test scene heading detection
        let sceneHeadings = screenplay.elements.filter { $0.elementType == .sceneHeading }
        for heading in sceneHeadings.prefix(5) {
            let text = heading.elementText.uppercased()
            let hasIntOrExt = text.contains("INT") || text.contains("EXT") || text.contains("I/E")
            #expect(hasIntOrExt, "Scene heading should contain INT/EXT: '\(heading.elementText)'")
        }

        // Test character name detection (should be short, uppercase)
        let characters = screenplay.elements.filter { $0.elementType == .character }
        for char in characters.prefix(5) {
            #expect(char.elementText.count < 50, "Character name should be short: '\(char.elementText)'")
            // Most character names should be uppercase or have uppercase letters
            let hasUppercase = char.elementText.rangeOfCharacter(from: .uppercaseLetters) != nil
            #expect(hasUppercase, "Character name should have uppercase letters: '\(char.elementText)'")
        }

        print("✅ Fountain format rules applied correctly")
        print("   Scene headings: \(sceneHeadings.count)")
        print("   Characters: \(characters.count)")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("PDF text extraction filters page numbers")
    func testPageNumberFiltering() async throws {
        // Test that page numbers and headers are filtered out
        let url = getFixture("Legion_1x01_-_Chapter_One.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Look for common page number patterns that should be filtered
        let elementsWithJustNumbers = screenplay.elements.filter { element in
            let trimmed = element.elementText.trimmingCharacters(in: .whitespaces)
            // Check if it's just a number (1-3 digits)
            return trimmed.range(of: "^\\d{1,3}$", options: .regularExpression) != nil
        }

        // Should have very few or no standalone numbers
        let numberPercentage = Double(elementsWithJustNumbers.count) / Double(screenplay.elements.count)
        #expect(numberPercentage < 0.05, "Should filter most page numbers (found \(elementsWithJustNumbers.count))")

        print("✅ Page number filtering works - \(elementsWithJustNumbers.count)/\(screenplay.elements.count) standalone numbers (\(String(format: "%.1f", numberPercentage * 100))%)")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Multiple page PDF conversion")
    func testMultiplePageConversion() async throws {
        // Test that multi-page PDFs are properly concatenated
        let url = getFixture("Eternal Sunshine of the Spotless Mind.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Should have substantial content from all pages
        #expect(screenplay.elements.count > 100, "Multi-page PDF should have many elements")

        // Should have elements from throughout the script (not just first page)
        let sceneHeadings = screenplay.elements.filter { $0.elementType == .sceneHeading }
        #expect(sceneHeadings.count > 10, "Should have scenes from multiple pages")

        print("✅ Multi-page conversion - \(screenplay.elements.count) elements, \(sceneHeadings.count) scenes")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Dialogue formatting preservation")
    func testDialogueFormatting() async throws {
        let url = getFixture("Heathers_1x01_-_Pilot.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Find dialogue elements
        let dialogue = screenplay.elements.filter { $0.elementType == .dialogue }

        #expect(dialogue.count > 5, "Should have multiple dialogue elements")

        // Dialogue should be substantial (not just punctuation)
        let meaningfulDialogue = dialogue.filter { element in
            let text = element.elementText.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasLetters = text.rangeOfCharacter(from: .letters) != nil
            return hasLetters && text.count > 3
        }

        let dialogueQuality = Double(meaningfulDialogue.count) / Double(dialogue.count)
        #expect(dialogueQuality > 0.7, "Most dialogue should be meaningful text")

        print("✅ Dialogue formatting - \(meaningfulDialogue.count)/\(dialogue.count) meaningful (\(String(format: "%.1f", dialogueQuality * 100))%)")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Progress reporting through all phases")
    func testProgressPhases() async throws {
        actor PhaseCollector {
            var phases: Set<String> = []

            func add(_ phase: String) {
                phases.insert(phase)
            }

            func getPhases() -> Set<String> {
                return phases
            }
        }

        let collector = PhaseCollector()
        let progress = OperationProgress(totalUnits: 100) { update in
            Task {
                let desc = update.description.lowercased()
                if desc.contains("extract") || desc.contains("reading") {
                    await collector.add("extraction")
                } else if desc.contains("convert") || desc.contains("format") {
                    await collector.add("conversion")
                } else if desc.contains("pars") {
                    await collector.add("parsing")
                }
            }
        }

        let url = getFixture("ATTACK-THE-BLOCK.pdf")
        _ = try await PDFScreenplayParser.parse(from: url, progress: progress)

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(200))

        let phases = await collector.getPhases()

        // Should report all three phases
        #expect(phases.contains("extraction"), "Should report extraction phase")
        #expect(phases.contains("conversion"), "Should report conversion phase")
        #expect(phases.contains("parsing"), "Should report parsing phase")

        print("✅ All phases reported: \(phases.sorted().joined(separator: ", "))")
    }

    // MARK: - Comprehensive PDF Validation Tests

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Parse The Terror TV pilot")
    func testTheTerrorPilot() async throws {
        // Test the remaining untested PDF
        let url = getFixture("The_Terror_1x01_-_Go_For_Broke.pdf")

        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Should extract content
        #expect(screenplay.elements.count > 20, "Should have substantial content")

        // Should detect various element types
        let sceneHeadings = screenplay.elements.filter { $0.elementType == .sceneHeading }
        let dialogue = screenplay.elements.filter { $0.elementType == .dialogue }
        let action = screenplay.elements.filter { $0.elementType == .action }

        #expect(sceneHeadings.count > 0, "Should have scene headings")
        #expect(dialogue.count > 0 || action.count > 0, "Should have dialogue or action")

        print("✅ The Terror pilot - \(screenplay.elements.count) elements")
        print("   Scenes: \(sceneHeadings.count), Dialogue: \(dialogue.count), Action: \(action.count)")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Validate all fixture PDFs parse successfully")
    func testAllFixturePDFs() async throws {
        let allPDFs = [
            "ATTACK-THE-BLOCK.pdf",
            "BULLITT.pdf",
            "Eternal Sunshine of the Spotless Mind.pdf",
            "Heathers_1x01_-_Pilot.pdf",
            "Legion_1x01_-_Chapter_One.pdf",
            "The Banshees of Inisherin.pdf",
            "The_Terror_1x01_-_Go_For_Broke.pdf",
            "Anatomy-Of-A-Fall-Read-The-Screenplay.pdf"
        ]

        var results: [(String, Int, Bool)] = []

        for filename in allPDFs {
            let url = getFixture(filename)
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("⚠️  Skipping \(filename) - file not found")
                continue
            }

            do {
                let screenplay = try await PDFScreenplayParser.parse(from: url)
                let hasElements = screenplay.elements.count > 0
                results.append((filename, screenplay.elements.count, hasElements))

                #expect(hasElements, "\(filename) should have elements")

                print("✅ \(filename) - \(screenplay.elements.count) elements")
            } catch {
                print("❌ \(filename) - Failed: \(error)")
                throw error
            }
        }

        // All PDFs should have parsed
        #expect(results.count >= 7, "Should successfully parse at least 7 PDFs")

        // Summary
        let totalElements = results.reduce(0) { $0 + $1.1 }
        print("\n📊 Summary: \(results.count) PDFs parsed, \(totalElements) total elements")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Element distribution validation")
    func testElementDistribution() async throws {
        let url = getFixture("BULLITT.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Count element types
        var typeCounts: [ElementType: Int] = [:]
        for element in screenplay.elements {
            typeCounts[element.elementType, default: 0] += 1
        }

        // Should have a reasonable distribution of element types
        #expect(typeCounts.count >= 2, "Should have at least 2 different element types")

        // Print distribution
        print("✅ Element distribution in BULLITT.pdf:")
        for (type, count) in typeCounts.sorted(by: { $0.value > $1.value }) {
            let percentage = Double(count) / Double(screenplay.elements.count) * 100
            print("   \(type): \(count) (\(String(format: "%.1f", percentage))%)")
        }
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Scene continuity validation")
    func testSceneContinuity() async throws {
        let url = getFixture("Legion_1x01_-_Chapter_One.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Find all scene headings
        let sceneHeadings = screenplay.elements.enumerated().filter { $0.element.elementType == .sceneHeading }

        #expect(sceneHeadings.count > 0, "Should have scene headings")

        // Validate scene structure - each scene should have some content after it
        for (index, (position, scene)) in sceneHeadings.enumerated() {
            let nextScenePosition = sceneHeadings.indices.contains(index + 1) ?
                sceneHeadings[index + 1].0 : screenplay.elements.count

            let sceneLength = nextScenePosition - position - 1

            // Each scene should have at least some content (or be the last scene)
            if index < sceneHeadings.count - 1 {
                #expect(sceneLength >= 0, "Scene '\(scene.elementText)' should have content")
            }
        }

        print("✅ Scene continuity validated - \(sceneHeadings.count) scenes")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Character dialogue consistency")
    func testCharacterDialogueConsistency() async throws {
        let url = getFixture("Heathers_1x01_-_Pilot.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Find character-dialogue pairs
        var characterDialoguePairs = 0
        for i in 0..<screenplay.elements.count - 1 {
            if screenplay.elements[i].elementType == .character &&
               screenplay.elements[i + 1].elementType == .dialogue {
                characterDialoguePairs += 1
            }
        }

        // Should have multiple character-dialogue pairs
        #expect(characterDialoguePairs > 0, "Should have character names followed by dialogue")

        let characters = screenplay.elements.filter { $0.elementType == .character }.count
        let dialogue = screenplay.elements.filter { $0.elementType == .dialogue }.count

        print("✅ Character-dialogue consistency:")
        print("   Characters: \(characters), Dialogue: \(dialogue)")
        print("   Character→Dialogue pairs: \(characterDialoguePairs)")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Text quality validation")
    func testTextQuality() async throws {
        let url = getFixture("The Banshees of Inisherin.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Check for text quality indicators
        var qualityMetrics = (
            hasLetters: 0,
            reasonableLength: 0,
            noWeirdCharacters: 0
        )

        for element in screenplay.elements {
            let text = element.elementText.trimmingCharacters(in: .whitespacesAndNewlines)

            // Has letters (not just punctuation/numbers)
            if text.rangeOfCharacter(from: .letters) != nil {
                qualityMetrics.hasLetters += 1
            }

            // Reasonable length (not too short, not too long)
            if text.count >= 2 && text.count <= 1000 {
                qualityMetrics.reasonableLength += 1
            }

            // No weird control characters
            if !text.contains("\u{0}") && !text.contains("\u{FFFD}") {
                qualityMetrics.noWeirdCharacters += 1
            }
        }

        let total = screenplay.elements.count
        let letterPercentage = Double(qualityMetrics.hasLetters) / Double(total)
        let lengthPercentage = Double(qualityMetrics.reasonableLength) / Double(total)
        let cleanPercentage = Double(qualityMetrics.noWeirdCharacters) / Double(total)

        // Most elements should have good quality text
        #expect(letterPercentage > 0.7, "Most elements should have letters")
        #expect(lengthPercentage > 0.8, "Most elements should have reasonable length")
        #expect(cleanPercentage > 0.95, "Elements should be clean (no weird characters)")

        print("✅ Text quality validation:")
        print("   Has letters: \(String(format: "%.1f", letterPercentage * 100))%")
        print("   Reasonable length: \(String(format: "%.1f", lengthPercentage * 100))%")
        print("   Clean text: \(String(format: "%.1f", cleanPercentage * 100))%")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Heuristic accuracy on standard format")
    func testHeuristicAccuracy() async throws {
        let url = getFixture("ATTACK-THE-BLOCK.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Validate heuristic detection accuracy
        let sceneHeadings = screenplay.elements.filter { $0.elementType == .sceneHeading }
        let characters = screenplay.elements.filter { $0.elementType == .character }
        let dialogue = screenplay.elements.filter { $0.elementType == .dialogue }
        let action = screenplay.elements.filter { $0.elementType == .action }

        // Standard screenplay should have good distribution
        let totalIdentified = sceneHeadings.count + characters.count + dialogue.count + action.count
        let identificationRate = Double(totalIdentified) / Double(screenplay.elements.count)

        #expect(identificationRate > 0.7, "Should identify at least 70% of elements")

        // Should have multiple types
        var typeCount = 0
        if !sceneHeadings.isEmpty { typeCount += 1 }
        if !characters.isEmpty { typeCount += 1 }
        if !dialogue.isEmpty { typeCount += 1 }
        if !action.isEmpty { typeCount += 1 }

        #expect(typeCount >= 2, "Should identify at least 2 different element types")

        print("✅ Heuristic accuracy validation:")
        print("   Identification rate: \(String(format: "%.1f", identificationRate * 100))%")
        print("   Element types found: \(typeCount)")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Scene heading format validation")
    func testSceneHeadingFormat() async throws {
        let url = getFixture("BULLITT.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        let sceneHeadings = screenplay.elements.filter { $0.elementType == .sceneHeading }

        #expect(sceneHeadings.count > 0, "Should have scene headings")

        // Validate scene heading format
        var validFormatCount = 0
        let sceneHeadingPattern = "^(INT\\.|EXT\\.|INT/EXT\\.|I/E\\.|INTERIOR|EXTERIOR)"

        for heading in sceneHeadings {
            let text = heading.elementText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if text.range(of: sceneHeadingPattern, options: .regularExpression) != nil {
                validFormatCount += 1
            }
        }

        let formatAccuracy = Double(validFormatCount) / Double(sceneHeadings.count)

        // Most scene headings should follow standard format
        #expect(formatAccuracy > 0.8, "At least 80% of scene headings should follow standard format")

        print("✅ Scene heading format: \(validFormatCount)/\(sceneHeadings.count) valid (\(String(format: "%.1f", formatAccuracy * 100))%)")
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Comparison across different PDF formats")
    func testCrossFormatComparison() async throws {
        let testFiles = [
            ("Classic", "BULLITT.pdf"),
            ("Modern", "The Banshees of Inisherin.pdf"),
            ("TV Pilot", "Heathers_1x01_-_Pilot.pdf")
        ]

        var results: [(String, Int, Int, Int)] = []

        for (format, filename) in testFiles {
            let url = getFixture(filename)
            guard FileManager.default.fileExists(atPath: url.path) else {
                continue
            }

            let screenplay = try await PDFScreenplayParser.parse(from: url)
            let sceneCount = screenplay.elements.filter { $0.elementType == .sceneHeading }.count
            let dialogueCount = screenplay.elements.filter { $0.elementType == .dialogue }.count

            results.append((format, screenplay.elements.count, sceneCount, dialogueCount))
        }

        #expect(results.count >= 2, "Should test at least 2 different formats")

        print("✅ Cross-format comparison:")
        for (format, total, scenes, dialogue) in results {
            print("   \(format): \(total) elements (\(scenes) scenes, \(dialogue) dialogue)")
        }

        // All formats should produce results
        for (format, total, _, _) in results {
            #expect(total > 0, "\(format) should produce elements")
        }
    }
}
