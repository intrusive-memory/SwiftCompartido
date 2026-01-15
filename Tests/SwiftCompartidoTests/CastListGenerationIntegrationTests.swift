//
//  CastListGenerationIntegrationTests.swift
//  SwiftCompartido
//
//  Integration tests for cast list generation with real screenplay fixtures
//

import Foundation
import Testing
@testable import SwiftCompartido

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Integration tests for AI-powered cast list generation using real screenplay files
///
/// **IMPORTANT**: These tests require Apple Intelligence to be enabled and will be skipped
/// if unavailable. They are part of the AITests test plan and should NOT run in CI.
///
/// To run these tests:
/// ```bash
/// ./Scripts/test-ai-features.sh --macos
/// ```
///
/// Requirements:
/// - iOS 26.2+ or macOS 26.0+
/// - Apple Intelligence enabled in System Settings
/// - M1+ Mac or A17 Pro+ device
///
/// These tests validate:
/// - Multiple file format support (Fountain, FDX, PDF)
/// - Character extraction accuracy
/// - Cast list structure and completeness
/// - Integration with real screenplay fixtures
@Suite("Cast List Generation Integration Tests (AI Required)", .tags(.ai))
struct CastListGenerationIntegrationTests {

    // MARK: - Helper Methods

    /// Check if Apple Intelligence is available
    private func isAppleIntelligenceAvailable() async -> Bool {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        return model.isAvailable
        #else
        return false
        #endif
    }

    /// Load and parse a screenplay fixture into a snapshot
    private func loadScreenplay(filename: String) async throws -> GuionDocumentSnapshot {
        let fixturesPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")

        let url = fixturesPath.appendingPathComponent(filename)

        // Parse the screenplay
        let screenplay = try await GuionParsedElementCollection(file: url.path)

        // Convert to snapshot
        return GuionDocumentSnapshot(from: screenplay)
    }

    // MARK: - Fountain Format Tests

    @Test("Generate cast list from Fountain screenplay - test.fountain")
    @available(iOS 26.2, macOS 26.0, *)
    func testCastListFromFountain() async throws {
        let available = await isAppleIntelligenceAvailable()
        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        let snapshot = try await loadScreenplay(filename: "test.fountain")

        let progress = OperationProgress(totalUnits: 100) { update in
            print("Progress (\(update.completedUnits)/\(update.totalUnits ?? 100)): \(update.description)")
        }

        let castList = try await snapshot.generateCastList(progress: progress)

        #expect(castList != nil, "Should generate cast list from Fountain file")
        guard let castList = castList else { return }

        print("\n📋 Cast List from test.fountain (\(castList.items.count) characters):")
        for member in castList.items {
            print("  • \(member.role): \(member.name)")
        }

        // Verify structure
        #expect(castList.title == "Cast List")
        #expect(!castList.items.isEmpty, "Cast list should contain characters")

        // Verify we got character names
        let roles = castList.items.map { $0.role }
        #expect(!roles.isEmpty, "Should extract character names")
    }

    @Test("Generate cast list from Big Fish screenplay")
    @available(iOS 26.2, macOS 26.0, *)
    func testCastListFromBigFish() async throws {
        let available = await isAppleIntelligenceAvailable()
        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        let snapshot = try await loadScreenplay(filename: "bigfish.fountain")

        let progress = OperationProgress(totalUnits: 100) { update in
            if update.completedUnits % 20 == 0 {
                print("Progress: \(update.description)")
            }
        }

        let castList = try await snapshot.generateCastList(progress: progress)

        #expect(castList != nil, "Should generate cast list from Big Fish")
        guard let castList = castList else { return }

        print("\n📋 Big Fish Cast List (\(castList.items.count) characters):")
        for (index, member) in castList.items.prefix(10).enumerated() {
            print("  \(index + 1). \(member.role): \(member.name)")
        }
        if castList.items.count > 10 {
            print("  ... and \(castList.items.count - 10) more characters")
        }

        // Big Fish is a feature-length screenplay with many characters
        #expect(castList.items.count >= 5, "Should identify at least 5 characters in Big Fish")
    }

    // MARK: - FDX Format Tests

    @Test("Generate cast list from Final Draft file - bigfish.fdx")
    @available(iOS 26.2, macOS 26.0, *)
    func testCastListFromFDX() async throws {
        let available = await isAppleIntelligenceAvailable()
        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        let snapshot = try await loadScreenplay(filename: "bigfish.fdx")

        let castList = try await snapshot.generateCastList(progress: nil)

        #expect(castList != nil, "Should generate cast list from FDX file")
        guard let castList = castList else { return }

        print("\n📋 Cast List from bigfish.fdx (\(castList.items.count) characters):")
        for member in castList.items.prefix(10) {
            print("  • \(member.role)")
        }

        #expect(castList.items.count >= 5, "Should identify multiple characters from FDX")
    }

    // MARK: - PDF Format Tests

