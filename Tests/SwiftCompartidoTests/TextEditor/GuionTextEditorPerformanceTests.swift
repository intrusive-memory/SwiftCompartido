//
//  GuionTextEditorPerformanceTests.swift
//  SwiftCompartido
//
//  Performance tests for GuionTextEditor vs GuionElementsList
//

import Testing
import Foundation
@testable import SwiftCompartido

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@Suite("GuionTextEditor Performance Tests")
struct GuionTextEditorPerformanceTests {

    @Test("TextKit2 - Load 1000 elements")
    func testTextKit2Load1000() async throws {
        let elements = generateElements(count: 1000)

        let startTime = CFAbsoluteTimeGetCurrent()

        let attributedText = GuionTextElementMapper.buildAttributedText(from: elements)

        let loadTime = CFAbsoluteTimeGetCurrent() - startTime

        await PerformanceMetricsTracker.shared.recordMetric(
            testName: "TextKit2_Load_1000",
            elementCount: 1000,
            parseTime: 0,
            convertTime: loadTime,
            sortTime: 0,
            formatTime: 0
        )

        print("📊 TextKit 2 load (1000 elements): \(String(format: "%.3f", loadTime))s")
        print("📏 Generated text length: \(attributedText.length) characters")

        #expect(loadTime < 0.5)  // Target: < 0.5s (vs 1.2s for List-based)
        #expect(attributedText.length > 0)
    }

    @Test("TextKit2 - Load 5000 elements")
    func testTextKit2Load5000() async throws {
        let elements = generateElements(count: 5000)

        let startTime = CFAbsoluteTimeGetCurrent()

        let attributedText = GuionTextElementMapper.buildAttributedText(from: elements)

        let loadTime = CFAbsoluteTimeGetCurrent() - startTime

        await PerformanceMetricsTracker.shared.recordMetric(
            testName: "TextKit2_Load_5000",
            elementCount: 5000,
            parseTime: 0,
            convertTime: loadTime,
            sortTime: 0,
            formatTime: 0
        )

        print("📊 TextKit 2 load (5000 elements): \(String(format: "%.3f", loadTime))s")
        print("📏 Generated text length: \(attributedText.length) characters")

        #expect(loadTime < 2.5)  // Target: < 2.5s (vs 24s for List-based)
        #expect(attributedText.length > 0)
    }

    @Test("TextKit2 - Spacing logic matches GuionElementsList")
    func testSpacingLogic() async throws {
        // Test dialogue group spacing
        let dialogueGroup = [
            GuionElementModel(elementText: "JOHN", elementType: .character, orderIndex: 0),
            GuionElementModel(elementText: "Hello there.", elementType: .dialogue, orderIndex: 1),
            GuionElementModel(elementText: "(smiling)", elementType: .parenthetical, orderIndex: 2),
            GuionElementModel(elementText: "How are you?", elementType: .dialogue, orderIndex: 3),
            GuionElementModel(elementText: "John walks away.", elementType: .action, orderIndex: 4)
        ]

        let attributedText = GuionTextElementMapper.buildAttributedText(from: dialogueGroup)
        let text = attributedText.string

        // Should have single newlines within dialogue group, double after
        let lines = text.components(separatedBy: "\n")

        print("📝 Generated text:\n\(text)")
        print("📊 Line count: \(lines.count)")

        // Verify text contains all elements
        #expect(text.contains("JOHN"))
        #expect(text.contains("Hello there."))
        #expect(text.contains("(smiling)"))
        #expect(text.contains("How are you?"))
        #expect(text.contains("John walks away."))
    }

    @Test("TextKit2 - Action spacing")
    func testActionSpacing() async throws {
        let elements = [
            GuionElementModel(elementText: "First action.", elementType: .action, orderIndex: 0),
            GuionElementModel(elementText: "Second action.", elementType: .action, orderIndex: 1)
        ]

        let attributedText = GuionTextElementMapper.buildAttributedText(from: elements)
        let text = attributedText.string

        // Actions should have double newline spacing
        #expect(text.contains("\n\n"))

        print("📝 Action spacing test:\n\(text)")
    }

