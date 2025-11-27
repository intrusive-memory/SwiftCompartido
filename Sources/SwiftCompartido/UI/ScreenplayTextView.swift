import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// High-performance screenplay viewer using native text rendering
/// Significantly faster than element-by-element SwiftUI views
public struct ScreenplayTextView: View {
    let document: GuionDocumentModel

    public init(document: GuionDocumentModel) {
        self.document = document
    }

    public var body: some View {
        #if canImport(AppKit)
        MacOSTextView(document: document)
        #else
        IOSTextView(document: document)
        #endif
    }
}

// MARK: - macOS Implementation

#if canImport(AppKit)
private struct MacOSTextView: NSViewRepresentable {
    let document: GuionDocumentModel

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        // Configure text view
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 20, height: 20)

        // Render screenplay
        let attributedString = ScreenplayTextRenderer.render(document: document)
        textView.textStorage?.setAttributedString(attributedString)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Re-render if document changes
        let attributedString = ScreenplayTextRenderer.render(document: document)
        textView.textStorage?.setAttributedString(attributedString)
    }
}
#endif

// MARK: - iOS Implementation

#if canImport(UIKit) && !targetEnvironment(macCatalyst)
private struct IOSTextView: UIViewRepresentable {
    let document: GuionDocumentModel

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        // Configure text view
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        // Render screenplay
        let attributedString = ScreenplayTextRenderer.render(document: document)
        textView.attributedText = attributedString

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Re-render if document changes
        let attributedString = ScreenplayTextRenderer.render(document: document)
        textView.attributedText = attributedString
    }
}
#endif

// MARK: - Catalyst Implementation

#if targetEnvironment(macCatalyst)
private struct IOSTextView: UIViewRepresentable {
    let document: GuionDocumentModel

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        // Configure text view
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        // Render screenplay
        let attributedString = ScreenplayTextRenderer.render(document: document)
        textView.attributedText = attributedString

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Re-render if document changes
        let attributedString = ScreenplayTextRenderer.render(document: document)
        textView.attributedText = attributedString
    }
}
#endif

// MARK: - Preview

#Preview("Screenplay Text View") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: GuionDocumentModel.self,
        configurations: config
    )

    let context = container.mainContext

    // Create sample document
    let document = GuionDocumentModel(
        filename: "sample.fountain",
        sourceFile: nil
    )

    let elements = [
        GuionElementModel(
            elementType: .sceneHeading,
            text: "INT. COFFEE SHOP - DAY",
            chapterIndex: 0,
            orderIndex: 0
        ),
        GuionElementModel(
            elementType: .action,
            text: "SARAH, 30s, sits at a corner table, laptop open. She types furiously.",
            chapterIndex: 0,
            orderIndex: 1
        ),
        GuionElementModel(
            elementType: .character,
            text: "SARAH",
            chapterIndex: 0,
            orderIndex: 2
        ),
        GuionElementModel(
            elementType: .dialogue,
            text: "This new text view is so much faster!",
            chapterIndex: 0,
            orderIndex: 3
        )
    ]

    for element in elements {
        element.document = document
        context.insert(element)
    }

    context.insert(document)

    return ScreenplayTextView(document: document)
        .frame(width: 800, height: 600)
}