    @Test("Generate cast list from PDF screenplay - ATTACK-THE-BLOCK.pdf")
    @available(iOS 26.2, macOS 26.0, *)
    func testCastListFromPDF() async throws {
        let available = await isAppleIntelligenceAvailable()
        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        let snapshot = try await loadScreenplay(filename: "ATTACK-THE-BLOCK.pdf")

        let progress = OperationProgress(totalUnits: 100) { update in
            if update.completedUnits % 20 == 0 {
                print("Progress: \(update.description)")
            }
        }

        let castList = try await snapshot.generateCastList(progress: progress)

        #expect(castList != nil, "Should generate cast list from PDF")
        guard let castList = castList else { return }

        print("\n📋 Cast List from ATTACK-THE-BLOCK.pdf (\(castList.items.count) characters):")
        for member in castList.items.prefix(10) {
            print("  • \(member.role): \(member.name)")
        }

        // Progress updates were reported via handler
        // (verified by print statements during test execution)

        // Attack the Block has multiple characters
        #expect(castList.items.count >= 3, "Should identify multiple characters from PDF")
    }

    @Test("Generate cast list from TV script PDF - Heathers pilot")
    @available(iOS 26.2, macOS 26.0, *)
    func testCastListFromTVScript() async throws {
        let available = await isAppleIntelligenceAvailable()
        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        let snapshot = try await loadScreenplay(filename: "Heathers_1x01_-_Pilot.pdf")

        let castList = try await snapshot.generateCastList(progress: nil)

        #expect(castList != nil, "Should generate cast list from TV script PDF")
        guard let castList = castList else { return }

        print("\n📋 Cast List from Heathers TV Pilot (\(castList.items.count) characters):")
        for member in castList.items.prefix(10) {
            print("  • \(member.role)")
        }

        // TV pilots typically have ensemble casts
        #expect(castList.items.count >= 4, "Should identify multiple characters from TV script")
    }

    // MARK: - Character Validation Tests

    @Test("Verify cast list contains expected characters - mr-mr-charles.fountain")
    @available(iOS 26.2, macOS 26.0, *)
    func testCharacterValidation() async throws {
        let available = await isAppleIntelligenceAvailable()
        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        let snapshot = try await loadScreenplay(filename: "mr-mr-charles.fountain")

        // First, check what characters are in the screenplay
        let expectedCharacters = snapshot.characters
        print("\n📝 Characters in mr-mr-charles.fountain: \(expectedCharacters.joined(separator: ", "))")

        let castList = try await snapshot.generateCastList(progress: nil)

        #expect(castList != nil, "Should generate cast list")
        guard let castList = castList else { return }

        print("\n📋 Generated Cast List (\(castList.items.count) characters):")
        for member in castList.items {
            print("  • \(member.role): \(member.name)")
        }

        // Verify all major characters were identified
        let generatedRoles = Set(castList.items.map { $0.role.uppercased() })
        let expectedSet = Set(expectedCharacters.map { $0.uppercased() })

        // AI should identify most characters (may miss very minor ones)
        let identifiedCount = generatedRoles.intersection(expectedSet).count
        let identificationRate = Double(identifiedCount) / Double(expectedSet.count)

        print("\n📊 Character Identification Rate: \(Int(identificationRate * 100))%")
        print("   Identified: \(identifiedCount) / \(expectedSet.count) characters")

        #expect(identificationRate >= 0.7, "Should identify at least 70% of characters")
    }

    // MARK: - Multiple Format Comparison

    @Test("Compare cast lists from same screenplay in different formats")
    @available(iOS 26.2, macOS 26.0, *)
    func testFormatComparison() async throws {
        let available = await isAppleIntelligenceAvailable()
        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        // Load Big Fish in both Fountain and FDX formats
        let fountainSnapshot = try await loadScreenplay(filename: "bigfish.fountain")
        let fdxSnapshot = try await loadScreenplay(filename: "bigfish.fdx")

        let fountainCastList = try await fountainSnapshot.generateCastList()
        let fdxCastList = try await fdxSnapshot.generateCastList()

        #expect(fountainCastList != nil && fdxCastList != nil,
                "Should generate cast lists from both formats")

        guard let fountain = fountainCastList, let fdx = fdxCastList else { return }

        print("\n📋 Big Fish Cast List Comparison:")
        print("   Fountain format: \(fountain.items.count) characters")
        print("   FDX format: \(fdx.items.count) characters")

        // Both should identify similar numbers of characters (within 20%)
        let diff = abs(fountain.items.count - fdx.items.count)
        let maxCount = max(fountain.items.count, fdx.items.count)
        let similarityRate = 1.0 - (Double(diff) / Double(maxCount))

        print("   Similarity: \(Int(similarityRate * 100))%")

