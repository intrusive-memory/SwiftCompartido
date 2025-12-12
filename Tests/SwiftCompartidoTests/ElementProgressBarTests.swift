//
//  ElementProgressBarTests.swift
//  SwiftCompartido Tests
//
//  Tests for ElementProgressBar component
//

import Testing
import Foundation
import SwiftUI
import SwiftData
@testable import SwiftCompartido

@Suite("ElementProgressBar Tests")
@MainActor
struct ElementProgressBarTests {

    // MARK: - Helper Methods

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: GuionElementModel.self,
            configurations: config
        )
    }

    private func makeTestElement(in context: ModelContext, text: String = "Test element") -> GuionElementModel {
        let element = GuionElementModel(
            elementText: text,
            elementType: .dialogue,
            orderIndex: 0
        )
        context.insert(element)
        return element
    }

    // MARK: - Initialization Tests

    @Test("ElementProgressBar initializes with element")
    func testElementProgressBarInitialization() throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let progressState = ElementProgressState()

        _ = ElementProgressBar(element: element)
            .environment(progressState)

        #expect(element.elementText == "Test element")
    }

    // MARK: - Progress State Tests

    @Test("ElementProgressBar hides when no progress")
    func testElementProgressBarNoProgress() throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let progressState = ElementProgressState()

        _ = ElementProgressBar(element: element)
            .environment(progressState)

        // Element has no progress
        #expect(progressState.hasVisibleProgress(for: element.persistentModelID) == false)
        #expect(progressState.progress(for: element.persistentModelID) == nil)
    }

    @Test("ElementProgressBar shows when progress is set")
    func testElementProgressBarShowsProgress() throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let progressState = ElementProgressState()

        progressState.setProgress(0.5, for: element.persistentModelID, message: "Processing...")

        _ = ElementProgressBar(element: element)
            .environment(progressState)

        // Progress is visible
        #expect(progressState.hasVisibleProgress(for: element.persistentModelID) == true)
        #expect(progressState.progress(for: element.persistentModelID)?.progress == 0.5)
        #expect(progressState.progress(for: element.persistentModelID)?.message == "Processing...")
    }

    @Test("ElementProgressBar updates with progress changes")
    func testElementProgressBarUpdatesProgress() throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let progressState = ElementProgressState()

        // Set initial progress
        progressState.setProgress(0.3, for: element.persistentModelID, message: "Starting...")
        #expect(progressState.progress(for: element.persistentModelID)?.progress == 0.3)

        // Update progress
        progressState.setProgress(0.7, for: element.persistentModelID, message: "Almost done...")
        #expect(progressState.progress(for: element.persistentModelID)?.progress == 0.7)
        #expect(progressState.progress(for: element.persistentModelID)?.message == "Almost done...")
    }

    @Test("ElementProgressBar shows completion state")
    func testElementProgressBarShowsCompletion() throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let progressState = ElementProgressState()

        progressState.setComplete(for: element.persistentModelID, message: "Done!")

        _ = ElementProgressBar(element: element)
            .environment(progressState)

        let progress = progressState.progress(for: element.persistentModelID)
        #expect(progress?.isComplete == true)
        #expect(progress?.progress == 1.0)
        #expect(progress?.message == "Done!")
    }

    @Test("ElementProgressBar completes successfully")
    func testElementProgressBarCompletes() throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let progressState = ElementProgressState()

        // Set complete
        progressState.setComplete(for: element.persistentModelID, message: "Complete!")

        // Should be visible
        #expect(progressState.hasVisibleProgress(for: element.persistentModelID) == true)

        // Progress should be marked complete
        #expect(progressState.progress(for: element.persistentModelID)?.isComplete == true)
    }

    @Test("ElementProgressBar shows error state")
    func testElementProgressBarShowsError() throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let progressState = ElementProgressState()

        struct TestError: LocalizedError {
            var errorDescription: String? { "Failed to process" }
        }

        progressState.setError(TestError(), for: element.persistentModelID)

        _ = ElementProgressBar(element: element)
            .environment(progressState)

        #expect(progressState.hasVisibleProgress(for: element.persistentModelID) == true)
        #expect(progressState.progress(for: element.persistentModelID)?.message.contains("Failed to process") == true)
    }

    // MARK: - Multiple Element Tests

    @Test("ElementProgressBar handles multiple elements independently")
    func testElementProgressBarMultipleElements() throws {
        let container = try makeTestContainer()
        let element1 = makeTestElement(in: container.mainContext, text: "Element 1")
        let element2 = makeTestElement(in: container.mainContext, text: "Element 2")
        let progressState = ElementProgressState()

        // Set different progress for each element
        progressState.setProgress(0.3, for: element1.persistentModelID, message: "Element 1 progress")
        progressState.setProgress(0.7, for: element2.persistentModelID, message: "Element 2 progress")

        _ = ElementProgressBar(element: element1)
            .environment(progressState)

        _ = ElementProgressBar(element: element2)
            .environment(progressState)

        // Each element has its own progress
        #expect(progressState.progress(for: element1.persistentModelID)?.progress == 0.3)
        #expect(progressState.progress(for: element2.persistentModelID)?.progress == 0.7)
        #expect(progressState.progress(for: element1.persistentModelID)?.message == "Element 1 progress")
        #expect(progressState.progress(for: element2.persistentModelID)?.message == "Element 2 progress")
    }

    @Test("ElementProgressBar clears progress independently")
    func testElementProgressBarClearsIndependently() throws {
        let container = try makeTestContainer()
        let element1 = makeTestElement(in: container.mainContext, text: "Element 1")
        let element2 = makeTestElement(in: container.mainContext, text: "Element 2")
        let progressState = ElementProgressState()

        // Set progress for both
        progressState.setProgress(0.5, for: element1.persistentModelID)
        progressState.setProgress(0.5, for: element2.persistentModelID)

        // Clear only element1
        progressState.clearProgress(for: element1.persistentModelID)

        // Element1 cleared, element2 still has progress
        #expect(progressState.hasVisibleProgress(for: element1.persistentModelID) == false)
        #expect(progressState.hasVisibleProgress(for: element2.persistentModelID) == true)
    }

    // MARK: - Message Tests

    @Test("ElementProgressBar handles progress without message")
    func testElementProgressBarNoMessage() throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let progressState = ElementProgressState()

        progressState.setProgress(0.5, for: element.persistentModelID)

        _ = ElementProgressBar(element: element)
            .environment(progressState)

        let progress = progressState.progress(for: element.persistentModelID)
        #expect(progress?.progress == 0.5)
        #expect(progress?.message == nil)
    }

    @Test("ElementProgressBar handles long messages")
    func testElementProgressBarLongMessage() throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let progressState = ElementProgressState()

        let longMessage = String(repeating: "This is a very long progress message. ", count: 10)
        progressState.setProgress(0.5, for: element.persistentModelID, message: longMessage)

        _ = ElementProgressBar(element: element)
            .environment(progressState)

        #expect(progressState.progress(for: element.persistentModelID)?.message == longMessage)
    }

    @Test("ElementProgressBar handles empty message")
    func testElementProgressBarEmptyMessage() throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let progressState = ElementProgressState()

        progressState.setProgress(0.5, for: element.persistentModelID, message: "")

        _ = ElementProgressBar(element: element)
            .environment(progressState)

        #expect(progressState.progress(for: element.persistentModelID)?.message == "")
    }

    // MARK: - Progress Value Tests

    @Test("ElementProgressBar handles zero progress")
    func testElementProgressBarZeroProgress() throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let progressState = ElementProgressState()

        progressState.setProgress(0.0, for: element.persistentModelID, message: "Starting...")

        _ = ElementProgressBar(element: element)
            .environment(progressState)

        #expect(progressState.progress(for: element.persistentModelID)?.progress == 0.0)
    }

    @Test("ElementProgressBar handles full progress")
    func testElementProgressBarFullProgress() throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let progressState = ElementProgressState()

        progressState.setProgress(1.0, for: element.persistentModelID, message: "Complete!")

        _ = ElementProgressBar(element: element)
            .environment(progressState)

        #expect(progressState.progress(for: element.persistentModelID)?.progress == 1.0)
    }

    @Test("ElementProgressBar handles mid-range progress")
    func testElementProgressBarMidRangeProgress() throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let progressState = ElementProgressState()

        let testValues: [Double] = [0.1, 0.25, 0.5, 0.75, 0.9]

        for value in testValues {
            progressState.setProgress(value, for: element.persistentModelID)
            #expect(progressState.progress(for: element.persistentModelID)?.progress == value)
        }
    }

    // MARK: - Edge Case Tests

    @Test("ElementProgressBar handles element without container")
    func testElementProgressBarElementWithoutContainer() throws {
        // Create element without inserting into container
        let element = GuionElementModel(
            elementText: "Unmanaged element",
            elementType: .dialogue,
            orderIndex: 0
        )

        let progressState = ElementProgressState()

        _ = ElementProgressBar(element: element)
            .environment(progressState)

        // Should handle gracefully
        #expect(progressState.hasVisibleProgress(for: element.persistentModelID) == false)
    }

    @Test("ElementProgressBar handles rapid progress updates")
    func testElementProgressBarRapidUpdates() throws {
        let container = try makeTestContainer()
        let element = makeTestElement(in: container.mainContext)
        let progressState = ElementProgressState()

        // Simulate rapid updates
        for i in 0...10 {
            let progress = Double(i) / 10.0
            progressState.setProgress(progress, for: element.persistentModelID, message: "Step \(i)")
        }

        // Final state should be the last update
        #expect(progressState.progress(for: element.persistentModelID)?.progress == 1.0)
        #expect(progressState.progress(for: element.persistentModelID)?.message == "Step 10")
    }
}
