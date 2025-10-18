//
//  FountainParserTests.swift
//  SwiftGuionTests
//
//  Copyright (c) 2025
//

import XCTest
@testable import SwiftCompartido

final class FountainParserTests: XCTestCase {

    // MARK: - Lyrics Tests

    func testLyricsWithTilde() {
        let script = """
        ~Oh, what a beautiful morning
        ~Oh, what a beautiful day

        ~I've got a wonderful feeling
        """

        let parser = FountainParser(string: script)

        XCTAssertGreaterThanOrEqual(parser.elements.count, 4, "Should parse lyrics elements")
        XCTAssertEqual(parser.elements[0].elementType, .lyrics)
        XCTAssertEqual(parser.elements[0].elementText, "~Oh, what a beautiful morning")
        XCTAssertEqual(parser.elements[1].elementType, .lyrics)
    }

    func testLyricsWithSpaceBetween() {
        let script = """
        ~First line

        ~Second line after blank line
        """

        let parser = FountainParser(string: script)

        XCTAssertGreaterThanOrEqual(parser.elements.count, 2, "Should handle lyrics with blank lines")
        XCTAssertEqual(parser.elements[0].elementType, .lyrics)
        // When there's a newline before, it should add a space separator
        let lyricsCount = parser.elements.filter { $0.elementType == .lyrics }.count
        XCTAssertGreaterThan(lyricsCount, 1, "Should have multiple lyrics elements")
    }

    // MARK: - Forced Action Tests

    func testForcedActionWithExclamation() {
        let script = """
        !This is a forced action line
        !Another forced action
        """

        let parser = FountainParser(string: script)

        XCTAssertGreaterThanOrEqual(parser.elements.count, 2, "Should parse forced action elements")
        XCTAssertEqual(parser.elements[0].elementType, .action)
        XCTAssertEqual(parser.elements[0].elementText, "!This is a forced action line")
        XCTAssertEqual(parser.elements[1].elementType, .action)
    }

    // MARK: - Forced Character Tests

    func testForcedCharacterWithAt() {
        let script = """
        @McCLANE
        Yippee-ki-yay!
        """

        let parser = FountainParser(string: script)

        XCTAssertGreaterThanOrEqual(parser.elements.count, 2, "Should parse forced character")
        XCTAssertEqual(parser.elements[0].elementType, .character)
        XCTAssertEqual(parser.elements[0].elementText, "@McCLANE")
        XCTAssertEqual(parser.elements[1].elementType, .dialogue)
    }

    // MARK: - Dialogue Continuation Tests

    func testDialogueContinuationWithDoubleSpaces() {
        let script = """
        JOHN
        This is the first line.

        This continues after double spaces.
        """

        let parser = FountainParser(string: script)

        let dialogueElements = parser.elements.filter { $0.elementType == .dialogue }
        XCTAssertGreaterThan(dialogueElements.count, 0, "Should have dialogue elements")
    }

    func testEmptyDialogueLineWithDoubleSpaces() {
        let script = """
        JOHN
        First line

        Second line after double space
        """

        let parser = FountainParser(string: script)

        XCTAssertGreaterThan(parser.elements.count, 0, "Should parse dialogue with double spaces")
        let characterIndex = parser.elements.firstIndex { $0.elementType == .character }
        XCTAssertNotNil(characterIndex, "Should have character element")
    }

    // MARK: - Multiple Spaces (Action) Tests

    func testMultipleSpacesAsAction() {
        let script = """
        Some action here



        More action after multiple spaces
        """

        let parser = FountainParser(string: script)

        let actionElements = parser.elements.filter { $0.elementType == .action }
        XCTAssertGreaterThan(actionElements.count, 0, "Should have action elements")
    }

    // MARK: - Complex Fountain Features

    func testPageBreaks() {
        let script = """
        Some action before page break

        ===

        Action after page break
        """

        let parser = FountainParser(string: script)

        let pageBreaks = parser.elements.filter { $0.elementType == .pageBreak }
        XCTAssertEqual(pageBreaks.count, 1, "Should have one page break")
    }

