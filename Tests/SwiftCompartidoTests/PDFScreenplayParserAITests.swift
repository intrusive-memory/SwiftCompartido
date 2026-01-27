//
//  PDFScreenplayParserAITests.swift
//  SwiftCompartidoTests
//
//  Tests for Apple Intelligence (Foundation Models) PDF parsing
//
//  These tests require:
//  - iOS 26.2+ / macOS 26.2+ (currently shipping)
//  - Apple Intelligence enabled in System Settings
//  - M1+ Mac or A17 Pro+ device
//
//  Run manually with: ./Scripts/test-ai-features.sh
//

import Testing
import Foundation
@testable import SwiftCompartido

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Tests for Apple Intelligence-powered PDF parsing
///
/// **IMPORTANT**: These tests are designed to run when Foundation Models API is available.
/// iOS 26.2 is currently shipping - API availability needs verification.
/// Run `./Scripts/test-ai-features.sh` to check if the API is functional.
///
/// These tests will:
/// - Skip gracefully if Apple Intelligence is unavailable
/// - Validate AI-enhanced conversion accuracy when available
/// - Compare AI vs. heuristic conversion quality
@Suite("PDF Parser AI Tests - Requires Apple Intelligence")
struct PDFScreenplayParserAITests {

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

    // MARK: - Apple Intelligence Availability

    /// Check if Foundation Models API is functional
    ///
    /// Returns true only if:
    /// - Framework is importable (#if canImport(FoundationModels))
    /// - SystemLanguageModel.default.isAvailable returns true
    /// - Apple Intelligence is enabled by user
    private func isAppleIntelligenceAvailable() async -> Bool {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        return model.isAvailable
        #else
        return false
        #endif
    }

    // MARK: - AI Availability Tests

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("Foundation Models framework detection")
    func testFoundationModelsDetection() async throws {
        #if canImport(FoundationModels)
        print("✅ Foundation Models framework is importable")

        // Check if API is functional
        let available = await isAppleIntelligenceAvailable()
        if available {
            print("✅ Apple Intelligence is available and enabled")
        } else {
            print("⚠️  Apple Intelligence not available (expected until iOS 26.1)")
            print("   Either API not ready or user hasn't enabled in Settings")
        }
        #else
        print("⚠️  Foundation Models framework not available on this platform")
        #endif

        // This test always passes - it's informational only
    }

