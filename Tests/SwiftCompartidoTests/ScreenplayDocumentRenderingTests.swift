//
//  ScreenplayDocumentRenderingTests.swift
//  SwiftCompartido
//
//  End-to-end tests for complete screenplay document rendering
//  Tests full documents against expected industry-standard formatting
//

import Foundation
import Testing
import SwiftUI
import SwiftData
@testable import SwiftCompartido

/// Test suite for validating complete screenplay document rendering
///
/// This suite tests entire screenplay documents to ensure:
/// - Correct element ordering and sequence
/// - Proper spacing between different element types
/// - Consistent formatting across a full script
/// - Dialogue blocks (character + parenthetical + dialogue) render correctly
/// - Scene sequences maintain proper structure
///
@MainActor
struct ScreenplayDocumentRenderingTests {

    // MARK: - Test Helpers

    /// Create a test model context
    private func createTestContext() -> ModelContext {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TypedDataStorage.self
        ])
        let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    /// Create a standard dialogue block (character + dialogue)
    private func createDialogueBlock(character: String, dialogue: String) -> String {
        return "\(character)\n\(dialogue)\n"
    }

    /// Create a dialogue block with parenthetical
    private func createDialogueWithParenthetical(character: String, parenthetical: String, dialogue: String) -> String {
        return "\(character)\n\(parenthetical)\n\(dialogue)\n"
    }

    // MARK: - Simple Scene Tests

    @Test("Single scene with action renders correctly")
    func testSingleSceneWithAction() async throws {
        let fountainText = """
        INT. OFFICE - DAY

        Bernard enters the room.
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let context = createTestContext()
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)

        // Should have 2 elements: scene heading + action
        #expect(document.sortedElements.count == 2)

        let elements = document.sortedElements

        // First element: scene heading
        #expect(elements[0].elementType == .sceneHeading)
        #expect(elements[0].elementText == "INT. OFFICE - DAY")

        // Second element: action
        #expect(elements[1].elementType == .action)
        #expect(elements[1].elementText == "Bernard enters the room.")
    }

    @Test("Scene with dialogue block renders correctly")
    func testSceneWithDialogue() async throws {
        let fountainText = """
        INT. STEAM ROOM - DAY

        Bernard and Killian sit in a steam room.

        BERNARD
        I can't believe it.
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let context = createTestContext()
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)

        let elements = document.sortedElements

        // Should have 4 elements: scene heading + action + character + dialogue
        #expect(elements.count == 4)

        // Scene heading
        #expect(elements[0].elementType == .sceneHeading)

        // Action
        #expect(elements[1].elementType == .action)

        // Character name
        #expect(elements[2].elementType == .character)
        #expect(elements[2].elementText == "BERNARD")

        // Dialogue
        #expect(elements[3].elementType == .dialogue)
        #expect(elements[3].elementText == "I can't believe it.")
    }

    @Test("Dialogue with parenthetical renders correctly")
    func testDialogueWithParenthetical() async throws {
        let fountainText = """
        INT. ROOM - DAY

        BERNARD
        (laughing)
        That's incredible!
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let context = createTestContext()
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)

        let elements = document.sortedElements

        // Should have 4 elements: scene heading + character + parenthetical + dialogue
        #expect(elements.count == 4)

        // Character name
        #expect(elements[1].elementType == .character)

        // Parenthetical (should be before dialogue)
        #expect(elements[2].elementType == .parenthetical)
        #expect(elements[2].elementText == "(laughing)")

        // Dialogue
        #expect(elements[3].elementType == .dialogue)
        #expect(elements[3].elementText == "That's incredible!")
    }

    // MARK: - Multi-Scene Tests

    @Test("Multiple scenes maintain correct sequence")
    func testMultipleScenes() async throws {
        let fountainText = """
        INT. OFFICE - DAY

        Bernard works at his desk.

        INT. HALLWAY - DAY

        Bernard walks down the hall.

        EXT. PARKING LOT - DAY

        Bernard gets in his car.
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let context = createTestContext()
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)

        let elements = document.sortedElements

        // Should have 6 elements: 3 scene headings + 3 actions
        #expect(elements.count == 6)

        // First scene
        #expect(elements[0].elementType == .sceneHeading)
        #expect(elements[0].elementText.contains("OFFICE"))
        #expect(elements[1].elementType == .action)

        // Second scene
        #expect(elements[2].elementType == .sceneHeading)
        #expect(elements[2].elementText.contains("HALLWAY"))
        #expect(elements[3].elementType == .action)

        // Third scene
        #expect(elements[4].elementType == .sceneHeading)
        #expect(elements[4].elementText.contains("PARKING LOT"))
        #expect(elements[5].elementType == .action)
    }

    @Test("Multiple dialogue blocks in sequence maintain order")
    func testMultipleDialogueBlocks() async throws {
        let fountainText = """
        INT. OFFICE - DAY

        BERNARD
        Hello.

        KILLIAN
        Hi there.

        BERNARD
        How are you?
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let context = createTestContext()
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)

        let elements = document.sortedElements

        // Should have 7 elements: scene heading + 3 dialogue blocks (character + dialogue each)
        #expect(elements.count == 7)

        // Scene heading
        #expect(elements[0].elementType == .sceneHeading)

        // First dialogue block
        #expect(elements[1].elementType == .character)
        #expect(elements[1].elementText == "BERNARD")
        #expect(elements[2].elementType == .dialogue)
        #expect(elements[2].elementText == "Hello.")

        // Second dialogue block
        #expect(elements[3].elementType == .character)
        #expect(elements[3].elementText == "KILLIAN")
        #expect(elements[4].elementType == .dialogue)
        #expect(elements[4].elementText == "Hi there.")

        // Third dialogue block
        #expect(elements[5].elementType == .character)
        #expect(elements[5].elementText == "BERNARD")
        #expect(elements[6].elementType == .dialogue)
        #expect(elements[6].elementText == "How are you?")
    }

    // MARK: - Complex Document Tests

    @Test("Complete scene with mixed elements renders correctly")
    func testComplexScene() async throws {
        let fountainText = """
        INT. STEAM ROOM - DAY

        Bernard and Killian sit in a steam room.

        BERNARD
        (sweating)
        I can't believe it.

        Killian nods.

        KILLIAN
        Believe it.

        > This is a note about the scene.

        Bernard stands up.
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let context = createTestContext()
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)

        let elements = document.sortedElements

        // Verify scene heading is first
        #expect(elements[0].elementType == .sceneHeading)

        // Find all element types present
        let elementTypes = Set(elements.map { $0.elementType })

        // Should contain scene heading, action, character, dialogue, parenthetical
        #expect(elementTypes.contains(.sceneHeading))
        #expect(elementTypes.contains(.action))
        #expect(elementTypes.contains(.character))
        #expect(elementTypes.contains(.dialogue))
        #expect(elementTypes.contains(.parenthetical))
    }

    @Test("Transitions render in correct position")
    func testTransitions() async throws {
        let fountainText = """
        INT. OFFICE - DAY

        Bernard works at his desk.

        CUT TO:

        INT. HALLWAY - DAY

        Bernard walks down the hall.

        FADE OUT.
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let context = createTestContext()
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)

        let elements = document.sortedElements

        // Find transitions
        let transitions = elements.filter { $0.elementType == .transition }
        #expect(transitions.count == 2)

        // First transition should be "CUT TO:"
        #expect(transitions[0].elementText.contains("CUT TO"))

        // Second transition should be "FADE OUT."
        #expect(transitions[1].elementText.contains("FADE OUT"))

        // Transitions should be between scenes
        let transitionIndices = elements.enumerated()
            .filter { $0.element.elementType == .transition }
            .map { $0.offset }

        // First transition should come after first scene's action
        #expect(transitionIndices[0] > 0)

        // Second transition should be at or near the end
        #expect(transitionIndices[1] >= elements.count - 2)
    }

    // MARK: - Document Order Tests

    @Test("Element ordering matches source screenplay order")
    func testElementOrdering() async throws {
        let fountainText = """
        INT. ROOM - DAY

        First action line.

        BERNARD
        First dialogue.

        Second action line.

        KILLIAN
        Second dialogue.

        Third action line.
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let context = createTestContext()
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)

        let elements = document.sortedElements

        // Build expected sequence
        let expectedSequence: [ElementType] = [
            .sceneHeading,
            .action,
            .character,
            .dialogue,
            .action,
            .character,
            .dialogue,
            .action
        ]

        #expect(elements.count == expectedSequence.count)

        // Verify each element matches expected type in order
        for (index, expected) in expectedSequence.enumerated() {
            #expect(elements[index].elementType == expected,
                    "Element at index \(index) should be \(expected), got \(elements[index].elementType)")
        }
    }

    @Test("Chapter sections maintain element ordering within chapters")
    func testChapterSectionOrdering() async throws {
        let fountainText = """
        # ACT I

        INT. OFFICE - DAY

        Bernard at his desk.

        ## CHAPTER 1

        INT. HALLWAY - DAY

        Bernard in the hall.

        ## CHAPTER 2

        EXT. PARK - DAY

        Bernard in the park.
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let context = createTestContext()
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)

        let elements = document.sortedElements

        // All elements should have sequential orderIndex within their chapter
        var lastChapterIndex: Int? = nil
        var lastOrderIndex: Int? = nil

        for element in elements {
            if let lastChapter = lastChapterIndex,
               element.chapterIndex == lastChapter {
                // Same chapter - orderIndex should increment
                if let lastOrder = lastOrderIndex {
                    #expect(element.orderIndex > lastOrder,
                            "orderIndex should increment within same chapter")
                }
            }

            lastChapterIndex = element.chapterIndex
            lastOrderIndex = element.orderIndex
        }
    }

    // MARK: - Special Element Tests

    @Test("Section headings create chapter boundaries")
    func testSectionHeadingsCreateChapters() async throws {
        let fountainText = """
        ## ACT I

        INT. ROOM - DAY

        First scene.

        ## ACT II

        INT. HALLWAY - DAY

        Second scene.
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let context = createTestContext()
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)

        let elements = document.sortedElements

        // Find section headings
        let sectionHeadings = elements.filter {
            if case .sectionHeading = $0.elementType {
                return true
            }
            return false
        }

        #expect(sectionHeadings.count == 2)

        // Elements after first section heading should have chapterIndex > 0
        let chaptersUsed = Set(elements.map { $0.chapterIndex })
        #expect(chaptersUsed.count > 1, "Multiple chapters should be created")
    }

    @Test("Empty lines between elements are handled correctly")
    func testEmptyLineHandling() async throws {
        let fountainText = """
        INT. ROOM - DAY



        Bernard enters.


        BERNARD
        Hello.
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let context = createTestContext()
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)

        let elements = document.sortedElements

        // Empty lines should not create empty elements
        for element in elements {
            #expect(!element.elementText.isEmpty, "Elements should not have empty text")
        }

        // Should have: scene heading + action + character + dialogue
        #expect(elements.count == 4)
    }

    // MARK: - Rendering Consistency Tests

    @Test("DocumentModelActor returns elements in correct order")
    func testDocumentModelActorElementOrder() async throws {
        let fountainText = """
        INT. OFFICE - DAY

        Bernard works.

        BERNARD
        Hello.

        Killian enters.

        KILLIAN
        Hi.
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let context = createTestContext()
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)

        context.insert(document)
        try context.save()

        // Create actor and fetch elements
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TypedDataStorage.self
        ])
        let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let actor = DocumentModelActor(modelContainer: container)

        // Parse and save document through actor
        let documentID = try await actor.parseAndSaveDocument(from: fountainText)

        // Get elements through actor
        let actorElements = try await actor.getElements(for: documentID)

        // Elements should be in correct order
        let expectedSequence: [ElementType] = [
            .sceneHeading,
            .action,
            .character,
            .dialogue,
            .action,
            .character,
            .dialogue
        ]

        #expect(actorElements.count == expectedSequence.count)

        for (index, expected) in expectedSequence.enumerated() {
            #expect(actorElements[index].elementType == expected,
                    "Actor element at index \(index) should be \(expected)")
        }
    }

    @Test("Large screenplay maintains element order")
    func testLargeScreenplayOrdering() async throws {
        // Create a screenplay with 100+ elements
        var fountainText = "INT. OFFICE - DAY\n\n"

        for i in 1...50 {
            fountainText += "Action line \(i).\n\n"
            fountainText += "CHARACTER \(i)\n"
            fountainText += "Dialogue line \(i).\n\n"
        }

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let context = createTestContext()
        let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)

        let elements = document.sortedElements

        // Should have 1 scene heading + 50 action lines + 50 character + 50 dialogue = 151 elements
        #expect(elements.count >= 150)

        // Verify ordering: action -> character -> dialogue pattern repeats
        var actionCount = 0
        var characterCount = 0
        var dialogueCount = 0

        for element in elements {
            switch element.elementType {
            case .action:
                actionCount += 1
            case .character:
                characterCount += 1
            case .dialogue:
                dialogueCount += 1
            default:
                break
            }
        }

        #expect(actionCount == 50)
        #expect(characterCount == 50)
        #expect(dialogueCount == 50)
    }
}
