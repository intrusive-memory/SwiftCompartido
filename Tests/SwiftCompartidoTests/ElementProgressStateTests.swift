//
//  ElementProgressStateTests.swift
//  SwiftCompartido Tests
//
//  Tests for ElementProgressState and ElementProgressTracker
//

import Testing
import Foundation
import SwiftData
@testable import SwiftCompartido

@Suite("ElementProgressState Tests")
@MainActor
struct ElementProgressStateTests {

    // Helper to create a test model container
    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: GuionElementModel.self,
            configurations: config
        )
    }

    // Helper to create a test element
    private func makeTestElement(in context: ModelContext, text: String = "Test") -> GuionElementModel {
        let element = GuionElementModel(
            elementText: text,
            elementType: .dialogue,
            orderIndex: 0
        )
        context.insert(element)
        return element
    }

    // MARK: - Basic Progress Tracking

    @Test("Set progress for element")
    func testSetProgress() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let state = ElementProgressState()
        let elementID = element.persistentModelID

        state.setProgress(0.5, for: elementID, message: "Testing")

        let progress = state.progress(for: elementID)
        #expect(progress != nil)
        #expect(progress?.progress == 0.5)
        #expect(progress?.message == "Testing")
        #expect(progress?.isComplete == false)
    }

    @Test("Progress clamped to valid range")
    func testProgressClamping() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "Clamp Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID

        // Test lower bound
        state.setProgress(-0.5, for: elementID)
        #expect(state.progress(for: elementID)?.progress == 0.0)

        // Test upper bound
        state.setProgress(1.5, for: elementID)
        #expect(state.progress(for: elementID)?.progress == 1.0)
    }

    @Test("Set complete marks progress as complete")
    func testSetComplete() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "Complete Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID

        state.setComplete(for: elementID, message: "Done!")

        let progress = state.progress(for: elementID)
        #expect(progress != nil)
        #expect(progress?.progress == 1.0)
        #expect(progress?.message == "Done!")
        #expect(progress?.isComplete == true)
        #expect(progress?.completedAt != nil)
    }

    @Test("Set error marks progress as complete with error message")
    func testSetError() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "Error Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID

        let error = NSError(domain: "TestError", code: 123, userInfo: [
            NSLocalizedDescriptionKey: "Test error message"
        ])

        state.setError(error, for: elementID)

        let progress = state.progress(for: elementID)
        #expect(progress != nil)
        #expect(progress?.isComplete == true)
        #expect(progress?.message?.contains("Test error message") == true)
    }

    @Test("Clear progress removes element progress")
    func testClearProgress() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "Clear Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID

        state.setProgress(0.5, for: elementID, message: "Testing")
        #expect(state.progress(for: elementID) != nil)

        state.clearProgress(for: elementID)
        #expect(state.progress(for: elementID) == nil)
    }

    @Test("Clear all removes all progress")
    func testClearAll() async throws {
        let container = try makeTestContainer()
        let element1 = makeTestElement(in: container.mainContext, text: "Element 1")
        let element2 = makeTestElement(in: container.mainContext, text: "Element 2")
        let state = ElementProgressState()
        let id1 = element1.persistentModelID
        let id2 = element2.persistentModelID

        state.setProgress(0.3, for: id1)
        state.setProgress(0.7, for: id2)

        #expect(state.progress(for: id1) != nil)
        #expect(state.progress(for: id2) != nil)

        state.clearAll()

        #expect(state.progress(for: id1) == nil)
        #expect(state.progress(for: id2) == nil)
    }

    // MARK: - Visibility Tests

    @Test("Has visible progress returns true for active progress")
    func testHasVisibleProgressActive() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "Active Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID

        state.setProgress(0.5, for: elementID, message: "Working...")
        #expect(state.hasVisibleProgress(for: elementID) == true)
    }

    @Test("Has visible progress returns false when no progress")
    func testHasVisibleProgressNone() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "No Progress Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID

        #expect(state.hasVisibleProgress(for: elementID) == false)
    }

    @Test("Has visible progress returns true immediately after completion")
    func testHasVisibleProgressJustCompleted() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "Just Completed Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID

        state.setComplete(for: elementID, message: "Done!")
        #expect(state.hasVisibleProgress(for: elementID) == true)
    }

    @Test("Auto-hide delay can be configured")
    func testConfigurableAutoHideDelay() async throws {
        let state = ElementProgressState()
        state.autoHideDelay = 5.0

        #expect(state.autoHideDelay == 5.0)
    }

    // MARK: - Multiple Elements

    @Test("Can track progress for multiple elements independently")
    func testMultipleElements() async throws {
        let container = try makeTestContainer()
        let element1 = makeTestElement(in: container.mainContext, text: "Multi Element 1")
        let element2 = makeTestElement(in: container.mainContext, text: "Multi Element 2")
        let element3 = makeTestElement(in: container.mainContext, text: "Multi Element 3")
        let state = ElementProgressState()
        let id1 = element1.persistentModelID
        let id2 = element2.persistentModelID
        let id3 = element3.persistentModelID

        state.setProgress(0.3, for: id1, message: "Element 1")
        state.setProgress(0.6, for: id2, message: "Element 2")
        state.setProgress(0.9, for: id3, message: "Element 3")

        #expect(state.progress(for: id1)?.progress == 0.3)
        #expect(state.progress(for: id1)?.message == "Element 1")

        #expect(state.progress(for: id2)?.progress == 0.6)
        #expect(state.progress(for: id2)?.message == "Element 2")

        #expect(state.progress(for: id3)?.progress == 0.9)
        #expect(state.progress(for: id3)?.message == "Element 3")
    }

    @Test("Progress updates are independent per element")
    func testIndependentUpdates() async throws {
        let container = try makeTestContainer()
        let element1 = makeTestElement(in: container.mainContext, text: "Independent 1")
        let element2 = makeTestElement(in: container.mainContext, text: "Independent 2")
        let state = ElementProgressState()
        let id1 = element1.persistentModelID
        let id2 = element2.persistentModelID

        state.setProgress(0.5, for: id1, message: "First")
        state.setProgress(0.8, for: id2, message: "Second")

        // Update first element
        state.setProgress(0.7, for: id1, message: "First updated")

        // Second element should be unchanged
        #expect(state.progress(for: id2)?.progress == 0.8)
        #expect(state.progress(for: id2)?.message == "Second")

        // First element should be updated
        #expect(state.progress(for: id1)?.progress == 0.7)
        #expect(state.progress(for: id1)?.message == "First updated")
    }

    // MARK: - ElementProgress Struct

    @Test("ElementProgress initializes correctly")
    func testElementProgressInit() {
        let progress = ElementProgress(progress: 0.5, message: "Test", isComplete: false)

        #expect(progress.progress == 0.5)
        #expect(progress.message == "Test")
        #expect(progress.isComplete == false)
        #expect(progress.completedAt == nil)
    }

    @Test("ElementProgress sets completedAt when complete")
    func testElementProgressCompletedAt() {
        let before = Date()
        let progress = ElementProgress(progress: 1.0, message: "Done", isComplete: true)
        let after = Date()

        #expect(progress.completedAt != nil)
        if let completedAt = progress.completedAt {
            #expect(completedAt >= before)
            #expect(completedAt <= after)
        }
    }
}

