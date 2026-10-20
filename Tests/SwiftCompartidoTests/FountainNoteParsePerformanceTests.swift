//
//  FountainNoteParsePerformanceTests.swift
//  SwiftCompartidoTests
//
//  Parse-time benchmark for a large screenplay that contains notes.
//  Listed in the Makefile's PERF_TESTS: excluded from CI, run with `make test-perf`.
//

import Foundation
import XCTest

@testable import SwiftCompartido

final class FountainNoteParsePerformanceTests: XCTestCase {

  /// bigfish.fountain repeated 10 times, with one-line and multi-line notes
  /// inserted between repetitions.
  private func largeScreenplay() throws -> String {
    let url = try XCTUnwrap(
      Bundle.module.url(forResource: "bigfish", withExtension: "fountain", subdirectory: "Fixtures")
    )
    let base = try String(contentsOf: url, encoding: .utf8)
    let notes = """

      [[ {"shot": {"size": "MS", "ref": ["a.png", "b.png"]}} ]]

      [[ {"shot": {
        "size": "WS",
        "ref": ["hall.png"]
      }} ]]

      [[ A plain note about the scene. ]]

      """
    return Array(repeating: base, count: 10).joined(separator: notes)
  }

  func testPerformance_ParseLargeScreenplayWithNotes() throws {
    let text = try largeScreenplay()
    measure {
      _ = FountainParser(string: text)
    }
  }
}
