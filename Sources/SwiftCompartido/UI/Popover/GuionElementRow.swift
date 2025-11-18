//
//  GuionElementRow.swift
//  SwiftCompartido
//
//  Row view for GuionElementsList with popover support
//

import SwiftUI

/// Row view that displays a GuionElementModel with optional popover support
///
/// This view wraps the element-specific views (ActionView, DialogueTextView, etc.)
/// and adds hover detection and popover display capabilities.
@MainActor
struct GuionElementRow<TrailingContent: View>: View {
    let element: GuionElementModel
    let trailingContent: ((GuionElementModel) -> TrailingContent)?

    @Environment(\.guionElementPopover) private var popoverProvider
    @Environment(\.guionElementContextMenu) private var contextMenuProvider
    @EnvironmentObject private var dismissCoordinator: PopoverDismissCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Check if this element's document is a markdown file
    private var isMarkdownDocument: Bool {
        guard let filename = element.document?.filename else { return false }
        let lowercased = filename.lowercased()
        return lowercased.hasSuffix(".md") || lowercased.hasSuffix(".markdown")
    }

    // Separate hover states for element and popover (for interactive support)
    @State private var isHoveringElement = false
    @State private var isHoveringPopover = false
    @State private var showPopover = false
    @State private var hoverTask: Task<Void, Never>?
    @State private var gracePeriodTask: Task<Void, Never>?

    // Long-press state for touch devices
    @State private var isLongPressing = false
    @State private var longPressLocation: CGPoint = .zero

    // Hover delay in seconds (will be configurable via environment in future phases)
    private let hoverDelay: TimeInterval = 0.3

    // Grace period when transitioning from element to popover (for interactive support)
    private let gracePeriod: TimeInterval = 0.1

    // Long-press duration for touch devices
    private let longPressDuration: TimeInterval = 0.5

    // Combined hover state: hovering either element OR popover
    private var isHovering: Bool {
        isHoveringElement || isHoveringPopover
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row with element content and trailing column
            HStack(alignment: .top, spacing: 0) {
                // Content area that dismisses popover on tap (iOS only)
                HStack(alignment: .top, spacing: 0) {
                    elementView

                    // Add trailing column content if provided
                    if let trailingContent = trailingContent {
                        trailingContent(element)
                    }

                    Spacer()
                }
                #if os(iOS)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Tap on content area (not hover target) dismisses popover
                    if showPopover {
                        dismissPopover()
                    }
                }
                #endif

                // Hover target area (only shown if popover is available)
                if popoverProvider != nil {
                    hoverTarget
                }
            }
            .background(
                // Visual feedback during long-press
                isLongPressing ? Color.primary.opacity(0.05) : Color.clear
            )
            #if os(macOS)
            // macOS: Keep long-press as fallback for non-trackpad interactions
            .onLongPressGesture(minimumDuration: longPressDuration, perform: {
                handleLongPressComplete()
            }, onPressingChanged: { pressing in
                handleLongPressChanged(pressing)
            })
            #endif
            .overlay(alignment: .topTrailing) {
                if showPopover, let provider = popoverProvider {
                    popoverView(content: provider(element))
                        .onHover { hoveringPopover in
                            handlePopoverHover(hoveringPopover)
                        }
                        .onTapGesture {
                            // Allow taps inside popover (prevent dismissal)
                        }
                }
            }

