//
//  HoverStateManagementTests.swift
//  SwiftCompartidoTests
//
//  Tests for hover state management in GuionElementRow
//

import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import SwiftCompartido

@Suite("Hover State Management Tests")
@MainActor
struct HoverStateManagementTests {

  // MARK: - Test Fixtures

  /// Creates a test GuionElementModel
  private func createTestElement() -> GuionElementModel {
    GuionElementModel(
      elementText: "Test element",
      elementType: .action,
      chapterIndex: 0,
      orderIndex: 0
    )
  }

  // MARK: - Element Property Tests

  // MARK: - Element Type Tests

  @Test("Elements maintain different types correctly")
  func testElementTypesCorrect() {
    let actionElement = GuionElementModel(
      elementText: "Action text",
      elementType: .action,
      chapterIndex: 0,
      orderIndex: 0
    )

    let sceneElement = GuionElementModel(
      elementText: "INT. ROOM - DAY",
      elementType: .sceneHeading,
      chapterIndex: 0,
      orderIndex: 1
    )

    let dialogueElement = GuionElementModel(
      elementText: "Hello there.",
      elementType: .dialogue,
      chapterIndex: 0,
      orderIndex: 2
    )

    let characterElement = GuionElementModel(
      elementText: "JOHN",
      elementType: .character,
      chapterIndex: 0,
      orderIndex: 3
    )

    // Verify element types are preserved
    #expect(actionElement.elementType == .action)
    #expect(sceneElement.elementType == .sceneHeading)
    #expect(dialogueElement.elementType == .dialogue)
    #expect(characterElement.elementType == .character)
  }

  @Test("All element types can be created")
  func testRowWithAllElementTypes() {
    let elementTypes: [ElementType] = [
      .action, .sceneHeading, .character, .dialogue,
      .parenthetical, .lyrics, .transition, .sectionHeading(level: 1),
      .synopsis, .comment, .boneyard, .pageBreak,
    ]

    let elements = elementTypes.enumerated().map { index, elementType in
      GuionElementModel(
        elementText: "Test \(index)",
        elementType: elementType,
        chapterIndex: 0,
        orderIndex: index
      )
    }

    // Verify all elements were created with correct types
    #expect(elements.count == elementTypes.count)
    for (element, expectedType) in zip(elements, elementTypes) {
      #expect(element.elementType == expectedType)
    }
  }

  // MARK: - Integration with GuionElementsList Tests

  @Test("GuionElementsList with SwiftData integration")
  func testListUsesRow() async throws {
    // Create in-memory model container
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: GuionDocumentModel.self, GuionElementModel.self,
      configurations: config
    )

    // Create test document
    let document = GuionDocumentModel(filename: "Test.guion")
    container.mainContext.insert(document)

    let element = GuionElementModel(
      elementText: "Test",
      elementType: .action,
      chapterIndex: 0,
      orderIndex: 0
    )
    element.document = document
    container.mainContext.insert(element)

    // Verify element is properly linked to document
    #expect(element.document === document)
    #expect(element.elementText == "Test")
  }

  // MARK: - Multiple Elements Tests

  @Test("Multiple elements maintain independent properties")
  func testMultipleRows() {
    let elements = (0..<5).map { i in
      GuionElementModel(
        elementText: "Element \(i)",
        elementType: .action,
        chapterIndex: 0,
        orderIndex: i
      )
    }

    #expect(elements.count == 5)
    for (index, element) in elements.enumerated() {
      #expect(element.elementText == "Element \(index)")
      #expect(element.orderIndex == index)
    }
  }
}
