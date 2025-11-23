//
//  PerformanceTests.swift
//  SwiftCompartidoTests
//
//  Performance benchmarks for SwiftCompartido operations.
//  These tests establish baselines and measure optimization improvements.
//

import XCTest
import SwiftData
@testable import SwiftCompartido

/// Performance test suite for SwiftCompartido library
///
/// Measures critical operations across the library to establish performance
/// baselines and track optimization efforts.
///
/// ## Test Categories
/// - Parsing Performance (Fountain, FDX, PDF, Markdown, Highland, TextBundle)
/// - SwiftData Model Conversion
/// - Element Ordering and Retrieval
/// - File Reference Operations
/// - Generated Content Storage/Retrieval
/// - Concurrent Operations
/// - Memory Footprint
///
/// ## Running Performance Tests
/// ```bash
/// swift test --filter PerformanceTests
/// xcodebuild test -scheme SwiftCompartido -only-testing:SwiftCompartidoTests/PerformanceTests
/// ```
///
/// ## Metrics Tracked
/// - XCTClockMetric: Wall clock time
/// - XCTCPUMetric: CPU usage
/// - XCTMemoryMetric: Memory allocations
/// - XCTStorageMetric: Disk I/O
///
final class PerformanceTests: XCTestCase {

    // MARK: - Test Configuration

    /// Number of iterations for repeated operations
    let iterationCount = 100

    /// Baseline metrics structure for comparison
    struct PerformanceBaseline: Codable {
        // Parsing times
        var fountainParseTime: TimeInterval
        var fdxParseTime: TimeInterval
        var markdownParseTime: TimeInterval

        // Model operations
        var swiftDataConversionTime: TimeInterval
        var elementOrderingTime: TimeInterval
        var contentStorageTime: TimeInterval
        var contentRetrievalTime: TimeInterval

        // File operations
        var fileReferenceCreationTime: TimeInterval
        var securityScopedAccessTime: TimeInterval

        // Metadata
        var timestamp: Date
        var xcodeBuildNumber: String?
    }

    // MARK: - Parsing Performance

    func testFountainParsingPerformanceSmallFile() throws {
        // Small screenplay ~10KB
        let smallScript = """
        Title: Small Test Script
        Author: Performance Test

        = ACT I

        INT. SMALL ROOM - DAY

        A simple scene.

        CHARACTER
        A short line of dialogue.

        ANOTHER CHARACTER
        Another line.

        ACTION

        A brief action description.

        FADE OUT.
        """

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTCPUMetric(),
            XCTMemoryMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 100

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Parse small fountain")
            Task {
                _ = try await GuionParsedElementCollection(string: smallScript)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testFountainParsingPerformanceMediumFile() throws {
        // Medium screenplay ~50KB
        var mediumScript = """
        Title: Medium Test Script
        Author: Performance Test

        """

        // Generate 100 scenes
        for i in 1...100 {
            mediumScript += """

            INT. LOCATION \(i) - DAY

            Scene \(i) action description here. This adds some content to make
            the file larger and more realistic.

            CHARACTER \(i)
            Dialogue for scene \(i). This is a line that contains
            enough text to be realistic.

            """
        }

        mediumScript += "\nFADE OUT."

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTCPUMetric(),
            XCTMemoryMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 20

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Parse medium fountain")
            Task {
                _ = try await GuionParsedElementCollection(string: mediumScript)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10.0)
        }
    }

    func testMarkdownParsingPerformance() throws {
        let markdown = """
        ---
        title: Test Screenplay
        author: Test Author
        draft: First Draft
        ---

        # Act One

        ## Scene 1

        **INT. OFFICE - DAY**

        John sits at his desk.

        > **JOHN**
        > I need to finish this report.

        ## Scene 2

        **EXT. STREET - DAY**

        John walks down the street.

        """

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTMemoryMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 50

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Parse markdown")
            Task {
                _ = try await GuionParsedElementCollection(string: markdown)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5.0)
        }
    }

    // MARK: - SwiftData Conversion Performance

