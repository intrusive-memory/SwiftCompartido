//
//  CustomPageContainerTests.swift
//  SwiftCompartidoTests
//
//  Copyright (c) 2025
//

import Foundation
import Testing

@testable import SwiftCompartido

@Suite("CustomPageContainer Tests")
struct CustomPageContainerTests {

  // MARK: - Type Detection Tests

  @Test("Detects cast list type from dictionary")
  func testDetectCastListType() throws {
    let dict: [String: Any] = [
      "id": "test-id",
      "type": "castList",
      "title": "Cast List",
      "position": 0,
      "printDots": true,
      "items": [],
    ]

    let container = try CustomPageContainer(from: dict)

    #expect(container.type == .castList)
    #expect(container.id == "test-id")
    #expect(container.title == "Cast List")
    #expect(container.positionValue == 0)
  }

  @Test("Detects advanced type from dictionary")
  func testDetectAdvancedType() throws {
    let dict: [String: Any] = [
      "id": "test-id",
      "type": "advanced",
      "title": "Advanced Page",
      "position": 1,
    ]

    let container = try CustomPageContainer(from: dict)

    #expect(container.type == .advanced)
    #expect(container.id == "test-id")
  }

  @Test("Detects empty type from dictionary")
  func testDetectEmptyType() throws {
    let dict: [String: Any] = [
      "id": "test-id",
      "type": "empty",
      "title": "Blank Page",
      "position": 2,
    ]

    let container = try CustomPageContainer(from: dict)

    #expect(container.type == .empty)
  }

  @Test("Defaults to unknown type for unsupported types")
  func testUnknownType() throws {
    let dict: [String: Any] = [
      "id": "test-id",
      "type": "futuristic-hologram-page",
      "title": "Future Page",
      "position": 3,
    ]

    let container = try CustomPageContainer(from: dict)

    #expect(container.type == .unknown)
  }

  @Test("Handles missing type field")
  func testMissingType() throws {
    let dict: [String: Any] = [
      "id": "test-id",
      "title": "No Type Page",
      "position": 0,
    ]

    let container = try CustomPageContainer(from: dict)

    #expect(container.type == .unknown)
  }

  // MARK: - Cast List Conversion Tests

  @Test("Converts cast list container to CastListPage")
  func testConvertToCastList() throws {
    let dict: [String: Any] = [
      "id": "cast-id",
      "type": "castList",
      "title": "Main Cast",
      "position": 0,
      "printDots": true,
      "items": [
        [
          "id": "member-1",
          "role": "HAMLET",
          "name": "Benedict Cumberbatch",
          "position": 0,
        ],
        [
          "id": "member-2",
          "role": "OPHELIA",
          "name": "Saoirse Ronan",
          "position": 1,
        ],
      ],
    ]

    let container = try CustomPageContainer(from: dict)
    let castList = try container.asCastList()

    #expect(castList != nil)
    #expect(castList?.id == "cast-id")
    #expect(castList?.title == "Main Cast")
    #expect(castList?.printDots == true)
    #expect(castList?.items.count == 2)
    #expect(castList?.items[0].role == "HAMLET")
    #expect(castList?.items[0].name == "Benedict Cumberbatch")
  }

  @Test("Returns nil when converting non-cast list to CastListPage")
  func testConvertNonCastListReturnsNil() throws {
    let dict: [String: Any] = [
      "id": "test-id",
      "type": "advanced",
      "title": "Advanced Page",
      "position": 0,
    ]

    let container = try CustomPageContainer(from: dict)
    let castList = try container.asCastList()

    #expect(castList == nil)
  }

  // MARK: - Raw JSON Preservation Tests

  @Test("Preserves raw JSON for round-trip")
  func testRawJSONPreservation() throws {
    let dict: [String: Any] = [
      "id": "test-id",
      "type": "advanced",
      "title": "Concept Art",
      "position": 0,
      "tc": ["text": "Top Center"],
      "cc": [
        "text": "Center Image",
        "assetFilename": "concept.png",
      ],
      "customField": "custom value",
    ]

    let container = try CustomPageContainer(from: dict)
    let restored = try container.asRawJSON()

    #expect(restored["id"] as? String == "test-id")
    #expect(restored["type"] as? String == "advanced")
    #expect(restored["customField"] as? String == "custom value")

    // Verify nested structures preserved
    let cc = restored["cc"] as? [String: Any]
    #expect(cc?["assetFilename"] as? String == "concept.png")
  }

  @Test("toDictionary returns valid dictionary")
  func testToDictionary() throws {
    let dict: [String: Any] = [
      "id": "test-id",
      "type": "castList",
      "title": "Cast List",
      "position": 0,
      "printDots": false,
      "items": [],
    ]

    let container = try CustomPageContainer(from: dict)
    let exported = try container.toDictionary()

    #expect(exported["id"] as? String == "test-id")
    #expect(exported["type"] as? String == "castList")
    #expect(exported["title"] as? String == "Cast List")
    #expect(exported["printDots"] as? Bool == false)
  }

  // MARK: - Creating from Typed Pages Tests

  @Test("Creates container from CastListPage")
  func testCreateFromCastListPage() throws {
    let castList = CastListPage(
      id: "cast-id",
      title: "Main Cast",
      position: 0,
      printDots: true,
      items: [
        CastListPage.CastMember(
          id: "member-1",
          role: "BERNARD",
          name: "Jason Manino",
          position: 0
        )
      ]
    )

    let container = try CustomPageContainer(page: castList, type: .castList)

    #expect(container.type == .castList)
    #expect(container.id == "cast-id")
    #expect(container.title == "Main Cast")

    let restored = try container.asCastList()
    #expect(restored?.items.count == 1)
    #expect(restored?.items[0].role == "BERNARD")
  }

  // MARK: - Edge Cases

  @Test("Handles empty items array in cast list")
  func testEmptyCastListItems() throws {
    let dict: [String: Any] = [
      "id": "cast-id",
      "type": "castList",
      "title": "Empty Cast",
      "position": 0,
      "printDots": true,
      "items": [],
    ]

    let container = try CustomPageContainer(from: dict)
    let castList = try container.asCastList()

    #expect(castList?.items.isEmpty == true)
  }

  @Test("Handles very large cast list")
  func testLargeCastList() throws {
    var items: [[String: Any]] = []
    for i in 0..<100 {
      items.append([
        "id": "member-\(i)",
        "role": "EXTRA \(i)",
        "name": "Actor \(i)",
        "position": i,
      ])
    }

    let dict: [String: Any] = [
      "id": "cast-id",
      "type": "castList",
      "title": "Large Cast",
      "position": 0,
      "printDots": true,
      "items": items,
    ]

    let container = try CustomPageContainer(from: dict)
    let castList = try container.asCastList()

    #expect(castList?.items.count == 100)
  }

  @Test("Preserves special characters in strings")
  func testSpecialCharacters() throws {
    let dict: [String: Any] = [
      "id": "test-id",
      "type": "castList",
      "title": "Cast List — Special \"Characters\"",
      "position": 0,
      "printDots": true,
      "items": [
        [
          "id": "member-1",
          "role": "O'BRIEN",
          "name": "Seán O'Casey",
          "position": 0,
        ]
      ],
    ]

    let container = try CustomPageContainer(from: dict)
    let castList = try container.asCastList()

    #expect(castList?.title.contains("—") == true)
    #expect(castList?.items[0].role == "O'BRIEN")
    #expect(castList?.items[0].name == "Seán O'Casey")
  }
}
