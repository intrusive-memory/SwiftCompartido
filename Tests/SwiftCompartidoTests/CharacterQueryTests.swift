//
//  CharacterQueryTests.swift
//  SwiftCompartidoTests
//
//  Per-character script queries (CP-P3, CP-P4, CP-P5).
//

import Foundation
import SwiftData
import Testing

@testable import SwiftCompartido

@Suite("Character Queries")
struct CharacterQueryTests {

  // Scene 0: HUNTER speaks at blocks 1 and 5 (four apart) -> one ±3 window.
  // Scene 1: no HUNTER.
  // Scene 2: HUNTER is the first and last block.
  private static let episodeOne = """
    Title: Episode 1

    INT. CABIN - NIGHT

    Wind howls.

    HUNTER
    Who's there?

    MAYA
    Just me.

    Rain hammers the roof.

    MAYA
    Again.

    HUNTER (CONT'D)
    (quietly)
    Come in.

    Maya enters.

    MAYA
    Thanks.

    The fire dies.

    Silence.

    EXT. FOREST - DAY

    Birds sing.

    MAYA
    Alone now.

    INT. CAR - DAY

    HUNTER
    Drive.

    The car lurches.

    HUNTER
    Faster.
    """

  private static let episodeTwo = """
    Title: Episode 2

    INT. BARN - DAY

    HUNTER
    Back again.
    """

  private func makeContainer() throws -> ModelContainer {
    let schema = Schema([
      GuionDocumentModel.self,
      GuionElementModel.self,
      TypedDataStorage.self,
      TitlePageEntryModel.self,
      CustomPageModel.self,
      CharacterVoiceMapping.self,
      CustomOutlineElement.self,
    ])
    return try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
  }

  private func makeActor() async throws -> DocumentModelActor {
    let actor = DocumentModelActor(modelContainer: try makeContainer())
    // Insert episode two first: ordering must not depend on insertion order.
    _ = try await actor.parseAndSaveDocument(from: Self.episodeTwo, title: "Episode 2")
    _ = try await actor.parseAndSaveDocument(from: Self.episodeOne, title: "Episode 1")
    return actor
  }

  // MARK: CP-P3

  @Test("CP-P3 returns a character's lines in script order")
  func linesInScriptOrder() async throws {
    let actor = try await makeActor()
    let lines = try await actor.fetchLines(for: "hunter (v.o.)")

    #expect(
      lines.map(\.text) == [
        "Who's there?", "(quietly)", "Come in.", "Drive.", "Faster.", "Back again.",
      ])
    #expect(lines.allSatisfy { $0.speaker == "HUNTER" })
    #expect(lines.map(\.documentTitle) == Array(repeating: "Episode 1", count: 5) + ["Episode 2"])
    #expect(lines.map(\.sceneIndex) == [0, 0, 0, 2, 2, 0])

