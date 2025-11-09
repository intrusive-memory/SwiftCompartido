//
//  CommonMarkParser.swift
//  SwiftCompartido
//
//  Copyright (c) 2025
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation
import Markdown

/// Parser that converts Markdown documents into GuionElement screenplay elements.
///
/// This parser uses Apple's swift-markdown library to bridge full CommonMark markdown
/// support into the screenplay format, converting markdown elements into their screenplay equivalents.
///
/// ## Supported Mappings
///
/// - **Headings** (`#`, `##`, etc.) → `ElementType.sectionHeading(level:)`
/// - **Paragraphs** → `ElementType.action`
/// - **Block quotes** → `ElementType.action` (prefixed with `>`)
/// - **Code blocks** → `ElementType.action` (preserved as-is)
/// - **Lists** → `ElementType.action` (formatted with bullets/numbers)
/// - **Thematic breaks** (`---`, `***`) → `ElementType.pageBreak`
/// - **HTML blocks** → `ElementType.comment`
///
/// ## Example
///
/// ```swift
/// let markdown = """
/// # Act One
///
/// INT. COFFEE SHOP - DAY
///
/// Sarah enters, looking around nervously.
/// """
///
/// let elements = try CommonMarkParser.parse(markdown)
/// // Returns array of GuionElement objects
/// ```
///
public enum CommonMarkParser {

    /// Parse a markdown string into an array of GuionElement objects.
    ///
    /// - Parameter markdown: The markdown text to parse
    /// - Returns: Array of GuionElement objects representing the screenplay
    /// - Throws: Error if the markdown cannot be parsed
    public static func parse(_ markdown: String) throws -> [GuionElement] {
        let document = Document(parsing: markdown)
        var converter = MarkdownToGuionConverter()
        converter.visit(document)
        return converter.elements
    }

}

// MARK: - Markdown to Guion Converter

/// MarkupWalker that converts markdown nodes to GuionElement objects.
private struct MarkdownToGuionConverter: MarkupWalker {
    var elements: [GuionElement] = []

    // MARK: - Block Elements

    mutating func visitHeading(_ heading: Heading) {
        let text = extractText(from: heading)
        if !text.isEmpty {
            let element = GuionElement(
                type: .sectionHeading(level: heading.level),
                text: text
            )
            elements.append(element)
        }
        // Don't call descendInto to avoid double-processing children
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        let text = extractText(from: paragraph)
        if !text.isEmpty {
            let element = GuionElement(
                type: .action,
                text: text
            )
            elements.append(element)
        }
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        // Process children and prefix each with >
        for child in blockQuote.children {
            if let paragraph = child as? Paragraph {
                let text = extractText(from: paragraph)
                if !text.isEmpty {
                    let element = GuionElement(
                        type: .action,
                        text: "> " + text
                    )
                    elements.append(element)
                }
            } else {
                // For non-paragraphs, recursively visit
                descendInto(child)
            }
        }
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let code = codeBlock.code

        // Split code block into lines and create action elements
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            let element = GuionElement(
                type: .action,
                text: "    " + String(line) // Indent to indicate code
            )
            elements.append(element)
        }
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        for child in unorderedList.listItems {
            let text = extractText(from: child)
            if !text.isEmpty {
                let element = GuionElement(
                    type: .action,
                    text: "• " + text
                )
                elements.append(element)
            }
        }
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        var itemNumber = orderedList.startIndex
        for child in orderedList.listItems {
            let text = extractText(from: child)
            if !text.isEmpty {
                let element = GuionElement(
                    type: .action,
                    text: "\(itemNumber). " + text
                )
                elements.append(element)
                itemNumber += 1
            }
        }
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        let element = GuionElement(
            type: .pageBreak,
            text: "==="
        )
        elements.append(element)
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        let rawHTML = html.rawHTML

        let element = GuionElement(
            type: .comment,
            text: rawHTML
        )
        elements.append(element)
    }

    // MARK: - Helper Methods

    /// Extract plain text from a Markup node and its children.
    ///
    /// This recursively traverses inline elements to build the full text content,
    /// handling emphasis, links, code spans, etc.
    ///
    /// - Parameter markup: The markup node to extract text from
    /// - Returns: Plain text string
    private func extractText(from markup: Markup) -> String {
        var text = ""

        for child in markup.children {
            if let textNode = child as? Markdown.Text {
                text += textNode.string
            } else if let code = child as? InlineCode {
                text += code.code
            } else if let softBreak = child as? SoftBreak {
                text += " "
            } else if let lineBreak = child as? LineBreak {
                text += "\n"
            } else if let emphasis = child as? Emphasis {
                text += extractText(from: emphasis)
            } else if let strong = child as? Strong {
                text += extractText(from: strong)
            } else if let link = child as? Link {
                // Extract link text (ignore URL)
                text += extractText(from: link)
            } else if let image = child as? Image {
                // Use alt text for images
                text += extractText(from: image)
            } else if child.childCount > 0 {
                // Recursively extract from any other nodes with children
                text += extractText(from: child)
            }
        }

        return text
    }
}
