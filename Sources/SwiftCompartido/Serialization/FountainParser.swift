//
//  FountainParser.swift
//  SwiftGuion
//
//  Copyright (c) 2012-2013 Nima Yousefi & John August
//  Swift conversion (c) 2025
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

/// Parses Fountain format screenplay files into GuionElements
public class FountainParser: @unchecked Sendable {
    public var elements: [GuionElement] = []
    public var titlePage: [[String: [String]]] = []

    private static let inlinePattern = "^([^\\t\\s][^:]+):\\s*([^\\t\\s].*$)"
    private static let directivePattern = "^([^\\t\\s][^:]+):([\\t\\s]*$)"

    // MARK: - Cached Regex Patterns

    /// Cached compiled regex patterns for maximum performance
    /// Patterns are compiled once and reused throughout parsing
    private static let regexCache: [String: (pattern: NSRegularExpression, caseInsensitive: NSRegularExpression?)] = {
        var cache: [String: (pattern: NSRegularExpression, caseInsensitive: NSRegularExpression?)] = [:]

        let patterns: [(key: String, pattern: String, needsCaseInsensitive: Bool)] = [
            ("directive", directivePattern, false),
            ("inline", inlinePattern, false),
            ("twoSpaces", "^\\s{2}$", false),
            ("twoOrMoreSpaces", "^\\s{2,}$", false),
            ("commentStart", "^\\/\\*", false),
            ("commentEnd", "\\*\\/\\s*$", false),
            ("whitespaceOnly", "^\\s*$", false),
            ("pageBreak", "^={3,}\\s*$", false),
            ("section", "^\\s*\\[{2}\\s*([^\\]\\n])+\\s*\\]{2}\\s*$", false),
            ("synopsis", "^\\s*=\\s+", false),
            ("sceneNumber", "#([^\\n#]*?)#\\s*$", false),
            ("sceneHeading", "^(INT|EXT|EST|(I|INT)\\.?\\/(E|EXT)\\.?)[\\.\\-\\s][^\\n]+$", true),
            ("overBlack", "^OVER BLACK$", true),
            ("transition", "[^a-z]*TO:$", false),
            ("character", "^[^a-z]+(\\(cont'd\\))?$", false),
            ("dualDialogueMarker", "\\^\\s*$", false),
            ("parenthetical", "^\\s*\\(", false),
            ("leadingWhitespace", "^\\s*", false),
            ("lineEndings", "\\r\\n|\\r|\\n", false)
        ]

        for (key, patternString, needsCaseInsensitive) in patterns {
            do {
                let regex = try NSRegularExpression(pattern: patternString, options: [])
                let caseInsensitiveRegex = needsCaseInsensitive ? try NSRegularExpression(pattern: patternString, options: [.caseInsensitive]) : nil
                cache[key] = (pattern: regex, caseInsensitive: caseInsensitiveRegex)
            } catch {
                print("Warning: Failed to compile regex pattern '\(key)': \(error)")
            }
        }

        return cache
    }()

    public init(file filePath: String) throws {
        let contents = try String(contentsOfFile: filePath, encoding: .utf8)
        parseContents(contents)
    }

    public init(string: String) {
        parseContents(string)
    }