    func testSynopsis() {
        let script = """
        INT. COFFEE SHOP - DAY

        = John meets Jane for the first time

        JOHN enters.
        """

        let parser = FountainParser(string: script)

        let synopses = parser.elements.filter { $0.elementType == .synopsis }
        XCTAssertEqual(synopses.count, 1, "Should have one synopsis")
        XCTAssertTrue(synopses[0].elementText.contains("John meets Jane"), "Synopsis text should contain expected content")
    }

    func testComment() {
        let script = """
        INT. OFFICE - DAY

        [[ This is a note about the scene ]]

        JOHN enters.
        """

        let parser = FountainParser(string: script)

        let comments = parser.elements.filter { $0.elementType == .comment }
        XCTAssertEqual(comments.count, 1, "Should have one comment")
        XCTAssertEqual(comments[0].elementText, "This is a note about the scene")
    }

    func testBoneyardSingleLine() {
        let script = """
        Some action

        /* This is in the boneyard */

        More action
        """

        let parser = FountainParser(string: script)

        let boneyards = parser.elements.filter { $0.elementType == .boneyard }
        XCTAssertEqual(boneyards.count, 1, "Should have one boneyard")
    }

    func testBoneyardMultiLine() {
        let script = """
        Some action

        /*
        This is a multi-line
        boneyard comment
        */

        More action
        """

        let parser = FountainParser(string: script)

        let boneyards = parser.elements.filter { $0.elementType == .boneyard }
        XCTAssertEqual(boneyards.count, 1, "Should have one boneyard")
    }

    func testSectionHeading() {
        let script = """
        # Act One

        ## Scene Group

        ### Sub-section

        INT. LOCATION - DAY
        """

        let parser = FountainParser(string: script)

        let sections = parser.elements.filter { $0.elementType.isSectionHeading }
        XCTAssertEqual(sections.count, 3, "Should have three section headings")
        XCTAssertEqual(sections[0].sectionDepth, 1)  // One #
        XCTAssertEqual(sections[1].sectionDepth, 2)  // Two #
        XCTAssertEqual(sections[2].sectionDepth, 3)  // Three #
    }

    func testForcedSceneHeading() {
        let script = """
        .FLASHBACK - 1984

        Some action here.
        """

        let parser = FountainParser(string: script)

        let scenes = parser.elements.filter { $0.elementType == .sceneHeading }
        XCTAssertEqual(scenes.count, 1, "Should have one forced scene heading")
        XCTAssertEqual(scenes[0].elementText, "FLASHBACK - 1984")
    }

    func testSceneHeadingWithNumber() {
        let script = """
        INT. OFFICE - DAY #1#

        Some action.
        """

        let parser = FountainParser(string: script)

        let scenes = parser.elements.filter { $0.elementType == .sceneHeading }
        XCTAssertEqual(scenes.count, 1, "Should have scene heading")
        XCTAssertEqual(scenes[0].sceneNumber, "1", "Should extract scene number")
        XCTAssertFalse(scenes[0].elementText.contains("#"), "Scene text should not contain # markers")
    }

    func testForcedSceneHeadingWithNumber() {
        let script = """
        .FLASHBACK #42A#

        Action here.
        """

        let parser = FountainParser(string: script)

        let scenes = parser.elements.filter { $0.elementType == .sceneHeading }
        XCTAssertEqual(scenes.count, 1, "Should have forced scene heading")
        XCTAssertEqual(scenes[0].sceneNumber, "42A", "Should extract scene number")
    }

    func testTransitions() {
        let script = """
        Action line.

        CUT TO:

        More action.

        FADE OUT.

        THE END
        """

        let parser = FountainParser(string: script)

        let transitions = parser.elements.filter { $0.elementType == .transition }
        XCTAssertGreaterThanOrEqual(transitions.count, 2, "Should have at least two transitions")
    }

