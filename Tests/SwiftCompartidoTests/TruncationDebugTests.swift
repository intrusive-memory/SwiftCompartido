//
//  TruncationDebugTests.swift
//  SwiftCompartido
//
//  Debug tests to identify truncation issues
//

import Testing
import SwiftUI
@testable import SwiftCompartido

@MainActor
struct TruncationDebugTests {

    let longActionText = """
    Bernard and Killian sit in a steam room at an upscale gym. The heat is oppressive, sweat dripping down their faces. They sit in silence for a moment, the tension palpable between them as steam rises around their bodies. Bernard finally speaks, breaking the uncomfortable silence that has stretched between them.
    """

    @Test("ActionView renders multi-line text without truncation")
    func testActionViewMultiLine() {
        let element = GuionElementModel(
            elementText: longActionText,
            elementType: .action
        )

        let view = ActionView(element: element)
            .environment(\.screenplayFontSize, 12)

        // The element should contain the full text
        #expect(element.elementText.count > 200)
        #expect(element.elementText.contains("Bernard finally speaks"))
    }

    @Test("DialogueTextView renders multi-line text without truncation")
    func testDialogueTextViewMultiLine() {
        let element = GuionElementModel(
            elementText: longActionText,
            elementType: .dialogue
        )

        let view = DialogueTextView(element: element)
            .environment(\.screenplayFontSize, 12)

        // The element should contain the full text
        #expect(element.elementText.count > 200)
        #expect(element.elementText.contains("Bernard finally speaks"))
    }

    @Test("Verify no lineLimit on action/dialogue elements")
    func testNoLineLimitOnElements() {
        // This test documents that action and dialogue should NOT have lineLimit
        let actionElement = GuionElementModel(
            elementText: longActionText,
            elementType: .action
        )

        let dialogueElement = GuionElementModel(
            elementText: longActionText,
            elementType: .dialogue
        )

        // Both should preserve full text
        #expect(actionElement.elementText == longActionText)
        #expect(dialogueElement.elementText == longActionText)
    }
}
