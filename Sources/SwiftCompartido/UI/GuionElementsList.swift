//
//  GuionElementsList.swift
//  SwiftCompartido
//
//  Simple list view displaying GuionElementModels from SwiftData
//

import SwiftUI
import SwiftData

/// PreferenceKey for tracking scroll position
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Simple list displaying GuionElementModels from SwiftData
public struct GuionElementsList<TrailingContent: View>: View {
    @Query private var elements: [GuionElementModel]
    @Environment(\.screenplayFontSize) var fontSize
    @StateObject private var dismissCoordinator = PopoverDismissCoordinator()
    @State private var scrollState = ScrollDetectionState()

    private let trailingContent: ((GuionElementModel) -> TrailingContent)?

    /// Cached spacing map: true if element needs spacing after it
    @State private var spacingMap: [PersistentIdentifier: Bool] = [:]

    /// Creates a GuionElementsList with all elements in order
    public init() where TrailingContent == EmptyView {
        _elements = Query(sort: [
            SortDescriptor(\GuionElementModel.chapterIndex),
            SortDescriptor(\GuionElementModel.orderIndex)
        ])
        self.trailingContent = nil
    }

    /// Creates a GuionElementsList filtered to a specific document, in order
    public init(document: GuionDocumentModel) where TrailingContent == EmptyView {
        let documentID = document.persistentModelID
        _elements = Query(
            filter: #Predicate<GuionElementModel> { element in
                element.document?.persistentModelID == documentID
            },
            sort: [
                SortDescriptor(\GuionElementModel.chapterIndex),
                SortDescriptor(\GuionElementModel.orderIndex)
            ]
        )
        self.trailingContent = nil
    }

    /// Creates a GuionElementsList with all elements in order and custom trailing content for each row
    /// - Parameter trailingContent: A ViewBuilder closure that creates trailing content for each element
    public init(@ViewBuilder trailingContent: @escaping (GuionElementModel) -> TrailingContent) {
        _elements = Query(sort: [
            SortDescriptor(\GuionElementModel.chapterIndex),
            SortDescriptor(\GuionElementModel.orderIndex)
        ])
        self.trailingContent = trailingContent
    }

    /// Creates a GuionElementsList filtered to a specific document with custom trailing content for each row
    /// - Parameters:
    ///   - document: The document to filter elements by
    ///   - trailingContent: A ViewBuilder closure that creates trailing content for each element
    public init(document: GuionDocumentModel, @ViewBuilder trailingContent: @escaping (GuionElementModel) -> TrailingContent) {
        let documentID = document.persistentModelID
        _elements = Query(
            filter: #Predicate<GuionElementModel> { element in
                element.document?.persistentModelID == documentID
            },
            sort: [
                SortDescriptor(\GuionElementModel.chapterIndex),
                SortDescriptor(\GuionElementModel.orderIndex)
            ]
        )
        self.trailingContent = trailingContent
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                // Scroll position tracker (invisible)
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                }
                .frame(height: 0)

                ForEach(Array(elements.enumerated()), id: \.element.id) { index, element in
                    VStack(spacing: 0) {
                        GuionElementRow(element: element, trailingContent: trailingContent)

                        // Add full line spacing using cached spacing map
                        if spacingMap[element.persistentModelID] == true {
                            Spacer()
                                .frame(height: fontSize * ScreenplayPageFormat.lineSpacingMultiplier)
                        }
                    }
                    .id(element.id)
                }
            }
            .padding(.horizontal, 0)
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            scrollState.updateScrollPosition(offset)
        }
        .environment(scrollState)
        .environmentObject(dismissCoordinator)
        .onAppear {
            computeSpacingMap()
        }
        .onChange(of: elements.count) { _, _ in
            computeSpacingMap()
        }
        .onDisappear {
            scrollState.reset()
        }
    }

    // MARK: - Spacing Helpers

    /// Pre-compute which elements need spacing after them
    /// This eliminates N+1 lookups during scroll by computing the map once
    private func computeSpacingMap() {
        var map: [PersistentIdentifier: Bool] = [:]

        for (index, element) in elements.enumerated() {
            // Action and synopsis always get spacing
            if element.elementType == .action || element.elementType == .synopsis {
                map[element.persistentModelID] = true
                continue
            }

            // Dialogue and parenthetical get spacing if at end of dialogue group
            if element.elementType == .dialogue || element.elementType == .parenthetical {
                // Check if there's a next element
                if index + 1 < elements.count {
                    let nextElement = elements[index + 1]
                    // Group ends if next element is NOT dialogue or parenthetical
                    map[element.persistentModelID] = (nextElement.elementType != .dialogue && nextElement.elementType != .parenthetical)
                } else {
                    // Last element in list - it ends the group
                    map[element.persistentModelID] = true
                }
            } else {
                // All other element types don't get spacing
                map[element.persistentModelID] = false
            }
        }

        spacingMap = map
    }

    /// Determines if the element at the given index is the end of a dialogue group
    /// A dialogue group consists of: character, dialogue, parenthetical (in any combination)
    /// The group ends when the next element is NOT dialogue or parenthetical
    /// - Note: This function is deprecated in favor of the cached spacingMap
    @available(*, deprecated, message: "Use spacingMap instead for better performance")
    private func isEndOfDialogueGroup(at index: Int) -> Bool {
        let element = elements[index]

        // Only dialogue and parenthetical elements can end a dialogue group
        guard element.elementType == .dialogue || element.elementType == .parenthetical else {
            return false
        }

        // Check if there's a next element
        guard index + 1 < elements.count else {
            // Last element in list - it ends the group
            return true
        }

        let nextElement = elements[index + 1]

        // Group continues if next element is dialogue or parenthetical
        // Group ends if next element is anything else
        return nextElement.elementType != .dialogue && nextElement.elementType != .parenthetical
    }
}

// MARK: - Preview

#Preview("Elements List - Default") {
    GuionElementsList()
        .modelContainer(for: [GuionDocumentModel.self, GuionElementModel.self])
}

#Preview("Elements List - With Trailing Column") {
    GuionElementsList { element in
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
    .modelContainer(for: [GuionDocumentModel.self, GuionElementModel.self])
}
