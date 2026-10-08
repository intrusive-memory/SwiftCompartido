//
//  CharacterWindowingTests.swift
//  SwiftCompartidoTests
//
//  Unit tests for CP-P5 window merging logic (pure functions).
//
//  These tests verify the edge cases in the window merging algorithm
//  without requiring a SwiftData store.
//

import Foundation
import Testing

@testable import SwiftCompartido

@Suite("Character Windowing Unit Tests")
struct CharacterWindowingTests {

  // MARK: - Block grouping tests

  @Test("Dialogue block groups character cue with its dialogue and parentheticals")
  func dialogueBlockGrouping() {
    let elements = [
      makeElement(type: .character, text: "ALICE", speaker: "ALICE"),
      makeElement(type: .parenthetical, text: "(quietly)", speaker: "ALICE"),
      makeElement(type: .dialogue, text: "Hello.", speaker: "ALICE"),
    ]

    let blocks = CharacterWindowing.blocks(from: elements)

    #expect(blocks.count == 1)
    #expect(blocks[0].speaker == "ALICE")
    #expect(blocks[0].isDialogueBlock == true)
    #expect(blocks[0].elements.count == 3)
  }

  @Test("Action elements are separate blocks")
  func actionBlockSeparation() {
    let elements = [
      makeElement(type: .action, text: "Alice enters."),
      makeElement(type: .action, text: "She sits down."),
    ]

    let blocks = CharacterWindowing.blocks(from: elements)

    #expect(blocks.count == 2)
    #expect(blocks[0].speaker == nil)
    #expect(blocks[0].isDialogueBlock == false)
    #expect(blocks[1].speaker == nil)
    #expect(blocks[1].isDialogueBlock == false)
  }

  @Test("Action closes open dialogue block")
  func actionClosesDialogue() {
    let elements = [
      makeElement(type: .character, text: "ALICE", speaker: "ALICE"),
      makeElement(type: .dialogue, text: "Hello.", speaker: "ALICE"),
      makeElement(type: .action, text: "She waves."),
      makeElement(type: .character, text: "BOB", speaker: "BOB"),
      makeElement(type: .dialogue, text: "Hi.", speaker: "BOB"),
    ]

    let blocks = CharacterWindowing.blocks(from: elements)

    #expect(blocks.count == 3)
    #expect(blocks[0].speaker == "ALICE")
    #expect(blocks[1].speaker == nil)  // Action
    #expect(blocks[2].speaker == "BOB")
  }

  @Test("Scene headings are skipped")
  func sceneHeadingsSkipped() {
    let elements = [
      makeElement(type: .sceneHeading, text: "INT. ROOM - DAY"),
      makeElement(type: .character, text: "ALICE", speaker: "ALICE"),
      makeElement(type: .dialogue, text: "Hello.", speaker: "ALICE"),
    ]

    let blocks = CharacterWindowing.blocks(from: elements)

    // Scene heading should not appear as a block
    #expect(blocks.count == 1)
    #expect(blocks[0].speaker == "ALICE")
  }

  @Test("Comments and boneyard don't close dialogue blocks")
  func commentsPreserveDialogue() {
    let elements = [
      makeElement(type: .character, text: "ALICE", speaker: "ALICE"),
      makeElement(type: .comment, text: "Note to self"),
      makeElement(type: .dialogue, text: "Hello.", speaker: "ALICE"),
      makeElement(type: .boneyard, text: "Cut content"),
      makeElement(type: .parenthetical, text: "(smiling)", speaker: "ALICE"),
    ]

    let blocks = CharacterWindowing.blocks(from: elements)

    // Should still be one dialogue block
    #expect(blocks.count == 1)
    #expect(blocks[0].speaker == "ALICE")
    #expect(blocks[0].elements.count == 3)  // Cue, dialogue, parenthetical
  }

