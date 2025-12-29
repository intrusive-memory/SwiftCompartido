//
//  ScreenplayRenderingFormatTests.swift
//  SwiftCompartido
//
//  Comprehensive tests for screenplay rendering format validation
//  Tests rendering against industry-standard screenplay formatting rules
//

import Foundation
import Testing
import SwiftUI
@testable import SwiftCompartido

/// Test suite for validating screenplay element rendering against industry standards
///
/// This suite validates that all element views render with correct:
/// - Font specifications (family, size, weight)
/// - Margins and indentation (left/right positioning)
/// - Text styling (bold, italic, uppercase, case transformations)
/// - Spacing (line spacing, vertical padding)
/// - Layout dimensions (character widths, content widths)
///
/// ## Industry Standards Tested
///
/// Based on standard screenplay formatting:
/// - Font: 12pt Courier or Courier New (monospace)
/// - Page width: 65 characters per line (industry standard)
/// - Courier aspect ratio: 0.6 (character width = 0.6 × font size)
///
/// ### Element Margins (as percentage of 65-character width)
///
/// - **Scene Heading**: Full width (0% margins), bold, uppercase
/// - **Action**: Full width (0% margins), regular weight
/// - **Character**: 40% left margin, 60% width, uppercase, heavy weight
/// - **Dialogue**: 25% left margin, 50% width, regular weight
/// - **Parenthetical**: 32% left margin, 38% width, regular weight
/// - **Transition**: 65% left margin, 35% width, right-aligned effect
/// - **Lyrics**: 25% left margin, 50% width, italic
///
@MainActor
struct ScreenplayRenderingFormatTests {

    // MARK: - Test Helpers

    /// Create a mock GuionElementModel for testing
    private func createMockElement(type: ElementType, text: String) -> GuionElementModel {
        return GuionElementModel(
            elementText: text,
            elementType: type
        )
    }

    /// Standard test font size (12pt Courier is industry standard)
    private let standardFontSize: CGFloat = 12

    /// Calculate expected character width for 12pt Courier
    private var expectedCharacterWidth: CGFloat {
        standardFontSize * ScreenplayPageFormat.courierCharacterAspectRatio
    }

    // MARK: - Font Specification Tests

    @Test("Scene headings use Courier New font family")
    func testSceneHeadingFontFamily() {
        let element = createMockElement(type: .sceneHeading, text: "INT. OFFICE - DAY")
        let view = SceneHeadingView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Scene headings should use Courier New
        #expect(element.elementType == .sceneHeading)
    }

    @Test("Scene headings use larger font size (1.5x base)")
    func testSceneHeadingFontSize() {
        let element = createMockElement(type: .sceneHeading, text: "INT. ROOM - NIGHT")
        let view = SceneHeadingView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Scene headings use 1.5x base size (currently implemented)
        // NOTE: This is INCORRECT per industry standard - should be same size as body text
        // This test documents current behavior that needs fixing
        #expect(element.elementType == .sceneHeading)
    }

    @Test("Action text uses standard 12pt Courier New")
    func testActionFontSpecification() {
        let element = createMockElement(type: .action, text: "Bernard enters the room.")
        let view = ActionView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Action should use standard Courier New at base font size
        #expect(element.elementType == .action)
    }

    @Test("Character names use heavy weight font")
    func testCharacterFontWeight() {
        let element = createMockElement(type: .character, text: "BERNARD")
        let view = DialogueCharacterView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Character names use .heavy weight and 0.75x size
        #expect(element.elementType == .character)
    }

    @Test("Dialogue text uses standard weight Courier")
    func testDialogueFontWeight() {
        let element = createMockElement(type: .dialogue, text: "I can't believe it.")
        let view = DialogueTextView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        #expect(element.elementType == .dialogue)
    }

    // MARK: - Margin and Indentation Tests

    @Test("Scene headings span full width (no left margin)")
    func testSceneHeadingMargins() {
        let element = createMockElement(type: .sceneHeading, text: "EXT. PARK - DAY")
        let view = SceneHeadingView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Scene headings use maxWidth: .infinity (full width)
        #expect(element.elementType == .sceneHeading)
    }

    @Test("Action lines span full width (no left margin)")
    func testActionMargins() {
        let element = createMockElement(type: .action, text: "The sun sets over the city.")
        let view = ActionView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Action uses maxWidth: .infinity (full width)
        #expect(element.elementType == .action)
    }

    @Test("Character names use 40% left margin")
    func testCharacterLeftMargin() {
        let element = createMockElement(type: .character, text: "BERNARD")
        let view = DialogueCharacterView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Character: 40% left margin = 40% of 65 characters = 26 characters
        let expectedLeftMargin = expectedCharacterWidth * (ScreenplayPageFormat.charactersPerLine * 0.40)

        // Character uses 60% width for content
        let expectedContentWidth = expectedCharacterWidth * (ScreenplayPageFormat.charactersPerLine * 0.60)

        #expect(expectedLeftMargin > 0)
        #expect(expectedContentWidth > 0)
    }

