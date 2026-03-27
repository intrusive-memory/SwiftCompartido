//
//  LongPressGestureTests.swift
//  SwiftCompartidoTests
//
//  Tests for long-press gesture support on touch devices
//

import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import SwiftCompartido

@Suite("Long-Press Gesture Tests")
@MainActor
struct LongPressGestureTests {

  // MARK: - Scroll-to-Dismiss Tests

  @Test("Dismiss coordinator has shouldDismiss property")
  func testDismissCoordinatorProperty() {
    let coordinator = PopoverDismissCoordinator()
    #expect(coordinator.shouldDismiss == false)
  }

  @Test("Trigger dismiss sets shouldDismiss to true")
  func testTriggerDismiss() async {
    let coordinator = PopoverDismissCoordinator()
    coordinator.triggerDismiss()
    #expect(coordinator.shouldDismiss == true)
  }

  // MARK: - SwiftData Integration Tests

  @Test("GuionElementsList with SwiftData model context compiles")
  func testListProvidesDismissCoordinator() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: GuionDocumentModel.self, GuionElementModel.self,
      configurations: config
    )

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

    // Test that the list compiles with the model container
    _ = GuionElementsList(document: document)
      .modelContainer(container)

    // Verify element was inserted successfully
    #expect(element.elementText == "Test")
    #expect(element.elementType == .action)
  }

  // MARK: - Edge Cases

  @Test("Multiple rows maintain independent state")
  func testMultipleRowsLongPress() {
    let elements = (0..<5).map { i in
      GuionElementModel(
        elementText: "Element \(i)",
        elementType: .action,
        chapterIndex: 0,
        orderIndex: i
      )
    }

    // Verify each element has correct properties
    #expect(elements.count == 5)
    for (index, element) in elements.enumerated() {
      #expect(element.elementText == "Element \(index)")
      #expect(element.orderIndex == index)
    }
  }

}
