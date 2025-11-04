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
        List {
            ForEach(elements) { element in
                GuionElementRow(element: element, trailingContent: trailingContent)
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .listStyle(.plain)
        .environmentObject(dismissCoordinator)
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
