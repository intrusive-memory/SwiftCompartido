//
//  FountainScript+Outline.swift
//  SwiftFountain
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

extension GuionParsedScreenplay {

    /// Extract outline elements from the script
    /// - Returns: An array of outline elements representing the script structure
    public func extractOutline() -> OutlineList {
        var outline: OutlineList = []
        var outlineIndex = 0
        var characterPosition = 0
        var parentStack: [OutlineElement] = [] // Stack to track parent elements

        // First pass: check if we have any level 1 headers
        var levelOneCount = 0
        for element in elements {
            if element.elementType == .sectionHeading(level: 1) {
                levelOneCount += 1
            }
        }

        // If no level 1 header exists, add the script title as level 1
        if levelOneCount == 0 {
            let scriptTitle = getScriptTitle()
            let titleId = "outline-\(outlineIndex)"
            let titleElement = OutlineElement(
                id: titleId,
                index: outlineIndex,
                level: 1,
                range: [0, scriptTitle.count],
                rawString: "# \(scriptTitle)",
                string: scriptTitle,
                type: "sectionHeader",
                sceneDirective: nil,
                sceneDirectiveDescription: nil,
                parentId: nil,
                childIds: [],
                isEndMarker: false,
                sceneId: nil,
                isSynthetic: true
            )
            outline.append(titleElement)
            parentStack.append(titleElement)
            outlineIndex += 1
        }
        
        for element in elements {
            var shouldInclude = false
            var outlineType = ""
            var level = -1

            // Determine if this element should be in the outline
            switch element.elementType {
            case .sectionHeading(let sectionLevel):
                shouldInclude = true
                outlineType = "sectionHeader"
                level = sectionLevel

            case .sceneHeading:
                shouldInclude = true
                outlineType = "sceneHeader"
                // Scene headings are typically level 4, but promote to level 3 when there's no intermediate directive
                level = 4
                if let structuralParent = parentStack.last(where: { $0.level < 4 }) {
                    level = max(3, structuralParent.level + 1)
                }

            case .comment:
                // Include notes (comments in brackets)
                if element.elementText.hasPrefix("NOTE:") || element.elementText.hasPrefix(" NOTE:") {
                    shouldInclude = true
                    outlineType = "note"
                    level = 5
                }

            default:
                break
            }

            if shouldInclude {
                let rawString = rawStringForElement(element)
                var cleanString = cleanStringForElement(element, type: outlineType, level: level)
                let length = rawString.count
                
                var sceneDirective: String? = nil
                var sceneDirectiveDescription: String? = nil
                var isEndMarker = false
                var hasHierarchyError = false

                // Check if this is an END marker for level 2 (chapter) elements
                if level == 2 && outlineType == "sectionHeader" {
                    let trimmedText = element.elementText.trimmingCharacters(in: .whitespaces).uppercased()
                    if trimmedText.hasPrefix("END") {
                        // Check if it's just "END" or "END" followed by words
                        let words = trimmedText.components(separatedBy: .whitespaces)
                        if words.first == "END" {
                            isEndMarker = true
                        }
                    }

                    // Check if this is a technical directive at the wrong level (should be level 3)
                    let technicalDirectives = ["SHOT:", "CUT TO:", "FADE IN:", "FADE OUT:", "DISSOLVE TO:", "MATCH CUT:", "SMASH CUT:"]
                    if technicalDirectives.contains(where: { trimmedText.hasPrefix($0) }) {
                        hasHierarchyError = true
                    }
                }
                
                // For level 3 section headers, extract scene directive information
                if level == 3 && outlineType == "sectionHeader" {
                    let fullText = element.elementText.trimmingCharacters(in: .whitespaces)
                    var directiveText = fullText

                    // Extract scene directive description (everything after S#)
                    if let markerRange = fullText.range(of: "S#") {
                        sceneDirectiveDescription = String(fullText[markerRange.lowerBound...]).trimmingCharacters(in: .whitespaces)
                        directiveText = String(fullText[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    }

                    // Extract directive name (handle colon separator if present)
                    if let colonIndex = directiveText.firstIndex(of: ":") {
                        let beforeColon = String(directiveText[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                        directiveText = beforeColon
                    }

                    if !directiveText.isEmpty {
                        sceneDirective = directiveText
                        cleanString = directiveText
                    }
                }

                if outlineType == "sceneHeader" && level == 3 {
                    if sceneDirective == nil {
                        sceneDirective = cleanString
                    }
                }
                
                // Determine parent-child relationships
                var parentId: String? = nil

                // Update parent stack based on current level
                while !parentStack.isEmpty && parentStack.last!.level >= level {
                    parentStack.removeLast()
                }

                // Check if we need to create synthetic elements for missing levels
                if !parentStack.isEmpty && !isEndMarker {
                    let lastStackLevel = parentStack.last?.level ?? 0
                    let expectedParentLevel = level - 1

                    if lastStackLevel < expectedParentLevel {
                        // We have a gap - need to create synthetic elements for missing levels
                        for syntheticLevel in (lastStackLevel + 1)...expectedParentLevel {
                            // Check if we already have a synthetic element at this level with the same parent
                            let potentialParent = parentStack.last
                            let existingSynthetic = outline.first {
                                $0.level == syntheticLevel &&
                                $0.isSynthetic &&
                                $0.parentId == potentialParent?.id
                            }

                            if let existing = existingSynthetic {
                                // Reuse existing synthetic element
                                parentStack.append(existing)
                            } else {
                                // Create new synthetic element
                                let syntheticId = "outline-\(outlineIndex)"
                                let syntheticParentId = potentialParent?.id

                                let syntheticElement = OutlineElement(
                                    id: syntheticId,
                                    index: outlineIndex,
                                    level: syntheticLevel,
                                    range: [characterPosition, 0],
                                    rawString: "",
                                    string: "(Untitled Section)",
                                    type: "sectionHeader",
                                    sceneDirective: nil,
                                    sceneDirectiveDescription: nil,
                                    parentId: syntheticParentId,
                                    childIds: [],
                                    isEndMarker: false,
                                    sceneId: nil,
                                    isSynthetic: true
                                )

                                outline.append(syntheticElement)

                                // Update parent's children
                                if let syntheticParentId = syntheticParentId,
                                   let parentIndex = outline.firstIndex(where: { $0.id == syntheticParentId }) {
                                    outline[parentIndex].childIds.append(syntheticId)
                                }

                                parentStack.append(syntheticElement)
                                outlineIndex += 1
                            }
                        }
                    }
                }

                // Set parent if there's a suitable parent in the stack
                if !parentStack.isEmpty && !isEndMarker {
                    if let parent = parentStack.last(where: { $0.level < level }) {
                        parentId = parent.id
                    }
                }

                let elementId = "outline-\(outlineIndex)"

                // Link scene UUID for Scene Heading elements
                var linkedSceneId: String? = nil
                if outlineType == "sceneHeader" {
                    linkedSceneId = element.sceneId
                }

                let outlineElement = OutlineElement(
                    id: elementId,
                    index: outlineIndex,
                    level: level,
                    range: [characterPosition, length],
                    rawString: rawString,
                    string: cleanString,
                    type: outlineType,
                    sceneDirective: sceneDirective,
                    sceneDirectiveDescription: sceneDirectiveDescription,
                    parentId: parentId,
                    childIds: [],
                    isEndMarker: isEndMarker,
                    sceneId: linkedSceneId,
                    isSynthetic: false,
                    hasHierarchyError: hasHierarchyError
                )

                outline.append(outlineElement)

                // Add this element to parent's children if it has a parent
                if let parentId = parentId,
                   let parentIndex = outline.firstIndex(where: { $0.id == parentId }) {
                    outline[parentIndex].childIds.append(outlineElement.id)
                }

                // Add to parent stack if it's a structural element (not end marker)
                if !isEndMarker {
                    parentStack.append(outlineElement)
                }
                
                outlineIndex += 1
            }

            // Track character position
            characterPosition += approximateElementLength(element)
        }

        // Add a final blank element if we have content
        if !outline.isEmpty {
            let blankId = "outline-\(outlineIndex)"
            outline.append(OutlineElement(
                id: blankId,
                index: outlineIndex,
                level: -1,
                range: [characterPosition, 0],
                rawString: "",
                string: "",
                type: "blank",
                sceneDirective: nil,
                sceneDirectiveDescription: nil,
                parentId: nil,
                childIds: [],
                isEndMarker: false
            ))
        }

        return outline
    }

    /// Write outline to a JSON file
    /// - Parameter path: File path to write the JSON to
    /// - Throws: File writing errors
    public func writeOutlineJSON(toFile path: String) throws {
        let outline = exportableOutline(extractOutline())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(outline)
        try data.write(to: URL(fileURLWithPath: path))
    }

    /// Write outline to a JSON file URL
    /// - Parameter url: File URL to write the JSON to
    /// - Throws: File writing errors
    public func writeOutlineJSON(to url: URL) throws {
        let outline = exportableOutline(extractOutline())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(outline)
        try data.write(to: url)
    }

    /// Extract outline and return as a tree structure
    /// - Returns: An OutlineTree representing the hierarchical structure
    public func extractOutlineTree() -> OutlineTree {
        let outline = extractOutline()
        return outline.tree()
    }

    // MARK: - Private Helpers

    private func exportableOutline(_ outline: OutlineList) -> OutlineList {
        guard let mainTitle = outline.first(where: { $0.level == 1 && $0.parentId == nil }) else {
            return outline
        }

        let removedId = mainTitle.id
        var exportOutline: OutlineList = []
        exportOutline.reserveCapacity(outline.count - 1)

        for element in outline where element.id != removedId {
            var mutableElement = element
            if mutableElement.parentId == removedId {
                mutableElement.parentId = nil
            }
            mutableElement.childIds.removeAll(where: { $0 == removedId })
            mutableElement.index = exportOutline.count
            exportOutline.append(mutableElement)
        }

        return exportOutline
    }
    
    /// Get the script title from filename or title page
    private func getScriptTitle() -> String {
        // First, try to get title from title page
        for titlePageSection in titlePage {
            if let title = titlePageSection["Title"] ?? titlePageSection["title"] {
                if let firstTitle = title.first, !firstTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                    return firstTitle.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // If no title page title, use filename without extension
        if let filename = filename {
            let url = URL(fileURLWithPath: filename)
            let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
            return nameWithoutExtension
        }
        
        // Default fallback
        return "Untitled Script"
    }

    /// Get the raw string representation of an element (as it appears in source)
    private func rawStringForElement(_ element: GuionElement) -> String {
        switch element.elementType {
        case .sectionHeading(let level):
            // Reconstruct with # marks based on depth
            let hashes = String(repeating: "#", count: level)
            // Check if element text already starts with space, if not add one
            let text = element.elementText
            let separator = text.hasPrefix(" ") ? "" : " "
            return "\(hashes)\(separator)\(text)"

        case .sceneHeading:
            return element.elementText

        case .comment:
            // Restore note format
            if element.elementText.hasPrefix("NOTE:") || element.elementText.hasPrefix(" NOTE:") {
                return "[[\(element.elementText)]]"
            }
            return element.elementText

        default:
            return element.elementText
        }
    }

    /// Clean the string for display (remove formatting markers)
    private func cleanStringForElement(_ element: GuionElement, type: String, level: Int = -1) -> String {
        var cleaned = element.elementText.trimmingCharacters(in: .whitespaces)

        if type == "note" {
            // Remove NOTE: prefix if present
            if cleaned.hasPrefix("NOTE:") {
                cleaned = String(cleaned.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if cleaned.hasPrefix(" NOTE:") {
                cleaned = String(cleaned.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            }
        } else if type == "sectionHeader" && level == 3 {
            // Level 3 headers are scene directive level - extract directive name
            if let colonIndex = cleaned.firstIndex(of: ":") {
                // Extract just the first word before the colon as the directive name
                let beforeColon = String(cleaned[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                if let firstWordEnd = beforeColon.firstIndex(of: " ") {
                    let firstWord = String(beforeColon[..<firstWordEnd])
                    cleaned = firstWord
                } else {
                    cleaned = beforeColon
                }
            }
        }

        return cleaned
    }

    /// Approximate the character length of an element in the source text
    private func approximateElementLength(_ element: GuionElement) -> Int {
        // This is an approximation - the actual fountain source would need to be parsed
        // for exact positions, but this gives reasonable ranges
        let baseLength = element.elementText.count

        switch element.elementType {
        case .sectionHeading(let level):
            // Add # marks and spaces
            return level + 1 + baseLength + 2 // hashes + space + text + newlines

        case .sceneHeading:
            return baseLength + 2 // text + newlines

        case .character:
            return baseLength + 2

        case .dialogue:
            return baseLength + 2

        case .action:
            return baseLength + 2

        case .comment:
            return baseLength + 6 // [[ ]] + newlines

        default:
            return baseLength + 2
        }
    }
}