            // Progress bar row (auto-shows when progress is active)
            ElementProgressBar(element: element)
        }
        .onChange(of: dismissCoordinator.shouldDismiss) { oldValue, newValue in
            if newValue == true && showPopover {
                dismissPopover()
            }
        }
        .onDisappear {
            // Dismiss popover when row disappears (e.g., during scroll)
            if showPopover {
                dismissCoordinator.triggerDismiss()
            }
        }
        .contextMenu {
            // Add context menu if provider is available
            // Works on both macOS (right-click) and iOS (long-press)
            if let provider = contextMenuProvider {
                provider.menuBuilder(element)
            }
        }
    }

    // MARK: - Hover Target

    /// Hover/tap area that triggers the popover
    /// - Width: 120pt (fixed)
    /// - Height: Expands to match row height
    /// - macOS: Hover to show popover
    /// - iOS: Tap to toggle popover
    @ViewBuilder
    private var hoverTarget: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 120)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                handleElementHover(hovering)
            }
            #if os(iOS)
            .onTapGesture {
                handleTap()
            }
            #endif
    }

    // MARK: - Element View

    /// Returns the appropriate view for the element type
    @ViewBuilder
    private var elementView: some View {
        // Use GitHub-style markdown views for .md/.markdown files
        if isMarkdownDocument {
            switch element.elementType {
            case .action:
                MarkdownActionView(element: element)
                    .debugBorder()
            case .sectionHeading:
                MarkdownSectionHeadingView(element: element)
                    .debugBorder()
            // For other types in markdown, fall through to standard views
            default:
                standardElementView
            }
        } else {
            standardElementView
        }
    }

    /// Standard screenplay element views (Fountain format)
    @ViewBuilder
    private var standardElementView: some View {
        switch element.elementType {
        case .action:
            ActionView(element: element)
                .debugBorder()
        case .sceneHeading:
            SceneHeadingView(element: element)
                .debugBorder()
        case .character:
            DialogueCharacterView(element: element)
                .debugBorder()
        case .dialogue:
            DialogueTextView(element: element)
                .debugBorder()
        case .parenthetical:
            DialogueParentheticalView(element: element)
                .debugBorder()
        case .lyrics:
            DialogueLyricsView(element: element)
                .debugBorder()
        case .transition:
            TransitionView(element: element)
                .debugBorder()
        case .sectionHeading:
            SectionHeadingView(element: element)
                .debugBorder()
        case .synopsis:
            SynopsisView(element: element)
                .debugBorder()
        case .comment:
            CommentView(element: element)
                .debugBorder()
        case .boneyard:
            BoneyardView(element: element)
                .debugBorder()
        case .pageBreak:
            PageBreakView()
                .debugBorder()
        }
    }

    // MARK: - Popover View

    /// Creates the styled popover view with size constraints
    @ViewBuilder
    private func popoverView(content: AnyView) -> some View {
        content
            .fixedSize()
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
            .offset(x: -12, y: -8)
            .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.95)))
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: showPopover)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Additional information")
    }

    // MARK: - Hover Handling

    /// Handles hover state changes on the element
    private func handleElementHover(_ hovering: Bool) {
        isHoveringElement = hovering

        if hovering {
            // Cancel any pending dismissal
            gracePeriodTask?.cancel()

            // Start hover delay to show popover
            hoverTask?.cancel()
            hoverTask = Task { @MainActor in
                do {
                    try await Task.sleep(for: .milliseconds(Int(hoverDelay * 1000)))
                    if isHoveringElement {
                        showPopover = true
                    }
                } catch {
                    // Task was cancelled, do nothing
                }
            }
        } else {
            // Cancel hover delay task
            hoverTask?.cancel()

            // Start grace period before dismissing
            // This allows user to move mouse from element to popover
            gracePeriodTask?.cancel()
            gracePeriodTask = Task { @MainActor in
                do {
                    try await Task.sleep(for: .milliseconds(Int(gracePeriod * 1000)))
                    // Only hide if not hovering either element or popover
                    if !isHovering {
                        showPopover = false
                    }
                } catch {
                    // Task was cancelled, do nothing
                }
            }
        }
    }

    /// Handles hover state changes on the popover
    private func handlePopoverHover(_ hovering: Bool) {
        isHoveringPopover = hovering

        if hovering {
            // Cancel any pending dismissal - user is now hovering popover
            gracePeriodTask?.cancel()
        } else {
            // Start grace period before dismissing
            gracePeriodTask?.cancel()
            gracePeriodTask = Task { @MainActor in
                do {
                    try await Task.sleep(for: .milliseconds(Int(gracePeriod * 1000)))
                    // Only hide if not hovering either element or popover
                    if !isHovering {
                        showPopover = false
                    }
                } catch {
                    // Task was cancelled, do nothing
                }
            }
        }
    }

    // MARK: - Long-Press Handling (Touch Support)

    /// Handles changes in long-press state (visual feedback)
    private func handleLongPressChanged(_ pressing: Bool) {
        isLongPressing = pressing

        if !pressing {
            // Long-press was cancelled (finger moved or lifted too early)
            // Reset state
            isLongPressing = false
        }
    }

    /// Handles completion of long-press gesture (triggers popover)
    private func handleLongPressComplete() {
        isLongPressing = false

        // Show popover
        showPopover = true

        // Trigger haptic feedback on iOS
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }

    // MARK: - Tap Handling (iOS Touch Support)

    /// Handles tap gesture on hover target (iOS only)
    /// Toggles popover visibility with haptic feedback
    private func handleTap() {
        #if os(iOS)
        // Toggle popover
        showPopover.toggle()

        // Trigger haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    /// Dismisses the popover
    private func dismissPopover() {
        showPopover = false
        isHoveringElement = false
        isHoveringPopover = false
        hoverTask?.cancel()
        gracePeriodTask?.cancel()
    }
}

