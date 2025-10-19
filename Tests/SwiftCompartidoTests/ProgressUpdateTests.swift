import Testing
import Foundation
@testable import SwiftCompartido

/// Tests for ProgressUpdate struct
///
/// Validates:
/// - Struct initialization and field values
/// - Sendable compliance (compile-time check)
/// - Determinate progress creation
/// - Indeterminate progress creation
/// - Fraction calculation accuracy
@Suite("ProgressUpdate Tests")
struct ProgressUpdateTests {

    @Test("ProgressUpdate initializes with all fields correctly")
    func testInitialization() {
        let now = Date()
        let update = ProgressUpdate(
            fractionCompleted: 0.5,
            completedUnits: 50,
            totalUnits: 100,
            description: "Processing...",
            additionalInfo: "Item 50 of 100",
            timestamp: now
        )

        #expect(update.fractionCompleted == 0.5)
        #expect(update.completedUnits == 50)
        #expect(update.totalUnits == 100)
        #expect(update.description == "Processing...")
        #expect(update.additionalInfo == "Item 50 of 100")
        #expect(update.timestamp == now)
    }

    @Test("ProgressUpdate.determinate calculates fraction correctly")
    func testDeterminateProgress() {
        let update = ProgressUpdate.determinate(
            completedUnits: 75,
            totalUnits: 100,
            description: "75% complete"
        )

        #expect(update.fractionCompleted == 0.75)
        #expect(update.completedUnits == 75)
        #expect(update.totalUnits == 100)
        #expect(update.description == "75% complete")
        #expect(update.additionalInfo == nil)
    }

    @Test("ProgressUpdate.determinate handles zero total")
    func testDeterminateWithZeroTotal() {
        let update = ProgressUpdate.determinate(
            completedUnits: 0,
            totalUnits: 0,
            description: "Empty operation"
        )

        #expect(update.fractionCompleted == 0.0)
        #expect(update.completedUnits == 0)
        #expect(update.totalUnits == 0)
    }

    @Test("ProgressUpdate.indeterminate has nil fraction")
    func testIndeterminateProgress() {
        let update = ProgressUpdate.indeterminate(
            completedUnits: 42,
            description: "Processing unknown amount..."
        )

        #expect(update.fractionCompleted == nil)
        #expect(update.completedUnits == 42)
        #expect(update.totalUnits == nil)
        #expect(update.description == "Processing unknown amount...")
    }

    @Test("ProgressUpdate is Sendable")
    func testSendableCompliance() async {
        let update = ProgressUpdate.determinate(
            completedUnits: 50,
            totalUnits: 100,
            description: "Test"
        )

        // Pass across actor boundary - this validates Sendable compliance
        let result = await withCheckedContinuation { continuation in
            Task {
                continuation.resume(returning: update)
            }
        }

        #expect(result.completedUnits == 50)
    }

    @Test("ProgressUpdate equality works correctly")
    func testEquality() {
        let timestamp = Date()
        let update1 = ProgressUpdate(
            fractionCompleted: 0.5,
            completedUnits: 50,
            totalUnits: 100,
            description: "Test",
            timestamp: timestamp
        )

        let update2 = ProgressUpdate(
            fractionCompleted: 0.5,
            completedUnits: 50,
            totalUnits: 100,
            description: "Test",
            timestamp: timestamp
        )

        #expect(update1 == update2)
    }

    @Test("ProgressUpdate with additional info")
    func testAdditionalInfo() {
        let update = ProgressUpdate.determinate(
            completedUnits: 25,
            totalUnits: 100,
            description: "Parsing",
            additionalInfo: "Line 250 of 1000"
        )

        #expect(update.additionalInfo == "Line 250 of 1000")
    }

    @Test("ProgressUpdate handles 100% completion")
    func testCompletion() {
        let update = ProgressUpdate.determinate(
            completedUnits: 100,
            totalUnits: 100,
            description: "Complete"
        )

        #expect(update.fractionCompleted == 1.0)
    }

    @Test("ProgressUpdate handles large unit counts")
    func testLargeUnitCounts() {
        let largeCount: Int64 = 10_000_000_000 // 10 billion
        let update = ProgressUpdate.determinate(
            completedUnits: largeCount / 2,
            totalUnits: largeCount,
            description: "Large operation"
        )

        #expect(update.fractionCompleted == 0.5)
        #expect(update.completedUnits == largeCount / 2)
        #expect(update.totalUnits == largeCount)
    }
}
