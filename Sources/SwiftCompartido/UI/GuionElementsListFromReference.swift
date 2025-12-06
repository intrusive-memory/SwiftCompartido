//
//  GuionElementsListFromReference.swift
//  SwiftCompartido
//
//  List view for displaying elements from ScreenplayElementsReference (App Intents integration)
//

import SwiftUI

/// Container view for element rows from ElementReference with stable identity
private struct ElementReferenceRowContainer<TrailingContent: View>: View {
    let elementRef: ElementReference
    let needsSpacing: Bool
    let fontSize: CGFloat
    let trailingContent: ((ElementReference) -> TrailingContent)?

    var body: some View {
        VStack(spacing: 0) {
            ElementReferenceRow(elementRef: elementRef, trailingContent: trailingContent)

            // Add full line spacing
            if needsSpacing {
                Spacer()
                    .frame(height: fontSize * ScreenplayPageFormat.lineSpacingMultiplier)
            }
        }
    }
}

/// Row view for displaying a single ElementReference
private struct ElementReferenceRow<TrailingContent: View>: View {
    let elementRef: ElementReference
    let trailingContent: ((ElementReference) -> TrailingContent)?

    @Environment(\.screenplayFontSize) var fontSize

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Main element view
            elementView
                .frame(maxWidth: .infinity, alignment: .leading)

            // Optional trailing content
            if let trailingContent = trailingContent {
                trailingContent(elementRef)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var elementView: some View {
        // Uses shared element views via DisplayableElement protocol
        // Reduces code duplication from ~200 lines to ~20 lines!
        switch elementRef.elementType {
        case .sceneHeading:
            SceneHeadingView(element: elementRef)
        case .action:
            ActionView(element: elementRef)
        case .character:
            DialogueCharacterView(element: elementRef)
        case .dialogue:
            DialogueTextView(element: elementRef)
        case .parenthetical:
            DialogueParentheticalView(element: elementRef)
        case .transition:
            TransitionView(element: elementRef)
        case .lyrics:
            DialogueLyricsView(element: elementRef)
        case .pageBreak:
            PageBreakView() // Doesn't need element parameter
        case .sectionHeading:
            SectionHeadingView(element: elementRef)
        case .synopsis:
            SynopsisView(element: elementRef)
        case .boneyard:
            BoneyardView(element: elementRef)
        case .comment:
            CommentView(element: elementRef)
        case .unorderedListItem:
            // Simplified version for ElementReference (no document context)
            MarkdownListItemReferenceView(element: elementRef)
        case .orderedListItem:
            // Simplified version for ElementReference (no document context)
            MarkdownListItemReferenceView(element: elementRef)
        }
    }
}

/// List view displaying ElementReferences from ScreenplayElementsReference
///
/// This view is designed for displaying screenplay elements from App Intents workflows.
/// Unlike `GuionElementsList`, it doesn't use SwiftData @Query - elements are provided
/// directly from a `ScreenplayElementsReference` (which comes from ParseScreenplayFileIntent
/// or QueryScreenplayElementsIntent).
///
/// ## Example
///
/// ```swift
/// struct ShortcutsResultView: View {
///     let reference: ScreenplayElementsReference // From App Intent
///
///     var body: some View {
///         GuionElementsListFromReference(reference: reference)
///             .environment(\.screenplayFontSize, 12)
///     }
/// }
/// ```
///
/// ## With Trailing Content
///
/// ```swift
/// GuionElementsListFromReference(reference: reference) { elementRef in
///     Button("Process") {
///         processElement(elementRef)
///     }
/// }
/// ```
@available(iOS 26.0, macOS 26.0, *)
public struct GuionElementsListFromReference<TrailingContent: View>: View {
    let reference: ScreenplayElementsReference
    private let trailingContent: ((ElementReference) -> TrailingContent)?

    @Environment(\.screenplayFontSize) var fontSize
    @State private var scrollState = ScrollDetectionState()

    /// Cached spacing map: true if element needs spacing after it
    @State private var spacingMap: [String: Bool] = [:]

    /// Creates a list displaying all elements from the reference
    /// - Parameter reference: The screenplay elements reference from an App Intent
    public init(reference: ScreenplayElementsReference) where TrailingContent == EmptyView {
        self.reference = reference
        self.trailingContent = nil
    }

    /// Creates a list with custom trailing content for each element
    /// - Parameters:
    ///   - reference: The screenplay elements reference from an App Intent
    ///   - trailingContent: A ViewBuilder closure that creates trailing content for each element
    public init(reference: ScreenplayElementsReference, @ViewBuilder trailingContent: @escaping (ElementReference) -> TrailingContent) {
        self.reference = reference
        self.trailingContent = trailingContent
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                ForEach(Array(reference.elements.enumerated()), id: \.element.id) { index, elementRef in
                    let idString = String(describing: elementRef.id)
                    ElementReferenceRowContainer(
                        elementRef: elementRef,
                        needsSpacing: spacingMap[idString, default: false],
                        fontSize: fontSize,
                        trailingContent: trailingContent
                    )
                    .id(idString)
                }
            }
            .padding(.vertical, 8)
        }
        .coordinateSpace(name: "scroll")
        .environment(scrollState)
        .onAppear {
            buildSpacingMap()
        }
        .onChange(of: reference.elementCount) { _, _ in
            buildSpacingMap()
        }
    }

    /// Build spacing map for efficient spacing lookups
    private func buildSpacingMap() {
        var newSpacingMap: [String: Bool] = [:]

        for (index, elementRef) in reference.elements.enumerated() {
            let isLast = (index == reference.elements.count - 1)
            let nextElement = isLast ? nil : reference.elements[index + 1]

            // Determine if spacing is needed after this element
            let needsSpacing: Bool
            if isLast {
                needsSpacing = false
            } else if let next = nextElement {
                // Simple spacing rules: add spacing between major structural elements
                needsSpacing = shouldAddSpacing(after: elementRef.elementType, before: next.elementType)
            } else {
                needsSpacing = false
            }

            let idString = String(describing: elementRef.id)
            newSpacingMap[idString] = needsSpacing
        }

        spacingMap = newSpacingMap
    }

    /// Determine if spacing should be added between element types
    private func shouldAddSpacing(after: ElementType, before: ElementType) -> Bool {
        switch (after, before) {
        case (.sceneHeading, _):
            return true
        case (_, .sceneHeading):
            return true
        case (.transition, _):
            return true
        case (_, .transition):
            return true
        case (.sectionHeading, _):
            return true
        case (_, .sectionHeading):
            return true
        case (.character, .action):
            return true
        case (.dialogue, .action):
            return true
        case (.parenthetical, .action):
            return true
        default:
            return false
        }
    }
}

// MARK: - No More Duplicate Views!
//
// Previously, this file contained ~200 lines of duplicate view code (SceneHeadingReferenceView,
// ActionReferenceView, etc.). This has been eliminated by making all element views generic
// via the DisplayableElement protocol.
//
// Both GuionElementModel and ElementReference now conform to DisplayableElement, allowing
// them to share the same view code in Sources/SwiftCompartido/UI/Elements/*.
//
// This reduces maintenance burden and ensures consistent styling across all use cases.
