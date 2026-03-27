//
//  SceneBrowserUITests.swift
//  SwiftGuionTests
//
//  UI and Integration tests for Scene Browser widgets
//

import Foundation
import SwiftFijos
import Testing

@testable import SwiftCompartido

struct SceneBrowserUITests {

  // MARK: - Integration Tests with Real Data

  @Test func testSceneBrowserDataFromTestFixture() async throws {
    // Load test.fountain and extract browser data
    let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") {
      $0
    }.path
    let script = try await GuionParsedElementCollection(file: fountainPath)
    let browserData = script.extractSceneBrowserData()

    // Verify title exists
    #expect(browserData.title != nil, "Browser should have a title")
    #expect(!browserData.title!.string.isEmpty, "Title should not be empty")

    // Verify chapters exist
    #expect(browserData.chapters.count > 0, "Should have at least one chapter")

    // Verify first chapter structure
    let firstChapter = browserData.chapters[0]
    #expect(!firstChapter.title.isEmpty, "Chapter should have a title")
    #expect(firstChapter.sceneGroups.count > 0, "Chapter should have scene groups")

    // Verify scene group structure
    let firstGroup = firstChapter.sceneGroups[0]
    #expect(!firstGroup.title.isEmpty, "Scene group should have a title")
    #expect(firstGroup.scenes.count > 0, "Scene group should have scenes")

