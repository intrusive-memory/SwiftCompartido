//
//  FountainWriter.swift
//  SwiftFountain
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

public class FountainWriter {

    public static func document(from script: GuionParsedScreenplay) -> String {
        let documentContent = body(from: script)
        let titlePageContent = titlePage(from: script)

        var document = ""

        if !titlePageContent.isEmpty {
            document += "\(titlePageContent)\n"
        }

        if !documentContent.isEmpty {
            document += documentContent
        }

        return document.trimmingCharacters(in: .newlines)
    }

    public static func body(from script: GuionParsedScreenplay) -> String {
        var fountainContent = ""
        var dualDialogueCount = 0

        for element in script.elements {
            // Data check
            if (element.elementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || element.elementText.isEmpty)
                && element.elementType != .pageBreak {
                continue
            }

            var textToWrite = ""

            switch element.elementType {
            case .comment:
                textToWrite = "\n[[\(element.elementText)]]"
            case .boneyard:
                textToWrite = "/*\(element.elementText)*/"
            case .synopsis:
                textToWrite = "=\(element.elementText)"
            case .sceneHeading:
                textToWrite = element.elementText

                // Determine if the scene heading was a forced scene heading
                let testString = "\n\(element.elementText)\n"
                if !matches(string: testString, pattern: FountainRegexes.sceneHeaderPattern) {
                    textToWrite = ".\(textToWrite)"
                }

                // Append a scene number if needed
                if !script.suppressSceneNumbers, let sceneNumber = element.sceneNumber {
                    textToWrite = "\(textToWrite) #\(sceneNumber)#"
                }
            case .pageBreak:
                textToWrite = "===="
            case .sectionHeading(let level):
                let sectionDepthMarkup = String(repeating: "#", count: level)
                // Remove leading space if present to avoid double spaces
                let text = element.elementText.hasPrefix(" ")
                    ? String(element.elementText.dropFirst())
                    : element.elementText
                textToWrite = sectionDepthMarkup + " " + text
            case .transition:
                if !matches(string: element.elementText, pattern: FountainRegexes.transitionPattern) {
                    textToWrite = "> \(element.elementText)"
                } else {
                    textToWrite = element.elementText
                }
            default:
                textToWrite = element.elementText
            }

            if element.isCentered {
                // There should be a space between the end of the line and the < char
                if matches(string: textToWrite, pattern: "[ ]$") {
                    textToWrite = "> \(textToWrite)<"
                } else {
                    textToWrite = "> \(textToWrite) <"
                }
            }

            if element.elementType == .character && element.isDualDialogue {
                dualDialogueCount += 1
                if dualDialogueCount == 2 {
                    textToWrite = "\(textToWrite) ^"
                    dualDialogueCount = 0
                }
            }

            // Character elements need a blank line before them to be recognized by the parser
            // Dialogue, parenthetical, and comments don't need blank lines before them
            if element.elementType == .dialogue || element.elementType == .parenthetical || element.elementType == .comment {
                fountainContent += "\(textToWrite)\n"
            } else {
                fountainContent += "\n\(textToWrite)\n"
            }
        }

        return fountainContent
    }

    public static func titlePage(from script: GuionParsedScreenplay) -> String {
        var titlePageContent = ""

        for dict in script.titlePage {
            for (key, values) in dict {
                // Make the key pretty by capitalizing the first char
                var keyString = key.capitalized

                if values.count == 1 {
                    // Fix for authors vs author when only one author's name is given
                    if key == "authors" {
                        keyString = "Author"
                    }
                    titlePageContent += "\(keyString): \(values[0])\n"
                } else {
                    titlePageContent += "\(keyString):\n"
                    for value in values {
                        titlePageContent += "\t\(value)\n"
                    }
                }
            }
        }

        return titlePageContent
    }

    // MARK: - Regex Helpers

    private static func matches(string: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }

        let nsString = string as NSString
        return regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: nsString.length)) != nil
    }
}
