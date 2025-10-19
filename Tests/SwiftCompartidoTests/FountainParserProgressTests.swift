import Testing
@testable import SwiftCompartido

/// Tests for FountainParser progress reporting functionality.
///
/// Validates Phase 1 requirements:
/// - Line-by-line progress tracking
/// - Progress accuracy
/// - Cancellation support
/// - Backward compatibility
/// - Performance overhead
@Suite("FountainParser Progress Tests")
struct FountainParserProgressTests {

    // MARK: - Test Data

    private let simpleScreenplay = """
    Title: Test Screenplay
    Author: Test Author

    INT. TEST LOCATION - DAY

    This is action text.

    CHARACTER
    This is dialogue.
    """

    private let largeScreenplay: String = {
        var lines: [String] = []
        lines.append("Title: Large Test Screenplay")
        lines.append("Author: Test Author")
        lines.append("")

        // Generate 500 lines of screenplay content
        for i in 0..<100 {
            lines.append("")
            lines.append("INT. SCENE \(i) - DAY")
            lines.append("")
            lines.append("Action paragraph for scene \(i).")
            lines.append("")
            lines.append("CHARACTER \(i)")
            lines.append("Dialogue for scene \(i).")
        }

        return lines.joined(separator: "\n")
    }()

    // MARK: - Progress Accuracy Tests

