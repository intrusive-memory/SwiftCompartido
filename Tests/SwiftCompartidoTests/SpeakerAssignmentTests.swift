//
//  SpeakerAssignmentTests.swift
//  SwiftCompartidoTests
//
//  Parse-time speaker assignment (CP-P1, Schema V3).
//

import Foundation
import SwiftData
import Testing

@testable import SwiftCompartido

@Suite("Speaker Assignment")
struct SpeakerAssignmentTests {

  private static let script = """
    INT. KITCHEN - DAY

    Bernard pours coffee.

    BERNARD (V.O.)
    (quietly)
    Morning.

    SYLVIA
    You're up early.

    BRICK
    Screw retirement.

    STEEL ^
    Screw retirement.

    Sylvia leaves.

    EXT. GARDEN - NIGHT

    BERNARD (CONT'D)
    Still here.
    """

  @MainActor
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

  /// Verifies speaker values on a document's sorted elements.
  private func verifySpeakers(_ elements: [GuionElementModel]) {
    for element in elements {
      switch element.elementType {
      case .dialogue, .parenthetical:
        #expect(element.speaker != nil, "\(element.elementText) should have a speaker")
      default:
        #expect(element.speaker == nil, "\(element.elementType) should have nil speaker")
      }
    }

    let dialogue = elements.filter { $0.elementType == .dialogue }
    #expect(dialogue.map(\.elementText) == [
      "Morning.", "You're up early.", "Screw retirement.", "Screw retirement.", "Still here.",
    ])
    #expect(dialogue.map(\.speaker) == ["BERNARD", "SYLVIA", "BRICK", "STEEL", "BERNARD"])

    let parenthetical = elements.filter { $0.elementType == .parenthetical }
    #expect(parenthetical.count == 1)
    #expect(parenthetical.first?.speaker == "BERNARD")
  }

  @Test("Static helper assigns speakers only to dialogue and parentheticals")
  func staticHelper() throws {
    let screenplay = try GuionParsedElementCollection(string: Self.script)
    let speakers = GuionParsedElementCollection.speakers(for: screenplay.elements)
    #expect(speakers.count == screenplay.elements.count)
    for (element, speaker) in zip(screenplay.elements, speakers) {
      switch element.elementType {
      case .dialogue, .parenthetical:
        #expect(speaker != nil)
      default:
        #expect(speaker == nil)
      }
    }
  }

  @Test("Dual dialogue cues are both marked and each speaker is kept")
  func dualDialogueParse() throws {
    let screenplay = try GuionParsedElementCollection(string: Self.script)
    let dualCues = screenplay.elements.filter {
      $0.elementType == .character && $0.isDualDialogue
    }
    #expect(dualCues.map(\.elementText) == ["BRICK", "STEEL"])
  }

  @Test("In-memory parse populates speaker on GuionElementModel")
  @MainActor
  func inMemoryParse() async throws {
    let screenplay = try await GuionParsedElementCollection(string: Self.script)
    let container = try makeContainer()
    let context = container.mainContext
    let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)
    verifySpeakers(document.sortedElements)
  }

  @Test("SwiftData predicate can select a character's lines")
  @MainActor
  func predicateOnSpeaker() async throws {
    let screenplay = try await GuionParsedElementCollection(string: Self.script)
    let container = try makeContainer()
    let context = container.mainContext
    let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)
    context.insert(document)
    try context.save()

    let name = "BERNARD"
    let descriptor = FetchDescriptor<GuionElementModel>(
      predicate: #Predicate { $0.speaker == name },
      sortBy: [SortDescriptor(\.chapterIndex), SortDescriptor(\.orderIndex)]
    )
    let lines = try context.fetch(descriptor)
    #expect(lines.map(\.elementText) == ["(quietly)", "Morning.", "Still here."])
  }

  @Test("Snapshot round-trip re-derives speaker")
  @MainActor
  func snapshotRoundTrip() async throws {
    let screenplay = try await GuionParsedElementCollection(string: Self.script)
    let container = try makeContainer()
    let context = container.mainContext
    let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: context)
    let snapshot = document.toSnapshot()

    let restored = GuionDocumentModel.from(snapshot, in: context)
    verifySpeakers(restored.sortedElements)
  }
}
