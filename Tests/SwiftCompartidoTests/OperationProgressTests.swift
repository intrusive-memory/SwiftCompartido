import Testing
import Foundation
@testable import SwiftCompartido

/// Tests for OperationProgress class
///
/// Validates:
/// - Progress calculation accuracy
/// - Thread safety with concurrent updates
/// - Progress batching/throttling
/// - Cancellation handling
/// - Completion behavior
@Suite("OperationProgress Tests")
struct OperationProgressTests {

    @Test("OperationProgress initializes with defaults")
    func testInitialization() {
        let progress = OperationProgress()

        #expect(progress.totalUnitCount == nil)
        #expect(progress.completedUnitCount == 0)
        #expect(progress.isCancelled == false)
    }

    @Test("OperationProgress initializes with total units")
    func testInitializationWithTotal() {
        let progress = OperationProgress(totalUnits: 100)

        #expect(progress.totalUnitCount == 100)
        #expect(progress.completedUnitCount == 0)
    }

    @Test("OperationProgress update changes completed units")
    func testUpdate() {
        let progress = OperationProgress(totalUnits: 100)

        progress.update(completedUnits: 50, description: "Halfway")

        #expect(progress.completedUnitCount == 50)
    }

    @Test("OperationProgress increment adds to completed units")
    func testIncrement() {
        let progress = OperationProgress(totalUnits: 100)

        progress.increment(by: 10, description: "Step 1")
        #expect(progress.completedUnitCount == 10)

        progress.increment(by: 15, description: "Step 2")
        #expect(progress.completedUnitCount == 25)

        progress.increment(description: "Step 3") // default by: 1
        #expect(progress.completedUnitCount == 26)
    }

    @Test("OperationProgress complete sets to total")
    func testComplete() {
        let progress = OperationProgress(totalUnits: 100)

        progress.update(completedUnits: 50, description: "Halfway")
        progress.complete()

        #expect(progress.completedUnitCount == 100)
    }

    @Test("OperationProgress cancel sets flag")
    func testCancel() {
        let progress = OperationProgress(totalUnits: 100)

        #expect(progress.isCancelled == false)

        progress.cancel()

        #expect(progress.isCancelled == true)
    }

    @Test("OperationProgress handler receives updates")
    func testHandlerReceivesUpdates() async {
        actor UpdateCollector {
            var updates: [ProgressUpdate] = []

            func add(_ update: ProgressUpdate) {
                updates.append(update)
            }

            func getUpdates() -> [ProgressUpdate] {
                return updates
            }
        }

        let collector = UpdateCollector()

        let progress = OperationProgress(totalUnits: 100) { update in
            Task {
                await collector.add(update)
            }
        }

        // Force updates to bypass throttling
        progress.update(completedUnits: 25, description: "25%", force: true)
        progress.update(completedUnits: 50, description: "50%", force: true)
        progress.update(completedUnits: 75, description: "75%", force: true)
        progress.complete(description: "100%")

        // Small delay to ensure handler executes
        try? await Task.sleep(for: .milliseconds(50))

        let receivedUpdates = await collector.getUpdates()
        #expect(receivedUpdates.count == 4)
        #expect(receivedUpdates[0].completedUnits == 25)
        #expect(receivedUpdates[1].completedUnits == 50)
        #expect(receivedUpdates[2].completedUnits == 75)
        #expect(receivedUpdates[3].completedUnits == 100)
    }

    @Test("OperationProgress calculates fraction correctly")
    func testFractionCalculation() async {
        actor UpdateHolder {
            var lastUpdate: ProgressUpdate?

            func set(_ update: ProgressUpdate) {
                lastUpdate = update
            }

            func get() -> ProgressUpdate? {
                return lastUpdate
            }
        }

        let holder = UpdateHolder()

        let progress = OperationProgress(totalUnits: 100) { update in
            Task {
                await holder.set(update)
            }
        }

        progress.update(completedUnits: 75, description: "75%", force: true)

        try? await Task.sleep(for: .milliseconds(50))

        let lastUpdate = await holder.get()
        #expect(lastUpdate?.fractionCompleted == 0.75)
    }

