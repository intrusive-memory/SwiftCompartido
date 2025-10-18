//
//  OutlineLevelParsingTests.swift
//  SwiftGuionTests
//
//  Comprehensive tests for outline level parsing and hierarchy
//

import XCTest
import SwiftFijos
@testable import SwiftCompartido

final class OutlineLevelParsingTests: XCTestCase {

    // MARK: - Basic Level Detection

    func testSingleLevel1Header() throws {
        let content = """
        # Main Title

        INT. ROOM - DAY

        Action.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        let level1Elements = outline.filter { $0.level == 1 }
        XCTAssertEqual(level1Elements.count, 1, "Should have exactly one level 1 element")
        XCTAssertEqual(level1Elements.first?.string, "Main Title")
    }

    func testMultipleLevel1HeadersAllowed() throws {
        let content = """
        # First Title

        Some action.

        # Second Title

        More action.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        let level1Elements = outline.filter { $0.level == 1 }

        XCTAssertEqual(level1Elements.count, 2, "Should allow multiple level 1 elements")
        XCTAssertEqual(level1Elements[0].string, "First Title")
        XCTAssertEqual(level1Elements[1].string, "Second Title")
    }

    func testNoLevel1CreatesSymtheticTitle() throws {
        let content = """
        ## Chapter 1

        INT. ROOM - DAY

        Action.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        let level1Elements = outline.filter { $0.level == 1 }
        XCTAssertEqual(level1Elements.count, 1, "Should create synthetic level 1 title")
        XCTAssertTrue(level1Elements.first?.isSynthetic ?? false, "Title should be marked as synthetic")
    }

    // MARK: - Chapter Level (Level 2) Detection

    func testLevel2ChaptersDetection() throws {
        let content = """
        ## CHAPTER 1

        ### Scene Group

        INT. ROOM - DAY

        Action.

        ## CHAPTER 2

        INT. ANOTHER ROOM - DAY

        More action.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        let chapters = outline.filter { $0.isChapter }
        XCTAssertEqual(chapters.count, 2, "Should detect 2 chapters")
        XCTAssertEqual(chapters[0].string, "CHAPTER 1")
        XCTAssertEqual(chapters[1].string, "CHAPTER 2")
    }

    func testENDMarkersNotCountedAsChapters() throws {
        let content = """
        ## CHAPTER 1

        INT. ROOM - DAY

        Action.

        ## END CHAPTER 1

        ## CHAPTER 2

        More action.

        ## END CHAPTER 2
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        let chapters = outline.filter { $0.isChapter }
        let endMarkers = outline.filter { $0.isEndMarker }

        XCTAssertEqual(chapters.count, 2, "Should detect 2 chapters (not END markers)")
        XCTAssertEqual(endMarkers.count, 2, "Should detect 2 END markers")
        XCTAssertFalse(endMarkers.allSatisfy { $0.isChapter }, "END markers should not be chapters")
    }

    func testSHOTDirectivesNotCountedAsChapters() throws {
        let content = """
        ## CHAPTER 1

        INT. ROOM - DAY

        Action.

        ## SHOT: Close-up on the door

        The door opens.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        let chapters = outline.filter { $0.isChapter }

        // SHOT: should not be counted as a chapter
        // It's a technical directive, not a story chapter
        XCTAssertEqual(chapters.count, 1, "SHOT directive should not be a chapter")
        XCTAssertEqual(chapters.first?.string, "CHAPTER 1")
    }

    // MARK: - Scene Group Level (Level 3) Detection

    func testLevel3SceneGroupDetection() throws {
        let content = """
        ## CHAPTER 1

        ### PROLOGUE

        INT. ROOM - DAY

        Action.

        ### ACT ONE

        INT. ANOTHER ROOM - DAY

        More action.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        let sceneGroups = outline.filter { $0.level == 3 && $0.type == "sectionHeader" }
        XCTAssertEqual(sceneGroups.count, 2, "Should detect 2 scene groups")
        XCTAssertEqual(sceneGroups[0].string, "PROLOGUE")
        XCTAssertEqual(sceneGroups[1].string, "ACT ONE")
    }

    func testSceneDirectiveExtraction() throws {
        let content = """
        ## CHAPTER 1

        ### PROLOGUE S#{{SERIES: 1001}}

        INT. ROOM - DAY

        Action.

        ### THE MURDER S#{{SERIES: 1002}}

        INT. ANOTHER ROOM - DAY

        More action.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        let sceneGroups = outline.filter { $0.level == 3 && $0.type == "sectionHeader" }

        XCTAssertEqual(sceneGroups.count, 2, "Should detect 2 scene groups")

        // Check first scene group
        XCTAssertEqual(sceneGroups[0].sceneDirective, "PROLOGUE")
        XCTAssertTrue(sceneGroups[0].sceneDirectiveDescription?.contains("SERIES: 1001") ?? false)

        // Check second scene group
        XCTAssertEqual(sceneGroups[1].sceneDirective, "THE MURDER")
        XCTAssertTrue(sceneGroups[1].sceneDirectiveDescription?.contains("SERIES: 1002") ?? false)
    }

