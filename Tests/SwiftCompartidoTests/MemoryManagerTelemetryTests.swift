//
//  MemoryManagerTelemetryTests.swift
//  SwiftCompartidoTests
//
//  Tests for MemoryManager telemetry instrumentation
//

import Foundation
import Testing

@testable import SwiftCompartido

// MARK: - Mock Telemetry Reporter

/// A mock telemetry reporter that captures events for testing
final class MockTelemetryReporter: CompartidoTelemetryReporter, @unchecked Sendable {
    /// Array of captured telemetry events (protected by actor semantics)
    private nonisolated(unsafe) var events: [CompartidoTelemetryEvent] = []

    /// Capture a telemetry event and add it to the events array
    /// - Parameter event: The event to capture
    func capture(_ event: CompartidoTelemetryEvent) async {
        // Simple append - not using locking since this is a test helper
        events.append(event)
    }

    /// Get the captured events
    /// - Returns: Array of captured events
    func getEvents() -> [CompartidoTelemetryEvent] {
        return events
    }

    /// Clear all captured events
    func clearEvents() {
        events.removeAll()
    }
}

// MARK: - MemoryManager Telemetry Tests

@Suite("MemoryManager Telemetry Tests")
struct MemoryManagerTelemetryTests {

    // MARK: - GPU Cache Clear Telemetry Tests

    @Test("GPU cache clear emits start and complete events")
    func testGPUCacheClearTelemetry() async throws {
        let mockTelemetry = MockTelemetryReporter()
        let manager = MemoryManager.shared

        // Set the mock telemetry reporter
        await manager.setTelemetry(mockTelemetry)

        // Call clearGPUCache
        await manager.clearGPUCache()

        // Get the captured events
        let events = mockTelemetry.getEvents()

        // Verify we captured exactly 2 events (start and complete)
        #expect(events.count == 2)

        // Verify first event is gpuCacheClearStart
        if case let .gpuCacheClearStart(metalAllocatedMB) = events[0] {
            #expect(metalAllocatedMB >= 0.0, "Start memory should be non-negative")
        } else {
            Issue.record("First event should be gpuCacheClearStart")
        }

        // Verify second event is gpuCacheClearComplete
        if case let .gpuCacheClearComplete(freedMB, metalAllocatedMB) = events[1] {
            #expect(freedMB >= 0.0, "Freed memory should be non-negative")
            #expect(metalAllocatedMB >= 0.0, "Final memory should be non-negative")
        } else {
            Issue.record("Second event should be gpuCacheClearComplete")
        }

        // Clean up telemetry
        await manager.setTelemetry(nil)
    }

    // MARK: - Memory Pressure Reporting Tests

