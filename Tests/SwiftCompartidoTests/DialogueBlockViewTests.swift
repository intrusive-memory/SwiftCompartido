//
//  DialogueBlockViewTests.swift
//  SwiftCompartido Tests
//
//  Tests for DialogueBlockView component and dialogue block grouping
//

import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import SwiftCompartido

@Suite("DialogueBlockView Tests")
@MainActor
struct DialogueBlockViewTests {

  // MARK: - Helper Methods

  private func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
      for: GuionElementModel.self,
      configurations: config
    )
  }

  private func makeElement(
    in context: ModelContext,
    text: String,
    type: ElementType,
    order: Int
  ) -> GuionElementModel {
    let element = GuionElementModel(
      elementText: text,
      elementType: type,
      orderIndex: order
    )
    context.insert(element)
    return element
  }

  // MARK: - DialogueBlock Tests

  @Test("DialogueBlock initializes with elements")
  func testDialogueBlockInitialization() {
    let container = try! makeTestContainer()
    let element = makeElement(in: container.mainContext, text: "Test", type: .dialogue, order: 0)

    let block = DialogueBlock(elements: [element], isDialogueBlock: true)

    #expect(block.elements.count == 1)
    #expect(block.isDialogueBlock == true)
    #expect(block.elements.first?.elementText == "Test")
  }

  @Test("DialogueBlock handles multiple elements")
  func testDialogueBlockMultipleElements() {
    let container = try! makeTestContainer()
    let char = makeElement(in: container.mainContext, text: "JOHN", type: .character, order: 0)
    let dialogue = makeElement(in: container.mainContext, text: "Hello", type: .dialogue, order: 1)

    let block = DialogueBlock(elements: [char, dialogue], isDialogueBlock: true)

    #expect(block.elements.count == 2)
    #expect(block.isDialogueBlock == true)
  }

  @Test("DialogueBlock handles non-dialogue elements")
  func testDialogueBlockNonDialogue() {
    let container = try! makeTestContainer()
    let action = makeElement(
      in: container.mainContext, text: "John enters.", type: .action, order: 0)

    let block = DialogueBlock(elements: [action], isDialogueBlock: false)

    #expect(block.elements.count == 1)
    #expect(block.isDialogueBlock == false)
  }

  // MARK: - groupDialogueBlocks() Tests

  @Test("groupDialogueBlocks groups character with dialogue")
  func testGroupDialogueBlocksBasicDialogue() {
    let container = try! makeTestContainer()
    let char = makeElement(in: container.mainContext, text: "JOHN", type: .character, order: 0)
    let dialogue = makeElement(in: container.mainContext, text: "Hello", type: .dialogue, order: 1)

    let blocks = groupDialogueBlocks(elements: [char, dialogue])

    #expect(blocks.count == 1)
    #expect(blocks[0].isDialogueBlock == true)
    #expect(blocks[0].elements.count == 2)
    #expect(blocks[0].elements[0].elementType == .character)
    #expect(blocks[0].elements[1].elementType == .dialogue)
  }

  @Test("groupDialogueBlocks groups character with parenthetical and dialogue")
  func testGroupDialogueBlocksWithParenthetical() {
    let container = try! makeTestContainer()
    let char = makeElement(in: container.mainContext, text: "JOHN", type: .character, order: 0)
    let paren = makeElement(
      in: container.mainContext, text: "(smiling)", type: .parenthetical, order: 1)
    let dialogue = makeElement(in: container.mainContext, text: "Hello", type: .dialogue, order: 2)

    let blocks = groupDialogueBlocks(elements: [char, paren, dialogue])

    #expect(blocks.count == 1)
    #expect(blocks[0].isDialogueBlock == true)
    #expect(blocks[0].elements.count == 3)
    #expect(blocks[0].elements[0].elementType == .character)
    #expect(blocks[0].elements[1].elementType == .parenthetical)
    #expect(blocks[0].elements[2].elementType == .dialogue)
  }

  @Test("groupDialogueBlocks groups character with lyrics")
  func testGroupDialogueBlocksWithLyrics() {
    let container = try! makeTestContainer()
    let char = makeElement(in: container.mainContext, text: "JOHN", type: .character, order: 0)
    let lyrics = makeElement(in: container.mainContext, text: "~La la la", type: .lyrics, order: 1)

    let blocks = groupDialogueBlocks(elements: [char, lyrics])

    #expect(blocks.count == 1)
    #expect(blocks[0].isDialogueBlock == true)
    #expect(blocks[0].elements.count == 2)
    #expect(blocks[0].elements[1].elementType == .lyrics)
  }

  @Test("groupDialogueBlocks separates non-dialogue elements")
  func testGroupDialogueBlocksSeparatesNonDialogue() {
    let container = try! makeTestContainer()
    let action1 = makeElement(
      in: container.mainContext, text: "John enters.", type: .action, order: 0)
    let char = makeElement(in: container.mainContext, text: "JOHN", type: .character, order: 1)
    let dialogue = makeElement(in: container.mainContext, text: "Hello", type: .dialogue, order: 2)
    let action2 = makeElement(
      in: container.mainContext, text: "John exits.", type: .action, order: 3)

    let blocks = groupDialogueBlocks(elements: [action1, char, dialogue, action2])

    #expect(blocks.count == 3)
    #expect(blocks[0].isDialogueBlock == false)  // action1
    #expect(blocks[1].isDialogueBlock == true)  // char + dialogue
    #expect(blocks[2].isDialogueBlock == false)  // action2
  }

  @Test("groupDialogueBlocks handles multiple dialogue blocks")
  func testGroupDialogueBlocksMultipleDialogues() {
    let container = try! makeTestContainer()
    let char1 = makeElement(in: container.mainContext, text: "JOHN", type: .character, order: 0)
    let dialogue1 = makeElement(in: container.mainContext, text: "Hello", type: .dialogue, order: 1)
    let char2 = makeElement(in: container.mainContext, text: "MARY", type: .character, order: 2)
    let dialogue2 = makeElement(in: container.mainContext, text: "Hi", type: .dialogue, order: 3)

    let blocks = groupDialogueBlocks(elements: [char1, dialogue1, char2, dialogue2])

    #expect(blocks.count == 2)
    #expect(blocks[0].isDialogueBlock == true)  // JOHN's dialogue
    #expect(blocks[0].elements[0].elementText == "JOHN")
    #expect(blocks[1].isDialogueBlock == true)  // MARY's dialogue
    #expect(blocks[1].elements[0].elementText == "MARY")
  }

  @Test("groupDialogueBlocks handles empty list")
  func testGroupDialogueBlocksEmpty() {
    let blocks = groupDialogueBlocks(elements: [])

    #expect(blocks.isEmpty)
  }

  @Test("groupDialogueBlocks handles single action element")
  func testGroupDialogueBlocksSingleAction() {
    let container = try! makeTestContainer()
    let action = makeElement(
      in: container.mainContext, text: "John enters.", type: .action, order: 0)

    let blocks = groupDialogueBlocks(elements: [action])

    #expect(blocks.count == 1)
    #expect(blocks[0].isDialogueBlock == false)
    #expect(blocks[0].elements.count == 1)
  }

  @Test("groupDialogueBlocks handles orphaned parenthetical")
  func testGroupDialogueBlocksOrphanedParenthetical() {
    let container = try! makeTestContainer()
    let paren = makeElement(
      in: container.mainContext, text: "(confused)", type: .parenthetical, order: 0)

    let blocks = groupDialogueBlocks(elements: [paren])

    // Orphaned parenthetical is treated as standalone
    #expect(blocks.count == 1)
    #expect(blocks[0].isDialogueBlock == false)
    #expect(blocks[0].elements.count == 1)
  }

  @Test("groupDialogueBlocks handles orphaned dialogue")
  func testGroupDialogueBlocksOrphanedDialogue() {
    let container = try! makeTestContainer()
    let dialogue = makeElement(in: container.mainContext, text: "Hello", type: .dialogue, order: 0)

    let blocks = groupDialogueBlocks(elements: [dialogue])

    // Orphaned dialogue is treated as standalone
    #expect(blocks.count == 1)
    #expect(blocks[0].isDialogueBlock == false)
    #expect(blocks[0].elements.count == 1)
  }

  @Test("groupDialogueBlocks handles scene heading separator")
  func testGroupDialogueBlocksSceneHeadingSeparator() {
    let container = try! makeTestContainer()
    let char1 = makeElement(in: container.mainContext, text: "JOHN", type: .character, order: 0)
    let dialogue1 = makeElement(in: container.mainContext, text: "Hello", type: .dialogue, order: 1)
    let scene = makeElement(
      in: container.mainContext, text: "INT. OFFICE - DAY", type: .sceneHeading, order: 2)
    let char2 = makeElement(in: container.mainContext, text: "MARY", type: .character, order: 3)
    let dialogue2 = makeElement(in: container.mainContext, text: "Hi", type: .dialogue, order: 4)

    let blocks = groupDialogueBlocks(elements: [char1, dialogue1, scene, char2, dialogue2])

    #expect(blocks.count == 3)
    #expect(blocks[0].isDialogueBlock == true)  // JOHN's dialogue
    #expect(blocks[1].isDialogueBlock == false)  // Scene heading
    #expect(blocks[2].isDialogueBlock == true)  // MARY's dialogue
  }

  @Test("groupDialogueBlocks handles transition separator")
  func testGroupDialogueBlocksTransitionSeparator() {
    let container = try! makeTestContainer()
    let char1 = makeElement(in: container.mainContext, text: "JOHN", type: .character, order: 0)
    let dialogue1 = makeElement(
      in: container.mainContext, text: "Goodbye", type: .dialogue, order: 1)
    let transition = makeElement(
      in: container.mainContext, text: "CUT TO:", type: .transition, order: 2)
    let char2 = makeElement(in: container.mainContext, text: "MARY", type: .character, order: 3)
    let dialogue2 = makeElement(in: container.mainContext, text: "Hello", type: .dialogue, order: 4)

    let blocks = groupDialogueBlocks(elements: [char1, dialogue1, transition, char2, dialogue2])

    #expect(blocks.count == 3)
    #expect(blocks[0].isDialogueBlock == true)  // JOHN's dialogue
    #expect(blocks[1].isDialogueBlock == false)  // Transition
    #expect(blocks[2].isDialogueBlock == true)  // MARY's dialogue
  }

  @Test("groupDialogueBlocks handles multiple parentheticals")
  func testGroupDialogueBlocksMultipleParentheticals() {
    let container = try! makeTestContainer()
    let char = makeElement(in: container.mainContext, text: "JOHN", type: .character, order: 0)
    let paren1 = makeElement(
      in: container.mainContext, text: "(hesitant)", type: .parenthetical, order: 1)
    let dialogue1 = makeElement(
      in: container.mainContext, text: "Well...", type: .dialogue, order: 2)
    let paren2 = makeElement(
      in: container.mainContext, text: "(smiling)", type: .parenthetical, order: 3)
    let dialogue2 = makeElement(in: container.mainContext, text: "Okay!", type: .dialogue, order: 4)

    let blocks = groupDialogueBlocks(elements: [char, paren1, dialogue1, paren2, dialogue2])

    #expect(blocks.count == 1)
    #expect(blocks[0].isDialogueBlock == true)
    #expect(blocks[0].elements.count == 5)
  }

  // MARK: - DialogueBlockView Rendering Tests

  @Test("DialogueBlockView initializes with dialogue block")
  func testDialogueBlockViewInitialization() {
    let container = try! makeTestContainer()
    let char = makeElement(in: container.mainContext, text: "JOHN", type: .character, order: 0)
    let dialogue = makeElement(in: container.mainContext, text: "Hello", type: .dialogue, order: 1)

    let block = DialogueBlock(elements: [char, dialogue], isDialogueBlock: true)
    _ = DialogueBlockView(block: block)
      .environment(\.screenplayFontSize, 12)

    #expect(block.isDialogueBlock == true)
    #expect(block.elements.count == 2)
  }

  @Test("DialogueBlockView initializes with non-dialogue block")
  func testDialogueBlockViewNonDialogue() {
    let container = try! makeTestContainer()
    let action = makeElement(
      in: container.mainContext, text: "John enters.", type: .action, order: 0)

    let block = DialogueBlock(elements: [action], isDialogueBlock: false)
    _ = DialogueBlockView(block: block)
      .environment(\.screenplayFontSize, 12)

    #expect(block.isDialogueBlock == false)
    #expect(block.elements.count == 1)
  }

  @Test("DialogueBlockView respects font size environment")
  func testDialogueBlockViewFontSize() {
    let container = try! makeTestContainer()
    let char = makeElement(in: container.mainContext, text: "JOHN", type: .character, order: 0)
    let dialogue = makeElement(in: container.mainContext, text: "Hello", type: .dialogue, order: 1)

    let block = DialogueBlock(elements: [char, dialogue], isDialogueBlock: true)
    let view1 = DialogueBlockView(block: block)
      .environment(\.screenplayFontSize, 10)

    let view2 = DialogueBlockView(block: block)
      .environment(\.screenplayFontSize, 18)

    #expect(block.elements.count == 2)
  }

  @Test("DialogueBlockView handles complex dialogue block")
  func testDialogueBlockViewComplexBlock() {
    let container = try! makeTestContainer()
    let char = makeElement(in: container.mainContext, text: "JOHN", type: .character, order: 0)
    let paren1 = makeElement(
      in: container.mainContext, text: "(hesitant)", type: .parenthetical, order: 1)
    let dialogue1 = makeElement(
      in: container.mainContext, text: "Well...", type: .dialogue, order: 2)
    let paren2 = makeElement(
      in: container.mainContext, text: "(smiling)", type: .parenthetical, order: 3)
    let dialogue2 = makeElement(in: container.mainContext, text: "Okay!", type: .dialogue, order: 4)

    let block = DialogueBlock(
      elements: [char, paren1, dialogue1, paren2, dialogue2], isDialogueBlock: true)
    _ = DialogueBlockView(block: block)
      .environment(\.screenplayFontSize, 12)

    #expect(block.elements.count == 5)
    #expect(block.isDialogueBlock == true)
  }

  @Test("DialogueBlockView handles block with lyrics")
  func testDialogueBlockViewWithLyrics() {
    let container = try! makeTestContainer()
    let char = makeElement(in: container.mainContext, text: "JOHN", type: .character, order: 0)
    let lyrics = makeElement(in: container.mainContext, text: "~La la la", type: .lyrics, order: 1)

    let block = DialogueBlock(elements: [char, lyrics], isDialogueBlock: true)
    _ = DialogueBlockView(block: block)
      .environment(\.screenplayFontSize, 12)

    #expect(block.elements.count == 2)
    #expect(block.elements[1].elementType == .lyrics)
  }

  @Test("DialogueBlockView handles empty block")
  func testDialogueBlockViewEmptyBlock() {
    let block = DialogueBlock(elements: [], isDialogueBlock: false)
    _ = DialogueBlockView(block: block)
      .environment(\.screenplayFontSize, 12)

    #expect(block.elements.isEmpty)
  }

  // MARK: - Integration Tests

  @Test("Full dialogue scene grouping and rendering")
  func testFullDialogueScene() {
    let container = try! makeTestContainer()

    let scene = makeElement(
      in: container.mainContext, text: "INT. OFFICE - DAY", type: .sceneHeading, order: 0)
    let action1 = makeElement(
      in: container.mainContext, text: "John enters.", type: .action, order: 1)
    let char1 = makeElement(in: container.mainContext, text: "JOHN", type: .character, order: 2)
    let dialogue1 = makeElement(
      in: container.mainContext, text: "Hello everyone.", type: .dialogue, order: 3)
    let action2 = makeElement(
      in: container.mainContext, text: "Mary looks up.", type: .action, order: 4)
    let char2 = makeElement(in: container.mainContext, text: "MARY", type: .character, order: 5)
    let paren = makeElement(
      in: container.mainContext, text: "(smiling)", type: .parenthetical, order: 6)
    let dialogue2 = makeElement(
      in: container.mainContext, text: "Hi John!", type: .dialogue, order: 7)

    let elements = [scene, action1, char1, dialogue1, action2, char2, paren, dialogue2]
    let blocks = groupDialogueBlocks(elements: elements)

    #expect(blocks.count == 5)
    #expect(blocks[0].isDialogueBlock == false)  // Scene heading
    #expect(blocks[1].isDialogueBlock == false)  // Action1
    #expect(blocks[2].isDialogueBlock == true)  // JOHN's dialogue
    #expect(blocks[3].isDialogueBlock == false)  // Action2
    #expect(blocks[4].isDialogueBlock == true)  // MARY's dialogue with parenthetical

    // Verify MARY's dialogue block structure
    #expect(blocks[4].elements.count == 3)
    #expect(blocks[4].elements[0].elementType == .character)
    #expect(blocks[4].elements[1].elementType == .parenthetical)
    #expect(blocks[4].elements[2].elementType == .dialogue)
  }
}
