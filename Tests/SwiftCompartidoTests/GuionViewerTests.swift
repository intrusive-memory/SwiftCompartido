//
//  GuionViewerTests.swift
//  SwiftCompartido Tests
//
//  Tests for GuionViewer component
//

import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import SwiftCompartido

@Suite("GuionViewer Tests")
@MainActor
struct GuionViewerTests {

  // MARK: - Helper Methods

  private func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
      for: GuionDocumentModel.self, GuionElementModel.self,
      configurations: config
    )
  }

  private func makeTestDocument(in context: ModelContext, title: String = "Test Screenplay")
    -> GuionDocumentModel
  {
    let document = GuionDocumentModel()
    document.title = title

    // Add some test elements
    let sceneHeading = GuionElementModel(
      elementText: "INT. OFFICE - DAY",
      elementType: .sceneHeading,
      orderIndex: 0
    )
    let action = GuionElementModel(
      elementText: "John sits at his desk.",
      elementType: .action,
      orderIndex: 1
    )
    let dialogue = GuionElementModel(
      elementText: "Hello, world!",
      elementType: .dialogue,
      orderIndex: 2
    )

    document.elements.append(sceneHeading)
    document.elements.append(action)
    document.elements.append(dialogue)

    context.insert(document)
    return document
  }

  // MARK: - Initialization Tests

  @Test("GuionViewer initializes with document")
  func testGuionViewerInitialization() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext)

    let viewer = GuionViewer(document: document)

    // Viewer should initialize without crashing
    #expect(document.title == "Test Screenplay")
    #expect(document.elements.count == 3)
  }

  @Test("GuionViewer handles document without title")
  func testGuionViewerWithoutTitle() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext, title: "")
    document.title = nil

    let viewer = GuionViewer(document: document)

    // Should handle nil title gracefully (displays "Untitled")
    #expect(document.title == nil)
  }

  @Test("GuionViewer handles empty document")
  func testGuionViewerEmptyDocument() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()
    document.title = "Empty Screenplay"
    container.mainContext.insert(document)

    let viewer = GuionViewer(document: document)

    // Should handle empty document without crashing
    #expect(document.elements.count == 0)
    #expect(document.title == "Empty Screenplay")
  }

  // MARK: - Document Display Tests

  @Test("GuionViewer displays elements from document")
  func testGuionViewerDisplaysElements() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext)

    let viewer = GuionViewer(document: document)

    // Document should have elements
    #expect(document.elements.count == 3)
    #expect(document.sortedElements.count == 3)

    // Elements should be in order
    let sorted = document.sortedElements
    #expect(sorted[0].elementType == .sceneHeading)
    #expect(sorted[1].elementType == .action)
    #expect(sorted[2].elementType == .dialogue)
  }

  @Test("GuionViewer uses sortedElements for ordered display")
  func testGuionViewerUsesOrderedElements() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()
    document.title = "Ordered Test"

    // Add elements out of order
    let element3 = GuionElementModel(elementText: "Third", elementType: .action, orderIndex: 2)
    let element1 = GuionElementModel(elementText: "First", elementType: .action, orderIndex: 0)
    let element2 = GuionElementModel(elementText: "Second", elementType: .action, orderIndex: 1)

    document.elements.append(element3)
    document.elements.append(element1)
    document.elements.append(element2)

    container.mainContext.insert(document)

    let viewer = GuionViewer(document: document)

    // sortedElements should be in correct order
    let sorted = document.sortedElements
    #expect(sorted[0].elementText == "First")
    #expect(sorted[1].elementText == "Second")
    #expect(sorted[2].elementText == "Third")
  }

  // MARK: - Font Size Tests

  @Test("GuionViewer supports font size environment")
  func testGuionViewerFontSizeEnvironment() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext)

    let viewer = GuionViewer(document: document)
      .environment(\.screenplayFontSize, 14)

    // View should accept font size environment value
    #expect(document.elements.count == 3)
  }

  // MARK: - Multiple Document Tests

  @Test("GuionViewer handles multiple documents")
  func testGuionViewerMultipleDocuments() throws {
    let container = try makeTestContainer()
    let doc1 = makeTestDocument(in: container.mainContext, title: "Screenplay 1")
    let doc2 = makeTestDocument(in: container.mainContext, title: "Screenplay 2")

    let viewer1 = GuionViewer(document: doc1)
    let viewer2 = GuionViewer(document: doc2)

    // Each viewer should display its own document
    #expect(doc1.title == "Screenplay 1")
    #expect(doc2.title == "Screenplay 2")
    #expect(doc1.elements.count == 3)
    #expect(doc2.elements.count == 3)
  }

  // MARK: - Large Document Tests

  @Test("GuionViewer handles large documents")
  func testGuionViewerLargeDocument() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()
    document.title = "Large Screenplay"

    // Add 100 elements
    for i in 0..<100 {
      let element = GuionElementModel(
        elementText: "Element \(i)",
        elementType: i % 2 == 0 ? .action : .dialogue,
        orderIndex: i
      )
      document.elements.append(element)
    }

    container.mainContext.insert(document)

    let viewer = GuionViewer(document: document)

    // Should handle large document without issues
    #expect(document.elements.count == 100)
    #expect(document.sortedElements.count == 100)
  }

  // MARK: - Edge Case Tests

  @Test("GuionViewer handles document with only scene headings")
  func testGuionViewerOnlySceneHeadings() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()
    document.title = "Scene Headings Only"

    for i in 0..<5 {
      let scene = GuionElementModel(
        elementText: "INT. LOCATION \(i) - DAY",
        elementType: .sceneHeading,
        orderIndex: i
      )
      document.elements.append(scene)
    }

    container.mainContext.insert(document)

    let viewer = GuionViewer(document: document)

    // Should handle scene-headings-only document
    #expect(document.elements.count == 5)
    #expect(document.sortedElements.allSatisfy { $0.elementType == .sceneHeading })
  }

  @Test("GuionViewer handles very long element text")
  func testGuionViewerLongElementText() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()
    document.title = "Long Text Test"

    let longText = String(repeating: "This is a very long line of action text. ", count: 50)
    let element = GuionElementModel(
      elementText: longText,
      elementType: .action,
      orderIndex: 0
    )
    document.elements.append(element)

    container.mainContext.insert(document)

    let viewer = GuionViewer(document: document)

    // Should handle very long text without crashing
    #expect(document.elements.count == 1)
    #expect(document.elements.first?.elementText.count ?? 0 > 1000)
  }
}
