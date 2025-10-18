//
//  FountainRegexesTests.swift
//  SwiftGuionTests
//
//  Tests for Fountain regex patterns
//

import XCTest
import Foundation
@testable import SwiftCompartido

final class FountainRegexesTests: XCTestCase {

    func testSceneHeaderPatternCompiles() throws {
        let pattern = FountainRegexes.sceneHeaderPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    func testSceneHeaderMatches() throws {
        let pattern = FountainRegexes.sceneHeaderPattern
        let regex = try NSRegularExpression(pattern: pattern)

        let testCases = [
            "\nINT. BEDROOM - DAY\n",
            "\nEXT. PARK - NIGHT\n",
            "\nINT./EXT. CAR - DAY\n",
            "\nI/E CAR - DAY\n"
        ]

        for testCase in testCases {
            let matches = regex.matches(in: testCase, range: NSRange(testCase.startIndex..., in: testCase))
            XCTAssertGreaterThan(matches.count, 0, "Should match: \(testCase)")
        }
    }

    
    func testActionPatternCompiles() throws {
        let pattern = FountainRegexes.actionPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testCharacterCuePatternCompiles() throws {
        let pattern = FountainRegexes.characterCuePattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testDialoguePatternCompiles() throws {
        let pattern = FountainRegexes.dialoguePattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testParentheticalPatternCompiles() throws {
        let pattern = FountainRegexes.parentheticalPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testTransitionPatternCompiles() throws {
        let pattern = FountainRegexes.transitionPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testTransitionMatches() throws {
        let pattern = FountainRegexes.transitionPattern
        let regex = try NSRegularExpression(pattern: pattern)

        let testCases = [
            "\nFADE TO BLACK.\n",
            "\nFADE OUT.\n",
            "\nCUT TO BLACK.\n"
        ]

        for testCase in testCases {
            let matches = regex.matches(in: testCase, range: NSRange(testCase.startIndex..., in: testCase))
            XCTAssertGreaterThan(matches.count, 0, "Should match: \(testCase)")
        }
    }

    
    func testForcedTransitionPatternCompiles() throws {
        let pattern = FountainRegexes.forcedTransitionPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testPageBreakPatternCompiles() throws {
        let pattern = FountainRegexes.pageBreakPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testPageBreakMatches() throws {
        let pattern = FountainRegexes.pageBreakPattern
        let regex = try NSRegularExpression(pattern: pattern)

        let testCases = [
            "\n===\n",
            "\n---\n",
            "\n___\n",
            "\n=====\n"
        ]

        for testCase in testCases {
            let matches = regex.matches(in: testCase, range: NSRange(testCase.startIndex..., in: testCase))
            XCTAssertGreaterThan(matches.count, 0, "Should match: \(testCase)")
        }
    }

    
    func testSceneNumberPatternCompiles() throws {
        let pattern = FountainRegexes.sceneNumberPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testSceneNumberMatches() throws {
        let pattern = FountainRegexes.sceneNumberPattern
        let regex = try NSRegularExpression(pattern: pattern)

        let testCases = [
            "#1#",
            "#42#",
            "#1A#",
            "#1.5#"
        ]

        for testCase in testCases {
            let matches = regex.matches(in: testCase, range: NSRange(testCase.startIndex..., in: testCase))
            XCTAssertGreaterThan(matches.count, 0, "Should match: \(testCase)")
        }
    }

    
    func testSectionHeaderPatternCompiles() throws {
        let pattern = FountainRegexes.sectionHeaderPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testSectionHeaderMatches() throws {
        let pattern = FountainRegexes.sectionHeaderPattern
        let regex = try NSRegularExpression(pattern: pattern)

        let testCases = [
            "# Act 1\n",
            "## Chapter 2\n",
            "### Scene Group\n"
        ]

        for testCase in testCases {
            let matches = regex.matches(in: testCase, range: NSRange(testCase.startIndex..., in: testCase))
            XCTAssertGreaterThan(matches.count, 0, "Should match: \(testCase)")
        }
    }

    
    func testBlockCommentPatternCompiles() throws {
        let pattern = FountainRegexes.blockCommentPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testBracketCommentPatternCompiles() throws {
        let pattern = FountainRegexes.bracketCommentPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testSynopsisPatternCompiles() throws {
        let pattern = FountainRegexes.synopsisPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testTitlePagePatternCompiles() throws {
        let pattern = FountainRegexes.titlePagePattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testInlineDirectivePatternCompiles() throws {
        let pattern = FountainRegexes.inlineDirectivePattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testInlineDirectiveMatches() throws {
        let pattern = FountainRegexes.inlineDirectivePattern
        let regex = try NSRegularExpression(pattern: pattern)

        let testCases = [
            "Title: Big Fish",
            "Author: John August",
            "Draft date: 2003-12-23"
        ]

        for testCase in testCases {
            let matches = regex.matches(in: testCase, range: NSRange(testCase.startIndex..., in: testCase))
            XCTAssertGreaterThan(matches.count, 0, "Should match: \(testCase)")
        }
    }

    
    func testBoldItalicUnderlinePatternCompiles() throws {
        let pattern = FountainRegexes.boldItalicUnderlinePattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testBoldPatternCompiles() throws {
        let pattern = FountainRegexes.boldPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testItalicPatternCompiles() throws {
        let pattern = FountainRegexes.italicPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testUnderlinePatternCompiles() throws {
        let pattern = FountainRegexes.underlinePattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThan(regex.numberOfCaptureGroups, 0)
    }

    
    func testDualDialoguePatternCompiles() throws {
        let pattern = FountainRegexes.dualDialoguePattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThanOrEqual(regex.numberOfCaptureGroups, 0)
    }

    
    func testCenteredTextPatternCompiles() throws {
        let pattern = FountainRegexes.centeredTextPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThanOrEqual(regex.numberOfCaptureGroups, 0)
    }

    
    func testUniversalLineBreaksPatternCompiles() throws {
        let pattern = FountainRegexes.universalLineBreaksPattern
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertGreaterThanOrEqual(regex.numberOfCaptureGroups, 0)
    }

    
    func testTemplateConstantsNonEmpty() {
        XCTAssertFalse(FountainRegexes.sceneHeaderTemplate.isEmpty)
        XCTAssertFalse(FountainRegexes.actionTemplate.isEmpty)
        XCTAssertFalse(FountainRegexes.characterCueTemplate.isEmpty)
        XCTAssertFalse(FountainRegexes.dialogueTemplate.isEmpty)
        XCTAssertFalse(FountainRegexes.parentheticalTemplate.isEmpty)
        XCTAssertFalse(FountainRegexes.transitionTemplate.isEmpty)
        XCTAssertFalse(FountainRegexes.boldItalicUnderlineTemplate.isEmpty)
        XCTAssertFalse(FountainRegexes.boldTemplate.isEmpty)
        XCTAssertFalse(FountainRegexes.italicTemplate.isEmpty)
        XCTAssertFalse(FountainRegexes.underlineTemplate.isEmpty)
    }
}
