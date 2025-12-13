//
//  MarkdownActionView.swift
//  SwiftCompartido
//
//  GitHub-style markdown paragraph rendering
//

import SwiftUI

/// GitHub-style markdown paragraph view
public struct MarkdownActionView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        formattedText
            .font(.system(size: fontSize))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    /// Renders text with GitHub markdown formatting
    private var formattedText: Text {
        parseMarkdownText(element.elementText)
    }

    /// Parses text with **bold**, *italic*, `code`, and other markdown syntax
    private func parseMarkdownText(_ text: String) -> Text {
        var result = Text("")
        var currentText = ""
        var i = text.startIndex

        while i < text.endIndex {
            // Check for **bold**
            if i < text.index(text.endIndex, offsetBy: -1),
               text[i] == "*",
               text[text.index(after: i)] == "*" {
                // Add accumulated text
                if !currentText.isEmpty {
                    result = result + Text(currentText)
                    currentText = ""
                }
                // Find closing **
                i = text.index(i, offsetBy: 2)
                var boldText = ""
                while i < text.endIndex {
                    if i < text.index(text.endIndex, offsetBy: -1),
                       text[i] == "*",
                       text[text.index(after: i)] == "*" {
                        result = result + Text(boldText).bold()
                        i = text.index(i, offsetBy: 2)
                        break
                    }
                    boldText.append(text[i])
                    i = text.index(after: i)
                }
                continue
            }

            // Check for *italic*
            if text[i] == "*" {
                // Add accumulated text
                if !currentText.isEmpty {
                    result = result + Text(currentText)
                    currentText = ""
                }
                // Find closing *
                i = text.index(after: i)
                var italicText = ""
                while i < text.endIndex {
                    if text[i] == "*" {
                        result = result + Text(italicText).italic()
                        i = text.index(after: i)
                        break
                    }
                    italicText.append(text[i])
                    i = text.index(after: i)
                }
                continue
            }

            // Check for `inline code`
            if text[i] == "`" {
                // Add accumulated text
                if !currentText.isEmpty {
                    result = result + Text(currentText)
                    currentText = ""
                }
                // Find closing `
                i = text.index(after: i)
                var codeText = ""
                while i < text.endIndex {
                    if text[i] == "`" {
                        result = result + Text(codeText)
                            .font(.system(size: fontSize * 0.85, design: .monospaced))
                            .foregroundStyle(.secondary)
                        i = text.index(after: i)
                        break
                    }
                    codeText.append(text[i])
                    i = text.index(after: i)
                }
                continue
            }

            currentText.append(text[i])
            i = text.index(after: i)
        }

        // Add remaining text
        if !currentText.isEmpty {
            result = result + Text(currentText)
        }

        return result
    }
}
