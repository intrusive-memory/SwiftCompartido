//
//  DocumentModelActor+CharacterQueries.swift
//  SwiftCompartido
//
//  Per-character script queries across the whole store:
//  CP-P3 (a character's lines), CP-P4 (complete scenes a character speaks in)
//  and CP-P5 (a character's lines with ±N neighbours, merged per scene).
//

import Foundation
@preconcurrency import SwiftData

extension DocumentModelActor {

  // MARK: - CP-P3: A character's lines

  /// Every dialogue and parenthetical element spoken by `characterName`, across
  /// every document in the store, in script order (CP-P3, CP-P6).
  ///
  /// The selection is a SwiftData predicate on ``GuionElementModel/speaker``.
  /// `characterName` is cleaned the same way cues are at parse time
  /// (extensions such as `(V.O.)` removed, uppercased), so `"Hunter (V.O.)"`
  /// and `"HUNTER"` select the same lines.
  ///
  /// Results are ordered by document `(title, filename)`, then
  /// `(chapterIndex, orderIndex)` — which is also scene order. Elements that
  /// belong to no document are not returned.
  ///
  /// ```swift
  /// let lines = try await actor.fetchLines(for: "HUNTER")
  /// for line in lines where line.elementType == .dialogue {
  ///     print("[\(line.documentTitle) #\(line.sceneIndex ?? -1)] \(line.text)")
  /// }
  /// ```
  ///
  /// - Parameter characterName: The character's name or cue.
  /// - Returns: The character's dialogue and parenthetical elements in script order.
  /// - Throws: ``DocumentModelActorError/speakerDataMissing(documentTitles:)`` if
  ///   any document predates speaker assignment (Schema V3) and must be
  ///   re-parsed, so a stale store never yields a silently empty result.
  public func fetchLines(for characterName: String) throws -> [ScriptElementInfo] {
    let target = GuionParsedElementCollection.cleanCharacterName(characterName)
    guard !target.isEmpty else { return [] }

    let documents = try orderedDocuments()
    try validateSpeakerData(in: documents)

    let predicate = #Predicate<GuionElementModel> { $0.speaker == target }
    let matches = try modelContext.fetch(FetchDescriptor(predicate: predicate))
    guard !matches.isEmpty else { return [] }

    // Only the documents that hold matches need walking for scene positions.
    let matchedIDs = Set(matches.map(\.persistentModelID))
    let matchedDocumentIDs = Set(matches.compactMap { $0.document?.persistentModelID })

    var result: [ScriptElementInfo] = []
    result.reserveCapacity(matches.count)
    for document in documents where matchedDocumentIDs.contains(document.persistentModelID) {
      for scene in scenes(of: document) {
        for (element, info) in zip(scene.models, scene.infos)
        where matchedIDs.contains(element.persistentModelID) {
          result.append(info)
        }
      }
    }
    return result
  }

  // MARK: - CP-P4: Complete scenes a character speaks in

  /// Every scene in which `characterName` has dialogue, complete and in script
  /// order (CP-P4, CP-P6).
  ///
  /// A scene runs from one scene heading up to the next. Each returned scene
  /// holds all of its elements — heading, action, every speaker's dialogue —
  /// not only the character's. A scene in which the character has only a
  /// parenthetical but no dialogue is not returned. Material before a
  /// document's first scene heading counts as a scene (with `sceneIndex == nil`)
  /// when the character speaks there.
  ///
  /// ```swift
  /// for scene in try await actor.fetchScenes(for: "HUNTER") {
  ///     print(scene.heading ?? "(opening)")
  ///     for element in scene.elements { print("  \(element.text)") }
  /// }
  /// ```
  ///
  /// - Parameter characterName: The character's name or cue (cleaned as in
  ///   ``fetchLines(for:)``).
  /// - Returns: The scenes in script order.
  /// - Throws: ``DocumentModelActorError/speakerDataMissing(documentTitles:)``
  ///   for a store that predates speaker assignment.
  public func fetchScenes(for characterName: String) throws -> [CharacterSceneInfo] {
    let target = GuionParsedElementCollection.cleanCharacterName(characterName)
    guard !target.isEmpty else { return [] }

    let documents = try orderedDocuments()
    try validateSpeakerData(in: documents)

    var result: [CharacterSceneInfo] = []
    for document in documents {
      for scene in scenes(of: document)
      where scene.infos.contains(where: { isDialogue($0) && $0.speaker == target }) {
        result.append(
          CharacterSceneInfo(
            documentId: scene.documentId,
            documentTitle: scene.documentTitle,
            sceneIndex: scene.sceneIndex,
            sceneId: scene.sceneId,
            heading: scene.heading,
            elements: scene.infos
          ))
      }
    }
    return result
  }

  // MARK: - CP-P5: Lines with neighbours

