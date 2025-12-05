//
//  FountainParserTests.swift
//  SwiftGuionTests
//
//  Copyright (c) 2025
//

import Testing
@testable import SwiftCompartido

struct FountainParserTests {

    // MARK: - Lyrics Tests

    @Test func testLyricsWithTilde() {
        let script = """
        ~Oh, what a beautiful morning
        ~Oh, what a beautiful day

        ~I've got a wonderful feeling
        """

        let parser = FountainParser(string: script)

        #expect(parser.elements.count >= 4, "Should parse lyrics elements")
        #expect(parser.elements[0].elementType == .lyrics)
        #expect(parser.elements[0].elementText == "~Oh, what a beautiful morning")
        #expect(parser.elements[1].elementType == .lyrics)
    }

    @Test func testLyricsWithSpaceBetween() {
        let script = """
        ~First line

        ~Second line after blank line
        """

        let parser = FountainParser(string: script)

        #expect(parser.elements.count >= 2, "Should handle lyrics with blank lines")
        #expect(parser.elements[0].elementType == .lyrics)
        // When there's a newline before, it should add a space separator
        let lyricsCount = parser.elements.filter { $0.elementType == .lyrics }.count
        #expect(lyricsCount > 1, "Should have multiple lyrics elements")
    }

    // MARK: - Forced Action Tests

    @Test func testForcedActionWithExclamation() {
        let script = """
        !This is a forced action line
        !Another forced action
        """

        let parser = FountainParser(string: script)

        #expect(parser.elements.count >= 2, "Should parse forced action elements")
        #expect(parser.elements[0].elementType == .action)
        #expect(parser.elements[0].elementText == "!This is a forced action line")
        #expect(parser.elements[1].elementType == .action)
    }

    // MARK: - Forced Character Tests

    @Test func testForcedCharacterWithAt() {
        let script = """
        @McCLANE
        Yippee-ki-yay!
        """

        let parser = FountainParser(string: script)

        #expect(parser.elements.count >= 2, "Should parse forced character")
        #expect(parser.elements[0].elementType == .character)
        #expect(parser.elements[0].elementText == "@McCLANE")
        #expect(parser.elements[1].elementType == .dialogue)
    }

    // MARK: - Dialogue Continuation Tests

    @Test func testDialogueContinuationWithDoubleSpaces() {
        let script = """
        JOHN
        This is the first line.

        This continues after double spaces.
        """

        let parser = FountainParser(string: script)

        let dialogueElements = parser.elements.filter { $0.elementType == .dialogue }
        #expect(dialogueElements.count > 0, "Should have dialogue elements")
    }

    @Test func testEmptyDialogueLineWithDoubleSpaces() {
        let script = """
        JOHN
        First line

        Second line after double space
        """

        let parser = FountainParser(string: script)

        #expect(parser.elements.count > 0, "Should parse dialogue with double spaces")
        let characterIndex = parser.elements.firstIndex { $0.elementType == .character }
        #expect(characterIndex, "Should have character element" != nil)
    }

    // MARK: - Multiple Spaces (Action) Tests

    @Test func testMultipleSpacesAsAction() {
        let script = """
        Some action here



        More action after multiple spaces
        """

        let parser = FountainParser(string: script)

        let actionElements = parser.elements.filter { $0.elementType == .action }
        #expect(actionElements.count > 0, "Should have action elements")
    }

    // MARK: - Complex Fountain Features

    @Test func testPageBreaks() {
        let script = """
        Some action before page break

        ===

        Action after page break
        """

        let parser = FountainParser(string: script)

        let pageBreaks = parser.elements.filter { $0.elementType == .pageBreak }
        #expect(pageBreaks.count == 1, "Should have one page break")
    }

    @Test func testSynopsis() {
        let script = """
        INT. COFFEE SHOP - DAY

        = John meets Jane for the first time

        JOHN enters.
        """

        let parser = FountainParser(string: script)

        let synopses = parser.elements.filter { $0.elementType == .synopsis }
        #expect(synopses.count == 1, "Should have one synopsis")
        #expect(synopses[0].elementText.contains("John meets Jane"), "Synopsis text should contain expected content")
    }

    @Test func testComment() {
        let script = """
        INT. OFFICE - DAY

        [[ This is a note about the scene ]]

        JOHN enters.
        """

        let parser = FountainParser(string: script)

        let comments = parser.elements.filter { $0.elementType == .comment }
        #expect(comments.count == 1, "Should have one comment")
        #expect(comments[0].elementText == "This is a note about the scene")
    }

    @Test func testBoneyardSingleLine() {
        let script = """
        Some action

        /* This is in the boneyard */

        More action
        """

        let parser = FountainParser(string: script)

        let boneyards = parser.elements.filter { $0.elementType == .boneyard }
        #expect(boneyards.count == 1, "Should have one boneyard")
    }

    @Test func testBoneyardMultiLine() {
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
        #expect(boneyards.count == 1, "Should have one boneyard")
    }

    @Test func testSectionHeading() {
        let script = """
        # Act One

        ## Scene Group

        ### Sub-section

        INT. LOCATION - DAY
        """

        let parser = FountainParser(string: script)

        let sections = parser.elements.filter { $0.elementType.isSectionHeading }
        #expect(sections.count == 3, "Should have three section headings")
        #expect(sections[0].sectionDepth == 1)  // One #
        #expect(sections[1].sectionDepth == 2)  // Two #
        #expect(sections[2].sectionDepth == 3)  // Three #
    }

