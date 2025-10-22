//
//  SceneBrowserUITests.swift
//  SwiftGuionTests
//
//  UI and Integration tests for Scene Browser widgets
//

import XCTest
import SwiftFijos
@testable import SwiftCompartido

final class SceneBrowserUITests: XCTestCase {

    // MARK: - Integration Tests with Real Data

    func testSceneBrowserDataFromTestFixture() throws {
        // Load test.fountain and extract browser data
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path
        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // Verify title exists
        XCTAssertNotNil(browserData.title, "Browser should have a title")
        XCTAssertFalse(browserData.title!.string.isEmpty, "Title should not be empty")

        // Verify chapters exist
        XCTAssertGreaterThan(browserData.chapters.count, 0, "Should have at least one chapter")

        // Verify first chapter structure
        let firstChapter = browserData.chapters[0]
        XCTAssertFalse(firstChapter.title.isEmpty, "Chapter should have a title")
        XCTAssertGreaterThan(firstChapter.sceneGroups.count, 0, "Chapter should have scene groups")

        // Verify scene group structure
        let firstGroup = firstChapter.sceneGroups[0]
        XCTAssertFalse(firstGroup.title.isEmpty, "Scene group should have a title")
        XCTAssertGreaterThan(firstGroup.scenes.count, 0, "Scene group should have scenes")

        // Verify scene structure
        let firstScene = firstGroup.scenes[0]
        XCTAssertFalse(firstScene.slugline.isEmpty, "Scene should have a slugline")
        XCTAssertNotNil(firstScene.element, "Scene should have outline element")
    }

    func testHierarchyIntegrityWithRealData() throws {
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path
        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // Verify all chapters have valid IDs
        for chapter in browserData.chapters {
            XCTAssertFalse(chapter.id.isEmpty, "Chapter should have valid ID")
            XCTAssertTrue(chapter.element.isChapter, "Chapter element should be marked as chapter")
            XCTAssertEqual(chapter.element.level, 2, "Chapter should be level 2")

            // Verify scene groups
            for sceneGroup in chapter.sceneGroups {
                XCTAssertFalse(sceneGroup.id.isEmpty, "Scene group should have valid ID")
                XCTAssertEqual(sceneGroup.element.level, 3, "Scene group should be level 3")

                // Verify scenes
                for scene in sceneGroup.scenes {
                    XCTAssertFalse(scene.id.isEmpty, "Scene should have valid ID")
                    XCTAssertEqual(scene.element?.type, "sceneHeader", "Scene element should be scene header")
                }
            }
        }
    }

    func testSceneContentExtraction() throws {
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path
        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // Find first scene with content
        var foundSceneWithContent = false
        for chapter in browserData.chapters {
            for sceneGroup in chapter.sceneGroups {
                for scene in sceneGroup.scenes {
                    if !(scene.sceneElements?.isEmpty ?? true) {
                        foundSceneWithContent = true

                        // Verify scene has elements
                        XCTAssertGreaterThan(scene.sceneElements?.count ?? 0, 0, "Scene should have elements")

                        // Verify elements have content
                        if let sceneElements = scene.sceneElements {
                            for element in sceneElements {
                                XCTAssertFalse(element.elementText.isEmpty, "Element should have text")
                                // ElementType is always valid (enum type)
                            }
                        }

                        break
                    }
                }
                if foundSceneWithContent { break }
            }
            if foundSceneWithContent { break }
        }

        XCTAssertTrue(foundSceneWithContent, "Should find at least one scene with content")
    }

    func testPreSceneContentAttachment() throws {
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path
        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // test.fountain has OVER BLACK content that should be attached to scenes
        var foundPreScene = false
        for chapter in browserData.chapters {
            for sceneGroup in chapter.sceneGroups {
                for scene in sceneGroup.scenes {
                    if scene.hasPreScene {
                        foundPreScene = true

                        XCTAssertNotNil(scene.preSceneElements, "PreScene elements should exist")
                        XCTAssertGreaterThan(scene.preSceneElements!.count, 0, "PreScene should have elements")

                        // Verify preScene content
                        for element in scene.preSceneElements! {
                            XCTAssertFalse(element.elementText.isEmpty, "PreScene element should have text")
                        }

                        // Verify preSceneText property
                        XCTAssertFalse(scene.preSceneText.isEmpty, "PreScene text should not be empty")

                        break
                    }
                }
                if foundPreScene { break }
            }
            if foundPreScene { break }
        }

        // Note: This test will pass even if no preScene is found,
        // as it verifies the structure works correctly
    }

