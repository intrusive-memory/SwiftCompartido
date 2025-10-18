//
//  SceneSummaryTests.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//
//  Tests for scene summarization functionality

import Testing
import SwiftFijos
@testable import SwiftCompartido
#if canImport(SwiftData)
import SwiftData
#endif

@Suite("Scene Summarization Tests")
struct SceneSummaryTests {

    @Test("SceneSummarizer extracts basic scene information")
    func testSceneSummarizerBasicExtraction() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)
        let outline = script.extractOutline()

        // Get first INT scene from Big Fish
        let firstScene = outline.first { $0.type == "sceneHeader" && $0.string.contains("INT.") }
        #expect(firstScene != nil, "Should find at least one INT scene")

        if let scene = firstScene {
            let sceneText = scene.sceneText(from: script, outline: outline)
            let summary = await SceneSummarizer.summarize(sceneText)

            #expect(summary != nil, "Summary should be generated")

            if let summary = summary {
                // Should not be empty
                #expect(summary.count > 0, "Summary should not be empty")

                print("Generated summary: \(summary)")
            }
        }
    }

    @Test("SceneSummarizer handles empty text")
    func testSceneSummarizerEmptyText() async throws {
        let summary = await SceneSummarizer.summarize("")
        #expect(summary == nil, "Empty text should return nil")
    }

    @Test("SceneSummarizer handles scene with minimal dialogue")
    func testSceneSummarizerMinimalDialogue() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)
        let outline = script.extractOutline()

        // Get an EXT scene from Big Fish
        let extScene = outline.first { $0.type == "sceneHeader" && $0.string.contains("EXT.") }

        if let scene = extScene {
            let sceneText = scene.sceneText(from: script, outline: outline)
            let summary = await SceneSummarizer.summarize(sceneText)
            #expect(summary != nil, "Should generate summary for scene")
        }
    }

    @Test("Scene text extraction and summarization integration")
    @MainActor
    func testSceneTextWithSummarization() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)
        let outline = script.extractOutline()

        // Find the first scene
        let firstScene = outline.first { $0.type == "sceneHeader" }
        #expect(firstScene != nil, "Should find a scene")

        if let scene = firstScene {
            // Test getting scene text
            let sceneText = scene.sceneText(from: script, outline: outline)
            #expect(!sceneText.isEmpty, "Scene text should not be empty")

            // Test summarizing the scene
            let summary = await SceneSummarizer.summarizeScene(scene, from: script, outline: outline)
            #expect(summary != nil, "Should generate summary for scene")

            if let summary = summary {
                print("Scene: \(scene.string)")
                print("Summary: \(summary)")
            }
        }
    }

    @Test("Scene text extraction correctly handles duplicate scene headings")
    func testDuplicateSceneHeadingTextExtraction() async throws {
        // Create a script with duplicate scene headings
        let fountainText = """
Title: Test Script with Duplicate Headings

INT. HOUSE - DAY

ALICE enters the house. She looks around the empty room.

ALICE
Where is everyone?

She walks to the kitchen.

INT. KITCHEN - DAY

BOB is cooking breakfast.

BOB
Good morning!

ALICE
Good morning! Smells great.

INT. HOUSE - DAY

Later that afternoon, CHARLIE enters the same house.

CHARLIE
Hello? Anyone home?

He checks the living room, but it's empty.

CHARLIE
(to himself)
Must have left already.

INT. KITCHEN - DAY

DIANA is making lunch.

DIANA
Who's there?

CHARLIE
(calling from other room)
It's just me!

"""

        let script = try GuionParsedScreenplay(string: fountainText)
        let outline = script.extractOutline()

        // Find all scenes with duplicate headings
        let houseScenes = outline.filter { $0.type == "sceneHeader" && $0.string == "INT. HOUSE - DAY" }
        let kitchenScenes = outline.filter { $0.type == "sceneHeader" && $0.string == "INT. KITCHEN - DAY" }

        // Verify we have duplicate scenes
        #expect(houseScenes.count == 2, "Should find 2 INT. HOUSE - DAY scenes")
        #expect(kitchenScenes.count == 2, "Should find 2 INT. KITCHEN - DAY scenes")

        // Verify each scene has a unique sceneId
        #expect(houseScenes[0].sceneId != nil, "First house scene should have sceneId")
        #expect(houseScenes[1].sceneId != nil, "Second house scene should have sceneId")
        #expect(houseScenes[0].sceneId != houseScenes[1].sceneId, "House scenes should have different sceneIds")

        #expect(kitchenScenes[0].sceneId != nil, "First kitchen scene should have sceneId")
        #expect(kitchenScenes[1].sceneId != nil, "Second kitchen scene should have sceneId")
        #expect(kitchenScenes[0].sceneId != kitchenScenes[1].sceneId, "Kitchen scenes should have different sceneIds")

        // Test first INT. HOUSE - DAY scene
        let firstHouseText = houseScenes[0].sceneText(from: script, outline: outline)
        #expect(firstHouseText.contains("ALICE"), "First house scene should contain ALICE")
        #expect(firstHouseText.contains("Where is everyone?"), "First house scene should contain ALICE's dialogue")
        #expect(!firstHouseText.contains("CHARLIE"), "First house scene should NOT contain CHARLIE")
        #expect(!firstHouseText.contains("Must have left already"), "First house scene should NOT contain CHARLIE's dialogue")

        // Test second INT. HOUSE - DAY scene
        let secondHouseText = houseScenes[1].sceneText(from: script, outline: outline)
        #expect(secondHouseText.contains("CHARLIE"), "Second house scene should contain CHARLIE")
        #expect(secondHouseText.contains("Must have left already"), "Second house scene should contain CHARLIE's dialogue")
        #expect(!secondHouseText.contains("ALICE"), "Second house scene should NOT contain ALICE")
        #expect(!secondHouseText.contains("Where is everyone?"), "Second house scene should NOT contain ALICE's dialogue")

        // Test first INT. KITCHEN - DAY scene
        let firstKitchenText = kitchenScenes[0].sceneText(from: script, outline: outline)
        #expect(firstKitchenText.contains("BOB"), "First kitchen scene should contain BOB")
        #expect(firstKitchenText.contains("Good morning!"), "First kitchen scene should contain morning greeting")
        #expect(firstKitchenText.contains("Smells great"), "First kitchen scene should contain ALICE's response")
        #expect(!firstKitchenText.contains("DIANA"), "First kitchen scene should NOT contain DIANA")

        // Test second INT. KITCHEN - DAY scene
        let secondKitchenText = kitchenScenes[1].sceneText(from: script, outline: outline)
        #expect(secondKitchenText.contains("DIANA"), "Second kitchen scene should contain DIANA")
        #expect(secondKitchenText.contains("Who's there?"), "Second kitchen scene should contain DIANA's dialogue")
        #expect(secondKitchenText.contains("It's just me"), "Second kitchen scene should contain CHARLIE's response")
        #expect(!secondKitchenText.contains("BOB"), "Second kitchen scene should NOT contain BOB")

        // Verify summaries would be different for duplicate scenes
        let firstHouseSummary = await SceneSummarizer.summarize(firstHouseText)
        let secondHouseSummary = await SceneSummarizer.summarize(secondHouseText)

        #expect(firstHouseSummary != nil, "First house scene should have a summary")
        #expect(secondHouseSummary != nil, "Second house scene should have a summary")

        if let summary1 = firstHouseSummary, let summary2 = secondHouseSummary {
            print("\nFirst INT. HOUSE - DAY summary: \(summary1)")
            print("Second INT. HOUSE - DAY summary: \(summary2)")

            // The summaries should be different since the scenes have different content
            #expect(summary1.contains("ALICE") || summary1.contains("Alice"), "First summary should reference Alice")
            #expect(summary2.contains("CHARLIE") || summary2.contains("Charlie"), "Second summary should reference Charlie")
        }
    }

    #if canImport(SwiftData)
    @Test("GuionElementModel includes summary field")
    func testGuionElementModelSummaryField() async throws {
        let element = GuionElementModel(
            elementText: "INT. COFFEE SHOP - DAY",
            elementType: .sceneHeading,
            summary: "Test summary"
        )

        #expect(element.summary == "Test summary", "Summary should be set correctly")
        #expect(element.elementType == .sceneHeading, "Element type should be Scene Heading")
    }

    @Test("Protocol-based conversion preserves summary")
    func testProtocolBasedConversionSummary() async throws {
        let element = GuionElement(elementType: .sceneHeading, elementText: "INT. COFFEE SHOP - DAY")
        let model = GuionElementModel(from: element, summary: "Test summary")

        #expect(model.summary == "Test summary", "Summary should be set correctly")
        #expect(model.elementType == .sceneHeading, "Element type should be Scene Heading")
        #expect(model.elementText == "INT. COFFEE SHOP - DAY", "Element text should be preserved")
    }
    #endif
}