    @Test func testForcedSceneHeading() {
        let script = """
        .FLASHBACK - 1984

        Some action here.
        """

        let parser = FountainParser(string: script)

        let scenes = parser.elements.filter { $0.elementType == .sceneHeading }
        #expect(scenes.count == 1, "Should have one forced scene heading")
        #expect(scenes[0].elementText == "FLASHBACK - 1984")
    }

    @Test func testSceneHeadingWithNumber() {
        let script = """
        INT. OFFICE - DAY #1#

        Some action.
        """

        let parser = FountainParser(string: script)

        let scenes = parser.elements.filter { $0.elementType == .sceneHeading }
        #expect(scenes.count == 1, "Should have scene heading")
        #expect(scenes[0].sceneNumber == "1", "Should extract scene number")
        #expect(!scenes[0].elementText.contains("#"), "Scene text should not contain # markers")
    }

    @Test func testForcedSceneHeadingWithNumber() {
        let script = """
        .FLASHBACK #42A#

        Action here.
        """

        let parser = FountainParser(string: script)

        let scenes = parser.elements.filter { $0.elementType == .sceneHeading }
        #expect(scenes.count == 1, "Should have forced scene heading")
        #expect(scenes[0].sceneNumber == "42A", "Should extract scene number")
    }

    @Test func testTransitions() {
        let script = """
        Action line.

        CUT TO:

        More action.

        FADE OUT.

        THE END
        """

        let parser = FountainParser(string: script)

        let transitions = parser.elements.filter { $0.elementType == .transition }
        #expect(transitions.count >= 2, "Should have at least two transitions")
    }

    @Test func testForcedTransition() {
        let script = """
        Action here.

        > SMASH CUT TO:

        More action.
        """

        let parser = FountainParser(string: script)

        let transitions = parser.elements.filter { $0.elementType == .transition }
        #expect(transitions.count == 1, "Should have forced transition")
        #expect(transitions[0].elementText.contains("SMASH CUT TO:"), "Transition text should contain expected content")
    }

    @Test func testCenteredText() {
        let script = """
        > THE END <

        """

        let parser = FountainParser(string: script)

        let centered = parser.elements.filter { $0.isCentered }
        #expect(centered.count == 1, "Should have centered text")
        #expect(centered[0].elementText == "THE END")
        #expect(centered[0].elementType == .action)
    }

    @Test func testDualDialogue() {
        let script = """
        JOHN
        Hello!

        JANE ^
        Hi there!
        """

        let parser = FountainParser(string: script)

        let characters = parser.elements.filter { $0.elementType == .character }
        #expect(characters.count >= 2, "Should have two characters")

        // Both characters should be marked as dual dialogue
        let dualCharacters = characters.filter { $0.isDualDialogue }
        #expect(dualCharacters.count >= 1, "Should have dual dialogue markers")
    }

    // MARK: - Title Page Tests

    @Test func testTitlePageDirective() {
        let script = """
        Title:
            My Screenplay
        Author:
            John Doe

        INT. LOCATION - DAY

        Action.
        """

        let parser = FountainParser(string: script)

        #expect(parser.titlePage.count > 0, "Should have title page entries")

        let titleEntry = parser.titlePage.first { $0.keys.contains("title") }
        #expect(titleEntry, "Should have title entry" != nil)
        #expect(titleEntry?["title"]?.first == "My Screenplay")
    }

    @Test func testTitlePageInline() {
        let script = """
        Title: My Screenplay
        Draft: First Draft

        INT. LOCATION - DAY
        """

        let parser = FountainParser(string: script)

        #expect(parser.titlePage.count >= 2, "Should have title page entries")
    }

    @Test func testTitlePageAuthorConversion() {
        let script = """
        Author: Jane Smith

        INT. LOCATION - DAY
        """

        let parser = FountainParser(string: script)

        // "Author" should be converted to "authors"
        let authorsEntry = parser.titlePage.first { $0.keys.contains("authors") }
        #expect(authorsEntry, "Should convert 'author' to 'authors'" != nil)
    }

    // MARK: - Edge Cases

    @Test func testOverBlackSceneHeading() {
        let script = """

        OVER BLACK

        We hear voices.
        """

        let parser = FountainParser(string: script)

        let scenes = parser.elements.filter { $0.elementType == .sceneHeading }
        #expect(scenes.count == 1, "Should recognize OVER BLACK as scene heading")
    }

    @Test func testCharacterWithContd() {
        let script = """
        JOHN
        I'm talking.

        JOHN (cont'd)
        I'm still talking.
        """

        let parser = FountainParser(string: script)

        let characters = parser.elements.filter { $0.elementType == .character }
        #expect(characters.count > 0, "Should parse character")
    }

    @Test func testSceneHeadingNotSurroundedByBlanks() {
        let script = """
        This looks like a scene heading
        INT. OFFICE - DAY
        but it's not surrounded by blank lines
        """

        let parser = FountainParser(string: script)

        // This should be merged into action, not treated as a scene heading
        let scenes = parser.elements.filter { $0.elementType == .sceneHeading }
        #expect(scenes.count == 0, "Should not treat as scene heading without blank lines")
    }

    @Test func testParentheticalInDialogue() {
        let script = """
        JOHN
        Hello there.
        (smiling)
        How are you?
        """

        let parser = FountainParser(string: script)

        let parentheticals = parser.elements.filter { $0.elementType == .parenthetical }
        #expect(parentheticals.count == 1, "Should have parenthetical")
    }
}