    // MARK: - Hierarchy and Parent-Child Relationships

    func testChapterSceneGroupHierarchy() throws {
        let content = """
        ## CHAPTER 1

        ### Scene Group A

        INT. ROOM - DAY

        Action.

        ### Scene Group B

        INT. ANOTHER ROOM - DAY

        More action.

        ## CHAPTER 2

        ### Scene Group C

        INT. THIRD ROOM - DAY

        Even more action.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        let chapters = outline.filter { $0.isChapter }
        XCTAssertEqual(chapters.count, 2)

        let chapter1 = chapters[0]
        let chapter2 = chapters[1]

        // Check that scene groups belong to correct chapters
        let groupsInChapter1 = outline.filter { $0.level == 3 && $0.parentId == chapter1.id }
        let groupsInChapter2 = outline.filter { $0.level == 3 && $0.parentId == chapter2.id }

        XCTAssertEqual(groupsInChapter1.count, 2, "Chapter 1 should have 2 scene groups")
        XCTAssertEqual(groupsInChapter2.count, 1, "Chapter 2 should have 1 scene group")
    }

    func testSceneHeadersUnderSceneGroups() throws {
        let content = """
        ## CHAPTER 1

        ### Scene Group

        INT. ROOM A - DAY

        Action one.

        INT. ROOM B - NIGHT

        Action two.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        let sceneGroup = outline.first { $0.level == 3 && $0.type == "sectionHeader" }
        XCTAssertNotNil(sceneGroup)

        let scenes = outline.filter { $0.type == "sceneHeader" && $0.parentId == sceneGroup?.id }
        XCTAssertEqual(scenes.count, 2, "Should have 2 scenes under scene group")
        XCTAssertEqual(scenes[0].string, "INT. ROOM A - DAY")
        XCTAssertEqual(scenes[1].string, "INT. ROOM B - NIGHT")
    }

    // MARK: - Edge Cases

    func testEmptyScript() {
        let script = GuionParsedScreenplay()
        let outline = script.extractOutline()

        // Empty script creates a synthetic title + blank element
        let structural = outline.filter { $0.type != "blank" }
        XCTAssertEqual(structural.count, 1, "Empty script creates a synthetic title")
        XCTAssertTrue(structural.first?.isSynthetic ?? false, "Title should be synthetic")
    }

    func testScriptWithOnlyScenes() throws {
        let content = """
        INT. ROOM - DAY

        Action.

        EXT. STREET - NIGHT

        More action.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        // Should create synthetic title
        let level1Elements = outline.filter { $0.level == 1 }
        XCTAssertEqual(level1Elements.count, 1, "Should create synthetic title")

        let scenes = outline.filter { $0.type == "sceneHeader" }
        XCTAssertEqual(scenes.count, 2, "Should detect 2 scene headers")
    }

    func testMixedHierarchyLevels() throws {
        let content = """
        # Main Title

        ## Chapter 1

        ### Scene Group

        INT. ROOM - DAY

        Action.

        ## Chapter 2

        INT. ANOTHER ROOM - DAY

        Direct scene without scene group.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        let level1 = outline.filter { $0.level == 1 }
        let chapters = outline.filter { $0.isChapter }
        let sceneGroups = outline.filter { $0.level == 3 && $0.type == "sectionHeader" }
        let scenes = outline.filter { $0.type == "sceneHeader" }

        XCTAssertEqual(level1.count, 1, "Should have 1 level 1 title")
        XCTAssertEqual(chapters.count, 2, "Should have 2 chapters")
        XCTAssertEqual(sceneGroups.count, 1, "Should have 1 scene group")
        XCTAssertEqual(scenes.count, 2, "Should have 2 scenes")
    }

    // MARK: - Multiple Level 1 Headers with Separate Hierarchies