// MARK: - Preview

#Preview("Element Row with Popover") {
    @Previewable @State var element = GuionElementModel(
        elementText: "INT. COFFEE SHOP - DAY",
        elementType: .sceneHeading,
        chapterIndex: 0,
        orderIndex: 1
    )

    return GuionElementRow<EmptyView>(element: element, trailingContent: nil)
        .guionElementPopover { element in
            VStack(alignment: .leading, spacing: 4) {
                Text("Scene Heading")
                    .font(.caption.bold())
                Text("Chapter \(element.chapterIndex), Order \(element.orderIndex)")
                    .font(.caption2)
            }
        }
        .padding()
}

#Preview("Element Row with Interactive Popover") {
    @Previewable @State var element = GuionElementModel(
        elementText: "JOHN walks into the coffee shop.",
        elementType: .action,
        chapterIndex: 0,
        orderIndex: 2
    )
    @Previewable @State var clickCount = 0

    return GuionElementRow<EmptyView>(element: element, trailingContent: nil)
        .guionElementPopover { element in
            VStack(alignment: .leading, spacing: 6) {
                Text("Generate Audio")
                    .font(.caption.bold())
                HStack {
                    Button("Generate") {
                        clickCount += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    if clickCount > 0 {
                        Text("Clicked \(clickCount)x")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
}

#Preview("Element Row with Trailing Content") {
    @Previewable @State var element = GuionElementModel(
        elementText: "JOHN walks into the room.",
        elementType: .action,
        chapterIndex: 0,
        orderIndex: 2
    )

    return GuionElementRow(element: element) { element in
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(element.chapterIndex)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(element.orderIndex)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 50)
    }
    .guionElementPopover { element in
        Text("Action element")
            .font(.caption)
    }
    .padding()
}

#Preview("Element Row with Tap (iOS Touch)") {
    @Previewable @State var element = GuionElementModel(
        elementText: "SARAH enters the building.",
        elementType: .action,
        chapterIndex: 0,
        orderIndex: 3
    )

    return VStack(spacing: 16) {
        Text("Instructions: Tap the right side to toggle popover")
            .font(.caption)
            .foregroundStyle(.secondary)

        GuionElementRow<EmptyView>(element: element, trailingContent: nil)
            .guionElementPopover { element in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tap Activated!")
                        .font(.caption.bold())
                    Button("Generate Audio") {
                        print("Generate tapped")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
    }
    .padding()
}