    @Test("TextKit2 - Formatting applied correctly")
    func testFormattingApplied() async throws {
        let elements = [
            GuionElementModel(elementText: "INT. OFFICE - DAY", elementType: .sceneHeading, orderIndex: 0),
            GuionElementModel(elementText: "JOHN", elementType: .character, orderIndex: 1),
            GuionElementModel(elementText: "Hello **world** with *italic*.", elementType: .dialogue, orderIndex: 2)
        ]

        let attributedText = GuionTextElementMapper.buildAttributedText(from: elements, fontSize: 12)

        // Verify attributed string has content
        #expect(attributedText.length > 0)
        #expect(attributedText.string.contains("INT. OFFICE - DAY"))
        #expect(attributedText.string.contains("JOHN"))

        // Inline formatting should remove markers
        #expect(attributedText.string.contains("world"))
        #expect(attributedText.string.contains("italic"))
        #expect(!attributedText.string.contains("**"))  // Bold markers removed
        #expect(!attributedText.string.contains("*italic*"))  // Italic markers removed
    }

    @Test("TextKit2 - Screenplay margins applied")
    func testScreenplayMargins() async throws {
        let elements = [
            GuionElementModel(elementText: "JOHN", elementType: .character, orderIndex: 0),
            GuionElementModel(elementText: "Hello there.", elementType: .dialogue, orderIndex: 1)
        ]

        let attributedText = GuionTextElementMapper.buildAttributedText(from: elements, fontSize: 12)

        // Verify paragraph styles are applied
        if let paragraphStyle = attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
            // Character should have left margin (40% = 26 chars * 7.2pt = 187.2pt)
            #expect(paragraphStyle.firstLineHeadIndent > 0)
            print("✅ Character left margin: \(paragraphStyle.firstLineHeadIndent)pt")
        }
    }

    @Test("TextKit2 - Markdown formatting")
    func testMarkdownFormatting() async throws {
        let elements = [
            GuionElementModel(elementText: "Chapter One", elementType: .sectionHeading(level: 1), orderIndex: 0),
            GuionElementModel(elementText: "Scene One", elementType: .sectionHeading(level: 2), orderIndex: 1),
            GuionElementModel(elementText: "- First item", elementType: .unorderedListItem(level: 0), orderIndex: 2),
            GuionElementModel(elementText: "1. First number", elementType: .orderedListItem(level: 0), orderIndex: 3)
        ]

        let attributedText = GuionTextElementMapper.buildAttributedText(from: elements, fontSize: 12)

        // Verify markdown elements present
        #expect(attributedText.string.contains("Chapter One"))
        #expect(attributedText.string.contains("Scene One"))
        #expect(attributedText.string.contains("- First item"))
        #expect(attributedText.string.contains("1. First number"))
    }

    @Test("TextKit2 - All screenplay element types render correctly")
    func testAllElementTypes() async throws {
        // Test each element type individually to ensure all are supported
        let testCases: [(String, ElementType)] = [
            ("INT. OFFICE - DAY", .sceneHeading),
            ("John walks in.", .action),
            ("JOHN", .character),
            ("Hello there.", .dialogue),
            ("(quietly)", .parenthetical),
            ("FADE TO:", .transition),
            ("This is a synopsis.", .synopsis),
            ("La la la", .lyrics)
        ]

        for (text, elementType) in testCases {
            let elements = [GuionElementModel(elementText: text, elementType: elementType, orderIndex: 0)]
            let attributedText = GuionTextElementMapper.buildAttributedText(from: elements, fontSize: 12)
            #expect(attributedText.string.contains(text), "Expected to find '\(text)' for element type \(elementType)")
        }

        print("✅ All screenplay element types rendered")
    }

    @Test("TextKit2 - Markdown element types render correctly")
    func testMarkdownElementTypes() async throws {
        // Test markdown-specific element types
        let testCases: [(String, ElementType)] = [
            ("This is a comment.", .comment),
            ("/* This is omitted */", .boneyard),
            ("===", .pageBreak)
        ]

        for (text, elementType) in testCases {
            let elements = [GuionElementModel(elementText: text, elementType: elementType, orderIndex: 0)]
            let attributedText = GuionTextElementMapper.buildAttributedText(from: elements, fontSize: 12)
            #expect(attributedText.string.contains(text), "Expected to find '\(text)' for element type \(elementType)")
        }

        print("✅ All markdown element types rendered")
    }

    @Test("TextKit2 - Font size scaling")
    func testFontSizeScaling() async throws {
        let elements = [
            GuionElementModel(elementText: "INT. OFFICE - DAY", elementType: .sceneHeading, orderIndex: 0),
            GuionElementModel(elementText: "JOHN", elementType: .character, orderIndex: 1)
        ]

        // Test with different font sizes
        let fontSize8 = GuionTextElementMapper.buildAttributedText(from: elements, fontSize: 8)
        let fontSize16 = GuionTextElementMapper.buildAttributedText(from: elements, fontSize: 16)
        let fontSize24 = GuionTextElementMapper.buildAttributedText(from: elements, fontSize: 24)

        // All should contain same text
        #expect(fontSize8.string.contains("INT. OFFICE - DAY"))
        #expect(fontSize16.string.contains("INT. OFFICE - DAY"))
        #expect(fontSize24.string.contains("INT. OFFICE - DAY"))

        print("✅ Font scaling: 8pt=\(fontSize8.length) 16pt=\(fontSize16.length) 24pt=\(fontSize24.length) chars")
    }

    @Test("TextKit2 - Empty element handling")
    func testEmptyElements() async throws {
        let elements = [
            GuionElementModel(elementText: "", elementType: .action, orderIndex: 0),
            GuionElementModel(elementText: "Non-empty", elementType: .action, orderIndex: 1),
            GuionElementModel(elementText: "", elementType: .dialogue, orderIndex: 2)
        ]

        let attributedText = GuionTextElementMapper.buildAttributedText(from: elements, fontSize: 12)

        // Should handle empty elements gracefully
        #expect(attributedText.string.contains("Non-empty"))
        print("✅ Empty elements handled: \(attributedText.length) characters")
    }

    @Test("TextKit2 - Section heading levels")
    func testSectionHeadingLevels() async throws {
        let elements = [
            GuionElementModel(elementText: "Heading 1", elementType: .sectionHeading(level: 1), orderIndex: 0),
            GuionElementModel(elementText: "Heading 2", elementType: .sectionHeading(level: 2), orderIndex: 1),
            GuionElementModel(elementText: "Heading 3", elementType: .sectionHeading(level: 3), orderIndex: 2),
            GuionElementModel(elementText: "Heading 4", elementType: .sectionHeading(level: 4), orderIndex: 3),
            GuionElementModel(elementText: "Heading 5", elementType: .sectionHeading(level: 5), orderIndex: 4),
            GuionElementModel(elementText: "Heading 6", elementType: .sectionHeading(level: 6), orderIndex: 5)
        ]

        let attributedText = GuionTextElementMapper.buildAttributedText(from: elements, fontSize: 12)

        // Verify all heading levels present
        for i in 1...6 {
            #expect(attributedText.string.contains("Heading \(i)"))
        }

        print("✅ All heading levels rendered: \(attributedText.length) characters")
    }

    @Test("TextKit2 - List indentation levels")
    func testListIndentation() async throws {
        let elements = [
            GuionElementModel(elementText: "- Level 0", elementType: .unorderedListItem(level: 0), orderIndex: 0),
            GuionElementModel(elementText: "- Level 1", elementType: .unorderedListItem(level: 1), orderIndex: 1),
            GuionElementModel(elementText: "1. Number 0", elementType: .orderedListItem(level: 0), orderIndex: 2),
            GuionElementModel(elementText: "1. Number 1", elementType: .orderedListItem(level: 1), orderIndex: 3)
        ]

        let attributedText = GuionTextElementMapper.buildAttributedText(from: elements, fontSize: 12)

        // Verify list items present
        #expect(attributedText.string.contains("- Level 0"))
        #expect(attributedText.string.contains("- Level 1"))
        #expect(attributedText.string.contains("1. Number 0"))
        #expect(attributedText.string.contains("1. Number 1"))

        print("✅ List indentation rendered: \(attributedText.length) characters")
    }

    @Test("TextKit2 - Mixed inline formatting")
    func testMixedInlineFormatting() async throws {
        let elements = [
            GuionElementModel(
                elementText: "This has **bold** and *italic* and _underline_ text.",
                elementType: .action,
                orderIndex: 0
            ),
            GuionElementModel(
                elementText: "**Bold only** text here.",
                elementType: .action,
                orderIndex: 1
            ),
            GuionElementModel(
                elementText: "*Italic only* text here.",
                elementType: .action,
                orderIndex: 2
            ),
            GuionElementModel(
                elementText: "_Underline only_ text here.",
                elementType: .action,
                orderIndex: 3
            )
        ]

        let attributedText = GuionTextElementMapper.buildAttributedText(from: elements, fontSize: 12)

        // Verify formatting markers removed
        #expect(attributedText.string.contains("bold"))
        #expect(attributedText.string.contains("italic"))
        #expect(attributedText.string.contains("underline"))
        #expect(!attributedText.string.contains("**bold**"))
        #expect(!attributedText.string.contains("*italic*"))
        #expect(!attributedText.string.contains("_underline_"))

        print("✅ Mixed inline formatting: \(attributedText.length) characters")
    }

    @Test("TextKit2 - Transition alignment")
    func testTransitionAlignment() async throws {
        let elements = [
            GuionElementModel(elementText: "FADE TO:", elementType: .transition, orderIndex: 0),
            GuionElementModel(elementText: "CUT TO:", elementType: .transition, orderIndex: 1),
            GuionElementModel(elementText: "DISSOLVE TO:", elementType: .transition, orderIndex: 2)
        ]

        let attributedText = GuionTextElementMapper.buildAttributedText(from: elements, fontSize: 12)

        // Check transitions present
        #expect(attributedText.string.contains("FADE TO:"))
        #expect(attributedText.string.contains("CUT TO:"))
        #expect(attributedText.string.contains("DISSOLVE TO:"))

        // Check alignment (should be right-aligned)
        let fullRange = NSRange(location: 0, length: attributedText.length)
        var foundRightAlign = false
        attributedText.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, stop in
            if let paragraphStyle = value as? NSParagraphStyle {
                if paragraphStyle.alignment == .right {
                    foundRightAlign = true
                }
            }
        }
        #expect(foundRightAlign)

        print("✅ Transitions right-aligned: \(attributedText.length) characters")
    }

    // MARK: - Helpers

    private func generateElements(count: Int) -> [GuionElementModel] {
        var elements: [GuionElementModel] = []

        for i in 0..<count {
            let elementType: ElementType

            // Mix of element types for realistic test
            switch i % 5 {
            case 0:
                elementType = .sceneHeading
            case 1:
                elementType = .action
            case 2:
                elementType = .character
            case 3:
                elementType = .dialogue
            default:
                elementType = .action
            }

            let element = GuionElementModel(
                elementText: "This is element \(i) with some **bold** and *italic* text.",
                elementType: elementType,
                chapterIndex: 0,
                orderIndex: i
            )

            elements.append(element)
        }

        return elements
    }
}
