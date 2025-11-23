//
//  GuionElementsList.swift
//  SwiftCompartido
//
//  Simple list view displaying GuionElementModels from SwiftData
//

import SwiftUI
import SwiftData

/// Simple list displaying GuionElementModels from SwiftData
public struct GuionElementsList<TrailingContent: View>: View {
    @Query private var elements: [GuionElementModel]
    @Environment(\.screenplayFontSize) var fontSize
    @StateObject private var dismissCoordinator = PopoverDismissCoordinator()

    private let trailingContent: ((GuionElementModel) -> TrailingContent)?

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
                ForEach(Array(elements.indices), id: \.self) { index in
                    let element = elements[index]
                    VStack(spacing: 0) {
                        GuionElementRow(element: element, trailingContent: trailingContent)

                        // Add full line spacing after action lines
                        if element.elementType == .action {
                            Spacer()
                                .frame(height: fontSize * ScreenplayPageFormat.lineSpacingMultiplier)
                        }
                        // Add full line spacing after synopsis
                        else if element.elementType == .synopsis {
                            Spacer()
                                .frame(height: fontSize * ScreenplayPageFormat.lineSpacingMultiplier)
                        }
                        // Add full line spacing after dialogue groups (character + dialogue/parenthetical)
                        else if isEndOfDialogueGroup(at: index) {
                            Spacer()
                                .frame(height: fontSize * ScreenplayPageFormat.lineSpacingMultiplier)
                        }
                    }
                    .id(element.id)
                }
            }
            .padding(.horizontal, 0)
        }
        .environmentObject(dismissCoordinator)
    }

    // MARK: - Spacing Helpers

    /// Determines if the element at the given index is the end of a dialogue group
    /// A dialogue group consists of: character, dialogue, parenthetical (in any combination)
    /// The group ends when the next element is NOT dialogue or parenthetical
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
