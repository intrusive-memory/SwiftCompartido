//
//  GlosaIntegrationTests.swift
//  SwiftCompartidoTests
//
//  Integration tests for the GlosaCore annotation pass wired into
//  DocumentModelActor (Sortie 3 of OPERATION ANNOTATED VAULT).
//
//  These exercise the three acceptance criteria:
//   - AC1: inline `[[<breath/>]]` import yields notes-stripped spokenText and
//          integer breath offsets.
//   - AC2: splitting spokenText.unicodeScalars at breathOffsets round-trips
//          losslessly.
//   - AC3: a no-markup screenplay imports unchanged; glosa fields remain
//          nil / empty (no regression).
//

import Foundation
import SwiftData
import Testing

@testable import SwiftCompartido

@Suite("Glosa Integration")
struct GlosaIntegrationTests {

  // MARK: - Helpers

  /// In-memory container with the models the annotation pass touches.
  private func makeContainer() throws -> ModelContainer {
    let schema = Schema([
      GuionDocumentModel.self,
      GuionElementModel.self,
      TypedDataStorage.self,
    ])
    return try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
  }

  /// Loads a `.fountain` fixture from the test bundle.
  private func fixtureText(_ name: String) throws -> String {
    let url = try #require(
      Bundle.module.url(forResource: name, withExtension: "fountain", subdirectory: "Fixtures"),
      "Missing fixture \(name).fountain"
    )
    return try String(contentsOf: url, encoding: .utf8)
  }

  /// Imports a fixture through the actor (glosa enabled) and returns the
  /// resulting dialogue `GuionElementModel`s in document order, fetched from
  /// the same container.
  @MainActor
  private func importDialogueElements(
    fixture: String,
    parseGlosa: Bool = true
  ) async throws -> [GuionElementModel] {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)
    let text = try fixtureText(fixture)

    _ = try await actor.parseAndSaveDocument(from: text, parseGlosa: parseGlosa)

    // Fetch from a fresh context bound to the same container. The actor wrote
    // through its own private @ModelActor context; a new reader context sees
    // the persisted rows without aliasing the actor's (now out-of-scope) one.
    let context = ModelContext(container)
    let all = try context.fetch(FetchDescriptor<GuionElementModel>())
    return
      all
      .filter { $0.elementType == .dialogue }
      .sorted {
        $0.chapterIndex != $1.chapterIndex
          ? $0.chapterIndex < $1.chapterIndex
          : $0.orderIndex < $1.orderIndex
      }
  }

  // MARK: - AC1: inline breath markup yields stripped text + offsets

  @Test("AC1: inline [[<breath/>]] yields notes-stripped spokenText and integer offsets")
  @MainActor
  func breathMarkupAnnotated() async throws {
    let dialogue = try await importDialogueElements(fixture: "glosa_with_breath")

    // The first dialogue line carries the inline breath marker.
    let bernard = try #require(dialogue.first)

    // Raw elementText is preserved with the marker intact (lossless export).
    #expect(bernard.elementText.contains("[[<breath"))

    // glosaSpokenText is notes-stripped: no [[ ]] marker remains.
    let spoken = try #require(bernard.glosaSpokenText)
    #expect(!spoken.contains("[["))
    #expect(!spoken.contains("]]"))
    #expect(spoken == "Hello there.How are you today?")

    // Breath offsets are populated with integer unicode-scalar offsets.
    let offsets = try #require(bernard.glosaBreathOffsets)
    #expect(offsets.count == 1)
    let offset = try #require(offsets.first)
    // The breath sits at the seam between the two sentences: after
    // "Hello there." (12 unicode scalars).
    #expect(offset == 12)
    #expect(offset >= 0)
    #expect(offset <= spoken.unicodeScalars.count)

    // Parallel breath strengths are present and same-count.
    let strengths = try #require(bernard.glosaBreathStrengths)
    #expect(strengths.count == offsets.count)
  }

  // MARK: - AC2: lossless reconstruction by splitting at breath offsets

  @Test("AC2: splitting spokenText at breathOffsets reconstructs it losslessly")
  @MainActor
  func breathOffsetsRoundTrip() async throws {
    let dialogue = try await importDialogueElements(fixture: "glosa_with_breath")
    let bernard = try #require(dialogue.first)

    let spoken = try #require(bernard.glosaSpokenText)
    let offsets = try #require(bernard.glosaBreathOffsets)

    // Split spokenText.unicodeScalars at the breath offsets, then rejoin.
    let scalars = Array(spoken.unicodeScalars)
    var bounds = [0]
    bounds.append(contentsOf: offsets)
    bounds.append(scalars.count)

    var reconstructed = ""
    for i in 0..<(bounds.count - 1) {
      let lower = bounds[i]
      let upper = bounds[i + 1]
      reconstructed.unicodeScalars.append(contentsOf: scalars[lower..<upper])
    }

    #expect(reconstructed == spoken)
  }

  // MARK: - AC3: no-markup screenplay imports unchanged, glosa fields empty/nil

  @Test("AC3: no-markup screenplay imports with no breath/pause data (no regression)")
  @MainActor
  func noMarkupNoRegression() async throws {
    let dialogue = try await importDialogueElements(fixture: "glosa_no_markup")
    #expect(!dialogue.isEmpty)

    for element in dialogue {
      // No inline markers in the raw text.
      #expect(!element.elementText.contains("[["))

      // No breath markers => empty (not nil, the pass ran) breath data.
      #expect((element.glosaBreathOffsets ?? []).isEmpty)
      #expect((element.glosaBreathStrengths ?? []).isEmpty)

      // spokenText, when present, equals the unmodified dialogue text.
      if let spoken = element.glosaSpokenText {
        #expect(spoken == element.elementText)
      }

      // No pause points encoded for plain dialogue.
      if let pauseData = element.glosaPausePoints {
        let pauses = try JSONDecoder().decode([PausePointDTO].self, from: pauseData)
        #expect(pauses.isEmpty)
      }
    }
  }
}
