//
//  ElementProgressState.swift
//  SwiftCompartido
//
//  State management for element-level progress tracking
//

import Foundation
import SwiftData
import Observation

/// Progress information for a single element operation
public struct ElementProgress: Sendable {
    /// Current progress value (0.0 to 1.0)
    public var progress: Double

    /// Optional message describing the current operation
    public var message: String?

    /// Whether the operation is complete
    public var isComplete: Bool

    /// Timestamp when the operation completed (for auto-hide)
    public var completedAt: Date?

    public init(progress: Double, message: String? = nil, isComplete: Bool = false) {
        self.progress = progress
        self.message = message
        self.isComplete = isComplete
        self.completedAt = isComplete ? Date() : nil
    }
}

/// Observable state manager for element progress tracking
///
/// Use this class to track progress for operations on GuionElementModel instances.
/// Progress bars automatically appear when progress is set and hide after completion.
///
/// ## Usage
/// ```swift
/// @State private var progressState = ElementProgressState()
///
/// GuionElementsList(document: screenplay)
///     .environment(progressState)
///
/// // Update progress from your operation
/// progressState.setProgress(0.5, for: elementID, message: "Processing...")
/// progressState.setComplete(for: elementID)
/// ```
@MainActor
@Observable
public final class ElementProgressState {
    /// Progress information keyed by element persistent model ID
    private var progressByElement: [PersistentIdentifier: ElementProgress] = [:]

    /// Auto-hide delay after completion (in seconds)
    public var autoHideDelay: TimeInterval = 2.0

    /// Cancellation handlers for each element (MainActor-isolated for Swift 6 safety)
    private var cancellationHandlers: [PersistentIdentifier: @MainActor () -> Void] = [:]

    /// Flag indicating if cancellation has been requested
    /// - Note: Used to stop batch operations from starting new tasks after cancel
    public private(set) var isCancelled: Bool = false

    public init() {}

    /// Get progress for a specific element
    /// - Parameter elementID: The persistent model ID of the element
    /// - Returns: Progress information, or nil if no progress is tracked
    public func progress(for elementID: PersistentIdentifier) -> ElementProgress? {
        progressByElement[elementID]
    }

    /// Check if element has active progress (not complete or recently completed)
    /// - Parameter elementID: The persistent model ID of the element
    /// - Returns: True if progress should be visible
    public func hasVisibleProgress(for elementID: PersistentIdentifier) -> Bool {
        guard let progress = progressByElement[elementID] else {
            return false
        }

        // If not complete, show it
        if !progress.isComplete {
            return true
        }

        // If complete, check if within auto-hide delay
        if let completedAt = progress.completedAt {
            return Date().timeIntervalSince(completedAt) < autoHideDelay
        }

        return false
    }

    /// Set progress for an element
    /// - Parameters:
    ///   - progress: Progress value (0.0 to 1.0)
    ///   - elementID: The persistent model ID of the element
    ///   - message: Optional message describing the operation
    public func setProgress(_ progress: Double, for elementID: PersistentIdentifier, message: String? = nil) {
        let clampedProgress = min(max(progress, 0.0), 1.0)
        progressByElement[elementID] = ElementProgress(
            progress: clampedProgress,
            message: message,
            isComplete: clampedProgress >= 1.0
        )

        // If complete, schedule auto-hide
        if clampedProgress >= 1.0 {
            scheduleAutoHide(for: elementID)
        }
    }

    /// Mark operation as complete for an element
    /// - Parameter elementID: The persistent model ID of the element
    public func setComplete(for elementID: PersistentIdentifier, message: String? = nil) {
        progressByElement[elementID] = ElementProgress(
            progress: 1.0,
            message: message ?? "Complete",
            isComplete: true
        )
        cancellationHandlers.removeValue(forKey: elementID)  // Clean up handler
        scheduleAutoHide(for: elementID)
    }