  @Test("Dual dialogue creates separate blocks")
  func dualDialogueSeparateBlocks() {
    let elements = [
      makeElement(type: .character, text: "ALICE", speaker: "ALICE"),
      makeElement(type: .dialogue, text: "Line 1.", speaker: "ALICE"),
      makeElement(type: .character, text: "BOB", speaker: "BOB"),
      makeElement(type: .dialogue, text: "Line 2.", speaker: "BOB"),
    ]

    let blocks = CharacterWindowing.blocks(from: elements)

    #expect(blocks.count == 2)
    #expect(blocks[0].speaker == "ALICE")
    #expect(blocks[1].speaker == "BOB")
  }

  @Test("Orphaned dialogue creates new block")
  func orphanedDialogueBlock() {
    let elements = [
      makeElement(type: .dialogue, text: "Orphan line.", speaker: "ALICE"),
    ]

    let blocks = CharacterWindowing.blocks(from: elements)

    #expect(blocks.count == 1)
    #expect(blocks[0].speaker == "ALICE")
    #expect(blocks[0].isDialogueBlock == true)
  }

  // MARK: - Line identification tests

  @Test("Block is a line when it has dialogue and matches character")
  func lineIdentification() {
    let block = CharacterWindowing.Block(
      speaker: "ALICE",
      isDialogueBlock: true,
      elements: [
        makeElement(type: .character, text: "ALICE", speaker: "ALICE"),
        makeElement(type: .dialogue, text: "Hello.", speaker: "ALICE"),
      ]
    )

    #expect(CharacterWindowing.isLine(block, of: "ALICE") == true)
    #expect(CharacterWindowing.isLine(block, of: "BOB") == false)
  }

  @Test("Block with only parenthetical is not a line")
  func parentheticalOnlyNotLine() {
    let block = CharacterWindowing.Block(
      speaker: "ALICE",
      isDialogueBlock: true,
      elements: [
        makeElement(type: .character, text: "ALICE", speaker: "ALICE"),
        makeElement(type: .parenthetical, text: "(quietly)", speaker: "ALICE"),
      ]
    )

    #expect(CharacterWindowing.isLine(block, of: "ALICE") == false)
  }

  @Test("Action block is never a line")
  func actionBlockNotLine() {
    let block = CharacterWindowing.Block(
      speaker: nil,
      isDialogueBlock: false,
      elements: [
        makeElement(type: .action, text: "Action text.")
      ]
    )

    #expect(CharacterWindowing.isLine(block, of: "ALICE") == false)
  }

  // MARK: - Window merging tests

  @Test("Single line creates single window")
  func singleLineWindow() {
    let lineIndices = [3]
    let blockCount = 10
    let radius = 2

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    #expect(windows.count == 1)
    #expect(windows[0] == 1...5)  // 3-2 to 3+2
  }

  @Test("Two overlapping windows merge")
  func overlappingWindowsMerge() {
    let lineIndices = [2, 4]  // Windows: [0-4] and [2-6], overlap at 2-4
    let blockCount = 10
    let radius = 2

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    #expect(windows.count == 1)
    #expect(windows[0] == 0...6)
  }

  @Test("Two adjacent windows that touch but don't overlap stay separate")
  func adjacentWindowsSeparate() {
    let lineIndices = [1, 5]  // Windows: [0-3] and [3-7], touch at 3
    let blockCount = 10
    let radius = 2

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    // Windows that share exactly one block (index 3) should merge
    #expect(windows.count == 1)
    #expect(windows[0] == 0...7)
  }

  @Test("Two windows with gap stay separate")
  func separateWindowsWithGap() {
    let lineIndices = [1, 6]  // Windows: [0-3] and [4-8], gap between
    let blockCount = 10
    let radius = 2

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    #expect(windows.count == 2)
    #expect(windows[0] == 0...3)
    #expect(windows[1] == 4...8)
  }

  @Test("Window clipping at start boundary")
  func windowClippingAtStart() {
    let lineIndices = [1]
    let blockCount = 10
    let radius = 5

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    #expect(windows.count == 1)
    #expect(windows[0] == 0...6)  // Clipped at 0, not -4
  }

