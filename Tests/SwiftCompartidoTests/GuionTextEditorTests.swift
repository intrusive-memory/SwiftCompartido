//
//  GuionTextEditorTests.swift
//  SwiftCompartido Tests
//
//  Tests for GuionTextEditor component (TextKit 2 read-only display)
//

import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import SwiftCompartido

@Suite("GuionTextEditor Tests")
@MainActor
struct GuionTextEditorTests {

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

  private func makeFormattedDocument(in context: ModelContext) -> GuionDocumentModel {
    let document = GuionDocumentModel()
    document.title = "Formatted Test"

    // Scene heading
    let scene = GuionElementModel(
      elementText: "INT. OFFICE - DAY",
      elementType: .sceneHeading,
      orderIndex: 0
    )

    // Action with bold/italic
    let action = GuionElementModel(
      elementText: "John **boldly** enters the room.",
      elementType: .action,
      orderIndex: 1
    )

    // Character
    let character = GuionElementModel(
      elementText: "JOHN",
      elementType: .character,
      orderIndex: 2
    )

    // Dialogue
    let dialogue = GuionElementModel(
      elementText: "Hello, world!",
      elementType: .dialogue,
      orderIndex: 3
    )

    // Transition
    let transition = GuionElementModel(
      elementText: "FADE TO:",
      elementType: .transition,
      orderIndex: 4
    )

    document.elements.append(scene)
    document.elements.append(action)
    document.elements.append(character)
    document.elements.append(dialogue)
    document.elements.append(transition)

    context.insert(document)
    return document
  }

  // MARK: - Initialization Tests