    // Deterministic
    #expect(try await actor.fetchLines(for: "HUNTER") == lines)
    #expect(try await actor.fetchLines(for: "NOBODY").isEmpty)
  }

  // MARK: CP-P4

  @Test("CP-P4 returns only scenes the character speaks in, each complete")
  func completeScenes() async throws {
    let actor = try await makeActor()
    let scenes = try await actor.fetchScenes(for: "HUNTER")

    #expect(scenes.map(\.sceneIndex) == [0, 2, 0])
    #expect(scenes.map(\.documentTitle) == ["Episode 1", "Episode 1", "Episode 2"])
    #expect(scenes[0].heading == "INT. CABIN - NIGHT")
    #expect(scenes[0].elements.first?.elementType == .sceneHeading)
    #expect(scenes[0].elements.last?.text == "Silence.")
    #expect(scenes[0].elements.contains { $0.speaker == "MAYA" })
    #expect(!scenes.contains { $0.heading == "EXT. FOREST - DAY" })
    let positions = scenes[0].elements.map { [$0.chapterIndex, $0.orderIndex] }
    #expect(positions == positions.sorted { $0.lexicographicallyPrecedes($1) })
  }

  // MARK: CP-P5

  @Test("CP-P5 merges windows four blocks apart and never crosses scenes")
  func lineWindows() async throws {
    let actor = try await makeActor()
    let windows = try await actor.fetchLineWindows(for: "HUNTER")

    // Scene 0 -> one merged window; scene 2 -> one window; episode 2 -> one.
    #expect(windows.map(\.sceneIndex) == [0, 2, 0])

    let cabin = windows[0]
    // Blocks: Wind | HUNTER | MAYA | Rain | MAYA | HUNTER | Maya enters | MAYA | fire | Silence
    // Lines at 1 and 5, ±3 -> 0...4 ∪ 2...8 = 0...8 (Silence excluded).
    #expect(cabin.blocks.count == 9)
    #expect(cabin.blocks.first?.text == "Wind howls.")
    #expect(cabin.blocks.last?.text == "The fire dies.")
    #expect(cabin.blocks.filter(\.isCharacterLine).map(\.text) == ["Who's there?", "(quietly)\nCome in."])
    #expect(cabin.blocks.map(\.speaker) == [
      nil, "HUNTER", "MAYA", nil, "MAYA", "HUNTER", nil, "MAYA", nil,
    ])
    // Every element of a dialogue block carries the block's speaker.
    for block in cabin.blocks where block.speaker != nil {
      #expect(block.elements.allSatisfy { $0.speaker == block.speaker })
    }
    // No window contains another scene's material.
    for window in windows {
      #expect(window.blocks.flatMap(\.elements).allSatisfy { $0.sceneIndex == window.sceneIndex })
    }

    // Scene 2: lines are first and last block; window clipped at both ends.
    #expect(windows[1].blocks.map(\.text) == ["Drive.", "The car lurches.", "Faster."])

    // N = 0 keeps lines only; non-adjacent lines stay separate windows.
    let bare = try await actor.fetchLineWindows(for: "HUNTER", neighbours: 0)
    #expect(bare.count == 5)
    #expect(bare.allSatisfy { $0.blocks.count == 1 && $0.blocks[0].isCharacterLine })

    await #expect(throws: DocumentModelActorError.self) {
      _ = try await actor.fetchLineWindows(for: "HUNTER", neighbours: -1)
    }
  }

  @Test("Window merging clips to bounds and merges overlapping or adjacent ranges")
  func mergedWindowRanges() {
    typealias W = CharacterWindowing
    #expect(W.mergedWindows(around: [1, 5], blockCount: 10, radius: 3) == [0...8])
    #expect(W.mergedWindows(around: [0, 9], blockCount: 10, radius: 3) == [0...3, 6...9])
    #expect(W.mergedWindows(around: [0, 7], blockCount: 10, radius: 3) == [0...9])  // adjacent
    #expect(W.mergedWindows(around: [5, 5, 2], blockCount: 6, radius: 1) == [1...5])
    #expect(W.mergedWindows(around: [0], blockCount: 1, radius: 3) == [0...0])
    #expect(W.mergedWindows(around: [], blockCount: 4, radius: 3).isEmpty)
  }

  // MARK: Stale stores

  @Test("Stores without speaker data throw instead of returning empty")
  func staleStoreThrows() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)
    _ = try await actor.parseAndSaveDocument(from: Self.episodeTwo, title: "Episode 2")

    // Simulate a V2-era record: clear the speaker field.
    let context = ModelContext(container)
    for element in try context.fetch(FetchDescriptor<GuionElementModel>()) {
      element.speaker = nil
    }
    try context.save()

    await #expect(throws: DocumentModelActorError.self) {
      _ = try await actor.fetchLines(for: "HUNTER")
    }
    await #expect(throws: DocumentModelActorError.self) {
      _ = try await actor.fetchScenes(for: "HUNTER")
    }
    await #expect(throws: DocumentModelActorError.self) {
      _ = try await actor.fetchLineWindows(for: "HUNTER")
    }
  }
}