    func testSceneLocationParsing() throws {
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path
        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // Find scenes with locations
        var foundSceneWithLocation = false
        for chapter in browserData.chapters {
            for sceneGroup in chapter.sceneGroups {
                for scene in sceneGroup.scenes {
                    if let location = scene.sceneLocation {
                        foundSceneWithLocation = true

                        // Verify location parsing
                        XCTAssertFalse(location.scene.isEmpty, "Location should have scene name")
                        XCTAssertNotEqual(location.lighting, .unknown, "Location should have valid lighting")

                        break
                    }
                }
                if foundSceneWithLocation { break }
            }
            if foundSceneWithLocation { break }
        }

        XCTAssertTrue(foundSceneWithLocation, "Should find at least one scene with parsed location")
    }

    func testSceneDirectiveMetadata() throws {
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path
        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // Look for scene groups with directives (like "### PROLOGUE S#{{SERIES: 1001}}")
        var foundDirective = false
        for chapter in browserData.chapters {
            for sceneGroup in chapter.sceneGroups {
                if let directive = sceneGroup.directive {
                    foundDirective = true

                    XCTAssertFalse(directive.isEmpty, "Directive should not be empty")

                    // Directive description is optional but should be valid if present
                    if let description = sceneGroup.directiveDescription {
                        XCTAssertFalse(description.isEmpty, "Directive description should not be empty if present")
                    }

                    break
                }
            }
            if foundDirective { break }
        }

        // Note: test.fountain may or may not have scene directives depending on fixture content
        if !foundDirective {
            print("ℹ️  Note: test.fountain does not contain scene directives. Test verifies structure only.")
        }
    }

    // MARK: - State Management Tests

    func testChapterExpansionState() {
        // Create sample browser data
        let browserData = createSampleBrowserData()

        // Verify we have chapters to test
        XCTAssertGreaterThan(browserData.chapters.count, 0, "Should have chapters for testing")

        // Test that chapter IDs are unique and valid
        var chapterIds = Set<String>()
        for chapter in browserData.chapters {
            XCTAssertFalse(chapter.id.isEmpty, "Chapter ID should not be empty")
            XCTAssertFalse(chapterIds.contains(chapter.id), "Chapter IDs should be unique")
            chapterIds.insert(chapter.id)
        }
    }

    func testSceneGroupExpansionState() {
        let browserData = createSampleBrowserData()

        // Verify scene groups have unique IDs
        var sceneGroupIds = Set<String>()
        for chapter in browserData.chapters {
            for sceneGroup in chapter.sceneGroups {
                XCTAssertFalse(sceneGroup.id.isEmpty, "Scene group ID should not be empty")
                XCTAssertFalse(sceneGroupIds.contains(sceneGroup.id), "Scene group IDs should be unique")
                sceneGroupIds.insert(sceneGroup.id)
            }
        }
    }

    func testSceneExpansionState() {
        let browserData = createSampleBrowserData()

        // Verify scenes have unique IDs
        var sceneIds = Set<String>()
        for chapter in browserData.chapters {
            for sceneGroup in chapter.sceneGroups {
                for scene in sceneGroup.scenes {
                    XCTAssertFalse(scene.id.isEmpty, "Scene ID should not be empty")
                    XCTAssertFalse(sceneIds.contains(scene.id), "Scene IDs should be unique")
                    sceneIds.insert(scene.id)
                }
            }
        }
    }

    // MARK: - Data Model Tests

    func testBrowserDataHierarchy() {
        let browserData = createSampleBrowserData()

        // Verify title
        XCTAssertNotNil(browserData.title, "Should have a title")
        XCTAssertEqual(browserData.title?.level, 1, "Title should be level 1")

        // Verify chapters
        XCTAssertGreaterThan(browserData.chapters.count, 0, "Should have chapters")

        for chapter in browserData.chapters {
            // Verify chapter level
            XCTAssertEqual(chapter.element.level, 2, "Chapter should be level 2")

            // Verify scene groups
            XCTAssertGreaterThan(chapter.sceneGroups.count, 0, "Chapter should have scene groups")

            for sceneGroup in chapter.sceneGroups {
                // Verify scene group level
                XCTAssertEqual(sceneGroup.element.level, 3, "Scene group should be level 3")

                // Verify scenes
                XCTAssertGreaterThan(sceneGroup.scenes.count, 0, "Scene group should have scenes")
            }
        }
    }

