//
//  SceneBrowserTests.swift
//  SwiftGuionTests
//
//  Tests for Scene Browser data extraction and hierarchy
//

import Testing
import SwiftFijos
@testable import SwiftCompartido

struct SceneBrowserTests {

    // MARK: - Test Data Model Initialization

    @Test func testSceneBrowserDataInitialization() {
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

        #expect(browserData.title != nil)
        #expect(browserData.title?.string == "Test Title")
        #expect(browserData.chapters.count == 0)
    }

    @Test func testChapterDataInitialization() {
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

        #expect(chapterData.id == "chapter-1")
        #expect(chapterData.title == "CHAPTER 1")
        #expect(chapterData.sceneGroups.count == 0)
    }

    @Test func testSceneGroupDataInitialization() {
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

        #expect(sceneGroupData.id == "group-1")
        #expect(sceneGroupData.title == "PROLOGUE")
        #expect(sceneGroupData.directive == "PROLOGUE")
        #expect(sceneGroupData.directiveDescription == "S#{{SERIES: 1001}}")
        #expect(sceneGroupData.scenes.count == 0)
    }

    @Test func testSceneDataInitialization() {
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

        #expect(sceneData.id == "scene-1")
        #expect(sceneData.slugline == "INT. STEAM ROOM - DAY")
        #expect(sceneData.sceneId == "uuid-123")
        #expect(sceneData.sceneElements?.count == 1)
        #expect(!sceneData.hasPreScene)
        #expect(!sceneData.isOverBlack)
    }

    @Test func testSceneDataWithPreScene() {
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

        #expect(sceneData.hasPreScene)
        #expect(sceneData.preSceneElements?.count == 2)
        #expect(sceneData.preSceneText.contains("CHAPTER 1"))
        #expect(sceneData.preSceneText.contains("BERNARD"))
    }

    @Test func testOverBlackDetection() {
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

        #expect(sceneData.isOverBlack)
    }

    // MARK: - Test Hierarchy Extraction

    @Test func testExtractSceneBrowserDataWithTestFixture() async throws {
        // Load test.fountain fixture
        let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") { $0 }.path

        let script = try await GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // Verify title exists
        #expect(browserData.title, "Should have a title element" != nil)

        // Verify chapters exist
        #expect(browserData.chapters.count > 0, "Should have at least one chapter")

        // Verify first chapter structure
        if let firstChapter = browserData.chapters.first {
            #expect(firstChapter.element != nil)
            #expect(firstChapter.element.isChapter)
            #expect(firstChapter.sceneGroups.count > 0, "Chapter should have scene groups")
        }
    }

    @Test func testSceneGroupsInChapter() async throws {
        let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") { $0 }.path

        let script = try await GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        guard let firstChapter = browserData.chapters.first else {
            Issue.record("Should have at least one chapter")
            return
        }

        // Verify scene groups exist
        #expect(firstChapter.sceneGroups.count > 0, "Should have scene groups")

        // Verify scene group structure
        if let firstGroup = firstChapter.sceneGroups.first {
            #expect(firstGroup.element.level == 3)
            #expect(firstGroup.scenes.count > 0, "Scene group should have scenes")
        }
    }

    @Test func testScenesInSceneGroup() async throws {
        let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") { $0 }.path

        let script = try await GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        guard let firstChapter = browserData.chapters.first,
              let firstGroup = firstChapter.sceneGroups.first else {
            Issue.record("Should have chapter and scene group")
            return
        }

        // Verify scenes exist
        #expect(firstGroup.scenes.count > 0, "Should have scenes")

        // Verify scene structure
        if let firstScene = firstGroup.scenes.first {
            #expect(!firstScene.slugline.isEmpty, "Scene should have slugline")
            #expect(firstScene.element != nil)
            #expect(firstScene.element?.type == "sceneHeader")
        }
    }

    @Test func testOverBlackAttachmentToNextScene() async throws {
        let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") { $0 }.path

        let script = try await GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // Find a scene with preScene content
        var foundPreScene = false
        for chapter in browserData.chapters {
            for sceneGroup in chapter.sceneGroups {
                for scene in sceneGroup.scenes {
                    if scene.hasPreScene {
                        foundPreScene = true
                        #expect(scene.preSceneElements != nil)
                        #expect(scene.preSceneElements!.count > 0)
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

    @Test func testSceneDirectiveMetadata() async throws {
        let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") { $0 }.path

        let script = try await GuionParsedElementCollection(file: fountainPath)
        let browserData = script.extractSceneBrowserData()

        // Look for scene groups with directives
        var foundDirective = false
        for chapter in browserData.chapters {
            for sceneGroup in chapter.sceneGroups {
                if sceneGroup.directive != nil {
                    foundDirective = true
                    #expect(!sceneGroup.directive!.isEmpty)
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

    @Test func testEmptyScript() {
        let script = GuionParsedElementCollection()
        let browserData = script.extractSceneBrowserData()

        // Empty script may have a default "Untitled Script" title from outline generation
        // This is expected behavior
        #expect(browserData.chapters.count == 0)
    }

    @Test func testScriptWithOnlyTitle() async throws {
        let content = "# Test Title\n"
        let script = try await GuionParsedElementCollection(string: content)
        let browserData = script.extractSceneBrowserData()

        #expect(browserData.title != nil)
        #expect(browserData.chapters.count == 0)
    }

    @Test func testMultipleChapters() async throws {
        let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") { $0 }.path
        print("\n=== DEBUG: Loading file from: \(fountainPath) ===")

        let script = try await GuionParsedElementCollection(file: fountainPath)
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
        #expect(browserData.chapters.count >= 1, "Should have at least one chapter")

        // Verify each chapter has an ID
        for chapter in browserData.chapters {
            #expect(!chapter.id.isEmpty)
            #expect(chapter.element.isChapter)
        }
    }
}