        #expect(similarityRate >= 0.8,
                "Cast lists from different formats should be similar")
    }

    // MARK: - Edge Cases

    @Test("Handle screenplay with minimal dialogue")
    @available(iOS 26.2, macOS 26.0, *)
    func testMinimalDialogue() async throws {
        let available = await isAppleIntelligenceAvailable()
        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        // Create a minimal screenplay with very few characters
        var snapshot = GuionDocumentSnapshot(
            id: UUID(),
            filename: "minimal",
            title: "Minimal Screenplay"
        )

        snapshot.elements = [
            GuionElementSnapshot(
                id: UUID(),
                elementText: "INT. ROOM - DAY",
                elementType: .sceneHeading
            ),
            GuionElementSnapshot(
                id: UUID(),
                elementText: "PERSON",
                elementType: .character
            ),
            GuionElementSnapshot(
                id: UUID(),
                elementText: "Hello.",
                elementType: .dialogue
            ),
        ]

        let castList = try await snapshot.generateCastList(progress: nil)

        #expect(castList != nil, "Should handle minimal screenplay")
        guard let castList = castList else { return }

        print("\n📋 Minimal Screenplay Cast List (\(castList.items.count) characters):")
        for member in castList.items {
            print("  • \(member.role): \(member.name)")
        }

        #expect(castList.items.count >= 1, "Should identify at least one character")
    }

    @Test("Handle screenplay with no dialogue")
    @available(iOS 26.2, macOS 26.0, *)
    func testNoDialogue() async throws {
        let available = await isAppleIntelligenceAvailable()
        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        // Create a screenplay with only action (no dialogue)
        var snapshot = GuionDocumentSnapshot(
            id: UUID(),
            filename: "silent",
            title: "Silent Film"
        )

        snapshot.elements = [
            GuionElementSnapshot(
                id: UUID(),
                elementText: "EXT. DESERT - DAY",
                elementType: .sceneHeading
            ),
            GuionElementSnapshot(
                id: UUID(),
                elementText: "A lone figure walks across the empty desert.",
                elementType: .action
            ),
            GuionElementSnapshot(
                id: UUID(),
                elementText: "The sun beats down mercilessly.",
                elementType: .action
            ),
        ]

        let castList = try await snapshot.generateCastList(progress: nil)

        #expect(castList != nil, "Should handle screenplay without dialogue")
        guard let castList = castList else { return }

        print("\n📋 Silent Film Cast List (\(castList.items.count) characters):")
        for member in castList.items {
            print("  • \(member.role): \(member.name)")
        }

        // May have zero characters if no explicit names mentioned
        print("   Note: Silent films may have no named characters")
    }

    // MARK: - Performance Tests

    @Test("Cast list generation performance with large screenplay")
    @available(iOS 26.2, macOS 26.0, *)
    func testPerformance() async throws {
        let available = await isAppleIntelligenceAvailable()
        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        let snapshot = try await loadScreenplay(filename: "bigfish.fountain")

        let startTime = Date()
        let castList = try await snapshot.generateCastList(progress: nil)
        let duration = Date().timeIntervalSince(startTime)

        print("\n⏱️  Cast list generation time: \(String(format: "%.2f", duration)) seconds")

        #expect(castList != nil, "Should generate cast list")
        #expect(duration < 60.0, "Should complete within 60 seconds")

        if let castList = castList {
            print("   Generated \(castList.items.count) characters")
        }
    }

    // MARK: - Fallback Tests (No AI)

    @Test("Gracefully handle unavailable Apple Intelligence")
    @available(iOS 26.2, macOS 26.0, *)
    func testUnavailableAI() async throws {
        let snapshot = try await loadScreenplay(filename: "test.fountain")

        #if !canImport(FoundationModels)
        // On platforms without Foundation Models
        let castList = try await snapshot.generateCastList(progress: nil)
        #expect(castList == nil, "Should return nil when Foundation Models unavailable")
        #else
        // On platforms with Foundation Models but AI disabled
        let available = await isAppleIntelligenceAvailable()
        if !available {
            let castList = try await snapshot.generateCastList(progress: nil)
            #expect(castList == nil, "Should return nil when AI unavailable")
        }
        #endif
    }

    @Test("Compare AI cast list with simple character extraction")
    @available(iOS 26.2, macOS 26.0, *)
    func testAIvsSimpleExtraction() async throws {
        let available = await isAppleIntelligenceAvailable()
        guard available else {
            Issue.record(
                "⚠️ SKIPPED: Apple Intelligence not available. Enable Apple Intelligence in System Settings to run AI tests.",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
            )
            return
        }

        let snapshot = try await loadScreenplay(filename: "test.fountain")

        // Simple extraction (baseline)
        let simpleCharacters = snapshot.characters
        print("\n📝 Simple extraction: \(simpleCharacters.count) characters")
        print("   \(simpleCharacters.joined(separator: ", "))")

        // AI extraction
        let castList = try await snapshot.generateCastList(progress: nil)

        #expect(castList != nil, "Should generate AI cast list")
        guard let castList = castList else { return }

        print("\n📋 AI extraction: \(castList.items.count) characters")
        for member in castList.items {
            print("   • \(member.role): \(member.name)")
        }

        // AI should identify at least as many characters as simple extraction
        #expect(castList.items.count >= simpleCharacters.count - 1,
                "AI should identify most characters found by simple extraction")

        print("\n💡 AI Benefits:")
        print("   • Adds role descriptions")
        print("   • Ranks by importance")
        print("   • Understands context")
    }
}