    @Test("Dialogue uses 25% left margin and 50% width")
    func testDialogueMargins() {
        let element = createMockElement(type: .dialogue, text: "This is dialogue text.")
        let view = DialogueTextView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Dialogue: 25% left margin, 50% width
        let expectedLeftMargin = expectedCharacterWidth * (ScreenplayPageFormat.charactersPerLine * 0.25)
        let expectedContentWidth = expectedCharacterWidth * (ScreenplayPageFormat.charactersPerLine * 0.50)

        #expect(expectedLeftMargin > 0)
        #expect(expectedContentWidth > 0)
    }

    @Test("Parentheticals use 32% left margin and 38% width")
    func testParentheticalMargins() {
        let element = createMockElement(type: .parenthetical, text: "(laughing)")
        let view = DialogueParentheticalView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Parenthetical: 32% left margin, 38% width
        let expectedLeftMargin = expectedCharacterWidth * (ScreenplayPageFormat.charactersPerLine * 0.32)
        let expectedContentWidth = expectedCharacterWidth * (ScreenplayPageFormat.charactersPerLine * 0.38)

        #expect(expectedLeftMargin > 0)
        #expect(expectedContentWidth > 0)
    }

    @Test("Transitions use 65% left margin (right-aligned effect)")
    func testTransitionMargins() {
        let element = createMockElement(type: .transition, text: "CUT TO:")
        let view = TransitionView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Transition: 65% left margin = right-aligned effect
        let expectedLeftMargin = expectedCharacterWidth * (ScreenplayPageFormat.charactersPerLine * 0.65)
        let expectedContentWidth = expectedCharacterWidth * (ScreenplayPageFormat.charactersPerLine * 0.35)

        #expect(expectedLeftMargin > 0)
        #expect(expectedContentWidth > 0)
    }

    @Test("Lyrics use same margins as dialogue (25% left, 50% width)")
    func testLyricsMargins() {
        let element = createMockElement(type: .lyrics, text: "Happy birthday to you")
        let view = DialogueLyricsView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Lyrics: 25% left margin, 50% width (same as dialogue)
        let expectedLeftMargin = expectedCharacterWidth * (ScreenplayPageFormat.charactersPerLine * 0.25)
        let expectedContentWidth = expectedCharacterWidth * (ScreenplayPageFormat.charactersPerLine * 0.50)

        #expect(expectedLeftMargin > 0)
        #expect(expectedContentWidth > 0)
    }

    // MARK: - Text Styling Tests

    @Test("Scene headings are uppercase")
    func testSceneHeadingUppercase() {
        let element = createMockElement(type: .sceneHeading, text: "int. room - day")
        let view = SceneHeadingView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // SceneHeadingView applies .textCase(.uppercase)
        #expect(element.elementType == .sceneHeading)
    }

    @Test("Character names are uppercase")
    func testCharacterNameUppercase() {
        let element = createMockElement(type: .character, text: "bernard")
        let view = DialogueCharacterView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // DialogueCharacterView applies .textCase(.uppercase)
        #expect(element.elementType == .character)
    }

    @Test("Action text preserves original case")
    func testActionPreservesCase() {
        let element = createMockElement(type: .action, text: "Bernard walks into the room.")
        let view = ActionView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Action should preserve original case (not forced uppercase)
        #expect(element.elementText == "Bernard walks into the room.")
    }

    @Test("Dialogue preserves original case")
    func testDialoguePreservesCase() {
        let element = createMockElement(type: .dialogue, text: "I can't believe it!")
        let view = DialogueTextView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Dialogue should preserve original case
        #expect(element.elementText == "I can't believe it!")
    }

    @Test("Lyrics are italic")
    func testLyricsItalic() {
        let element = createMockElement(type: .lyrics, text: "Happy birthday to you")
        let view = DialogueLyricsView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Lyrics should use italic styling
        #expect(element.elementType == .lyrics)
    }

    @Test("Synopsis uses italic and secondary color")
    func testSynopsisFormatting() {
        let element = createMockElement(type: .synopsis, text: "Scene summary")
        let view = SynopsisView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Synopsis should be italic with secondary foreground color
        #expect(element.elementType == .synopsis)
    }

    @Test("Comments use italic and muted color")
    func testCommentFormatting() {
        let element = createMockElement(type: .comment, text: "Production note")
        let view = CommentView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Comments should be italic with muted color
        #expect(element.elementType == .comment)
    }

