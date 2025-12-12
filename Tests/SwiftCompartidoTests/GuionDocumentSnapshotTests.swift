//
//  GuionDocumentSnapshotTests.swift
//  SwiftCompartidoTests
//
//  Unit tests for GuionDocumentSnapshot (Phase 1)
//

import XCTest
@testable import SwiftCompartido

final class GuionDocumentSnapshotTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInit_EmptyDocument() {
        let snapshot = GuionDocumentSnapshot()

        XCTAssertNotNil(snapshot.id)
        XCTAssertNil(snapshot.filename)
        XCTAssertNil(snapshot.title)
        XCTAssertNil(snapshot.created)
        XCTAssertNil(snapshot.modified)
        XCTAssertFalse(snapshot.suppressSceneNumbers)
        XCTAssertTrue(snapshot.elements.isEmpty)
        XCTAssertTrue(snapshot.titlePage.isEmpty)
        XCTAssertNil(snapshot.customPages)
        XCTAssertNil(snapshot.generatedContent)
        XCTAssertNil(snapshot.casting)
        XCTAssertNil(snapshot.sourceFileBookmark)
        XCTAssertNil(snapshot.lastImportDate)
        XCTAssertNil(snapshot.sourceFileModificationDate)
        XCTAssertNil(snapshot.lastOpenedDate)
    }

    func testInit_WithAllFields() {
        let id = UUID()
        let created = Date()
        let modified = Date()
        let lastImport = Date()
        let sourceModified = Date()
        let lastOpened = Date()

        let element = GuionElementSnapshot(
            elementText: "INT. COFFEE SHOP - DAY",
            elementType: .sceneHeading
        )

        let titleEntry = TitlePageEntrySnapshot(
            key: "TITLE",
            values: ["Test Screenplay"]
        )

        let voiceMapping = CharacterVoiceMappingSnapshot(
            voiceURI: "macos://Samantha",
            voiceName: "Samantha",
            providerID: "macos"
        )

        let snapshot = GuionDocumentSnapshot(
            id: id,
            filename: "test.guion",
            title: "Test Screenplay",
            created: created,
            modified: modified,
            suppressSceneNumbers: true,
            elements: [element],
            titlePage: [titleEntry],
            customPages: nil,
            generatedContent: nil,
            casting: ["JANE": voiceMapping],
            sourceFileBookmark: Data([1, 2, 3]),
            lastImportDate: lastImport,
            sourceFileModificationDate: sourceModified,
            lastOpenedDate: lastOpened
        )

        XCTAssertEqual(snapshot.id, id)
        XCTAssertEqual(snapshot.filename, "test.guion")
        XCTAssertEqual(snapshot.title, "Test Screenplay")
        XCTAssertEqual(snapshot.created, created)
        XCTAssertEqual(snapshot.modified, modified)
        XCTAssertTrue(snapshot.suppressSceneNumbers)
        XCTAssertEqual(snapshot.elements.count, 1)
        XCTAssertEqual(snapshot.titlePage.count, 1)
        XCTAssertEqual(snapshot.casting?["JANE"]?.voiceName, "Samantha")
        XCTAssertEqual(snapshot.sourceFileBookmark, Data([1, 2, 3]))
        XCTAssertEqual(snapshot.lastImportDate, lastImport)
        XCTAssertEqual(snapshot.sourceFileModificationDate, sourceModified)
        XCTAssertEqual(snapshot.lastOpenedDate, lastOpened)
    }

    // MARK: - Voice Casting Tests

    func testCharacters_EmptyElements() {
        let snapshot = GuionDocumentSnapshot()
        XCTAssertTrue(snapshot.characters.isEmpty)
    }

    func testCharacters_ExtractsFromElements() {
        var snapshot = GuionDocumentSnapshot()
        snapshot.elements = [
            GuionElementSnapshot(elementText: "JANE", elementType: .character),
            GuionElementSnapshot(elementText: "Hello", elementType: .dialogue),
            GuionElementSnapshot(elementText: "JOHN", elementType: .character),
            GuionElementSnapshot(elementText: "Hi", elementType: .dialogue),
            GuionElementSnapshot(elementText: "JANE", elementType: .character), // Duplicate
        ]

        let characters = snapshot.characters
        XCTAssertEqual(characters.count, 2)
        XCTAssertTrue(characters.contains("JANE"))
        XCTAssertTrue(characters.contains("JOHN"))
        XCTAssertEqual(characters, ["JANE", "JOHN"]) // Should be sorted
    }

    func testVoiceMapping_GetAndSet() {
        var snapshot = GuionDocumentSnapshot()

        // Initially nil
        XCTAssertNil(snapshot.voiceMapping(for: "JANE"))

        // Set mapping
        let mapping = CharacterVoiceMappingSnapshot(
            voiceURI: "macos://Samantha",
            voiceName: "Samantha",
            providerID: "macos"
        )
        snapshot.setVoiceMapping(mapping, for: "JANE")

        // Verify
        let retrieved = snapshot.voiceMapping(for: "JANE")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.voiceURI, "macos://Samantha")
        XCTAssertEqual(retrieved?.voiceName, "Samantha")
    }

    func testVoiceMapping_MultipleCharacters() {
        var snapshot = GuionDocumentSnapshot()

        let jane = CharacterVoiceMappingSnapshot(
            voiceURI: "macos://Samantha",
            voiceName: "Samantha",
            providerID: "macos"
        )
        let john = CharacterVoiceMappingSnapshot(
            voiceURI: "macos://Alex",
            voiceName: "Alex",
            providerID: "macos"
        )

        snapshot.setVoiceMapping(jane, for: "JANE")
        snapshot.setVoiceMapping(john, for: "JOHN")

        XCTAssertEqual(snapshot.casting?.count, 2)
        XCTAssertEqual(snapshot.voiceMapping(for: "JANE")?.voiceName, "Samantha")
        XCTAssertEqual(snapshot.voiceMapping(for: "JOHN")?.voiceName, "Alex")
    }

    // MARK: - Codable Tests

    func testCodable_EmptyDocument() throws {
        let snapshot = GuionDocumentSnapshot()

        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)
        XCTAssertGreaterThan(data.count, 0)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GuionDocumentSnapshot.self, from: data)

        XCTAssertEqual(decoded.id, snapshot.id)
        XCTAssertEqual(decoded.filename, snapshot.filename)
        XCTAssertTrue(decoded.elements.isEmpty)
    }

    func testCodable_WithElements() throws {
        var snapshot = GuionDocumentSnapshot()
        snapshot.filename = "test.guion"
        snapshot.title = "Test Screenplay"
        snapshot.elements = [
            GuionElementSnapshot(
                elementText: "INT. COFFEE SHOP - DAY",
                elementType: .sceneHeading
            ),
            GuionElementSnapshot(
                elementText: "A quiet morning.",
                elementType: .action
            ),
        ]

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GuionDocumentSnapshot.self, from: data)

        XCTAssertEqual(decoded.filename, "test.guion")
        XCTAssertEqual(decoded.title, "Test Screenplay")
        XCTAssertEqual(decoded.elements.count, 2)
        XCTAssertEqual(decoded.elements[0].elementText, "INT. COFFEE SHOP - DAY")
        XCTAssertEqual(decoded.elements[0].elementType, .sceneHeading)
    }

    func testCodable_WithTitlePage() throws {
        var snapshot = GuionDocumentSnapshot()
        snapshot.titlePage = [
            TitlePageEntrySnapshot(key: "TITLE", values: ["My Screenplay"]),
            TitlePageEntrySnapshot(key: "AUTHOR", values: ["Jane Doe", "John Smith"]),
        ]

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(GuionDocumentSnapshot.self, from: data)

        XCTAssertEqual(decoded.titlePage.count, 2)
        XCTAssertEqual(decoded.titlePage[0].key, "TITLE")
        XCTAssertEqual(decoded.titlePage[0].values, ["My Screenplay"])
        XCTAssertEqual(decoded.titlePage[1].key, "AUTHOR")
        XCTAssertEqual(decoded.titlePage[1].values.count, 2)
    }

    func testCodable_WithCasting() throws {
        var snapshot = GuionDocumentSnapshot()
        snapshot.casting = [
            "JANE": CharacterVoiceMappingSnapshot(
                voiceURI: "macos://Samantha",
                voiceName: "Samantha",
                providerID: "macos"
            ),
            "JOHN": CharacterVoiceMappingSnapshot(
                voiceURI: "elevenlabs://voice-123",
                voiceName: "Adam",
                providerID: "elevenlabs"
            ),
        ]

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(GuionDocumentSnapshot.self, from: data)

        XCTAssertEqual(decoded.casting?.count, 2)
        XCTAssertEqual(decoded.casting?["JANE"]?.voiceName, "Samantha")
        XCTAssertEqual(decoded.casting?["JOHN"]?.providerID, "elevenlabs")
    }

    func testCodable_WithGeneratedContent() throws {
        var snapshot = GuionDocumentSnapshot()
        let contentID = UUID()

        snapshot.generatedContent = [
            contentID: TypedDataStorageSnapshot(
                providerId: "openai",
                requestorID: "gpt-4",
                mimeType: "text/plain",
                prompt: "Generate summary",
                textValue: "Test summary"
            )
        ]

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(GuionDocumentSnapshot.self, from: data)

        XCTAssertEqual(decoded.generatedContent?.count, 1)
        XCTAssertEqual(decoded.generatedContent?[contentID]?.textValue, "Test summary")
    }

    func testCodable_WithDates() throws {
        let created = Date()
        let modified = Date().addingTimeInterval(3600)

        var snapshot = GuionDocumentSnapshot()
        snapshot.created = created
        snapshot.modified = modified

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GuionDocumentSnapshot.self, from: data)

        // Dates should be approximately equal (within 1 second due to encoding precision)
        XCTAssertNotNil(decoded.created)
        XCTAssertNotNil(decoded.modified)
        if let decodedCreated = decoded.created {
            XCTAssertEqual(decodedCreated.timeIntervalSince1970,
                         created.timeIntervalSince1970,
                         accuracy: 1.0)
        }
    }

    func testCodable_RoundTrip() throws {
        let original = createComplexSnapshot()

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GuionDocumentSnapshot.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.filename, original.filename)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.suppressSceneNumbers, original.suppressSceneNumbers)
        XCTAssertEqual(decoded.elements.count, original.elements.count)
        XCTAssertEqual(decoded.titlePage.count, original.titlePage.count)
        XCTAssertEqual(decoded.casting?.count, original.casting?.count)
    }

    // MARK: - Helper Methods

    private func createComplexSnapshot() -> GuionDocumentSnapshot {
        var snapshot = GuionDocumentSnapshot()
        snapshot.filename = "complex.guion"
        snapshot.title = "Complex Screenplay"
        snapshot.suppressSceneNumbers = true

        snapshot.elements = [
            GuionElementSnapshot(
                chapterIndex: 0,
                orderIndex: 1,
                elementText: "INT. COFFEE SHOP - DAY",
                elementType: .sceneHeading,
                sceneNumber: "1"
            ),
            GuionElementSnapshot(
                chapterIndex: 0,
                orderIndex: 2,
                elementText: "JANE",
                elementType: .character
            ),
            GuionElementSnapshot(
                chapterIndex: 0,
                orderIndex: 3,
                elementText: "Hello, world!",
                elementType: .dialogue
            ),
        ]

        snapshot.titlePage = [
            TitlePageEntrySnapshot(key: "TITLE", values: ["Complex Screenplay"]),
            TitlePageEntrySnapshot(key: "AUTHOR", values: ["Test Author"]),
        ]

        snapshot.casting = [
            "JANE": CharacterVoiceMappingSnapshot(
                voiceURI: "macos://Samantha",
                voiceName: "Samantha",
                providerID: "macos"
            )
        ]

        return snapshot
    }
}
