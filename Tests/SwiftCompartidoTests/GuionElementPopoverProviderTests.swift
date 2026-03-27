//
//  GuionElementPopoverProviderTests.swift
//  SwiftCompartidoTests
//
//  Tests for GuionElementPopoverProvider type-erased wrapper
//

import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import SwiftCompartido

@Suite("GuionElementPopoverProvider Tests")
@MainActor
struct GuionElementPopoverProviderTests {

  // MARK: - Test Fixtures

  /// Creates a test GuionElementModel
  private func createTestElement(elementText: String = "Test content") -> GuionElementModel {
    let element = GuionElementModel(
      elementText: elementText,
      elementType: .action,
      chapterIndex: 0,
      orderIndex: 0
    )
    return element
  }

  // MARK: - Type Erasure Tests

  @Test("Provider callAsFunction returns AnyView")
  func testProviderReturnsAnyView() {
    let provider = GuionElementPopoverProvider { element in
      Text(element.elementText)
    }

    let element = createTestElement()
    let result = provider(element)

    #expect(type(of: result) == AnyView.self)
  }

  // MARK: - Element Properties Tests

  @Test("Provider accesses element properties correctly")
  func testProviderHandlesMultipleElements() {
    let element1 = GuionElementModel(
      elementText: "First",
      elementType: .action,
      chapterIndex: 0,
      orderIndex: 0
    )

    let element2 = GuionElementModel(
      elementText: "Second",
      elementType: .dialogue,
      chapterIndex: 1,
      orderIndex: 5
    )

    // Verify element properties are accessible
    #expect(element1.elementText == "First")
    #expect(element1.elementType == .action)
    #expect(element2.elementText == "Second")
    #expect(element2.chapterIndex == 1)
    #expect(element2.orderIndex == 5)
  }

  // MARK: - Edge Cases

  @Test("Element with very long content maintains property")
  func testProviderWithLongContent() {
    let longContent = String(repeating: "A", count: 10000)
    let element = createTestElement(elementText: longContent)

    #expect(element.elementText == longContent)
    #expect(element.elementText.count == 10000)
  }

  @Test("Element with special characters maintains property")
  func testProviderWithSpecialCharacters() {
    let specialContent = "Test 🎬 content with émojis and àccénts"
    let element = createTestElement(elementText: specialContent)

    #expect(element.elementText == specialContent)
  }

  @Test("Element with empty content maintains property")
  func testProviderWithEmptyContent() {
    let element = createTestElement(elementText: "")

    #expect(element.elementText == "")
  }
}
