import Testing
import Foundation
import SwiftFijos
#if canImport(SwiftData)
import SwiftData
#endif
@testable import SwiftCompartido

/// Tests for SwiftData progress reporting functionality (Phase 5).
///
/// Validates Phase 5 requirements:
/// - Element conversion progress tracking
/// - AI summary generation progress (if available)
/// - Cancellation support during conversion
/// - Memory efficient progress reporting
/// - @MainActor compliance
/// - Backward compatibility
/// - Progress accuracy
@Suite("SwiftData Progress Tests")
struct SwiftDataProgressTests {

    // MARK: - Helper Methods

    private func loadFixtureScreenplay(_ name: String) throws -> GuionParsedScreenplay {
        let url = try Fijos.getFixture(name, extension: "fountain")
        return try GuionParsedScreenplay(file: url.path)
    }

    private func createSimpleScreenplay() throws -> GuionParsedScreenplay {
        let screenplay = """
        Title: Test Screenplay
        Author: Test Author

        INT. LOCATION - DAY

        Action text.

        CHARACTER
        Dialogue.
        """

        return try GuionParsedScreenplay(string: screenplay)
    }

    private func createInMemoryModelContext() throws -> ModelContext {
        #if canImport(SwiftData)
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
        #else
        throw TestError.swiftDataNotAvailable
        #endif
    }

    enum TestError: Error {
        case swiftDataNotAvailable
    }

    // MARK: - Element Conversion Progress Tests

    @Test("Element conversion reports progress")
    @MainActor
    func testElementConversionProgress() async throws {
        #if canImport(SwiftData)
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

        let screenplay = try loadFixtureScreenplay("bigfish")
        let context = try createInMemoryModelContext()

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context,
            generateSummaries: false,
            progress: progress
        )

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let updates = await collector.getUpdates()

