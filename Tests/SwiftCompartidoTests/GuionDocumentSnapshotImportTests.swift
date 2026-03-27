//
//  GuionDocumentSnapshotImportTests.swift
//  SwiftCompartidoTests
//
//  Tests for P1.3: Import Pipeline Integration
//  Verifies GuionDocumentSnapshot.init(from: GuionParsedElementCollection)
//

import XCTest

@testable import SwiftCompartido

final class GuionDocumentSnapshotImportTests: XCTestCase {

  // MARK: - Basic Conversion Tests

  func testConversion_EmptyScreenplay() {
    let screenplay = GuionParsedElementCollection(
      filename: "test.fountain",
      elements: [],
      titlePage: [],
      suppressSceneNumbers: false
    )

    let snapshot = GuionDocumentSnapshot(from: screenplay)

    XCTAssertEqual(snapshot.filename, "test.fountain")
    XCTAssertTrue(snapshot.elements.isEmpty)
    XCTAssertTrue(snapshot.titlePage.isEmpty)
    XCTAssertNil(snapshot.customPages)
    XCTAssertFalse(snapshot.suppressSceneNumbers)
    XCTAssertNotNil(snapshot.id)
    XCTAssertNotNil(snapshot.created)
    XCTAssertNotNil(snapshot.modified)
    XCTAssertNotNil(snapshot.lastImportDate)
  }

  func testConversion_BasicScreenplay() {
    let screenplay = GuionParsedElementCollection(
      filename: "script.fountain",
      elements: [
        GuionElement(elementType: .sceneHeading, elementText: "INT. COFFEE SHOP - DAY"),
        GuionElement(elementType: .action, elementText: "A quiet morning."),
        GuionElement(elementType: .character, elementText: "JANE"),
        GuionElement(elementType: .dialogue, elementText: "Hello, world!"),
      ],
      titlePage: [],
      suppressSceneNumbers: false
    )

    let snapshot = GuionDocumentSnapshot(from: screenplay)

    XCTAssertEqual(snapshot.filename, "script.fountain")
    XCTAssertEqual(snapshot.elements.count, 4)
    XCTAssertFalse(snapshot.suppressSceneNumbers)
  }

  // MARK: - Element Conversion Tests

  func testConversion_ElementsPreserveOrder() {
    let originalElements = [
      GuionElement(elementType: .sceneHeading, elementText: "SCENE 1"),
      GuionElement(elementType: .action, elementText: "Action 1"),
      GuionElement(elementType: .character, elementText: "CHARACTER 1"),
      GuionElement(elementType: .dialogue, elementText: "Dialogue 1"),
      GuionElement(elementType: .action, elementText: "Action 2"),
    ]

    let screenplay = GuionParsedElementCollection(
      elements: originalElements
    )

    let snapshot = GuionDocumentSnapshot(from: screenplay)

    XCTAssertEqual(snapshot.elements.count, 5)
    XCTAssertEqual(snapshot.elements[0].elementText, "SCENE 1")
    XCTAssertEqual(snapshot.elements[1].elementText, "Action 1")
    XCTAssertEqual(snapshot.elements[2].elementText, "CHARACTER 1")
    XCTAssertEqual(snapshot.elements[3].elementText, "Dialogue 1")
    XCTAssertEqual(snapshot.elements[4].elementText, "Action 2")
  }

  func testConversion_ElementsHaveCorrectOrderIndex() {
    let screenplay = GuionParsedElementCollection(
      elements: [
        GuionElement(elementType: .action, elementText: "First"),
        GuionElement(elementType: .action, elementText: "Second"),
        GuionElement(elementType: .action, elementText: "Third"),
      ]
    )

    let snapshot = GuionDocumentSnapshot(from: screenplay)

    XCTAssertEqual(snapshot.elements[0].orderIndex, 0)
    XCTAssertEqual(snapshot.elements[1].orderIndex, 1)
    XCTAssertEqual(snapshot.elements[2].orderIndex, 2)
  }

