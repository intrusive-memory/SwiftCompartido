//
//  FountainNoteRoundTripTests.swift
//  SwiftCompartidoTests
//
//  parse → FountainWriter → parse keeps every note's text. Synthetic fixtures.
//

import Foundation
import Testing

@testable import SwiftCompartido

struct FountainNoteRoundTripTests {

  private static let notes: [String] = [
    #"[[ {"shot": {"size": "MS", "ref": ["a.png", "b.png"]}} ]]"#,
    """
    [[ {"shot": {
      "size": "WS",
      "angle": "low",
      "ref": ["hall.png"]
    }} ]]
    """,
    "[[ the sign reads ] EXIT ]]",
    #"[[ {"grid": [[1, 2], [3, 4]]} ]]"#,
    """
    [[ {"grid": [
      [1, [2]],
      [[3, 4]]
    ]} ]]
    """,
    "[[ first part\n  \nsecond part ]]",
    "[[ This is a note about the scene ]]",
  ]

  private func commentTexts(_ text: String) throws -> [String] {
    try GuionParsedElementCollection(string: text).elements
      .filter { $0.elementType == .comment }
      .map(\.elementText)
  }

  @Test(arguments: notes)
  func noteSurvivesRoundTrip(_ note: String) throws {
    let source = "INT. HALL - DAY\n\n\(note)\n\nJOHN enters.\n"
    let first = try GuionParsedElementCollection(string: source)
    let firstComments = first.elements.filter { $0.elementType == .comment }.map(\.elementText)
    #expect(firstComments.count == 1)

    let written = FountainWriter.document(from: first)
    #expect(try commentTexts(written) == firstComments)
  }

  @Test func allNotesInOneScriptSurviveRoundTrip() throws {
    let source = "INT. HALL - DAY\n\n" + Self.notes.joined(separator: "\n\nJOHN waits.\n\n")
      + "\n\nJOHN enters.\n"
    let first = try commentTexts(source)
    #expect(first.count == Self.notes.count)

    let written = FountainWriter.document(from: try GuionParsedElementCollection(string: source))
    #expect(try commentTexts(written) == first)
  }

  @Test func writerOutputOfMultiLineNoteIsStable() throws {
    let source = "INT. HALL - DAY\n\n\(Self.notes[1])\n\nJOHN enters.\n"
    let once = FountainWriter.document(from: try GuionParsedElementCollection(string: source))
    let twice = FountainWriter.document(from: try GuionParsedElementCollection(string: once))
    #expect(once == twice)
  }
}
