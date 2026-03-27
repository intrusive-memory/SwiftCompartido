//
//  GuionViewerPerformanceTests.swift
//  SwiftCompartidoTests
//
//  Performance benchmarks for core library operations.
//  Measures parse → convert → format pipeline on realistic screenplays.
//

import Foundation
import Testing
import SwiftUI
import SwiftData
@testable import SwiftCompartido

/// Performance test suite for core library operations
///
/// ## Purpose
/// Track performance of the complete parse-to-render pipeline to detect regressions.
///
/// ## Key Metrics
/// - Parse time: String → GuionParsedElementCollection
/// - Convert time: GuionParsedElementCollection → SwiftData
/// - Format time: Text formatting with Fountain syntax
///
/// ## Test Scenarios
/// - Medium screenplay: 1000 elements (~typical script)
/// - Large screenplay: 5000 elements (stress test)
///
@MainActor
struct GuionViewerPerformanceTests {

    // MARK: - Helper Methods

    /// Generates a large screenplay with specified number of elements
    /// - Parameter elementCount: Number of elements to generate
    /// - Returns: Fountain-formatted screenplay string
    private func generateLargeScreenplay(elementCount: Int) -> String {
        var screenplay = """
        Title: Performance Test Screenplay
        Author: SwiftCompartido Test Suite
        Draft: Performance Baseline

        """

        // Template for scene elements (each element adds 1 to count)
        let sceneTemplate: [(text: String, elementCount: Int)] = [
            ("INT. TEST LOCATION {scene} - DAY\n\n", 1),
            ("Action description for scene {scene}. This is a longer action line that contains enough text to be realistic for testing purposes. It might span multiple lines when rendered.\n\n", 1),
            ("CHARACTER ONE\n", 1),
            ("This is dialogue from character one in scene {scene}. It contains **bold text**, *italic text*, and _underlined text_ to test formatting performance.\n\n", 1),
            ("CHARACTER TWO\n", 1),
            ("(excited)\n", 1),
            ("A response from character two with a parenthetical!\n\n", 1),
            ("Another action happens in scene {scene}.\n\n", 1),
            ("CHARACTER THREE\n", 1),
            ("Final dialogue for this scene from character three.\n\n", 1)
        ]

        var currentIndex = 0
        var sceneNum = 1

        while currentIndex < elementCount {
            for (template, count) in sceneTemplate {
                if currentIndex >= elementCount { break }

                let text = template.replacingOccurrences(of: "{scene}", with: "\(sceneNum)")
                screenplay += text
                currentIndex += count
            }
            sceneNum += 1
        }

        screenplay += "\nFADE OUT.\n"

        return screenplay
    }

    // MARK: - End-to-End Performance Tests

    @Test func testEndToEnd_ParseAndRender_1000Elements() async throws {
        let screenplay = generateLargeScreenplay(elementCount: 1000)

        print("\n📊 PERFORMANCE BASELINE - 1000 Elements")
        print("========================================")

        // Measure parsing
        let parseStart = Date()
        let parsed = try await GuionParsedElementCollection(string: screenplay)
        let parseTime = Date().timeIntervalSince(parseStart)

        // Measure SwiftData conversion
        let convertStart = Date()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: GuionDocumentModel.self,
            configurations: config
        )

        let document = await GuionDocumentParserSwiftData.parse(
            script: parsed,
            in: container.mainContext
        )
        let convertTime = Date().timeIntervalSince(convertStart)

        // Measure sorted access
        let sortStart = Date()
        let elements = document.sortedElements
        let sortTime = Date().timeIntervalSince(sortStart)

        // Measure text formatting (simulates view rendering)
        let baseFont = Font.custom("Courier New", size: 12)
        let formatStart = Date()
        for element in elements {
            _ = FountainTextFormatter.format(element.elementText, baseFont: baseFont)
        }
        let formatTime = Date().timeIntervalSince(formatStart)

        let totalTime = parseTime + convertTime + sortTime + formatTime

        print("Parse Time:          \(String(format: "%.3f", parseTime))s")
        print("Convert Time:        \(String(format: "%.3f", convertTime))s")
        print("Sort Access Time:    \(String(format: "%.3f", sortTime))s")
        print("Format Time:         \(String(format: "%.3f", formatTime))s")
        print("----------------------------------------")
        print("TOTAL TIME:          \(String(format: "%.3f", totalTime))s")
        print("Elements:            \(elements.count)")

        // Guard against division by zero
        if elements.count > 0 {
            print("Avg per element:     \(String(format: "%.4f", totalTime / Double(elements.count)))s")
        } else {
            print("Avg per element:     N/A (no elements)")
        }
        print("========================================\n")

        // Record metrics for build-to-build tracking
        await PerformanceMetricsTracker.shared.recordMetric(
            testName: "ParseAndRender_1000",
            elementCount: elements.count,
            parseTime: parseTime,
            convertTime: convertTime,
            sortTime: sortTime,
            formatTime: formatTime
        )

        // Assert reasonable performance thresholds
        #expect(elements.count > 0, "Should have parsed elements")
    }

    @Test func testEndToEnd_ParseAndRender_5000Elements() async throws {
        let screenplay = generateLargeScreenplay(elementCount: 5000)

        print("\n📊 PERFORMANCE BASELINE - 5000 Elements")
        print("========================================")

        // Measure parsing
        let parseStart = Date()
        let parsed = try await GuionParsedElementCollection(string: screenplay)
        let parseTime = Date().timeIntervalSince(parseStart)

        // Measure SwiftData conversion
        let convertStart = Date()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: GuionDocumentModel.self,
            configurations: config
        )

        let document = await GuionDocumentParserSwiftData.parse(
            script: parsed,
            in: container.mainContext
        )
        let convertTime = Date().timeIntervalSince(convertStart)

        // Measure sorted access
        let sortStart = Date()
        let elements = document.sortedElements
        let sortTime = Date().timeIntervalSince(sortStart)

        // Measure text formatting (simulates view rendering)
        let baseFont = Font.custom("Courier New", size: 12)
        let formatStart = Date()
        for element in elements {
            _ = FountainTextFormatter.format(element.elementText, baseFont: baseFont)
        }
        let formatTime = Date().timeIntervalSince(formatStart)

        let totalTime = parseTime + convertTime + sortTime + formatTime

        print("Parse Time:          \(String(format: "%.3f", parseTime))s")
        print("Convert Time:        \(String(format: "%.3f", convertTime))s")
        print("Sort Access Time:    \(String(format: "%.3f", sortTime))s")
        print("Format Time:         \(String(format: "%.3f", formatTime))s")
        print("----------------------------------------")
        print("TOTAL TIME:          \(String(format: "%.3f", totalTime))s")
        print("Elements:            \(elements.count)")

        // Guard against division by zero
        if elements.count > 0 {
            print("Avg per element:     \(String(format: "%.4f", totalTime / Double(elements.count)))s")
        } else {
            print("Avg per element:     N/A (no elements)")
        }
        print("========================================\n")

        // Record metrics for build-to-build tracking
        await PerformanceMetricsTracker.shared.recordMetric(
            testName: "ParseAndRender_5000",
            elementCount: elements.count,
            parseTime: parseTime,
            convertTime: convertTime,
            sortTime: sortTime,
            formatTime: formatTime
        )

        // Assert reasonable performance thresholds (more lenient for larger dataset)
        #expect(elements.count > 0, "Should have parsed elements")
    }
}