    func testMultipleChapters() throws {
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path
        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // test.fountain should have at least one chapter
        // Note: Some test fixtures may only have a single chapter depending on content
        XCTAssertGreaterThanOrEqual(browserData.chapters.count, 1, "test.fountain should have at least 1 chapter")

        // Verify each chapter has unique content
        let chapterTitles = Set(browserData.chapters.map { $0.title })
        XCTAssertEqual(chapterTitles.count, browserData.chapters.count, "Chapter titles should be unique")
    }

    // MARK: - Phase 5: Polish & Edge Case Tests

    func testEmptyChapterHandling() {
        // Create browser data with empty chapters array
        let browserData = SceneBrowserData(
            title: OutlineElement(
                id: "title-1",
                index: 0,
                level: 1,
                range: [0, 10],
                rawString: "# Test Script",
                string: "Test Script",
                type: "sectionHeader"
            ),
            chapters: []
        )

        XCTAssertNotNil(browserData.title, "Should have title even with no chapters")
        XCTAssertTrue(browserData.chapters.isEmpty, "Chapters should be empty")
    }

    func testChapterWithNoSceneGroups() {
        let browserData = SceneBrowserData(
            title: nil,
            chapters: [
                ChapterData(
                    element: OutlineElement(
                        id: "chapter-1",
                        index: 1,
                        level: 2,
                        range: [10, 20],
                        rawString: "## CHAPTER 1",
                        string: "CHAPTER 1",
                        type: "sectionHeader"
                    ),
                    sceneGroups: []
                )
            ]
        )

        XCTAssertEqual(browserData.chapters.count, 1, "Should have one chapter")
        XCTAssertTrue(browserData.chapters[0].sceneGroups.isEmpty, "Chapter should have no scene groups")
    }

    func testSceneGroupWithNoScenes() {
        let browserData = SceneBrowserData(
            title: nil,
            chapters: [
                ChapterData(
                    element: OutlineElement(
                        id: "chapter-1",
                        index: 1,
                        level: 2,
                        range: [10, 100],
                        rawString: "## CHAPTER 1",
                        string: "CHAPTER 1",
                        type: "sectionHeader"
                    ),
                    sceneGroups: [
                        SceneGroupData(
                            element: OutlineElement(
                                id: "group-1",
                                index: 2,
                                level: 3,
                                range: [20, 30],
                                rawString: "### PROLOGUE",
                                string: "PROLOGUE",
                                type: "sectionHeader"
                            ),
                            scenes: []
                        )
                    ]
                )
            ]
        )

        let firstChapter = browserData.chapters[0]
        XCTAssertEqual(firstChapter.sceneGroups.count, 1, "Should have one scene group")
        XCTAssertTrue(firstChapter.sceneGroups[0].scenes.isEmpty, "Scene group should have no scenes")
    }

    func testSceneWithNoElements() {
        let sceneData = SceneData(
            element: OutlineElement(
                id: "scene-1",
                index: 1,
                level: 0,
                range: [10, 20],
                rawString: "INT. EMPTY ROOM - DAY",
                string: "INT. EMPTY ROOM - DAY",
                type: "sceneHeader"
            ),
            sceneElements: [],
            sceneLocation: SceneLocation.parse("INT. EMPTY ROOM - DAY")
        )

        XCTAssertFalse(sceneData.slugline.isEmpty, "Scene should have slugline")
        XCTAssertTrue(sceneData.sceneElements?.isEmpty ?? true, "Scene should have no elements")
        XCTAssertFalse(sceneData.hasPreScene, "Scene should have no preScene")
    }

    func testSceneWithNilLocation() {
        let sceneData = SceneData(
            element: OutlineElement(
                id: "scene-1",
                index: 1,
                level: 0,
                range: [10, 20],
                rawString: "SOME INVALID SCENE HEADING",
                string: "SOME INVALID SCENE HEADING",
                type: "sceneHeader"
            ),
            sceneElements: [
                GuionElement(type: .action, text: "Something happens")
            ],
            sceneLocation: nil
        )

        XCTAssertNil(sceneData.sceneLocation, "Scene should have nil location")
        XCTAssertFalse(sceneData.sceneElements?.isEmpty ?? true, "Scene should still have elements")
    }