    /// Set an error state for an element
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - elementID: The persistent model ID of the element
    public func setError(_ error: Error, for elementID: PersistentIdentifier) {
        progressByElement[elementID] = ElementProgress(
            progress: 0.0,
            message: "Error: \(error.localizedDescription)",
            isComplete: true
        )
        cancellationHandlers.removeValue(forKey: elementID)  // Clean up handler
        scheduleAutoHide(for: elementID)
    }

    /// Clear progress for an element
    /// - Parameter elementID: The persistent model ID of the element
    public func clearProgress(for elementID: PersistentIdentifier) {
        progressByElement.removeValue(forKey: elementID)
        cancellationHandlers.removeValue(forKey: elementID)
    }

    /// Clear all progress
    public func clearAll() {
        progressByElement.removeAll()
        cancellationHandlers.removeAll()
        isCancelled = false
    }

    // MARK: - Batch Operations

    /// Pre-register elements for batch operations
    /// - Parameters:
    ///   - elementIDs: Array of persistent model IDs to pre-register
    ///   - message: Optional initial message for all elements
    /// - Note: Use this for batch operations to show accurate total from the start
    public func prepareForBatch(elementIDs: [PersistentIdentifier], message: String? = nil) {
        // Reset cancellation flag for new batch operation
        isCancelled = false

        // Pre-register elements with zero progress
        for elementID in elementIDs {
            progressByElement[elementID] = ElementProgress(
                progress: 0.0,
                message: message ?? "Waiting...",
                isComplete: false
            )
        }
    }

    /// Register a cancellation handler for an element
    /// - Parameters:
    ///   - elementID: The persistent model ID of the element
    ///   - handler: MainActor-isolated closure to call when element should be cancelled
    public func registerCancellationHandler(
        for elementID: PersistentIdentifier,
        handler: @escaping @MainActor () -> Void
    ) {
        cancellationHandlers[elementID] = handler
    }

    /// Cancel all in-progress operations
    /// - Note: Uses Swift 6 structured concurrency for safe task cancellation
    public func cancelAll() {
        // Set cancellation flag to prevent new tasks from starting
        isCancelled = true

        // Get all in-progress element IDs
        let inProgressIDs = progressByElement.filter { !$0.value.isComplete }.map { $0.key }

        // Call cancellation handlers (Swift 6 ensures MainActor isolation)
        for elementID in inProgressIDs {
            cancellationHandlers[elementID]?()
        }

        // Clear all progress
        clearAll()
    }

    // MARK: - Aggregate Progress Metrics

    /// Total number of elements with tracked progress
    public var totalElements: Int {
        progressByElement.count
    }

    /// Number of elements with completed operations
    public var completedElements: Int {
        progressByElement.values.filter { $0.isComplete }.count
    }

    /// Number of elements with in-progress operations
    public var inProgressElements: Int {
        progressByElement.values.filter { !$0.isComplete }.count
    }

    /// Overall progress across all tracked elements (0.0 to 1.0)
    public var overallProgress: Double {
        guard totalElements > 0 else { return 0.0 }
        return Double(completedElements) / Double(totalElements)
    }

    /// Whether there are any active progress operations
    public var isActive: Bool {
        !progressByElement.isEmpty
    }

    /// Aggregate status message describing current state
    public var aggregateStatusMessage: String {
        guard !progressByElement.isEmpty else { return "" }

        // All tasks complete
        if inProgressElements == 0 {
            return "Complete: Generated \(totalElements) element\(totalElements == 1 ? "" : "s")"
        }

        // Single task in progress
        if totalElements == 1, let progress = progressByElement.values.first {
            let message = progress.message ?? "Processing"
            return "\(message)..."
        }

        // Multiple tasks
        return "Generating \(completedElements) of \(totalElements) elements..."
    }

    /// Schedule auto-hide for a completed element
    private func scheduleAutoHide(for elementID: PersistentIdentifier) {
        Task {
            try? await Task.sleep(for: .seconds(autoHideDelay))
            clearProgress(for: elementID)
        }
    }
}