  func testConversion_ElementTypesPreserved() {
    let screenplay = GuionParsedElementCollection(
      elements: [
        GuionElement(elementType: .sceneHeading, elementText: "Scene"),
        GuionElement(elementType: .action, elementText: "Action"),
        GuionElement(elementType: .character, elementText: "CHARACTER"),
        GuionElement(elementType: .dialogue, elementText: "Dialogue"),
        GuionElement(elementType: .parenthetical, elementText: "(quietly)"),
        GuionElement(elementType: .transition, elementText: "FADE IN:"),
      ]
    )

    let snapshot = GuionDocumentSnapshot(from: screenplay)

    XCTAssertEqual(snapshot.elements[0].elementType, ElementType.sceneHeading)
    XCTAssertEqual(snapshot.elements[1].elementType, ElementType.action)
    XCTAssertEqual(snapshot.elements[2].elementType, ElementType.character)
    XCTAssertEqual(snapshot.elements[3].elementType, ElementType.dialogue)
    XCTAssertEqual(snapshot.elements[4].elementType, ElementType.parenthetical)
    XCTAssertEqual(snapshot.elements[5].elementType, ElementType.transition)
  }

  // MARK: - Title Page Conversion Tests

  func testConversion_TitlePageSingleEntry() {
    let screenplay = GuionParsedElementCollection(
      titlePage: [
        ["Title": ["My Screenplay"]]
      ]
    )

    let snapshot = GuionDocumentSnapshot(from: screenplay)

    XCTAssertEqual(snapshot.titlePage.count, 1)
    XCTAssertEqual(snapshot.titlePage[0].key, "TITLE")
    XCTAssertEqual(snapshot.titlePage[0].values, ["My Screenplay"])
  }

  func testConversion_TitlePageMultipleEntries() {
    let screenplay = GuionParsedElementCollection(
      titlePage: [
        ["Title": ["My Screenplay"]],
        ["Author": ["Jane Doe", "John Smith"]],
        ["Draft": ["Final Draft"]],
      ]
    )

    let snapshot = GuionDocumentSnapshot(from: screenplay)

    XCTAssertEqual(snapshot.titlePage.count, 3)

    // Find entries by key (order may vary)
    let titleEntry = snapshot.titlePage.first { $0.key == "TITLE" }
    let authorEntry = snapshot.titlePage.first { $0.key == "AUTHOR" }
    let draftEntry = snapshot.titlePage.first { $0.key == "DRAFT" }

    XCTAssertNotNil(titleEntry)
    XCTAssertEqual(titleEntry?.values, ["My Screenplay"])

    XCTAssertNotNil(authorEntry)
    XCTAssertEqual(authorEntry?.values.count, 2)

    XCTAssertNotNil(draftEntry)
    XCTAssertEqual(draftEntry?.values, ["Final Draft"])
  }

  func testConversion_TitlePageKeysNormalized() {
    let screenplay = GuionParsedElementCollection(
      titlePage: [
        ["title": ["Test"]],
        ["AUTHOR": ["Test"]],
        ["DRaFT": ["Test"]],
      ]
    )

    let snapshot = GuionDocumentSnapshot(from: screenplay)

    // All keys should be uppercased
    XCTAssertTrue(snapshot.titlePage.contains { $0.key == "TITLE" })
    XCTAssertTrue(snapshot.titlePage.contains { $0.key == "AUTHOR" })
    XCTAssertTrue(snapshot.titlePage.contains { $0.key == "DRAFT" })
  }

  // MARK: - Custom Pages Tests

  func testConversion_CustomPagesEmpty() {
    let screenplay = GuionParsedElementCollection(
      customPages: []
    )

    let snapshot = GuionDocumentSnapshot(from: screenplay)

    XCTAssertNil(snapshot.customPages)
  }

  func testConversion_CustomPagesPresent() throws {
    // Create a simple cast list page structure
    let pageDict: [String: Any] = [
      "type": "castList",
      "title": "Cast List",
      "id": UUID().uuidString,
      "position": 0,
      "printDots": true,
      "items": [],
    ]

    let customPage = try CustomPageContainer(from: pageDict)

    let screenplay = GuionParsedElementCollection(
      customPages: [customPage]
    )

    let snapshot = GuionDocumentSnapshot(from: screenplay)

    XCTAssertNotNil(snapshot.customPages)
    XCTAssertEqual(snapshot.customPages?.count, 1)
    XCTAssertEqual(snapshot.customPages?.first?.type, .castList)
  }

  // MARK: - Metadata Tests

