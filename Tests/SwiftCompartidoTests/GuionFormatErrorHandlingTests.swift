//
//  GuionFormatErrorHandlingTests.swift
//  SwiftCompartidoTests
//
//  Error handling tests for .guion file format
//  Tests that corrupted/malformed files are handled gracefully
//

import Foundation
import XCTest

@testable import SwiftCompartido

/// Error handling tests for .guion format
///
/// Validates that corrupted or malformed .guion files produce clear errors
/// instead of crashes or silent data corruption.
final class GuionFormatErrorHandlingTests: XCTestCase {

  // MARK: - Truncated JSON Tests

  func testTruncatedJSON() {
    let truncatedJSON = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "filename": "test.guion",
        "suppressSceneNumbers": false,
        "elements": [
          {
            "id": "E1111111-1111-1111-1111
      """

    let data = truncatedJSON.data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(data)) { error in
      XCTAssertTrue(error is DecodingError, "Should throw DecodingError for truncated JSON")
    }
  }

  func testTruncatedMidObject() {
    let truncatedMidObject = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "suppressSceneNumbers": false,
        "elements": [],
        "titlePage": [
      """

    let data = truncatedMidObject.data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  // MARK: - Missing Required Fields

  func testMissingIDField() {
    let jsonMissingID = """
      {
        "filename": "test.guion",
        "suppressSceneNumbers": false,
        "elements": [],
        "titlePage": []
      }
      """

    let data = jsonMissingID.data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testMissingElementsField() {
    let jsonMissingElements = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "suppressSceneNumbers": false,
        "titlePage": []
      }
      """

    let data = jsonMissingElements.data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testMissingTitlePageField() {
    let jsonMissingTitlePage = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "suppressSceneNumbers": false,
        "elements": []
      }
      """

    let data = jsonMissingTitlePage.data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testMissingSuppressSceneNumbersField() {
    let jsonMissingFlag = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "elements": [],
        "titlePage": []
      }
      """

    let data = jsonMissingFlag.data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  // MARK: - Invalid UUID Format

  func testInvalidUUIDFormat() {
    let jsonInvalidUUID = """
      {
        "id": "not-a-valid-uuid",
        "suppressSceneNumbers": false,
        "elements": [],
        "titlePage": []
      }
      """

    let data = jsonInvalidUUID.data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testInvalidElementUUID() {
    let jsonInvalidElementID = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "suppressSceneNumbers": false,
        "elements": [
          {
            "id": "invalid-uuid-format",
            "chapterIndex": 0,
            "orderIndex": 1,
            "elementText": "Test",
            "elementType": { "case": "action" },
            "isCentered": false,
            "isDualDialogue": false,
            "sectionDepth": 0
          }
        ],
        "titlePage": []
      }
      """

    let data = jsonInvalidElementID.data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  // MARK: - Negative Indices

  func testNegativeChapterIndex() {
    let jsonNegativeChapter = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "suppressSceneNumbers": false,
        "elements": [
          {
            "id": "E1111111-1111-1111-1111-111111111111",
            "chapterIndex": -1,
            "orderIndex": 1,
            "elementText": "Test",
            "elementType": { "case": "action" },
            "isCentered": false,
            "isDualDialogue": false,
            "sectionDepth": 0
          }
        ],
        "titlePage": []
      }
      """

    let data = jsonNegativeChapter.data(using: .utf8)!

    // Negative indices are technically valid integers, so this will decode
    // but we should verify the value is preserved
    XCTAssertNoThrow(try GuionJSONSerializer.decode(data))

    let snapshot = try! GuionJSONSerializer.decode(data)
    XCTAssertEqual(snapshot.elements[0].chapterIndex, -1)
  }

  func testNegativeOrderIndex() {
    let jsonNegativeOrder = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "suppressSceneNumbers": false,
        "elements": [
          {
            "id": "E1111111-1111-1111-1111-111111111111",
            "chapterIndex": 0,
            "orderIndex": -5,
            "elementText": "Test",
            "elementType": { "case": "action" },
            "isCentered": false,
            "isDualDialogue": false,
            "sectionDepth": 0
          }
        ],
        "titlePage": []
      }
      """

    let data = jsonNegativeOrder.data(using: .utf8)!

    // Negative order is preserved (no validation at decode time)
    XCTAssertNoThrow(try GuionJSONSerializer.decode(data))

    let snapshot = try! GuionJSONSerializer.decode(data)
    XCTAssertEqual(snapshot.elements[0].orderIndex, -5)
  }

  // MARK: - Type Mismatches

  func testSuppressSceneNumbersWrongType() {
    let jsonWrongType = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "suppressSceneNumbers": "yes",
        "elements": [],
        "titlePage": []
      }
      """

    let data = jsonWrongType.data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testElementsWrongType() {
    let jsonElementsString = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "suppressSceneNumbers": false,
        "elements": "not an array",
        "titlePage": []
      }
      """

    let data = jsonElementsString.data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testChapterIndexWrongType() {
    let jsonChapterString = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "suppressSceneNumbers": false,
        "elements": [
          {
            "id": "E1111111-1111-1111-1111-111111111111",
            "chapterIndex": "zero",
            "orderIndex": 1,
            "elementText": "Test",
            "elementType": { "case": "action" },
            "isCentered": false,
            "isDualDialogue": false,
            "sectionDepth": 0
          }
        ],
        "titlePage": []
      }
      """

    let data = jsonChapterString.data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  // MARK: - Malformed Dates

  func testMalformedCreatedDate() {
    let jsonBadDate = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "created": "not-a-date",
        "suppressSceneNumbers": false,
        "elements": [],
        "titlePage": []
      }
      """

    let data = jsonBadDate.data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testInvalidISO8601Date() {
    let jsonInvalidDate = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "created": "2024-13-45T99:99:99Z",
        "suppressSceneNumbers": false,
        "elements": [],
        "titlePage": []
      }
      """

    let data = jsonInvalidDate.data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  // MARK: - Empty Element Text

  func testEmptyElementTextAllowed() {
    // Empty element text should be allowed (e.g., blank lines)
    let jsonEmptyText = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "suppressSceneNumbers": false,
        "elements": [
          {
            "id": "E1111111-1111-1111-1111-111111111111",
            "chapterIndex": 0,
            "orderIndex": 1,
            "elementText": "",
            "elementType": { "case": "action" },
            "isCentered": false,
            "isDualDialogue": false,
            "sectionDepth": 0
          }
        ],
        "titlePage": []
      }
      """

    let data = jsonEmptyText.data(using: .utf8)!

    XCTAssertNoThrow(try GuionJSONSerializer.decode(data))

    let snapshot = try! GuionJSONSerializer.decode(data)
    XCTAssertEqual(snapshot.elements[0].elementText, "")
  }

  // MARK: - Duplicate Element IDs

  func testDuplicateElementIDs() {
    // Duplicate IDs should decode (no uniqueness validation at decode time)
    let jsonDuplicateIDs = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "suppressSceneNumbers": false,
        "elements": [
          {
            "id": "E1111111-1111-1111-1111-111111111111",
            "chapterIndex": 0,
            "orderIndex": 1,
            "elementText": "First",
            "elementType": { "case": "action" },
            "isCentered": false,
            "isDualDialogue": false,
            "sectionDepth": 0
          },
          {
            "id": "E1111111-1111-1111-1111-111111111111",
            "chapterIndex": 0,
            "orderIndex": 2,
            "elementText": "Second (duplicate ID)",
            "elementType": { "case": "action" },
            "isCentered": false,
            "isDualDialogue": false,
            "sectionDepth": 0
          }
        ],
        "titlePage": []
      }
      """

    let data = jsonDuplicateIDs.data(using: .utf8)!

    // Should decode - uniqueness is enforced at app level, not format level
    XCTAssertNoThrow(try GuionJSONSerializer.decode(data))

    let snapshot = try! GuionJSONSerializer.decode(data)
    XCTAssertEqual(snapshot.elements.count, 2)
    XCTAssertEqual(snapshot.elements[0].id, snapshot.elements[1].id)
  }

  // MARK: - Oversized Content

  func testVeryLargeElementText() {
    // Test that very large text content doesn't cause issues
    let largeText = String(repeating: "A", count: 100_000)

    let jsonLargeText = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "suppressSceneNumbers": false,
        "elements": [
          {
            "id": "E1111111-1111-1111-1111-111111111111",
            "chapterIndex": 0,
            "orderIndex": 1,
            "elementText": "\(largeText)",
            "elementType": { "case": "action" },
            "isCentered": false,
            "isDualDialogue": false,
            "sectionDepth": 0
          }
        ],
        "titlePage": []
      }
      """

    let data = jsonLargeText.data(using: .utf8)!

    XCTAssertNoThrow(try GuionJSONSerializer.decode(data))

    let snapshot = try! GuionJSONSerializer.decode(data)
    XCTAssertEqual(snapshot.elements[0].elementText.count, 100_000)
  }

  // MARK: - Invalid JSON Structure

  func testNotJSON() {
    let notJSON = "This is not JSON at all!".data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(notJSON)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testJSONArray() {
    // Root must be object, not array
    let jsonArray = "[]".data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(jsonArray)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testJSONString() {
    // Root must be object, not string
    let jsonString = "\"test\"".data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(jsonString)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  // MARK: - Binary Data Corruption

  func testRandomBinaryData() {
    // Random binary data should fail to decode
    var randomBytes = Data(count: 1000)
    randomBytes.withUnsafeMutableBytes { buffer in
      for i in 0..<1000 {
        buffer[i] = UInt8.random(in: 0...255)
      }
    }

    XCTAssertThrowsError(try GuionJSONSerializer.decode(randomBytes)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testPartiallyCorruptedJSON() {
    // Start with valid JSON, corrupt the middle
    var validJSON = """
      {
        "id": "D1111111-1111-1111-1111-111111111111",
        "suppressSceneNumbers": false,
        "elements": [],
        "titlePage": []
      }
      """.data(using: .utf8)!

    // Corrupt some bytes in the middle
    validJSON[50] = 0xFF
    validJSON[51] = 0xFE

    XCTAssertThrowsError(try GuionJSONSerializer.decode(validJSON)) { error in
      // Could be DecodingError or data corruption error
      XCTAssertTrue(error is DecodingError || error is Swift.DecodingError)
    }
  }

  // MARK: - Empty File

  func testEmptyFile() {
    let emptyData = Data()

    XCTAssertThrowsError(try GuionJSONSerializer.decode(emptyData)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  // MARK: - Null Document

  func testNullAsRootObject() {
    let nullData = "null".data(using: .utf8)!

    XCTAssertThrowsError(try GuionJSONSerializer.decode(nullData)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }
}