  /// Each of `characterName`'s lines with the `neighbours` blocks before and
  /// after it, clipped to the scene, with overlapping windows merged
  /// (CP-P5, CP-P6).
  ///
  /// ## Units
  ///
  /// Windows count *blocks*, not raw elements. A block is one dialogue block
  /// (a character cue with the parentheticals and dialogue under it — the
  /// narrator's speech included), or one action paragraph or other body
  /// element. Scene headings bound the scene and are not blocks (the heading
  /// is returned in ``CharacterLineWindow/heading``). Comments, boneyard,
  /// synopses, section headings and page breaks are not blocks and are left
  /// out of the result; they do not split a dialogue block.
  ///
  /// A *line* of the character is a dialogue block whose speaker is the
  /// character and which contains dialogue — one per cue, matching
  /// ``StoreCharacterInfo/lineCount``. Dual dialogue gives each speaker their
  /// own block.
  ///
  /// ## Windows
  ///
  /// A line at block `i` of a scene with `count` blocks covers
  /// `max(0, i - neighbours) ... min(count - 1, i + neighbours)`. Within a scene,
  /// windows that overlap (share at least one block) are merged into one;
  /// windows that only touch stay separate. Windows never cross a
  /// scene boundary.
  ///
  /// ```swift
  /// let windows = try await actor.fetchLineWindows(for: "HUNTER", neighbours: 3)
  /// for window in windows {
  ///     for block in window.blocks {
  ///         print("\(block.speaker ?? "ACTION"): \(block.text)")
  ///     }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - characterName: The character's name or cue (cleaned as in
  ///     ``fetchLines(for:)``).
  ///   - neighbours: Blocks to include on each side of a line. Default 3.
  /// - Returns: Merged windows in script order.
  /// - Throws: ``DocumentModelActorError/invalidData`` if `neighbours` is
  ///   negative; ``DocumentModelActorError/speakerDataMissing(documentTitles:)``
  ///   for a store that predates speaker assignment.
  public func fetchLineWindows(
    for characterName: String,
    neighbours: Int = 3
  ) throws -> [CharacterLineWindow] {
    guard neighbours >= 0 else { throw DocumentModelActorError.invalidData }
    let target = GuionParsedElementCollection.cleanCharacterName(characterName)
    guard !target.isEmpty else { return [] }

    let documents = try orderedDocuments()
    try validateSpeakerData(in: documents)

    var result: [CharacterLineWindow] = []
    for document in documents {
      for scene in scenes(of: document) {
        let blocks = CharacterWindowing.blocks(from: scene.infos)
        let lineIndices = blocks.indices.filter {
          CharacterWindowing.isLine(blocks[$0], of: target)
        }
        guard !lineIndices.isEmpty else { continue }

        let ranges = CharacterWindowing.mergedWindows(
          around: lineIndices, blockCount: blocks.count, radius: neighbours)
        let lineSet = Set(lineIndices)
        for range in ranges {
          let windowBlocks = range.map { index in
            ScriptBlockInfo(
              speaker: blocks[index].speaker,
              isCharacterLine: lineSet.contains(index),
              elements: blocks[index].elements)
          }
          result.append(
            CharacterLineWindow(
              documentId: scene.documentId,
              documentTitle: scene.documentTitle,
              sceneIndex: scene.sceneIndex,
              sceneId: scene.sceneId,
              heading: scene.heading,
              blocks: windowBlocks
            ))
        }
      }
    }
    return result
  }

  // MARK: - Shared helpers

  /// One scene of a document: parallel arrays of models and their DTOs.
  private struct SceneSlice {
    let documentId: String
    let documentTitle: String
    let sceneIndex: Int?
    let sceneId: String?
    let heading: String?
    var models: [GuionElementModel]
    var infos: [ScriptElementInfo]
  }

  /// All documents in deterministic order: `(title, filename)`, the same as
  /// ``extractAllCharacters()``.
  private func orderedDocuments() throws -> [GuionDocumentModel] {
    let descriptor = FetchDescriptor<GuionDocumentModel>(
      sortBy: [SortDescriptor(\.title), SortDescriptor(\.filename)]
    )
    return try modelContext.fetch(descriptor)
  }

  /// Split a document into scenes in `(chapterIndex, orderIndex)` order.
  ///
  /// Each scene starts at a scene heading. Elements before the first heading
  /// form a scene with `sceneIndex == nil` (omitted when empty).
  private func scenes(of document: GuionDocumentModel) -> [SceneSlice] {
    let documentId = String(describing: document.persistentModelID)
    let documentTitle = document.title ?? document.filename ?? "Untitled"

    var slices: [SceneSlice] = []
    var current = SceneSlice(
      documentId: documentId, documentTitle: documentTitle,
      sceneIndex: nil, sceneId: nil, heading: nil, models: [], infos: [])
    var sceneIndex = -1

    for element in document.sortedElements {
      if element.elementType == .sceneHeading {
        if !current.models.isEmpty { slices.append(current) }
        sceneIndex += 1
        current = SceneSlice(
          documentId: documentId, documentTitle: documentTitle,
          sceneIndex: sceneIndex,
          sceneId: element.sceneId.flatMap { $0.isEmpty ? nil : $0 },
          heading: element.elementText,
          models: [], infos: [])
      }

      let speaker: String?
      switch element.elementType {
      case .character:
        let name = GuionParsedElementCollection.cleanCharacterName(element.elementText)
        speaker = name.isEmpty ? nil : name
      case .dialogue, .parenthetical:
        speaker = element.speaker.flatMap { $0.isEmpty ? nil : $0 }
      default:
        speaker = nil
      }

      current.models.append(element)
      current.infos.append(
        ScriptElementInfo(
          elementId: element.uuid.uuidString,
          documentId: documentId,
          documentTitle: documentTitle,
          sceneIndex: current.sceneIndex,
          sceneId: element.sceneId.flatMap { $0.isEmpty ? nil : $0 } ?? current.sceneId,
          chapterIndex: element.chapterIndex,
          orderIndex: element.orderIndex,
          elementTypeName: element.elementType.description,
          text: element.elementText,
          speaker: speaker
        ))
    }
    if !current.models.isEmpty { slices.append(current) }
    return slices
  }

