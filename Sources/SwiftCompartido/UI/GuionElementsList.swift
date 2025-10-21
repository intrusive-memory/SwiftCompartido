//
//  GuionElementsList.swift
//  SwiftCompartido
//
//  Simple list view displaying GuionElementModels from SwiftData
//

import SwiftUI
import SwiftData

/// Simple list displaying GuionElementModels from SwiftData
public struct GuionElementsList: View {
    @Query private var elements: [GuionElementModel]
    @Environment(\.screenplayFontSize) var fontSize

    /// Creates a GuionElementsList with all elements
    public init() {
        _elements = Query()
    }

    /// Creates a GuionElementsList filtered to a specific document
    public init(document: GuionDocumentModel) {
        let documentID = document.persistentModelID
        _elements = Query(
            filter: #Predicate<GuionElementModel> { element in
                element.document?.persistentModelID == documentID
            }
        )
    }

    public var body: some View {
        List {
            ForEach(elements) { element in
                // Simple switch/case for each element type
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
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Elements List") {
    GuionElementsList()
        .modelContainer(for: [GuionDocumentModel.self, GuionElementModel.self])
}