  func testConversion_SuppressSceneNumbers() {
    let screenplay1 = GuionParsedElementCollection(suppressSceneNumbers: true)
    let screenplay2 = GuionParsedElementCollection(suppressSceneNumbers: false)

    let snapshot1 = GuionDocumentSnapshot(from: screenplay1)
    let snapshot2 = GuionDocumentSnapshot(from: screenplay2)

    XCTAssertTrue(snapshot1.suppressSceneNumbers)
    XCTAssertFalse(snapshot2.suppressSceneNumbers)
  }

  func testConversion_GeneratesUniqueID() {
    let screenplay = GuionParsedElementCollection()

    let snapshot1 = GuionDocumentSnapshot(from: screenplay)
    let snapshot2 = GuionDocumentSnapshot(from: screenplay)

    XCTAssertNotEqual(snapshot1.id, snapshot2.id)
  }

  func testConversion_SetsTimestamps() {
    let before = Date()
    let screenplay = GuionParsedElementCollection()
    let snapshot = GuionDocumentSnapshot(from: screenplay)
    let after = Date()

    XCTAssertNotNil(snapshot.created)
    XCTAssertNotNil(snapshot.modified)
    XCTAssertNotNil(snapshot.lastImportDate)

    // Timestamps should be between before and after
    if let created = snapshot.created {
      XCTAssertGreaterThanOrEqual(created, before)
      XCTAssertLessThanOrEqual(created, after)
    }
  }

  func testConversion_InitiallyNilFields() {
    let screenplay = GuionParsedElementCollection()
    let snapshot = GuionDocumentSnapshot(from: screenplay)

    XCTAssertNil(snapshot.title)
    XCTAssertNil(snapshot.generatedContent)
    XCTAssertNil(snapshot.casting)
    XCTAssertNil(snapshot.sourceFileBookmark)
    XCTAssertNil(snapshot.sourceFileModificationDate)
    XCTAssertNil(snapshot.lastOpenedDate)
  }

  // MARK: - Large Document Tests

  func testConversion_LargeScreenplay() {
    // Create a 1000-element screenplay
    let elements = (0..<1000).map { index in
      GuionElement(
        elementType: .action,
        elementText: "Element \(index)"
      )
    }

    let screenplay = GuionParsedElementCollection(elements: elements)
    let snapshot = GuionDocumentSnapshot(from: screenplay)

    XCTAssertEqual(snapshot.elements.count, 1000)
    XCTAssertEqual(snapshot.elements.first?.elementText, "Element 0")
    XCTAssertEqual(snapshot.elements.last?.elementText, "Element 999")
    XCTAssertEqual(snapshot.elements.first?.orderIndex, 0)
    XCTAssertEqual(snapshot.elements.last?.orderIndex, 999)
  }

  // MARK: - Real-World Scenario Tests

  func testConversion_CompleteScreenplay() {
    let screenplay = GuionParsedElementCollection(
      filename: "complete.fountain",
      elements: [
        GuionElement(elementType: .sceneHeading, elementText: "INT. COFFEE SHOP - DAY"),
        GuionElement(elementType: .action, elementText: "JANE sits at a table."),
        GuionElement(elementType: .character, elementText: "JANE"),
        GuionElement(elementType: .dialogue, elementText: "I need coffee."),
        GuionElement(elementType: .action, elementText: "JOHN enters."),
        GuionElement(elementType: .character, elementText: "JOHN"),
        GuionElement(elementType: .dialogue, elementText: "Good morning!"),
      ],
      titlePage: [
        ["Title": ["Coffee Shop"]],
        ["Author": ["Test Writer"]],
      ],
      suppressSceneNumbers: false,
      customPages: []
    )

    let snapshot = GuionDocumentSnapshot(from: screenplay)

    // Verify all components
    XCTAssertEqual(snapshot.filename, "complete.fountain")
    XCTAssertEqual(snapshot.elements.count, 7)
    XCTAssertEqual(snapshot.titlePage.count, 2)
    XCTAssertNil(snapshot.customPages)
    XCTAssertFalse(snapshot.suppressSceneNumbers)

    // Verify element preservation
    XCTAssertEqual(snapshot.elements[0].elementType, ElementType.sceneHeading)
    XCTAssertEqual(snapshot.elements[2].elementType, ElementType.character)
    XCTAssertEqual(snapshot.elements[3].elementType, ElementType.dialogue)
  }
}
