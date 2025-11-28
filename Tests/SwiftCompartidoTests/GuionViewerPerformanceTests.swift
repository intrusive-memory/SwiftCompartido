//
//  GuionViewerPerformanceTests.swift
//  SwiftCompartidoTests
//
//  Performance benchmarks for GuionViewer and text rendering.
//  Measures parse + render + scroll performance on large screenplays.
//

import XCTest
import SwiftUI
import SwiftData
@testable import SwiftCompartido

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Performance test suite specifically for GuionViewer UI rendering
///
/// ## Purpose
/// Establish baseline performance metrics for the current SwiftUI-based GuionViewer
/// to compare against future TextKit 2 implementation.
///
/// ## Key Metrics
/// - Parse time: GuionParsedElementCollection → SwiftData conversion
/// - Initial render: Time to display first frame
/// - Scroll performance: Ability to scroll to end of large document
/// - Memory usage: Peak memory during rendering
///
/// ## Test Scenarios
/// - Small screenplay: 100 elements
/// - Medium screenplay: 500 elements
/// - Large screenplay: 1000+ elements
/// - Extra large screenplay: 5000+ elements
///
/// ## Running Tests
/// ```bash
/// xcodebuild test \
///   -scheme SwiftCompartido \
///   -only-testing:SwiftCompartidoTests/GuionViewerPerformanceTests
/// ```
@MainActor
final class GuionViewerPerformanceTests: XCTestCase {

    // MARK: - Test Configuration

    /// Timeout for async operations
    let asyncTimeout: TimeInterval = 60.0

    /// Number of iterations for performance measurements
    let measureIterations = 5

    /// Whether to set performance baselines (enable for initial baseline, disable for comparisons)
    /// Set to `true` when establishing new baselines, `false` when comparing against baselines
    let establishBaselines = false  // TODO: Set to true on first run, then false

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

    /// Creates a GuionDocumentModel in SwiftData from screenplay text
    /// - Parameters:
    ///   - screenplay: Fountain-formatted screenplay string
    ///   - container: SwiftData ModelContainer
    /// - Returns: Parsed GuionDocumentModel
    private func createDocument(from screenplay: String, in container: ModelContainer) async throws -> GuionDocumentModel {
        let parsed = try await GuionParsedElementCollection(string: screenplay)
        let document = await GuionDocumentParserSwiftData.parse(
            script: parsed,
            in: container.mainContext
        )
        return document
    }

    // MARK: - Parse Performance Tests