@Suite("ElementProgressTracker Tests")
@MainActor
struct ElementProgressTrackerTests {

    // Helper to create a test model container
    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: GuionElementModel.self,
            configurations: config
        )
    }

    // Helper to create a test element
    private func makeTestElement(in context: ModelContext, text: String = "Test") -> GuionElementModel {
        let element = GuionElementModel(
            elementText: text,
            elementType: .dialogue,
            orderIndex: 0
        )
        context.insert(element)
        return element
    }

    // MARK: - Basic Tracker Operations

    @Test("Tracker sets progress for correct element")
    func testTrackerSetProgress() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "Tracker Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID
        let tracker = ElementProgressTracker(elementID: elementID, state: state)

        tracker.setProgress(0.5, message: "Testing")

        let progress = state.progress(for: elementID)
        #expect(progress?.progress == 0.5)
        #expect(progress?.message == "Testing")
    }

    @Test("Tracker marks complete for correct element")
    func testTrackerSetComplete() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "Complete Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID
        let tracker = ElementProgressTracker(elementID: elementID, state: state)

        tracker.setComplete(message: "Done!")

        let progress = state.progress(for: elementID)
        #expect(progress?.isComplete == true)
        #expect(progress?.message == "Done!")
    }

    @Test("Tracker sets error for correct element")
    func testTrackerSetError() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "Error Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID
        let tracker = ElementProgressTracker(elementID: elementID, state: state)

        let error = NSError(domain: "Test", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Test error"
        ])

        tracker.setError(error)

        let progress = state.progress(for: elementID)
        #expect(progress?.isComplete == true)
        #expect(progress?.message?.contains("Test error") == true)
    }

    @Test("Tracker clears progress for correct element")
    func testTrackerClearProgress() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "Clear Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID
        let tracker = ElementProgressTracker(elementID: elementID, state: state)

        tracker.setProgress(0.5, message: "Testing")
        #expect(state.progress(for: elementID) != nil)

        tracker.clearProgress()
        #expect(state.progress(for: elementID) == nil)
    }

    // MARK: - Query Methods

    @Test("Tracker has visible progress returns correct value")
    func testTrackerHasVisibleProgress() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "Visible Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID
        let tracker = ElementProgressTracker(elementID: elementID, state: state)

        #expect(tracker.hasVisibleProgress == false)

        tracker.setProgress(0.5, message: "Working")
        #expect(tracker.hasVisibleProgress == true)

        tracker.clearProgress()
        #expect(tracker.hasVisibleProgress == false)
    }

    @Test("Tracker current progress returns correct value")
    func testTrackerCurrentProgress() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "Current Progress Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID
        let tracker = ElementProgressTracker(elementID: elementID, state: state)

        #expect(tracker.currentProgress == nil)

        tracker.setProgress(0.7, message: "Almost there")

        let progress = tracker.currentProgress
        #expect(progress?.progress == 0.7)
        #expect(progress?.message == "Almost there")
    }

    // MARK: - Convenience Method: withProgress

    @Test("withProgress executes operation and completes")
    func testWithProgressSuccess() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "WithProgress Success Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID
        let tracker = ElementProgressTracker(elementID: elementID, state: state)

        var executedSteps: [Double] = []

        let result = try await tracker.withProgress(
            startMessage: "Starting",
            completeMessage: "Finished"
        ) { updateProgress in
            updateProgress(0.3, "Step 1")
            executedSteps.append(0.3)

            updateProgress(0.6, "Step 2")
            executedSteps.append(0.6)

            return "Success"
        }

        #expect(result == "Success")
        #expect(executedSteps == [0.3, 0.6])

        let finalProgress = state.progress(for: elementID)
        #expect(finalProgress?.isComplete == true)
        #expect(finalProgress?.message == "Finished")
    }

    @Test("withProgress handles errors and reports them")
    func testWithProgressError() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "WithProgress Error Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID
        let tracker = ElementProgressTracker(elementID: elementID, state: state)

        let testError = NSError(domain: "Test", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Test failure"
        ])

        do {
            try await tracker.withProgress(
                startMessage: "Starting",
                completeMessage: "Should not see this"
            ) { updateProgress in
                updateProgress(0.5, "About to fail")
                throw testError
            }
            Issue.record("Should have thrown error")
        } catch {
            // Expected to throw
        }

        let progress = state.progress(for: elementID)
        #expect(progress?.isComplete == true)
        #expect(progress?.message?.contains("Test failure") == true)
    }

    // MARK: - Convenience Method: withSteps

    @Test("withSteps executes all steps with correct progress")
    func testWithStepsSuccess() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "WithSteps Success Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID
        let tracker = ElementProgressTracker(elementID: elementID, state: state)

        let steps = ["Step 1", "Step 2", "Step 3", "Step 4"]
        var executedSteps: [(Int, String)] = []

        try await tracker.withSteps(steps) { index, step in
            executedSteps.append((index, step))
        }

        #expect(executedSteps.count == 4)
        #expect(executedSteps[0].0 == 0)
        #expect(executedSteps[0].1 == "Step 1")
        #expect(executedSteps[3].0 == 3)
        #expect(executedSteps[3].1 == "Step 4")

        let finalProgress = state.progress(for: elementID)
        #expect(finalProgress?.isComplete == true)
        #expect(finalProgress?.message == "All steps complete!")
    }

    @Test("withSteps handles errors in steps")
    func testWithStepsError() async throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext, text: "WithSteps Error Test")
        let state = ElementProgressState()
        let elementID = element.persistentModelID
        let tracker = ElementProgressTracker(elementID: elementID, state: state)

        let steps = ["Step 1", "Step 2", "Step 3"]
        let testError = NSError(domain: "Test", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Step failed"
        ])

        do {
            try await tracker.withSteps(steps) { index, step in
                if index == 1 {
                    throw testError
                }
            }
            Issue.record("Should have thrown error")
        } catch {
            // Expected to throw
        }

        let progress = state.progress(for: elementID)
        #expect(progress?.isComplete == true)
        #expect(progress?.message?.contains("Step failed") == true)
    }

    // MARK: - Multiple Trackers

    @Test("Multiple trackers track different elements independently")
    func testMultipleTrackers() async throws {
        let container = try makeTestContainer()
        let element1 = makeTestElement(in: container.mainContext, text: "Tracker 1")
        let element2 = makeTestElement(in: container.mainContext, text: "Tracker 2")
        let state = ElementProgressState()
        let id1 = element1.persistentModelID
        let id2 = element2.persistentModelID

        let tracker1 = ElementProgressTracker(elementID: id1, state: state)
        let tracker2 = ElementProgressTracker(elementID: id2, state: state)

        tracker1.setProgress(0.3, message: "Tracker 1")
        tracker2.setProgress(0.7, message: "Tracker 2")

        #expect(state.progress(for: id1)?.progress == 0.3)
        #expect(state.progress(for: id1)?.message == "Tracker 1")

        #expect(state.progress(for: id2)?.progress == 0.7)
        #expect(state.progress(for: id2)?.message == "Tracker 2")
    }
}
