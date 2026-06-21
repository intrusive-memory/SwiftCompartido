//
//  GuionFormatVersioningTests.swift
//  SwiftCompartidoTests
//
//  Schema version compatibility tests for .guion file format
//  Tests that .guion files maintain backward/forward compatibility
//

import Foundation
import XCTest

@testable import SwiftCompartido

/// Schema versioning tests for .guion format
///
/// Validates that .guion files created with different versions of
/// SwiftCompartido can be loaded correctly, and that unknown fields
/// are handled gracefully.
///
/// Current schema version: 1.0
final class GuionFormatVersioningTests: XCTestCase {

  // MARK: - Helper Methods

  private func loadFixture(_ name: String) throws -> Data {
    let fixtureURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Fixtures/GuionVersioning/\(name)")

    return try Data(contentsOf: fixtureURL)
  }

  // MARK: - Basic Compatibility Tests

  func testLoadV1File() throws {
    // Load a .guion file created with SwiftCompartido 7.0.4
    let v1Data = try loadFixture("v1-screenplay.guion")

    // Decode with current decoder
    let snapshot = try GuionJSONSerializer.decode(v1Data)

    // Verify basic fields preserved
    XCTAssertEqual(snapshot.title, "V1 Schema Test")
    XCTAssertEqual(snapshot.filename, "v1-screenplay.guion")
    XCTAssertEqual(snapshot.elements.count, 4)
    XCTAssertEqual(snapshot.id.uuidString, "D1111111-1111-1111-1111-111111111111")
  }

  func testV1FileRoundTrip() throws {
    // Load V1 file
    let v1Data = try loadFixture("v1-screenplay.guion")
    let originalSnapshot = try GuionJSONSerializer.decode(v1Data)

    // Round-trip: encode and decode again
    let reEncodedData = try GuionJSONSerializer.encode(originalSnapshot)
    let reDecodedSnapshot = try GuionJSONSerializer.decode(reEncodedData)

    // Verify data integrity
    XCTAssertEqual(reDecodedSnapshot.id, originalSnapshot.id)
    XCTAssertEqual(reDecodedSnapshot.title, originalSnapshot.title)
    XCTAssertEqual(reDecodedSnapshot.elements.count, originalSnapshot.elements.count)
  }

  func testV1AllFieldsPreserved() throws {
    // Load V1 file and verify ALL fields are preserved
    let v1Data = try loadFixture("v1-screenplay.guion")
    let snapshot = try GuionJSONSerializer.decode(v1Data)

    // Identity
    XCTAssertEqual(snapshot.id.uuidString, "D1111111-1111-1111-1111-111111111111")

    // Metadata
    XCTAssertEqual(snapshot.filename, "v1-screenplay.guion")
    XCTAssertEqual(snapshot.title, "V1 Schema Test")
    XCTAssertFalse(snapshot.suppressSceneNumbers)
    XCTAssertNotNil(snapshot.created)
    XCTAssertNotNil(snapshot.modified)

    // Title page
    XCTAssertEqual(snapshot.titlePage.count, 2)
    XCTAssertEqual(snapshot.titlePage[0].key, "TITLE")
    XCTAssertEqual(snapshot.titlePage[0].values, ["V1 Schema Test"])
    XCTAssertEqual(snapshot.titlePage[1].key, "AUTHOR")
    XCTAssertEqual(snapshot.titlePage[1].values, ["Test Author"])

    // Voice casting
    XCTAssertEqual(snapshot.casting?.count, 1)
    XCTAssertEqual(snapshot.casting?["JANE"]?.voiceName, "Samantha")
    XCTAssertEqual(snapshot.casting?["JANE"]?.providerID, "macos")
    XCTAssertEqual(snapshot.casting?["JANE"]?.voiceURI, "macos://Samantha?lang=en")

    // Elements
    XCTAssertEqual(snapshot.elements.count, 4)

    // Scene heading
    let sceneHeading = snapshot.elements[0]
    XCTAssertEqual(sceneHeading.elementType, .sceneHeading)
    XCTAssertEqual(sceneHeading.elementText, "INT. COFFEE SHOP - DAY")
    XCTAssertEqual(sceneHeading.sceneNumber, "1")
    XCTAssertEqual(sceneHeading.orderIndex, 1)

    // Action
    let action = snapshot.elements[1]
    XCTAssertEqual(action.elementType, .action)
    XCTAssertEqual(action.elementText, "A quiet morning. Steam rises from coffee cups.")

    // Character
    let character = snapshot.elements[2]
    XCTAssertEqual(character.elementType, .character)
    XCTAssertEqual(character.elementText, "JANE")

    // Dialogue
    let dialogue = snapshot.elements[3]
    XCTAssertEqual(dialogue.elementType, .dialogue)
    XCTAssertEqual(dialogue.elementText, "Hello, world! {{smiling}} How are you today?")
  }