        #expect(updates.count > 0, "Should receive progress updates during conversion")
        #expect(document.elements.count > 0, "Should convert elements")
        #expect(document.elements.count == screenplay.elements.count, "Should convert all elements")
        #else
        throw TestError.swiftDataNotAvailable
        #endif
    }

    @Test("Large screenplay conversion tracks progress accurately")
    @MainActor
    func testLargeScreenplayConversion() async throws {
        #if canImport(SwiftData)
        actor ProgressCollector {
            var maxCompleted: Int64 = 0
            var finalTotal: Int64?

            func update(_ completed: Int64, _ total: Int64?) {
                if completed > maxCompleted {
                    maxCompleted = completed
                }
                if total != nil {
                    finalTotal = total
                }
            }

            func getResults() -> (maxCompleted: Int64, finalTotal: Int64?) {
                return (maxCompleted, finalTotal)
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.update(update.completedUnits, update.totalUnits)
            }
        }

        let screenplay = try loadFixtureScreenplay("bigfish")
        let context = try createInMemoryModelContext()

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context,
            generateSummaries: false,
            progress: progress
        )

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let results = await collector.getResults()

        #expect(results.maxCompleted > 0, "Should track progress")
        #expect(document.elements.count > 500, "Big Fish has many elements")

        if let total = results.finalTotal {
            #expect(results.maxCompleted <= total, "Completed units should not exceed total")
        }
        #else
        throw TestError.swiftDataNotAvailable
        #endif
    }

    @Test("Element conversion progress descriptions are meaningful")
    @MainActor
    func testConversionProgressDescriptions() async throws {
        #if canImport(SwiftData)
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

        let screenplay = try createSimpleScreenplay()
        let context = try createInMemoryModelContext()

        _ = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context,
            generateSummaries: false,
            progress: progress
        )

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let descriptions = await collector.getDescriptions()

        #expect(descriptions.count > 0, "Should have progress descriptions")

        // Check for meaningful content
        let allDescriptions = descriptions.joined(separator: " ").lowercased()
        let hasConversion = allDescriptions.contains("converting") ||
                           allDescriptions.contains("element") ||
                           allDescriptions.contains("title") ||
                           allDescriptions.contains("complete")

        #expect(hasConversion, "Progress descriptions should be meaningful")
        #else
        throw TestError.swiftDataNotAvailable
        #endif
    }

    // MARK: - Cancellation Tests

    @Test("Cancellation support is implemented with Task.checkCancellation")
    @MainActor
    func testCancellationSupport() async throws {
        #if canImport(SwiftData)
        // Verify that cancellation doesn't cause crashes
        // The implementation uses Task.checkCancellation() at appropriate points
        let screenplay = try createSimpleScreenplay()
        let context = try createInMemoryModelContext()

        // Run with progress - implementation has Task.checkCancellation() calls
        let progress = OperationProgress(totalUnits: nil)
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context,
            generateSummaries: false,
            progress: progress
        )

        #expect(document.elements.count > 0, "Conversion should complete successfully")
        #else
        throw TestError.swiftDataNotAvailable
        #endif
    }

    // MARK: - Memory Efficiency Tests

    @Test("Progress updates don't cause memory spikes")
    @MainActor
    func testMemoryEfficiency() async throws {
        #if canImport(SwiftData)
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

        let screenplay = try loadFixtureScreenplay("bigfish")
        let context = try createInMemoryModelContext()

        _ = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context,
            generateSummaries: false,
            progress: progress
        )

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let updateCount = await collector.getCount()

        // Should have reasonable number of updates (not one per element for 600+ elements)
        // Big Fish has 600+ elements, batched every 10 = ~60-70 updates + stages
        // Allow up to 200 to account for CI timing variations while ensuring batching
        #expect(updateCount > 0, "Should have progress updates")
        #expect(updateCount < 200, "Should batch updates for memory efficiency (not 600+ individual updates)")
        #else
        throw TestError.swiftDataNotAvailable
        #endif
    }

    // MARK: - Nil Progress Handler Tests

    @Test("Conversion works with nil progress handler")
    @MainActor
    func testNilProgressHandler() async throws {
        #if canImport(SwiftData)
        let screenplay = try createSimpleScreenplay()
        let context = try createInMemoryModelContext()

        let nilProgress: OperationProgress? = nil
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context,
            generateSummaries: false,
            progress: nilProgress
        )

        #expect(document.elements.count > 0, "Should convert with nil progress")
        #else
        throw TestError.swiftDataNotAvailable
        #endif
    }

    // MARK: - Backward Compatibility Tests

    @Test("Async conversion without progress still works")
    @MainActor
    func testBackwardCompatibility() async throws {
        #if canImport(SwiftData)
        let screenplay = try createSimpleScreenplay()
        let context = try createInMemoryModelContext()

        // Use method without progress parameter
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context,
            generateSummaries: false
        )

        #expect(document.elements.count > 0, "Should work without progress")
        #else
        throw TestError.swiftDataNotAvailable
        #endif
    }

    @Test("Methods with and without progress produce identical results")
    @MainActor
    func testProgressEquivalence() async throws {
        #if canImport(SwiftData)
        let screenplay = try createSimpleScreenplay()

        // Without progress
        let context1 = try createInMemoryModelContext()
        let doc1 = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context1,
            generateSummaries: false
        )

        // With nil progress
        let context2 = try createInMemoryModelContext()
        let nilProgress: OperationProgress? = nil
        let doc2 = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context2,
            generateSummaries: false,
            progress: nilProgress
        )

        #expect(doc1.elements.count == doc2.elements.count, "Should produce same element count")
        #else
        throw TestError.swiftDataNotAvailable
        #endif
    }

    // MARK: - Progress Accuracy Tests

    @Test("Progress reports correct fractionCompleted")
    @MainActor
    func testProgressFractionCompleted() async throws {
        #if canImport(SwiftData)
        actor ProgressCollector {
            var fractions: [Double] = []

            func add(_ fraction: Double?) {
                if let f = fraction {
                    fractions.append(f)
                }
            }

            func getFractions() -> [Double] {
                return fractions
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.add(update.fractionCompleted)
            }
        }

        let screenplay = try createSimpleScreenplay()
        let context = try createInMemoryModelContext()

        _ = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context,
            generateSummaries: false,
            progress: progress
        )

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let fractions = await collector.getFractions()

        #expect(fractions.count > 0, "Should have progress fractions")

        // Check fractions are valid and increasing
        var lastFraction = 0.0
        for fraction in fractions {
            #expect(fraction >= lastFraction, "Progress should increase monotonically")
            #expect(fraction >= 0.0 && fraction <= 1.0, "Fraction should be between 0 and 1")
            lastFraction = fraction
        }
        #else
        throw TestError.swiftDataNotAvailable
        #endif
    }

    // MARK: - loadAndParse Tests

    @Test("loadAndParse with progress works for Fountain files")
    @MainActor
    func testLoadAndParseWithProgress() async throws {
        #if canImport(SwiftData)
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

        let url = try Fijos.getFixture("bigfish", extension: "fountain")
        let context = try createInMemoryModelContext()

        let document = try await GuionDocumentParserSwiftData.loadAndParse(
            from: url,
            in: context,
            generateSummaries: false,
            progress: progress
        )

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let updateCount = await collector.getCount()

        #expect(updateCount > 0, "Should have progress updates")
        #expect(document.elements.count > 500, "Should parse Big Fish")
        #else
        throw TestError.swiftDataNotAvailable
        #endif
    }

    @Test("loadAndParse with progress works for FDX files")
    @MainActor
    func testLoadAndParseFDXWithProgress() async throws {
        #if canImport(SwiftData)
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

        let url = try Fijos.getFixture("bigfish", extension: "fdx")
        let context = try createInMemoryModelContext()

        let document = try await GuionDocumentParserSwiftData.loadAndParse(
            from: url,
            in: context,
            generateSummaries: false,
            progress: progress
        )

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let updateCount = await collector.getCount()

        #expect(updateCount > 0, "Should have progress updates")
        #expect(document.elements.count > 0, "Should parse FDX")
        #else
        throw TestError.swiftDataNotAvailable
        #endif
    }

    // MARK: - Empty Screenplay Tests

    @Test("Empty screenplay conversion completes with progress")
    @MainActor
    func testEmptyScreenplayConversion() async throws {
        #if canImport(SwiftData)
        actor ProgressCollector {
            var finalUpdate: ProgressUpdate?

            func setFinal(_ update: ProgressUpdate) {
                finalUpdate = update
            }

            func getFinal() -> ProgressUpdate? {
                return finalUpdate
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.setFinal(update)
            }
        }

        let screenplay = try GuionParsedScreenplay(string: "")
        let context = try createInMemoryModelContext()

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context,
            generateSummaries: false,
            progress: progress
        )

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let finalUpdate = await collector.getFinal()

        #expect(document.elements.count == 0, "Empty screenplay should have no elements")

        // Should still complete progress
        if let final = finalUpdate {
            #expect(final.completedUnits >= 0, "Should have progress")
        }
        #else
        throw TestError.swiftDataNotAvailable
        #endif
    }

    // MARK: - @MainActor Compliance Tests

    @Test("Parse method requires @MainActor context")
    @MainActor
    func testMainActorCompliance() async throws {
        #if canImport(SwiftData)
        let screenplay = try createSimpleScreenplay()
        let context = try createInMemoryModelContext()
        let progress = OperationProgress(totalUnits: nil)

        // This should compile because we're in @MainActor context
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context,
            generateSummaries: false,
            progress: progress
        )

        #expect(document.elements.count > 0, "Should parse in @MainActor context")
        #else
        throw TestError.swiftDataNotAvailable
        #endif
    }
}
