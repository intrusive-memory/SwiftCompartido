//
//  CharacterInfoTests.swift
//  SwiftGuionTests
//
//  Tests for character extraction and analysis functionality
//

import Testing
import Foundation
@testable import SwiftCompartido

@Suite("CharacterInfo Tests")
struct CharacterInfoTests {

    @Test("Extract characters and write to JSON file")
    func testWriteCharactersJSON() throws {
        // Create a simple script with characters
        let script = GuionParsedScreenplay(
            elements: [
                GuionElement(elementType: .sceneHeading, elementText: "INT. COFFEE SHOP - DAY"),
                GuionElement(elementType: .character, elementText: "ALICE"),
                GuionElement(elementType: .dialogue, elementText: "Hello, Bob!"),
                GuionElement(elementType: .character, elementText: "BOB"),
                GuionElement(elementType: .dialogue, elementText: "Hi, Alice!"),
                GuionElement(elementType: .character, elementText: "ALICE"),
                GuionElement(elementType: .dialogue, elementText: "How are you?"),
            ]
        )

        // Write to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let outputPath = tempDir.appendingPathComponent("test-characters.json").path

        try script.writeCharactersJSON(toFile: outputPath)

        // Verify file was created
        #expect(FileManager.default.fileExists(atPath: outputPath), "JSON file should be created")

        // Verify the content can be read back
        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json != nil, "Should be able to parse character JSON")
        #expect(json!["ALICE"] != nil, "Should contain ALICE")
        #expect(json!["BOB"] != nil, "Should contain BOB")

        // Clean up
        try? FileManager.default.removeItem(atPath: outputPath)
    }

    @Test("Write characters JSON with special character names")
    func testWriteCharactersJSONWithSpecialNames() throws {
        let script = GuionParsedScreenplay(
            elements: [
                GuionElement(elementType: .character, elementText: "JOHN (V.O.)"),
                GuionElement(elementType: .dialogue, elementText: "This is a voiceover."),
                GuionElement(elementType: .character, elementText: "SARAH (O.S.)"),
                GuionElement(elementType: .dialogue, elementText: "I'm off screen."),
            ]
        )

        let tempDir = FileManager.default.temporaryDirectory
        let outputPath = tempDir.appendingPathComponent("test-special-characters.json").path

        try script.writeCharactersJSON(toFile: outputPath)

        #expect(FileManager.default.fileExists(atPath: outputPath))

        // Clean up
        try? FileManager.default.removeItem(atPath: outputPath)
    }

    @Test("Write empty characters to JSON")
    func testWriteEmptyCharactersJSON() throws {
        let script = GuionParsedScreenplay(
            elements: [
                GuionElement(elementType: .sceneHeading, elementText: "INT. ROOM - DAY"),
                GuionElement(elementType: .action, elementText: "The room is empty."),
            ]
        )

        let tempDir = FileManager.default.temporaryDirectory
        let outputPath = tempDir.appendingPathComponent("test-empty-characters.json").path

        try script.writeCharactersJSON(toFile: outputPath)

        #expect(FileManager.default.fileExists(atPath: outputPath))

        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json != nil, "Should be able to parse JSON")
        #expect(json!.isEmpty, "Should be empty when no characters")

        // Clean up
        try? FileManager.default.removeItem(atPath: outputPath)
    }
}
