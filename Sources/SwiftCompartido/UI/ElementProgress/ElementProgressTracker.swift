//
//  ElementProgressTracker.swift
//  SwiftCompartido
//
//  Scoped progress tracker for a specific GuionElementModel
//

import Foundation
import SwiftData

/// Scoped progress tracker for a specific element
///
/// Provides a convenient API for tracking progress without manually passing element IDs.
/// Obtained via `element.progressTracker(using:)`.
///
/// ## Usage
/// ```swift
/// @Environment(ElementProgressState.self) private var progressState
///
/// func performAction() async {
///     let tracker = element.progressTracker(using: progressState)
///
///     tracker.setProgress(0.0, message: "Starting...")
///     tracker.setProgress(0.5, message: "Processing...")
///     tracker.setComplete(message: "Done!")
/// }
/// ```
@MainActor
public struct ElementProgressTracker {
    /// The element's persistent model ID
    private let elementID: PersistentIdentifier

    /// The progress state manager
    private let state: ElementProgressState

    /// Internal initializer - use `element.progressTracker(using:)` instead
    internal init(elementID: PersistentIdentifier, state: ElementProgressState) {
        self.elementID = elementID
        self.state = state
    }

    // MARK: - Progress Operations

    /// Update progress for this element
    /// - Parameters:
    ///   - progress: Progress value (0.0 to 1.0)
    ///   - message: Optional message describing the operation
    public func setProgress(_ progress: Double, message: String? = nil) {
        state.setProgress(progress, for: elementID, message: message)
    }

    /// Mark operation as complete for this element
    /// - Parameter message: Optional completion message
    public func setComplete(message: String? = nil) {
        state.setComplete(for: elementID, message: message)
    }

    /// Set an error state for this element
    /// - Parameter error: The error that occurred
    public func setError(_ error: Error) {
        state.setError(error, for: elementID)
    }

    /// Clear progress for this element
    public func clearProgress() {
        state.clearProgress(for: elementID)
    }

    // MARK: - Progress Queries

    /// Check if this element has visible progress
    /// - Returns: True if progress should be displayed
    public var hasVisibleProgress: Bool {
        state.hasVisibleProgress(for: elementID)
    }

    /// Get current progress information for this element
    /// - Returns: Progress information, or nil if no progress is tracked
    public var currentProgress: ElementProgress? {
        state.progress(for: elementID)
    }

    // MARK: - Convenience Methods

    /// Execute an async operation with automatic progress tracking
    /// - Parameters:
    ///   - startMessage: Message to show when starting
    ///   - completeMessage: Message to show on completion
    ///   - operation: The async operation to perform
    /// - Throws: Rethrows any error from the operation
    public func withProgress<T>(
        startMessage: String = "Starting...",
        completeMessage: String = "Complete!",
        _ operation: (_ updateProgress: @Sendable @escaping (Double, String?) -> Void) async throws -> T
    ) async throws -> T {
        setProgress(0.0, message: startMessage)

        do {
            let result = try await operation { progress, message in
                Task { @MainActor in
                    self.setProgress(progress, message: message)
                }
            }
            setComplete(message: completeMessage)
            return result
        } catch {
            setError(error)
            throw error
        }
    }

    /// Execute an async operation with step-based progress tracking
    /// - Parameters:
    ///   - steps: Array of step descriptions
    ///   - operation: The async operation to perform for each step
    /// - Throws: Rethrows any error from the operations
    public func withSteps(
        _ steps: [String],
        operation: @escaping (Int, String) async throws -> Void
    ) async throws {
        setProgress(0.0, message: steps.first ?? "Starting...")

        do {
            for (index, step) in steps.enumerated() {
                let progress = Double(index) / Double(steps.count)
                setProgress(progress, message: step)
                try await operation(index, step)
            }

            setComplete(message: "All steps complete!")
        } catch {
            setError(error)
            throw error
        }
    }
}

// MARK: - GuionElementModel Extension

extension GuionElementModel {
    /// Get a scoped progress tracker for this element
    /// - Parameter state: The progress state manager from the environment
    /// - Returns: A progress tracker scoped to this element
    ///
    /// ## Usage
    /// ```swift
    /// @Environment(ElementProgressState.self) private var progressState
    ///
    /// let tracker = element.progressTracker(using: progressState)
    /// tracker.setProgress(0.5, message: "Processing...")
    /// ```
    @MainActor
    public func progressTracker(using state: ElementProgressState) -> ElementProgressTracker {
        ElementProgressTracker(elementID: persistentModelID, state: state)
    }

    /// Check if this element has visible progress
    /// - Parameter state: The progress state manager from the environment
    /// - Returns: True if progress should be displayed
    @MainActor
    public func hasVisibleProgress(in state: ElementProgressState) -> Bool {
        state.hasVisibleProgress(for: persistentModelID)
    }

    /// Get current progress for this element
    /// - Parameter state: The progress state manager from the environment
    /// - Returns: Progress information, or nil if no progress is tracked
    @MainActor
    public func currentProgress(in state: ElementProgressState) -> ElementProgress? {
        state.progress(for: persistentModelID)
    }
}
