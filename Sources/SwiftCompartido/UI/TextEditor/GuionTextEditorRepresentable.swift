//
//  GuionTextEditorRepresentable.swift
//  SwiftCompartido
//
//  Cross-platform read-only text view wrapper
//  Phase 1: Basic display with Courier font - no fancy formatting
//

import SwiftUI

#if os(iOS)
import UIKit

/// iOS read-only text view wrapper - minimal version
struct GuionTextEditorRepresentable: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        // Basic settings
        textView.font = UIFont(name: "Courier New", size: fontSize) ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
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
        if uiView.text != text {
            uiView.text = text
        }

        if let currentFont = uiView.font, currentFont.pointSize != fontSize {
            uiView.font = UIFont(name: "Courier New", size: fontSize) ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
    }
}

#elseif os(macOS)
import AppKit

/// macOS read-only text view wrapper - minimal version
struct GuionTextEditorRepresentable: NSViewRepresentable {
    let text: String
    let fontSize: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView()

        // Basic settings
        textView.font = NSFont(name: "Courier New", size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
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

        if textView.string != text {
            textView.string = text
        }

        if let currentFont = textView.font, currentFont.pointSize != fontSize {
            textView.font = NSFont(name: "Courier New", size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
    }
}
#endif
