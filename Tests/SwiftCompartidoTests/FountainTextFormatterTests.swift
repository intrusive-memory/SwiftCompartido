//
//  FountainTextFormatterTests.swift
//  SwiftCompartido
//
//  Tests for Fountain inline text formatting
//

import Foundation
import Testing
import SwiftUI
@testable import SwiftCompartido

@MainActor
struct FountainTextFormatterTests {

    // MARK: - Bold Formatting Tests

    @Test("Format bold text with **markers**")
    func formatBoldText() {
        let input = "This is **bold** text"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        // Markers should be removed
        #expect(output == "This is bold text")

        // Check that we have an attributed string (formatting was applied)
        #expect(result.runs.count > 1)
    }

    @Test("Format multiple bold sections")
    func formatMultipleBold() {
        let input = "**First** and **second** bold"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "First and second bold")
        #expect(result.runs.count > 1)
    }

    @Test("Handle bold with no closing marker")
    func boldNoClosingMarker() {
        let input = "This is **unclosed bold"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        // Should remain unchanged if not properly closed
        #expect(output == input)
    }

    @Test("Handle empty bold markers")
    func emptyBoldMarkers() {
        let input = "This has **** empty markers"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        // Should remain unchanged (no content between markers)
        #expect(output == input)
    }

    // MARK: - Italic Formatting Tests

    @Test("Format italic text with *markers*")
    func formatItalicText() {
        let input = "This is *italic* text"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "This is italic text")
        #expect(result.runs.count > 1)
    }

    @Test("Format multiple italic sections")
    func formatMultipleItalic() {
        let input = "*First* and *second* italic"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "First and second italic")
        #expect(result.runs.count > 1)
    }

    @Test("Distinguish italic from bold")
    func distinguishItalicFromBold() {
        let input = "This is *italic* not **bold**"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "This is italic not bold")
        #expect(result.runs.count > 1)
    }

    // MARK: - Underline Formatting Tests

    @Test("Format underlined text with _markers_")
    func formatUnderlineText() {
        let input = "This is _underlined_ text"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "This is underlined text")
        #expect(result.runs.count > 1)
    }

    @Test("Format multiple underlined sections")
    func formatMultipleUnderline() {
        let input = "_First_ and _second_ underlined"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "First and second underlined")
        #expect(result.runs.count > 1)
    }

    // MARK: - Combined Formatting Tests

    @Test("Format text with multiple types of formatting")
    func formatMultipleTypes() {
        let input = "This has **bold**, *italic*, and _underlined_ text"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "This has bold, italic, and underlined text")
        #expect(result.runs.count > 1)
    }

    @Test("Format complex screenplay action line")
    func formatComplexActionLine() {
        let input = "MIMI digs through **kitchen cabinets**, tossing _glasses_ and plates to the floor"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "MIMI digs through kitchen cabinets, tossing glasses and plates to the floor")
        #expect(result.runs.count > 1)
    }

    @Test("Format dialogue with emphasis")
    func formatDialogueWithEmphasis() {
        let input = "'Scuse me. Aren't you **MITCH** Sawyer?"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "'Scuse me. Aren't you MITCH Sawyer?")
        #expect(result.runs.count > 1)
    }

    // MARK: - Edge Cases

    @Test("Handle text with no formatting")
    func noFormatting() {
        let input = "Plain text with no formatting"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == input)
        #expect(result.runs.count == 1) // Single run, no formatting
    }

    @Test("Handle empty string")
    func emptyString() {
        let input = ""
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "")
        // Empty strings have 0 runs
        #expect(result.runs.count == 0)
    }

    @Test("Handle single character formatting")
    func singleCharacterFormatting() {
        let input = "The letter **A** is bold"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "The letter A is bold")
        #expect(result.runs.count > 1)
    }

    @Test("Handle adjacent formatting markers")
    func adjacentFormatting() {
        let input = "**bold** *italic* _underline_"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "bold italic underline")
        #expect(result.runs.count > 1)
    }

    @Test("Handle formatting at start of string")
    func formattingAtStart() {
        let input = "**Bold** at start"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "Bold at start")
        #expect(result.runs.count > 1)
    }

    @Test("Handle formatting at end of string")
    func formattingAtEnd() {
        let input = "Ends with **bold**"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "Ends with bold")
        #expect(result.runs.count > 1)
    }

    @Test("Handle entire string formatted")
    func entireStringFormatted() {
        let input = "**Everything is bold**"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "Everything is bold")
        #expect(result.runs.count >= 1)
    }

    // MARK: - Special Characters

    @Test("Handle special characters within formatting")
    func specialCharactersInFormatting() {
        let input = "**Bold with !@#$%** symbols"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "Bold with !@#$% symbols")
        #expect(result.runs.count > 1)
    }

    @Test("Handle newlines within formatting")
    func newlinesInFormatting() {
        let input = "**Bold\nwith\nnewlines**"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "Bold\nwith\nnewlines")
        #expect(result.runs.count >= 1)
    }

    @Test("Handle unicode characters within formatting")
    func unicodeInFormatting() {
        let input = "**Café** and _naïve_ with émphasis"
        let baseFont = Font.custom("Courier New", size: 14)

        let result = FountainTextFormatter.format(input, baseFont: baseFont)
        let output = String(result.characters)

        #expect(output == "Café and naïve with émphasis")
        #expect(result.runs.count > 1)
    }
}
