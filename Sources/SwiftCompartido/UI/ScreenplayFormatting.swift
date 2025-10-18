//
//  ScreenplayFormatting.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//
//  Dynamic screenplay formatting calculations based on standard page dimensions
//

import SwiftUI

// MARK: - Screenplay Page Constants

/// Standard screenplay page dimensions
public struct ScreenplayPageFormat {
    /// Standard character width per line (industry standard)
    public static let charactersPerLine: CGFloat = 65

    /// Standard lines per page (industry standard)
    public static let linesPerPage: Int = 54

    /// Courier font character width-to-height ratio
    /// For monospace Courier fonts, character width ≈ 0.6 × font size
    public static let courierCharacterAspectRatio: CGFloat = 0.6

    /// Line spacing multiplier for screen readability (1.5x for comfortable reading)
    public static let lineSpacingMultiplier: CGFloat = 1.5

    /// Percentage of window width available for content after margins/padding
    /// Accounts for: ScrollView padding (32pt), Scene indent (24pt), and disclosure padding (24pt)
    public static let contentWidthPercentage: CGFloat = 0.88

    /// Calculate font size to fit exactly 65 characters across a given width
    /// - Parameter availableWidth: The available window width in points
    /// - Returns: The font size that will fit exactly 65 characters in the content area
    public static func calculateFontSize(forWidth availableWidth: CGFloat) -> CGFloat {
        // Account for margins and padding to get actual content width
        let contentWidth = availableWidth * contentWidthPercentage

        // For 65 characters to fit in contentWidth:
        // character_width = contentWidth / 65
        // font_size = character_width / aspect_ratio
        let characterWidth = contentWidth / charactersPerLine
        let fontSize = characterWidth / courierCharacterAspectRatio

        // Clamp to reasonable bounds (8pt to 24pt)
        return max(8, min(24, fontSize))
    }

    /// Calculate line height based on font size and line spacing
    /// - Parameter fontSize: The font size
    /// - Returns: The line height including spacing
    public static func lineHeight(forFontSize fontSize: CGFloat) -> CGFloat {
        return fontSize * lineSpacingMultiplier
    }

    /// Calculate page height based on font size (54 lines per page)
    /// - Parameter fontSize: The font size
    /// - Returns: The page height in points
    public static func pageHeight(forFontSize fontSize: CGFloat) -> CGFloat {
        return lineHeight(forFontSize: fontSize) * CGFloat(linesPerPage)
    }

    /// Extract chapter number from chapter title
    /// Examples: "CHAPTER 1" -> 1, "Chapter 2: The Beginning" -> 2, "ACT 3" -> 3
    /// - Parameter title: The chapter title string
    /// - Returns: The chapter number if found, nil otherwise
    public static func extractChapterNumber(from title: String) -> Int? {
        // Try to find a number in the title
        let patterns = [
            "CHAPTER\\s+(\\d+)",     // "CHAPTER 1"
            "Chapter\\s+(\\d+)",     // "Chapter 1"
            "ACT\\s+(\\d+)",         // "ACT 1"
            "Act\\s+(\\d+)",         // "Act 1"
            "^(\\d+)\\.",            // "1." or "2."
            "^(\\d+)\\s"             // "1 " or "2 "
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)),
               match.numberOfRanges > 1 {
                let numberRange = match.range(at: 1)
                if let range = Range(numberRange, in: title),
                   let number = Int(title[range]) {
                    return number
                }
            }
        }

        return nil
    }

    /// Calculate starting page number for a chapter
    /// - Parameter chapterNumber: The chapter number (if available)
    /// - Returns: The starting page number (chapter_number * 100, or 1 if no chapter number)
    public static func startingPageNumber(forChapter chapterNumber: Int?) -> Int {
        if let number = chapterNumber {
            return number * 100
        }
        return 1
    }
}

// MARK: - Environment Key

/// Environment key for dynamic screenplay font size
struct ScreenplayFontSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 12
}

extension EnvironmentValues {
    /// Dynamic font size for screenplay text, calculated to fit 65 characters per line
    public var screenplayFontSize: CGFloat {
        get { self[ScreenplayFontSizeKey.self] }
        set { self[ScreenplayFontSizeKey.self] = newValue }
    }
}
