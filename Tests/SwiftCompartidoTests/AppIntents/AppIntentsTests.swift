//
//  AppIntentsTests.swift
//  SwiftCompartidoTests
//
//  Unit tests for App Intents (ParseScreenplayFileIntent and QueryScreenplayElementsIntent)
//

import Testing
import SwiftData
import Foundation
@testable import SwiftCompartido

/// Test suite for App Intents
///
/// Tests the App Intents functionality for Shortcuts integration, including:
/// - ParseScreenplayFileIntent (parsing files)
/// - QueryScreenplayElementsIntent (querying existing documents)
/// - ScreenplayElementsReference (transferable reference type)
@Suite("App Intents Tests")
@MainActor
struct AppIntentsTests {

    // MARK: - Test Fixtures

    /// Get URL for a test fixture file
    private func fixtureURL(named filename: String) throws -> URL {
        let fixturesPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // AppIntents
            .deletingLastPathComponent() // SwiftCompartidoTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // SwiftCompartido
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: fixturesPath.path) else {
            throw AppIntentsTestError.fixtureNotFound(filename)
        }

        return fixturesPath
    }

    /// Create an in-memory test container
    private func makeTestContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: GuionDocumentModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return container
    }

    // MARK: - ScreenplayElementsReference Tests

    @Test("ScreenplayElementsReference creation from document")
    func testScreenplayElementsReferenceCreation() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)
        let document = try await service.document(id: documentID)

        // Create reference from document
        let reference = ScreenplayElementsReference(from: document)

        #expect(reference.documentID == documentID)
        #expect(reference.documentTitle == document.title)
        #expect(reference.documentFilename == document.filename)
        #expect(reference.elementCount > 0)
        #expect(reference.elementCount == document.sortedElements.count)
    }

    @Test("ScreenplayElementsReference filtered elements")
    func testScreenplayElementsReferenceFilteredElements() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)
        let document = try await service.document(id: documentID)

        // Get only dialogue elements
        let dialogueElements = document.sortedElements.filter { $0.elementType == .dialogue }

        // Create reference with filtered elements
        let reference = ScreenplayElementsReference(from: document, elements: dialogueElements)

        #expect(reference.elementCount == dialogueElements.count)
        #expect(reference.elements.allSatisfy { $0.isDialogue })
    }

    @Test("ScreenplayElementsReference character names extraction")
    func testScreenplayElementsReferenceCharacterNames() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)
        let document = try await service.document(id: documentID)

        let reference = ScreenplayElementsReference(from: document)

        // Verify character names are extracted and sorted
        let characterNames = reference.characterNames
        #expect(characterNames.count > 0)

        // Verify sorted alphabetically
        let sortedNames = characterNames.sorted()
        #expect(characterNames == sortedNames)
    }

    @Test("ScreenplayElementsReference dialogue count")
    func testScreenplayElementsReferenceDialogueCount() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)
        let document = try await service.document(id: documentID)

        let reference = ScreenplayElementsReference(from: document)

        let expectedDialogueCount = document.sortedElements.filter { $0.elementType == .dialogue }.count
        #expect(reference.dialogueCount == expectedDialogueCount)
    }

    @Test("ScreenplayElementsReference scene count")
    func testScreenplayElementsReferenceSceneCount() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)
        let document = try await service.document(id: documentID)

        let reference = ScreenplayElementsReference(from: document)

        let expectedSceneCount = document.sortedElements.filter { $0.elementType == .sceneHeading }.count
        #expect(reference.sceneCount == expectedSceneCount)
    }


    // MARK: - ParseScreenplayFileIntent Tests
    // NOTE: Actual intent execution tests are disabled because they require a singleton
    // ModelContainer that can't be injected during testing. In production, intents will
    // use ParsedFileService.shared which creates its own container.
    //
    // The intent's logic is tested indirectly through ParsedFileService tests.

    @Test("ParseScreenplayFileIntent initialization")
    func testParseScreenplayFileIntentInitialization() async throws {
        let fileURL = try fixtureURL(named: "bigfish.fountain")

        var intent = ParseScreenplayFileIntent()
        intent.fileURL = fileURL
        intent.elementTypes = [ElementTypeEntity(id: "Dialogue", elementType: .dialogue)]
        intent.chapterIndex = 0
        intent.searchText = "Edward"

        // Verify parameters are set correctly
        #expect(intent.fileURL == fileURL)
        #expect(intent.elementTypes?.count == 1)
        #expect(intent.chapterIndex == 0)
        #expect(intent.searchText == "Edward")
    }

    // MARK: - QueryScreenplayElementsIntent Tests
    // NOTE: These tests are disabled because PersistentIdentifier cannot be easily
    // serialized/deserialized via JSON (it uses NSSecureCoding internally).
    // In production, the documentID would be passed from a previous intent result
    // in the Shortcuts workflow, not manually encoded/decoded.

    // @Test("QueryScreenplayElementsIntent queries existing document")
    // func testQueryScreenplayElementsIntent() async throws {
    //     // Skipped - PersistentIdentifier serialization via JSON not supported
    // }

    // MARK: - ElementTypeEntity Tests

    @Test("ElementTypeEntity query returns all types")
    func testElementTypeEntityQuery() async throws {
        let query = ElementTypeQuery()

        let allTypes = try await query.suggestedEntities()

        #expect(allTypes.count == 7) // dialogue, action, character, sceneHeading, parenthetical, transition, lyrics
        #expect(allTypes.contains(where: { $0.elementType == .dialogue }))
        #expect(allTypes.contains(where: { $0.elementType == .action }))
        #expect(allTypes.contains(where: { $0.elementType == .sceneHeading }))
    }

    @Test("ElementTypeEntity query by ID")
    func testElementTypeEntityQueryByID() async throws {
        let query = ElementTypeQuery()

        let entities = try await query.entities(for: ["Dialogue", "Action"])

        #expect(entities.count == 2)
        #expect(entities.contains(where: { $0.elementType == .dialogue }))
        #expect(entities.contains(where: { $0.elementType == .action }))
    }
}

// MARK: - Test Errors

enum AppIntentsTestError: Error {
    case fixtureNotFound(String)
}
