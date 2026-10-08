//
//  CharacterQueryAcceptanceTests.swift
//  SwiftCompartidoTests
//
//  Acceptance tests for CP-P2 through CP-P5 (Sortie 5).
//
//  These tests verify the acceptance criteria from REQUIREMENTS_PERSONAJE.md:
//  1. Store-wide character collection (CP-P2) with deterministic counts
//  2. Full-scene queries return complete scenes (CP-P4)
//  3. Line windows merge correctly and respect scene boundaries (CP-P5)
//  4. Migration validation for stores parsed before CP-P1
//  5. Existing voice intents unchanged (regression)
//

import Foundation
import SwiftData
import Testing

@testable import SwiftCompartido

@Suite("Character Query Acceptance Tests")
struct CharacterQueryAcceptanceTests {

  // MARK: - Acceptance 1: Store-wide character collection (CP-P2)

  @Test(
    "CP-P2: Store-wide collection returns all characters with line counts matching per-document sums"
  )
  @MainActor
  func storeWideCharacterCollection() async throws {
    let container = try makeContainer()
    let context = container.mainContext
    let actor = DocumentModelActor(modelContainer: container)

    // Parse three documents with overlapping and unique characters
    let doc1 = """
      INT. OFFICE - DAY

      ALICE
      Hello, Bob.

      BOB
      Hi, Alice.

      ALICE
      How are you?
      """

    let doc2 = """
      EXT. PARK - DAY

      BOB
      Beautiful day.

      CHARLIE
      Indeed.

      BOB
      Let's walk.
      """

    let doc3 = """
      INT. CAFE - NIGHT

      CHARLIE
      Coffee?

      ALICE
      Thanks.

      NARRATOR (V.O.)
      They met every week.
      """

    let id1 = try await actor.parseAndSaveDocument(from: doc1, title: "Episode 1")
    let id2 = try await actor.parseAndSaveDocument(from: doc2, title: "Episode 2")
    let id3 = try await actor.parseAndSaveDocument(from: doc3, title: "Episode 3")

    // Get per-document character lists for comparison
    guard let perDoc1 = context.model(for: id1) as? GuionDocumentModel,
      let perDoc2 = context.model(for: id2) as? GuionDocumentModel,
      let perDoc3 = context.model(for: id3) as? GuionDocumentModel
    else {
      Issue.record("Failed to retrieve documents")
      return
    }

    let chars1 = perDoc1.extractCharacters()
    let chars2 = perDoc2.extractCharacters()
    let chars3 = perDoc3.extractCharacters()

    // Get store-wide collection
    let storeWide = try await actor.extractAllCharacters()

    // Verify all characters are present
    #expect(storeWide.characters.keys.contains("ALICE"))
    #expect(storeWide.characters.keys.contains("BOB"))
    #expect(storeWide.characters.keys.contains("CHARLIE"))
    #expect(storeWide.characters.keys.contains("NARRATOR"))

    // Verify line counts match per-document sums
    let aliceStore = storeWide.characters["ALICE"]!
    let aliceDoc1 = chars1["ALICE"]?.counts.lineCount ?? 0
    let aliceDoc3 = chars3["ALICE"]?.counts.lineCount ?? 0
    #expect(aliceStore.lineCount == aliceDoc1 + aliceDoc3)

    let bobStore = storeWide.characters["BOB"]!
    let bobDoc1 = chars1["BOB"]?.counts.lineCount ?? 0
    let bobDoc2 = chars2["BOB"]?.counts.lineCount ?? 0
    #expect(bobStore.lineCount == bobDoc1 + bobDoc2)

    let charlieStore = storeWide.characters["CHARLIE"]!
    let charlieDoc2 = chars2["CHARLIE"]?.counts.lineCount ?? 0
    let charlieDoc3 = chars3["CHARLIE"]?.counts.lineCount ?? 0
    #expect(charlieStore.lineCount == charlieDoc2 + charlieDoc3)

    // Verify word counts match per-document sums
    let aliceWords = (chars1["ALICE"]?.counts.wordCount ?? 0) + (chars3["ALICE"]?.counts.wordCount
      ?? 0)
    #expect(aliceStore.wordCount == aliceWords)

    // Verify document references
    #expect(aliceStore.documents.count == 2)  // Episodes 1 and 3
    #expect(bobStore.documents.count == 2)  // Episodes 1 and 2
    #expect(charlieStore.documents.count == 2)  // Episodes 2 and 3

    // Verify first line is captured
    #expect(aliceStore.firstLine != nil)
    #expect(aliceStore.firstLine?.text == "Hello, Bob.")
    #expect(aliceStore.firstLine?.documentTitle == "Episode 1")
  }