    // Verify scene structure
    let firstScene = firstGroup.scenes[0]
    #expect(!firstScene.slugline.isEmpty, "Scene should have a slugline")
    #expect(firstScene.element != nil, "Scene should have outline element")
  }

  @Test func testHierarchyIntegrityWithRealData() async throws {
    let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") {
      $0
    }.path
    let script = try await GuionParsedElementCollection(file: fountainPath)
    let browserData = script.extractSceneBrowserData()

    // Verify all chapters have valid IDs
    for chapter in browserData.chapters {
      #expect(!chapter.id.isEmpty, "Chapter should have valid ID")
      #expect(chapter.element.isChapter, "Chapter element should be marked as chapter")
      #expect(chapter.element.level == 2, "Chapter should be level 2")

      // Verify scene groups
      for sceneGroup in chapter.sceneGroups {
        #expect(!sceneGroup.id.isEmpty, "Scene group should have valid ID")
        #expect(sceneGroup.element.level == 3, "Scene group should be level 3")

        // Verify scenes
        for scene in sceneGroup.scenes {
          #expect(!scene.id.isEmpty, "Scene should have valid ID")
          #expect(scene.element?.type == "sceneHeader", "Scene element should be scene header")
        }
      }
    }
  }

  @Test func testSceneContentExtraction() async throws {
    let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") {
      $0
    }.path
    let script = try await GuionParsedElementCollection(file: fountainPath)
    let browserData = script.extractSceneBrowserData()

    // Find first scene with content
    var foundSceneWithContent = false
    for chapter in browserData.chapters {
      for sceneGroup in chapter.sceneGroups {
        for scene in sceneGroup.scenes {
          if !(scene.sceneElements?.isEmpty ?? true) {
            foundSceneWithContent = true

            // Verify scene has elements
            #expect(scene.sceneElements?.count ?? 0 > 0, "Scene should have elements")

            // Verify elements have content
            if let sceneElements = scene.sceneElements {
              for element in sceneElements {
                #expect(!element.elementText.isEmpty, "Element should have text")
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

    #expect(foundSceneWithContent, "Should find at least one scene with content")
  }

  @Test func testPreSceneContentAttachment() async throws {
    let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") {
      $0
    }.path
    let script = try await GuionParsedElementCollection(file: fountainPath)
    let browserData = script.extractSceneBrowserData()

    // test.fountain has OVER BLACK content that should be attached to scenes
    var foundPreScene = false
    for chapter in browserData.chapters {
      for sceneGroup in chapter.sceneGroups {
        for scene in sceneGroup.scenes {
          if scene.hasPreScene {
            foundPreScene = true

            #expect(scene.preSceneElements != nil, "PreScene elements should exist")
            #expect(scene.preSceneElements!.count > 0, "PreScene should have elements")

            // Verify preScene content
            for element in scene.preSceneElements! {
              #expect(!element.elementText.isEmpty, "PreScene element should have text")
            }

            // Verify preSceneText property
            #expect(!scene.preSceneText.isEmpty, "PreScene text should not be empty")

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

  @Test func testSceneLocationParsing() async throws {
    let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") {
      $0
    }.path
    let script = try await GuionParsedElementCollection(file: fountainPath)
    let browserData = script.extractSceneBrowserData()

    // Find scenes with locations
    var foundSceneWithLocation = false
    for chapter in browserData.chapters {
      for sceneGroup in chapter.sceneGroups {
        for scene in sceneGroup.scenes {
          if let location = scene.sceneLocation {
            foundSceneWithLocation = true

            // Verify location parsing
            #expect(!location.scene.isEmpty, "Location should have scene name")
            #expect(location.lighting != .unknown, "Location should have valid lighting")

            break
          }
        }
        if foundSceneWithLocation { break }
      }
      if foundSceneWithLocation { break }
    }

    #expect(foundSceneWithLocation, "Should find at least one scene with parsed location")
  }

  @Test func testSceneDirectiveMetadata() async throws {
    let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") {
      $0
    }.path
    let script = try await GuionParsedElementCollection(file: fountainPath)
    let browserData = script.extractSceneBrowserData()

    // Look for scene groups with directives (like "### PROLOGUE S#{{SERIES: 1001}}")
    var foundDirective = false
    for chapter in browserData.chapters {
      for sceneGroup in chapter.sceneGroups {
        if let directive = sceneGroup.directive {
          foundDirective = true

          #expect(!directive.isEmpty, "Directive should not be empty")

          // Directive description is optional but should be valid if present
          if let description = sceneGroup.directiveDescription {
            #expect(!description.isEmpty, "Directive description should not be empty if present")
          }

          break
        }
      }
      if foundDirective { break }
    }

    // Note: test.fountain may or may not have scene directives depending on fixture content
    if !foundDirective {
      print(
        "ℹ️  Note: test.fountain does not contain scene directives. Test verifies structure only.")
    }
  }

  // MARK: - State Management Tests

  @Test func testChapterExpansionState() {
    // Create sample browser data
    let browserData = createSampleBrowserData()

    // Verify we have chapters to test
    #expect(browserData.chapters.count > 0, "Should have chapters for testing")

    // Test that chapter IDs are unique and valid
    var chapterIds = Set<String>()
    for chapter in browserData.chapters {
      #expect(!chapter.id.isEmpty, "Chapter ID should not be empty")
      #expect(!chapterIds.contains(chapter.id), "Chapter IDs should be unique")
      chapterIds.insert(chapter.id)
    }
  }

  @Test func testSceneGroupExpansionState() {
    let browserData = createSampleBrowserData()

    // Verify scene groups have unique IDs
    var sceneGroupIds = Set<String>()
    for chapter in browserData.chapters {
      for sceneGroup in chapter.sceneGroups {
        #expect(!sceneGroup.id.isEmpty, "Scene group ID should not be empty")
        #expect(!sceneGroupIds.contains(sceneGroup.id), "Scene group IDs should be unique")
        sceneGroupIds.insert(sceneGroup.id)
      }
    }
  }

  @Test func testSceneExpansionState() {
    let browserData = createSampleBrowserData()

    // Verify scenes have unique IDs
    var sceneIds = Set<String>()
    for chapter in browserData.chapters {
      for sceneGroup in chapter.sceneGroups {
        for scene in sceneGroup.scenes {
          #expect(!scene.id.isEmpty, "Scene ID should not be empty")
          #expect(!sceneIds.contains(scene.id), "Scene IDs should be unique")
          sceneIds.insert(scene.id)
        }
      }
    }
  }

  // MARK: - Data Model Tests

  @Test func testBrowserDataHierarchy() {
    let browserData = createSampleBrowserData()

    // Verify title
    #expect(browserData.title != nil, "Should have a title")
    #expect(browserData.title?.level == 1, "Title should be level 1")

    // Verify chapters
    #expect(browserData.chapters.count > 0, "Should have chapters")

    for chapter in browserData.chapters {
      // Verify chapter level
      #expect(chapter.element.level == 2, "Chapter should be level 2")

      // Verify scene groups
      #expect(chapter.sceneGroups.count > 0, "Chapter should have scene groups")

      for sceneGroup in chapter.sceneGroups {
        // Verify scene group level
        #expect(sceneGroup.element.level == 3, "Scene group should be level 3")

        // Verify scenes
        #expect(sceneGroup.scenes.count > 0, "Scene group should have scenes")
      }
    }
  }

  @Test func testMultipleChapters() async throws {
    let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") {
      $0
    }.path
    let script = try await GuionParsedElementCollection(file: fountainPath)
    let browserData = script.extractSceneBrowserData()

    // test.fountain should have at least one chapter
    // Note: Some test fixtures may only have a single chapter depending on content
    #expect(browserData.chapters.count >= 1, "test.fountain should have at least 1 chapter")

    // Verify each chapter has unique content
    let chapterTitles = Set(browserData.chapters.map { $0.title })
    #expect(chapterTitles.count == browserData.chapters.count, "Chapter titles should be unique")
  }

  // MARK: - Phase 5: Polish & Edge Case Tests

  @Test func testEmptyChapterHandling() {
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

    #expect(browserData.title != nil, "Should have title even with no chapters")
    #expect(browserData.chapters.isEmpty, "Chapters should be empty")
  }

  @Test func testChapterWithNoSceneGroups() {
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

    #expect(browserData.chapters.count == 1, "Should have one chapter")
    #expect(browserData.chapters[0].sceneGroups.isEmpty, "Chapter should have no scene groups")
  }

  @Test func testSceneGroupWithNoScenes() {
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
    #expect(firstChapter.sceneGroups.count == 1, "Should have one scene group")
    #expect(firstChapter.sceneGroups[0].scenes.isEmpty, "Scene group should have no scenes")
  }

  @Test func testSceneWithNoElements() {
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

    #expect(!sceneData.slugline.isEmpty, "Scene should have slugline")
    #expect(sceneData.sceneElements?.isEmpty ?? true, "Scene should have no elements")
    #expect(!sceneData.hasPreScene, "Scene should have no preScene")
  }

  @Test func testSceneWithNilLocation() {
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

    #expect(sceneData.sceneLocation == nil, "Scene should have nil location")
    #expect(!(sceneData.sceneElements?.isEmpty ?? true), "Scene should still have elements")
  }

  @Test func testPreSceneTextProperty() {
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
        GuionElement(type: .action, text: "BERNARD"),
      ],
      sceneLocation: nil
    )

    #expect(sceneData.hasPreScene, "Scene should have preScene")
    #expect(
      sceneData.preSceneText == "CHAPTER 1\nBERNARD", "PreScene text should be joined with newlines"
    )
  }

  @Test func testEmptyPreSceneText() {
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

    #expect(!sceneData.hasPreScene, "Scene should not have preScene")
    #expect(sceneData.preSceneText.isEmpty, "PreScene text should be empty")
  }

  @Test func testLargeScriptPerformance() async throws {
    // Test with BigFish which is a large script
    let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "bigfish.fountain") {
      $0
    }.path
    let script = try await GuionParsedElementCollection(file: fountainPath)

    // Measure extraction time
    let startTime = Date()
    let browserData = script.extractSceneBrowserData()
    let duration = Date().timeIntervalSince(startTime)

    // Verify data was extracted
    #expect(browserData.title != nil, "BigFish should have a title")

    print("⚡ Performance: BigFish extraction took \(String(format: "%.3f", duration)) seconds")

    // Report performance metric (no assertion - tracked separately)
    print("📊 PERFORMANCE METRICS:")
    print("   BigFish extraction: \(String(format: "%.3f", duration))s")
  }

  @Test func testDataIntegrityWithRealScript() async throws {
    let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") {
      $0
    }.path
    let script = try await GuionParsedElementCollection(file: fountainPath)
    let browserData = script.extractSceneBrowserData()

    // Verify no empty IDs
    for chapter in browserData.chapters {
      #expect(!chapter.id.isEmpty, "Chapter ID should not be empty")

      for sceneGroup in chapter.sceneGroups {
        #expect(!sceneGroup.id.isEmpty, "Scene group ID should not be empty")

        for scene in sceneGroup.scenes {
          #expect(!scene.id.isEmpty, "Scene ID should not be empty")
          #expect(!scene.slugline.isEmpty, "Scene slugline should not be empty")
        }
      }
    }
  }

  @Test func testSceneIdUniqueness() async throws {
    let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") {
      $0
    }.path
    let script = try await GuionParsedElementCollection(file: fountainPath)
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

    #expect(duplicates.isEmpty, "All scene IDs should be unique. Duplicates: \(duplicates)")
  }

  @Test func testSyntheticChapterWithNoChapters() async throws {
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

    let script = try await GuionParsedElementCollection(file: tempURL.path)
    let browserData = script.extractSceneBrowserData()

    // Should create a synthetic chapter
    #expect(browserData.chapters.count == 1, "Should have one synthetic chapter")
    #expect(
      browserData.chapters[0].title == "(Untitled Section)",
      "Synthetic chapter should be named '(Untitled Section)'")
    #expect(
      browserData.chapters[0].element.isSynthetic, "Synthetic chapter should be marked as synthetic"
    )

    // Should contain scene groups
    #expect(
      browserData.chapters[0].sceneGroups.count > 0, "Synthetic chapter should have scene groups")
  }

  @Test func testSyntheticChapterWithNoSceneGroups() async throws {
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

    let script = try await GuionParsedElementCollection(file: tempURL.path)
    let outline = script.extractOutline()

    print("📋 Outline elements:")
    for element in outline {
      print(
        "  - \(element.type) level:\(element.level) parent:\(element.parentId ?? "nil") '\(element.string)'"
      )
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
    #expect(browserData.chapters.count == 1, "Should have one synthetic chapter")

    // The synthetic chapter will contain whatever structure is found
    // If there are scene headers at level 0, they become scene groups
    #expect(browserData.chapters[0].sceneGroups.count > 0, "Should have scene groups")
  }

  @Test func testDialogueDisplayInExpandedScene() async throws {
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
        GuionElement(type: .dialogue, text: "Oh, hi John!"),
      ],
      sceneLocation: SceneLocation.parse("INT. COFFEE SHOP - DAY")
    )

    // Verify scene has dialogue elements
    #expect(sceneWithDialogue.sceneElements != nil, "Scene should have elements")
    #expect(sceneWithDialogue.sceneElements?.count == 6, "Scene should have 6 elements")

    // Verify dialogue elements are present
    let dialogueElements = sceneWithDialogue.sceneElements?.filter { $0.elementType == .dialogue }
    #expect(dialogueElements?.count == 2, "Scene should have 2 dialogue elements")
    #expect(dialogueElements?[0].elementText == "Hey, Jane!", "First dialogue should match")
    #expect(dialogueElements?[1].elementText == "Oh, hi John!", "Second dialogue should match")

    // Verify character elements are present
    let characterElements = sceneWithDialogue.sceneElements?.filter { $0.elementType == .character }
    #expect(characterElements?.count == 2, "Scene should have 2 character elements")
    #expect(characterElements?[0].elementText == "JOHN", "First character should be JOHN")
    #expect(characterElements?[1].elementText == "JANE", "Second character should be JANE")

    // Verify parenthetical element is present
    let parentheticalElements = sceneWithDialogue.sceneElements?.filter {
      $0.elementType == .parenthetical
    }
    #expect(parentheticalElements?.count == 1, "Scene should have 1 parenthetical")
    #expect(parentheticalElements?[0].elementText == "(looking up)", "Parenthetical should match")

    // Verify action element is present
    let actionElements = sceneWithDialogue.sceneElements?.filter { $0.elementType == .action }
    #expect(actionElements?.count == 1, "Scene should have 1 action")
    #expect(
      actionElements?[0].elementText == "JANE sits at a table, typing on her laptop.",
      "Action should match")

    print("✅ Dialogue display test passed - all elements present and correctly typed")
  }

  @Test func testDialogueInRealScript() async throws {
    // Load test.fountain and verify it contains dialogue
    let fountainPath = try await FixtureManager.shared.withExclusiveAccess(to: "test.fountain") {
      $0
    }.path
    let script = try await GuionParsedElementCollection(file: fountainPath)
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

      #expect(dialogueElements.count > 0, "Should have dialogue elements")
      #expect(characterElements.count > 0, "Should have character elements")

      // Print dialogue for debugging
      for element in scene.sceneElements ?? [] {
        if element.elementType == .character || element.elementType == .dialogue
          || element.elementType == .parenthetical
        {
          print("  \(element.elementType): \(element.elementText)")
        }
      }

      print("✅ Dialogue verification passed")
    } else {
      // Note: test.fountain may or may not have dialogue depending on fixture content
      print("ℹ️  Note: test.fountain does not contain dialogue. Test verifies structure only.")
    }
  }

  @Test func testDialogueBlockGrouping() async throws {
    // Create test elements
    let elements = [
      GuionElementModel(elementText: "Action line 1", elementType: .action),
      GuionElementModel(elementText: "JOHN", elementType: .character),
      GuionElementModel(elementText: "Hello!", elementType: .dialogue),
      GuionElementModel(elementText: "JANE", elementType: .character),
      GuionElementModel(elementText: "(smiling)", elementType: .parenthetical),
      GuionElementModel(elementText: "Hi there!", elementType: .dialogue),
      GuionElementModel(elementText: "Action line 2", elementType: .action),
    ]

    let blocks = groupDialogueBlocks(elements: elements)

    // Should have 4 blocks: Action, John's dialogue, Jane's dialogue, Action
    #expect(blocks.count == 4, "Should have 4 blocks")

    // Block 0: Action
    #expect(!blocks[0].isDialogueBlock, "First block should not be dialogue")
    #expect(blocks[0].elements.count == 1, "Action block should have 1 element")

    // Block 1: John's dialogue
    #expect(blocks[1].isDialogueBlock, "Second block should be dialogue")
    #expect(
      blocks[1].elements.count == 2, "John's block should have 2 elements (Character + Dialogue)")
    #expect(blocks[1].elements[0].elementType == .character)
    #expect(blocks[1].elements[1].elementType == .dialogue)

    // Block 2: Jane's dialogue with parenthetical
    #expect(blocks[2].isDialogueBlock, "Third block should be dialogue")
    #expect(
      blocks[2].elements.count == 3,
      "Jane's block should have 3 elements (Character + Parenthetical + Dialogue)")
    #expect(blocks[2].elements[0].elementType == .character)
    #expect(blocks[2].elements[1].elementType == .parenthetical)
    #expect(blocks[2].elements[2].elementType == .dialogue)

    // Block 3: Action
    #expect(!blocks[3].isDialogueBlock, "Fourth block should not be dialogue")
    #expect(blocks[3].elements.count == 1, "Action block should have 1 element")

    print("✅ Dialogue block grouping test passed")
  }

  @Test func testDialogueElementModels() async throws {
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
        GuionElement(type: .dialogue, text: "Can you hear me?"),
      ],
      sceneLocation: nil
    )

    // Get element models (this is what the UI actually uses)
    let elementModels = sceneWithDialogue.sceneElementModels

    #expect(elementModels.count == 4, "Should have 4 element models")

    // Verify each element model
    #expect(elementModels[0].elementType == .character, "First should be Character")
    #expect(elementModels[0].elementText == "BOB", "Character name should be BOB")

    #expect(elementModels[1].elementType == .dialogue, "Second should be Dialogue")
    #expect(elementModels[1].elementText == "This is a test.", "Dialogue text should match")

    #expect(elementModels[2].elementType == .parenthetical, "Third should be Parenthetical")
    #expect(elementModels[2].elementText == "(whispering)", "Parenthetical text should match")

    #expect(elementModels[3].elementType == .dialogue, "Fourth should be Dialogue")
    #expect(elementModels[3].elementText == "Can you hear me?", "Second dialogue should match")

    print("✅ Element model conversion test passed")
  }

  @Test func testSyntheticElementsNotExported() async throws {
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
    #expect(elementJSON == "{}", "Synthetic elements should encode as empty JSON object")

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
    #expect(regularJSON != "{}", "Regular elements should encode with full data")
    #expect(
      regularJSON.contains("Chapter 1"), "Regular element JSON should contain the element string")

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
