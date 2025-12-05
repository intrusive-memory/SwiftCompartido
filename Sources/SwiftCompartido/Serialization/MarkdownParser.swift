//
//  MarkdownParser.swift
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
/// This parser uses Apple's swift-markdown library to parse markdown content,
/// converting markdown elements into their screenplay equivalents. It also supports
/// YAML front matter for document metadata (title, author, etc.), similar to how
/// Fountain handles title pages.
///
/// ## YAML Front Matter Support
///
/// The parser extracts YAML front matter from markdown files, converting it to the
/// same format as Fountain title pages. Front matter must be at the start of the file
/// between `---` delimiters:
///
/// ```markdown
/// ---
/// title: My Screenplay
/// author: John Doe
/// draft: First Draft
/// ---
///
/// # Act One
/// ...
/// ```
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
/// ---
/// title: Coffee Shop Scene
/// author: Jane Smith
/// ---
///
/// # Act One
///
/// INT. COFFEE SHOP - DAY
///
/// Sarah enters, looking around nervously.
/// """
///
/// let (elements, titlePage) = try MarkdownParser.parse(markdown)
/// // elements: Array of GuionElement objects
/// // titlePage: [["title": ["Coffee Shop Scene"]], ["author": ["Jane Smith"]]]
/// ```
///
public enum MarkdownParser {

    /// Parse a markdown string into screenplay elements and optional front matter.
    ///
    /// This method parses both YAML front matter (for metadata like title, author)
    /// and the markdown content body. The front matter is returned in the same
    /// format as Fountain title pages for consistency across parsers.
    ///
    /// - Parameter markdown: The markdown text to parse
    /// - Returns: Tuple containing:
    ///   - elements: Array of GuionElement objects representing the screenplay
    ///   - titlePage: Array of dictionaries with metadata from YAML front matter
    ///   - customPages: Array of CustomPageContainer objects extracted from YAML
    /// - Throws: Error if the markdown cannot be parsed
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let (elements, titlePage, customPages) = try MarkdownParser.parse(markdownString)
    ///
    /// // Access title from front matter
    /// if let titleDict = titlePage.first(where: { $0.keys.contains("title") }),
    ///    let title = titleDict["title"]?.first {
    ///     print("Title: \(title)")
    /// }
    /// ```
    public static func parse(_ markdown: String) throws -> (elements: [GuionElement], titlePage: [[String: [String]]], customPages: [CustomPageContainer]) {
        // Extract YAML front matter if present
        let (contentWithoutFrontMatter, titlePage, customPages) = extractYAMLFrontMatter(from: markdown)

        // Parse the markdown content (without front matter)
        let document = Document(parsing: contentWithoutFrontMatter)
        var converter = MarkdownToGuionConverter()
        converter.visit(document)

        return (converter.elements, titlePage, customPages)
    }

