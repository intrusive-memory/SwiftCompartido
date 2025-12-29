//
//  GuionTextEditor.swift
//  SwiftCompartido
//
//  Read-only TextKit 2 display for screenplay documents
//  with full screenplay and markdown formatting
//

import SwiftUI
@preconcurrency import SwiftData

/// Read-only text view for screenplay documents
///
/// Displays formatted screenplays and markdown documents with proper styling:
/// - **Screenplay**: Scene headings, dialogue margins, transitions, etc.
/// - **Markdown**: GitHub-style headings, lists, and inline formatting
/// - **Inline formatting**: Bold, italic, underline from Fountain syntax
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
///
/// ## Formatting Support
///
/// ### Screenplay Elements
/// - Scene headings: Bold, 1.5x size, full width
/// - Character names: Bold, 0.75x size, 40% left margin
/// - Dialogue: 25% left and right margins
/// - Parentheticals: 30% left margin
/// - Action: Full width
/// - Transitions: Right-aligned
///
/// ### Markdown Elements
/// - Headings (H1-H6): GitHub-style sizing
/// - Unordered lists: Bullet points with indentation
/// - Ordered lists: Numbered lists with indentation
/// - Comments: Gray, italic
/// - Boneyard: Grayed out (omitted content)
///
/// ### Inline Formatting
/// - `**bold**` → **bold**
/// - `*italic*` → *italic*
/// - `_underline_` → underline
public struct GuionTextEditor: View {
    let document: GuionDocumentModel

    @Environment(\.screenplayFontSize) var fontSize
    @State private var attributedText: NSAttributedString = NSAttributedString()

    public init(document: GuionDocumentModel) {
        self.document = document
    }

    public var body: some View {
        GuionTextEditorRepresentable(
            attributedText: attributedText,
            fontSize: fontSize
        )
        .onAppear {
            rebuildText()
        }
        .onChange(of: document.sortedElements.count) { _, _ in
            rebuildText()
        }
        .onChange(of: fontSize) { _, _ in
            rebuildText()
        }
    }

    private func rebuildText() {
        attributedText = GuionTextElementMapper.buildAttributedText(
            from: document.sortedElements,
            fontSize: fontSize
        )
    }
}

// MARK: - Preview

#Preview("TextKit 2 Editor - Formatted") {
    GuionTextEditor(document: GuionDocumentModel())
        .modelContainer(for: [GuionDocumentModel.self, GuionElementModel.self])
        .environment(\.screenplayFontSize, 12)
}
