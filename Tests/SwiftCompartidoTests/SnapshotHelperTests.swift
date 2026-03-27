//
//  SnapshotHelperTests.swift
//  SwiftCompartidoTests
//
//  Unit tests for TitlePageEntrySnapshot and CharacterVoiceMappingSnapshot (Phase 1)
//

import XCTest

@testable import SwiftCompartido

final class TitlePageEntrySnapshotTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInit_SingleValue() {
    let snapshot = TitlePageEntrySnapshot(key: "title", values: ["My Screenplay"])

    XCTAssertEqual(snapshot.key, "TITLE")  // Should be uppercased
    XCTAssertEqual(snapshot.values, ["My Screenplay"])
  }

  func testInit_MultipleValues() {
    let snapshot = TitlePageEntrySnapshot(
      key: "author",
      values: ["Jane Doe", "John Smith"]
    )

    XCTAssertEqual(snapshot.key, "AUTHOR")
    XCTAssertEqual(snapshot.values.count, 2)
    XCTAssertTrue(snapshot.values.contains("Jane Doe"))
    XCTAssertTrue(snapshot.values.contains("John Smith"))
  }

  func testInit_KeyNormalization() {
    let snapshot1 = TitlePageEntrySnapshot(key: "title", values: ["Test"])
    let snapshot2 = TitlePageEntrySnapshot(key: "TITLE", values: ["Test"])
    let snapshot3 = TitlePageEntrySnapshot(key: "TiTlE", values: ["Test"])

    XCTAssertEqual(snapshot1.key, "TITLE")
    XCTAssertEqual(snapshot2.key, "TITLE")
    XCTAssertEqual(snapshot3.key, "TITLE")
  }

  // MARK: - Codable Tests

  func testCodable_SingleValue() throws {
    let original = TitlePageEntrySnapshot(key: "TITLE", values: ["My Screenplay"])

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(TitlePageEntrySnapshot.self, from: data)

    XCTAssertEqual(decoded.key, original.key)
    XCTAssertEqual(decoded.values, original.values)
  }

  func testCodable_MultipleValues() throws {
    let original = TitlePageEntrySnapshot(
      key: "AUTHOR",
      values: ["Jane Doe", "John Smith", "Alice Johnson"]
    )

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(TitlePageEntrySnapshot.self, from: data)

    XCTAssertEqual(decoded.values.count, 3)
    XCTAssertEqual(decoded.values, original.values)
  }

  func testCodable_EmptyValues() throws {
    let original = TitlePageEntrySnapshot(key: "NOTES", values: [])

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(TitlePageEntrySnapshot.self, from: data)

    XCTAssertTrue(decoded.values.isEmpty)
  }

  func testCodable_SpecialCharacters() throws {
    let original = TitlePageEntrySnapshot(
      key: "AUTHOR",
      values: ["Author with émojis 🎬", "日本語 Author"]
    )

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(TitlePageEntrySnapshot.self, from: data)

    XCTAssertEqual(decoded.values, original.values)
  }

  // MARK: - Hashable Tests

  func testHashable_EqualSnapshots() {
    let snapshot1 = TitlePageEntrySnapshot(key: "TITLE", values: ["Test"])
    let snapshot2 = TitlePageEntrySnapshot(key: "TITLE", values: ["Test"])

    XCTAssertEqual(snapshot1, snapshot2)
    XCTAssertEqual(snapshot1.hashValue, snapshot2.hashValue)
  }

  func testHashable_DifferentSnapshots() {
    let snapshot1 = TitlePageEntrySnapshot(key: "TITLE", values: ["Test 1"])
    let snapshot2 = TitlePageEntrySnapshot(key: "TITLE", values: ["Test 2"])

    XCTAssertNotEqual(snapshot1, snapshot2)
  }
}

// MARK: - CharacterVoiceMappingSnapshot Tests

final class CharacterVoiceMappingSnapshotTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInit_MacOSVoice() {
    let snapshot = CharacterVoiceMappingSnapshot(
      voiceURI: "macos://Samantha?lang=en",
      voiceName: "Samantha",
      providerID: "macos"
    )