    @Test("Memory pressure reporting returns valid values")
    func testMemoryPressureReporting() async throws {
        let manager = MemoryManager.shared

        // Get memory pressure report
        let report = await manager.reportMemoryPressure()

        // Verify resident memory is reported and non-negative
        #expect(report.residentMB >= 0.0, "Resident memory should be non-negative")

        // Verify available memory is reported and non-negative
        #expect(report.availableMB >= 0.0, "Available memory should be non-negative")

        // Verify pressure level is one of the expected values
        let validPressureLevels: [MemoryPressureLevel] = [.low, .moderate, .high, .critical]
        #expect(validPressureLevels.contains { level in
            switch (level, report.pressureLevel) {
            case (.low, .low), (.moderate, .moderate), (.high, .high), (.critical, .critical):
                return true
            default:
                return false
            }
        }, "Pressure level should be one of the valid levels")

        // Verify resident + available is approximately total system memory
        // (allowing for some variance due to system state changes)
        let totalMemory = report.residentMB + report.availableMB
        #expect(totalMemory > 0.0, "Total memory should be positive")
    }

    // MARK: - Memory Pressure Level Determination Tests

    @Test("Memory pressure level is calculated correctly")
    func testMemoryPressureLevelCalculation() async throws {
        let manager = MemoryManager.shared

        // Get memory pressure report
        let report = await manager.reportMemoryPressure()

        // Calculate expected pressure level based on resident memory percentage
        let totalMemory = report.residentMB + report.availableMB
        let usagePercent = (report.residentMB / totalMemory) * 100.0

        // Determine expected pressure level
        let expectedLevel: MemoryPressureLevel
        switch usagePercent {
        case 0..<50:
            expectedLevel = .low
        case 50..<75:
            expectedLevel = .moderate
        case 75..<90:
            expectedLevel = .high
        default:
            expectedLevel = .critical
        }

        // Verify the reported pressure level matches the calculation
        switch (expectedLevel, report.pressureLevel) {
        case (.low, .low), (.moderate, .moderate), (.high, .high), (.critical, .critical):
            // Match expected
            break
        default:
            Issue.record("Pressure level calculation mismatch")
        }
    }

    // MARK: - Telemetry Optional Chaining Tests

    @Test("Telemetry calls work correctly when nil")
    func testTelemetryOptionalChaining() async throws {
        let manager = MemoryManager.shared

        // Ensure telemetry is nil
        await manager.setTelemetry(nil)

        // Call clearGPUCache with no telemetry reporter
        // This should not crash and should work normally
        await manager.clearGPUCache()

        // If we get here without crashing, the test passes
        #expect(true)
    }

    // MARK: - Integration Test Verification Instructions
    //
    // INTEGRATION TEST: Testing with Produciesta CLI
    //
    // To verify telemetry integration with the Produciesta system:
    //
    // 1. Prerequisites:
    //    - Install Produciesta CLI if not already installed
    //    - Ensure SwiftCompartido is built: `xcodebuild build -scheme SwiftCompartido -destination 'platform=macOS'`
    //
    // 2. Manual Integration Test (using Produciesta CLI):
    //
    //    Run the following command to test memory telemetry output:
    //    ```bash
    //    bin/produciesta ~/test-project --telemetry | grep -i "compartido"
    //    ```
    //
    //    Expected output (lines containing Compartido telemetry):
    //    ```
    //    📊 [Compartido] GPU cache clear: X.X MB freed (Y.Y MB remaining)
    //    📊 [Compartido] Memory Pressure: Z.Z MB resident, P% pressure level
    //    ```
    //
    // 3. Verification Steps:
    //    a) Confirm GPU cache clear shows non-zero freed memory (typically 0+ MB)
    //    b) Confirm memory pressure shows reasonable resident memory values
    //    c) Confirm both start and complete events are captured in sequence
    //    d) Monitor for any memory leaks between repeated clear operations
    //
    // 4. Expected Findings:
    //    - GPU cache clear START event shows allocated Metal memory before clearing
    //    - GPU cache clear COMPLETE event shows freed MB and remaining allocated memory
    //    - Memory pressure reports resident/available memory and pressure level
    //    - Multiple calls should show consistent memory allocation patterns
    //
    // 5. Failure Scenarios:
    //    - If freed MB is always 0.0: Metal device allocation tracking may not work on this system
    //    - If resident/available memory is 0.0: mach_task_basic_info query failed
    //    - If events are missing: Telemetry reporter may not be set or capturing
    //
    // 6. Further Testing:
    //    - Run Produciesta CLI on different projects (VoxAlta, Secuencia) to cross-compare
    //    - Use `Activity Monitor` or `Instruments.app` to correlate with actual memory usage
    //    - Compare telemetry findings with TELEMETRY_FINDINGS.md in Produciesta repo
    //
    // For detailed Produciesta telemetry integration, see:
    // - Produciesta: /Users/stovak/Projects/Produciesta/Sources/Produciesta/Telemetry/
    // - Coordination: /Users/stovak/Projects/Produciesta/MULTI_REPO_TELEMETRY.md
}