    func testMultipleLevel1HeadersWithSeparateHierarchies() throws {
        let content = """
        # PITCH NOTES

        ## LOGLINE

        This is the logline.

        ## GENRES

        Mystery, Comedy

        # SCREENPLAY

        ## CHAPTER 1

        ### Scene Group A

        INT. ROOM - DAY

        Action.

        ## CHAPTER 2

        ### Scene Group B

        INT. ANOTHER ROOM - DAY

        More action.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        // Should have 2 level 1 elements
        let level1Elements = outline.filter { $0.level == 1 }
        XCTAssertEqual(level1Elements.count, 2, "Should have 2 level 1 elements")
        XCTAssertEqual(level1Elements[0].string, "PITCH NOTES")
        XCTAssertEqual(level1Elements[1].string, "SCREENPLAY")

        // Check PITCH NOTES children
        let pitchNotesId = level1Elements[0].id
        let pitchNotesChildren = outline.filter { $0.parentId == pitchNotesId && $0.level == 2 }
        XCTAssertEqual(pitchNotesChildren.count, 2, "PITCH NOTES should have 2 level 2 children")
        XCTAssertTrue(pitchNotesChildren.contains { $0.string == "LOGLINE" })
        XCTAssertTrue(pitchNotesChildren.contains { $0.string == "GENRES" })

        // Check SCREENPLAY children
        let screenplayId = level1Elements[1].id
        let screenplayChildren = outline.filter { $0.parentId == screenplayId && $0.level == 2 }
        XCTAssertEqual(screenplayChildren.count, 2, "SCREENPLAY should have 2 level 2 children")
        XCTAssertTrue(screenplayChildren.contains { $0.string == "CHAPTER 1" })
        XCTAssertTrue(screenplayChildren.contains { $0.string == "CHAPTER 2" })

        // Verify that children don't cross between level 1 sections
        let allLevel2 = outline.filter { $0.level == 2 && $0.type == "sectionHeader" }
        XCTAssertTrue(allLevel2.allSatisfy { $0.parentId == pitchNotesId || $0.parentId == screenplayId },
                      "All level 2 elements should belong to one of the level 1 parents")
    }

    func testMultipleLevel1HeadersWithComplexHierarchies() throws {
        let content = """
        # SECTION A

        ## Chapter A1

        ### Scene Group A1-1

        INT. ROOM - DAY

        Action.

        ### Scene Group A1-2

        INT. ANOTHER ROOM - DAY

        More action.

        ## Chapter A2

        INT. THIRD ROOM - DAY

        Even more action.

        # SECTION B

        ## Chapter B1

        ### Scene Group B1-1

        INT. FOURTH ROOM - DAY

        Action in section B.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        let level1Elements = outline.filter { $0.level == 1 }
        XCTAssertEqual(level1Elements.count, 2, "Should have 2 level 1 elements")

        let sectionA = level1Elements.first { $0.string == "SECTION A" }
        let sectionB = level1Elements.first { $0.string == "SECTION B" }

        XCTAssertNotNil(sectionA)
        XCTAssertNotNil(sectionB)

        // Check Section A has correct children
        let sectionAChildren = outline.filter { $0.parentId == sectionA?.id && $0.level == 2 }
        XCTAssertEqual(sectionAChildren.count, 2, "Section A should have 2 chapters")

        // Check Section B has correct children
        let sectionBChildren = outline.filter { $0.parentId == sectionB?.id && $0.level == 2 }
        XCTAssertEqual(sectionBChildren.count, 1, "Section B should have 1 chapter")

        // Verify hierarchies don't cross
        let chapterA1 = sectionAChildren.first { $0.string == "Chapter A1" }
        let sceneGroupsUnderA1 = outline.filter { $0.parentId == chapterA1?.id && $0.level == 3 }
        XCTAssertEqual(sceneGroupsUnderA1.count, 2, "Chapter A1 should have 2 scene groups")
    }

