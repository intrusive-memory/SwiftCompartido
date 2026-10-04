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

  /// Total line count across all documents: the number of character cues
  /// (speech blocks), equal to the sum of per-document `extractCharacters()`
  /// `counts.lineCount` values
  public let lineCount: Int

  /// Total word count (dialogue + parenthetical) across all documents, equal to
  /// the sum of per-document `extractCharacters()` `counts.wordCount` values
  public let wordCount: Int

  /// Scene identifiers where this character appears, in script order.
  ///
  /// Only populated when the store carries scene IDs on scene headings (FDX
  /// imports do; Fountain parses currently do not). For per-document scene
  /// positions that are always available, use ``DocumentInfo/scenes``.
  public let sceneIds: [String]

  /// All documents (episodes) where this character appears, in store order
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

    /// Zero-based scene indices (by scene heading) in this document where the
    /// character appears. Same semantics as `CharacterInfo.scenes` from
    /// per-document `extractCharacters()`.
    public var scenes: [Int]

    public init(id: String, title: String, scenes: [Int] = []) {
      self.id = id
      self.title = title
      self.scenes = scenes
    }
  }

  /// A character's first dialogue line
  public struct FirstLineInfo: Codable, Sendable {
    /// The dialogue text
    public let text: String

    /// The document where this line appears
    public let documentTitle: String

    /// The scene ID where this line appears (if the store carries one)
    public let sceneId: String?

    /// The document's persistent identifier as a string
    public let documentId: String?

    /// Zero-based scene index (by scene heading) within the document, or nil
    /// if the line precedes the first scene heading
    public let sceneIndex: Int?

    public init(
      text: String, documentTitle: String, sceneId: String?,
      documentId: String? = nil, sceneIndex: Int? = nil
    ) {
      self.text = text
      self.documentTitle = documentTitle
      self.sceneId = sceneId
      self.documentId = documentId
      self.sceneIndex = sceneIndex
    }
  }
}
