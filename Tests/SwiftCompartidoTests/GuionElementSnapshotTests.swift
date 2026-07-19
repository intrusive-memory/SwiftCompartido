//
//  GuionElementSnapshotTests.swift
//  SwiftCompartidoTests
//
//  Unit tests for GuionElementSnapshot (Phase 1)
//

import XCTest

@testable import SwiftCompartido

final class GuionElementSnapshotTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInit_MinimalElement() {
    let snapshot = GuionElementSnapshot(
      elementText: "Test",
      elementType: .action
    )

    XCTAssertNotNil(snapshot.id)
    XCTAssertEqual(snapshot.chapterIndex, 0)
    XCTAssertEqual(snapshot.orderIndex, 0)
    XCTAssertEqual(snapshot.elementText, "Test")
    XCTAssertEqual(snapshot.elementType, .action)
    XCTAssertFalse(snapshot.isCentered)
    XCTAssertFalse(snapshot.isDualDialogue)
    XCTAssertNil(snapshot.sceneNumber)
    XCTAssertNil(snapshot.sceneId)
    XCTAssertNil(snapshot.summary)
    XCTAssertNil(snapshot.cachedSceneLocation)
    XCTAssertNil(snapshot.generatedContent)
  }

  func testInit_CompleteElement() {
    let id = UUID()
    let sceneLocation = SceneLocation(
      lighting: .interior,
      scene: "COFFEE SHOP",
      timeOfDay: "DAY",
      originalText: "INT. COFFEE SHOP - DAY"
    )

    let snapshot = GuionElementSnapshot(
      id: id,
      chapterIndex: 1,
      orderIndex: 5,
      elementText: "INT. COFFEE SHOP - DAY",
      elementType: .sceneHeading,
      isCentered: false,
      isDualDialogue: false,
      sceneNumber: "1A",
      sectionDepth: 0,
      sceneId: "scene-1",
      summary: "Opening scene",
      cachedSceneLocation: sceneLocation,
      generatedContent: nil
    )

    XCTAssertEqual(snapshot.id, id)
    XCTAssertEqual(snapshot.chapterIndex, 1)
    XCTAssertEqual(snapshot.orderIndex, 5)
    XCTAssertEqual(snapshot.elementText, "INT. COFFEE SHOP - DAY")
    XCTAssertEqual(snapshot.elementType, .sceneHeading)
    XCTAssertEqual(snapshot.sceneNumber, "1A")
    XCTAssertEqual(snapshot.sceneId, "scene-1")
    XCTAssertEqual(snapshot.summary, "Opening scene")
    XCTAssertEqual(snapshot.cachedSceneLocation?.scene, "COFFEE SHOP")
    XCTAssertEqual(snapshot.cachedSceneLocation?.lighting, .interior)
  }

  func testInit_FromGuionElement() {
    var element = GuionElement(
      elementType: .sceneHeading,
      elementText: "INT. OFFICE - DAY"
    )
    element.sceneNumber = "2"
    element.sceneId = "scene-2"

    let snapshot = GuionElementSnapshot(from: element, orderIndex: 10)

    XCTAssertEqual(snapshot.chapterIndex, 0)
    XCTAssertEqual(snapshot.orderIndex, 10)
    XCTAssertEqual(snapshot.elementText, "INT. OFFICE - DAY")
    XCTAssertEqual(snapshot.elementType, ElementType.sceneHeading)
    XCTAssertEqual(snapshot.sceneNumber, "2")
    XCTAssertEqual(snapshot.sceneId, "scene-2")
  }

  // MARK: - Voice Generation Tests

  func testSpeakableText_WithoutStageDirections() {
    let snapshot = GuionElementSnapshot(
      elementText: "Hello, world!",
      elementType: .dialogue
    )

    XCTAssertEqual(snapshot.speakableText, "Hello, world!")
  }

  func testSpeakableText_RemovesStageDirections() {
    let snapshot = GuionElementSnapshot(
      elementText: "Hello {{whispers}} world {{nervously}} there!",
      elementType: .dialogue
    )

    XCTAssertEqual(snapshot.speakableText, "Hello  world  there!")
  }

  func testSpeakableText_MultipleStageDirections() {
    let snapshot = GuionElementSnapshot(
      elementText: "{{angry}} Stop {{pauses}} right {{shouts}} there!",
      elementType: .dialogue
    )

    // Should remove all {{stage directions}}
    let speakable = snapshot.speakableText
    XCTAssertFalse(speakable.contains("{{"))
    XCTAssertFalse(speakable.contains("}}"))
  }

  func testSpeakableText_RemovesMultiLineStageDirections() {
    // A {{ … }} block can span multiple lines (e.g. a Slugline document-
    // settings trailer glued to the end of a line). The whole block must be
    // removed, not just its opening/closing lines.
    let snapshot = GuionElementSnapshot(
      elementText: """
        Hold on to your soul.
        {{Slugline Document Settings
        Scene Headings Double Spaced: yes
        Print Font: Courier Prime
        Note Color 8: TODO}}
        """,
      elementType: .dialogue
    )

    let speakable = snapshot.speakableText
    XCTAssertEqual(speakable, "Hold on to your soul.")
    XCTAssertFalse(speakable.contains("{{"))
    XCTAssertFalse(speakable.contains("}}"))
    XCTAssertFalse(speakable.contains("Print Font"))
  }

  func testSpeakableText_MultiLineBlockOnlyYieldsEmpty() {
    // An element that is nothing but a multi-line {{ … }} block has no spoken
    // content once the block is removed.
    let snapshot = GuionElementSnapshot(
      elementText: "{{Slugline Document Settings\nPrint Font: Courier Prime\nNote Color 8: TODO}}",
      elementType: .action
    )

    XCTAssertEqual(snapshot.speakableText, "")
  }

  func testCharacterName_FromCharacterElement() {
    let snapshot = GuionElementSnapshot(
      elementText: "JANE",
      elementType: .character
    )

    XCTAssertEqual(snapshot.characterName, "JANE")
  }

  func testCharacterName_FromCharacterElementWithWhitespace() {
    let snapshot = GuionElementSnapshot(
      elementText: "  john  ",
      elementType: .character
    )

    XCTAssertEqual(snapshot.characterName, "JOHN")  // Should be trimmed and uppercased
  }

  func testCharacterName_NonCharacterElement() {
    let snapshot = GuionElementSnapshot(
      elementText: "Hello",
      elementType: .dialogue
    )

    XCTAssertNil(snapshot.characterName)
  }

  func testCharacterName_ActionElement() {
    let snapshot = GuionElementSnapshot(
      elementText: "JANE enters the room.",
      elementType: .action
    )

    XCTAssertNil(snapshot.characterName)
  }

  // MARK: - Generated Content Tests

  func testGeneratedContent_Storage() {
    let contentID = UUID()
    var snapshot = GuionElementSnapshot(
      elementText: "Hello",
      elementType: .dialogue
    )

    snapshot.generatedContent = [
      contentID: TypedDataStorageSnapshot(
        providerId: "elevenlabs",
        requestorID: "tts.rachel",
        mimeType: "audio/mpeg",
        prompt: "Generate speech",
        binaryValue: Data([1, 2, 3, 4]),
        durationSeconds: 2.5,
        voiceID: "rachel",
        voiceName: "Rachel"
      )
    ]

    XCTAssertEqual(snapshot.generatedContent?.count, 1)
    XCTAssertEqual(snapshot.generatedContent?[contentID]?.voiceName, "Rachel")
    XCTAssertEqual(snapshot.generatedContent?[contentID]?.durationSeconds, 2.5)
  }

  // MARK: - Codable Tests

  func testCodable_SimpleElement() throws {
    let snapshot = GuionElementSnapshot(
      elementText: "Test action",
      elementType: .action
    )

    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(GuionElementSnapshot.self, from: data)

    XCTAssertEqual(decoded.id, snapshot.id)
    XCTAssertEqual(decoded.elementText, snapshot.elementText)
    XCTAssertEqual(decoded.elementType, snapshot.elementType)
  }

  func testCodable_SceneHeading() throws {
    let snapshot = GuionElementSnapshot(
      elementText: "INT. COFFEE SHOP - DAY",
      elementType: .sceneHeading,
      sceneNumber: "1"
    )

    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(GuionElementSnapshot.self, from: data)

    XCTAssertEqual(decoded.elementText, "INT. COFFEE SHOP - DAY")
    XCTAssertEqual(decoded.elementType, .sceneHeading)
    XCTAssertEqual(decoded.sceneNumber, "1")
  }

  func testCodable_WithSceneLocation() throws {
    let location = SceneLocation(
      lighting: .interior,
      scene: "COFFEE SHOP",
      timeOfDay: "DAY",
      originalText: "INT. COFFEE SHOP - DAY"
    )

    let snapshot = GuionElementSnapshot(
      elementText: "INT. COFFEE SHOP - DAY",
      elementType: .sceneHeading,
      cachedSceneLocation: location
    )

    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(GuionElementSnapshot.self, from: data)

    XCTAssertEqual(decoded.cachedSceneLocation?.scene, "COFFEE SHOP")
    XCTAssertEqual(decoded.cachedSceneLocation?.lighting, .interior)
    XCTAssertEqual(decoded.cachedSceneLocation?.timeOfDay, "DAY")
  }

  func testCodable_WithGeneratedContent() throws {
    let contentID = UUID()
    var snapshot = GuionElementSnapshot(
      elementText: "Hello",
      elementType: .dialogue
    )

    snapshot.generatedContent = [
      contentID: TypedDataStorageSnapshot(
        providerId: "elevenlabs",
        requestorID: "tts.rachel",
        mimeType: "audio/mpeg",
        prompt: "Generate speech",
        binaryValue: Data([1, 2, 3]),
        durationSeconds: 2.5
      )
    ]

    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(GuionElementSnapshot.self, from: data)

    XCTAssertEqual(decoded.generatedContent?.count, 1)
    XCTAssertEqual(decoded.generatedContent?[contentID]?.durationSeconds, 2.5)
  }

  func testCodable_AllElementTypes() throws {
    let types: [ElementType] = [
      .action,
      .character,
      .dialogue,
      .parenthetical,
      .sceneHeading,
      .transition,
      .lyrics,
      .pageBreak,
      .sectionHeading(level: 1),
      .sectionHeading(level: 2),
    ]

    for elementType in types {
      let snapshot = GuionElementSnapshot(
        elementText: "Test",
        elementType: elementType
      )

      let data = try JSONEncoder().encode(snapshot)
      let decoded = try JSONDecoder().decode(GuionElementSnapshot.self, from: data)

      XCTAssertEqual(
        decoded.elementType, elementType,
        "Failed for type: \(elementType)")
    }
  }

  func testCodable_CenteredElements() throws {
    let snapshot = GuionElementSnapshot(
      elementText: "FADE IN:",
      elementType: .transition,
      isCentered: true
    )

    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(GuionElementSnapshot.self, from: data)

    XCTAssertTrue(decoded.isCentered)
  }

  func testCodable_DualDialogue() throws {
    let snapshot = GuionElementSnapshot(
      elementText: "Hello!",
      elementType: .dialogue,
      isDualDialogue: true
    )

    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(GuionElementSnapshot.self, from: data)

    XCTAssertTrue(decoded.isDualDialogue)
  }

  func testCodable_RoundTrip() throws {
    let original = createComplexElement()

    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(GuionElementSnapshot.self, from: data)

    XCTAssertEqual(decoded.id, original.id)
    XCTAssertEqual(decoded.chapterIndex, original.chapterIndex)
    XCTAssertEqual(decoded.orderIndex, original.orderIndex)
    XCTAssertEqual(decoded.elementText, original.elementText)
    XCTAssertEqual(decoded.elementType, original.elementType)
    XCTAssertEqual(decoded.sceneNumber, original.sceneNumber)
    XCTAssertEqual(decoded.sceneId, original.sceneId)
  }

  // MARK: - Helper Methods

  private func createComplexElement() -> GuionElementSnapshot {
    GuionElementSnapshot(
      chapterIndex: 2,
      orderIndex: 15,
      elementText: "INT. COFFEE SHOP - DAY",
      elementType: .sceneHeading,
      isCentered: false,
      isDualDialogue: false,
      sceneNumber: "3A",
      sectionDepth: 0,
      sceneId: "scene-3a",
      summary: "Complex scene",
      cachedSceneLocation: SceneLocation(
        lighting: .interior,
        scene: "COFFEE SHOP",
        timeOfDay: "DAY",
        originalText: "INT. COFFEE SHOP - DAY"
      ),
      generatedContent: nil
    )
  }
}
