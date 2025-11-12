//
//  FountainTextFormatter.swift
//  SwiftCompartido
//
//  Converts Fountain inline formatting to SwiftUI AttributedString
//

import SwiftUI

/// Formatter for Fountain inline text formatting
///
/// Supports:
/// - `**bold**` → Bold text
/// - `*italic*` → Italic text
/// - `_underline_` → Underlined text
@MainActor
public struct FountainTextFormatter {

    /// Convert Fountain-formatted text to AttributedString
    /// - Parameters:
    ///   - text: The raw text with Fountain markup
    ///   - baseFont: The base font to use
    /// - Returns: AttributedString with formatting applied
    public static func format(_ text: String, baseFont: Font) -> AttributedString {
        var result = AttributedString(text)

        // Process bold (**text**)
        result = processBold(result, baseFont: baseFont)

        // Process italic (*text*)
        result = processItalic(result, baseFont: baseFont)

        // Process underline (_text_)
        result = processUnderline(result, baseFont: baseFont)

        return result
    }

    /// Process bold formatting (**text**)
    private static func processBold(_ input: AttributedString, baseFont: Font) -> AttributedString {
        var result = input
        let pattern = "\\*\\*([^*]+)\\*\\*"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return result
        }

        let string = String(input.characters)
        let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))

        // Process in reverse to maintain indices
        for match in matches.reversed() {
            guard let range = Range(match.range, in: string),
                  let contentRange = Range(match.range(at: 1), in: string) else {
                continue
            }

            // Get the content without markers
            let content = String(string[contentRange])

            // Convert to AttributedString range
            if let attrRange = Range(range, in: result) {
                // Replace with bold text
                var replacement = AttributedString(content)
                replacement.font = .custom("Courier New", size: 14).weight(.bold) // Will be overridden by parent
                result.replaceSubrange(attrRange, with: replacement)
            }
        }

        return result
    }

    /// Process italic formatting (*text*)
    private static func processItalic(_ input: AttributedString, baseFont: Font) -> AttributedString {
        var result = input
        // Match *text* but not **text**
        let pattern = "(?<!\\*)\\*([^*]+)\\*(?!\\*)"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return result
        }

        let string = String(input.characters)
        let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))

        for match in matches.reversed() {
            guard let range = Range(match.range, in: string),
                  let contentRange = Range(match.range(at: 1), in: string) else {
                continue
            }

            let content = String(string[contentRange])

            if let attrRange = Range(range, in: result) {
                var replacement = AttributedString(content)
                replacement.font = .custom("Courier New", size: 14).italic()
                result.replaceSubrange(attrRange, with: replacement)
            }
        }

        return result
    }

    /// Process underline formatting (_text_)
    private static func processUnderline(_ input: AttributedString, baseFont: Font) -> AttributedString {
        var result = input
        let pattern = "_([^_]+)_"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return result
        }

        let string = String(input.characters)
        let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))

        for match in matches.reversed() {
            guard let range = Range(match.range, in: string),
                  let contentRange = Range(match.range(at: 1), in: string) else {
                continue
            }

            let content = String(string[contentRange])

            if let attrRange = Range(range, in: result) {
                var replacement = AttributedString(content)
                replacement.underlineStyle = .single
                result.replaceSubrange(attrRange, with: replacement)
            }
        }

        return result
    }
}