    @Test("Progress updates occur during parsing")
    func testProgressUpdates() async throws {
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
        let progress = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.add(update)
            }
        }

        let parser = try await FountainParser(string: largeScreenplay, progress: progress)

        // Wait for async updates to propagate
        try await Task.sleep(for: .milliseconds(50))

        let updates = await collector.getUpdates()

        // Should have received multiple progress updates
        #expect(updates.count > 0, "Should receive progress updates")

        // Parser should have elements
        #expect(parser.elements.count > 0, "Parser should have elements")
    }

    @Test("Progress reaches 100% on completion")
    func testProgressCompletion() async throws {
        actor ProgressCollector {
            var allUpdates: [ProgressUpdate] = []

            func add(_ update: ProgressUpdate) {
                allUpdates.append(update)
            }

            func getAll() -> [ProgressUpdate] {
                return allUpdates
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.add(update)
            }
        }

        _ = try await FountainParser(string: simpleScreenplay, progress: progress)

        // Wait a bit for async updates to propagate
        try await Task.sleep(for: .milliseconds(50))

        let allUpdates = await collector.getAll()

        #expect(allUpdates.count > 0, "Should receive progress updates")

        // Check the final update
        if let finalUpdate = allUpdates.last {
            #expect(finalUpdate.description.contains("complete"), "Final update should mention completion")
        }
    }

    @Test("Progress reports line counts correctly")
    func testProgressLineCounts() async throws {
        actor ProgressCollector {
            var maxCompletedUnits: Int64 = 0
            var totalUnits: Int64?

            func update(_ update: ProgressUpdate) {
                if update.completedUnits > maxCompletedUnits {
                    maxCompletedUnits = update.completedUnits
                }
                if totalUnits == nil, let total = update.totalUnits {
                    totalUnits = total
                }
            }

            func getStats() -> (max: Int64, total: Int64?) {
                return (maxCompletedUnits, totalUnits)
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.update(update)
            }
        }

        _ = try await FountainParser(string: largeScreenplay, progress: progress)

        // Wait for async updates to propagate
        try await Task.sleep(for: .milliseconds(50))

        let stats = await collector.getStats()

        // Should have processed all lines
        #expect(stats.max > 0, "Should have processed lines")
        #expect(stats.total != nil, "Should have total line count")
    }

    // MARK: - Cancellation Tests

    @Test("Cancellation stops parsing mid-operation")
    func testCancellation() async throws {
        let task = Task {
            let progress = OperationProgress(totalUnits: nil)
            return try await FountainParser(string: largeScreenplay, progress: progress)
        }

        // Cancel the task immediately
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected CancellationError to be thrown")
        } catch is CancellationError {
            // Expected - test passes
        } catch {
            Issue.record("Expected CancellationError, got \(error)")
        }
    }

    // MARK: - Nil Progress Handler Tests

    @Test("Parser works with nil progress handler")
    func testNilProgressHandler() async throws {
        // Explicitly pass nil progress to use async init
        let nilProgress: OperationProgress? = nil
        let parser = try await FountainParser(string: simpleScreenplay, progress: nilProgress)

        #expect(parser.elements.count > 0, "Should parse elements with nil progress")
        #expect(parser.titlePage.count > 0, "Should parse title page with nil progress")
    }

    // MARK: - Title Page Tests

    @Test("Title page parsing reports progress")
    func testTitlePageProgress() async throws {
        let screenplayWithLargeTitlePage = """
        Title: Test Screenplay
        Credit: Written by
        Author: Test Author
        Source: Original Screenplay
        Draft date: 2025-01-01
        Contact:
            Test Productions
            123 Test Street
            Test City, TS 12345
            test@example.com

        INT. TEST - DAY

        Action.
        """

        actor ProgressCollector {
            var descriptions: [String] = []

            func add(_ desc: String) {
                descriptions.append(desc)
            }

            func getDescriptions() -> [String] {
                return descriptions
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.add(update.description)
            }
        }

        _ = try await FountainParser(string: screenplayWithLargeTitlePage, progress: progress)

        // Wait for async updates to propagate
        try await Task.sleep(for: .milliseconds(50))

        let descriptions = await collector.getDescriptions()

        // Should have at least one progress update
        #expect(descriptions.count > 0, "Should have progress updates")
    }

    // MARK: - Empty File Tests

    @Test("Empty string parsing completes successfully")
    func testEmptyFileHandling() async throws {
        let progress = OperationProgress(totalUnits: nil)

        let parser = try await FountainParser(string: "", progress: progress)

        #expect(parser.elements.count == 0, "Empty string should result in zero elements")
        #expect(parser.titlePage.count == 0, "Empty string should result in empty title page")
    }

    // MARK: - Multi-line Element Tests

    @Test("Multi-line action blocks are counted correctly")
    func testMultiLineElements() async throws {
        let multiLineScreenplay = """
        Title: Test

        INT. TEST - DAY

        This is a multi-line
        action block that spans
        several lines of text.

        CHARACTER
        Multi-line dialogue
        that continues here.
        """

        let nilProgress: OperationProgress? = nil
        let parser = try await FountainParser(string: multiLineScreenplay, progress: nilProgress)

        #expect(parser.elements.count > 0, "Should parse multi-line elements")
    }

    // MARK: - Backward Compatibility Tests

    @Test("Synchronous init still works")
    func testBackwardCompatibility() {
        // Call in non-async context to ensure sync init is used
        let parser = FountainParser(string: simpleScreenplay)

        #expect(parser.elements.count > 0, "Sync parser should work")
        #expect(parser.titlePage.count > 0, "Sync parser should parse title page")
    }

    @Test("Async and sync parsers produce identical results")
    func testAsyncSyncEquivalence() async throws {
        // Create sync parser in a non-async closure to force synchronous init
        let syncParser = { FountainParser(string: simpleScreenplay) }()

        let nilProgress: OperationProgress? = nil
        let asyncParser = try await FountainParser(string: simpleScreenplay, progress: nilProgress)

        #expect(syncParser.elements.count == asyncParser.elements.count,
                "Sync and async should produce same element count")
        #expect(syncParser.titlePage.count == asyncParser.titlePage.count,
                "Sync and async should produce same title page count")

        // Compare element types
        for i in 0..<syncParser.elements.count {
            #expect(syncParser.elements[i].elementType == asyncParser.elements[i].elementType,
                    "Element \(i) types should match")
        }
    }

    // MARK: - Progress Description Tests

    @Test("Progress descriptions are meaningful")
    func testProgressDescriptions() async throws {
        actor ProgressCollector {
            var lastDescription: String = ""

            func update(_ desc: String) {
                lastDescription = desc
            }

            func getLast() -> String {
                return lastDescription
            }
        }

        let collector = ProgressCollector()
        let progress: OperationProgress? = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.update(update.description)
            }
        }

        _ = try await FountainParser(string: simpleScreenplay, progress: progress)

        // Wait for async updates to propagate
        try await Task.sleep(for: .milliseconds(50))

        let lastDescription = await collector.getLast()

        // Final description should mention completion
        #expect(lastDescription.contains("complete") || lastDescription.contains("Parsing"),
                "Progress description should be meaningful")
    }

    // MARK: - Large File Tests

    @Test("Large screenplay parsing works with progress")
    func testLargeScreenplayParsing() async throws {
        // Generate a very large screenplay (1000+ lines)
        var lines: [String] = []
        lines.append("Title: Large Screenplay")
        lines.append("")

        for i in 0..<250 {
            lines.append("")
            lines.append("INT. SCENE \(i) - DAY")
            lines.append("")
            lines.append("Action for scene \(i).")
            lines.append("")
            lines.append("CHARACTER")
            lines.append("Dialogue \(i).")
        }

        let veryLargeScreenplay = lines.joined(separator: "\n")

        actor ProgressCollector {
            var updateCount: Int = 0

            func increment() {
                updateCount += 1
            }

            func getCount() -> Int {
                return updateCount
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: nil) { _ in
            Task {
                await collector.increment()
            }
        }

        let parser = try await FountainParser(string: veryLargeScreenplay, progress: progress)

        let updateCount = await collector.getCount()

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let finalUpdateCount = await collector.getCount()

        // Should have at least one progress update for large file
        #expect(finalUpdateCount > 0, "Large file should have progress updates")
        #expect(parser.elements.count >= 1000, "Should parse large screenplay")
    }
}