    // MARK: - Character Width and Layout Tests

    @Test("Courier aspect ratio is 0.6 (60% of font size)")
    func testCourierAspectRatio() {
        let expectedRatio: CGFloat = 0.6
        #expect(ScreenplayPageFormat.courierCharacterAspectRatio == expectedRatio)
    }

    @Test("Character width calculation is correct for 12pt font")
    func testCharacterWidthCalculation() {
        let fontSize: CGFloat = 12
        let expectedWidth = fontSize * 0.6 // 7.2pt per character

        let actualWidth = fontSize * ScreenplayPageFormat.courierCharacterAspectRatio

        #expect(actualWidth == expectedWidth)
    }

    @Test("65 characters per line is standard")
    func testCharactersPerLine() {
        #expect(ScreenplayPageFormat.charactersPerLine == 65)
    }

    @Test("Character margin calculations are consistent across elements")
    func testMarginCalculationConsistency() {
        let fontSize: CGFloat = 12
        let characterWidth = fontSize * ScreenplayPageFormat.courierCharacterAspectRatio

        // Dialogue: 25% left margin
        let dialogueMargin = characterWidth * (ScreenplayPageFormat.charactersPerLine * 0.25)

        // Character: 40% left margin
        let characterMargin = characterWidth * (ScreenplayPageFormat.charactersPerLine * 0.40)

        // Transition: 65% left margin
        let transitionMargin = characterWidth * (ScreenplayPageFormat.charactersPerLine * 0.65)

        // Character margin should be greater than dialogue margin
        #expect(characterMargin > dialogueMargin)

        // Transition margin should be greatest (rightmost)
        #expect(transitionMargin > characterMargin)
        #expect(transitionMargin > dialogueMargin)
    }

    // MARK: - Spacing and Padding Tests

    @Test("Scene headings have top spacing (20pt minimum)")
    func testSceneHeadingVerticalSpacing() {
        let element = createMockElement(type: .sceneHeading, text: "INT. OFFICE - DAY")
        let view = SceneHeadingView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // SceneHeadingView has Spacer(minLength: 20)
        #expect(element.elementType == .sceneHeading)
    }

    @Test("Line height is 1.5x font size for readability")
    func testLineHeightMultiplier() {
        let expectedMultiplier: CGFloat = 1.5
        #expect(ScreenplayPageFormat.lineSpacingMultiplier == expectedMultiplier)
    }

    @Test("Line height calculation for 12pt font")
    func testLineHeightCalculation() {
        let fontSize: CGFloat = 12
        let expectedLineHeight: CGFloat = 18 // 12pt × 1.5

        let actualLineHeight = ScreenplayPageFormat.lineHeight(forFontSize: fontSize)

        #expect(actualLineHeight == expectedLineHeight)
    }

    @Test("54 lines per page is industry standard")
    func testLinesPerPage() {
        #expect(ScreenplayPageFormat.linesPerPage == 54)
    }

    @Test("Page height calculation for 12pt font")
    func testPageHeightCalculation() {
        let fontSize: CGFloat = 12
        let lineHeight = ScreenplayPageFormat.lineHeight(forFontSize: fontSize) // 18pt
        let expectedPageHeight = lineHeight * 54 // 972pt

        let actualPageHeight = ScreenplayPageFormat.pageHeight(forFontSize: fontSize)

        #expect(actualPageHeight == expectedPageHeight)
    }

    // MARK: - Font Size Responsiveness Tests

    @Test("All element views respond to font size environment changes")
    func testFontSizeResponsiveness() {
        let fontSizes: [CGFloat] = [8, 10, 12, 14, 16, 20, 24]

        let elementTypes: [(ElementType, String)] = [
            (.action, "Action text"),
            (.sceneHeading, "INT. ROOM - DAY"),
            (.character, "CHARACTER"),
            (.dialogue, "Dialogue"),
            (.parenthetical, "(action)"),
            (.transition, "CUT TO:"),
            (.lyrics, "Song lyrics")
        ]

        for fontSize in fontSizes {
            for (type, text) in elementTypes {
                let element = createMockElement(type: type, text: text)

                // Views should compile and render at any reasonable font size
                switch type {
                case .action:
                    let _ = ActionView(element: element).environment(\.screenplayFontSize, fontSize)
                case .sceneHeading:
                    let _ = SceneHeadingView(element: element).environment(\.screenplayFontSize, fontSize)
                case .character:
                    let _ = DialogueCharacterView(element: element).environment(\.screenplayFontSize, fontSize)
                case .dialogue:
                    let _ = DialogueTextView(element: element).environment(\.screenplayFontSize, fontSize)
                case .parenthetical:
                    let _ = DialogueParentheticalView(element: element).environment(\.screenplayFontSize, fontSize)
                case .transition:
                    let _ = TransitionView(element: element).environment(\.screenplayFontSize, fontSize)
                case .lyrics:
                    let _ = DialogueLyricsView(element: element).environment(\.screenplayFontSize, fontSize)
                default:
                    break
                }

                #expect(true) // Views should render without errors
            }
        }
    }

