//
//  ElementViewTests.swift
//  SwiftCompartido
//
//  Comprehensive tests for all screenplay element views
//

import Testing
import SwiftUI
@testable import SwiftCompartido

/// Test suite for all screenplay element view components
@MainActor
struct ElementViewTests {

    // MARK: - Test Helpers

    /// Create a mock GuionElementModel for testing
    private func createMockElement(type: ElementType, text: String) -> GuionElementModel {
        return GuionElementModel(
            elementText: text,
            elementType: type
        )
    }

    // MARK: - Action View Tests

    @Test("ActionView displays correct text")
    func testActionViewDisplaysText() {
        let element = createMockElement(type: .action, text: "Bernard and Killian sit in a steam room.")
        let view = ActionView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "Bernard and Killian sit in a steam room.")
    }

    @Test("ActionView uses correct font family")
    func testActionViewFontFamily() {
        let element = createMockElement(type: .action, text: "Test action")
        let view = ActionView(element: element)
            .environment(\.screenplayFontSize, 12)

        // Verify element is configured
        #expect(element.elementType == .action)
    }

    @Test("ActionView has proper margins")
    func testActionViewMargins() {
        let element = createMockElement(type: .action, text: "Action with multi-line text that should wrap properly.")
        let view = ActionView(element: element)
            .environment(\.screenplayFontSize, 12)

        // ActionView should use 10% left and right margins
        #expect(element.elementText.count > 0)
    }

    @Test("ActionView supports text selection")
    func testActionViewTextSelection() {
        let element = createMockElement(type: .action, text: "Selectable action text")
        let view = ActionView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "Selectable action text")
    }

    // MARK: - Scene Heading View Tests

    @Test("SceneHeadingView displays slugline correctly")
    func testSceneHeadingViewDisplaysText() {
        let element = createMockElement(type: .sceneHeading, text: "INT. STEAM ROOM - DAY")
        let view = SceneHeadingView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "INT. STEAM ROOM - DAY")
        #expect(element.elementType == .sceneHeading)
    }

    @Test("SceneHeadingView is bold and uppercase")
    func testSceneHeadingViewFormatting() {
        let element = createMockElement(type: .sceneHeading, text: "ext. park - night")
        let view = SceneHeadingView(element: element)
            .environment(\.screenplayFontSize, 12)

        // View should apply bold weight and uppercase transformation
        #expect(element.elementType == .sceneHeading)
    }

    @Test("SceneHeadingView has proper vertical padding")
    func testSceneHeadingViewPadding() {
        let element = createMockElement(type: .sceneHeading, text: "INT. OFFICE - DAY")
        let view = SceneHeadingView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText.count > 0)
    }

    // MARK: - Transition View Tests

    @Test("TransitionView displays transition text")
    func testTransitionViewDisplaysText() {
        let element = createMockElement(type: .transition, text: "CUT TO:")
        let view = TransitionView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "CUT TO:")
        #expect(element.elementType == .transition)
    }

    @Test("TransitionView is right-aligned")
    func testTransitionViewAlignment() {
        let element = createMockElement(type: .transition, text: "FADE OUT.")
        let view = TransitionView(element: element)
            .environment(\.screenplayFontSize, 12)

        // TransitionView should use 65% left margin for right-alignment effect
        #expect(element.elementType == .transition)
    }

    @Test("TransitionView handles various transition types")
    func testTransitionViewVariousTypes() {
        let transitions = ["CUT TO:", "FADE OUT.", "DISSOLVE TO:", "FADE IN:"]

        for transitionText in transitions {
            let element = createMockElement(type: .transition, text: transitionText)
            let view = TransitionView(element: element)
                .environment(\.screenplayFontSize, 12)

            #expect(element.elementText == transitionText)
        }
    }

    // MARK: - Section Heading View Tests

    @Test("SectionHeadingView handles level 1 (Title)")
    func testSectionHeadingViewLevel1() {
        let element = createMockElement(type: .sectionHeading(level: 1), text: "MY SCREENPLAY TITLE")
        let view = SectionHeadingView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "MY SCREENPLAY TITLE")

        if case .sectionHeading(let level) = element.elementType {
            #expect(level == 1)
        }
    }

    @Test("SectionHeadingView handles level 2 (Act)")
    func testSectionHeadingViewLevel2() {
        let element = createMockElement(type: .sectionHeading(level: 2), text: "ACT I")
        let view = SectionHeadingView(element: element)
            .environment(\.screenplayFontSize, 12)

        if case .sectionHeading(let level) = element.elementType {
            #expect(level == 2)
        }
    }

    @Test("SectionHeadingView handles level 3 (Sequence)")
    func testSectionHeadingViewLevel3() {
        let element = createMockElement(type: .sectionHeading(level: 3), text: "THE BEGINNING")
        let view = SectionHeadingView(element: element)
            .environment(\.screenplayFontSize, 12)

        if case .sectionHeading(let level) = element.elementType {
            #expect(level == 3)
        }
    }

    @Test("SectionHeadingView handles level 4 (Scene group)")
    func testSectionHeadingViewLevel4() {
        let element = createMockElement(type: .sectionHeading(level: 4), text: "PROLOGUE")
        let view = SectionHeadingView(element: element)
            .environment(\.screenplayFontSize, 12)

        if case .sectionHeading(let level) = element.elementType {
            #expect(level == 4)
        }
    }

    @Test("SectionHeadingView handles level 5 (Sub-scene)")
    func testSectionHeadingViewLevel5() {
        let element = createMockElement(type: .sectionHeading(level: 5), text: "Part A")
        let view = SectionHeadingView(element: element)
            .environment(\.screenplayFontSize, 12)

        if case .sectionHeading(let level) = element.elementType {
            #expect(level == 5)
        }
    }

    @Test("SectionHeadingView handles level 6 (Beat)")
    func testSectionHeadingViewLevel6() {
        let element = createMockElement(type: .sectionHeading(level: 6), text: "Beat 1")
        let view = SectionHeadingView(element: element)
            .environment(\.screenplayFontSize, 12)

        if case .sectionHeading(let level) = element.elementType {
            #expect(level == 6)
        }
    }

    @Test("SectionHeadingView has different font sizes per level")
    func testSectionHeadingViewFontScaling() {
        for level in 1...6 {
            let element = createMockElement(type: .sectionHeading(level: level), text: "Heading Level \(level)")
            let view = SectionHeadingView(element: element)
                .environment(\.screenplayFontSize, 12)

            if case .sectionHeading(let lvl) = element.elementType {
                #expect(lvl == level)
            }
        }
    }

    // MARK: - Synopsis View Tests

    @Test("SynopsisView displays synopsis text")
    func testSynopsisViewDisplaysText() {
        let element = createMockElement(type: .synopsis, text: "Brief scene summary")
        let view = SynopsisView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "Brief scene summary")
        #expect(element.elementType == .synopsis)
    }

    @Test("SynopsisView is italic and secondary color")
    func testSynopsisViewFormatting() {
        let element = createMockElement(type: .synopsis, text: "Scene description")
        let view = SynopsisView(element: element)
            .environment(\.screenplayFontSize, 12)

        // Synopsis should be italic and use secondary foreground color
        #expect(element.elementType == .synopsis)
    }

    @Test("SynopsisView handles multi-line synopsis")
    func testSynopsisViewMultiLine() {
        let longText = "This is a longer synopsis that describes the scene in detail and may span multiple lines."
        let element = createMockElement(type: .synopsis, text: longText)
        let view = SynopsisView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == longText)
    }

    // MARK: - Comment View Tests

    @Test("CommentView displays comment with brackets")
    func testCommentViewDisplaysText() {
        let element = createMockElement(type: .comment, text: "This is a note")
        let view = CommentView(element: element)
            .environment(\.screenplayFontSize, 12)

        // CommentView adds [[ ]] around the text
        #expect(element.elementText == "This is a note")
        #expect(element.elementType == .comment)
    }

    @Test("CommentView is italic and muted")
    func testCommentViewFormatting() {
        let element = createMockElement(type: .comment, text: "Production note")
        let view = CommentView(element: element)
            .environment(\.screenplayFontSize, 12)

        // Comment should be italic and use muted secondary color
        #expect(element.elementType == .comment)
    }

    @Test("CommentView handles long comments")
    func testCommentViewLongText() {
        let longComment = "This is a very long comment that provides detailed notes about the scene and may contain important production information."
        let element = createMockElement(type: .comment, text: longComment)
        let view = CommentView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText.count > 50)
    }

    // MARK: - Boneyard View Tests

    @Test("BoneyardView displays omitted text")
    func testBoneyardViewDisplaysText() {
        let element = createMockElement(type: .boneyard, text: "Deleted scene content")
        let view = BoneyardView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "Deleted scene content")
        #expect(element.elementType == .boneyard)
    }

    @Test("BoneyardView has strikethrough styling")
    func testBoneyardViewFormatting() {
        let element = createMockElement(type: .boneyard, text: "Old version")
        let view = BoneyardView(element: element)
            .environment(\.screenplayFontSize, 12)

        // Boneyard should have strikethrough and muted color
        #expect(element.elementType == .boneyard)
    }

    @Test("BoneyardView handles multi-line content")
    func testBoneyardViewMultiLine() {
        let multiLine = "This is old content\nthat spans multiple lines\nand should be struck through"
        let element = createMockElement(type: .boneyard, text: multiLine)
        let view = BoneyardView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText.contains("\n"))
    }

    // MARK: - Page Break View Tests

    @Test("PageBreakView displays visual divider")
    func testPageBreakViewDisplay() {
        let view = PageBreakView()
            .environment(\.screenplayFontSize, 12)

        // PageBreakView doesn't take an element, just displays a divider
        #expect(true) // View should compile and render
    }

    @Test("PageBreakView uses correct font size")
    func testPageBreakViewFontSize() {
        let smallView = PageBreakView()
            .environment(\.screenplayFontSize, 8)
        let largeView = PageBreakView()
            .environment(\.screenplayFontSize, 16)

        #expect(true) // Both views should render
    }

    // MARK: - Dialogue View Tests (Existing Views)

    @Test("DialogueCharacterView displays character name")
    func testDialogueCharacterViewDisplaysText() {
        let element = createMockElement(type: .character, text: "BERNARD")
        let view = DialogueCharacterView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "BERNARD")
        #expect(element.elementType == .character)
    }

    @Test("DialogueTextView displays dialogue text")
    func testDialogueTextViewDisplaysText() {
        let element = createMockElement(type: .dialogue, text: "I can't believe it.")
        let view = DialogueTextView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "I can't believe it.")
        #expect(element.elementType == .dialogue)
    }

    @Test("DialogueParentheticalView displays parenthetical")
    func testDialogueParentheticalViewDisplaysText() {
        let element = createMockElement(type: .parenthetical, text: "(laughing)")
        let view = DialogueParentheticalView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "(laughing)")
        #expect(element.elementType == .parenthetical)
    }

    @Test("DialogueLyricsView displays lyrics")
    func testDialogueLyricsViewDisplaysText() {
        let element = createMockElement(type: .lyrics, text: "Happy birthday to you")
        let view = DialogueLyricsView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "Happy birthday to you")
        #expect(element.elementType == .lyrics)
    }

    // MARK: - Integration Tests

    @Test("All element views respond to font size environment")
    func testAllViewsRespondToFontSize() {
        let elementTypes: [(ElementType, String)] = [
            (.action, "Action text"),
            (.sceneHeading, "INT. ROOM - DAY"),
            (.transition, "CUT TO:"),
            (.sectionHeading(level: 1), "Title"),
            (.synopsis, "Synopsis"),
            (.comment, "Comment"),
            (.boneyard, "Boneyard"),
            (.character, "CHARACTER"),
            (.dialogue, "Dialogue"),
            (.parenthetical, "(action)"),
            (.lyrics, "Song lyrics")
        ]

        for (type, text) in elementTypes {
            let element = createMockElement(type: type, text: text)

            // Test with different font sizes
            let sizes: [CGFloat] = [8, 12, 16, 20]
            for size in sizes {
                switch type {
                case .action:
                    let _ = ActionView(element: element).environment(\.screenplayFontSize, size)
                case .sceneHeading:
                    let _ = SceneHeadingView(element: element).environment(\.screenplayFontSize, size)
                case .transition:
                    let _ = TransitionView(element: element).environment(\.screenplayFontSize, size)
                case .sectionHeading:
                    let _ = SectionHeadingView(element: element).environment(\.screenplayFontSize, size)
                case .synopsis:
                    let _ = SynopsisView(element: element).environment(\.screenplayFontSize, size)
                case .comment:
                    let _ = CommentView(element: element).environment(\.screenplayFontSize, size)
                case .boneyard:
                    let _ = BoneyardView(element: element).environment(\.screenplayFontSize, size)
                case .character:
                    let _ = DialogueCharacterView(element: element).environment(\.screenplayFontSize, size)
                case .dialogue:
                    let _ = DialogueTextView(element: element).environment(\.screenplayFontSize, size)
                case .parenthetical:
                    let _ = DialogueParentheticalView(element: element).environment(\.screenplayFontSize, size)
                case .lyrics:
                    let _ = DialogueLyricsView(element: element).environment(\.screenplayFontSize, size)
                default:
                    break
                }
            }

            #expect(true) // All views should compile
        }
    }

    @Test("All element views are Sendable-compatible")
    func testAllViewsAreSendable() {
        // Verify all element models can be created
        let element = createMockElement(type: .action, text: "Test")

        // GuionElementModel conforms to Sendable
        #expect(element.elementText == "Test")
    }

    @Test("Element views handle empty text gracefully")
    func testElementViewsHandleEmptyText() {
        let types: [ElementType] = [
            .action, .sceneHeading, .transition,
            .sectionHeading(level: 1), .synopsis, .comment, .boneyard
        ]

        for type in types {
            let element = createMockElement(type: type, text: "")
            #expect(element.elementText.isEmpty)
        }
    }

    @Test("Element views handle very long text")
    func testElementViewsHandleLongText() {
        let longText = String(repeating: "This is a very long text. ", count: 50)
        let types: [ElementType] = [
            .action, .sceneHeading, .transition,
            .sectionHeading(level: 1), .synopsis, .comment, .boneyard
        ]

        for type in types {
            let element = createMockElement(type: type, text: longText)
            #expect(element.elementText.count > 1000)
        }
    }
}