    func testMrMrCharlesDocument() throws {
        // This test uses inline content instead of a fixture file
        // The mr-mr-charles.fountain fixture demonstrates multiple level 1 sections
        let content = """
        # PITCH NOTES

        ## **_LOGLINE_**

        Set in modern Palm Springs, semi-retired photojournalist Mitch Sawyer and his husband Billy Charles become embroiled in a mystery when billionaire Clive WYNANT's assistant is murdered and the whole Wynant family is suspect.

        ## **_GENRES_**

        Mystery, LGBT, PALM SPRINGS, Noir, Comedy

        # SCREENPLAY

        ## CHAPTER 1

        ### PROLOGUE

        INT. ROOM - DAY

        Action.

        ## CHAPTER 2

        ### Scene Group

        INT. ANOTHER ROOM - DAY

        More action.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        // Should have multiple level 1 sections
        let level1Elements = outline.filter { $0.level == 1 && $0.type == "sectionHeader" }
        XCTAssertGreaterThan(level1Elements.count, 1, "Mr Mr Charles should have multiple level 1 sections")

        // Find PITCH NOTES and SCREENPLAY
        let pitchNotes = level1Elements.first { $0.string == "PITCH NOTES" }
        let screenplay = level1Elements.first { $0.string == "SCREENPLAY" }

        XCTAssertNotNil(pitchNotes, "Should have PITCH NOTES section")
        XCTAssertNotNil(screenplay, "Should have SCREENPLAY section")

        // PITCH NOTES should have children like LOGLINE, GENRES, etc.
        let pitchNotesChildren = outline.filter {
            $0.parentId == pitchNotes?.id && $0.level == 2 && $0.type == "sectionHeader"
        }
        XCTAssertGreaterThan(pitchNotesChildren.count, 0, "PITCH NOTES should have level 2 children")

        // SCREENPLAY should have children (chapters)
        let screenplayChildren = outline.filter {
            $0.parentId == screenplay?.id && $0.level == 2 && $0.type == "sectionHeader"
        }
        XCTAssertGreaterThan(screenplayChildren.count, 0, "SCREENPLAY should have level 2 children")

        // Verify LOGLINE is under PITCH NOTES, not SCREENPLAY
        let logline = outline.first { $0.string.contains("LOGLINE") }
        if let logline = logline {
            XCTAssertEqual(logline.parentId, pitchNotes?.id, "LOGLINE should be a child of PITCH NOTES")
        }

        // Verify chapters are under SCREENPLAY
        let chapter1 = outline.first { $0.string.contains("CHAPTER 1") && $0.level == 2 }
        if let chapter1 = chapter1 {
            XCTAssertEqual(chapter1.parentId, screenplay?.id, "CHAPTER 1 should be a child of SCREENPLAY")
        }
    }

    // MARK: - Synthetic Element Generation for Missing Levels

    func testMissingLevel3CreatesSymtheticElement() throws {
        let content = """
        ## Chapter 1

        #### Scene 1

        Action.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        // Should have chapter (level 2), synthetic level 3, and scene (level 4)
        let level2Elements = outline.filter { $0.level == 2 && $0.type == "sectionHeader" }
        let level3Elements = outline.filter { $0.level == 3 }
        let level4Elements = outline.filter { $0.level == 4 }

        XCTAssertEqual(level2Elements.count, 1, "Should have 1 chapter")
        XCTAssertEqual(level3Elements.count, 1, "Should create 1 synthetic level 3 element")
        XCTAssertEqual(level4Elements.count, 1, "Should have 1 level 4 scene")

        // Verify synthetic element properties
        let syntheticLevel3 = level3Elements.first
        XCTAssertNotNil(syntheticLevel3)
        XCTAssertTrue(syntheticLevel3?.isSynthetic ?? false, "Level 3 should be marked as synthetic")

        // Verify hierarchy
        let chapter = level2Elements.first
        let scene = level4Elements.first
        XCTAssertEqual(syntheticLevel3?.parentId, chapter?.id, "Synthetic level 3 should be child of chapter")
        XCTAssertEqual(scene?.parentId, syntheticLevel3?.id, "Scene should be child of synthetic level 3")
    }