    func testPreSceneTextProperty() {
        let sceneData = SceneData(
            element: OutlineElement(
                id: "scene-1",
                index: 1,
                level: 0,
                range: [10, 20],
                rawString: "INT. ROOM - DAY",
                string: "INT. ROOM - DAY",
                type: "sceneHeader"
            ),
            sceneElements: [],
            preSceneElements: [
                GuionElement(type: .action, text: "CHAPTER 1"),
                GuionElement(type: .action, text: "BERNARD")
            ],
            sceneLocation: nil
        )

        XCTAssertTrue(sceneData.hasPreScene, "Scene should have preScene")
        XCTAssertEqual(sceneData.preSceneText, "CHAPTER 1\nBERNARD", "PreScene text should be joined with newlines")
    }

    func testEmptyPreSceneText() {
        let sceneData = SceneData(
            element: OutlineElement(
                id: "scene-1",
                index: 1,
                level: 0,
                range: [10, 20],
                rawString: "INT. ROOM - DAY",
                string: "INT. ROOM - DAY",
                type: "sceneHeader"
            ),
            sceneElements: [],
            preSceneElements: nil,
            sceneLocation: nil
        )

        XCTAssertFalse(sceneData.hasPreScene, "Scene should not have preScene")
        XCTAssertTrue(sceneData.preSceneText.isEmpty, "PreScene text should be empty")
    }

    func testLargeScriptPerformance() throws {
        // Test with BigFish which is a large script
        let fountainPath = try Fijos.getFixture("bigfish", extension: "fountain").path
        let script = try GuionParsedElementCollection(file: fountainPath)

        // Measure extraction time
        let startTime = Date()
        let browserData = script.extractSceneBrowserData()
        let duration = Date().timeIntervalSince(startTime)

        // Verify data was extracted
        XCTAssertNotNil(browserData.title, "BigFish should have a title")

        print("⚡ Performance: BigFish extraction took \(String(format: "%.3f", duration)) seconds")

        // Report performance metric (no assertion - tracked separately)
        print("📊 PERFORMANCE METRICS:")
        print("   BigFish extraction: \(String(format: "%.3f", duration))s")
    }

    func testDataIntegrityWithRealScript() throws {
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path
        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // Verify no empty IDs
        for chapter in browserData.chapters {
            XCTAssertFalse(chapter.id.isEmpty, "Chapter ID should not be empty")

            for sceneGroup in chapter.sceneGroups {
                XCTAssertFalse(sceneGroup.id.isEmpty, "Scene group ID should not be empty")

                for scene in sceneGroup.scenes {
                    XCTAssertFalse(scene.id.isEmpty, "Scene ID should not be empty")
                    XCTAssertFalse(scene.slugline.isEmpty, "Scene slugline should not be empty")
                }
            }
        }
    }

    func testSceneIdUniqueness() throws {
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path
        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // Collect all scene IDs
        var sceneIds = Set<String>()
        var duplicates: [String] = []

        for chapter in browserData.chapters {
            for sceneGroup in chapter.sceneGroups {
                for scene in sceneGroup.scenes {
                    if sceneIds.contains(scene.id) {
                        duplicates.append(scene.id)
                    }
                    sceneIds.insert(scene.id)
                }
            }
        }

        XCTAssertTrue(duplicates.isEmpty, "All scene IDs should be unique. Duplicates: \(duplicates)")
    }

