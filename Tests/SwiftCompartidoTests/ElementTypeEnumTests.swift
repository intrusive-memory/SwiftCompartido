//
//  ElementTypeEnumTests.swift
//  SwiftGuionTests
//
//  Tests for the ElementType enum conversion
//

import Foundation
import Testing

@testable import SwiftCompartido

@Suite("ElementType Enum Tests")
struct ElementTypeEnumTests {

  // MARK: - Table-Driven String Representation Tests

  @Test(
    "String representation matches expected values",
    arguments: [
      (ElementType.sceneHeading, "Scene Heading"),
      (ElementType.action, "Action"),
      (ElementType.character, "Character"),
      (ElementType.dialogue, "Dialogue"),
      (ElementType.parenthetical, "Parenthetical"),
      (ElementType.transition, "Transition"),
      (ElementType.synopsis, "Synopsis"),
      (ElementType.comment, "Comment"),
      (ElementType.boneyard, "Boneyard"),
      (ElementType.lyrics, "Lyrics"),
      (ElementType.pageBreak, "Page Break"),
    ]
  )
  func testStringRepresentation(type: ElementType, expectedDescription: String) {
    #expect(type.description == expectedDescription)
  }

  @Test("Section heading string representation")
  func testSectionHeadingStringRepresentation() {
    let level1 = ElementType.sectionHeading(level: 1)
    let level3 = ElementType.sectionHeading(level: 3)

    #expect(level1.description == "Section Heading")
    #expect(level3.description == "Section Heading")
  }

  // MARK: - Table-Driven Initialization from String Tests

  @Test(
    "Initialize from valid string values",
    arguments: [
      ("Scene Heading", ElementType.sceneHeading),
      ("Action", ElementType.action),
      ("Character", ElementType.character),
      ("Dialogue", ElementType.dialogue),
      ("Parenthetical", ElementType.parenthetical),
      ("Transition", ElementType.transition),
      ("Synopsis", ElementType.synopsis),
      ("Comment", ElementType.comment),
      ("Boneyard", ElementType.boneyard),
      ("Lyrics", ElementType.lyrics),
      ("Page Break", ElementType.pageBreak),
    ]
  )
  func testInitFromValidStrings(input: String, expected: ElementType) {
    #expect(ElementType(string: input) == expected)
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
      .sectionHeading(level: 3),
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

  // MARK: - Table-Driven Level Property Tests

  @Test(
    "Level property returns correct value for section headings",
    arguments: [1, 2, 3, 4, 5, 6]
  )
  func testLevelProperty(level: Int) {
    let sectionHeading = ElementType.sectionHeading(level: level)
    #expect(sectionHeading.level == level)
  }

  @Test(
    "Level property returns 0 for non-section heading types",
    arguments: [
      ElementType.sceneHeading,
      ElementType.action,
      ElementType.dialogue,
      ElementType.character,
      ElementType.parenthetical,
    ]
  )
  func testLevelPropertyNonSectionHeadings(type: ElementType) {
    #expect(type.level == 0)
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
      .sectionHeading(level: 6),
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
