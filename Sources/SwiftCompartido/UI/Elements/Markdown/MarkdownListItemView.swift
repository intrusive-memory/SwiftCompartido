//
//  MarkdownListItemView.swift
//  SwiftCompartido
//
//  GitHub-style markdown list item rendering
//

import SwiftUI

/// GitHub-style markdown list item view
///
/// Renders ordered and unordered list items with proper indentation
/// based on nesting level, matching GitHub's markdown display.
public struct MarkdownListItemView: View {
    let element: GuionElementModel
    let document: GuionDocumentModel?
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: GuionElementModel, document: GuionDocumentModel? = nil) {
        self.element = element
        self.document = document
    }

    /// Indentation per level in points (GitHub uses ~24px per level)
    private let indentPerLevel: CGFloat = 24

    /// Spacing between bullet/number and text
    private let bulletSpacing: CGFloat = 8

    private var level: Int {
        element.elementType.level
    }

    private var isOrdered: Bool {
        if case .orderedListItem = element.elementType {
            return true
        }
        return false
    }

    /// Compute the item number for ordered lists
    private var itemNumber: Int {
        guard isOrdered, let doc = document ?? element.document else {
            return 1
        }

        // Find all ordered list items at the same level up to this element
        let sortedElements = doc.sortedElements
        guard let currentIndex = sortedElements.firstIndex(where: { $0.id == element.id }) else {
            return 1
        }

        var count = 1
        for i in 0..<currentIndex {
            let el = sortedElements[i]
            if case .orderedListItem(let lvl) = el.elementType, lvl == level {
                count += 1
            } else if case .orderedListItem = el.elementType {
                // Different level - reset count if we've moved to a different list
                continue
            } else if el.elementType != .orderedListItem(level: level) {
                // Non-list item that could signal a new list context
                // For now, continue counting (GitHub preserves numbers across paragraphs)
                continue
            }
        }
        return count
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // Indentation based on nesting level
            if level > 0 {
                Spacer()
                    .frame(width: indentPerLevel * CGFloat(level))
            }

            // Bullet or number
            if isOrdered {
                // Use monospaced font for consistent number alignment
                Text(bulletOrNumber)
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 36, alignment: .trailing)
            } else {
                // Bullets use standard font
                Text(bulletOrNumber)
                    .font(.system(size: fontSize))
                    .foregroundStyle(.primary)
                    .frame(width: 20, alignment: .center)
            }

            Spacer()
                .frame(width: bulletSpacing)

            // List item content with markdown formatting
            formattedText
                .font(.system(size: fontSize))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, itemTopPadding)
        .padding(.bottom, 1)
    }

    /// Calculate top padding based on list type and level
    private var itemTopPadding: CGFloat {
        // Top-level items need more spacing to separate them
        if level == 0 {
            return isOrdered ? 8 : 4
        } else {
            // Nested items need less spacing
            return 2
        }
    }

    /// Returns the bullet point or number prefix
    private var bulletOrNumber: String {
        if isOrdered {
            return "\(itemNumber)."
        } else {
            // GitHub uses different bullets for different levels
            switch level {
            case 0:
                return "•" // Filled circle
            case 1:
                return "◦" // Hollow circle
            default:
                return "▪" // Small square
            }
        }
    }

    /// Renders text with GitHub markdown formatting (bold, italic, code)
    private var formattedText: Text {
        parseMarkdownText(element.elementText)
    }

    /// Parses text with **bold**, *italic*, `code`, and other markdown syntax
    ///
    /// This is a simplified inline markdown parser that handles the most common
    /// formatting elements. It reuses the same logic as MarkdownActionView.
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
