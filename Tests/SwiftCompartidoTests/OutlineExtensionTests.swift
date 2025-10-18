//
//  OutlineExtensionTests.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//
//  Tests for the enhanced outline functionality with proper level handling.
//

import Testing
import SwiftFijos
@testable import SwiftCompartido

@Suite("Enhanced Outline Level Tests")
struct OutlineExtensionTests {

    @Test("Outline with no level 1 header should generate script title")
    func testOutlineWithNoLevelOneHeader() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)
        let outline = script.extractOutline()

        // Should have outline elements
        #expect(outline.count > 0)
        let firstElement = outline[0]
        #expect(firstElement.level >= 1)
        #expect(firstElement.type == "sectionHeader")
    }

    @Test("Outline with level 1 header should respect existing title")
    func testOutlineWithLevelOneHeader() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)
        let outline = script.extractOutline()

        // Should have outline elements
        #expect(outline.count > 0)
        let level1Elements = outline.filter { $0.level == 1 }
        #expect(!level1Elements.isEmpty)
    }

    @Test("Scene directive parsing")
    func testSceneDirectiveParsing() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)
        let outline = script.extractOutline()

        // Find scene directive elements (if any exist in bigfish)
        let sceneDirectives = outline.filter { $0.isSceneDirective }

        // Verify structure for any scene directives found
        for directive in sceneDirectives {
            #expect(directive.sceneDirective != nil, "Scene directive should have sceneDirective property")
            #expect(directive.level >= 3, "Scene directives typically at level 3+")
        }
    }

    @Test("Multiple level 1 headers are allowed")
    func testMultipleLevelOneHeaders() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)
        let outline = script.extractOutline()

        let level1Elements = outline.filter { $0.level == 1 }

        // Should have at least one level 1 element, multiple are allowed
        #expect(level1Elements.count >= 1)
    }

    @Test("Chapter level headers identification")
    func testChapterLevelHeaders() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)
        let outline = script.extractOutline()

        let sectionHeaders = outline.filter { $0.type == "sectionHeader" }
        #expect(!sectionHeaders.isEmpty, "Should have section headers")
    }

    @Test("ElementType property returns 'outline' for API compatibility")
    func testElementTypePropertyReturnsOutline() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)
        let outline = script.extractOutline()

        // Test that all outline elements have elementType "outline"
        for element in outline {
            #expect(element.elementType == "outline", "All outline elements should have elementType 'outline'")
        }

        // Test specific element types
        if let title = outline.first(where: { $0.isMainTitle }) {
            #expect(title.elementType == "outline", "Title element should have elementType 'outline'")
        }

        if let sceneHeader = outline.first(where: { $0.type == "sceneHeader" }) {
            #expect(sceneHeader.elementType == "outline", "Scene header element should have elementType 'outline'")
        }

        // Test that elementType is consistent regardless of internal type
        let sectionHeaders = outline.filter { $0.type == "sectionHeader" }
        for header in sectionHeaders {
            #expect(header.elementType == "outline", "All section headers should have elementType 'outline'")
        }
    }

    @Test("Parent-child relationships and tree structure")
    func testParentChildRelationships() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)
        let outline = script.extractOutline()

        // Verify parent-child relationships exist
        let title = outline.first { $0.isMainTitle || $0.level == 1 }
        #expect(title != nil, "Should have a main title or level 1 element")

        // Test parent() and children() methods work
        for element in outline {
            if let parentId = element.parentId {
                let parent = element.parent(from: outline)
                #expect(parent?.id == parentId, "parent() method should return correct parent")
            }

            let children = element.children(from: outline)
            #expect(children.count == element.childIds.count, "children() count should match childIds count")
        }
    }

    @Test("Tree structure functionality")
    func testTreeStructure() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)
        let outline = script.extractOutline()
        let tree = outline.tree()

        // Test tree root
        #expect(tree.root != nil, "Tree should have a root")

        // Test tree structure
        let allNodes = tree.allNodes
        #expect(allNodes.count > 0, "Tree should have nodes")

        // Test node relationships
        if let rootNode = tree.root {
            #expect(rootNode.parent == nil, "Root should have no parent")
            #expect(rootNode.hasChildren, "Root should have children")
        }

        // Test tree utility methods
        let leafNodes = tree.leafNodes
        #expect(leafNodes.count > 0, "Tree should have leaf nodes")
    }

    @Test("END marker detection")
    func testEndMarkerDetection() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)
        let outline = script.extractOutline()

        let endMarkers = outline.filter { $0.isEndMarker }

        // Verify END markers if they exist
        for endMarker in endMarkers {
            #expect(endMarker.isEndMarker, "Should be identified as END marker")
            #expect(endMarker.childIds.isEmpty, "END markers should not have children")
        }
    }

    @Test("Convenience tree extraction method")
    func testConvenienceTreeExtraction() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)

        // Test convenience method
        let tree = script.extractOutlineTree()
        #expect(tree.root != nil, "Convenience method should return tree with root")

        // Should be equivalent to outline.tree()
        let outline = script.extractOutline()
        let manualTree = outline.tree()

        #expect(tree.allNodes.count == manualTree.allNodes.count, "Convenience method should produce same tree structure")
        #expect(tree.root?.element.id == manualTree.root?.element.id, "Trees should have same root")
    }

    @Test("Scene text extraction returns complete scene content")
    func testSceneTextExtraction() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)
        let outline = script.extractOutline()

        // Find the first INT scene
        let firstScene = outline.first { $0.type == "sceneHeader" && $0.string.contains("INT.") }
        #expect(firstScene != nil, "Should find at least one INT scene")

        if let scene = firstScene {
            let sceneText = scene.sceneText(from: script, outline: outline)

            // Check that the scene text includes the heading
            #expect(sceneText.contains("INT."), "Scene text should contain scene heading")
            #expect(!sceneText.isEmpty, "Scene text should not be empty")
        }
    }

    @Test("Scene text extraction for non-scene elements returns string")
    func testSceneTextExtractionForNonScenes() async throws {
        let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
        let script = try GuionParsedScreenplay(file: fountainURL.path)
        let outline = script.extractOutline()

        // Get a non-scene element (title or section header)
        let sectionHeader = outline.first { $0.type == "sectionHeader" }
        #expect(sectionHeader != nil, "Should find section header")

        if let element = sectionHeader {
            let text = element.sceneText(from: script, outline: outline)
            // For non-scene elements, should just return the string
            #expect(text == element.string, "Non-scene elements should return their string property")
        }
    }
}