    /// Extract YAML front matter from the beginning of a markdown document.
    ///
    /// YAML front matter must be at the very start of the file, enclosed between
    /// `---` delimiters. This follows the CommonMark/Jekyll convention.
    ///
    /// - Parameter markdown: The full markdown string
    /// - Returns: Tuple containing:
    ///   - content: The markdown content without front matter
    ///   - titlePage: Extracted metadata in Fountain title page format
    ///   - customPages: Array of CustomPageContainer objects from YAML
    ///
    /// ## Supported Formats
    ///
    /// ```yaml
    /// ---
    /// title: My Document
    /// author: John Doe
    /// authors:
    ///   - Jane Smith
    ///   - Bob Johnson
    /// draft: First Draft
    /// customPages:
    ///   - type: castList
    ///     title: Cast List
    ///     position: 1
    /// ---
    /// ```
    private static func extractYAMLFrontMatter(from markdown: String) -> (content: String, titlePage: [[String: [String]]], customPages: [CustomPageContainer]) {
        var titlePage: [[String: [String]]] = []
        var customPages: [CustomPageContainer] = []

        // Check if document starts with ---
        guard markdown.hasPrefix("---\n") || markdown.hasPrefix("---\r\n") else {
            return (markdown, titlePage, customPages)
        }

        // Find the closing ---
        let lines = markdown.components(separatedBy: .newlines)
        guard lines.count > 2 else {
            return (markdown, titlePage, customPages)
        }

        // Find end of front matter (second --- line)
        var endIndex = -1
        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // Skip first ---
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                endIndex = index
                break
            }
        }

        guard endIndex > 0 else {
            return (markdown, titlePage, customPages)
        }

        // Extract front matter lines (between the two ---)
        let frontMatterLines = Array(lines[1..<endIndex])
        let frontMatterText = frontMatterLines.joined(separator: "\n")

        // Try to parse as JSON-compatible YAML for customPages extraction
        // This is a simple approach: convert YAML to JSON-like structure
        if let yamlData = frontMatterText.data(using: .utf8),
           let yamlDict = try? parseSimpleYAML(yamlData) {

            // Extract customPages if present
            if let customPagesArray = yamlDict["custompages"] as? [[String: Any]] ?? yamlDict["customPages"] as? [[String: Any]] {
                for pageDict in customPagesArray {
                    if let container = try? CustomPageContainer(from: pageDict) {
                        customPages.append(container)
                    }
                }
            }
        }

        // Parse YAML-style key: value pairs for titlePage
        var currentKey = ""
        var currentValues: [String] = []
        var inCustomPages = false
        var customPagesIndentLevel = 0

        for line in frontMatterLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.isEmpty {
                continue
            }

            // Calculate indent level
            let leadingSpaces = line.prefix(while: { $0 == " " }).count

            // Check if we're entering or exiting customPages section
            if let colonIndex = trimmedLine.firstIndex(of: ":"),
               trimmedLine[..<colonIndex].trimmingCharacters(in: .whitespaces).lowercased() == "custompages" {
                // Save previous key if any
                if !currentKey.isEmpty && !inCustomPages {
                    titlePage.append([currentKey: currentValues])
                    currentKey = ""
                    currentValues = []
                }
                inCustomPages = true
                customPagesIndentLevel = leadingSpaces
                continue
            }

            // Skip lines that are part of customPages section
            if inCustomPages {
                if leadingSpaces <= customPagesIndentLevel && !trimmedLine.hasPrefix("-") {
                    inCustomPages = false
                } else {
                    continue
                }
            }

            // Check if this is a key: value line
            if let colonIndex = trimmedLine.firstIndex(of: ":") {
                // Save previous key if any
                if !currentKey.isEmpty {
                    titlePage.append([currentKey: currentValues])
                }

                let key = String(trimmedLine[..<colonIndex]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(trimmedLine[trimmedLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

                // Normalize "author" to "authors" for consistency with Fountain
                currentKey = (key == "author") ? "authors" : key

                if !value.isEmpty {
                    currentValues = [value]
                } else {
                    currentValues = []
                }
            } else if trimmedLine.hasPrefix("-") {
                // This is a list item (multi-value field like multiple authors)
                let value = trimmedLine.dropFirst().trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    currentValues.append(value)
                }
            } else if !currentKey.isEmpty {
                // Continuation of previous value (multi-line)
                currentValues.append(trimmedLine)
            }
        }

        // Save last key
        if !currentKey.isEmpty && !inCustomPages {
            titlePage.append([currentKey: currentValues])
        }

        // Remove front matter from content
        let remainingLines = Array(lines[(endIndex + 1)...])
        let contentWithoutFrontMatter = remainingLines.joined(separator: "\n")

        return (contentWithoutFrontMatter, titlePage, customPages)
    }

    /// Parse simple YAML into a dictionary (limited YAML support for customPages)
    ///
    /// This is a basic YAML parser that handles the subset needed for customPages.
    /// It converts YAML to a JSON-compatible structure.
    ///
    /// - Parameter data: YAML data
    /// - Returns: Dictionary representation of YAML
    private static func parseSimpleYAML(_ data: Data) throws -> [String: Any] {
        guard let yamlString = String(data: data, encoding: .utf8) else {
            return [:]
        }

        var result: [String: Any] = [:]
        var currentKey: String?
        var currentArray: [[String: Any]] = []
        var currentDict: [String: Any] = [:]
        var previousIndent = 0

        let lines = yamlString.components(separatedBy: .newlines)

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { continue }

            let leadingSpaces = line.prefix(while: { $0 == " " }).count

            // Top-level key
            if leadingSpaces == 0 && line.contains(":") {
                // Save previous array if any
                if let key = currentKey, !currentArray.isEmpty {
                    result[key] = currentArray
                    currentArray = []
                }

                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count >= 1 {
                    currentKey = String(parts[0]).trimmingCharacters(in: .whitespaces).lowercased()
                    if parts.count == 2 {
                        let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                        if !value.isEmpty {
                            result[currentKey!] = value
                            currentKey = nil
                        }
                    }
                }
            } else if trimmedLine.hasPrefix("-") && currentKey != nil {
                // Array item
                if !currentDict.isEmpty {
                    currentArray.append(currentDict)
                    currentDict = [:]
                }
                previousIndent = leadingSpaces
            } else if leadingSpaces > previousIndent && line.contains(":") {
                // Nested key-value in array item
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespaces)

                    // Try to parse as number or bool
                    if let intValue = Int(value) {
                        currentDict[key] = intValue
                    } else if let boolValue = Bool(value) {
                        currentDict[key] = boolValue
                    } else {
                        currentDict[key] = value
                    }
                }
            }
        }

        // Save final array
        if let key = currentKey {
            if !currentDict.isEmpty {
                currentArray.append(currentDict)
            }
            if !currentArray.isEmpty {
                result[key] = currentArray
            }
        }

        return result
    }

}