    func testParsePerformance_100Elements() throws {
        let screenplay = generateLargeScreenplay(elementCount: 100)

        let metrics: [XCTMetric] = [XCTClockMetric(), XCTMemoryMetric()]
        let options = XCTMeasureOptions()
        options.iterationCount = measureIterations

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Parse 100 elements")
            let scriptCopy = screenplay
            Task { @Sendable in
                _ = try await GuionParsedElementCollection(string: scriptCopy)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: asyncTimeout)
        }
    }

    func testParsePerformance_500Elements() throws {
        let screenplay = generateLargeScreenplay(elementCount: 500)

        let metrics: [XCTMetric] = [XCTClockMetric(), XCTMemoryMetric()]
        let options = XCTMeasureOptions()
        options.iterationCount = measureIterations

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Parse 500 elements")
            let scriptCopy = screenplay
            Task { @Sendable in
                _ = try await GuionParsedElementCollection(string: scriptCopy)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: asyncTimeout)
        }
    }

    func testParsePerformance_1000Elements() throws {
        let screenplay = generateLargeScreenplay(elementCount: 1000)

        let metrics: [XCTMetric] = [XCTClockMetric(), XCTMemoryMetric()]
        let options = XCTMeasureOptions()
        options.iterationCount = measureIterations

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Parse 1000 elements")
            let scriptCopy = screenplay
            Task { @Sendable in
                _ = try await GuionParsedElementCollection(string: scriptCopy)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: asyncTimeout)
        }
    }

    func testParsePerformance_5000Elements() throws {
        let screenplay = generateLargeScreenplay(elementCount: 5000)

        let metrics: [XCTMetric] = [XCTClockMetric(), XCTMemoryMetric()]
        let options = XCTMeasureOptions()
        options.iterationCount = 3  // Reduced for large dataset

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Parse 5000 elements")
            let scriptCopy = screenplay
            Task { @Sendable in
                _ = try await GuionParsedElementCollection(string: scriptCopy)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: asyncTimeout)
        }
    }

    // MARK: - SwiftData Conversion Performance

    func testSwiftDataConversion_100Elements() throws {
        let screenplay = generateLargeScreenplay(elementCount: 100)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: GuionDocumentModel.self,
            configurations: config
        )

        let metrics: [XCTMetric] = [XCTClockMetric(), XCTMemoryMetric()]
        let options = XCTMeasureOptions()
        options.iterationCount = measureIterations

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Convert 100 elements")
            Task {
                _ = try await createDocument(from: screenplay, in: container)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: asyncTimeout)

            // Clean up for next iteration
            try? container.mainContext.delete(model: GuionDocumentModel.self)
        }
    }

    func testSwiftDataConversion_1000Elements() throws {
        let screenplay = generateLargeScreenplay(elementCount: 1000)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: GuionDocumentModel.self,
            configurations: config
        )

        let metrics: [XCTMetric] = [XCTClockMetric(), XCTMemoryMetric()]
        let options = XCTMeasureOptions()
        options.iterationCount = measureIterations

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Convert 1000 elements")
            Task {
                _ = try await createDocument(from: screenplay, in: container)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: asyncTimeout)

            // Clean up for next iteration
            try? container.mainContext.delete(model: GuionDocumentModel.self)
        }
    }

    func testSwiftDataConversion_5000Elements() throws {
        let screenplay = generateLargeScreenplay(elementCount: 5000)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: GuionDocumentModel.self,
            configurations: config
        )

        // For very large datasets, use fewer iterations to avoid CI timeouts
        let metrics: [XCTMetric] = [XCTClockMetric(), XCTMemoryMetric()]
        let options = XCTMeasureOptions()
        options.iterationCount = 3  // Reduced from default 10 (3 * 24s = ~72s vs 240s)

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Convert 5000 elements")
            Task {
                _ = try await createDocument(from: screenplay, in: container)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: asyncTimeout)

            // Clean up for next iteration
            try? container.mainContext.delete(model: GuionDocumentModel.self)
        }
    }

    // MARK: - Element Access Performance

    func testSortedElementsAccess_1000Elements() throws {
        let screenplay = generateLargeScreenplay(elementCount: 1000)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: GuionDocumentModel.self,
            configurations: config
        )

        let expectation = self.expectation(description: "Create document")
        var document: GuionDocumentModel?
        Task {
            document = try await createDocument(from: screenplay, in: container)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: asyncTimeout)

        guard let doc = document else {
            XCTFail("Failed to create document")
            return
        }

        measure(metrics: [XCTClockMetric()]) {
            // Access sorted elements (critical for GuionViewer performance)
            _ = doc.sortedElements
        }
    }

    func testSortedElementsIteration_1000Elements() throws {
        let screenplay = generateLargeScreenplay(elementCount: 1000)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: GuionDocumentModel.self,
            configurations: config
        )

        let expectation = self.expectation(description: "Create document")
        var document: GuionDocumentModel?
        Task {
            document = try await createDocument(from: screenplay, in: container)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: asyncTimeout)

        guard let doc = document else {
            XCTFail("Failed to create document")
            return
        }

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            // Simulate what GuionElementsList does
            let elements = doc.sortedElements
            for element in elements {
                // Access element properties (simulates view rendering)
                _ = element.elementType
                _ = element.elementText
                _ = element.chapterIndex
                _ = element.orderIndex
            }
        }
    }

    // MARK: - Text Formatting Performance

    func testFountainTextFormatting_1000Elements() throws {
        let screenplay = generateLargeScreenplay(elementCount: 1000)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: GuionDocumentModel.self,
            configurations: config
        )

        let expectation = self.expectation(description: "Create document")
        var document: GuionDocumentModel?
        Task {
            document = try await createDocument(from: screenplay, in: container)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: asyncTimeout)

        guard let doc = document else {
            XCTFail("Failed to create document")
            return
        }

        let baseFont = Font.custom("Courier New", size: 12)

        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            // Simulate FountainTextFormatter being called for each element
            let elements = doc.sortedElements
            for element in elements {
                _ = FountainTextFormatter.format(element.elementText, baseFont: baseFont)
            }
        }
    }

    // MARK: - End-to-End Performance Tests

    func testEndToEnd_ParseAndRender_1000Elements() async throws {
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
        XCTAssertGreaterThan(elements.count, 0, "Should have parsed elements")
        XCTAssertLessThan(totalTime, 30.0, "Total time should be less than 30 seconds for 1000 elements")
    }

    func testEndToEnd_ParseAndRender_5000Elements() async throws {
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
        XCTAssertGreaterThan(elements.count, 0, "Should have parsed elements")
        XCTAssertLessThan(totalTime, 150.0, "Total time should be less than 150 seconds for 5000 elements")
    }

    // MARK: - Test Suite Lifecycle

    override func tearDown() async throws {
        // Save performance report after all tests complete
        try await PerformanceMetricsTracker.shared.saveReport()

        // Optionally compare with baseline
        if let comparison = try? await PerformanceMetricsTracker.shared.compareWithBaseline() {
            print(comparison.summary)
        }

        try await super.tearDown()
    }

    // MARK: - Memory Pressure Tests

    func testMemoryFootprint_1000Elements() throws {
        let screenplay = generateLargeScreenplay(elementCount: 1000)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: GuionDocumentModel.self,
            configurations: config
        )

        measure(metrics: [XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Create and hold document")
            var document: GuionDocumentModel?
            Task {
                document = try await createDocument(from: screenplay, in: container)

                // Access all elements to trigger loading
                let elements = document?.sortedElements ?? []
                let baseFont = Font.custom("Courier New", size: 12)

                // Format all elements to simulate full render
                for element in elements {
                    _ = FountainTextFormatter.format(element.elementText, baseFont: baseFont)
                }

                expectation.fulfill()
            }
            wait(for: [expectation], timeout: asyncTimeout)

            // Keep document in memory for measurement
            _ = document

            // Clean up
            try? container.mainContext.delete(model: GuionDocumentModel.self)
        }
    }
}