    func testSwiftDataModelConversionPerformance() throws {
        // Create a screenplay with multiple elements
        let script = """
        Title: Conversion Test

        INT. ROOM - DAY

        Scene one.

        CHARACTER ONE
        First dialogue.

        CHARACTER TWO
        Second dialogue.

        EXT. STREET - NIGHT

        Scene two.

        CHARACTER THREE
        Third dialogue.
        """

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: GuionDocumentModel.self,
            configurations: config
        )

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTCPUMetric(),
            XCTMemoryMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 20

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Convert to SwiftData")
            Task {
                let screenplay = try await GuionParsedElementCollection(string: script)
                _ = await GuionDocumentParserSwiftData.parse(
                    script: screenplay,
                    in: container.mainContext
                )
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10.0)
        }
    }

    // MARK: - Element Ordering Performance

    func testElementOrderingPerformance() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: GuionDocumentModel.self,
            configurations: config
        )

        // Create a document with 1000 elements
        let document = GuionDocumentModel(
            filename: "ordering_test.fountain",
            originalFormat: .fountain
        )

        for i in 0..<1000 {
            let element = GuionElementModel(
                elementText: "Element \(i)",
                elementType: .action,
                chapterIndex: i / 10,
                orderIndex: i % 10
            )
            element.document = document
            container.mainContext.insert(element)
        }

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTMemoryMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 50

        measure(metrics: metrics, options: options) {
            // Access sorted elements
            _ = document.sortedElements
        }
    }

    func testElementFilteringPerformance() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: GuionDocumentModel.self,
            configurations: config
        )

        // Create a document with mixed element types
        let document = GuionDocumentModel(
            filename: "filtering_test.fountain",
            originalFormat: .fountain
        )

        let elementTypes: [ElementType] = [
            .sceneHeading, .action, .dialogue, .character,
            .parenthetical, .transition, .section, .synopsis
        ]

        for i in 0..<500 {
            let element = GuionElementModel(
                elementText: "Element \(i)",
                elementType: elementTypes[i % elementTypes.count],
                chapterIndex: 0,
                orderIndex: i
            )
            element.document = document
            container.mainContext.insert(element)
        }

        let sortedElements = document.sortedElements

        measure(metrics: [XCTClockMetric()]) {
            // Filter by various criteria
            _ = sortedElements.filter { $0.elementType == .dialogue }
            _ = sortedElements.filter { $0.elementType == .sceneHeading }
            _ = sortedElements.filter { $0.elementText.contains("Element") }
        }
    }

    // MARK: - Generated Content Performance

    func testGeneratedContentStoragePerformance() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: TypedDataStorage.self,
            configurations: config
        )

        let testText = "This is a test of generated content storage performance."
        let textData = GeneratedTextData(
            text: testText,
            model: "test-model",
            provider: "test-provider"
        )

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTMemoryMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 50

        measure(metrics: metrics, options: options) {
            for i in 0..<20 {
                let record = TypedDataStorage(
                    id: UUID(),
                    providerId: "test-provider-\(i)",
                    requestorID: "requestor-\(i)",
                    data: textData,
                    prompt: "Test prompt \(i)"
                )
                container.mainContext.insert(record)
            }

            // Save all at once
            try? container.mainContext.save()

            // Delete for next iteration
            try? container.mainContext.delete(model: TypedDataStorage.self)
        }
    }

    func testGeneratedContentRetrievalPerformance() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: TypedDataStorage.self,
            configurations: config
        )

        // Pre-populate with 100 records
        for i in 0..<100 {
            let textData = GeneratedTextData(
                text: "Content \(i)",
                model: "model-\(i % 5)",
                provider: "provider-\(i % 3)"
            )
            let record = TypedDataStorage(
                id: UUID(),
                providerId: "provider-\(i % 3)",
                requestorID: "requestor-\(i)",
                data: textData,
                prompt: "Prompt \(i)"
            )
            container.mainContext.insert(record)
        }
        try! container.mainContext.save()

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTMemoryMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 50

        measure(metrics: metrics, options: options) {
            // Fetch with various predicates
            let descriptor1 = FetchDescriptor<TypedDataStorage>(
                predicate: #Predicate { $0.providerId == "provider-0" }
            )
            _ = try? container.mainContext.fetch(descriptor1)

            let descriptor2 = FetchDescriptor<TypedDataStorage>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            _ = try? container.mainContext.fetch(descriptor2)

            let descriptor3 = FetchDescriptor<TypedDataStorage>(
                predicate: #Predicate { $0.metadata.contentType == .text }
            )
            _ = try? container.mainContext.fetch(descriptor3)
        }
    }

    // MARK: - File Reference Performance

    func testFileReferenceCreationPerformance() {
        let testURL = URL(fileURLWithPath: "/tmp/test.fountain")

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for i in 0..<1000 {
                _ = TypedDataFileReference(
                    fileName: "test-\(i).fountain",
                    fileExtension: "fountain",
                    mimeType: "text/plain",
                    fileSize: 1024,
                    storageArea: .temporary(requestID: UUID())
                )
            }
        }
    }

    func testStorageAreaReferencePerformance() {
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<1000 {
                let requestID = UUID()
                _ = StorageAreaReference.temporary(requestID: requestID)
                _ = StorageAreaReference.persistent(subfolder: "test")
                _ = StorageAreaReference.cache(subfolder: "test")
            }
        }
    }

    // MARK: - Concurrent Operations Performance

    func testConcurrentParsingPerformance() throws {
        let script = """
        Title: Concurrent Test

        INT. ROOM - DAY

        A test scene.

        CHARACTER
        Test dialogue.
        """

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTCPUMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 10

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Concurrent parsing")
            expectation.expectedFulfillmentCount = 10

            Task {
                await withTaskGroup(of: Void.self) { group in
                    for _ in 0..<10 {
                        group.addTask {
                            do {
                                _ = try await GuionParsedElementCollection(string: script)
                                expectation.fulfill()
                            } catch {
                                XCTFail("Parsing failed: \(error)")
                            }
                        }
                    }
                }
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    // MARK: - Memory Footprint Tests

    func testLargeDocumentMemoryFootprint() throws {
        // Generate a large document with 10,000 elements
        var largeScript = "Title: Memory Test\n\n"
        for i in 0..<10000 {
            largeScript += """
            INT. LOCATION \(i) - DAY

            Element \(i)

            """
        }

        measure(metrics: [XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Parse large document")
            Task {
                _ = try await GuionParsedElementCollection(string: largeScript)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 30.0)
        }
    }

    func testSwiftDataMemoryFootprint() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: GuionDocumentModel.self,
            configurations: config
        )

        measure(metrics: [XCTMemoryMetric()]) {
            // Create 1000 documents with elements
            for docIndex in 0..<100 {
                let document = GuionDocumentModel(
                    filename: "doc_\(docIndex).fountain",
                    originalFormat: .fountain
                )

                for elemIndex in 0..<100 {
                    let element = GuionElementModel(
                        elementText: "Element \(elemIndex)",
                        elementType: .action,
                        chapterIndex: 0,
                        orderIndex: elemIndex
                    )
                    element.document = document
                    container.mainContext.insert(element)
                }

                container.mainContext.insert(document)
            }

            try? container.mainContext.save()

            // Clean up
            try? container.mainContext.delete(model: GuionDocumentModel.self)
        }
    }

    // MARK: - Baseline Recording & Comparison

    func testRecordPerformanceBaseline() throws {
        print("""

        ==========================================
        PERFORMANCE BASELINE RECORDING
        ==========================================
        """)

        let script = """
        Title: Baseline Test

        INT. ROOM - DAY

        Test content.

        CHARACTER
        Test dialogue.
        """

        // Measure Fountain parsing
        let fountainStart = Date()
        let fountainExpectation = self.expectation(description: "Fountain parse")
        var fountainTime: TimeInterval = 0
        Task {
            _ = try await GuionParsedElementCollection(string: script)
            fountainTime = Date().timeIntervalSince(fountainStart)
            fountainExpectation.fulfill()
        }
        wait(for: [fountainExpectation], timeout: 5.0)

        // Measure Markdown parsing
        let markdown = "# Test\n\nContent"
        let markdownStart = Date()
        let markdownExpectation = self.expectation(description: "Markdown parse")
        var markdownTime: TimeInterval = 0
        Task {
            _ = try await GuionParsedElementCollection(string: markdown)
            markdownTime = Date().timeIntervalSince(markdownStart)
            markdownExpectation.fulfill()
        }
        wait(for: [markdownExpectation], timeout: 5.0)

        // Measure SwiftData conversion
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: GuionDocumentModel.self,
            configurations: config
        )

        let conversionStart = Date()
        let conversionExpectation = self.expectation(description: "SwiftData conversion")
        var conversionTime: TimeInterval = 0
        Task {
            let screenplay = try await GuionParsedElementCollection(string: script)
            _ = await GuionDocumentParserSwiftData.parse(
                script: screenplay,
                in: container.mainContext
            )
            conversionTime = Date().timeIntervalSince(conversionStart)
            conversionExpectation.fulfill()
        }
        wait(for: [conversionExpectation], timeout: 10.0)

        // Measure other operations
        let document = GuionDocumentModel(filename: "test.fountain", originalFormat: .fountain)
        for i in 0..<100 {
            let element = GuionElementModel(
                elementText: "Element \(i)",
                elementType: .action,
                chapterIndex: 0,
                orderIndex: i
            )
            element.document = document
            container.mainContext.insert(element)
        }

        let orderingStart = Date()
        _ = document.sortedElements
        let orderingTime = Date().timeIntervalSince(orderingStart)

        let fileRefStart = Date()
        _ = TypedDataFileReference(
            fileName: "test.mp3",
            fileExtension: "mp3",
            mimeType: "audio/mpeg",
            fileSize: 1024,
            storageArea: .temporary(requestID: UUID())
        )
        let fileRefTime = Date().timeIntervalSince(fileRefStart)

        let textData = GeneratedTextData(text: "Test", model: "test", provider: "test")
        let storageStart = Date()
        let record = TypedDataStorage(
            id: UUID(),
            providerId: "test",
            requestorID: "test",
            data: textData,
            prompt: "test"
        )
        container.mainContext.insert(record)
        try? container.mainContext.save()
        let storageTime = Date().timeIntervalSince(storageStart)

        let retrievalStart = Date()
        let descriptor = FetchDescriptor<TypedDataStorage>()
        _ = try? container.mainContext.fetch(descriptor)
        let retrievalTime = Date().timeIntervalSince(retrievalStart)

        let baseline = PerformanceBaseline(
            fountainParseTime: fountainTime,
            fdxParseTime: 0.0, // Would need FDX file
            markdownParseTime: markdownTime,
            swiftDataConversionTime: conversionTime,
            elementOrderingTime: orderingTime,
            contentStorageTime: storageTime,
            contentRetrievalTime: retrievalTime,
            fileReferenceCreationTime: fileRefTime,
            securityScopedAccessTime: 0.0, // Platform-specific
            timestamp: Date(),
            xcodeBuildNumber: ProcessInfo.processInfo.operatingSystemVersionString
        )

        print("""
        Fountain Parse Time:      \(String(format: "%.4f", fountainTime))s
        Markdown Parse Time:      \(String(format: "%.4f", markdownTime))s
        SwiftData Conversion:     \(String(format: "%.4f", conversionTime))s
        Element Ordering:         \(String(format: "%.6f", orderingTime))s
        Content Storage:          \(String(format: "%.6f", storageTime))s
        Content Retrieval:        \(String(format: "%.6f", retrievalTime))s
        File Reference Creation:  \(String(format: "%.6f", fileRefTime))s
        Timestamp:                \(baseline.timestamp)
        OS Version:               \(baseline.xcodeBuildNumber ?? "Unknown")
        ==========================================

        """)

        // Save baseline
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(baseline) {
            let tempDir = FileManager.default.temporaryDirectory
            let baselineFile = tempDir.appendingPathComponent("swiftcompartido_performance_baseline.json")
            try? data.write(to: baselineFile)
            print("Baseline saved to: \(baselineFile.path)")
        }
    }
}
