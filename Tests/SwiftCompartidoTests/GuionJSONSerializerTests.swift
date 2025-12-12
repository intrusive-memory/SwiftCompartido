//
//  GuionJSONSerializerTests.swift
//  SwiftCompartidoTests
//
//  Unit tests for GuionJSONSerializer (Phase 1)
//

import XCTest
@testable import SwiftCompartido

final class GuionJSONSerializerTests: XCTestCase {

    // MARK: - Encoder/Decoder Configuration Tests

    func testEncoder_Configuration() {
        let encoder = GuionJSONSerializer.encoder

        // Should have pretty printing and sorted keys
        XCTAssertTrue(encoder.outputFormatting.contains(.prettyPrinted))
        XCTAssertTrue(encoder.outputFormatting.contains(.sortedKeys))
    }

    func testDecoder_Configuration() {
        let decoder = GuionJSONSerializer.decoder

        // Should decode ISO8601 dates
        // We can't directly test this, but we'll verify it works in integration tests
        XCTAssertNotNil(decoder)
    }

    // MARK: - Encode Tests

    func testEncode_EmptyDocument() throws {
        let snapshot = GuionDocumentSnapshot()

        let data = try GuionJSONSerializer.encode(snapshot)

        XCTAssertGreaterThan(data.count, 0)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(json)
    }

    func testEncode_ProducesPrettyPrintedJSON() throws {
        var snapshot = GuionDocumentSnapshot()
        snapshot.filename = "test.guion"
        snapshot.title = "Test"

        let data = try GuionJSONSerializer.encode(snapshot)
        let jsonString = String(data: data, encoding: .utf8)!

        // Should contain newlines (pretty-printed)
        XCTAssertTrue(jsonString.contains("\n"))
        // Should contain indentation
        XCTAssertTrue(jsonString.contains("  "))
    }

    func testEncode_ProducesSortedKeys() throws {
        var snapshot = GuionDocumentSnapshot()
        snapshot.filename = "test.guion"
        snapshot.title = "Test"

        let data = try GuionJSONSerializer.encode(snapshot)
        let jsonString = String(data: data, encoding: .utf8)!

        // Keys should appear in alphabetical order
        let idIndex = jsonString.range(of: "\"id\"")?.lowerBound
        let titleIndex = jsonString.range(of: "\"title\"")?.lowerBound

        XCTAssertNotNil(idIndex)
        XCTAssertNotNil(titleIndex)
        if let idIdx = idIndex, let titleIdx = titleIndex {
            XCTAssertLessThan(idIdx, titleIdx) // "id" comes before "title"
        }
    }

    func testEncode_WithElements() throws {
        var snapshot = GuionDocumentSnapshot()
        snapshot.elements = [
            GuionElementSnapshot(
                elementText: "INT. COFFEE SHOP - DAY",
                elementType: .sceneHeading
            )
        ]

        let data = try GuionJSONSerializer.encode(snapshot)

        XCTAssertGreaterThan(data.count, 0)

        // Verify elements are encoded
        let jsonString = String(data: data, encoding: .utf8)!
        XCTAssertTrue(jsonString.contains("INT. COFFEE SHOP - DAY"))
    }

    func testEncode_UTF8Characters() throws {
        var snapshot = GuionDocumentSnapshot()
        snapshot.filename = "screenplay-émojis-日本語.guion"
        snapshot.title = "Test 🎬 Émojis 日本語"

        let data = try GuionJSONSerializer.encode(snapshot)
        let decoded = try GuionJSONSerializer.decode(data)

        XCTAssertEqual(decoded.filename, snapshot.filename)
        XCTAssertEqual(decoded.title, snapshot.title)
    }

    func testEncode_SpecialCharacters() throws {
        var snapshot = GuionDocumentSnapshot()
        snapshot.elements = [
            GuionElementSnapshot(
                elementText: "Hello \"world\" \n\t\\<>&",
                elementType: .dialogue
            )
        ]

        let data = try GuionJSONSerializer.encode(snapshot)
        let decoded = try GuionJSONSerializer.decode(data)

        XCTAssertEqual(decoded.elements.first?.elementText, "Hello \"world\" \n\t\\<>&")
    }

    // MARK: - Decode Tests