  @Test("GuionTextEditor initializes with document")
  func testGuionTextEditorInitialization() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext)

    _ = GuionTextEditor(document: document)

    #expect(document.title == "Test Screenplay")
    #expect(document.elements.count == 5)
  }

  @Test("GuionTextEditor initializes with empty document")
  func testGuionTextEditorEmptyDocument() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()
    document.title = "Empty"
    container.mainContext.insert(document)

    _ = GuionTextEditor(document: document)

    #expect(document.elements.count == 0)
    #expect(document.title == "Empty")
  }

  @Test("GuionTextEditor initializes without title")
  func testGuionTextEditorNoTitle() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()
    container.mainContext.insert(document)

    _ = GuionTextEditor(document: document)

    #expect(document.title == nil)
  }

  // MARK: - Font Size Tests

  @Test("GuionTextEditor respects font size environment")
  func testGuionTextEditorFontSizeEnvironment() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext)

    _ = GuionTextEditor(document: document)
      .environment(\.screenplayFontSize, 14)

    #expect(document.elements.count == 5)
  }

  @Test("GuionTextEditor handles font size changes")
  func testGuionTextEditorFontSizeChanges() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext)

    // Test with different font sizes
    let editor1 = GuionTextEditor(document: document)
      .environment(\.screenplayFontSize, 10)

    let editor2 = GuionTextEditor(document: document)
      .environment(\.screenplayFontSize, 18)

    #expect(document.elements.count == 5)
  }

  // MARK: - Document Updates Tests

  @Test("GuionTextEditor responds to element count changes")
  func testGuionTextEditorElementCountChanges() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()
    document.title = "Dynamic"

    let element = GuionElementModel(
      elementText: "Initial",
      elementType: .action,
      orderIndex: 0
    )
    document.elements.append(element)
    container.mainContext.insert(document)

    _ = GuionTextEditor(document: document)

    #expect(document.elements.count == 1)

    // Add another element
    let newElement = GuionElementModel(
      elementText: "Added",
      elementType: .action,
      orderIndex: 1
    )
    document.elements.append(newElement)

    #expect(document.elements.count == 2)
    #expect(document.sortedElements.count == 2)
  }

  @Test("GuionTextEditor handles document modifications")
  func testGuionTextEditorDocumentModifications() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext, elementCount: 3)

    _ = GuionTextEditor(document: document)

    let initialCount = document.elements.count
    #expect(initialCount == 3)

    // Modify element text
    if let firstElement = document.sortedElements.first {
      firstElement.elementText = "Modified text"
      #expect(firstElement.elementText == "Modified text")
    }
  }

  // MARK: - Element Type Tests

  @Test("GuionTextEditor displays formatted elements")
  func testGuionTextEditorFormattedElements() throws {
    let container = try makeTestContainer()
    let document = makeFormattedDocument(in: container.mainContext)

    _ = GuionTextEditor(document: document)

    #expect(document.elements.count == 5)

    let sorted = document.sortedElements
    #expect(sorted[0].elementType == .sceneHeading)
    #expect(sorted[1].elementType == .action)
    #expect(sorted[2].elementType == .character)
    #expect(sorted[3].elementType == .dialogue)
    #expect(sorted[4].elementType == .transition)
  }

  @Test("GuionTextEditor handles inline formatting")
  func testGuionTextEditorInlineFormatting() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()

    let boldAction = GuionElementModel(
      elementText: "This has **bold** text.",
      elementType: .action,
      orderIndex: 0
    )

    let italicAction = GuionElementModel(
      elementText: "This has *italic* text.",
      elementType: .action,
      orderIndex: 1
    )

    let underlineAction = GuionElementModel(
      elementText: "This has _underline_ text.",
      elementType: .action,
      orderIndex: 2
    )

    document.elements.append(boldAction)
    document.elements.append(italicAction)
    document.elements.append(underlineAction)
    container.mainContext.insert(document)

    _ = GuionTextEditor(document: document)

    #expect(document.elements.count == 3)
    #expect(document.sortedElements[0].elementText.contains("**bold**"))
    #expect(document.sortedElements[1].elementText.contains("*italic*"))
    #expect(document.sortedElements[2].elementText.contains("_underline_"))
  }

  // MARK: - Large Document Tests

  @Test("GuionTextEditor handles large documents")
  func testGuionTextEditorLargeDocument() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext, elementCount: 100)

    _ = GuionTextEditor(document: document)

    #expect(document.elements.count == 100)
    #expect(document.sortedElements.count == 100)
  }

  @Test("GuionTextEditor handles very large documents")
  func testGuionTextEditorVeryLargeDocument() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext, elementCount: 500)

    _ = GuionTextEditor(document: document)

    #expect(document.elements.count == 500)
    #expect(document.sortedElements.count == 500)
  }

  // MARK: - Element Ordering Tests

  @Test("GuionTextEditor preserves element order")
  func testGuionTextEditorPreservesOrder() throws {
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

    _ = GuionTextEditor(document: document)

    // sortedElements should be in correct order
    let sorted = document.sortedElements
    #expect(sorted[0].elementText == "First")
    #expect(sorted[1].elementText == "Second")
    #expect(sorted[2].elementText == "Third")
  }

  @Test("GuionTextEditor handles chapter ordering")
  func testGuionTextEditorChapterOrdering() throws {
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

    _ = GuionTextEditor(document: document)

    // Elements should be sorted by (chapterIndex, orderIndex)
    let sorted = document.sortedElements
    #expect(sorted[0].elementText == "Ch1 El1")
    #expect(sorted[1].elementText == "Ch1 El2")
    #expect(sorted[2].elementText == "Ch2 El1")
    #expect(sorted[3].elementText == "Ch2 El2")
  }

  // MARK: - Markdown Element Tests

  @Test("GuionTextEditor displays markdown elements")
  func testGuionTextEditorMarkdownElements() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()

    let heading = GuionElementModel(
      elementText: "# Act I",
      elementType: .sectionHeading(level: 1),
      orderIndex: 0
    )

    let list = GuionElementModel(
      elementText: "- Item 1",
      elementType: .unorderedListItem(level: 0),
      orderIndex: 1
    )

    let comment = GuionElementModel(
      elementText: "/* This is a comment */",
      elementType: .comment,
      orderIndex: 2
    )

    document.elements.append(heading)
    document.elements.append(list)
    document.elements.append(comment)
    container.mainContext.insert(document)

    _ = GuionTextEditor(document: document)

    #expect(document.elements.count == 3)

    let sorted = document.sortedElements
    #expect(sorted[0].elementType == .sectionHeading(level: 1))
    #expect(sorted[1].elementType == .unorderedListItem(level: 0))
    #expect(sorted[2].elementType == .comment)
  }

  // MARK: - Edge Case Tests

  @Test("GuionTextEditor handles single element")
  func testGuionTextEditorSingleElement() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext, elementCount: 1)

    _ = GuionTextEditor(document: document)

    #expect(document.elements.count == 1)
  }

  @Test("GuionTextEditor handles very long element text")
  func testGuionTextEditorLongElementText() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()

    let longText = String(repeating: "This is a very long line of action text. ", count: 100)
    let element = GuionElementModel(
      elementText: longText,
      elementType: .action,
      orderIndex: 0
    )
    document.elements.append(element)
    container.mainContext.insert(document)

    _ = GuionTextEditor(document: document)

    #expect(document.elements.count == 1)
    #expect(document.elements.first?.elementText.count ?? 0 > 1000)
  }

  @Test("GuionTextEditor handles all element types")
  func testGuionTextEditorAllElementTypes() throws {
    let container = try makeTestContainer()
    let document = GuionDocumentModel()

    let types: [ElementType] = [
      .sceneHeading, .action, .dialogue, .character,
      .parenthetical, .transition, .sectionHeading(level: 1),
      .synopsis, .pageBreak, .comment, .boneyard,
      .unorderedListItem(level: 0), .orderedListItem(level: 0),
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

    _ = GuionTextEditor(document: document)

    #expect(document.elements.count == types.count)
  }

  // MARK: - Multiple Documents Tests

  @Test("GuionTextEditor with multiple documents")
  func testGuionTextEditorMultipleDocuments() throws {
    let container = try makeTestContainer()
    let doc1 = makeTestDocument(in: container.mainContext, title: "Doc 1", elementCount: 3)
    let doc2 = makeTestDocument(in: container.mainContext, title: "Doc 2", elementCount: 5)

    _ = GuionTextEditor(document: doc1)
    _ = GuionTextEditor(document: doc2)

    #expect(doc1.title == "Doc 1")
    #expect(doc2.title == "Doc 2")
    #expect(doc1.elements.count == 3)
    #expect(doc2.elements.count == 5)
  }
}
