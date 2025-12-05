//
//  FountainRegexesTests.swift
//  SwiftGuionTests
//
//  Tests for Fountain regex patterns
//

import Testing
import Foundation
@testable import SwiftCompartido

struct FountainRegexesTests {

    @Test func testSceneHeaderPatternCompiles() throws {
        let pattern = FountainRegexes.sceneHeaderPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    @Test func testSceneHeaderMatches() throws {
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
            #expect(matches.count > 0, "Should match: \(testCase)")
        }
    }

    
    @Test func testActionPatternCompiles() throws {
        let pattern = FountainRegexes.actionPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testCharacterCuePatternCompiles() throws {
        let pattern = FountainRegexes.characterCuePattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testDialoguePatternCompiles() throws {
        let pattern = FountainRegexes.dialoguePattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testParentheticalPatternCompiles() throws {
        let pattern = FountainRegexes.parentheticalPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testTransitionPatternCompiles() throws {
        let pattern = FountainRegexes.transitionPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testTransitionMatches() throws {
        let pattern = FountainRegexes.transitionPattern
        let regex = try NSRegularExpression(pattern: pattern)

        let testCases = [
            "\nFADE TO BLACK.\n",
            "\nFADE OUT.\n",
            "\nCUT TO BLACK.\n"
        ]

        for testCase in testCases {
            let matches = regex.matches(in: testCase, range: NSRange(testCase.startIndex..., in: testCase))
            #expect(matches.count > 0, "Should match: \(testCase)")
        }
    }

    
    @Test func testForcedTransitionPatternCompiles() throws {
        let pattern = FountainRegexes.forcedTransitionPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testPageBreakPatternCompiles() throws {
        let pattern = FountainRegexes.pageBreakPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testPageBreakMatches() throws {
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
            #expect(matches.count > 0, "Should match: \(testCase)")
        }
    }

    
    @Test func testSceneNumberPatternCompiles() throws {
        let pattern = FountainRegexes.sceneNumberPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testSceneNumberMatches() throws {
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
            #expect(matches.count > 0, "Should match: \(testCase)")
        }
    }

    
    @Test func testSectionHeaderPatternCompiles() throws {
        let pattern = FountainRegexes.sectionHeaderPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testSectionHeaderMatches() throws {
        let pattern = FountainRegexes.sectionHeaderPattern
        let regex = try NSRegularExpression(pattern: pattern)

        let testCases = [
            "# Act 1\n",
            "## Chapter 2\n",
            "### Scene Group\n"
        ]

        for testCase in testCases {
            let matches = regex.matches(in: testCase, range: NSRange(testCase.startIndex..., in: testCase))
            #expect(matches.count > 0, "Should match: \(testCase)")
        }
    }

    
    @Test func testBlockCommentPatternCompiles() throws {
        let pattern = FountainRegexes.blockCommentPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testBracketCommentPatternCompiles() throws {
        let pattern = FountainRegexes.bracketCommentPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testSynopsisPatternCompiles() throws {
        let pattern = FountainRegexes.synopsisPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testTitlePagePatternCompiles() throws {
        let pattern = FountainRegexes.titlePagePattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testInlineDirectivePatternCompiles() throws {
        let pattern = FountainRegexes.inlineDirectivePattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testInlineDirectiveMatches() throws {
        let pattern = FountainRegexes.inlineDirectivePattern
        let regex = try NSRegularExpression(pattern: pattern)

        let testCases = [
            "Title: Big Fish",
            "Author: John August",
            "Draft date: 2003-12-23"
        ]

        for testCase in testCases {
            let matches = regex.matches(in: testCase, range: NSRange(testCase.startIndex..., in: testCase))
            #expect(matches.count > 0, "Should match: \(testCase)")
        }
    }

    
    @Test func testBoldItalicUnderlinePatternCompiles() throws {
        let pattern = FountainRegexes.boldItalicUnderlinePattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testBoldPatternCompiles() throws {
        let pattern = FountainRegexes.boldPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testItalicPatternCompiles() throws {
        let pattern = FountainRegexes.italicPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testUnderlinePatternCompiles() throws {
        let pattern = FountainRegexes.underlinePattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups > 0)
    }

    
    @Test func testDualDialoguePatternCompiles() throws {
        let pattern = FountainRegexes.dualDialoguePattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups >= 0)
    }

    
    @Test func testCenteredTextPatternCompiles() throws {
        let pattern = FountainRegexes.centeredTextPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups >= 0)
    }

    
    @Test func testUniversalLineBreaksPatternCompiles() throws {
        let pattern = FountainRegexes.universalLineBreaksPattern
        let regex = try NSRegularExpression(pattern: pattern)
        #expect(regex.numberOfCaptureGroups >= 0)
    }

    
    @Test func testTemplateConstantsNonEmpty() {
        #expect(!FountainRegexes.sceneHeaderTemplate.isEmpty)
        #expect(!FountainRegexes.actionTemplate.isEmpty)
        #expect(!FountainRegexes.characterCueTemplate.isEmpty)
        #expect(!FountainRegexes.dialogueTemplate.isEmpty)
        #expect(!FountainRegexes.parentheticalTemplate.isEmpty)
        #expect(!FountainRegexes.transitionTemplate.isEmpty)
        #expect(!FountainRegexes.boldItalicUnderlineTemplate.isEmpty)
        #expect(!FountainRegexes.boldTemplate.isEmpty)
        #expect(!FountainRegexes.italicTemplate.isEmpty)
        #expect(!FountainRegexes.underlineTemplate.isEmpty)
    }
}
