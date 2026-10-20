//
//  FountainParserNoteTests.swift
//  SwiftCompartidoTests
//
//  Fountain note (`[[ … ]]`) parsing through both FountainParser paths:
//  the synchronous `init(string:)` and the async progress-reporting
//  `init(string:progress:)`. All fixtures are synthetic.
//
//  Expected values for the "unchanged" cases were captured from the parser
//  before the note fix, so they pin today's behaviour.
//

import Foundation
import Testing

@testable import SwiftCompartido

struct FountainParserNoteTests {

  struct E: Equatable, CustomStringConvertible {
    let type: ElementType
    let text: String
    var description: String { "\(type) | \(text.debugDescription)" }
  }

  private static let heading = E(type: .sceneHeading, text: "INT. HALL - DAY")
  private static let after = E(type: .action, text: "JOHN enters.")

  /// Wraps `body` in a scene so the note follows a blank line and is followed by one.
  private func script(_ body: String) -> String {
    "INT. HALL - DAY\n\n\(body)\n\nJOHN enters.\n"
  }

  private func elements(_ parser: FountainParser) -> [E] {
    parser.elements.map { E(type: $0.elementType, text: $0.elementText) }
  }

  /// The synchronous path. A non-async context so `init(string:)` resolves to
  /// the synchronous initializer rather than the async one.
  private func syncElements(_ text: String) -> [E] {
    elements(FountainParser(string: text))
  }

  /// Parses through both paths, asserts they agree, and returns the elements.
  private func parseBoth(_ text: String) async throws -> [E] {
    let sync = syncElements(text)
    let async = elements(
      try await FountainParser(string: text, progress: OperationProgress(totalUnits: nil)))
    #expect(sync == async, "sync and async parse paths disagree")
    return sync
  }

  private func expectNote(_ body: String, _ text: String) async throws {
    let parsed = try await parseBoth(script(body))
    #expect(parsed == [Self.heading, E(type: .comment, text: text), Self.after])
  }

  // MARK: - Notation 2.0 shots and bracketed content

  @Test func shotWithRefArray() async throws {
    try await expectNote(
      #"[[ {"shot": {"size": "MS", "ref": ["a.png", "b.png"]}} ]]"#,
      #"{"shot": {"size": "MS", "ref": ["a.png", "b.png"]}}"#)
  }

  @Test func multiLineShot() async throws {
    let body = """
      [[ {"shot": {
        "size": "WS",
        "angle": "low",
        "ref": ["hall.png"]
      }} ]]
      """
    try await expectNote(
      body,
      "{\"shot\": {\n  \"size\": \"WS\",\n  \"angle\": \"low\",\n  \"ref\": [\"hall.png\"]\n}}")
  }

  @Test func singleClosingBracketInProse() async throws {
    try await expectNote("[[ the sign reads ] EXIT ]]", "the sign reads ] EXIT")
  }

  @Test func bracketPairInProse() async throws {
    try await expectNote("[[ see [1] ]]", "see [1]")
  }

  @Test func nestedArraysSingleLine() async throws {
    try await expectNote(
      #"[[ {"grid": [[1, 2], [3, 4]]} ]]"#, #"{"grid": [[1, 2], [3, 4]]}"#)
  }

  @Test func nestedArraysMultiLine() async throws {
    let body = """
      [[ {"grid": [
        [1, [2]],
        [[3, 4]]
      ]} ]]
      """
    try await expectNote(body, "{\"grid\": [\n  [1, [2]],\n  [[3, 4]]\n]}")
  }

  @Test func multiLineWithWhitespaceOnlyLine() async throws {
    try await expectNote("[[ first part\n  \nsecond part ]]", "first part\n  \nsecond part")
  }

  @Test func multiLineAllCapsIsANoteNotDialogue() async throws {
    // Before the fix this parsed as Character + Dialogue.
    try await expectNote("[[ NOTE ONE\nNOTE TWO ]]", "NOTE ONE\nNOTE TWO")
  }

  @Test func interiorDoubleBracketsArePreserved() async throws {
    // Before the fix interior `[[` was stripped, giving "a b".
    try await expectNote("[[ a [[b ]]", "a [[b")
  }

  @Test func multiLineNoteFollowedDirectlyByAction() async throws {
    let parsed = try await parseBoth(
      "INT. HALL - DAY\n\n[[ line one\nline two ]]\nJOHN enters.\n")
    #expect(parsed == [Self.heading, E(type: .comment, text: "line one\nline two"), Self.after])
  }

  @Test func consecutiveNotes() async throws {
    let parsed = try await parseBoth(script("[[ {\"shot\": {\n  \"size\": \"CU\"\n}} ]]\n\n[[ plain ]]"))
    #expect(
      parsed == [
        Self.heading,
        E(type: .comment, text: "{\"shot\": {\n  \"size\": \"CU\"\n}}"),
        E(type: .comment, text: "plain"),
        Self.after,
      ])
  }

  // MARK: - Unchanged behaviour (regressions)

  @Test func existingSingleLineNoteUnchanged() async throws {
    try await expectNote("[[ This is a note about the scene ]]", "This is a note about the scene")
  }

  @Test func inlineDialogueNoteStaysInDialogue() async throws {
    let parsed = try await parseBoth(
      "INT. HALL - DAY\n\nBERNARD\nHello [[<breath/>]] world.\n[[ trailing ]]\n\nJOHN enters.\n")
    #expect(
      parsed == [
        Self.heading,
        E(type: .character, text: "BERNARD"),
        E(type: .dialogue, text: "Hello [[<breath/>]] world.\n[[ trailing ]]"),
        Self.after,
      ])
  }

  @Test func emptyLineInsideIsNotANote() async throws {
    let parsed = try await parseBoth(script("[[ first part\n\nsecond part ]]"))
    #expect(
      parsed == [
        Self.heading,
        E(type: .action, text: "[[ first part"),
        E(type: .action, text: "second part ]]"),
        Self.after,
      ])
  }

  @Test func unterminatedIsNotANote() async throws {
    let parsed = try await parseBoth(script("[[ never closed\nstill open"))
    #expect(parsed == [Self.heading, E(type: .action, text: "[[ never closed\nstill open"), Self.after])
  }

  @Test func twoInlineNotesOnOneLineUnchanged() async throws {
    let parsed = try await parseBoth(script("[[a]] [[b]]"))
    #expect(parsed == [Self.heading, E(type: .action, text: "[[a]] [[b]]"), Self.after])
  }

  @Test func inlineNotesAcrossLinesUnchanged() async throws {
    let parsed = try await parseBoth(script("[[x]] some action\nmore [[y]]"))
    #expect(
      parsed == [Self.heading, E(type: .action, text: "[[x]] some action\nmore [[y]]"), Self.after])
  }

  @Test func emptyBracketsUnchanged() async throws {
    let parsed = try await parseBoth(script("[[]]"))
    #expect(parsed == [Self.heading, E(type: .action, text: "[[]]"), Self.after])
  }

  @Test func noteWithoutPrecedingBlankLineIsNotExtracted() async throws {
    let parsed = try await parseBoth("INT. HALL - DAY\n\nJohn waits.\n[[ not standalone ]]\n")
    #expect(
      parsed == [Self.heading, E(type: .action, text: "John waits.\n[[ not standalone ]]")])
  }
}
