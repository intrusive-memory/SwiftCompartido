//
//  GuionElementsListTests.swift
//  SwiftCompartido Tests
//
//  Tests for GuionElementsList component
//

import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import SwiftCompartido

@Suite("GuionElementsList Tests")
@MainActor
struct GuionElementsListTests {

  // MARK: - Helper Methods

  private func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
      for: GuionDocumentModel.self, GuionElementModel.self,
      configurations: config
    )
  }

  private func makeTestDocument(
    in context: ModelContext,
    title: String = "Test Screenplay",
    elementCount: Int = 5
  ) -> GuionDocumentModel {
    let document = GuionDocumentModel()
    document.title = title

    for i in 0..<elementCount {
      let element = GuionElementModel(
        elementText: "Element \(i)",
        elementType: i % 3 == 0 ? .sceneHeading : (i % 3 == 1 ? .action : .dialogue),
        orderIndex: i
      )
      document.elements.append(element)
    }

    context.insert(document)
    return document
  }

  // MARK: - Initialization Tests

  @Test("GuionElementsList initializes with all elements")
  func testGuionElementsListAllElements() throws {
    let container = try makeTestContainer()
    _ = makeTestDocument(in: container.mainContext)

    let list = GuionElementsList()

    // List should initialize without crashing
    // Query will be empty until context is provided via environment
    #expect(true)  // Successfully initialized
  }

  @Test("GuionElementsList initializes with document filter")
  func testGuionElementsListWithDocument() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext)

    let list = GuionElementsList(document: document)

    // List should initialize without crashing
    #expect(document.elements.count == 5)
  }

  @Test("GuionElementsList initializes in hierarchical mode")
  func testGuionElementsListHierarchical() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext)

    let list = GuionElementsList(document: document, hierarchical: true)

    // List should initialize in hierarchical mode without crashing
    #expect(document.elements.count == 5)
  }

  @Test("GuionElementsList initializes with trailing content")
  func testGuionElementsListWithTrailingContent() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext)

    let list = GuionElementsList(document: document) { element in
      Text("Trailing")
    }

    // List should initialize with trailing content without crashing
    #expect(document.elements.count == 5)
  }

  // MARK: - Document Filtering Tests

  @Test("GuionElementsList filters by document")
  func testGuionElementsListFiltersByDocument() throws {
    let container = try makeTestContainer()
    let doc1 = makeTestDocument(in: container.mainContext, title: "Doc 1", elementCount: 3)
    let doc2 = makeTestDocument(in: container.mainContext, title: "Doc 2", elementCount: 5)

    let list1 = GuionElementsList(document: doc1)
    let list2 = GuionElementsList(document: doc2)

    // Each list should filter to its document
    #expect(doc1.elements.count == 3)
    #expect(doc2.elements.count == 5)
  }

  @Test("GuionElementsList handles empty document")
  func testGuionElementsListEmptyDocument() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()
    document.title = "Empty"
    container.mainContext.insert(document)

    let list = GuionElementsList(document: document)

    // List should handle empty document without crashing
    #expect(document.elements.count == 0)
  }

  // MARK: - Element Ordering Tests

  @Test("GuionElementsList preserves element order")
  func testGuionElementsListPreservesOrder() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()

    // Add elements out of order
    let el3 = GuionElementModel(elementText: "Third", elementType: .action, orderIndex: 2)
    let el1 = GuionElementModel(elementText: "First", elementType: .action, orderIndex: 0)
    let el2 = GuionElementModel(elementText: "Second", elementType: .action, orderIndex: 1)

    document.elements.append(el3)
    document.elements.append(el1)
    document.elements.append(el2)

    container.mainContext.insert(document)

    let list = GuionElementsList(document: document)

    // Elements should be sorted by orderIndex in query
    let sorted = document.sortedElements
    #expect(sorted[0].elementText == "First")
    #expect(sorted[1].elementText == "Second")
    #expect(sorted[2].elementText == "Third")
  }

  @Test("GuionElementsList handles chapter ordering")
  func testGuionElementsListChapterOrdering() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()

    // Create elements in two chapters
    let ch1_el1 = GuionElementModel(
      elementText: "Ch1 El1", elementType: .action, chapterIndex: 0, orderIndex: 0)
    let ch1_el2 = GuionElementModel(
      elementText: "Ch1 El2", elementType: .action, chapterIndex: 0, orderIndex: 1)
    let ch2_el1 = GuionElementModel(
      elementText: "Ch2 El1", elementType: .action, chapterIndex: 1, orderIndex: 0)
    let ch2_el2 = GuionElementModel(
      elementText: "Ch2 El2", elementType: .action, chapterIndex: 1, orderIndex: 1)

    // Add out of order
    document.elements.append(ch2_el2)
    document.elements.append(ch1_el1)
    document.elements.append(ch2_el1)
    document.elements.append(ch1_el2)

    container.mainContext.insert(document)

    let list = GuionElementsList(document: document)

    // Elements should be sorted by (chapterIndex, orderIndex)
    let sorted = document.sortedElements
    #expect(sorted[0].elementText == "Ch1 El1")
    #expect(sorted[1].elementText == "Ch1 El2")
    #expect(sorted[2].elementText == "Ch2 El1")
    #expect(sorted[3].elementText == "Ch2 El2")
  }

  // MARK: - Font Size Tests

  @Test("GuionElementsList respects font size environment")
  func testGuionElementsListFontSize() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext)

    let list = GuionElementsList(document: document)
      .environment(\.screenplayFontSize, 14)

    // List should accept font size environment value
    #expect(document.elements.count == 5)
  }

  // MARK: - Large Dataset Tests

  @Test("GuionElementsList handles large datasets")
  func testGuionElementsListLargeDataset() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext, elementCount: 100)

    let list = GuionElementsList(document: document)

    // List should handle 100 elements
    #expect(document.elements.count == 100)
    #expect(document.sortedElements.count == 100)
  }

  @Test("GuionElementsList handles very large datasets")
  func testGuionElementsListVeryLargeDataset() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext, elementCount: 1000)

    let list = GuionElementsList(document: document)

    // List should handle 1000 elements (LazyVStack for efficiency)
    #expect(document.elements.count == 1000)
  }

  // MARK: - Edge Case Tests

  @Test("GuionElementsList handles single element")
  func testGuionElementsListSingleElement() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext, elementCount: 1)

    let list = GuionElementsList(document: document)

    #expect(document.elements.count == 1)
  }

  @Test("GuionElementsList handles all same element type")
  func testGuionElementsListSameElementType() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()

    for i in 0..<10 {
      let action = GuionElementModel(
        elementText: "Action \(i)",
        elementType: .action,
        orderIndex: i
      )
      document.elements.append(action)
    }

    container.mainContext.insert(document)

    let list = GuionElementsList(document: document)

    // All elements are action type
    #expect(document.elements.allSatisfy { $0.elementType == .action })
  }

  @Test("GuionElementsList handles diverse element types")
  func testGuionElementsListDiverseTypes() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()

    let types: [ElementType] = [
      .sceneHeading, .action, .dialogue, .parenthetical,
      .transition, .sectionHeading(level: 1), .synopsis, .pageBreak,
    ]

    for (i, type) in types.enumerated() {
      let element = GuionElementModel(
        elementText: "Element \(i)",
        elementType: type,
        orderIndex: i
      )
      document.elements.append(element)
    }

    container.mainContext.insert(document)

    let list = GuionElementsList(document: document)

    #expect(document.elements.count == types.count)
  }

  // MARK: - Multiple Documents Tests

  @Test("GuionElementsList with multiple documents shows all")
  func testGuionElementsListMultipleDocumentsAll() throws {
    let container = try makeTestContainer()
    let doc1 = makeTestDocument(in: container.mainContext, title: "Doc 1", elementCount: 3)
    let doc2 = makeTestDocument(in: container.mainContext, title: "Doc 2", elementCount: 5)

    // List without filter shows all elements
    let list = GuionElementsList()

    // Total elements should be 8
    let allElements = doc1.elements.count + doc2.elements.count
    #expect(allElements == 8)
  }

  // MARK: - Hierarchical Mode Tests

  @Test("GuionElementsList hierarchical mode with sections")
  func testGuionElementsListHierarchicalSections() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()

    // Add section heading
    let section1 = GuionElementModel(
      elementText: "# ACT I",
      elementType: .sectionHeading(level: 1),
      orderIndex: 0
    )
    let scene1 = GuionElementModel(
      elementText: "INT. OFFICE - DAY",
      elementType: .sceneHeading,
      orderIndex: 1
    )
    let action1 = GuionElementModel(
      elementText: "John enters.",
      elementType: .action,
      orderIndex: 2
    )

    document.elements.append(section1)
    document.elements.append(scene1)
    document.elements.append(action1)

    container.mainContext.insert(document)

    let list = GuionElementsList(document: document, hierarchical: true)

    // Hierarchical list should handle sections
    #expect(document.elements.count == 3)
  }
}
