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
/// GuionElementsList(document: screenplay) { element in
///     GenerateAudioElementButton(element: element)
/// }
/// .environment(progressState)
///
/// // Update progress
/// progressState.setProgress(0.5, for: elementID, message: "Generating...")
/// progressState.setComplete(for: elementID)
/// ```
@MainActor
@Observable
public final class ElementProgressState {
    /// Progress information keyed by element persistent model ID
    private var progressByElement: [PersistentIdentifier: ElementProgress] = [:]

    /// Auto-hide delay after completion (in seconds)
    public var autoHideDelay: TimeInterval = 2.0

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
        scheduleAutoHide(for: elementID)
    }

    /// Clear progress for an element
    /// - Parameter elementID: The persistent model ID of the element
    public func clearProgress(for elementID: PersistentIdentifier) {
        progressByElement.removeValue(forKey: elementID)
    }

    /// Clear all progress
    public func clearAll() {
        progressByElement.removeAll()
    }

    /// Schedule auto-hide for a completed element
    private func scheduleAutoHide(for elementID: PersistentIdentifier) {
        Task {
            try? await Task.sleep(for: .seconds(autoHideDelay))
            clearProgress(for: elementID)
        }
    }
}

