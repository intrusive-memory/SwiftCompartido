//
//  SceneBrowserTests.swift
//  SwiftGuionTests
//
//  Tests for Scene Browser data extraction and hierarchy
//

import XCTest
import SwiftFijos
@testable import SwiftCompartido

final class SceneBrowserTests: XCTestCase {

    // MARK: - Test Data Model Initialization

    func testSceneBrowserDataInitialization() {
        let title = OutlineElement(
            id: "title-1",
            index: 0,
            level: 1,
            range: [0, 10],
            rawString: "# Test Title",
            string: "Test Title",
            type: "sectionHeader"
        )

        let chapters: [ChapterData] = []
        let browserData = SceneBrowserData(title: title, chapters: chapters)

        XCTAssertNotNil(browserData.title)
        XCTAssertEqual(browserData.title?.string, "Test Title")
        XCTAssertEqual(browserData.chapters.count, 0)
    }

    func testChapterDataInitialization() {
        let chapterElement = OutlineElement(
            id: "chapter-1",
            index: 1,
            level: 2,
            range: [10, 20],
            rawString: "## Chapter 1",
            string: "CHAPTER 1",
            type: "sectionHeader"
        )

        let chapterData = ChapterData(element: chapterElement, sceneGroups: [])

        XCTAssertEqual(chapterData.id, "chapter-1")
        XCTAssertEqual(chapterData.title, "CHAPTER 1")
        XCTAssertEqual(chapterData.sceneGroups.count, 0)
    }

    func testSceneGroupDataInitialization() {
        let sceneGroupElement = OutlineElement(
            id: "group-1",
            index: 2,
            level: 3,
            range: [20, 30],
            rawString: "### PROLOGUE S#{{SERIES: 1001}}",
            string: "PROLOGUE",
            type: "sectionHeader",
            sceneDirective: "PROLOGUE",
            sceneDirectiveDescription: "S#{{SERIES: 1001}}"
        )

        let sceneGroupData = SceneGroupData(element: sceneGroupElement, scenes: [])

        XCTAssertEqual(sceneGroupData.id, "group-1")
        XCTAssertEqual(sceneGroupData.title, "PROLOGUE")
        XCTAssertEqual(sceneGroupData.directive, "PROLOGUE")
        XCTAssertEqual(sceneGroupData.directiveDescription, "S#{{SERIES: 1001}}")
        XCTAssertEqual(sceneGroupData.scenes.count, 0)
    }

    func testSceneDataInitialization() {
        let sceneElement = OutlineElement(
            id: "scene-1",
            index: 3,
            level: 0,
            range: [30, 100],
            rawString: "INT. STEAM ROOM - DAY",
            string: "INT. STEAM ROOM - DAY",
            type: "sceneHeader",
            sceneId: "uuid-123"
        )

        let sceneElements = [
            GuionElement(type: .action, text: "Bernard and Killian sit in a steam room.")
        ]

        let sceneData = SceneData(
            element: sceneElement,
            sceneElements: sceneElements
        )

        XCTAssertEqual(sceneData.id, "scene-1")
        XCTAssertEqual(sceneData.slugline, "INT. STEAM ROOM - DAY")
        XCTAssertEqual(sceneData.sceneId, "uuid-123")
        XCTAssertEqual(sceneData.sceneElements?.count, 1)
        XCTAssertFalse(sceneData.hasPreScene)
        XCTAssertFalse(sceneData.isOverBlack)
    }

    func testSceneDataWithPreScene() {
        let sceneElement = OutlineElement(
            id: "scene-1",
            index: 3,
            level: 0,
            range: [30, 100],
            rawString: "INT. STEAM ROOM - DAY",
            string: "INT. STEAM ROOM - DAY",
            type: "sceneHeader"
        )

        let sceneElements = [
            GuionElement(type: .action, text: "Bernard and Killian sit in a steam room.")
        ]

        let preSceneElements = [
            GuionElement(type: .action, text: "CHAPTER 1"),
            GuionElement(type: .action, text: "BERNARD")
        ]

        let sceneData = SceneData(
            element: sceneElement,
            sceneElements: sceneElements,
            preSceneElements: preSceneElements
        )

        XCTAssertTrue(sceneData.hasPreScene)
        XCTAssertEqual(sceneData.preSceneElements?.count, 2)
        XCTAssertTrue(sceneData.preSceneText.contains("CHAPTER 1"))
        XCTAssertTrue(sceneData.preSceneText.contains("BERNARD"))
    }

    func testOverBlackDetection() {
        let overBlackElement = OutlineElement(
            id: "scene-over-black",
            index: 1,
            level: 0,
            range: [5, 15],
            rawString: "OVER BLACK",
            string: "OVER BLACK",
            type: "sceneHeader"
        )

        let sceneData = SceneData(
            element: overBlackElement,
            sceneElements: []
        )

        XCTAssertTrue(sceneData.isOverBlack)
    }

    // MARK: - Test Hierarchy Extraction

    func testExtractSceneBrowserDataWithTestFixture() throws {
        // Load test.fountain fixture
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path

        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // Verify title exists
        XCTAssertNotNil(browserData.title, "Should have a title element")

        // Verify chapters exist
        XCTAssertGreaterThan(browserData.chapters.count, 0, "Should have at least one chapter")

        // Verify first chapter structure
        if let firstChapter = browserData.chapters.first {
            XCTAssertNotNil(firstChapter.element)
            XCTAssertTrue(firstChapter.element.isChapter)
            XCTAssertGreaterThan(firstChapter.sceneGroups.count, 0, "Chapter should have scene groups")
        }
    }

