//
//  TextPackTests.swift
//  SwiftGuionTests
//
//  Copyright (c) 2025
//

import Testing
import Foundation
import SwiftFijos
@testable import SwiftCompartido

/// Tests for TextPack bundle format (.guion files)
struct TextPackTests {

    // MARK: - TextPack Creation Tests

    @Test func testCreateTextPackFromScreenplay() async throws {
        // Create a simple screenplay
        let screenplay = try GuionParsedScreenplay(string: """
        Title: Test Script
        Author: Test Author

        INT. COFFEE SHOP - DAY

        JOHN enters.

        JOHN
        Hello, world!
        """)

        // Create TextPack
        let textPack = try TextPackWriter.createTextPack(from: screenplay)

        // Verify it's a directory
        #expect(textPack.isDirectory)

        // Verify required files exist
        let fileWrappers = textPack.fileWrappers
        #expect(fileWrappers?["info.json"] != nil)
        #expect(fileWrappers?["screenplay.fountain"] != nil)
        #expect(fileWrappers?["Resources"] != nil)
    }

    @Test func testTextPackContainsInfoJSON() async throws {
        let screenplay = try GuionParsedScreenplay(string: """
        Title: My Script

        INT. ROOM - DAY

        Action here.
        """)

        let textPack = try TextPackWriter.createTextPack(from: screenplay)

        // Read info.json
        guard let infoWrapper = textPack.fileWrappers?["info.json"],
              let infoData = infoWrapper.regularFileContents else {
            Issue.record("info.json not found in TextPack")
            return
        }

        let info = try JSONDecoder.textPackDecoder.decode(TextPackInfo.self, from: infoData)

        #expect(info.version == "1.0")
        #expect(info.format == "guion-textpack")
        #expect(info.resources.contains("characters.json"))
        #expect(info.resources.contains("locations.json"))
        #expect(info.resources.contains("elements.json"))
        #expect(info.resources.contains("titlepage.json"))
    }

    @Test func testTextPackContainsScreenplayFountain() async throws {
        let originalScript = """
        INT. OFFICE - DAY

        JANE sits at her desk.
        """

        let screenplay = try GuionParsedScreenplay(string: originalScript)
        let textPack = try TextPackWriter.createTextPack(from: screenplay)

        // Read screenplay.fountain
        guard let screenplayWrapper = textPack.fileWrappers?["screenplay.fountain"],
              let screenplayData = screenplayWrapper.regularFileContents,
              let screenplayText = String(data: screenplayData, encoding: .utf8) else {
            Issue.record("screenplay.fountain not found or unreadable")
            return
        }

        #expect(screenplayText.contains("INT. OFFICE - DAY"))
        #expect(screenplayText.contains("JANE sits at her desk"))
    }

    @Test func testTextPackContainsResourcesDirectory() async throws {
        let screenplay = try GuionParsedScreenplay(string: """
        INT. BAR - NIGHT

        MIKE
        Great to see you!

        SARAH
        You too!
        """)

        let textPack = try TextPackWriter.createTextPack(from: screenplay)

        // Verify Resources directory
        guard let resourcesWrapper = textPack.fileWrappers?["Resources"],
              resourcesWrapper.isDirectory,
              let resourceFiles = resourcesWrapper.fileWrappers else {
            Issue.record("Resources directory not found or invalid")
            return
        }

        #expect(resourceFiles["characters.json"] != nil)
        #expect(resourceFiles["locations.json"] != nil)
        #expect(resourceFiles["elements.json"] != nil)
        #expect(resourceFiles["titlepage.json"] != nil)
    }

    // MARK: - TextPack Reading Tests

    @Test func testReadTextPackRoundTrip() async throws {
        // Create original screenplay
        let original = try GuionParsedScreenplay(string: """
        Title: Round Trip Test

        INT. APARTMENT - DAY

        BOB enters.

        BOB
        Testing round trip!
        """)

        // Write to TextPack
        let textPack = try TextPackWriter.createTextPack(from: original)

        // Read back
        let restored = try TextPackReader.readTextPack(from: textPack)

        // Verify content preserved
        #expect(restored.elements.count == original.elements.count)
        #expect(restored.titlePage.count == original.titlePage.count)
    }

    @Test func testReadCharactersJSON() async throws {
        let screenplay = try GuionParsedScreenplay(string: """
        INT. OFFICE - DAY

        ALICE
        Hello!

        BOB
        Hi there!

        ALICE
        How are you?
        """)

        let textPack = try TextPackWriter.createTextPack(from: screenplay)

        // Read characters
        guard let characters = TextPackReader.readCharacters(from: textPack) else {
            Issue.record("Could not read characters.json")
            return
        }

        #expect(characters.characters.count == 2)

        let names = characters.characters.map { $0.name }.sorted()
        #expect(names == ["ALICE", "BOB"])

        // Verify ALICE has 2 dialogue lines
        let alice = characters.characters.first { $0.name == "ALICE" }
        #expect(alice?.dialogueLines == 2)
    }

