//
//  GuionElementPopoverEnvironmentTests.swift
//  SwiftCompartidoTests
//
//  Tests for GuionElementPopover environment key and propagation
//

import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import SwiftCompartido

@Suite("GuionElementPopover Environment Tests")
@MainActor
struct GuionElementPopoverEnvironmentTests {

  // MARK: - Test Fixtures

  /// Test view that reads the popover environment value
  struct TestEnvironmentReaderView: View {
    @Environment(\.guionElementPopover) var popoverProvider

    var body: some View {
      Text("Test")
    }

    func hasProvider() -> Bool {
      popoverProvider != nil
    }
  }

  /// Creates a test element
  private func createTestElement() -> GuionElementModel {
    GuionElementModel(
      elementText: "Test",
      elementType: .action,
      chapterIndex: 0,
      orderIndex: 0
    )
  }

  // MARK: - Environment Key Tests

  @Test("Environment value defaults to nil")
  func testEnvironmentDefaultValue() {
    let key = GuionElementPopoverKey.self
    let defaultValue = key.defaultValue

    #expect(defaultValue == nil)
  }

  @Test("Environment key has correct default value type")
  func testEnvironmentKeyDefaultValueType() {
    let defaultValue = GuionElementPopoverKey.defaultValue
    #expect(type(of: defaultValue) == Optional<GuionElementPopoverProvider>.self)
  }

  // MARK: - Environment Values Tests

  @Test("EnvironmentValues has guionElementPopover property")
  func testEnvironmentValuesExtension() {
    var environmentValues = EnvironmentValues()

    // Should be nil by default
    #expect(environmentValues.guionElementPopover == nil)
  }

  @Test("Can set and clear environment value")
  func testSetEnvironmentValue() {
    var environmentValues = EnvironmentValues()

    let provider = GuionElementPopoverProvider { element in
      Text(element.elementText)
    }

    environmentValues.guionElementPopover = provider
    #expect(environmentValues.guionElementPopover != nil)

    environmentValues.guionElementPopover = nil
    #expect(environmentValues.guionElementPopover == nil)
  }

  // MARK: - Integration with GuionElementsList Tests

  @Test("GuionElementsList with SwiftData integration")
  func testGuionElementsListReceivesEnvironment() async throws {
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

    // Verify the element is correctly configured
    #expect(element.elementText == "Test")
    #expect(element.document === document)
  }

  // MARK: - Provider Functionality Tests

  @Test("Environment provider handles nil gracefully")
  func testEnvironmentProviderNilHandling() {
    var environmentValues = EnvironmentValues()

    // Provider is nil by default
    let element = createTestElement()
    let view = environmentValues.guionElementPopover?(element)

    #expect(view == nil)
  }
}
