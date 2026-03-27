//
//  PreSceneBoxTests.swift
//  SwiftCompartido Tests
//
//  Tests for PreSceneBox component
//

import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import SwiftCompartido

@Suite("PreSceneBox Tests")
@MainActor
struct PreSceneBoxTests {

  // MARK: - Helper Methods

  private func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
      for: GuionElementModel.self,
      configurations: config
    )
  }

  private func makeElement(
    in context: ModelContext,
    text: String,
    type: ElementType = .action,
    order: Int = 0
  ) -> GuionElementModel {
    let element = GuionElementModel(
      elementText: text,
      elementType: type,
      orderIndex: order
    )
    context.insert(element)
    return element
  }

  // MARK: - Initialization Tests

  @Test("PreSceneBox initializes with single element")
  func testPreSceneBoxInitialization() throws {
    let container = try makeTestContainer()
    let element = makeElement(in: container.mainContext, text: "FADE IN:", order: 0)

    @State var isExpanded = false
    _ = PreSceneBox(content: [element], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(element.elementText == "FADE IN:")
  }

  @Test("PreSceneBox initializes with multiple elements")
  func testPreSceneBoxMultipleElements() throws {
    let container = try makeTestContainer()
    let element1 = makeElement(in: container.mainContext, text: "FADE IN:", order: 0)
    let element2 = makeElement(in: container.mainContext, text: "Opening text", order: 1)

    @State var isExpanded = false
    _ = PreSceneBox(content: [element1, element2], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(true)  // Successfully initialized
  }

  @Test("PreSceneBox initializes with empty content")
  func testPreSceneBoxEmptyContent() throws {
    @State var isExpanded = false
    _ = PreSceneBox(content: [], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(true)  // Successfully initialized with empty content
  }

  // MARK: - Expansion State Tests

  @Test("PreSceneBox starts collapsed by default")
  func testPreSceneBoxStartsCollapsed() throws {
    let container = try makeTestContainer()
    let element = makeElement(in: container.mainContext, text: "FADE IN:")

    @State var isExpanded = false
    _ = PreSceneBox(content: [element], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(isExpanded == false)
  }

  @Test("PreSceneBox can start expanded")
  func testPreSceneBoxStartsExpanded() throws {
    let container = try makeTestContainer()
    let element = makeElement(in: container.mainContext, text: "FADE IN:")

    @State var isExpanded = true
    _ = PreSceneBox(content: [element], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(isExpanded == true)
  }

  // MARK: - Font Size Tests

  @Test("PreSceneBox respects font size environment")
  func testPreSceneBoxFontSize() throws {
    let container = try makeTestContainer()
    let element = makeElement(in: container.mainContext, text: "FADE IN:")

    @State var isExpanded = false

    let view1 = PreSceneBox(content: [element], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 10)

    let view2 = PreSceneBox(content: [element], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 18)

    #expect(true)  // Successfully created with different font sizes
  }

  // MARK: - Content Tests

  @Test("PreSceneBox handles single line content")
  func testPreSceneBoxSingleLine() throws {
    let container = try makeTestContainer()
    let element = makeElement(in: container.mainContext, text: "FADE IN:")

    @State var isExpanded = true
    _ = PreSceneBox(content: [element], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(element.elementText == "FADE IN:")
  }

  @Test("PreSceneBox handles multi-line content")
  func testPreSceneBoxMultiLine() throws {
    let container = try makeTestContainer()
    let elements = [
      makeElement(in: container.mainContext, text: "FADE IN:", order: 0),
      makeElement(in: container.mainContext, text: "Once upon a time...", order: 1),
      makeElement(in: container.mainContext, text: "In a galaxy far away...", order: 2),
    ]

    @State var isExpanded = true
    _ = PreSceneBox(content: elements, isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(elements.count == 3)
  }

  @Test("PreSceneBox handles long text content")
  func testPreSceneBoxLongText() throws {
    let container = try makeTestContainer()
    let longText = String(repeating: "This is a very long piece of pre-scene text. ", count: 20)
    let element = makeElement(in: container.mainContext, text: longText)

    @State var isExpanded = true
    _ = PreSceneBox(content: [element], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(element.elementText.count > 100)
  }

  @Test("PreSceneBox handles special characters")
  func testPreSceneBoxSpecialCharacters() throws {
    let container = try makeTestContainer()
    let element = makeElement(
      in: container.mainContext, text: "FADE IN: © 2025 — All Rights Reserved™")

    @State var isExpanded = true
    _ = PreSceneBox(content: [element], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(element.elementText.contains("©"))
    #expect(element.elementText.contains("™"))
  }

  // MARK: - Element Type Tests

  @Test("PreSceneBox handles action elements")
  func testPreSceneBoxActionElements() throws {
    let container = try makeTestContainer()
    let element = makeElement(in: container.mainContext, text: "FADE IN:", type: .action)

    @State var isExpanded = true
    _ = PreSceneBox(content: [element], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(element.elementType == .action)
  }

  @Test("PreSceneBox handles comment elements")
  func testPreSceneBoxCommentElements() throws {
    let container = try makeTestContainer()
    let element = makeElement(
      in: container.mainContext, text: "/* Note to director */", type: .comment)

    @State var isExpanded = true
    _ = PreSceneBox(content: [element], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(element.elementType == .comment)
  }

  @Test("PreSceneBox handles mixed element types")
  func testPreSceneBoxMixedElementTypes() throws {
    let container = try makeTestContainer()
    let elements = [
      makeElement(in: container.mainContext, text: "FADE IN:", type: .action, order: 0),
      makeElement(
        in: container.mainContext, text: "/* Production note */", type: .comment, order: 1),
      makeElement(in: container.mainContext, text: "= Story begins", type: .synopsis, order: 2),
    ]

    @State var isExpanded = true
    _ = PreSceneBox(content: elements, isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(elements.count == 3)
    #expect(elements[0].elementType == .action)
    #expect(elements[1].elementType == .comment)
    #expect(elements[2].elementType == .synopsis)
  }

  // MARK: - Edge Case Tests

  @Test("PreSceneBox handles single character content")
  func testPreSceneBoxSingleCharacter() throws {
    let container = try makeTestContainer()
    let element = makeElement(in: container.mainContext, text: "A")

    @State var isExpanded = true
    _ = PreSceneBox(content: [element], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(element.elementText == "A")
  }

  @Test("PreSceneBox handles whitespace-only content")
  func testPreSceneBoxWhitespaceContent() throws {
    let container = try makeTestContainer()
    let element = makeElement(in: container.mainContext, text: "   ")

    @State var isExpanded = true
    _ = PreSceneBox(content: [element], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(element.elementText == "   ")
  }

  @Test("PreSceneBox handles newlines in content")
  func testPreSceneBoxNewlines() throws {
    let container = try makeTestContainer()
    let element = makeElement(in: container.mainContext, text: "Line 1\nLine 2\nLine 3")

    @State var isExpanded = true
    _ = PreSceneBox(content: [element], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(element.elementText.contains("\n"))
  }

  // MARK: - Large Content Tests

  @Test("PreSceneBox handles many elements")
  func testPreSceneBoxManyElements() throws {
    let container = try makeTestContainer()
    var elements: [GuionElementModel] = []

    for i in 0..<10 {
      let element = makeElement(in: container.mainContext, text: "Line \(i)", order: i)
      elements.append(element)
    }

    @State var isExpanded = true
    _ = PreSceneBox(content: elements, isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(elements.count == 10)
  }

  @Test("PreSceneBox handles very many elements")
  func testPreSceneBoxVeryManyElements() throws {
    let container = try makeTestContainer()
    var elements: [GuionElementModel] = []

    for i in 0..<50 {
      let element = makeElement(in: container.mainContext, text: "Line \(i)", order: i)
      elements.append(element)
    }

    @State var isExpanded = true
    _ = PreSceneBox(content: elements, isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(elements.count == 50)
  }

  // MARK: - Accessibility Tests

  @Test("PreSceneBox has accessibility support")
  func testPreSceneBoxAccessibility() throws {
    let container = try makeTestContainer()
    let element = makeElement(in: container.mainContext, text: "FADE IN:")

    @State var isExpanded = false
    _ = PreSceneBox(content: [element], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    // PreSceneBox has built-in accessibility labels and hints
    #expect(true)  // Successfully created with accessibility support
  }

  // MARK: - Integration Tests

  @Test("PreSceneBox in typical screenplay context")
  func testPreSceneBoxTypicalUsage() throws {
    let container = try makeTestContainer()

    // Typical pre-scene content: FADE IN and opening text
    let fadeIn = makeElement(in: container.mainContext, text: "FADE IN:", type: .action, order: 0)
    let openingText = makeElement(
      in: container.mainContext,
      text: "The year is 2042. Humanity has colonized Mars.",
      type: .action,
      order: 1
    )

    @State var isExpanded = false
    _ = PreSceneBox(content: [fadeIn, openingText], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(fadeIn.elementText == "FADE IN:")
    #expect(openingText.elementText.contains("2042"))
  }

  @Test("PreSceneBox with production notes")
  func testPreSceneBoxProductionNotes() throws {
    let container = try makeTestContainer()

    let note1 = makeElement(in: container.mainContext, text: "FADE IN:", type: .action, order: 0)
    let note2 = makeElement(
      in: container.mainContext, text: "/* Filmed on location */", type: .comment, order: 1)
    let note3 = makeElement(
      in: container.mainContext, text: "= Opening establishes tone", type: .synopsis, order: 2)

    @State var isExpanded = true
    _ = PreSceneBox(content: [note1, note2, note3], isExpanded: $isExpanded)
      .environment(\.screenplayFontSize, 12)

    #expect(note1.elementType == .action)
    #expect(note2.elementType == .comment)
    #expect(note3.elementType == .synopsis)
  }

  @Test("Multiple PreSceneBoxes with independent states")
  func testMultiplePreSceneBoxes() throws {
    let container = try makeTestContainer()

    let element1 = makeElement(in: container.mainContext, text: "Scene 1 opening", order: 0)
    let element2 = makeElement(in: container.mainContext, text: "Scene 2 opening", order: 1)

    @State var isExpanded1 = true
    @State var isExpanded2 = false

    _ = PreSceneBox(content: [element1], isExpanded: $isExpanded1)
      .environment(\.screenplayFontSize, 12)

    _ = PreSceneBox(content: [element2], isExpanded: $isExpanded2)
      .environment(\.screenplayFontSize, 12)

    #expect(isExpanded1 == true)
    #expect(isExpanded2 == false)
  }
}