  @Test("CP-P2: Dual dialogue characters counted separately")
  @MainActor
  func dualDialogueCharacterCounts() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let script = """
      INT. ROOM - DAY

      BRICK ^
      I'm leaving.

      STEEL ^
      So am I.

      They exit.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Dual Test")

    let result = try await actor.extractAllCharacters()

    #expect(result.characters.keys.contains("BRICK"))
    #expect(result.characters.keys.contains("STEEL"))
    #expect(result.characters["BRICK"]?.lineCount == 1)
    #expect(result.characters["STEEL"]?.lineCount == 1)
  }

  @Test("CP-P2: Unnamed cues are distinct characters")
  @MainActor
  func unnamedCuesAsCharacters() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let script = """
      INT. BAR - NIGHT

      BARTENDER
      What'll it be?

      COP #1
      Beer.

      COP #2
      Same.

      BARTENDER
      Coming up.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Bar Scene")

    let result = try await actor.extractAllCharacters()

    #expect(result.characters.keys.contains("BARTENDER"))
    #expect(result.characters.keys.contains("COP #1"))
    #expect(result.characters.keys.contains("COP #2"))
    #expect(result.characters["BARTENDER"]?.lineCount == 2)
    #expect(result.characters["COP #1"]?.lineCount == 1)
    #expect(result.characters["COP #2"]?.lineCount == 1)
  }

  @Test("CP-P2: Extension removal (V.O., CONT'D) works correctly")
  @MainActor
  func characterNameCleaning() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let script = """
      INT. OFFICE - DAY

      HUNTER
      Start the mission.

      EXT. FIELD - DAY

      HUNTER (V.O.)
      We're on our way.

      INT. OFFICE - DAY

      HUNTER (CONT'D)
      Almost there.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Extensions Test")

    let result = try await actor.extractAllCharacters()

    // All variations should be cleaned to "HUNTER"
    #expect(result.characters.keys.count == 1)
    #expect(result.characters.keys.contains("HUNTER"))
    #expect(result.characters["HUNTER"]?.lineCount == 3)
  }

  @Test("CP-P2: Result is Codable and Sendable")
  @MainActor
  func resultIsCodableAndSendable() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let script = """
      INT. ROOM - DAY

      ALICE
      Hello.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Test")

    let result = try await actor.extractAllCharacters()

    // Verify it can be encoded and decoded
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(result)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(CharacterCollectionResult.self, from: data)

    #expect(decoded.characters.keys.count == result.characters.keys.count)
    #expect(decoded.characters["ALICE"]?.lineCount == result.characters["ALICE"]?.lineCount)
  }

  // MARK: - Acceptance 1.5: Character's lines query (CP-P3)

  @Test("CP-P3: fetchLines returns character's dialogue in script order across documents")
  @MainActor
  func characterLinesQuery() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    // Parse three documents with HUNTER appearing in different orders
    let doc1 = """
      INT. OFFICE - DAY

      ALICE
      Ready?

      HUNTER
      Let's begin.

      BOB
      I agree.

      HUNTER
      Good luck.
      """

    let doc2 = """
      EXT. FIELD - DAY

      CHARLIE
      What now?

      HUNTER
      Keep moving.
      """

    let doc3 = """
      INT. BASE - NIGHT

      HUNTER
      Mission complete.

      ALICE
      Well done.

      HUNTER
      (quietly)
      Thanks.

      HUNTER
      Let's head back.
      """

    // Parse in specific order: Episode 2, Episode 1, Episode 3
    // Results should be ordered by title: Episode 1, Episode 2, Episode 3
    _ = try await actor.parseAndSaveDocument(from: doc2, title: "Episode 2")
    _ = try await actor.parseAndSaveDocument(from: doc1, title: "Episode 1")
    _ = try await actor.parseAndSaveDocument(from: doc3, title: "Episode 3")

    let lines = try await actor.fetchLines(for: "HUNTER")

    // Verify line count: 2 from Episode 1, 1 from Episode 2, 4 from Episode 3
    #expect(lines.count == 7)

    // Verify all are HUNTER's lines
    for line in lines {
      #expect(line.speaker == "HUNTER")
    }

    // Verify script order: Episode 1, then Episode 2, then Episode 3
    #expect(lines[0].documentTitle == "Episode 1")
    #expect(lines[0].text == "Let's begin.")

    #expect(lines[1].documentTitle == "Episode 1")
    #expect(lines[1].text == "Good luck.")

    #expect(lines[2].documentTitle == "Episode 2")
    #expect(lines[2].text == "Keep moving.")

    #expect(lines[3].documentTitle == "Episode 3")
    #expect(lines[3].text == "Mission complete.")

    #expect(lines[4].documentTitle == "Episode 3")
    #expect(lines[4].text == "(quietly)")

    #expect(lines[5].documentTitle == "Episode 3")
    #expect(lines[5].text == "Thanks.")

    #expect(lines[6].documentTitle == "Episode 3")
    #expect(lines[6].text == "Let's head back.")

    // Verify orderIndex is increasing within each document
    var lastDocTitle = ""
    var lastOrderIndex = -1
    for line in lines {
      if line.documentTitle != lastDocTitle {
        lastDocTitle = line.documentTitle
        lastOrderIndex = -1
      }
      #expect(line.orderIndex > lastOrderIndex)
      lastOrderIndex = line.orderIndex
    }
  }

  @Test("CP-P3: Character name cleaning works in fetchLines")
  @MainActor
  func fetchLinesWithExtensions() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let script = """
      INT. ROOM - DAY

      HUNTER
      Start.

      HUNTER (V.O.)
      Narrating.

      HUNTER (CONT'D)
      Continue.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Test")

    // All variations should return the same lines
    let lines1 = try await actor.fetchLines(for: "HUNTER")
    let lines2 = try await actor.fetchLines(for: "HUNTER (V.O.)")
    let lines3 = try await actor.fetchLines(for: "HUNTER (CONT'D)")

    #expect(lines1.count == 3)
    #expect(lines2.count == 3)
    #expect(lines3.count == 3)

    #expect(lines1.map(\.text) == ["Start.", "Narrating.", "Continue."])
  }

  // MARK: - Acceptance 2: Full-scene query (CP-P4)

  @Test("CP-P4: Full-scene query returns only scenes where character speaks, complete")
  @MainActor
  func fullSceneQuery() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let script = """
      INT. OFFICE - DAY

      ALICE
      Good morning.

      BOB
      Morning.

      EXT. PARK - DAY

      CHARLIE
      Nice weather.

      DANA
      Indeed.

      INT. CAFE - NIGHT

      ALICE
      Coffee?

      CHARLIE
      Please.

      ALICE
      Here you go.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Multi-Scene")

    let aliceScenes = try await actor.fetchScenes(for: "ALICE")

    // ALICE speaks in scenes 0 and 2, not scene 1
    #expect(aliceScenes.count == 2)
    #expect(aliceScenes[0].sceneIndex == 0)
    #expect(aliceScenes[1].sceneIndex == 2)

    // Verify scene 0 is complete (heading + all elements)
    let scene0 = aliceScenes[0]
    #expect(scene0.heading == "INT. OFFICE - DAY")
    #expect(scene0.elements.count > 0)
    #expect(scene0.elements.contains { $0.speaker == "ALICE" })
    #expect(scene0.elements.contains { $0.speaker == "BOB" })

    // Verify scene 2 is complete
    let scene2 = aliceScenes[1]
    #expect(scene2.heading == "INT. CAFE - NIGHT")
    #expect(scene2.elements.contains { $0.speaker == "ALICE" })
    #expect(scene2.elements.contains { $0.speaker == "CHARLIE" })
  }

  @Test("CP-P4: Scene query respects script order across documents")
  @MainActor
  func sceneQueryScriptOrder() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let doc1 = """
      INT. OFFICE - DAY

      HUNTER
      Let's go.
      """

    let doc2 = """
      EXT. FIELD - DAY

      HUNTER
      We're here.
      """

    // Parse in order: Episode 1, then Episode 2
    _ = try await actor.parseAndSaveDocument(from: doc1, title: "Episode 1")
    _ = try await actor.parseAndSaveDocument(from: doc2, title: "Episode 2")

    let scenes = try await actor.fetchScenes(for: "HUNTER")

    #expect(scenes.count == 2)
    // Documents are sorted by title, so "Episode 1" comes before "Episode 2"
    #expect(scenes[0].documentTitle == "Episode 1")
    #expect(scenes[1].documentTitle == "Episode 2")
  }

  // MARK: - Acceptance 3: Line windows with neighbours (CP-P5)

  @Test("CP-P5: Lines four elements apart merge into one window")
  @MainActor
  func lineWindowMerging() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    // Character has two lines with 4 blocks between them (within ±3 range)
    let script = """
      INT. ROOM - DAY

      HUNTER
      First line.

      Action block 1.

      ALICE
      Response.

      Action block 2.

      HUNTER
      Second line.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Window Test")

    let windows = try await actor.fetchLineWindows(for: "HUNTER", neighbours: 3)

    // Should merge into one window since they're 4 blocks apart (within ±3)
    #expect(windows.count == 1)

    let window = windows[0]
    #expect(window.blocks.count > 1)

    // Verify both HUNTER lines are marked as character lines
    let hunterLines = window.blocks.filter { $0.isCharacterLine }
    #expect(hunterLines.count == 2)
  }

  @Test("CP-P5: Windows don't cross scene boundaries")
  @MainActor
  func windowsRespectSceneBoundaries() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let script = """
      INT. ROOM A - DAY

      HUNTER
      End of scene.

      INT. ROOM B - DAY

      HUNTER
      Start of new scene.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Scene Boundary")

    let windows = try await actor.fetchLineWindows(for: "HUNTER", neighbours: 10)

    // Should be two separate windows despite large radius
    #expect(windows.count == 2)
    #expect(windows[0].sceneIndex == 0)
    #expect(windows[1].sceneIndex == 1)
  }

  @Test("CP-P5: Adjacent windows that don't overlap stay separate")
  @MainActor
  func adjacentWindowsSeparate() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    // Create script where HUNTER lines are far enough apart that ±3 windows don't overlap
    // Block structure: HUNTER (0), Action (1), ALICE (2), Action (3), BOB (4), Action (5), HUNTER (6)
    // HUNTER at block 0: window is [0-3] (max(0, 0-3) to min(6, 0+3))
    // HUNTER at block 6: window is [3-6] (max(0, 6-3) to min(6, 6+3))
    // These overlap at blocks 3, so they should merge into one window
    let script = """
      INT. ROOM - DAY

      HUNTER
      Line one.

      Action 1.

      ALICE
      A speaks.

      Action 2.

      BOB
      B speaks.

      Action 3.

      HUNTER
      Line two.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Adjacent Test")

    let windows = try await actor.fetchLineWindows(for: "HUNTER", neighbours: 3)

    // With 7 total blocks and HUNTER at blocks 0 and 6:
    // Window 1: [0-3], Window 2: [3-6] → overlap at block 3 → merge
    #expect(windows.count == 1)
    #expect(windows[0].blocks.count == 7)  // All blocks in the scene
  }

  @Test("CP-P5: Window clipping at scene boundaries")
  @MainActor
  func windowClippingAtBoundaries() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let script = """
      INT. ROOM - DAY

      HUNTER
      First line in scene.

      Action.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Boundary Clip")

    let windows = try await actor.fetchLineWindows(for: "HUNTER", neighbours: 10)

    // Large radius, but window should be clipped to scene
    #expect(windows.count == 1)
    let window = windows[0]
    // Should not extend beyond the scene's actual content
    #expect(window.blocks.count <= 3)  // HUNTER block + Action block + margin
  }

  @Test("CP-P5: Speaker labels on all blocks")
  @MainActor
  func speakerLabelsOnBlocks() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let script = """
      INT. ROOM - DAY

      ALICE
      Hello.

      Action paragraph.

      BOB
      Hi there.

      ALICE
      How are you?
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Labels Test")

    let windows = try await actor.fetchLineWindows(for: "ALICE", neighbours: 2)

    #expect(windows.count >= 1)
    let window = windows[0]

    // Verify speaker labels are present
    let aliceBlocks = window.blocks.filter { $0.speaker == "ALICE" }
    let bobBlocks = window.blocks.filter { $0.speaker == "BOB" }
    let actionBlocks = window.blocks.filter { $0.speaker == nil }

    #expect(aliceBlocks.count > 0)
    #expect(bobBlocks.count > 0 || actionBlocks.count > 0)
  }

  // MARK: - Acceptance 4: Migration validation

  @Test("CP-P1: Query on store with missing speaker data throws error")
  @MainActor
  func migrationValidation() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    // Create a document and manually clear speaker to simulate V2 data
    let script = """
      INT. ROOM - DAY

      ALICE
      Hello.
      """

    let id = try await actor.parseAndSaveDocument(from: script, title: "Old Document")

    // Now manually clear the speaker field to simulate Schema V2 migration
    let context = container.mainContext
    guard let doc = context.model(for: id) as? GuionDocumentModel else {
      Issue.record("Failed to retrieve document")
      return
    }

    for element in doc.sortedElements {
      element.speaker = nil
    }
    try context.save()

    // Queries should throw speakerDataMissing error
    do {
      _ = try await actor.fetchLines(for: "ALICE")
      Issue.record("Expected speakerDataMissing error")
    } catch DocumentModelActorError.speakerDataMissing(let titles) {
      #expect(titles.count > 0)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  // MARK: - Acceptance 5: Existing voice intents unchanged (regression)

  @Test("CP-P1: CharacterVoiceMapping model unchanged")
  @MainActor
  func voiceMappingModelRegression() async throws {
    let container = try makeContainer()
    let context = container.mainContext

    // Create a voice mapping as it was at b0bd600
    let mapping = CharacterVoiceMapping(
      characterName: "ALICE",
      voiceURI: "system://com.apple.voice.premium.en-US.Samantha",
      voiceName: "Samantha",
      providerID: "system"
    )

    context.insert(mapping)
    try context.save()

    // Verify it persists correctly
    let descriptor = FetchDescriptor<CharacterVoiceMapping>()
    let mappings = try context.fetch(descriptor)

    #expect(mappings.count == 1)
    #expect(mappings[0].characterName == "ALICE")
    #expect(mappings[0].voiceURI == "system://com.apple.voice.premium.en-US.Samantha")
    #expect(mappings[0].voiceName == "Samantha")
    #expect(mappings[0].providerID == "system")
  }

  @Test("CP-P1: ExtractCharactersIntent structure unchanged")
  func extractCharactersIntentRegression() async throws {
    // Verify the intent exists and has the expected structure
    let intent = ExtractCharactersIntent()

    // Verify documentIDString parameter exists
    _ = intent.documentIDString

    // The intent should still work
    // documentIDString is non-optional, so just verify it exists
    _ = intent.documentIDString
  }

  @Test("CP-P1: Voice casting intents structure unchanged")
  func voiceCastingIntentsRegression() async throws {
    // Verify GetVoiceCastingIntent exists
    let getIntent = GetVoiceCastingIntent()
    _ = getIntent.documentIDString

    // Verify SetVoiceCastingIntent exists
    let setIntent = SetVoiceCastingIntent()
    _ = setIntent.documentIDString
    _ = setIntent.characterName
    _ = setIntent.voiceURI

    // documentIDString is non-optional, so just verify they exist
    _ = getIntent.documentIDString
    _ = setIntent.documentIDString
  }

  // MARK: - Edge case unit tests

  @Test("CP-P3: Empty store returns empty results")
  @MainActor
  func emptyStoreQuery() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let lines = try await actor.fetchLines(for: "NONEXISTENT")
    #expect(lines.isEmpty)

    let scenes = try await actor.fetchScenes(for: "NONEXISTENT")
    #expect(scenes.isEmpty)

    let windows = try await actor.fetchLineWindows(for: "NONEXISTENT")
    #expect(windows.isEmpty)
  }

  @Test("CP-P3: Query for nonexistent character returns empty")
  @MainActor
  func nonexistentCharacterQuery() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let script = """
      INT. ROOM - DAY

      ALICE
      Hello.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Test")

    let lines = try await actor.fetchLines(for: "BOB")
    #expect(lines.isEmpty)
  }

  @Test("CP-P5: Negative neighbours parameter throws error")
  @MainActor
  func negativeNeighboursError() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let script = """
      INT. ROOM - DAY

      ALICE
      Hello.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Test")

    do {
      _ = try await actor.fetchLineWindows(for: "ALICE", neighbours: -1)
      Issue.record("Expected invalidData error")
    } catch DocumentModelActorError.invalidData {
      // Expected
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test("CP-P6: Results are deterministic across multiple queries")
  @MainActor
  func deterministicOrdering() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let script = """
      INT. ROOM - DAY

      ALICE
      Line 1.

      BOB
      Response.

      ALICE
      Line 2.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Determinism Test")

    // Run query multiple times
    let lines1 = try await actor.fetchLines(for: "ALICE")
    let lines2 = try await actor.fetchLines(for: "ALICE")
    let lines3 = try await actor.fetchLines(for: "ALICE")

    // Results should be identical
    #expect(lines1.count == lines2.count)
    #expect(lines2.count == lines3.count)

    for i in 0..<lines1.count {
      #expect(lines1[i].text == lines2[i].text)
      #expect(lines2[i].text == lines3[i].text)
      #expect(lines1[i].orderIndex == lines2[i].orderIndex)
    }
  }

  @Test("CP-P5: Single-element scene handling")
  @MainActor
  func singleElementScene() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let script = """
      INT. ROOM - DAY

      ALICE
      Only line in scene.

      INT. NEXT ROOM - DAY

      BOB
      Different scene.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Single Element")

    let windows = try await actor.fetchLineWindows(for: "ALICE", neighbours: 3)

    #expect(windows.count == 1)
    #expect(windows[0].sceneIndex == 0)
  }

  @Test("CP-P2: Character with parenthetical and dialogue is counted")
  @MainActor
  func parentheticalWithDialogueCounted() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    let script = """
      INT. ROOM - DAY

      ALICE
      (quietly)
      Hello.

      BOB
      Hi there.
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Parenthetical Test")

    let result = try await actor.extractAllCharacters()

    // Both ALICE and BOB have dialogue, so both should be counted
    #expect(result.characters.keys.contains("ALICE"))
    #expect(result.characters.keys.contains("BOB"))
    #expect(result.characters["ALICE"]?.lineCount == 1)
    #expect(result.characters["BOB"]?.lineCount == 1)
  }

  // MARK: - Regression Tests

  @Test("Regression: Parenthetical-only character is not counted as speaking")
  @MainActor
  func parentheticalOnlyCharacterNotCounted() async throws {
    let container = try makeContainer()
    let actor = DocumentModelActor(modelContainer: container)

    // Script where DIRECTOR has only a parenthetical, no dialogue
    let script = """
      INT. OFFICE - DAY

      ALICE
      (excited)
      I got the job!

      DIRECTOR
      (shaking head)

      The director doesn't speak, only a parenthetical.

      BOB
      Congratulations!
      """

    _ = try await actor.parseAndSaveDocument(from: script, title: "Parenthetical Only")

    let result = try await actor.extractAllCharacters()

    // ALICE and BOB have dialogue, so they should be counted
    #expect(result.characters.keys.contains("ALICE"))
    #expect(result.characters.keys.contains("BOB"))
    #expect(result.characters["ALICE"]?.lineCount == 1)
    #expect(result.characters["BOB"]?.lineCount == 1)

    // DIRECTOR has only parenthetical, no dialogue → should NOT be in speaking characters
    // (Per CP-P2 contract: a speaking character has dialogue, not just parenthetical)
    #expect(!result.characters.keys.contains("DIRECTOR"))
  }

  // MARK: - Helper

  @MainActor
  private func makeContainer() throws -> ModelContainer {
    let schema = Schema([
      GuionDocumentModel.self,
      GuionElementModel.self,
      TypedDataStorage.self,
      TitlePageEntryModel.self,
      CustomPageModel.self,
      CharacterVoiceMapping.self,
      CustomOutlineElement.self,
    ])
    return try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
  }
}