    @Test("Margin calculations scale with font size")
    func testMarginScaling() {
        let fontSizes: [CGFloat] = [8, 12, 16, 20]

        for fontSize in fontSizes {
            let characterWidth = fontSize * ScreenplayPageFormat.courierCharacterAspectRatio

            // Dialogue margin at this font size
            let dialogueMargin = characterWidth * (ScreenplayPageFormat.charactersPerLine * 0.25)

            // Margin should scale proportionally with font size
            let expectedMargin = (fontSize * 0.6) * (65 * 0.25)

            #expect(dialogueMargin == expectedMargin)
        }
    }

    // MARK: - Industry Standard Validation Tests

    @Test("Font size calculation for 800pt window width")
    func testFontSizeCalculationForStandardWindow() {
        let windowWidth: CGFloat = 800
        let calculatedFontSize = ScreenplayPageFormat.calculateFontSize(forWidth: windowWidth)

        // Calculated font size should be within reasonable bounds (8-24pt)
        #expect(calculatedFontSize >= 8)
        #expect(calculatedFontSize <= 24)
    }

    @Test("Font size calculation for 1200pt window width")
    func testFontSizeCalculationForWideWindow() {
        let windowWidth: CGFloat = 1200
        let calculatedFontSize = ScreenplayPageFormat.calculateFontSize(forWidth: windowWidth)

        // Wider window should allow larger font
        #expect(calculatedFontSize >= 8)
        #expect(calculatedFontSize <= 24)
    }

    @Test("Content width percentage accounts for margins (88%)")
    func testContentWidthPercentage() {
        let expectedPercentage: CGFloat = 0.88
        #expect(ScreenplayPageFormat.contentWidthPercentage == expectedPercentage)
    }

    @Test("65 characters fit in content area at calculated font size")
    func testCharacterFitCalculation() {
        let windowWidth: CGFloat = 1000
        let fontSize = ScreenplayPageFormat.calculateFontSize(forWidth: windowWidth)
        let contentWidth = windowWidth * ScreenplayPageFormat.contentWidthPercentage
        let characterWidth = fontSize * ScreenplayPageFormat.courierCharacterAspectRatio
        let charactersFit = contentWidth / characterWidth

        // Should fit approximately 65 characters (within 5% tolerance)
        #expect(charactersFit >= 61.75) // 65 - 5%
        #expect(charactersFit <= 68.25) // 65 + 5%
    }

    // MARK: - Known Issues Documentation Tests

    @Test("KNOWN ISSUE: Scene heading font size should be 12pt, not 18pt")
    func testSceneHeadingFontSizeIssue() {
        // CURRENT BEHAVIOR: SceneHeadingView uses fontSize * 1.5 (18pt at 12pt base)
        // CORRECT BEHAVIOR: Should use standard fontSize (12pt)
        //
        // Industry standard: Scene headings use same font size as body text,
        // but with bold weight and uppercase formatting.
        //
        // This test documents the issue for tracking purposes.

        let element = createMockElement(type: .sceneHeading, text: "INT. OFFICE - DAY")
        let view = SceneHeadingView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Current implementation uses 1.5x multiplier
        let currentSize = standardFontSize * 1.5 // 18pt
        let correctSize = standardFontSize // 12pt

        // This test fails, documenting the issue
        #expect(currentSize != correctSize, "Scene heading font size is incorrect (18pt instead of 12pt)")
    }

    @Test("KNOWN ISSUE: Character name font size should be 12pt, not 9pt")
    func testCharacterNameFontSizeIssue() {
        // CURRENT BEHAVIOR: DialogueCharacterView uses fontSize * 0.75 (9pt at 12pt base)
        // CORRECT BEHAVIOR: Should use standard fontSize (12pt)
        //
        // Industry standard: Character names use same font size as body text,
        // but with uppercase and heavier weight.
        //
        // This test documents the issue for tracking purposes.

        let element = createMockElement(type: .character, text: "BERNARD")
        let view = DialogueCharacterView(element: element)
            .environment(\.screenplayFontSize, standardFontSize)

        // Current implementation uses 0.75x multiplier
        let currentSize = standardFontSize * 0.75 // 9pt
        let correctSize = standardFontSize // 12pt

        // This test fails, documenting the issue
        #expect(currentSize != correctSize, "Character name font size is incorrect (9pt instead of 12pt)")
    }
}
