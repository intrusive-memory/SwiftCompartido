//
//  FountainNoteBlock.swift
//  SwiftCompartido
//
//  Recognises a Fountain note (`[[ … ]]`) that stands as its own element,
//  including notes that span several lines.
//

import Foundation

/// Recognises standalone Fountain note blocks.
///
/// Fountain notes are enclosed in double brackets and may contain line breaks,
/// but not an empty line (a line of whitespace, such as two spaces, connects the
/// note instead). Only the first `[[` and the final `]]` of a block are
/// delimiters; any `[`, `]`, `[[` or `]]` between them is content. This lets a
/// note carry JSON, such as a multi-line object with arrays.
///
/// Rules (see `Docs/missions/fountain-notes/REQUIREMENTS.md`, R1–R4):
///
/// - The *content* is everything between the first `[[` and the final `]]`.
/// - The content's bracket depth is a running count from 0: `+1` per `[`,
///   `-1` per `]`. Content is *well-formed* when the depth never drops below
///   `-1`. One stray `]` in prose is allowed; a note that closed early, as in
///   `[[a]] [[b]]`, is not.
/// - A **one-line** note is a line that, trimmed, starts with `[[`, ends with
///   `]]`, and has non-empty, well-formed content.
/// - A **multi-line** note starts with a line that, trimmed, starts with `[[`
///   and is not a one-line note candidate. It closes at the first following
///   line ending in `]]` where the content is well-formed and its final depth
///   is `<= 0`. An empty line or the end of the document before that point
///   means there is no note.
/// - A line that is a one-line candidate is never extended to a multi-line
///   note, so today's single-line notes keep their exact boundaries.
///
/// The returned text has only the outer delimiters removed and is trimmed of
/// leading and trailing spaces and tabs. Every other byte is preserved.
///
/// The caller is responsible for the Fountain precondition that a standalone
/// note follows a blank line.
enum FountainNoteBlock {

  /// A recognised note block.
  struct Match: Equatable, Sendable {
    /// The note text: the content between the outer delimiters, trimmed of
    /// leading and trailing spaces and tabs.
    let text: String
    /// Index into `lines` of the block's last line (equal to the start index
    /// for a one-line note).
    let lastLineIndex: Int
  }

  private static let openBracket = UInt8(ascii: "[")
  private static let closeBracket = UInt8(ascii: "]")

  /// Returns the note block that starts at `lines[index]`, or `nil` if there is none.
  static func match(lines: [String], at index: Int) -> Match? {
    guard lines.indices.contains(index) else { return nil }

    let first = lines[index]
    let firstBody = first.drop(while: isHorizontalWhitespace)
    guard firstBody.hasPrefix("[[") else { return nil }

    // Content of the first line, after the opening delimiter.
    let firstContent = firstBody.dropFirst(2)

    // One-line note candidate: the line itself ends with `]]`.
    if let inner = droppingClosingDelimiter(firstContent) {
      guard !inner.isEmpty else { return nil }
      var scan = DepthScan()
      scan.consume(inner)
      guard scan.isWellFormed else { return nil }
      return Match(text: trimmed(inner), lastLineIndex: index)
    }

    // Multi-line note: scan forward to the first empty line or end of document.
    var scan = DepthScan()
    scan.consume(firstContent)
    guard scan.isWellFormed else { return nil }

    var k = index + 1
    while k < lines.count {
      let line = lines[k]
      if line.isEmpty { return nil }

      if let inner = droppingClosingDelimiter(Substring(line)) {
        var candidate = scan
        candidate.consume(inner)
        if candidate.isWellFormed && candidate.depth <= 0 {
          var content = String(firstContent)
          for j in (index + 1)..<k {
            content.append("\n")
            content.append(lines[j])
          }
          content.append("\n")
          content.append(contentsOf: inner)
          return Match(text: trimmed(Substring(content)), lastLineIndex: k)
        }
      }

      scan.consume(Substring(line))
      // Depth only falls further from here, so an ill-formed prefix can never
      // become a note.
      guard scan.isWellFormed else { return nil }
      k += 1
    }
    return nil
  }

  // MARK: - Helpers

  /// Running bracket depth over note content.
  private struct DepthScan {
    var depth = 0
    var minDepth = 0

    var isWellFormed: Bool { minDepth >= -1 }

    mutating func consume(_ text: Substring) {
      for byte in text.utf8 {
        if byte == FountainNoteBlock.openBracket {
          depth += 1
        } else if byte == FountainNoteBlock.closeBracket {
          depth -= 1
          if depth < minDepth { minDepth = depth }
        }
      }
    }
  }

  /// Matches `CharacterSet.whitespaces` (spaces and tabs, no newlines), the
  /// set the parser has always trimmed note text with.
  private static func isHorizontalWhitespace(_ c: Character) -> Bool {
    c.unicodeScalars.allSatisfy { CharacterSet.whitespaces.contains($0) }
  }

  /// If `text`, ignoring trailing spaces and tabs, ends with `]]`, returns the
  /// text before that `]]`.
  private static func droppingClosingDelimiter(_ text: Substring) -> Substring? {
    var end = text.endIndex
    while end > text.startIndex {
      let before = text.index(before: end)
      guard isHorizontalWhitespace(text[before]) else { break }
      end = before
    }
    let body = text[text.startIndex..<end]
    guard body.hasSuffix("]]") else { return nil }
    return body.dropLast(2)
  }

  private static func trimmed(_ text: Substring) -> String {
    text.trimmingCharacters(in: .whitespaces)
  }
}