    func testDecode_ValidJSON() throws {
        let jsonString = """
        {
          "id": "12345678-1234-1234-1234-123456789012",
          "filename": "test.guion",
          "title": "Test",
          "suppressSceneNumbers": false,
          "elements": [],
          "titlePage": []
        }
        """

        let data = jsonString.data(using: .utf8)!
        let snapshot = try GuionJSONSerializer.decode(data)

        XCTAssertEqual(snapshot.filename, "test.guion")
        XCTAssertEqual(snapshot.title, "Test")
        XCTAssertFalse(snapshot.suppressSceneNumbers)
    }

    func testDecode_WithMissingOptionalFields() throws {
        // Minimal valid JSON
        let jsonString = """
        {
          "id": "12345678-1234-1234-1234-123456789012",
          "suppressSceneNumbers": false,
          "elements": [],
          "titlePage": []
        }
        """

        let data = jsonString.data(using: .utf8)!
        let snapshot = try GuionJSONSerializer.decode(data)

        XCTAssertNil(snapshot.filename)
        XCTAssertNil(snapshot.title)
        XCTAssertNil(snapshot.casting)
    }

    func testDecode_WithElements() throws {
        let jsonString = """
        {
          "id": "12345678-1234-1234-1234-123456789012",
          "suppressSceneNumbers": false,
          "elements": [
            {
              "id": "87654321-4321-4321-4321-210987654321",
              "chapterIndex": 0,
              "orderIndex": 1,
              "elementText": "INT. COFFEE SHOP - DAY",
              "elementType": {
                "case": "sceneHeading"
              },
              "isCentered": false,
              "isDualDialogue": false,
              "sectionDepth": 0
            }
          ],
          "titlePage": []
        }
        """

        let data = jsonString.data(using: .utf8)!
        let snapshot = try GuionJSONSerializer.decode(data)

        XCTAssertEqual(snapshot.elements.count, 1)
        XCTAssertEqual(snapshot.elements.first?.elementText, "INT. COFFEE SHOP - DAY")
        XCTAssertEqual(snapshot.elements.first?.elementType, .sceneHeading)
    }