  func testLoadV2File() throws {
    // Load a .guion file that includes newer fields
    let v2Data = try loadFixture("v2-screenplay.guion")

    // Should decode successfully (future fields are ignored gracefully)
    let snapshot = try GuionJSONSerializer.decode(v2Data)

    // Verify basic fields
    XCTAssertEqual(snapshot.title, "V2 Schema Test")
    XCTAssertEqual(snapshot.elements.count, 4)
    XCTAssertEqual(snapshot.id.uuidString, "D2222222-2222-2222-2222-222222222222")

    // Elements should be preserved
    let dialogue = snapshot.elements.first { $0.elementType == .dialogue }
    XCTAssertNotNil(dialogue)
    XCTAssertEqual(dialogue?.elementText, "Hello, world! {{smiling}} How are you today?")
  }

  // MARK: - Forward Compatibility Tests

  func testUnknownFieldsIgnoredGracefully() throws {
    // Create JSON with future fields that don't exist in current schema
    let jsonWithFutureFields = """
      {
        "id": "D3333333-3333-3333-3333-333333333333",
        "filename": "future.guion",
        "title": "Future Schema Test",
        "suppressSceneNumbers": false,
        "futureFieldV3": "This field doesn't exist yet",
        "futureMetadata": {
          "schemaVersion": "3.0",
          "newFeature": true
        },
        "elements": [
          {
            "id": "E5555555-5555-5555-5555-555555555555",
            "chapterIndex": 0,
            "orderIndex": 1,
            "elementText": "INT. TEST - DAY",
            "elementType": { "case": "sceneHeading" },
            "isCentered": false,
            "isDualDialogue": false,
            "sectionDepth": 0,
            "futureElementField": "Unknown element field",
            "futureArray": [1, 2, 3]
          }
        ],
        "titlePage": []
      }
      """

    let data = jsonWithFutureFields.data(using: .utf8)!

    // Should decode gracefully, ignoring unknown fields
    XCTAssertNoThrow(try GuionJSONSerializer.decode(data))

    let snapshot = try GuionJSONSerializer.decode(data)
    XCTAssertEqual(snapshot.title, "Future Schema Test")
    XCTAssertEqual(snapshot.elements.count, 1)
    XCTAssertEqual(snapshot.elements[0].elementText, "INT. TEST - DAY")
  }