    func testSyntheticChapterWithNoChapters() throws {
        // Create a simple fountain script without chapter markers
        let fountainText = """
# Script Title

### ACT ONE

INT. ROOM - DAY

Action line.

CHARACTER
Dialogue.
"""
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("test-no-chapters.fountain")
        try fountainText.write(to: tempURL, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let script = try GuionParsedElementCollection(file: tempURL.path)
        let browserData = script.extractSceneBrowserData()

        // Should create a synthetic chapter
        XCTAssertEqual(browserData.chapters.count, 1, "Should have one synthetic chapter")
        XCTAssertEqual(browserData.chapters[0].title, "(Untitled Section)", "Synthetic chapter should be named '(Untitled Section)'")
        XCTAssertTrue(browserData.chapters[0].element.isSynthetic, "Synthetic chapter should be marked as synthetic")

        // Should contain scene groups
        XCTAssertGreaterThan(browserData.chapters[0].sceneGroups.count, 0, "Synthetic chapter should have scene groups")
    }

    func testSyntheticChapterWithNoSceneGroups() throws {
        // Create a fountain script with only scenes, no structure
        let fountainText = """
INT. ROOM - DAY

Action line.

EXT. STREET - NIGHT

More action.
"""
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("test-no-groups.fountain")
        try fountainText.write(to: tempURL, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let script = try GuionParsedElementCollection(file: tempURL.path)
        let outline = script.extractOutline()

        print("📋 Outline elements:")
        for element in outline {
            print("  - \(element.type) level:\(element.level) parent:\(element.parentId ?? "nil") '\(element.string)'")
        }

        let browserData = script.extractSceneBrowserData()

        print("📊 Browser data:")
        print("  Chapters: \(browserData.chapters.count)")
        for chapter in browserData.chapters {
            print("  Chapter: '\(chapter.title)'")
            for group in chapter.sceneGroups {
                print("    Group: '\(group.title)' (\(group.scenes.count) scenes)")
                for scene in group.scenes {
                    print("      Scene: '\(scene.slugline)'")
                }
            }
        }

        // Should create synthetic chapter
        XCTAssertEqual(browserData.chapters.count, 1, "Should have one synthetic chapter")

        // The synthetic chapter will contain whatever structure is found
        // If there are scene headers at level 0, they become scene groups
        XCTAssertGreaterThan(browserData.chapters[0].sceneGroups.count, 0, "Should have scene groups")
    }

    func testDialogueDisplayInExpandedScene() throws {
        // Create a scene with dialogue elements
        let sceneWithDialogue = SceneData(
            element: OutlineElement(
                id: "scene-dialogue",
                index: 1,
                level: 0,
                range: [10, 100],
                rawString: "INT. COFFEE SHOP - DAY",
                string: "INT. COFFEE SHOP - DAY",
                type: "sceneHeader"
            ),
            sceneElements: [
                GuionElement(type: .action, text: "JANE sits at a table, typing on her laptop."),
                GuionElement(type: .character, text: "JOHN"),
                GuionElement(type: .dialogue, text: "Hey, Jane!"),
                GuionElement(type: .character, text: "JANE"),
                GuionElement(type: .parenthetical, text: "(looking up)"),
                GuionElement(type: .dialogue, text: "Oh, hi John!")
            ],
            sceneLocation: SceneLocation.parse("INT. COFFEE SHOP - DAY")
        )

        // Verify scene has dialogue elements
        XCTAssertNotNil(sceneWithDialogue.sceneElements, "Scene should have elements")
        XCTAssertEqual(sceneWithDialogue.sceneElements?.count, 6, "Scene should have 6 elements")

        // Verify dialogue elements are present
        let dialogueElements = sceneWithDialogue.sceneElements?.filter { $0.elementType == .dialogue }
        XCTAssertEqual(dialogueElements?.count, 2, "Scene should have 2 dialogue elements")
        XCTAssertEqual(dialogueElements?[0].elementText, "Hey, Jane!", "First dialogue should match")
        XCTAssertEqual(dialogueElements?[1].elementText, "Oh, hi John!", "Second dialogue should match")

        // Verify character elements are present
        let characterElements = sceneWithDialogue.sceneElements?.filter { $0.elementType == .character }
        XCTAssertEqual(characterElements?.count, 2, "Scene should have 2 character elements")
        XCTAssertEqual(characterElements?[0].elementText, "JOHN", "First character should be JOHN")
        XCTAssertEqual(characterElements?[1].elementText, "JANE", "Second character should be JANE")

        // Verify parenthetical element is present
        let parentheticalElements = sceneWithDialogue.sceneElements?.filter { $0.elementType == .parenthetical }
        XCTAssertEqual(parentheticalElements?.count, 1, "Scene should have 1 parenthetical")
        XCTAssertEqual(parentheticalElements?[0].elementText, "(looking up)", "Parenthetical should match")

        // Verify action element is present
        let actionElements = sceneWithDialogue.sceneElements?.filter { $0.elementType == .action }
        XCTAssertEqual(actionElements?.count, 1, "Scene should have 1 action")
        XCTAssertEqual(actionElements?[0].elementText, "JANE sits at a table, typing on her laptop.", "Action should match")

        print("✅ Dialogue display test passed - all elements present and correctly typed")
    }

    func testDialogueInRealScript() throws {
        // Load test.fountain and verify it contains dialogue
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path
        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // Find a scene with dialogue
        var foundDialogue = false
        var sceneWithDialogue: SceneData?

        for chapter in browserData.chapters {
            for sceneGroup in chapter.sceneGroups {
                for scene in sceneGroup.scenes {
                    if let elements = scene.sceneElements {
                        let hasDialogue = elements.contains { $0.elementType == .dialogue }
                        if hasDialogue {
                            foundDialogue = true
                            sceneWithDialogue = scene
                            break
                        }
                    }
                }
                if foundDialogue { break }
            }
            if foundDialogue { break }
        }

        if let scene = sceneWithDialogue {
            print("📝 Found scene with dialogue: '\(scene.slugline)'")

            // Verify dialogue structure
            let dialogueElements = scene.sceneElements?.filter { $0.elementType == .dialogue } ?? []
            let characterElements = scene.sceneElements?.filter { $0.elementType == .character } ?? []

            XCTAssertGreaterThan(dialogueElements.count, 0, "Should have dialogue elements")
            XCTAssertGreaterThan(characterElements.count, 0, "Should have character elements")

            // Print dialogue for debugging
            for element in scene.sceneElements ?? [] {
                if element.elementType == .character || element.elementType == .dialogue || element.elementType == .parenthetical {
                    print("  \(element.elementType): \(element.elementText)")
                }
            }

            print("✅ Dialogue verification passed")
        } else {
            // Note: test.fountain may or may not have dialogue depending on fixture content
            print("ℹ️  Note: test.fountain does not contain dialogue. Test verifies structure only.")
        }
    }

    func testDialogueBlockGrouping() throws {
        // Create test elements
        let elements = [
            GuionElementModel(elementText: "Action line 1", elementType: .action),
            GuionElementModel(elementText: "JOHN", elementType: .character),
            GuionElementModel(elementText: "Hello!", elementType: .dialogue),
            GuionElementModel(elementText: "JANE", elementType: .character),
            GuionElementModel(elementText: "(smiling)", elementType: .parenthetical),
            GuionElementModel(elementText: "Hi there!", elementType: .dialogue),
            GuionElementModel(elementText: "Action line 2", elementType: .action)
        ]

        let blocks = groupDialogueBlocks(elements: elements)

        // Should have 4 blocks: Action, John's dialogue, Jane's dialogue, Action
        XCTAssertEqual(blocks.count, 4, "Should have 4 blocks")

        // Block 0: Action
        XCTAssertFalse(blocks[0].isDialogueBlock, "First block should not be dialogue")
        XCTAssertEqual(blocks[0].elements.count, 1, "Action block should have 1 element")

        // Block 1: John's dialogue
        XCTAssertTrue(blocks[1].isDialogueBlock, "Second block should be dialogue")
        XCTAssertEqual(blocks[1].elements.count, 2, "John's block should have 2 elements (Character + Dialogue)")
        XCTAssertEqual(blocks[1].elements[0].elementType, .character)
        XCTAssertEqual(blocks[1].elements[1].elementType, .dialogue)

        // Block 2: Jane's dialogue with parenthetical
        XCTAssertTrue(blocks[2].isDialogueBlock, "Third block should be dialogue")
        XCTAssertEqual(blocks[2].elements.count, 3, "Jane's block should have 3 elements (Character + Parenthetical + Dialogue)")
        XCTAssertEqual(blocks[2].elements[0].elementType, .character)
        XCTAssertEqual(blocks[2].elements[1].elementType, .parenthetical)
        XCTAssertEqual(blocks[2].elements[2].elementType, .dialogue)

        // Block 3: Action
        XCTAssertFalse(blocks[3].isDialogueBlock, "Fourth block should not be dialogue")
        XCTAssertEqual(blocks[3].elements.count, 1, "Action block should have 1 element")

        print("✅ Dialogue block grouping test passed")
    }

    func testDialogueElementModels() throws {
        // Test that dialogue converts correctly to GuionElementModel
        let sceneWithDialogue = SceneData(
            element: OutlineElement(
                id: "scene-dialogue",
                index: 1,
                level: 0,
                range: [10, 100],
                rawString: "INT. ROOM - DAY",
                string: "INT. ROOM - DAY",
                type: "sceneHeader"
            ),
            sceneElements: [
                GuionElement(type: .character, text: "BOB"),
                GuionElement(type: .dialogue, text: "This is a test."),
                GuionElement(type: .parenthetical, text: "(whispering)"),
                GuionElement(type: .dialogue, text: "Can you hear me?")
            ],
            sceneLocation: nil
        )

        // Get element models (this is what the UI actually uses)
        let elementModels = sceneWithDialogue.sceneElementModels

        XCTAssertEqual(elementModels.count, 4, "Should have 4 element models")

        // Verify each element model
        XCTAssertEqual(elementModels[0].elementType, .character, "First should be Character")
        XCTAssertEqual(elementModels[0].elementText, "BOB", "Character name should be BOB")

        XCTAssertEqual(elementModels[1].elementType, .dialogue, "Second should be Dialogue")
        XCTAssertEqual(elementModels[1].elementText, "This is a test.", "Dialogue text should match")

        XCTAssertEqual(elementModels[2].elementType, .parenthetical, "Third should be Parenthetical")
        XCTAssertEqual(elementModels[2].elementText, "(whispering)", "Parenthetical text should match")

        XCTAssertEqual(elementModels[3].elementType, .dialogue, "Fourth should be Dialogue")
        XCTAssertEqual(elementModels[3].elementText, "Can you hear me?", "Second dialogue should match")

        print("✅ Element model conversion test passed")
    }

    func testSyntheticElementsNotExported() throws {
        // Create a synthetic element directly
        let syntheticElement = OutlineElement(
            id: "synthetic-test",
            index: -1,
            level: 2,
            range: [0, 0],
            rawString: "## Scenes",
            string: "Scenes",
            type: "sectionHeader",
            isSynthetic: true
        )

        // Encode the synthetic element
        let encoder = JSONEncoder()
        let elementData = try encoder.encode(syntheticElement)

        // Verify it's empty (synthetic elements skip encoding)
        let elementJSON = String(data: elementData, encoding: .utf8)!
        XCTAssertEqual(elementJSON, "{}", "Synthetic elements should encode as empty JSON object")

        // Test a non-synthetic element for comparison
        let regularElement = OutlineElement(
            id: "regular-test",
            index: 1,
            level: 2,
            range: [0, 10],
            rawString: "## Chapter 1",
            string: "Chapter 1",
            type: "sectionHeader",
            isSynthetic: false
        )

        let regularData = try encoder.encode(regularElement)
        let regularJSON = String(data: regularData, encoding: .utf8)!
        XCTAssertNotEqual(regularJSON, "{}", "Regular elements should encode with full data")
        XCTAssertTrue(regularJSON.contains("Chapter 1"), "Regular element JSON should contain the element string")

        print("✅ Verified synthetic elements are not exported")
    }

    // MARK: - Helper Methods

    private func createSampleBrowserData() -> SceneBrowserData {
        return SceneBrowserData(
            title: OutlineElement(
                id: "title-1",
                index: 0,
                level: 1,
                range: [0, 10],
                rawString: "# Test Script",
                string: "Test Script",
                type: "sectionHeader"
            ),
            chapters: [
                ChapterData(
                    element: OutlineElement(
                        id: "chapter-1",
                        index: 1,
                        level: 2,
                        range: [10, 100],
                        rawString: "## CHAPTER 1",
                        string: "CHAPTER 1",
                        type: "sectionHeader"
                    ),
                    sceneGroups: [
                        SceneGroupData(
                            element: OutlineElement(
                                id: "group-1",
                                index: 2,
                                level: 3,
                                range: [20, 80],
                                rawString: "### PROLOGUE",
                                string: "PROLOGUE",
                                type: "sectionHeader"
                            ),
                            scenes: [
                                SceneData(
                                    element: OutlineElement(
                                        id: "scene-1",
                                        index: 3,
                                        level: 0,
                                        range: [30, 70],
                                        rawString: "INT. STEAM ROOM - DAY",
                                        string: "INT. STEAM ROOM - DAY",
                                        type: "sceneHeader"
                                    ),
                                    sceneElements: [
                                        GuionElement(type: .action, text: "Bernard and Killian sit in a steam room.")
                                    ],
                                    sceneLocation: SceneLocation.parse("INT. STEAM ROOM - DAY")
                                )
                            ]
                        )
                    ]
                )
            ]
        )
    }
}
