//
//  FountainScript+Characters.swift
//  SwiftFountain
//
//  Copyright (c) 2025
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

extension GuionParsedElementCollection {

  /// Extract character information from the script
  /// - Returns: A dictionary mapping character names to their information
  public func extractCharacters() -> CharacterList {
    var characters: CharacterList = [:]
    var currentSceneIndex: Int = -1
    var lastCharacterName: String?

    for element in elements {
      // Track scene changes
      if element.elementType == .sceneHeading {
        currentSceneIndex += 1
      }

      // Process character dialogue
      if element.elementType == .character {
        let characterName = cleanCharacterName(element.elementText)
        lastCharacterName = characterName

        // Initialize character if needed
        if characters[characterName] == nil {
          characters[characterName] = CharacterInfo()
        }

        // Add scene if not already tracked
        if currentSceneIndex >= 0 && !characters[characterName]!.scenes.contains(currentSceneIndex)
        {
          characters[characterName]!.scenes.append(currentSceneIndex)
        }

        // Increment line count for each character appearance
        characters[characterName]!.counts.lineCount += 1
      }

      // Process dialogue content (accumulate word counts)
      // Count words in Dialogue and Parenthetical
      if element.elementType == .dialogue || element.elementType == .parenthetical {
        if let characterName = lastCharacterName {
          characters[characterName]!.counts.wordCount += countWords(in: element.elementText)
        }
      }
    }

    return characters
  }

  /// Write character list to a JSON file
  /// - Parameter path: File path to write the JSON to
  /// - Throws: File writing errors
  public func writeCharactersJSON(toFile path: String) throws {
    let characters = extractCharacters()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(characters)
    try data.write(to: URL(fileURLWithPath: path))
  }

  /// Write character list to a JSON file URL
  /// - Parameter url: File URL to write the JSON to
  /// - Throws: File writing errors
  public func writeCharactersJSON(to url: URL) throws {
    let characters = extractCharacters()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(characters)
    try data.write(to: url)
  }

  // MARK: - Speaker Assignment (CP-P1)

  /// Compute the speaker for every element in `elements`, in order.
  ///
  /// The returned array is parallel to `elements`. For each `.dialogue` or
  /// `.parenthetical` element the entry is the cleaned name of the most recent
  /// preceding `.character` cue (see ``findMostRecentCharacter(in:beforeIndex:)``
  /// and ``cleanCharacterName(_:)``). Every other element type gets `nil`.
  ///
  /// Dual dialogue needs no special handling: the parser emits each speaker's
  /// cue as its own `.character` element (with the `^` marker stripped) ahead
  /// of that speaker's dialogue, so walking back to the nearest cue assigns
  /// each block to its own speaker.
  ///
  /// `elements` must be in script order.
  static func speakers<E: GuionElementProtocol>(for elements: [E]) -> [String?] {
    var result: [String?] = []
    result.reserveCapacity(elements.count)
    for (index, element) in elements.enumerated() {
      switch element.elementType {
      case .dialogue, .parenthetical:
        result.append(findMostRecentCharacter(in: elements, beforeIndex: index))
      default:
        result.append(nil)
      }
    }
    return result
  }

  /// Clean character name by removing extensions and parentheticals
  static func cleanCharacterName(_ name: String) -> String {
    var cleaned = name.trimmingCharacters(in: .whitespaces)

    // Remove character extensions like (V.O.), (O.S.), (CONT'D)
    if let openParen = cleaned.firstIndex(of: "(") {
      cleaned = String(cleaned[..<openParen]).trimmingCharacters(in: .whitespaces)
    }

    // Remove dual dialogue marker
    cleaned = cleaned.replacingOccurrences(of: "^", with: "").trimmingCharacters(in: .whitespaces)

    return cleaned.uppercased()
  }

  /// Find the most recent character that spoke before the given index
  static func findMostRecentCharacter<E: GuionElementProtocol>(
    in elements: [E], beforeIndex currentIndex: Int
  ) -> String? {
    guard currentIndex > 0 && currentIndex <= elements.count else {
      return nil
    }

    // Search backwards for the most recent Character element
    for i in stride(from: currentIndex - 1, through: 0, by: -1) {
      if elements[i].elementType == .character {
        return cleanCharacterName(elements[i].elementText)
      }
    }

    return nil
  }

  // MARK: - Private Helpers

  /// Clean character name by removing extensions and parentheticals
  private func cleanCharacterName(_ name: String) -> String {
    Self.cleanCharacterName(name)
  }

  /// Find the most recent character that spoke before the given index
  private func findMostRecentCharacter(beforeIndex currentIndex: Int) -> String? {
    Self.findMostRecentCharacter(in: elements, beforeIndex: currentIndex)
  }

  /// Count words in a string
  private func countWords(in text: String) -> Int {
    let words = text.components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
    return words.count
  }

  /// Find the first spoken line of dialog for a given character
  /// - Parameter characterName: The character's name (case-insensitive, extensions like (V.O.) are ignored)
  /// - Returns: The first dialogue text spoken by the character, or nil if the character has no dialogue
  public func firstDialogue(for characterName: String) -> String? {
    let cleanedSearchName = cleanCharacterName(characterName)
    var currentCharacter: String?

    for element in elements {
      if element.elementType == .character {
        currentCharacter = cleanCharacterName(element.elementText)
      } else if element.elementType == .dialogue,
        let character = currentCharacter,
        character == cleanedSearchName
      {
        return element.elementText
      }
    }

    return nil
  }
}
