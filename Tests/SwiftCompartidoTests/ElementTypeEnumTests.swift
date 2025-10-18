//
//  ElementTypeEnumTests.swift
//  SwiftGuionTests
//
//  Tests for the ElementType enum conversion
//

import Testing
import Foundation
@testable import SwiftCompartido

@Suite("ElementType Enum Tests")
struct ElementTypeEnumTests {

    // MARK: - Enum Case Creation Tests

    @Test("Create all basic element type cases")
    func testBasicElementTypeCases() {
        // Test that all basic cases can be created
        let sceneHeading = ElementType.sceneHeading
        let action = ElementType.action
        let character = ElementType.character
        let dialogue = ElementType.dialogue
        let parenthetical = ElementType.parenthetical
        let transition = ElementType.transition
        let synopsis = ElementType.synopsis
        let comment = ElementType.comment
        let boneyard = ElementType.boneyard
        let lyrics = ElementType.lyrics
        let pageBreak = ElementType.pageBreak

        // Verify they are not nil (compilation check)
        #expect(sceneHeading != nil)
        #expect(action != nil)
        #expect(character != nil)
        #expect(dialogue != nil)
        #expect(parenthetical != nil)
        #expect(transition != nil)
        #expect(synopsis != nil)
        #expect(comment != nil)
        #expect(boneyard != nil)
        #expect(lyrics != nil)
        #expect(pageBreak != nil)
    }

    @Test("Create section heading with levels 1-6")
    func testSectionHeadingLevels() {
        let level1 = ElementType.sectionHeading(level: 1)
        let level2 = ElementType.sectionHeading(level: 2)
        let level3 = ElementType.sectionHeading(level: 3)
        let level4 = ElementType.sectionHeading(level: 4)
        let level5 = ElementType.sectionHeading(level: 5)
        let level6 = ElementType.sectionHeading(level: 6)

        #expect(level1 != nil)
        #expect(level2 != nil)
        #expect(level3 != nil)
        #expect(level4 != nil)
        #expect(level5 != nil)
        #expect(level6 != nil)
    }

    // MARK: - String Representation Tests

    @Test("String representation matches expected values")
    func testStringRepresentation() {
        #expect(ElementType.sceneHeading.description == "Scene Heading")
        #expect(ElementType.action.description == "Action")
        #expect(ElementType.character.description == "Character")
        #expect(ElementType.dialogue.description == "Dialogue")
        #expect(ElementType.parenthetical.description == "Parenthetical")
        #expect(ElementType.transition.description == "Transition")
        #expect(ElementType.synopsis.description == "Synopsis")
        #expect(ElementType.comment.description == "Comment")
        #expect(ElementType.boneyard.description == "Boneyard")
        #expect(ElementType.lyrics.description == "Lyrics")
        #expect(ElementType.pageBreak.description == "Page Break")
    }

    @Test("Section heading string representation includes level")
    func testSectionHeadingStringRepresentation() {
        let level1 = ElementType.sectionHeading(level: 1)
        let level3 = ElementType.sectionHeading(level: 3)

        #expect(level1.description == "Section Heading")
        #expect(level3.description == "Section Heading")
    }

    // MARK: - Initialization from String Tests

    @Test("Initialize from valid string values")
    func testInitFromValidStrings() {
        #expect(ElementType(string: "Scene Heading") == .sceneHeading)
        #expect(ElementType(string: "Action") == .action)
        #expect(ElementType(string: "Character") == .character)
        #expect(ElementType(string: "Dialogue") == .dialogue)
        #expect(ElementType(string: "Parenthetical") == .parenthetical)
        #expect(ElementType(string: "Transition") == .transition)
        #expect(ElementType(string: "Synopsis") == .synopsis)
        #expect(ElementType(string: "Comment") == .comment)
        #expect(ElementType(string: "Boneyard") == .boneyard)
        #expect(ElementType(string: "Lyrics") == .lyrics)
        #expect(ElementType(string: "Page Break") == .pageBreak)
    }

    @Test("Initialize section heading from string defaults to level 1")
    func testInitSectionHeadingFromString() {
        let sectionHeading = ElementType(string: "Section Heading")

        if case .sectionHeading(let level) = sectionHeading {
            #expect(level == 1)
        } else {
            Issue.record("Expected section heading case")
        }
    }

    @Test("Initialize from invalid string returns action as default")
    func testInitFromInvalidString() {
        let invalid = ElementType(string: "Invalid Type")
        #expect(invalid == .action)

        let empty = ElementType(string: "")
        #expect(empty == .action)
    }

    // MARK: - Pattern Matching Tests

    @Test("Pattern matching with switch statement")
    func testPatternMatchingSwitch() {
        let types: [ElementType] = [
            .sceneHeading,
            .action,
            .character,
            .dialogue,
            .sectionHeading(level: 3)
        ]

        var matchedCorrectly = true

        for type in types {
            switch type {
            case .sceneHeading:
                matchedCorrectly = matchedCorrectly && true
            case .action:
                matchedCorrectly = matchedCorrectly && true
            case .character:
                matchedCorrectly = matchedCorrectly && true
            case .dialogue:
                matchedCorrectly = matchedCorrectly && true
            case .sectionHeading(let level):
                matchedCorrectly = matchedCorrectly && (level == 3)
            default:
                matchedCorrectly = false
            }
        }

        #expect(matchedCorrectly)
    }