  func testUnknownElementTypeThrowsError() throws {
    // Test that an unknown element type throws a decoding error
    // This is current behavior - strict validation
    let jsonWithUnknownType = """
      {
        "id": "D4444444-4444-4444-4444-444444444444",
        "filename": "unknown-type.guion",
        "suppressSceneNumbers": false,
        "elements": [
          {
            "id": "E6666666-6666-6666-6666-666666666666",
            "chapterIndex": 0,
            "orderIndex": 1,
            "elementText": "Test element",
            "elementType": { "case": "futureElementType" },
            "isCentered": false,
            "isDualDialogue": false,
            "sectionDepth": 0
          }
        ],
        "titlePage": []
      }
      """

    let data = jsonWithUnknownType.data(using: .utf8)!

    // Should throw DecodingError for unknown element type
    XCTAssertThrowsError(try GuionJSONSerializer.decode(data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  // MARK: - Optional Fields Tests

  func testMinimalValidFile() throws {
    // Test that only required fields are needed
    let minimalJSON = """
      {
        "id": "D5555555-5555-5555-5555-555555555555",
        "suppressSceneNumbers": false,
        "elements": [],
        "titlePage": []
      }
      """

    let data = minimalJSON.data(using: .utf8)!
    let snapshot = try GuionJSONSerializer.decode(data)

    XCTAssertEqual(snapshot.id.uuidString, "D5555555-5555-5555-5555-555555555555")
    XCTAssertNil(snapshot.filename)
    XCTAssertNil(snapshot.title)
    XCTAssertTrue(snapshot.elements.isEmpty)
    XCTAssertTrue(snapshot.titlePage.isEmpty)
  }

  func testOptionalFieldsDefaultToNil() throws {
    let minimalJSON = """
      {
        "id": "D6666666-6666-6666-6666-666666666666",
        "suppressSceneNumbers": false,
        "elements": [],
        "titlePage": []
      }
      """

    let data = minimalJSON.data(using: .utf8)!
    let snapshot = try GuionJSONSerializer.decode(data)

    // All optional fields should be nil
    XCTAssertNil(snapshot.filename)
    XCTAssertNil(snapshot.title)
    XCTAssertNil(snapshot.created)
    XCTAssertNil(snapshot.modified)
    XCTAssertNil(snapshot.casting)
    XCTAssertNil(snapshot.generatedContent)
    XCTAssertNil(snapshot.customPages)
    XCTAssertNil(snapshot.sourceFileBookmark)
    XCTAssertNil(snapshot.lastImportDate)
    XCTAssertNil(snapshot.sourceFileModificationDate)
    XCTAssertNil(snapshot.lastOpenedDate)
  }

  // MARK: - Date Format Tests

  func testISO8601DateParsing() throws {
    let v1Data = try loadFixture("v1-screenplay.guion")
    let snapshot = try GuionJSONSerializer.decode(v1Data)

    // Dates should be parsed correctly
    XCTAssertNotNil(snapshot.created)
    XCTAssertNotNil(snapshot.modified)

    // Verify dates are in expected range (2024-01-15)
    let calendar = Calendar.current
    if let created = snapshot.created {
      let components = calendar.dateComponents([.year, .month, .day], from: created)
      XCTAssertEqual(components.year, 2024)
      XCTAssertEqual(components.month, 1)
      XCTAssertEqual(components.day, 15)
    }
  }

  // MARK: - Format Metadata Tests

  func testFileFormatMetadata() {
    // Document current format version
    XCTAssertEqual(GuionJSONSerializer.FileFormat.version, "1.0")
    XCTAssertEqual(GuionJSONSerializer.FileFormat.fileExtension, "guion")
    XCTAssertEqual(GuionJSONSerializer.FileFormat.uti, "com.swiftguion.screenplay")
    XCTAssertEqual(GuionJSONSerializer.FileFormat.mimeType, "application/vnd.swiftguion+json")
  }

  // MARK: - Corruption Resilience Tests

  func testEmptyArraysAndStringsHandled() throws {
    let jsonWithEmpties = """
      {
        "id": "D7777777-7777-7777-7777-777777777777",
        "filename": "",
        "title": "",
        "suppressSceneNumbers": false,
        "elements": [],
        "titlePage": []
      }
      """

    let data = jsonWithEmpties.data(using: .utf8)!
    let snapshot = try GuionJSONSerializer.decode(data)

    XCTAssertEqual(snapshot.filename, "")
    XCTAssertEqual(snapshot.title, "")
    XCTAssertTrue(snapshot.elements.isEmpty)
  }

  func testExplicitNullsDecodedAsNil() throws {
    // Test that explicit null values in JSON decode to Swift nil
    let jsonWithNulls = """
      {
        "id": "D8888888-8888-8888-8888-888888888888",
        "filename": null,
        "title": null,
        "suppressSceneNumbers": false,
        "elements": [],
        "titlePage": []
      }
      """

    let data = jsonWithNulls.data(using: .utf8)!

    // Should decode successfully
    XCTAssertNoThrow(try GuionJSONSerializer.decode(data))

    let snapshot = try GuionJSONSerializer.decode(data)
    XCTAssertNil(snapshot.filename)
    XCTAssertNil(snapshot.title)
  }
}
