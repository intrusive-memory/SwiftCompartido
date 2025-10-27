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
        List {
            ForEach(elements) { element in
                VStack(spacing: 0) {
                    // Main row with element content and trailing column
                    HStack(alignment: .top) {
                        switch element.elementType {
                        case .action:
                            ActionView(element: element)
                        case .sceneHeading:
                            SceneHeadingView(element: element)
                        case .character:
                            DialogueCharacterView(element: element)
                        case .dialogue:
                            DialogueTextView(element: element)
                        case .parenthetical:
                            DialogueParentheticalView(element: element)
                        case .lyrics:
                            DialogueLyricsView(element: element)
                        case .transition:
                            TransitionView(element: element)
                        case .sectionHeading:
                            SectionHeadingView(element: element)
                        case .synopsis:
                            SynopsisView(element: element)
                        case .comment:
                            CommentView(element: element)
                        case .boneyard:
                            BoneyardView(element: element)
                        case .pageBreak:
                            PageBreakView()
                        }

                        // Add trailing column content if provided
                        if let trailingContent = trailingContent {
                            trailingContent(element)
                        }
                    }

                    // Progress bar row (auto-shows when progress is active)
                    ElementProgressBar(element: element)
                }
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .listStyle(.plain)
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
