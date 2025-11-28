//
//  GuionTextEditor.swift
//  SwiftCompartido
//
//  Read-only TextKit 2 display for screenplay documents
//  Phase 1: Fast scrolling with basic Courier text
//

import SwiftUI
import SwiftData

/// Read-only text view for screenplay documents
///
/// Phase 1: Displays all elements as plain Courier text in a single scrollable view
/// Focus: Fast scrolling performance, no formatting yet
///
/// ## Example
///
/// ```swift
/// struct ContentView: View {
///     @Query var documents: [GuionDocumentModel]
///
///     var body: some View {
///         if let document = documents.first {
///             GuionTextEditor(document: document)
///                 .environment(\.screenplayFontSize, 12)
///         }
///     }
/// }
/// ```
public struct GuionTextEditor: View {
    let document: GuionDocumentModel

    @Environment(\.screenplayFontSize) var fontSize
    @State private var text: String = ""

    public init(document: GuionDocumentModel) {
        self.document = document
    }

    public var body: some View {
        GuionTextEditorRepresentable(
            text: text,
            fontSize: fontSize
        )
        .onAppear {
            rebuildText()
        }
        .onChange(of: document.sortedElements.count) { _, _ in
            rebuildText()
        }
        .onChange(of: fontSize) { _, _ in
            // No need to rebuild text, just update font size
            // TextViewRepresentable will handle it in updateUIView/updateNSView
        }
    }

    private func rebuildText() {
        text = GuionTextElementMapper.buildText(from: document.sortedElements)
    }
}

// MARK: - Preview

#Preview("TextKit 2 Editor - Basic") {
    GuionTextEditor(document: GuionDocumentModel())
        .modelContainer(for: [GuionDocumentModel.self, GuionElementModel.self])
        .environment(\.screenplayFontSize, 12)
}
