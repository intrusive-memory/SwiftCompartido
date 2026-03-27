//
//  AppIntentsIntegrationTests.swift
//  SwiftCompartidoTests
//
//  Simple integration tests verifying App Intents can be initialized.
//

import Foundation
import Testing

@testable import SwiftCompartido

/// Simple integration tests for App Intents.
///
/// Note: Full intent execution requires singleton ModelContainer that can't be injected.
/// These tests verify intent initialization and parameter handling.
@Suite("App Intents Integration Tests")
@MainActor
struct AppIntentsIntegrationTests {

  // MARK: - Test Fixtures

  /// Get URL for a test fixture file
  private func fixtureURL(named filename: String) throws -> URL {
    let fixturesPath = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // AppIntents
      .deletingLastPathComponent()  // SwiftCompartidoTests
      .deletingLastPathComponent()  // Tests
      .deletingLastPathComponent()  // SwiftCompartido
      .appendingPathComponent("Fixtures")
      .appendingPathComponent(filename)

    guard FileManager.default.fileExists(atPath: fixturesPath.path) else {
      throw IntegrationTestError.fixtureNotFound(filename)
    }

    return fixturesPath
  }

  // MARK: - Intent Initialization Tests

  @Test("ParseScreenplayFileIntent: Fountain file initialization")
  func testParseScreenplayFileIntent_Init() async throws {
    let fileURL = try fixtureURL(named: "bigfish.fountain")

    // Create intent with parameters
    var intent = ParseScreenplayFileIntent()
    intent.fileURL = fileURL
    intent.elementTypes = [ElementTypeEntity(id: "Dialogue", elementType: .dialogue)]
    intent.chapterIndex = 0
    intent.searchText = "Edward"

    // Verify parameters set correctly
    #expect(intent.fileURL == fileURL)
    #expect(intent.elementTypes?.count == 1)
    #expect(intent.chapterIndex == 0)
    #expect(intent.searchText == "Edward")
  }

  @Test("QueryScreenplayElementsIntent: Initialization")
  func testQueryScreenplayElementsIntent_Init() async throws {
    // Create intent with parameters
    let documentIDString = "test-document-id"
    let intent = QueryScreenplayElementsIntent(
      documentIDString: documentIDString,
      elementTypes: [ElementTypeEntity(id: "Dialogue", elementType: .dialogue)],
      chapterIndex: 0,
      characterName: "EDWARD",
      searchText: "test"
    )

    // Verify parameters
    #expect(intent.documentIDString == documentIDString)
    #expect(intent.elementTypes?.count == 1)
    #expect(intent.chapterIndex == 0)
    #expect(intent.characterName == "EDWARD")
    #expect(intent.searchText == "test")
  }

  @Test("ElementTypeEntity: Query all types")
  func testElementTypeEntityQuery() async throws {
    let query = ElementTypeQuery()

    let allTypes = try await query.suggestedEntities()

    // Verify all screenplay element types are available
    #expect(allTypes.count == 7)
    #expect(allTypes.contains(where: { $0.elementType == .dialogue }))
    #expect(allTypes.contains(where: { $0.elementType == .action }))
    #expect(allTypes.contains(where: { $0.elementType == .sceneHeading }))
    #expect(allTypes.contains(where: { $0.elementType == .character }))
  }

  @Test("ElementTypeEntity: Query by ID")
  func testElementTypeEntityQueryByID() async throws {
    let query = ElementTypeQuery()

    let entities = try await query.entities(for: ["Dialogue", "Action"])

    #expect(entities.count == 2)
    #expect(entities.contains(where: { $0.elementType == .dialogue }))
    #expect(entities.contains(where: { $0.elementType == .action }))
  }
}

// MARK: - Test Errors

enum IntegrationTestError: Error {
  case fixtureNotFound(String)
}
