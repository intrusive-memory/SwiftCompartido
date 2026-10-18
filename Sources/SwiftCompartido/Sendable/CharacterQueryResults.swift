//
//  CharacterQueryResults.swift
//  SwiftCompartido
//
//  Result types for the per-character script queries (CP-P3, CP-P4, CP-P5).
//

import Foundation

/// One screenplay element as returned by the character queries.
///
/// A plain `Codable`/`Sendable` value: no SwiftData model crosses the actor
/// boundary. Every value carries its full script position so callers can sort
/// or group without going back to the store.
///
/// ## Script order (CP-P6)
///
/// Results are ordered by document, then scene, then element. Concretely:
///
/// 1. Documents by `(title, filename)` — the same order
///    ``DocumentModelActor/extractAllCharacters()`` uses.
/// 2. Within a document, by `(chapterIndex, orderIndex)`.
///
/// Scenes are derived from scene headings in that order, so the scene index is
/// monotonic in `(chapterIndex, orderIndex)` and sorting by element position is
/// the same as sorting by `(scene, orderIndex)`. The stored `sceneId` is not
/// used as a sort key: Fountain parses never set it, and FDX imports set it on
/// scene headings only.
public struct ScriptElementInfo: Codable, Sendable, Hashable {
  /// The element's stable UUID string (``GuionElementModel/uuid``).
  public let elementId: String

  /// The owning document's persistent identifier as a string (same format as
  /// ``StoreCharacterInfo/DocumentInfo/id``).
  public let documentId: String

  /// The owning document's title, or filename, or `"Untitled"`.
  public let documentTitle: String

  /// Zero-based scene index (by scene heading) within the document, or `nil`
  /// when the element precedes the first scene heading. Same semantics as
  /// ``CharacterInfo/scenes``.
  public let sceneIndex: Int?

  /// The element's `sceneId`, or the enclosing scene heading's, when the store
  /// carries one (FDX imports do; Fountain parses do not).
  public let sceneId: String?

  /// Chapter index within the document.
  public let chapterIndex: Int

  /// Order index within the chapter.
  public let orderIndex: Int

  /// The element type's display name (``ElementType/description``), e.g.
  /// `"Dialogue"`. Use ``elementType`` for the enum value.
  public let elementTypeName: String

  /// The element's text.
  public let text: String

  /// Who speaks this element.
  ///
  /// - `.dialogue` / `.parenthetical`: the stored ``GuionElementModel/speaker``.
  /// - `.character` cue: the cleaned cue name, so a whole dialogue block
  ///   (cue + parentheticals + dialogue) carries one label.
  /// - Everything else (action, headings, transitions, …): `nil`.
  public let speaker: String?

  /// The element type as an ``ElementType`` (section heading and list levels
  /// are not preserved).
  public var elementType: ElementType { ElementType(string: elementTypeName) }

  public init(
    elementId: String,
    documentId: String,
    documentTitle: String,
    sceneIndex: Int?,
    sceneId: String?,
    chapterIndex: Int,
    orderIndex: Int,
    elementTypeName: String,
    text: String,
    speaker: String?
  ) {
    self.elementId = elementId
    self.documentId = documentId
    self.documentTitle = documentTitle
    self.sceneIndex = sceneIndex
    self.sceneId = sceneId
    self.chapterIndex = chapterIndex
    self.orderIndex = orderIndex
    self.elementTypeName = elementTypeName
    self.text = text
    self.speaker = speaker
  }
}

/// A complete scene in which a character speaks (CP-P4).
///
/// `elements` holds every element of the scene in script order, starting with
/// the scene heading. A "scene" with `sceneIndex == nil` is the material before
/// a document's first scene heading; it is returned only if the character
/// speaks there.
public struct CharacterSceneInfo: Codable, Sendable, Hashable {
  /// The owning document's persistent identifier as a string.
  public let documentId: String

  /// The owning document's title, or filename, or `"Untitled"`.
  public let documentTitle: String

  /// Zero-based scene index within the document, or `nil` for the material
  /// before the first scene heading.
  public let sceneIndex: Int?

  /// The scene heading's `sceneId`, when the store carries one.
  public let sceneId: String?

  /// The scene heading text, or `nil` for the material before the first heading.
  public let heading: String?

  /// Every element of the scene in script order, heading first.
  public let elements: [ScriptElementInfo]

  public init(
    documentId: String,
    documentTitle: String,
    sceneIndex: Int?,
    sceneId: String?,
    heading: String?,
    elements: [ScriptElementInfo]
  ) {
    self.documentId = documentId
    self.documentTitle = documentTitle
    self.sceneIndex = sceneIndex
    self.sceneId = sceneId
    self.heading = heading
    self.elements = elements
  }
}

/// One unit of a line window (CP-P5): a dialogue block, or an action paragraph
/// or other body element, labelled with its speaker.
///
/// A dialogue block is a character cue together with the parentheticals and
/// dialogue that follow it. A narrator's speech is a dialogue block whose
/// speaker is the narrator's cue. Every other body element (action, transition,
/// lyrics, list item) is a block of its own with `speaker == nil`.
public struct ScriptBlockInfo: Codable, Sendable, Hashable {
  /// The block's speaker, or `nil` for action and other non-dialogue blocks.
  public let speaker: String?

  /// `true` when this block is one of the queried character's lines (a window
  /// centre), `false` when it is a neighbour.
  public let isCharacterLine: Bool

  /// The block's elements in script order, each labelled with its speaker.
  public let elements: [ScriptElementInfo]

  /// The block's spoken or narrative text: its non-cue elements joined by
  /// newlines.
  public var text: String {
    elements
      .filter { $0.elementTypeName != ElementType.character.description }
      .map(\.text)
      .joined(separator: "\n")
  }

  public init(speaker: String?, isCharacterLine: Bool, elements: [ScriptElementInfo]) {
    self.speaker = speaker
    self.isCharacterLine = isCharacterLine
    self.elements = elements
  }
}

/// A character's lines with their neighbours, within one scene (CP-P5).
///
/// Each of the character's lines contributes the `N` blocks before and after
/// it, clipped to the scene. Windows that overlap (share a block) are merged, so a
/// window can contain several of the character's lines. A window never crosses
/// a scene boundary.
public struct CharacterLineWindow: Codable, Sendable, Hashable {
  /// The owning document's persistent identifier as a string.
  public let documentId: String

  /// The owning document's title, or filename, or `"Untitled"`.
  public let documentTitle: String

  /// Zero-based scene index within the document, or `nil` for the material
  /// before the first scene heading.
  public let sceneIndex: Int?

  /// The scene heading's `sceneId`, when the store carries one.
  public let sceneId: String?

  /// The scene heading text, for context. Not part of ``blocks``.
  public let heading: String?

  /// The window's blocks in script order.
  public let blocks: [ScriptBlockInfo]

  public init(
    documentId: String,
    documentTitle: String,
    sceneIndex: Int?,
    sceneId: String?,
    heading: String?,
    blocks: [ScriptBlockInfo]
  ) {
    self.documentId = documentId
    self.documentTitle = documentTitle
    self.sceneIndex = sceneIndex
    self.sceneId = sceneId
    self.heading = heading
    self.blocks = blocks
  }
}
