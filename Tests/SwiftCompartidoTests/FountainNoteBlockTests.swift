//
//  FountainNoteBlockTests.swift
//  SwiftCompartidoTests
//
//  Unit tests for the standalone Fountain note recognizer. All fixtures are
//  synthetic.
//

import Foundation
import Testing

@testable import SwiftCompartido

struct FountainNoteBlockTests {

  private func match(_ text: String, at index: Int = 0) -> FountainNoteBlock.Match? {
    FountainNoteBlock.match(lines: text.components(separatedBy: "\n"), at: index)
  }

  // MARK: - One-line notes

  @Test func plainSingleLineNote() {
    let m = match("[[ This is a note about the scene ]]")
    #expect(m == .init(text: "This is a note about the scene", lastLineIndex: 0))
  }

  @Test func leadingAndTrailingWhitespaceAroundDelimiters() {
    let m = match("  \t[[  padded  ]]  \t")
    #expect(m == .init(text: "padded", lastLineIndex: 0))
  }

  @Test func shotWithRefArray() {
    let line = #"[[ {"shot": {"size": "MS", "ref": ["a.png", "b.png"]}} ]]"#
    let m = match(line)
    #expect(m?.text == #"{"shot": {"size": "MS", "ref": ["a.png", "b.png"]}}"#)
    #expect(m?.lastLineIndex == 0)
  }

  @Test func singleClosingBracketInProse() {
    let m = match("[[ the sign reads ] EXIT ]]")
    #expect(m?.text == "the sign reads ] EXIT")
  }

  @Test func bracketPairInProse() {
    #expect(match("[[ see [1] ]]")?.text == "see [1]")
  }

  @Test func nestedArraysOnOneLine() {
    let m = match(#"[[ {"grid": [[1, 2], [3, 4]]} ]]"#)
    #expect(m?.text == #"{"grid": [[1, 2], [3, 4]]}"#)
  }

  @Test func interiorDoubleBracketsArePreserved() {
    #expect(match(#"[[ {"ref": [["a"]]} ]]"#)?.text == #"{"ref": [["a"]]}"#)
    #expect(match("[[ a [[b ]]")?.text == "a [[b")
  }

  @Test func whitespaceOnlyContentIsAnEmptyNote() {
    // Matches today's behaviour: `[[ ]]` is a note with empty text.
    #expect(match("[[ ]]") == .init(text: "", lastLineIndex: 0))
  }

  // MARK: - Multi-line notes

  @Test func multiLineShot() {
    let text = """
      [[ {"shot": {
        "size": "WS",
        "angle": "low",
        "ref": ["hall.png"]
      }} ]]
      """
    let m = match(text)
    #expect(m?.lastLineIndex == 4)
    #expect(
      m?.text == """
        {"shot": {
          "size": "WS",
          "angle": "low",
          "ref": ["hall.png"]
        }}
        """)
  }

  @Test func multiLineNestedArraysDoNotCloseEarly() {
    let text = """
      [[ {"grid": [
        [1, [2]]
      ]} ]]
      """
    let m = match(text)
    #expect(m?.lastLineIndex == 2)
    #expect(m?.text == "{\"grid\": [\n  [1, [2]]\n]}")
  }

  @Test func multiLineWithWhitespaceOnlyLine() {
    let text = "[[ first part\n  \nsecond part ]]"
    let m = match(text)
    #expect(m == .init(text: "first part\n  \nsecond part", lastLineIndex: 2))
  }

  @Test func multiLineDelimitersOnTheirOwnLines() {
    let text = "[[\n{\"a\": 1}\n]]"
    let m = match(text)
    #expect(m == .init(text: "\n{\"a\": 1}\n", lastLineIndex: 2))
  }

  @Test func multiLineStopsAtTheClosingLineOnly() {
    let text = "[[ line one\nline two ]]\nAfter the note."
    #expect(match(text) == .init(text: "line one\nline two", lastLineIndex: 1))
  }

  @Test func matchAtNonZeroIndex() {
    let text = "Action.\n\n[[ note ]]"
    #expect(match(text, at: 2) == .init(text: "note", lastLineIndex: 2))
  }

  // MARK: - Not notes

  @Test func emptyLineInsideIsNotANote() {
    #expect(match("[[ first part\n\nsecond part ]]") == nil)
  }

  @Test func unterminatedIsNotANote() {
    #expect(match("[[ never closed\nstill open") == nil)
  }

  @Test func twoInlineNotesOnOneLineAreNotANoteBlock() {
    #expect(match("[[a]] [[b]]") == nil)
  }

  @Test func inlineNotesAcrossLinesAreNotANoteBlock() {
    #expect(match("[[x]] some action\nmore [[y]]") == nil)
  }

  @Test func emptyBracketsAreNotANote() {
    #expect(match("[[]]") == nil)
  }

  @Test func lineNotStartingWithBracketsIsNotANote() {
    #expect(match("Hello [[<breath/>]] world") == nil)
    #expect(match("[ single ]") == nil)
  }

  @Test func outOfRangeIndexIsNil() {
    #expect(FountainNoteBlock.match(lines: ["[[ a ]]"], at: 1) == nil)
    #expect(FountainNoteBlock.match(lines: [], at: 0) == nil)
  }
}