    /// Creates a parser with progress reporting support.
    ///
    /// This async initializer parses a Fountain screenplay with progress updates and
    /// cancellation support. Progress is reported approximately every 100 lines.
    ///
    /// Parsing is automatically offloaded to a background thread to prevent blocking
    /// the main thread during long operations.
    ///
    /// - Parameters:
    ///   - string: The Fountain format text to parse
    ///   - progress: Optional progress tracker for monitoring parse progress
    ///
    /// - Throws: `CancellationError` if the task is cancelled during parsing
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let progress = OperationProgress(totalUnits: nil) { update in
    ///     print("Parsing: \(Int((update.fractionCompleted ?? 0) * 100))%")
    /// }
    ///
    /// let parser = try await FountainParser(string: screenplay, progress: progress)
    /// ```
    public init(string: String, progress: OperationProgress? = nil) async throws {
        // Offload parsing to background thread to prevent main thread blocking
        // Using Task with priority ensures background execution while inheriting cancellation
        let parseTask = Task(priority: .userInitiated) { [self] in
            try await self.parseContentsAsync(string, progress: progress)
        }

        // Check if already cancelled before awaiting
        try Task.checkCancellation()

        // Await the result (cancellation will propagate automatically)
        try await parseTask.value
    }

    private func parseContents(_ contents: String) {
        // Trim leading newlines from the document
        var processedContents = contents.replacingOccurrences(of: "^\\s*", with: "", options: .regularExpression)
        processedContents = processedContents.replacingOccurrences(of: "\\r\\n|\\r|\\n", with: "\n", options: .regularExpression)
        processedContents = "\(processedContents)\n\n"

        // Find the first newline
        guard let firstBlankLineRange = processedContents.range(of: "\n\n") else { return }
        let topOfDocument = String(processedContents[..<firstBlankLineRange.lowerBound])

        // ----------------------------------------------------------------------
        // TITLE PAGE
        // ----------------------------------------------------------------------
        var foundTitlePage = false
        var openKey = ""
        var openValues: [String] = []
        let topLines = topOfDocument.components(separatedBy: "\n")

        for line in topLines {
            if line.isEmpty || matchesCached(string: line, patternKey: "directive") {
                foundTitlePage = true
                // If a key was open we want to close it
                if !openKey.isEmpty {
                    titlePage.append([openKey: openValues])
                }

                if var key = firstMatchCached(in: line, patternKey: "directive", captureGroup: 1)?.lowercased() {
                    if key == "author" {
                        key = "authors"
                    }
                    openKey = key
                    openValues = []
                }
            } else if matchesCached(string: line, patternKey: "inline") {
                foundTitlePage = true
                // If a key was open we want to close it
                if !openKey.isEmpty {
                    titlePage.append([openKey: openValues])
                    openKey = ""
                    openValues = []
                }

                if var key = firstMatchCached(in: line, patternKey: "inline", captureGroup: 1)?.lowercased(),
                   let value = firstMatchCached(in: line, patternKey: "inline", captureGroup: 2) {
                    if key == "author" {
                        key = "authors"
                    }
                    titlePage.append([key: [value]])
                    openKey = ""
                    openValues = []
                }
            } else if foundTitlePage {
                openValues.append(line.trimmingCharacters(in: .whitespaces))
            }
        }

        if foundTitlePage {
            if openKey.isEmpty && openValues.isEmpty && titlePage.isEmpty {
                // do nothing
            } else {
                // Close any remaining directives
                if !openKey.isEmpty {
                    titlePage.append([openKey: openValues])
                    openKey = ""
                    openValues = []
                }
                processedContents = processedContents.replacingOccurrences(of: topOfDocument, with: "")
            }
        }

        // ----------------------------------------------------------------------
        // BODY
        // ----------------------------------------------------------------------
        processedContents = "\n\(processedContents)"
        let lines = processedContents.components(separatedBy: .newlines)

        var newlinesBefore = 0
        var index = -1
        var isCommentBlock = false
        var isInsideDialogueBlock = false
        var commentText = ""
        var lastCharacterIndex: Int? = nil  // Cache last character index for O(1) dual dialogue detection

        for line in lines {
            index += 1

            // Lyrics
            if !line.isEmpty && line.first == "~" {
                if let lastElement = elements.last, lastElement.elementType == .lyrics && newlinesBefore > 0 {
                    elements.append(GuionElement(type: .lyrics, text: " "))
                }

                elements.append(GuionElement(type: .lyrics, text: line))
                newlinesBefore = 0
                continue
            }

            // Forced action
            if !line.isEmpty && line.first == "!" {
                elements.append(GuionElement(type: .action, text: line))
                newlinesBefore = 0
                continue
            }

            // Forced character
            if !line.isEmpty && line.first == "@" {
                elements.append(GuionElement(type: .character, text: line))
                newlinesBefore = 0
                isInsideDialogueBlock = true
                continue
            }

            // Empty lines within dialogue -- denoted by two spaces inside a dialogue block
            if matchesCached(string: line, patternKey: "twoSpaces") && isInsideDialogueBlock {
                newlinesBefore = 0
                if let lastIndex = elements.indices.last {
                    if elements[lastIndex].elementType == .dialogue {
                        elements[lastIndex].elementText.append("\n\(line)")
                    } else {
                        elements.append(GuionElement(type: .dialogue, text: line))
                    }
                } else {
                    elements.append(GuionElement(type: .dialogue, text: line))
                }
                continue
            }

            // Multiple spaces (action)
            if matchesCached(string: line, patternKey: "twoOrMoreSpaces") {
                elements.append(GuionElement(type: .action, text: line))
                newlinesBefore = 0
                continue
            }

            // Blank line
            if line.isEmpty && !isCommentBlock {
                isInsideDialogueBlock = false
                newlinesBefore += 1
                continue
            }

            // Open Boneyard
            if matchesCached(string: line, patternKey: "commentStart") {
                if matchesCached(string: line, patternKey: "commentEnd") {
                    let text = line
                        .replacingOccurrences(of: "/*", with: "")
                        .replacingOccurrences(of: "*/", with: "")
                    isCommentBlock = false
                    elements.append(GuionElement(type: .boneyard, text: text))
                    newlinesBefore = 0
                } else {
                    isCommentBlock = true
                    commentText.append("\n")
                }
                continue
            }

            // Close Boneyard
            if matchesCached(string: line, patternKey: "commentEnd") {
                let text = line.replacingOccurrences(of: "*/", with: "")
                if !text.isEmpty && !matchesCached(string: text, patternKey: "whitespaceOnly") {
                    commentText.append(text.trimmingCharacters(in: .whitespaces))
                }
                isCommentBlock = false
                elements.append(GuionElement(type: .boneyard, text: commentText))
                commentText = ""
                newlinesBefore = 0
                continue
            }

            // Inside the Boneyard
            if isCommentBlock {
                commentText.append(line)
                commentText.append("\n")
                continue
            }

            // Page Breaks
            if matchesCached(string: line, patternKey: "pageBreak") {
                elements.append(GuionElement(type: .pageBreak, text: line))
                newlinesBefore = 0
                continue
            }

            // Synopsis (Outline Summary)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if !trimmedLine.isEmpty && trimmedLine.first == "=" {
                if let markupRange = line.range(of: "^\\s*={1}", options: .regularExpression) {
                    let text = String(line[markupRange.upperBound...])
                    elements.append(GuionElement(type: .synopsis, text: text))
                    continue
                }
            }

            // Comment
            if newlinesBefore > 0 && matchesCached(string: line, patternKey: "section") {
                let text = line
                    .replacingOccurrences(of: "[[", with: "")
                    .replacingOccurrences(of: "]]", with: "")
                    .trimmingCharacters(in: .whitespaces)
                elements.append(GuionElement(type: .comment, text: text))
                continue
            }

            // Synopsis
            if newlinesBefore > 0 && matchesCached(string: line, patternKey: "synopsis") {
                let text = line
                    .replacingOccurrences(of: "^\\s*=\\s+", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                elements.append(GuionElement(type: .synopsis, text: text))
                newlinesBefore = 0
                continue
            }

            // Section heading (Outline elements)
            if !trimmedLine.isEmpty && trimmedLine.first == "#" {
                newlinesBefore = 0

                if let markupRange = line.range(of: "^\\s*#+", options: .regularExpression) {
                    let depth = line.distance(from: markupRange.lowerBound, to: markupRange.upperBound)
                    let text = String(line[markupRange.upperBound...])

                    if !text.isEmpty {
                        // Create section heading with level directly in the enum
                        let element = GuionElement(type: .sectionHeading(level: depth), text: text)
                        elements.append(element)
                        continue
                    }
                }
            }

            // Forced scene heading
            if line.count > 1 && line.first == "." && line[line.index(line.startIndex, offsetBy: 1)] != "." {
                newlinesBefore = 0
                var sceneNumber: String?
                var text = ""

                if matchesCached(string: line, patternKey: "sceneNumber") {
                    sceneNumber = firstMatchCached(in: line, patternKey: "sceneNumber", captureGroup: 1)
                    text = line.replacingOccurrences(of: "#([^\\n#]*?)#\\s*$", with: "", options: .regularExpression)
                    text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
                } else {
                    text = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                }

                var element = GuionElement(type: .sceneHeading, text: text)
                element.sceneNumber = sceneNumber
                element.sceneId = UUID().uuidString
                elements.append(element)
                continue
            }

            // Scene Headings
            if newlinesBefore > 0 && (matchesCached(string: line, patternKey: "sceneHeading", caseInsensitive: true) || matchesCached(string: line, patternKey: "overBlack", caseInsensitive: true)) {
                newlinesBefore = 0
                var sceneNumber: String?
                var text = ""

                if matchesCached(string: line, patternKey: "sceneNumber") {
                    sceneNumber = firstMatchCached(in: line, patternKey: "sceneNumber", captureGroup: 1)
                    text = line.replacingOccurrences(of: "#([^\\n#]*?)#\\s*$", with: "", options: .regularExpression)
                } else {
                    text = line
                }

                var element = GuionElement(type: .sceneHeading, text: text)
                element.sceneNumber = sceneNumber
                element.sceneId = UUID().uuidString
                elements.append(element)
                continue
            }

            // Transitions
            if matchesCached(string: line, patternKey: "transition") {
                newlinesBefore = 0
                elements.append(GuionElement(type: .transition, text: line))
                continue
            }

            let lineWithTrimmedLeading = line.replacingOccurrences(of: "^\\s*", with: "", options: .regularExpression)
            let transitions: Set<String> = ["FADE OUT.", "CUT TO BLACK.", "FADE TO BLACK."]
            if transitions.contains(lineWithTrimmedLeading) {
                newlinesBefore = 0
                elements.append(GuionElement(type: .transition, text: line))
                continue
            }

            // Forced transitions and centered text
            if !line.isEmpty && line.first == ">" {
                if line.count > 1 && line.last == "<" {
                    var text = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                    text = String(text.dropLast()).trimmingCharacters(in: .whitespaces)

                    var element = GuionElement(type: .action, text: text)
                    element.isCentered = true
                    elements.append(element)
                    newlinesBefore = 0
                    continue
                } else {
                    let text = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                    elements.append(GuionElement(type: .transition, text: text))
                    newlinesBefore = 0
                    continue
                }
            }

            // Character
            if newlinesBefore > 0 && matchesCached(string: line, patternKey: "character") {
                // Look ahead to see if the next line is blank
                let nextIndex = index + 1
                if nextIndex < lines.count {
                    let nextLine = lines[nextIndex]
                    if !nextLine.isEmpty {
                        newlinesBefore = 0
                        var element = GuionElement(type: .character, text: line)

                        if matchesCached(string: line, patternKey: "dualDialogueMarker") {
                            element.isDualDialogue = true
                            element.elementText = element.elementText.replacingOccurrences(of: "\\s*\\^\\s*$", with: "", options: .regularExpression)

                            // Mark previous character element as dual dialogue using cached index (O(1))
                            if let lastIdx = lastCharacterIndex {
                                elements[lastIdx].isDualDialogue = true
                            }
                        }

                        lastCharacterIndex = elements.count  // Cache this character's index
                        elements.append(element)
                        isInsideDialogueBlock = true
                        continue
                    }
                }
            }

            // Dialogue and Parentheticals
            if isInsideDialogueBlock {
                if newlinesBefore == 0 && matchesCached(string: line, patternKey: "parenthetical") {
                    elements.append(GuionElement(type: .parenthetical, text: line))
                    continue
                } else {
                    if let lastIndex = elements.indices.last {
                        if elements[lastIndex].elementType == .dialogue {
                            elements[lastIndex].elementText.append("\n\(line)")
                        } else {
                            elements.append(GuionElement(type: .dialogue, text: line))
                        }
                    } else {
                        elements.append(GuionElement(type: .dialogue, text: line))
                    }
                    continue
                }
            }

            // Merge with previous action if no blank line
            if newlinesBefore == 0 && !elements.isEmpty {
                let lastIndex = elements.count - 1

                // Scene Heading must be surrounded by blank lines
                if elements[lastIndex].elementType == .sceneHeading {
                    elements[lastIndex].elementType = .action
                }

                elements[lastIndex].elementText.append("\n\(line)")
                newlinesBefore = 0
                continue
            } else {
                elements.append(GuionElement(type: .action, text: line))
                newlinesBefore = 0
                continue
            }
        }
    }

    /// Async version of parseContents with progress reporting and cancellation support.
    ///
    /// This method parses Fountain content with the same logic as `parseContents(_:)` but
    /// adds progress updates every 100 lines and checks for task cancellation.
    ///
    /// - Parameters:
    ///   - contents: The Fountain format text to parse
    ///   - progress: Optional progress tracker
    ///
    /// - Throws: `CancellationError` if `Task.isCancelled` becomes true during parsing
    private func parseContentsAsync(_ contents: String, progress: OperationProgress?) async throws {
        // Trim leading newlines from the document
        var processedContents = contents.replacingOccurrences(of: "^\\s*", with: "", options: .regularExpression)
        processedContents = processedContents.replacingOccurrences(of: "\\r\\n|\\r|\\n", with: "\n", options: .regularExpression)
        processedContents = "\(processedContents)\n\n"

        // Find the first newline
        guard let firstBlankLineRange = processedContents.range(of: "\n\n") else { return }
        let topOfDocument = String(processedContents[..<firstBlankLineRange.lowerBound])

        // ----------------------------------------------------------------------
        // TITLE PAGE
        // ----------------------------------------------------------------------
        var foundTitlePage = false
        var openKey = ""
        var openValues: [String] = []
        let topLines = topOfDocument.components(separatedBy: "\n")

        // Set total units for progress (title page lines + body lines)
        let totalLines = processedContents.components(separatedBy: .newlines).count
        progress?.setTotalUnitCount(Int64(totalLines))

        // Calculate progress update interval (report every 1% or every line if < 100 lines)
        let titlePageUpdateInterval = max(1, topLines.count / 100)

        for (lineIndex, line) in topLines.enumerated() {
            // Check for cancellation
            try Task.checkCancellation()

            if line.isEmpty || matchesCached(string: line, patternKey: "directive") {
                foundTitlePage = true
                // If a key was open we want to close it
                if !openKey.isEmpty {
                    titlePage.append([openKey: openValues])
                }

                if var key = firstMatchCached(in: line, patternKey: "directive", captureGroup: 1)?.lowercased() {
                    if key == "author" {
                        key = "authors"
                    }
                    openKey = key
                    openValues = []
                }
            } else if matchesCached(string: line, patternKey: "inline") {
                foundTitlePage = true
                // If a key was open we want to close it
                if !openKey.isEmpty {
                    titlePage.append([openKey: openValues])
                    openKey = ""
                    openValues = []
                }

                if var key = firstMatchCached(in: line, patternKey: "inline", captureGroup: 1)?.lowercased(),
                   let value = firstMatchCached(in: line, patternKey: "inline", captureGroup: 2) {
                    if key == "author" {
                        key = "authors"
                    }
                    titlePage.append([key: [value]])
                    openKey = ""
                    openValues = []
                }
            } else if foundTitlePage {
                openValues.append(line.trimmingCharacters(in: .whitespaces))
            }

            // Report progress every 1% (or every line if < 100 lines)
            if lineIndex % titlePageUpdateInterval == 0 {
                progress?.update(
                    completedUnits: Int64(lineIndex),
                    description: "Parsing title page..."
                )
            }
        }

        if foundTitlePage {
            if openKey.isEmpty && openValues.isEmpty && titlePage.isEmpty {
                // do nothing
            } else {
                // Close any remaining directives
                if !openKey.isEmpty {
                    titlePage.append([openKey: openValues])
                    openKey = ""
                    openValues = []
                }
                processedContents = processedContents.replacingOccurrences(of: topOfDocument, with: "")
            }
        }

        // ----------------------------------------------------------------------
        // BODY
        // ----------------------------------------------------------------------
        processedContents = "\n\(processedContents)"
        let lines = processedContents.components(separatedBy: .newlines)

        var newlinesBefore = 0
        var index = -1
        var isCommentBlock = false
        var isInsideDialogueBlock = false
        var commentText = ""
        var lastCharacterIndex: Int? = nil  // Cache last character index for O(1) dual dialogue detection

        let titlePageLineCount = topLines.count
        // Calculate progress update interval for body (report every 1% or every line if < 100 lines)
        let bodyUpdateInterval = max(1, lines.count / 100)

        for line in lines {
            index += 1

            // Check for cancellation and report progress every 1%
            if index % bodyUpdateInterval == 0 {
                try Task.checkCancellation()
                progress?.update(
                    completedUnits: Int64(titlePageLineCount + index),
                    description: "Parsing screenplay... (\(elements.count) elements)"
                )
            }

            // Lyrics
            if !line.isEmpty && line.first == "~" {
                if let lastElement = elements.last, lastElement.elementType == .lyrics && newlinesBefore > 0 {
                    elements.append(GuionElement(type: .lyrics, text: " "))
                }

                elements.append(GuionElement(type: .lyrics, text: line))
                newlinesBefore = 0
                continue
            }

            // Forced action
            if !line.isEmpty && line.first == "!" {
                elements.append(GuionElement(type: .action, text: line))
                newlinesBefore = 0
                continue
            }

            // Forced character
            if !line.isEmpty && line.first == "@" {
                elements.append(GuionElement(type: .character, text: line))
                newlinesBefore = 0
                isInsideDialogueBlock = true
                continue
            }

            // Empty lines within dialogue -- denoted by two spaces inside a dialogue block
            if matchesCached(string: line, patternKey: "twoSpaces") && isInsideDialogueBlock {
                newlinesBefore = 0
                if let lastIndex = elements.indices.last {
                    if elements[lastIndex].elementType == .dialogue {
                        elements[lastIndex].elementText.append("\n\(line)")
                    } else {
                        elements.append(GuionElement(type: .dialogue, text: line))
                    }
                } else {
                    elements.append(GuionElement(type: .dialogue, text: line))
                }
                continue
            }

            // Multiple spaces (action)
            if matchesCached(string: line, patternKey: "twoOrMoreSpaces") {
                elements.append(GuionElement(type: .action, text: line))
                newlinesBefore = 0
                continue
            }

            // Blank line
            if line.isEmpty && !isCommentBlock {
                isInsideDialogueBlock = false
                newlinesBefore += 1
                continue
            }

            // Open Boneyard
            if matchesCached(string: line, patternKey: "commentStart") {
                if matchesCached(string: line, patternKey: "commentEnd") {
                    let text = line
                        .replacingOccurrences(of: "/*", with: "")
                        .replacingOccurrences(of: "*/", with: "")
                    isCommentBlock = false
                    elements.append(GuionElement(type: .boneyard, text: text))
                    newlinesBefore = 0
                } else {
                    isCommentBlock = true
                    commentText.append("\n")
                }
                continue
            }

            // Close Boneyard
            if matchesCached(string: line, patternKey: "commentEnd") {
                let text = line.replacingOccurrences(of: "*/", with: "")
                if !text.isEmpty && !matchesCached(string: text, patternKey: "whitespaceOnly") {
                    commentText.append(text.trimmingCharacters(in: .whitespaces))
                }
                isCommentBlock = false
                elements.append(GuionElement(type: .boneyard, text: commentText))
                commentText = ""
                newlinesBefore = 0
                continue
            }

            // Inside the Boneyard
            if isCommentBlock {
                commentText.append(line)
                commentText.append("\n")
                continue
            }

            // Page Breaks
            if matchesCached(string: line, patternKey: "pageBreak") {
                elements.append(GuionElement(type: .pageBreak, text: line))
                newlinesBefore = 0
                continue
            }

            // Synopsis (Outline Summary)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if !trimmedLine.isEmpty && trimmedLine.first == "=" {
                if let markupRange = line.range(of: "^\\s*={1}", options: .regularExpression) {
                    let text = String(line[markupRange.upperBound...])
                    elements.append(GuionElement(type: .synopsis, text: text))
                    continue
                }
            }

            // Comment
            if newlinesBefore > 0 && matchesCached(string: line, patternKey: "section") {
                let text = line
                    .replacingOccurrences(of: "[[", with: "")
                    .replacingOccurrences(of: "]]", with: "")
                    .trimmingCharacters(in: .whitespaces)
                elements.append(GuionElement(type: .comment, text: text))
                continue
            }

            // Synopsis
            if newlinesBefore > 0 && matchesCached(string: line, patternKey: "synopsis") {
                let text = line
                    .replacingOccurrences(of: "^\\s*=\\s+", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                elements.append(GuionElement(type: .synopsis, text: text))
                newlinesBefore = 0
                continue
            }

            // Section heading (Outline elements)
            if !trimmedLine.isEmpty && trimmedLine.first == "#" {
                newlinesBefore = 0

                if let markupRange = line.range(of: "^\\s*#+", options: .regularExpression) {
                    let depth = line.distance(from: markupRange.lowerBound, to: markupRange.upperBound)
                    let text = String(line[markupRange.upperBound...])

                    if !text.isEmpty {
                        // Create section heading with level directly in the enum
                        let element = GuionElement(type: .sectionHeading(level: depth), text: text)
                        elements.append(element)
                        continue
                    }
                }
            }

            // Forced scene heading
            if line.count > 1 && line.first == "." && line[line.index(line.startIndex, offsetBy: 1)] != "." {
                newlinesBefore = 0
                var sceneNumber: String?
                var text = ""

                if matchesCached(string: line, patternKey: "sceneNumber") {
                    sceneNumber = firstMatchCached(in: line, patternKey: "sceneNumber", captureGroup: 1)
                    text = line.replacingOccurrences(of: "#([^\\n#]*?)#\\s*$", with: "", options: .regularExpression)
                    text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
                } else {
                    text = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                }

                var element = GuionElement(type: .sceneHeading, text: text)
                element.sceneNumber = sceneNumber
                element.sceneId = UUID().uuidString
                elements.append(element)
                continue
            }

            // Scene Headings
            if newlinesBefore > 0 && (matchesCached(string: line, patternKey: "sceneHeading", caseInsensitive: true) || matchesCached(string: line, patternKey: "overBlack", caseInsensitive: true)) {
                newlinesBefore = 0
                var sceneNumber: String?
                var text = ""

                if matchesCached(string: line, patternKey: "sceneNumber") {
                    sceneNumber = firstMatchCached(in: line, patternKey: "sceneNumber", captureGroup: 1)
                    text = line.replacingOccurrences(of: "#([^\\n#]*?)#\\s*$", with: "", options: .regularExpression)
                } else {
                    text = line
                }

                var element = GuionElement(type: .sceneHeading, text: text)
                element.sceneNumber = sceneNumber
                element.sceneId = UUID().uuidString
                elements.append(element)
                continue
            }

            // Transitions
            if matchesCached(string: line, patternKey: "transition") {
                newlinesBefore = 0
                elements.append(GuionElement(type: .transition, text: line))
                continue
            }

            let lineWithTrimmedLeading = line.replacingOccurrences(of: "^\\s*", with: "", options: .regularExpression)
            let transitions: Set<String> = ["FADE OUT.", "CUT TO BLACK.", "FADE TO BLACK."]
            if transitions.contains(lineWithTrimmedLeading) {
                newlinesBefore = 0
                elements.append(GuionElement(type: .transition, text: line))
                continue
            }

            // Forced transitions and centered text
            if !line.isEmpty && line.first == ">" {
                if line.count > 1 && line.last == "<" {
                    var text = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                    text = String(text.dropLast()).trimmingCharacters(in: .whitespaces)

                    var element = GuionElement(type: .action, text: text)
                    element.isCentered = true
                    elements.append(element)
                    newlinesBefore = 0
                    continue
                } else {
                    let text = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                    elements.append(GuionElement(type: .transition, text: text))
                    newlinesBefore = 0
                    continue
                }
            }

            // Character
            if newlinesBefore > 0 && matchesCached(string: line, patternKey: "character") {
                // Look ahead to see if the next line is blank
                let nextIndex = index + 1
                if nextIndex < lines.count {
                    let nextLine = lines[nextIndex]
                    if !nextLine.isEmpty {
                        newlinesBefore = 0
                        var element = GuionElement(type: .character, text: line)

                        if matchesCached(string: line, patternKey: "dualDialogueMarker") {
                            element.isDualDialogue = true
                            element.elementText = element.elementText.replacingOccurrences(of: "\\s*\\^\\s*$", with: "", options: .regularExpression)

                            // Mark previous character element as dual dialogue using cached index (O(1))
                            if let lastIdx = lastCharacterIndex {
                                elements[lastIdx].isDualDialogue = true
                            }
                        }

                        lastCharacterIndex = elements.count  // Cache this character's index
                        elements.append(element)
                        isInsideDialogueBlock = true
                        continue
                    }
                }
            }

            // Dialogue and Parentheticals
            if isInsideDialogueBlock {
                if newlinesBefore == 0 && matchesCached(string: line, patternKey: "parenthetical") {
                    elements.append(GuionElement(type: .parenthetical, text: line))
                    continue
                } else {
                    if let lastIndex = elements.indices.last {
                        if elements[lastIndex].elementType == .dialogue {
                            elements[lastIndex].elementText.append("\n\(line)")
                        } else {
                            elements.append(GuionElement(type: .dialogue, text: line))
                        }
                    } else {
                        elements.append(GuionElement(type: .dialogue, text: line))
                    }
                    continue
                }
            }

            // Merge with previous action if no blank line
            if newlinesBefore == 0 && !elements.isEmpty {
                let lastIndex = elements.count - 1

                // Scene Heading must be surrounded by blank lines
                if elements[lastIndex].elementType == .sceneHeading {
                    elements[lastIndex].elementType = .action
                }

                elements[lastIndex].elementText.append("\n\(line)")
                newlinesBefore = 0
                continue
            } else {
                elements.append(GuionElement(type: .action, text: line))
                newlinesBefore = 0
                continue
            }
        }

        // Final progress update
        progress?.complete(description: "Parsing complete - \(elements.count) elements")
    }

    // MARK: - Regex Helpers

    /// Fast regex matching using cached compiled patterns
    private func matchesCached(string: String, patternKey: String, caseInsensitive: Bool = false) -> Bool {
        guard let cached = Self.regexCache[patternKey] else {
            print("Warning: Pattern key '\(patternKey)' not found in cache")
            return false
        }

        let regex = caseInsensitive ? (cached.caseInsensitive ?? cached.pattern) : cached.pattern
        let nsString = string as NSString
        return regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: nsString.length)) != nil
    }

    /// Fast regex capture using cached compiled patterns
    private func firstMatchCached(in text: String, patternKey: String, captureGroup: Int) -> String? {
        guard let cached = Self.regexCache[patternKey] else {
            print("Warning: Pattern key '\(patternKey)' not found in cache")
            return nil
        }

        let nsText = text as NSString
        guard let match = cached.pattern.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) else {
            return nil
        }

        guard match.numberOfRanges > captureGroup else { return nil }
        let range = match.range(at: captureGroup)
        guard range.location != NSNotFound else { return nil }
        return nsText.substring(with: range)
    }

    /// Legacy regex matching - compiles pattern on every call (deprecated, use matchesCached)
    private func matches(string: String, pattern: String, caseInsensitive: Bool = false) -> Bool {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return false
        }

        let nsString = string as NSString
        return regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: nsString.length)) != nil
    }

    /// Legacy regex capture - compiles pattern on every call (deprecated, use firstMatchCached)
    private func firstMatch(in text: String, pattern: String, captureGroup: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) else {
            return nil
        }

        guard match.numberOfRanges > captureGroup else { return nil }
        let range = match.range(at: captureGroup)
        guard range.location != NSNotFound else { return nil }
        return nsText.substring(with: range)
    }
}