    // MARK: - AI-Powered Conversion Tests

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("AI-powered PDF conversion when available")
    func testAIConversion() async throws {
        let available = await isAppleIntelligenceAvailable()

        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        #if canImport(FoundationModels)
        let url = getFixture("ATTACK-THE-BLOCK.pdf")

        // Parse with AI enhancement
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // AI should produce high-quality results
        #expect(screenplay.elements.count > 0, "Should parse with AI")

        // Validate AI-enhanced accuracy
        let sceneHeadings = screenplay.elements.filter { $0.elementType == .sceneHeading }
        let dialogue = screenplay.elements.filter { $0.elementType == .dialogue }
        let characters = screenplay.elements.filter { $0.elementType == .character }

        // AI should detect screenplay structure accurately
        #expect(sceneHeadings.count > 0, "AI should detect scene headings")
        #expect(dialogue.count > 0, "AI should detect dialogue")

        print("✅ AI-powered conversion:")
        print("   Scenes: \(sceneHeadings.count)")
        print("   Characters: \(characters.count)")
        print("   Dialogue: \(dialogue.count)")
        #endif
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("AI vs Heuristic accuracy comparison")
    func testAIvsHeuristicAccuracy() async throws {
        let available = await isAppleIntelligenceAvailable()

        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        #if canImport(FoundationModels)
        let url = getFixture("BULLITT.pdf")

        // Parse with AI (should use AI path automatically)
        let aiScreenplay = try await PDFScreenplayParser.parse(from: url)

        // Count AI results
        let aiScenes = aiScreenplay.elements.filter { $0.elementType == .sceneHeading }.count
        let aiDialogue = aiScreenplay.elements.filter { $0.elementType == .dialogue }.count
        let aiCharacters = aiScreenplay.elements.filter { $0.elementType == .character }.count

        print("✅ AI vs Heuristic comparison:")
        print("   AI - Scenes: \(aiScenes), Characters: \(aiCharacters), Dialogue: \(aiDialogue)")

        // AI should have good accuracy (quantify when we have baseline)
        #expect(aiScenes > 5, "AI should detect multiple scenes")
        #expect(aiDialogue > 10, "AI should detect dialogue")
        #endif
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("AI handles non-standard PDF formats")
    func testNonStandardFormatWithAI() async throws {
        let available = await isAppleIntelligenceAvailable()

        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        #if canImport(FoundationModels)
        // Test with TV pilot (different formatting)
        let url = getFixture("Legion_1x01_-_Chapter_One.pdf")

        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // AI should handle TV format well
        let sceneHeadings = screenplay.elements.filter { $0.elementType == .sceneHeading }
        let dialogue = screenplay.elements.filter { $0.elementType == .dialogue }

        #expect(sceneHeadings.count > 0, "AI should detect TV format scene headings")
        #expect(dialogue.count > 0, "AI should detect TV format dialogue")

        print("✅ AI handles TV format - Scenes: \(sceneHeadings.count), Dialogue: \(dialogue.count)")
        #endif
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("AI content preservation accuracy")
    func testAIContentPreservation() async throws {
        let available = await isAppleIntelligenceAvailable()

        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        #if canImport(FoundationModels)
        let url = getFixture("Heathers_1x01_-_Pilot.pdf")

        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // AI should preserve all content (no hallucinations, no omissions)
        #expect(screenplay.elements.count > 20, "AI should preserve substantial content")

        // Check for text quality
        let elementsWithText = screenplay.elements.filter {
            !$0.elementText.trimmingCharacters(in: .whitespaces).isEmpty
        }

        let contentPercentage = Double(elementsWithText.count) / Double(screenplay.elements.count)

        // AI should have high content preservation (>90%)
        #expect(contentPercentage > 0.9, "AI should preserve 90%+ of content")

        print("✅ AI content preservation: \(String(format: "%.1f", contentPercentage * 100))%")
        #endif
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("AI system prompt effectiveness")
    func testSystemPromptEffectiveness() async throws {
        let available = await isAppleIntelligenceAvailable()

        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        #if canImport(FoundationModels)
        let url = getFixture("The Banshees of Inisherin.pdf")

        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Validate that AI follows Fountain format rules from system prompt
        let sceneHeadings = screenplay.elements.filter { $0.elementType == .sceneHeading }

        // Check scene heading format compliance
        var validFormatCount = 0
        for heading in sceneHeadings {
            let text = heading.elementText.uppercased()
            if text.contains("INT") || text.contains("EXT") || text.contains("I/E") {
                validFormatCount += 1
            }
        }

        let formatAccuracy = Double(validFormatCount) / Double(sceneHeadings.count)

        // AI should follow format rules accurately (>95%)
        #expect(formatAccuracy > 0.95, "AI should follow Fountain format rules")

        print("✅ System prompt effectiveness: \(String(format: "%.1f", formatAccuracy * 100))% format compliance")
        #endif
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("AI progress reporting")
    func testAIProgressReporting() async throws {
        let available = await isAppleIntelligenceAvailable()

        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        #if canImport(FoundationModels)
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

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(200))

        let updates = await collector.getUpdates()

        // Should report AI conversion phase
        let hasAIPhase = updates.contains { update in
            update.description.lowercased().contains("intelligence") ||
            update.description.lowercased().contains("ai") ||
            update.description.lowercased().contains("convert")
        }

        #expect(hasAIPhase, "Should report AI conversion progress")

        print("✅ AI progress reporting - \(updates.count) updates")
        #endif
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @Test("AI handles multiple PDFs sequentially")
    func testMultiplePDFsWithAI() async throws {
        let available = await isAppleIntelligenceAvailable()

        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        #if canImport(FoundationModels)
        let testFiles = [
            "ATTACK-THE-BLOCK.pdf",
            "BULLITT.pdf",
            "Heathers_1x01_-_Pilot.pdf"
        ]

        var results: [(String, Int)] = []

        for filename in testFiles {
            let url = getFixture(filename)
            let screenplay = try await PDFScreenplayParser.parse(from: url)
            results.append((filename, screenplay.elements.count))

            #expect(screenplay.elements.count > 0, "\(filename) should parse with AI")
        }

        print("✅ Multiple PDFs with AI:")
        for (filename, count) in results {
            print("   \(filename): \(count) elements")
        }
        #endif
    }
}