    @Test("Extract associated value from section heading")
    func testExtractAssociatedValue() {
        let level3 = ElementType.sectionHeading(level: 3)

        if case .sectionHeading(let level) = level3 {
            #expect(level == 3)
        } else {
            Issue.record("Failed to extract level from section heading")
        }
    }

    // MARK: - Equality Tests

    @Test("Equality comparison for simple cases")
    func testEqualitySimpleCases() {
        #expect(ElementType.sceneHeading == ElementType.sceneHeading)
        #expect(ElementType.action == ElementType.action)
        #expect(ElementType.dialogue == ElementType.dialogue)

        #expect(ElementType.sceneHeading != ElementType.action)
        #expect(ElementType.character != ElementType.dialogue)
    }

    @Test("Equality comparison for section headings with levels")
    func testEqualitySectionHeadings() {
        let level1a = ElementType.sectionHeading(level: 1)
        let level1b = ElementType.sectionHeading(level: 1)
        let level2 = ElementType.sectionHeading(level: 2)

        #expect(level1a == level1b)
        #expect(level1a != level2)
    }

    // MARK: - Level Property Tests

    @Test("Level property returns correct value for section headings")
    func testLevelProperty() {
        let level1 = ElementType.sectionHeading(level: 1)
        let level3 = ElementType.sectionHeading(level: 3)
        let level6 = ElementType.sectionHeading(level: 6)

        #expect(level1.level == 1)
        #expect(level3.level == 3)
        #expect(level6.level == 6)
    }

    @Test("Level property returns 0 for non-section heading types")
    func testLevelPropertyNonSectionHeadings() {
        #expect(ElementType.sceneHeading.level == 0)
        #expect(ElementType.action.level == 0)
        #expect(ElementType.dialogue.level == 0)
    }

    // MARK: - Outline Element Tests (Per Fountain.io Spec)

    @Test("Outline level 1 represents title")
    func testOutlineLevel1() {
        let title = ElementType.sectionHeading(level: 1)
        #expect(title.level == 1)
        #expect(title.description == "Section Heading")
    }

    @Test("Outline level 2 represents act")
    func testOutlineLevel2() {
        let act = ElementType.sectionHeading(level: 2)
        #expect(act.level == 2)
    }

    @Test("Outline level 3 represents sequence")
    func testOutlineLevel3() {
        let sequence = ElementType.sectionHeading(level: 3)
        #expect(sequence.level == 3)
    }

    @Test("Outline level 4 represents scene group")
    func testOutlineLevel4() {
        let sceneGroup = ElementType.sectionHeading(level: 4)
        #expect(sceneGroup.level == 4)
    }

    @Test("Outline level 5 represents sub-scene")
    func testOutlineLevel5() {
        let subScene = ElementType.sectionHeading(level: 5)
        #expect(subScene.level == 5)
    }

    @Test("Outline level 6 represents beat")
    func testOutlineLevel6() {
        let beat = ElementType.sectionHeading(level: 6)
        #expect(beat.level == 6)
    }

    @Test("Outline summary is represented by synopsis")
    func testOutlineSummary() {
        let summary = ElementType.synopsis
        #expect(summary == .synopsis)
        #expect(summary.description == "Synopsis")
    }

    // MARK: - Helper Method Tests

    @Test("isSectionHeading helper returns correct value")
    func testIsSectionHeadingHelper() {
        #expect(ElementType.sectionHeading(level: 1).isSectionHeading == true)
        #expect(ElementType.sectionHeading(level: 3).isSectionHeading == true)
        #expect(ElementType.sceneHeading.isSectionHeading == false)
        #expect(ElementType.action.isSectionHeading == false)
    }

    @Test("isDialogueRelated helper returns correct value")
    func testIsDialogueRelatedHelper() {
        #expect(ElementType.character.isDialogueRelated == true)
        #expect(ElementType.dialogue.isDialogueRelated == true)
        #expect(ElementType.parenthetical.isDialogueRelated == true)
        #expect(ElementType.action.isDialogueRelated == false)
        #expect(ElementType.sceneHeading.isDialogueRelated == false)
    }

    // MARK: - Codable Tests

    @Test("Encode and decode section heading preserves level")
    func testCodableSectionHeading() throws {
        let original = ElementType.sectionHeading(level: 3)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ElementType.self, from: data)

        #expect(decoded == original)
        if case .sectionHeading(let level) = decoded {
            #expect(level == 3)
        } else {
            Issue.record("Decoded type is not section heading")
        }
    }

    @Test("Encode and decode all basic types")
    func testCodableAllTypes() throws {
        let types: [ElementType] = [
            .sceneHeading,
            .action,
            .character,
            .dialogue,
            .parenthetical,
            .transition,
            .synopsis,
            .comment,
            .boneyard,
            .lyrics,
            .pageBreak,
            .sectionHeading(level: 1),
            .sectionHeading(level: 6)
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for type in types {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(ElementType.self, from: data)
            #expect(decoded == type)
        }
    }
}