    @Test("OperationProgress throttles rapid updates")
    func testUpdateThrottling() async {
        actor Counter {
            var count = 0

            func increment() {
                count += 1
            }

            func get() -> Int {
                return count
            }
        }

        let counter = Counter()

        let progress = OperationProgress(
            totalUnits: 1000,
            updateInterval: 0.1
        ) { _ in
            Task {
                await counter.increment()
            }
        }

        // Send 1000 rapid updates without force flag
        for i in 0..<1000 {
            progress.update(completedUnits: Int64(i), description: "Item \(i)")
        }

        // Wait for any pending updates
        try? await Task.sleep(for: .milliseconds(200))

        // Should receive far fewer than 1000 updates due to throttling
        // With 100ms interval and ~0ms operation time, expect ~2-3 updates
        let updateCount = await counter.get()
        #expect(updateCount < 20)
    }

    @Test("OperationProgress thread safety with concurrent updates")
    func testThreadSafety() async {
        let progress = OperationProgress(totalUnits: 10_000)

        // Launch 10 concurrent tasks, each incrementing 1000 times
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    for _ in 0..<1000 {
                        progress.increment(by: 1, description: "Processing")
                    }
                }
            }
        }

        // All increments should be recorded
        #expect(progress.completedUnitCount == 10_000)
    }

    @Test("OperationProgress indeterminate progress")
    func testIndeterminateProgress() async {
        actor UpdateHolder {
            var lastUpdate: ProgressUpdate?

            func set(_ update: ProgressUpdate) {
                lastUpdate = update
            }

            func get() -> ProgressUpdate? {
                return lastUpdate
            }
        }

        let holder = UpdateHolder()

        let progress = OperationProgress(handler: { update in
            Task {
                await holder.set(update)
            }
        })

        progress.update(completedUnits: 42, description: "Processing...", force: true)

        try? await Task.sleep(for: .milliseconds(50))

        let lastUpdate = await holder.get()
        #expect(lastUpdate?.fractionCompleted == nil)
        #expect(lastUpdate?.totalUnits == nil)
        #expect(lastUpdate?.completedUnits == 42)
    }

    @Test("OperationProgress can change from indeterminate to determinate")
    func testChangeToDeterminate() async {
        actor UpdateCollector {
            var updates: [ProgressUpdate] = []

            func add(_ update: ProgressUpdate) {
                updates.append(update)
            }

            func getUpdates() -> [ProgressUpdate] {
                return updates
            }
        }

        let collector = UpdateCollector()

        let progress = OperationProgress { update in
            Task {
                await collector.add(update)
            }
        }

        // Start indeterminate
        progress.update(completedUnits: 10, description: "Scanning...", force: true)

        // Discover total
        progress.setTotalUnitCount(100)
        progress.update(completedUnits: 50, description: "Processing...", force: true)

        try? await Task.sleep(for: .milliseconds(50))

        let updates = await collector.getUpdates()
        #expect(updates.count == 2)
        #expect(updates[0].fractionCompleted == nil)
        #expect(updates[1].fractionCompleted == 0.5)
    }

    @Test("OperationProgress complete with indeterminate")
    func testCompleteIndeterminate() {
        let progress = OperationProgress() // No total units

        progress.update(completedUnits: 50, description: "Processing")
        progress.complete()

        // Completed units should stay at 50 (can't jump to unknown total)
        #expect(progress.completedUnitCount == 50)
    }

    @Test("OperationProgress nil handler doesn't crash")
    func testNilHandler() {
        let progress = OperationProgress(totalUnits: 100, handler: nil)

        // Should not crash
        progress.update(completedUnits: 50, description: "Test")
        progress.complete()

        #expect(progress.completedUnitCount == 100)
    }

    @Test("OperationProgress is Sendable")
    func testSendableCompliance() async {
        let progress = OperationProgress(totalUnits: 100)

        // Pass across actor boundary
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                progress.increment(by: 50, description: "Task 1")
            }
        }

        #expect(progress.completedUnitCount == 50)
    }
}