    func testMissingLevel2And3CreatesMultipleSyntheticElements() throws {
        let content = """
        # Main Title

        #### Scene 1

        Action.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        // Should have title (level 1), synthetic level 2, synthetic level 3, and scene (level 4)
        let level1Elements = outline.filter { $0.level == 1 }
        let level2Elements = outline.filter { $0.level == 2 }
        let level3Elements = outline.filter { $0.level == 3 }
        let level4Elements = outline.filter { $0.level == 4 }

        XCTAssertEqual(level1Elements.count, 1, "Should have 1 title")
        XCTAssertEqual(level2Elements.count, 1, "Should create 1 synthetic level 2 element")
        XCTAssertEqual(level3Elements.count, 1, "Should create 1 synthetic level 3 element")
        XCTAssertEqual(level4Elements.count, 1, "Should have 1 level 4 scene")

        // Verify synthetic elements
        let syntheticLevel2 = level2Elements.first
        let syntheticLevel3 = level3Elements.first
        XCTAssertTrue(syntheticLevel2?.isSynthetic ?? false, "Level 2 should be marked as synthetic")
        XCTAssertTrue(syntheticLevel3?.isSynthetic ?? false, "Level 3 should be marked as synthetic")

        // Verify hierarchy chain
        let title = level1Elements.first
        let scene = level4Elements.first
        XCTAssertEqual(syntheticLevel2?.parentId, title?.id, "Synthetic level 2 should be child of title")
        XCTAssertEqual(syntheticLevel3?.parentId, syntheticLevel2?.id, "Synthetic level 3 should be child of synthetic level 2")
        XCTAssertEqual(scene?.parentId, syntheticLevel3?.id, "Scene should be child of synthetic level 3")
    }

    func testMultipleScenesWithMissingLevel3() throws {
        let content = """
        ## Chapter 1

        #### Scene 1

        Action 1.

        #### Scene 2

        Action 2.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        // Should create only ONE synthetic level 3 for both scenes
        let level3Elements = outline.filter { $0.level == 3 }
        let level4Elements = outline.filter { $0.level == 4 }

        XCTAssertEqual(level3Elements.count, 1, "Should create only 1 synthetic level 3 element for both scenes")
        XCTAssertEqual(level4Elements.count, 2, "Should have 2 level 4 scenes")

        // Verify both scenes share the same synthetic parent
        let syntheticLevel3 = level3Elements.first
        XCTAssertTrue(syntheticLevel3?.isSynthetic ?? false, "Level 3 should be marked as synthetic")
        XCTAssertTrue(level4Elements.allSatisfy { $0.parentId == syntheticLevel3?.id }, "Both scenes should share the same synthetic parent")
    }

    func testSyntheticElementsNotEncodedInSerialization() throws {
        let content = """
        ## Chapter 1

        #### Scene 1

        Action.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        // Encode and decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(outline)
        let decoder = JSONDecoder()
        let decodedOutline = try decoder.decode(OutlineList.self, from: data)

        // Synthetic elements should not be in the decoded version (they're skipped during encoding)
        let syntheticElements = decodedOutline.filter { $0.isSynthetic }
        XCTAssertEqual(syntheticElements.count, 0, "Synthetic elements should not be encoded/decoded")

        // But real elements should be preserved
        let realElements = decodedOutline.filter { !$0.isSynthetic && $0.type != "blank" }
        XCTAssertGreaterThan(realElements.count, 0, "Real elements should be preserved")
    }

    func testMissingLevelWhenSceneGroupExists() throws {
        let content = """
        ## Chapter 1

        ### Scene Group

        INT. ROOM - DAY

        Action 1.

        #### Detailed Scene

        Action 2.
        """

        let script = try GuionParsedScreenplay(string: content)
        let outline = script.extractOutline()

        // When level 3 exists explicitly, scenes under it should not create synthetic elements
        let level3Elements = outline.filter { $0.level == 3 }
        let syntheticElements = level3Elements.filter { $0.isSynthetic }

        XCTAssertEqual(syntheticElements.count, 0, "Should not create synthetic level 3 when it already exists")

        // Both the scene heading and the #### element should be level 4 and be children of the explicit level 3
        let level4Elements = outline.filter { $0.level == 4 }
        XCTAssertEqual(level4Elements.count, 2, "Should have 2 level 4 elements (scene heading + #### section)")

        let explicitLevel3 = level3Elements.first { !$0.isSynthetic }
        XCTAssertTrue(level4Elements.allSatisfy { $0.parentId == explicitLevel3?.id }, "All level 4 elements should be children of explicit level 3")
    }

    // MARK: - Scene Browser Integration

    func testSceneBrowserWithMultipleChapters() throws {
        let content = """
        ## CHAPTER 1

        ### PROLOGUE S#{{SERIES: 1001}}

        INT. ROOM - DAY

        Action.

        ## CHAPTER 2

        ### Scene Group S#{{SERIES: 2001}}

        INT. ANOTHER ROOM - DAY

        More action.
        """

        let script = try GuionParsedScreenplay(string: content)
        let browserData = script.extractSceneBrowserData()

        XCTAssertEqual(browserData.chapters.count, 2, "Should extract 2 chapters")
        XCTAssertEqual(browserData.chapters[0].title, "CHAPTER 1")
        XCTAssertEqual(browserData.chapters[1].title, "CHAPTER 2")

        // Check scene groups
        XCTAssertEqual(browserData.chapters[0].sceneGroups.count, 1)
        XCTAssertEqual(browserData.chapters[0].sceneGroups[0].directive, "PROLOGUE")

        XCTAssertEqual(browserData.chapters[1].sceneGroups.count, 1)
        XCTAssertEqual(browserData.chapters[1].sceneGroups[0].directive, "Scene Group")
    }
}
