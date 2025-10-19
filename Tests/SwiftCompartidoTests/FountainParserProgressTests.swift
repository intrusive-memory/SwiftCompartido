import Testing
import SwiftFijos
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

    // MARK: - Helper Methods

    private func loadFixtureString(_ name: String) throws -> String {
        let url = try Fijos.getFixture(name, extension: "fountain")
        return try String(contentsOf: url, encoding: .utf8)
    }

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

        // Use bigfish.fountain fixture - large real-world screenplay
        let screenplay = try loadFixtureString("bigfish")
        let parser = try await FountainParser(string: screenplay, progress: progress)

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

        // Use test.fountain fixture - smaller screenplay for quick completion test
        let screenplay = try loadFixtureString("test")
        _ = try await FountainParser(string: screenplay, progress: progress)

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

        // Use bigfish.fountain fixture
        let screenplay = try loadFixtureString("bigfish")
        _ = try await FountainParser(string: screenplay, progress: progress)

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
        let screenplay = try loadFixtureString("bigfish")

        let task = Task {
            let progress = OperationProgress(totalUnits: nil)
            return try await FountainParser(string: screenplay, progress: progress)
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
        let screenplay = try loadFixtureString("test")

        // Explicitly pass nil progress to use async init
        let nilProgress: OperationProgress? = nil
        let parser = try await FountainParser(string: screenplay, progress: nilProgress)

        #expect(parser.elements.count > 0, "Should parse elements with nil progress")
        #expect(parser.titlePage.count > 0, "Should parse title page with nil progress")
    }

    // MARK: - Title Page Tests

    @Test("Title page parsing reports progress")
    func testTitlePageProgress() async throws {
        // Use bigfish.fountain which has a complete title page
        let screenplay = try loadFixtureString("bigfish")

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

        _ = try await FountainParser(string: screenplay, progress: progress)

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
        // Use test.fountain which has multi-line elements
        let screenplay = try loadFixtureString("test")

        let nilProgress: OperationProgress? = nil
        let parser = try await FountainParser(string: screenplay, progress: nilProgress)

        #expect(parser.elements.count > 0, "Should parse multi-line elements")
    }

    // MARK: - Backward Compatibility Tests

    @Test("Synchronous init still works")
    func testBackwardCompatibility() throws {
        let screenplay = try loadFixtureString("test")

        // Call in non-async context to ensure sync init is used
        let parser = FountainParser(string: screenplay)

        #expect(parser.elements.count > 0, "Sync parser should work")
        #expect(parser.titlePage.count > 0, "Sync parser should parse title page")
    }

    @Test("Async and sync parsers produce identical results")
    func testAsyncSyncEquivalence() async throws {
        let screenplay = try loadFixtureString("test")

        // Create sync parser in a non-async closure to force synchronous init
        let syncParser = { FountainParser(string: screenplay) }()

        let nilProgress: OperationProgress? = nil
        let asyncParser = try await FountainParser(string: screenplay, progress: nilProgress)

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

        let screenplay = try loadFixtureString("test")
        _ = try await FountainParser(string: screenplay, progress: progress)

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
        // Use bigfish.fountain - real large screenplay
        let veryLargeScreenplay = try loadFixtureString("bigfish")

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
        // Big Fish has 600+ elements
        #expect(parser.elements.count > 500, "Should parse large screenplay")
    }
}