  /// Throw if any document holds dialogue that has a preceding cue but no
  /// stored speaker — i.e. it was stored before Schema V3 speaker assignment
  /// and a query on it would silently miss lines.
  internal func validateSpeakerData(in documents: [GuionDocumentModel]) throws {
    var stale: [String] = []
    for document in documents {
      var seenCue = false
      elementLoop: for element in document.sortedElements {
        switch element.elementType {
        case .character:
          seenCue = true
        case .dialogue, .parenthetical:
          if seenCue && (element.speaker?.isEmpty ?? true) {
            stale.append(document.title ?? document.filename ?? "Untitled")
            break elementLoop
          }
        default:
          continue
        }
      }
    }
    if !stale.isEmpty {
      throw DocumentModelActorError.speakerDataMissing(documentTitles: stale)
    }
  }

  private func isDialogue(_ info: ScriptElementInfo) -> Bool {
    info.elementTypeName == ElementType.dialogue.description
  }
}

// MARK: - Windowing (pure, testable)

/// Block grouping and window merging for CP-P5. Pure functions over DTOs so the
/// edge cases can be tested without a store.
enum CharacterWindowing {

  /// A block: one dialogue block or one body element.
  struct Block: Equatable {
    var speaker: String?
    var isDialogueBlock: Bool
    var elements: [ScriptElementInfo]

    var hasDialogue: Bool {
      elements.contains { $0.elementTypeName == ElementType.dialogue.description }
    }
  }

  /// Group one scene's elements into blocks.
  ///
  /// - The scene heading is dropped (it bounds the scene).
  /// - A `.character` cue opens a dialogue block; following `.parenthetical`
  ///   and `.dialogue` elements of the same speaker join it.
  /// - Dialogue or a parenthetical with no open block of its speaker opens one.
  /// - Comments, boneyard, synopses, section headings and page breaks are
  ///   skipped and do not close an open dialogue block.
  /// - Every other element (action, transition, lyrics, list items) is its own
  ///   block with no speaker, and closes any open dialogue block.
  static func blocks(from elements: [ScriptElementInfo]) -> [Block] {
    var blocks: [Block] = []
    var open: Block?

    func close() {
      if let block = open { blocks.append(block) }
      open = nil
    }

    for element in elements {
      switch element.elementType {
      case .sceneHeading, .comment, .boneyard, .synopsis, .sectionHeading, .pageBreak:
        continue

      case .character:
        close()
        open = Block(speaker: element.speaker, isDialogueBlock: true, elements: [element])

      case .dialogue, .parenthetical:
        if open == nil || open?.speaker != element.speaker {
          close()
          open = Block(speaker: element.speaker, isDialogueBlock: true, elements: [])
        }
        open?.elements.append(element)

      default:
        close()
        blocks.append(Block(speaker: nil, isDialogueBlock: false, elements: [element]))
      }
    }
    close()
    return blocks
  }

  /// Whether `block` is one of `character`'s lines: a dialogue block with that
  /// speaker that contains dialogue.
  static func isLine(_ block: Block, of character: String) -> Bool {
    block.isDialogueBlock && block.speaker == character && block.hasDialogue
  }

  /// The ±`radius` windows around `lineIndices`, clipped to
  /// `0 ..< blockCount`, with overlapping windows (sharing at least one block) merged.
  /// Adjacent windows that do not share a block stay separate.
  ///
  /// `lineIndices` may be in any order and contain duplicates. The result is
  /// sorted and its ranges are disjoint.
  static func mergedWindows(
    around lineIndices: [Int], blockCount: Int, radius: Int
  ) -> [ClosedRange<Int>] {
    guard blockCount > 0, radius >= 0 else { return [] }
    let windows =
      lineIndices
      .filter { $0 >= 0 && $0 < blockCount }
      .sorted()
      .map { max(0, $0 - radius)...min(blockCount - 1, $0 + radius) }

    var merged: [ClosedRange<Int>] = []
    for window in windows {
      if let last = merged.last, window.lowerBound <= last.upperBound {
        merged[merged.count - 1] = last.lowerBound...max(last.upperBound, window.upperBound)
      } else {
        merged.append(window)
      }
    }
    return merged
  }
}