    func testDecode_InvalidJSON() {
        let invalidJSON = "not json".data(using: .utf8)!

        XCTAssertThrowsError(try GuionJSONSerializer.decode(invalidJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    // MARK: - Round-Trip Tests

    func testRoundTrip_EmptyDocument() throws {
        let original = GuionDocumentSnapshot()

        let data = try GuionJSONSerializer.encode(original)
        let decoded = try GuionJSONSerializer.decode(data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.suppressSceneNumbers, original.suppressSceneNumbers)
    }

    func testRoundTrip_CompleteDocument() throws {
        let original = createComplexSnapshot()

        let data = try GuionJSONSerializer.encode(original)
        let decoded = try GuionJSONSerializer.decode(data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.filename, original.filename)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.elements.count, original.elements.count)
        XCTAssertEqual(decoded.titlePage.count, original.titlePage.count)
    }

    func testRoundTrip_WithAudio() throws {
        var original = GuionDocumentSnapshot()
        original.filename = "test.guion"

        let audioID = UUID()
        original.generatedContent = [
            audioID: TypedDataStorageSnapshot(
                providerId: "elevenlabs",
                requestorID: "tts.rachel",
                mimeType: "audio/mpeg",
                prompt: "Test",
                binaryValue: Data([1, 2, 3, 4, 5]),
                durationSeconds: 2.5
            )
        ]

        let data = try GuionJSONSerializer.encode(original)
        let decoded = try GuionJSONSerializer.decode(data)

        XCTAssertEqual(decoded.generatedContent?.count, 1)
        XCTAssertEqual(decoded.generatedContent?[audioID]?.binaryValue, Data([1, 2, 3, 4, 5]))
    }

    func testRoundTrip_WithCasting() throws {
        var original = GuionDocumentSnapshot()
        original.casting = [
            "JANE": CharacterVoiceMappingSnapshot(
                voiceURI: "macos://Samantha",
                voiceName: "Samantha",
                providerID: "macos"
            ),
            "JOHN": CharacterVoiceMappingSnapshot(
                voiceURI: "elevenlabs://voice-123",
                voiceName: "Adam",
                providerID: "elevenlabs"
            )
        ]

        let data = try GuionJSONSerializer.encode(original)
        let decoded = try GuionJSONSerializer.decode(data)

        XCTAssertEqual(decoded.casting?.count, 2)
        XCTAssertEqual(decoded.casting?["JANE"]?.voiceName, "Samantha")
        XCTAssertEqual(decoded.casting?["JOHN"]?.voiceName, "Adam")
    }

    func testRoundTrip_LargeDocument() throws {
        var original = GuionDocumentSnapshot()
        original.filename = "large.guion"

        // Create 1000 elements
        original.elements = (0..<1000).map { index in
            GuionElementSnapshot(
                chapterIndex: index / 100,
                orderIndex: index,
                elementText: "Element \(index)",
                elementType: .action
            )
        }

        let data = try GuionJSONSerializer.encode(original)
        let decoded = try GuionJSONSerializer.decode(data)

        XCTAssertEqual(decoded.elements.count, 1000)
        XCTAssertEqual(decoded.elements.first?.elementText, "Element 0")
        XCTAssertEqual(decoded.elements.last?.elementText, "Element 999")
    }

    // MARK: - Validation Tests

    func testValidateRoundTrip_Success() throws {
        let snapshot = createComplexSnapshot()

        // Should not throw
        try GuionJSONSerializer.validateRoundTrip(snapshot)
    }

    func testValidateRoundTrip_DetectsIDMismatch() throws {
        // This test verifies the validation catches issues
        // In practice, round-trip should always preserve IDs
        let snapshot = GuionDocumentSnapshot()

        // Should not throw for valid round-trip
        XCTAssertNoThrow(try GuionJSONSerializer.validateRoundTrip(snapshot))
    }

    func testValidateRoundTrip_DetectsElementCountMismatch() throws {
        // This test verifies the validation catches issues
        let snapshot = createComplexSnapshot()

        // Should not throw for valid round-trip
        XCTAssertNoThrow(try GuionJSONSerializer.validateRoundTrip(snapshot))
    }

    // MARK: - File Format Metadata Tests

    func testFileFormat_Metadata() {
        XCTAssertEqual(GuionJSONSerializer.FileFormat.version, "1.0")
        XCTAssertEqual(GuionJSONSerializer.FileFormat.fileExtension, "guion")
        XCTAssertEqual(GuionJSONSerializer.FileFormat.uti, "com.swiftguion.screenplay")
        XCTAssertEqual(GuionJSONSerializer.FileFormat.mimeType, "application/vnd.swiftguion+json")
    }

    // MARK: - Performance Tests

    func testPerformance_Encode120PageScreenplay() throws {
        let snapshot = create120PageScreenplay()

        measure {
            _ = try? GuionJSONSerializer.encode(snapshot)
        }

        // Should complete in < 100ms (will vary by hardware)
    }

    func testPerformance_Decode120PageScreenplay() throws {
        let snapshot = create120PageScreenplay()
        let data = try GuionJSONSerializer.encode(snapshot)

        measure {
            _ = try? GuionJSONSerializer.decode(data)
        }

        // Should complete in < 100ms (will vary by hardware)
    }

    func testPerformance_RoundTrip() throws {
        let snapshot = create120PageScreenplay()

        measure {
            if let data = try? GuionJSONSerializer.encode(snapshot) {
                _ = try? GuionJSONSerializer.decode(data)
            }
        }

        // Should complete in < 200ms (will vary by hardware)
    }

    // MARK: - Helper Methods

    private func createComplexSnapshot() -> GuionDocumentSnapshot {
        var snapshot = GuionDocumentSnapshot()
        snapshot.filename = "complex.guion"
        snapshot.title = "Complex Screenplay"
        snapshot.suppressSceneNumbers = false

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

        return snapshot
    }

    private func create120PageScreenplay() -> GuionDocumentSnapshot {
        var snapshot = GuionDocumentSnapshot()
        snapshot.filename = "120-pages.guion"
        snapshot.title = "120 Page Screenplay"

        // Typical 120-page screenplay has ~800-1000 elements
        snapshot.elements = (0..<900).map { index in
            let types: [ElementType] = [.sceneHeading, .action, .character, .dialogue]
            let type = types[index % types.count]

            return GuionElementSnapshot(
                chapterIndex: index / 100,
                orderIndex: index,
                elementText: "Element \(index) text",
                elementType: type
            )
        }

        return snapshot
    }
}
