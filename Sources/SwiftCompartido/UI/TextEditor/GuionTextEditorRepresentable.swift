//
//  GuionTextEditorRepresentable.swift
//  SwiftCompartido
//
//  Cross-platform read-only text view wrapper
//  Displays formatted NSAttributedString with screenplay and markdown styling
//

import SwiftUI

#if os(iOS)
import UIKit

/// iOS read-only text view wrapper with attributed text support
struct GuionTextEditorRepresentable: UIViewRepresentable {
    let attributedText: NSAttributedString
    let fontSize: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        // Basic settings
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true

        // Appearance
        textView.backgroundColor = .systemBackground
        textView.textColor = .label

        // Padding
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributedText {
            uiView.attributedText = attributedText
        }
    }
}

#elseif os(macOS)
import AppKit

/// macOS read-only text view wrapper with attributed text support
struct GuionTextEditorRepresentable: NSViewRepresentable {
    let attributedText: NSAttributedString
    let fontSize: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView()

        // Basic settings
        textView.isEditable = false
        textView.isSelectable = true

        // Appearance
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .labelColor

        // Padding
        textView.textContainerInset = NSSize(width: 20, height: 20)

        // Disable auto-corrections
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        if textView.attributedString() != attributedText {
            textView.textStorage?.setAttributedString(attributedText)
        }
    }
}
#endif