    func testForcedTransition() {
        let script = """
        Action here.

        > SMASH CUT TO:

        More action.
        """

        let parser = FountainParser(string: script)

        let transitions = parser.elements.filter { $0.elementType == .transition }
        XCTAssertEqual(transitions.count, 1, "Should have forced transition")
        XCTAssertTrue(transitions[0].elementText.contains("SMASH CUT TO:"), "Transition text should contain expected content")
    }

    func testCenteredText() {
        let script = """
        > THE END <

        """

        let parser = FountainParser(string: script)

        let centered = parser.elements.filter { $0.isCentered }
        XCTAssertEqual(centered.count, 1, "Should have centered text")
        XCTAssertEqual(centered[0].elementText, "THE END")
        XCTAssertEqual(centered[0].elementType, .action)
    }

    func testDualDialogue() {
        let script = """
        JOHN
        Hello!

        JANE ^
        Hi there!
        """

        let parser = FountainParser(string: script)

        let characters = parser.elements.filter { $0.elementType == .character }
        XCTAssertGreaterThanOrEqual(characters.count, 2, "Should have two characters")

        // Both characters should be marked as dual dialogue
        let dualCharacters = characters.filter { $0.isDualDialogue }
        XCTAssertGreaterThanOrEqual(dualCharacters.count, 1, "Should have dual dialogue markers")
    }

    // MARK: - Title Page Tests

    func testTitlePageDirective() {
        let script = """
        Title:
            My Screenplay
        Author:
            John Doe

        INT. LOCATION - DAY

        Action.
        """

        let parser = FountainParser(string: script)

        XCTAssertGreaterThan(parser.titlePage.count, 0, "Should have title page entries")

        let titleEntry = parser.titlePage.first { $0.keys.contains("title") }
        XCTAssertNotNil(titleEntry, "Should have title entry")
        XCTAssertEqual(titleEntry?["title"]?.first, "My Screenplay")
    }

    func testTitlePageInline() {
        let script = """
        Title: My Screenplay
        Draft: First Draft

        INT. LOCATION - DAY
        """

        let parser = FountainParser(string: script)

        XCTAssertGreaterThanOrEqual(parser.titlePage.count, 2, "Should have title page entries")
    }

    func testTitlePageAuthorConversion() {
        let script = """
        Author: Jane Smith

        INT. LOCATION - DAY
        """

        let parser = FountainParser(string: script)

        // "Author" should be converted to "authors"
        let authorsEntry = parser.titlePage.first { $0.keys.contains("authors") }
        XCTAssertNotNil(authorsEntry, "Should convert 'author' to 'authors'")
    }

    // MARK: - Edge Cases

    func testOverBlackSceneHeading() {
        let script = """

        OVER BLACK

        We hear voices.
        """

        let parser = FountainParser(string: script)

        let scenes = parser.elements.filter { $0.elementType == .sceneHeading }
        XCTAssertEqual(scenes.count, 1, "Should recognize OVER BLACK as scene heading")
    }

    func testCharacterWithContd() {
        let script = """
        JOHN
        I'm talking.

        JOHN (cont'd)
        I'm still talking.
        """

        let parser = FountainParser(string: script)

        let characters = parser.elements.filter { $0.elementType == .character }
        XCTAssertGreaterThan(characters.count, 0, "Should parse character")
    }

    func testSceneHeadingNotSurroundedByBlanks() {
        let script = """
        This looks like a scene heading
        INT. OFFICE - DAY
        but it's not surrounded by blank lines
        """

        let parser = FountainParser(string: script)

        // This should be merged into action, not treated as a scene heading
        let scenes = parser.elements.filter { $0.elementType == .sceneHeading }
        XCTAssertEqual(scenes.count, 0, "Should not treat as scene heading without blank lines")
    }

    func testParentheticalInDialogue() {
        let script = """
        JOHN
        Hello there.
        (smiling)
        How are you?
        """

        let parser = FountainParser(string: script)

        let parentheticals = parser.elements.filter { $0.elementType == .parenthetical }
        XCTAssertEqual(parentheticals.count, 1, "Should have parenthetical")
    }
}