  @Test("Window clipping at end boundary")
  func windowClippingAtEnd() {
    let lineIndices = [8]
    let blockCount = 10
    let radius = 5

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    #expect(windows.count == 1)
    #expect(windows[0] == 3...9)  // Clipped at 9, not 13
  }

  @Test("Zero radius creates single-block windows")
  func zeroRadiusWindows() {
    let lineIndices = [2, 5, 8]
    let blockCount = 10
    let radius = 0

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    #expect(windows.count == 3)
    #expect(windows[0] == 2...2)
    #expect(windows[1] == 5...5)
    #expect(windows[2] == 8...8)
  }

  @Test("Duplicate line indices handled correctly")
  func duplicateLineIndices() {
    let lineIndices = [3, 3, 3]
    let blockCount = 10
    let radius = 1

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    #expect(windows.count == 1)
    #expect(windows[0] == 2...4)
  }

  @Test("Out of range indices filtered out")
  func outOfRangeIndicesFiltered() {
    let lineIndices = [-1, 3, 15]
    let blockCount = 10
    let radius = 1

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    #expect(windows.count == 1)
    #expect(windows[0] == 2...4)  // Only index 3 is valid
  }

  @Test("Unsorted line indices produce sorted windows")
  func unsortedIndicesSorted() {
    let lineIndices = [7, 2, 5]
    let blockCount = 10
    let radius = 0

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    #expect(windows.count == 3)
    #expect(windows[0] == 2...2)
    #expect(windows[1] == 5...5)
    #expect(windows[2] == 7...7)
  }

  @Test("Empty line indices produce empty windows")
  func emptyLineIndices() {
    let lineIndices: [Int] = []
    let blockCount = 10
    let radius = 2

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    #expect(windows.isEmpty)
  }

  @Test("Three overlapping windows merge into one")
  func threeWindowsMerge() {
    let lineIndices = [2, 4, 6]  // With radius 2, all overlap
    let blockCount = 10
    let radius = 2

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    #expect(windows.count == 1)
    #expect(windows[0] == 0...8)
  }

  @Test("Complex merging scenario")
  func complexMergingScenario() {
    // Indices: 1, 3, 8, 10 with radius 1
    // Windows: [0-2], [2-4], [7-9], [9-11]
    // Merged: [0-4], [7-11]
    let lineIndices = [1, 3, 8, 10]
    let blockCount = 15
    let radius = 1

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    #expect(windows.count == 2)
    #expect(windows[0] == 0...4)
    #expect(windows[1] == 7...11)
  }

  @Test("Acceptance 3 specific case: four blocks apart with radius 3")
  func acceptance3FourBlocksApart() {
    // Two lines at indices 0 and 4 (4 blocks apart)
    // With radius 3: [0-3] and [1-7] → overlap at 1-3 → merge to [0-7]
    let lineIndices = [0, 4]
    let blockCount = 10
    let radius = 3

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    #expect(windows.count == 1)  // Should merge
    #expect(windows[0] == 0...7)
  }

  @Test("Acceptance 3 specific case: seven blocks apart with radius 3")
  func acceptance3SevenBlocksApart() {
    // Two lines at indices 0 and 7 (7 blocks apart)
    // With radius 3: [0-3] and [4-10] → no overlap, stay separate
    let lineIndices = [0, 7]
    let blockCount = 15
    let radius = 3

    let windows = CharacterWindowing.mergedWindows(
      around: lineIndices, blockCount: blockCount, radius: radius)

    // Windows [0-3] and [4-10] don't overlap (gap at index 4), so stay separate
    #expect(windows.count == 2)
    #expect(windows[0] == 0...3)
    #expect(windows[1] == 4...10)
  }

  // MARK: - Helper

  private func makeElement(
    type: ElementType,
    text: String,
    speaker: String? = nil
  ) -> ScriptElementInfo {
    ScriptElementInfo(
      elementId: UUID().uuidString,
      documentId: "doc1",
      documentTitle: "Test",
      sceneIndex: 0,
      sceneId: nil,
      chapterIndex: 0,
      orderIndex: 0,
      elementTypeName: type.description,
      text: text,
      speaker: speaker
    )
  }
}