    XCTAssertEqual(snapshot.voiceURI, "macos://Samantha?lang=en")
    XCTAssertEqual(snapshot.voiceName, "Samantha")
    XCTAssertEqual(snapshot.providerID, "macos")
  }

  func testInit_ElevenLabsVoice() {
    let snapshot = CharacterVoiceMappingSnapshot(
      voiceURI: "elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en",
      voiceName: "Rachel",
      providerID: "elevenlabs"
    )

    XCTAssertEqual(snapshot.voiceURI, "elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en")
    XCTAssertEqual(snapshot.voiceName, "Rachel")
    XCTAssertEqual(snapshot.providerID, "elevenlabs")
  }

  func testInit_OpenAIVoice() {
    let snapshot = CharacterVoiceMappingSnapshot(
      voiceURI: "openai://alloy?lang=en",
      voiceName: "Alloy",
      providerID: "openai"
    )

    XCTAssertEqual(snapshot.voiceURI, "openai://alloy?lang=en")
    XCTAssertEqual(snapshot.voiceName, "Alloy")
    XCTAssertEqual(snapshot.providerID, "openai")
  }

  // MARK: - Codable Tests

  func testCodable_MacOSVoice() throws {
    let original = CharacterVoiceMappingSnapshot(
      voiceURI: "macos://Samantha?lang=en",
      voiceName: "Samantha",
      providerID: "macos"
    )

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(CharacterVoiceMappingSnapshot.self, from: data)

    XCTAssertEqual(decoded.voiceURI, original.voiceURI)
    XCTAssertEqual(decoded.voiceName, original.voiceName)
    XCTAssertEqual(decoded.providerID, original.providerID)
  }

  func testCodable_ElevenLabsVoice() throws {
    let original = CharacterVoiceMappingSnapshot(
      voiceURI: "elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en",
      voiceName: "Rachel",
      providerID: "elevenlabs"
    )

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(CharacterVoiceMappingSnapshot.self, from: data)

    XCTAssertEqual(decoded.voiceURI, original.voiceURI)
    XCTAssertEqual(decoded.voiceName, original.voiceName)
    XCTAssertEqual(decoded.providerID, original.providerID)
  }

  func testCodable_CustomProvider() throws {
    let original = CharacterVoiceMappingSnapshot(
      voiceURI: "custom://voice-xyz?lang=en",
      voiceName: "Custom Voice",
      providerID: "custom-provider"
    )

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(CharacterVoiceMappingSnapshot.self, from: data)

    XCTAssertEqual(decoded.providerID, "custom-provider")
  }

  func testCodable_SpecialCharactersInName() throws {
    let original = CharacterVoiceMappingSnapshot(
      voiceURI: "provider://voice-123",
      voiceName: "Voice with émojis 🎤 and 日本語",
      providerID: "test"
    )

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(CharacterVoiceMappingSnapshot.self, from: data)

    XCTAssertEqual(decoded.voiceName, original.voiceName)
  }

  // MARK: - Hashable Tests

  func testHashable_EqualMappings() {
    let mapping1 = CharacterVoiceMappingSnapshot(
      voiceURI: "macos://Samantha?lang=en",
      voiceName: "Samantha",
      providerID: "macos"
    )
    let mapping2 = CharacterVoiceMappingSnapshot(
      voiceURI: "macos://Samantha?lang=en",
      voiceName: "Samantha",
      providerID: "macos"
    )

    XCTAssertEqual(mapping1, mapping2)
    XCTAssertEqual(mapping1.hashValue, mapping2.hashValue)
  }

  func testHashable_DifferentMappings() {
    let mapping1 = CharacterVoiceMappingSnapshot(
      voiceURI: "macos://Samantha?lang=en",
      voiceName: "Samantha",
      providerID: "macos"
    )
    let mapping2 = CharacterVoiceMappingSnapshot(
      voiceURI: "macos://Alex",
      voiceName: "Alex",
      providerID: "macos"
    )

    XCTAssertNotEqual(mapping1, mapping2)
  }

  // MARK: - Integration Tests

  func testIntegration_InCastingDictionary() throws {
    var casting: [String: CharacterVoiceMappingSnapshot] = [:]

    casting["JANE"] = CharacterVoiceMappingSnapshot(
      voiceURI: "macos://Samantha?lang=en",
      voiceName: "Samantha",
      providerID: "macos"
    )
    casting["JOHN"] = CharacterVoiceMappingSnapshot(
      voiceURI: "elevenlabs://voice-123?lang=en",
      voiceName: "Adam",
      providerID: "elevenlabs"
    )

    // Encode dictionary
    let data = try JSONEncoder().encode(casting)

    // Decode dictionary
    let decoded = try JSONDecoder().decode([String: CharacterVoiceMappingSnapshot].self, from: data)

    XCTAssertEqual(decoded.count, 2)
    XCTAssertEqual(decoded["JANE"]?.voiceName, "Samantha")
    XCTAssertEqual(decoded["JOHN"]?.voiceName, "Adam")
  }
}