// MARK: - Markdown to Guion Converter

/// MarkupWalker that converts markdown nodes to GuionElement objects.
private struct MarkdownToGuionConverter: MarkupWalker {
    var elements: [GuionElement] = []

    /// Current nesting level for lists (0 = top level, 1 = nested once, etc.)
    private var listNestingLevel: Int = 0

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
                        text: "> \(text)"
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
                text: "    \(line)" // Indent to indicate code
            )
            elements.append(element)
        }
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        let currentLevel = listNestingLevel
        listNestingLevel += 1

        for child in unorderedList.listItems {
            processListItem(child, level: currentLevel, isOrdered: false, itemNumber: nil)
        }

        listNestingLevel -= 1
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        let currentLevel = listNestingLevel
        listNestingLevel += 1

        var itemNumber = orderedList.startIndex
        for child in orderedList.listItems {
            processListItem(child, level: currentLevel, isOrdered: true, itemNumber: Int(itemNumber))
            itemNumber += 1
        }

        listNestingLevel -= 1
    }

    /// Process a single list item, handling nested lists recursively
    private mutating func processListItem(_ listItem: ListItem, level: Int, isOrdered: Bool, itemNumber: Int?) {
        // Extract text from immediate children (paragraphs), but not nested lists
        var itemText = ""
        var hasNestedList = false

        for child in listItem.children {
            if let paragraph = child as? Paragraph {
                let text = extractText(from: paragraph)
                if !itemText.isEmpty {
                    itemText.append(" ")
                }
                itemText.append(text)
            } else if child is UnorderedList || child is OrderedList {
                hasNestedList = true
            }
        }

        // Create list item element with proper type and level
        if !itemText.isEmpty {
            let elementType: ElementType
            if isOrdered {
                elementType = .orderedListItem(level: level)
            } else {
                elementType = .unorderedListItem(level: level)
            }

            let element = GuionElement(
                type: elementType,
                text: itemText
            )
            elements.append(element)
        }

        // Process nested lists
        if hasNestedList {
            for child in listItem.children {
                if let nestedUnorderedList = child as? UnorderedList {
                    visitUnorderedList(nestedUnorderedList)
                } else if let nestedOrderedList = child as? OrderedList {
                    visitOrderedList(nestedOrderedList)
                }
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
                text.append(textNode.string)
            } else if let code = child as? InlineCode {
                text.append(code.code)
            } else if child is SoftBreak {
                text.append(" ")
            } else if child is LineBreak {
                text.append("\n")
            } else if let emphasis = child as? Emphasis {
                text.append(extractText(from: emphasis))
            } else if let strong = child as? Strong {
                text.append(extractText(from: strong))
            } else if let link = child as? Link {
                // Extract link text (ignore URL)
                text.append(extractText(from: link))
            } else if let image = child as? Image {
                // Use alt text for images
                text.append(extractText(from: image))
            } else if child.childCount > 0 {
                // Recursively extract from any other nodes with children
                text.append(extractText(from: child))
            }
        }

        return text
    }
}
