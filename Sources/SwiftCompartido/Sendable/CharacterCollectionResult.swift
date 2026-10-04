//
//  CharacterCollectionResult.swift
//  SwiftCompartido
//
//  Store-wide character aggregation result type
//

import Foundation

/// Store-wide character collection result.
///
/// Aggregates character information across all documents in a SwiftData store,
/// providing complete casting metadata for multi-episode series or collections.
///
/// ## Usage
///
/// ```swift
/// let actor = DocumentModelActor(modelContainer: container)
/// let result = try await actor.extractAllCharacters()
///
/// for (name, info) in result.characters {
///     print("\(name): \(info.lineCount) lines across \(info.documents.count) episodes")
///     if let firstLine = info.firstLine {
///         print("  First line: \(firstLine.text)")
///     }
/// }
/// ```
public struct CharacterCollectionResult: Codable, Sendable {
  /// All speaking characters in the store, keyed by cleaned character name
  public let characters: [String: StoreCharacterInfo]

  public init(characters: [String: StoreCharacterInfo]) {
    self.characters = characters
  }
}

/// Information about a single character across all documents in the store.
public struct StoreCharacterInfo: Codable, Sendable {
  /// Cleaned character name (cue with V.O., CONT'D, etc. removed)
  public let name: String

  /// Total dialogue line count across all documents
  public let lineCount: Int

  /// Total word count across all documents
  public let wordCount: Int

  /// All scene IDs where this character speaks (may contain duplicates across documents)
  public let sceneIds: [String]

  /// All documents where this character appears
  public let documents: [DocumentInfo]

  /// The character's first dialogue line (earliest by document → scene → orderIndex)
  public let firstLine: FirstLineInfo?

  public init(
    name: String,
    lineCount: Int,
    wordCount: Int,
    sceneIds: [String],
    documents: [DocumentInfo],
    firstLine: FirstLineInfo?
  ) {
    self.name = name
    self.lineCount = lineCount
    self.wordCount = wordCount
    self.sceneIds = sceneIds
    self.documents = documents
    self.firstLine = firstLine
  }

  /// Document where a character appears
  public struct DocumentInfo: Codable, Sendable {
    /// Document's persistent identifier as a string
    public let id: String

    /// Document filename or title
    public let title: String

    public init(id: String, title: String) {
      self.id = id
      self.title = title
    }
  }

  /// A character's first dialogue line
  public struct FirstLineInfo: Codable, Sendable {
    /// The dialogue text
    public let text: String

    /// The document where this line appears
    public let documentTitle: String

    /// The scene ID where this line appears (if available)
    public let sceneId: String?

    public init(text: String, documentTitle: String, sceneId: String?) {
      self.text = text
      self.documentTitle = documentTitle
      self.sceneId = sceneId
    }
  }
}