    @Test func testReadLocationsJSON() async throws {
        let screenplay = try GuionParsedScreenplay(string: """
        INT. COFFEE SHOP - DAY

        Action here.

        EXT. PARK - NIGHT

        More action.

        INT. COFFEE SHOP - DAY

        Back to the coffee shop.
        """)

        let textPack = try TextPackWriter.createTextPack(from: screenplay)

        // Read locations
        guard let locations = TextPackReader.readLocations(from: textPack) else {
            Issue.record("Could not read locations.json")
            return
        }

        // Should have 2 unique locations (COFFEE SHOP appears twice)
        #expect(locations.locations.count == 2)

        // Verify location details
        let coffeeShop = locations.locations.first { $0.scene == "COFFEE SHOP" }
        #expect(coffeeShop?.lighting == "INT") // Stored as abbreviated form
        #expect(coffeeShop?.timeOfDay == "DAY")
        #expect(coffeeShop?.sceneIds.count == 2) // Appears in 2 scenes

        let park = locations.locations.first { $0.scene == "PARK" }
        #expect(park?.lighting == "EXT") // Stored as abbreviated form
        #expect(park?.timeOfDay == "NIGHT")
    }

    @Test func testReadElementsJSON() async throws {
        let screenplay = try GuionParsedScreenplay(string: """
        INT. ROOM - DAY

        Action line.

        CHARACTER
        Dialogue line.
        """)

        let textPack = try TextPackWriter.createTextPack(from: screenplay)

        // Read elements
        guard let elements = TextPackReader.readElements(from: textPack) else {
            Issue.record("Could not read elements.json")
            return
        }

        #expect(elements.elements.count == screenplay.elements.count)

        // Verify element types (TextPack elements use string representations)
        let types = elements.elements.map { $0.elementType }
        #expect(types.contains("Scene Heading"))
        #expect(types.contains("Action"))
        #expect(types.contains("Character"))
        #expect(types.contains("Dialogue"))
    }

    @Test func testReadTitlePageJSON() async throws {
        let screenplay = try GuionParsedScreenplay(string: """
        Title: My Great Script
        Author: Jane Doe
        Draft: First Draft

        INT. ROOM - DAY

        Action.
        """)

        let textPack = try TextPackWriter.createTextPack(from: screenplay)

        // Read title page
        guard let titlePage = TextPackReader.readTitlePage(from: textPack) else {
            Issue.record("Could not read titlepage.json")
            return
        }

        #expect(titlePage.titlePage.count > 0)
    }

    // MARK: - Error Handling Tests

    @Test func testReadTextPackFromNonDirectory() async throws {
        // Create a regular file wrapper (not a directory)
        let regularFile = FileWrapper(regularFileWithContents: Data("not a bundle".utf8))

        do {
            _ = try TextPackReader.readTextPack(from: regularFile)
            Issue.record("Should have thrown notADirectory error")
        } catch TextPackError.notADirectory {
            // Expected
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test func testReadTextPackMissingScreenplayFile() async throws {
        // Create directory without screenplay.fountain
        let emptyDir = FileWrapper(directoryWithFileWrappers: [:])

        do {
            _ = try TextPackReader.readTextPack(from: emptyDir)
            Issue.record("Should have thrown missingScreenplayFile error")
        } catch TextPackError.missingScreenplayFile {
            // Expected
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - Character Extraction Tests

    @Test func testCharacterExtractionWithSceneMapping() async throws {
        let screenplay = try GuionParsedScreenplay(string: """
        INT. OFFICE - DAY #1#

        JOHN
        First scene.

        INT. PARK - DAY #2#

        JANE
        Second scene.

        JOHN
        Also in second scene.
        """)

        let textPack = try TextPackWriter.createTextPack(from: screenplay)
        guard let characters = TextPackReader.readCharacters(from: textPack) else {
            Issue.record("Could not read characters")
            return
        }

        let john = characters.characters.first { $0.name == "JOHN" }
        #expect(john?.scenes.count == 2) // Appears in 2 scenes

        let jane = characters.characters.first { $0.name == "JANE" }
        #expect(jane?.scenes.count == 1) // Appears in 1 scene
    }

    // MARK: - Integration Tests

    @Test func testTextPackWithBigFishFixture() async throws {
        // Load Big Fish screenplay
        let bigfishURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let screenplay = try GuionParsedScreenplay(file: bigfishURL.path)

        // Create TextPack
        let textPack = try TextPackWriter.createTextPack(from: screenplay)

        // Verify structure
        #expect(textPack.isDirectory)
        #expect(textPack.fileWrappers?["info.json"] != nil)
        #expect(textPack.fileWrappers?["screenplay.fountain"] != nil)
        #expect(textPack.fileWrappers?["Resources"] != nil)

        // Read back and verify
        let restored = try TextPackReader.readTextPack(from: textPack)
        #expect(restored.elements.count == screenplay.elements.count)

        // Verify characters were extracted
        let characters = TextPackReader.readCharacters(from: textPack)
        #expect(characters?.characters.count ?? 0 > 0)

        // Verify locations were extracted
        let locations = TextPackReader.readLocations(from: textPack)
        #expect(locations?.locations.count ?? 0 > 0)
    }
}
