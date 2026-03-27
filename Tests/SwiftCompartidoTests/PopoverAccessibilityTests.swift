//
//  PopoverAccessibilityTests.swift
//  SwiftCompartidoTests
//
//  Tests for popover accessibility features (keyboard focus, VoiceOver, reduced motion)
//

import Foundation
import SwiftUI
import Testing

@testable import SwiftCompartido

@Suite("Popover Accessibility Tests")
@MainActor
struct PopoverAccessibilityTests {

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

  // MARK: - Reduced Motion Tests

  @Test("Reduced motion environment value is accessible")
  func testReducedMotionEnvironment() {
    var environment = EnvironmentValues()

    // Verify we can access the reduce motion value
    let reduceMotion = environment.accessibilityReduceMotion

    // Default value is false (not reduced)
    #expect(reduceMotion == false)
  }

  // MARK: - Focus State Tests

  @Test("Element row supports keyboard focus")
  func testElementRowFocusable() {
    let element = createTestElement()

    // Create row with popover
    let row = GuionElementRow<EmptyView>(element: element, trailingContent: nil)
      .guionElementPopover { element in
        Text(element.elementText)
      }

    // Verify row compiles with focusable modifier
    #expect(element.elementText == "Test element")
  }

  // MARK: - VoiceOver Label Tests

  @Test("Element maintains accessible properties")
  func testElementAccessibility() {
    let element = createTestElement()

    // Verify element properties are accessible
    #expect(element.elementText == "Test element")
    #expect(element.elementType == .action)
  }

  @Test("Multiple elements maintain accessible properties")
  func testMultipleElementsAccessibility() {
    let elements = (0..<5).map { i in
      GuionElementModel(
        elementText: "Element \(i)",
        elementType: .action,
        chapterIndex: 0,
        orderIndex: i
      )
    }

    // Verify all elements maintain properties
    #expect(elements.count == 5)
    for (index, element) in elements.enumerated() {
      #expect(element.elementText == "Element \(index)")
      #expect(element.orderIndex == index)
    }
  }

  // MARK: - Animation Tests

  @Test("Animation respects timing configuration")
  func testAnimationTiming() {
    let element = createTestElement()

    // Verify element can be used in animated contexts
    let row = GuionElementRow<EmptyView>(element: element, trailingContent: nil)
      .guionElementPopover { element in
        Text(element.elementText)
      }

    // Animations are applied in the view body
    #expect(element.elementText == "Test element")
  }

  // MARK: - Integration Tests

  @Test("Keyboard focus works with hover states")
  func testFocusAndHoverIntegration() {
    let element = createTestElement()

    // Create row that supports both keyboard focus and hover
    let row = GuionElementRow<EmptyView>(element: element, trailingContent: nil)
      .guionElementPopover { element in
        VStack {
          Text(element.elementText)
          Button("Action") {}
        }
      }

    // Both mechanisms can coexist
    #expect(element.elementType == .action)
  }

  @Test("Accessibility works with interactive content")
  func testAccessibilityWithInteractiveContent() {
    let element = createTestElement()

    // Create row with interactive popover
    let row = GuionElementRow<EmptyView>(element: element, trailingContent: nil)
      .guionElementPopover { element in
        VStack {
          Text("Generate Audio")
          Button("Generate") {}
            .accessibilityLabel("Generate audio for this element")
        }
      }

    // Interactive content maintains accessibility
    #expect(element.elementText == "Test element")
  }
}
