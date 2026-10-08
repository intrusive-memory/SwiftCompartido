//
//  StoreCharacterCollectionTests.swift
//  SwiftCompartidoTests
//
//  Store-wide character collection (CP-P2).
//

import Foundation
import SwiftData
import Testing

@testable import SwiftCompartido

@Suite("Store Character Collection")
struct StoreCharacterCollectionTests {

  // BOB has one cue with two dialogue elements split by a parenthetical:
  // per-document extraction counts that as ONE line (one cue).
  private static let episodeOne = """
    Title: Episode 1

    INT. KITCHEN - DAY

    BOB
    Hello there.
    (beat)
    Goodbye now.

    ALICE (V.O.)
    Hi Bob.

    COP #1
    Freeze!

    EXT. STREET - NIGHT

    BOB (CONT'D)
    Still here.
    """

  private static let episodeTwo = """
    Title: Episode 2

    INT. BAR - NIGHT

    BARTENDER
    What'll it be?

    BOB
    Whiskey.
    (pause)
    Neat.
    (sighs)
    Make it a double.

    ALICE
    Same.
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

  @Test("Store-wide counts equal the sum of per-document extractCharacters()")
  func countsMatchPerDocumentSums() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)
    _ = try await actor.parseAndSaveDocument(from: Self.episodeOne)
    _ = try await actor.parseAndSaveDocument(from: Self.episodeTwo)

    let result = try await actor.extractAllCharacters()

    // Sum per-document extraction
    let context = ModelContext(container)
    let documents = try context.fetch(FetchDescriptor<GuionDocumentModel>())
    #expect(documents.count == 2)
    var expectedLines: [String: Int] = [:]
    var expectedWords: [String: Int] = [:]
    // [name: [documentTitle: scenes]]
    var expectedScenes: [String: [String: [Int]]] = [:]
    for document in documents {
      let title = document.title ?? document.filename ?? "Untitled"
      for (name, info) in document.extractCharacters() {
        expectedLines[name, default: 0] += info.counts.lineCount
        expectedWords[name, default: 0] += info.counts.wordCount
        expectedScenes[name, default: [:]][title] = info.scenes
      }
    }

    #expect(Set(result.characters.keys) == Set(expectedLines.keys))
    for (name, info) in result.characters {
      #expect(info.lineCount == expectedLines[name], "lineCount mismatch for \(name)")
      #expect(info.wordCount == expectedWords[name], "wordCount mismatch for \(name)")
      let actualScenes = Dictionary(
        uniqueKeysWithValues: info.documents.map { ($0.title, $0.scenes) })
      #expect(actualScenes == expectedScenes[name], "scenes mismatch for \(name)")
    }

    // Explicit values: BOB has 3 cues (2 in ep1, 1 in ep2), not 6 dialogue elements
    #expect(result.characters["BOB"]?.lineCount == 3)
    #expect(result.characters["ALICE"]?.lineCount == 2)
    #expect(result.characters["ALICE"]?.documents.count == 2)
    #expect(result.characters["BOB"]?.documents.count == 2)
    #expect(result.characters["COP #1"]?.lineCount == 1)
    #expect(result.characters["BARTENDER"]?.lineCount == 1)
    #expect(result.characters["BOB"]?.documents.first?.scenes == [0, 1])
    #expect(result.characters["BOB"]?.documents.last?.scenes == [0])
    #expect(result.characters["BOB"]?.firstLine?.text == "Hello there.")
    #expect(result.characters["BOB"]?.firstLine?.documentTitle == "Episode 1")
    #expect(result.characters["BOB"]?.firstLine?.sceneIndex == 0)
    #expect(result.characters["BARTENDER"]?.firstLine?.documentTitle == "Episode 2")
  }

  @Test("Result decodes as plain JSON without SwiftCompartido types")
  func jsonRoundTrip() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)
    _ = try await actor.parseAndSaveDocument(from: Self.episodeOne)
    let result = try await actor.extractAllCharacters()

    let data = try JSONEncoder().encode(result)

    // Mirror types a consumer like SwiftReparto would define independently
    struct Collection: Decodable {
      struct Character: Decodable {
        struct Doc: Decodable { let id: String; let title: String }
        struct First: Decodable { let text: String; let documentTitle: String; let sceneId: String? }
        let name: String
        let lineCount: Int
        let wordCount: Int
        let sceneIds: [String]
        let documents: [Doc]
        let firstLine: First?
      }
      let characters: [String: Character]
    }
    let decoded = try JSONDecoder().decode(Collection.self, from: data)
    #expect(decoded.characters["BOB"]?.lineCount == 2)
    #expect(decoded.characters["ALICE"]?.firstLine?.text == "Hi Bob.")
  }

  @Test("Empty store returns empty collection")
  func emptyStore() async throws {
    let actor = DocumentModelActor(modelContainer: try makeContainer())
    let result = try await actor.extractAllCharacters()
    #expect(result.characters.isEmpty)
  }
}
