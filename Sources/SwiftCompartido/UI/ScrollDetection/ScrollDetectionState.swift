//
//  ScrollDetectionState.swift
//  SwiftCompartido
//
//  Observable state that tracks active scrolling to optimize performance
//  by deferring hit testing during scroll momentum
//

import SwiftUI
import Observation

/// Observable state that detects active scrolling
///
/// This class tracks scroll position changes and determines when the user
/// is actively scrolling. UI components can use this to defer expensive
/// operations (like hit testing for gestures) during scroll momentum.
///
/// Usage:
/// ```swift
/// @Environment(ScrollDetectionState.self) private var scrollState
///
/// SomeView()
///     .allowsHitTesting(!scrollState.isScrolling)
/// ```
@Observable
public final class ScrollDetectionState {

    /// Whether the scroll view is currently being scrolled
    public private(set) var isScrolling = false

    /// Last known scroll position (y-axis)
    private var lastScrollPosition: CGFloat = 0

    /// Task that resets scrolling state after inactivity
    private var resetTask: Task<Void, Never>?

    /// Delay before considering scroll to have stopped (in seconds)
    private let scrollEndDelay: TimeInterval = 0.15

    public init() {}

    /// Updates scroll position and marks as actively scrolling
    /// - Parameter position: Current scroll position (y-axis)
    @MainActor
    public func updateScrollPosition(_ position: CGFloat) {
        // Only process if position actually changed
        guard position != lastScrollPosition else { return }

        lastScrollPosition = position

        // Mark as scrolling
        if !isScrolling {
            isScrolling = true
        }

        // Cancel any pending reset task
        resetTask?.cancel()

        // Schedule reset task to mark scrolling as stopped
        resetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(scrollEndDelay))

            // Only reset if task wasn't cancelled
            guard !Task.isCancelled else { return }

            isScrolling = false
        }
    }

    /// Manually resets scrolling state
    /// Use this when scroll view disappears or is reset
    @MainActor
    public func reset() {
        resetTask?.cancel()
        resetTask = nil
        isScrolling = false
        lastScrollPosition = 0
    }
}