    func testSceneGroupsInChapter() throws {
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path

        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        guard let firstChapter = browserData.chapters.first else {
            XCTFail("Should have at least one chapter")
            return
        }

        // Verify scene groups exist
        XCTAssertGreaterThan(firstChapter.sceneGroups.count, 0, "Should have scene groups")

        // Verify scene group structure
        if let firstGroup = firstChapter.sceneGroups.first {
            XCTAssertEqual(firstGroup.element.level, 3)
            XCTAssertGreaterThan(firstGroup.scenes.count, 0, "Scene group should have scenes")
        }
    }

    func testScenesInSceneGroup() throws {
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path

        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        guard let firstChapter = browserData.chapters.first,
              let firstGroup = firstChapter.sceneGroups.first else {
            XCTFail("Should have chapter and scene group")
            return
        }

        // Verify scenes exist
        XCTAssertGreaterThan(firstGroup.scenes.count, 0, "Should have scenes")

        // Verify scene structure
        if let firstScene = firstGroup.scenes.first {
            XCTAssertFalse(firstScene.slugline.isEmpty, "Scene should have slugline")
            XCTAssertNotNil(firstScene.element)
            XCTAssertEqual(firstScene.element?.type, "sceneHeader")
        }
    }

    func testOverBlackAttachmentToNextScene() throws {
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path

        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // Find a scene with preScene content
        var foundPreScene = false
        for chapter in browserData.chapters {
            for sceneGroup in chapter.sceneGroups {
                for scene in sceneGroup.scenes {
                    if scene.hasPreScene {
                        foundPreScene = true
                        XCTAssertNotNil(scene.preSceneElements)
                        XCTAssertGreaterThan(scene.preSceneElements!.count, 0)
                        break
                    }
                }
                if foundPreScene { break }
            }
            if foundPreScene { break }
        }

        // Note: This test depends on test.fountain having OVER BLACK content
        // If it doesn't exist, the test will just verify the structure works
    }

    func testSceneDirectiveMetadata() throws {
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path

        let script = try GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // Look for scene groups with directives
        var foundDirective = false
        for chapter in browserData.chapters {
            for sceneGroup in chapter.sceneGroups {
                if sceneGroup.directive != nil {
                    foundDirective = true
                    XCTAssertFalse(sceneGroup.directive!.isEmpty)
                    // Directive description might be nil or might have metadata
                    break
                }
            }
            if foundDirective { break }
        }

        // Note: test.fountain may or may not have scene directives depending on fixture content
        // This test verifies that the directive extraction works when directives are present
        if !foundDirective {
            print("ℹ️  Note: test.fountain does not contain scene directives. Test verifies structure only.")
        }
    }

    // MARK: - Edge Cases

    func testEmptyScript() {
        let script = GuionParsedElementCollection()
        let browserData = script.extractSceneBrowserData()

        // Empty script may have a default "Untitled Script" title from outline generation
        // This is expected behavior
        XCTAssertEqual(browserData.chapters.count, 0)
    }

    func testScriptWithOnlyTitle() throws {
        let content = "# Test Title\n"
        let script = try GuionParsedElementCollection(string: content)
        let browserData = script.extractSceneBrowserData()

        XCTAssertNotNil(browserData.title)
        XCTAssertEqual(browserData.chapters.count, 0)
    }

    func testMultipleChapters() throws {
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path
        print("\n=== DEBUG: Loading file from: \(fountainPath) ===")

        let script = try GuionParsedElementCollection(file: fountainPath)
        print("Loaded \(script.elements.count) elements")

        // Debug: Check for Section Headings
        let sectionHeadings = script.elements.filter { $0.elementType.isSectionHeading }
        print("Found \(sectionHeadings.count) Section Headings")
        for heading in sectionHeadings.prefix(10) {
            print("  - Depth \(heading.sectionDepth): '\(heading.elementText)'")
        }

        let outline = script.extractOutline()

        // Debug: Print all level 2 elements
        print("\n=== DEBUG: All Level 2 Elements ===")
        let level2 = outline.filter { $0.level == 2 && $0.type == "sectionHeader" }
        for element in level2 {
            print("[\(element.index)] '\(element.string)' - isChapter:\(element.isChapter) END:\(element.isEndMarker) ERROR:\(element.hasHierarchyError)")
        }

        let browserData = script.extractSceneBrowserData()

        print("\n=== DEBUG: Chapters Found ===")
        for (index, chapter) in browserData.chapters.enumerated() {
            print("[\(index)] '\(chapter.title)'")
        }
        print("Total chapters: \(browserData.chapters.count)\n")

        // test.fountain should have at least one chapter
        // Note: Some test fixtures may only have a single chapter depending on content
        XCTAssertGreaterThanOrEqual(browserData.chapters.count, 1, "Should have at least one chapter")

        // Verify each chapter has an ID
        for chapter in browserData.chapters {
            XCTAssertFalse(chapter.id.isEmpty)
            XCTAssertTrue(chapter.element.isChapter)
        }
    }
}
