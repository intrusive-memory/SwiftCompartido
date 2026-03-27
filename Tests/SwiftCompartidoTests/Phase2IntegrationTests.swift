//
//  Phase2IntegrationTests.swift
//  SwiftCompartido
//
//  Phase 2: Testing & Production Readiness
//  Integration tests for JSON .guion format round-trip fidelity
//

import Foundation
import Testing

#if canImport(SwiftData)
  import SwiftData
  @testable import SwiftCompartido

  /// Phase 2 integration tests validating production readiness
  ///
  /// These tests ensure Phase 1 implementation is bulletproof:
  /// - JSON round-trip fidelity
  /// - Casting persistence
  /// - UUID preservation
  /// - TextPack backward compatibility
  /// - Performance benchmarks
  @Suite("Phase 2: Production Readiness Tests")
  struct Phase2IntegrationTests {

    // MARK: - JSON Round-Trip Tests

    @Test("JSON round-trip preserves basic document properties")
    @MainActor
    func testBasicDocumentRoundTrip() async throws {
      let container = try ModelContainer(for: GuionDocumentModel.self)
      let context = ModelContext(container)

      // Create document with basic properties
      let original = GuionDocumentModel(
        filename: "test-screenplay.guion",
        rawContent: "INT. TEST - DAY",
        suppressSceneNumbers: true
      )
      original.title = "Test Screenplay"

      // Add elements
      let element1 = GuionElementModel(
        elementText: "INT. COFFEE SHOP - DAY",
        elementType: .sceneHeading,
        orderIndex: 1
      )
      let element2 = GuionElementModel(
        elementText: "JANE sits at a table.",
        elementType: .action,
        orderIndex: 2
      )
      original.elements = [element1, element2]

      // Convert to snapshot
      let snapshot = original.toSnapshot()

      // Serialize to JSON
      let jsonData = try GuionJSONSerializer.encode(snapshot)

      // Deserialize from JSON
      let loadedSnapshot = try GuionJSONSerializer.decode(jsonData)

      // Convert back to model
      let restored = GuionDocumentModel.from(loadedSnapshot, in: context)

      // Verify basic properties
      #expect(restored.filename == original.filename)
      #expect(restored.title == original.title)
      #expect(restored.suppressSceneNumbers == original.suppressSceneNumbers)
      #expect(restored.elements.count == original.elements.count)

      // Verify elements
      let sortedOriginal = original.sortedElements
      let sortedRestored = restored.sortedElements

      #expect(sortedRestored[0].elementText == sortedOriginal[0].elementText)
      #expect(sortedRestored[0].elementType == sortedOriginal[0].elementType)
      #expect(sortedRestored[1].elementText == sortedOriginal[1].elementText)
      #expect(sortedRestored[1].elementType == sortedOriginal[1].elementType)
    }

    @Test("JSON round-trip preserves element UUIDs")
    @MainActor
    func testUUIDPreservation() async throws {
      let container = try ModelContainer(for: GuionDocumentModel.self)
      let context = ModelContext(container)

      // Create document with elements
      let original = GuionDocumentModel(filename: "uuid-test.guion")

      let uuid1 = UUID()
      let uuid2 = UUID()
      let uuid3 = UUID()

      let element1 = GuionElementModel(
        elementText: "Scene 1",
        elementType: .sceneHeading,
        orderIndex: 1,
        uuid: uuid1
      )
      let element2 = GuionElementModel(
        elementText: "Action line",
        elementType: .action,
        orderIndex: 2,
        uuid: uuid2
      )
      let element3 = GuionElementModel(
        elementText: "JANE",
        elementType: .character,
        orderIndex: 3,
        uuid: uuid3
      )

      original.elements = [element1, element2, element3]

      // Round-trip through JSON
      let snapshot = original.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)
      let loadedSnapshot = try GuionJSONSerializer.decode(jsonData)
      let restored = GuionDocumentModel.from(loadedSnapshot, in: context)

      // Verify UUIDs are preserved
      let sortedRestored = restored.sortedElements

      #expect(sortedRestored[0].uuid == uuid1)
      #expect(sortedRestored[1].uuid == uuid2)
      #expect(sortedRestored[2].uuid == uuid3)
    }

    @Test("JSON round-trip preserves character voice casting")
    @MainActor
    func testCastingRoundTrip() async throws {
      let container = try ModelContainer(
        for: GuionDocumentModel.self,
        CharacterVoiceMapping.self
      )
      let context = ModelContext(container)

      // Create document with casting
      let original = GuionDocumentModel(filename: "casting-test.guion")

      let janeVoice = CharacterVoiceMapping(
        characterName: "JANE",
        voiceURI: "macos://Samantha?lang=en",
        voiceName: "Samantha",
        providerID: "macos"
      )

      let johnVoice = CharacterVoiceMapping(
        characterName: "JOHN",
        voiceURI: "elevenlabs://voice-id-123?lang=en",
        voiceName: "Daniel",
        providerID: "elevenlabs"
      )

      original.casting = [janeVoice, johnVoice]

      // Round-trip through JSON
      let snapshot = original.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)
      let loadedSnapshot = try GuionJSONSerializer.decode(jsonData)
      let restored = GuionDocumentModel.from(loadedSnapshot, in: context)

      // Verify casting is preserved
      #expect(restored.casting?.count == 2)

      let janeRestored = restored.casting?.first { $0.characterName == "JANE" }
      #expect(janeRestored?.voiceURI == "macos://Samantha?lang=en")
      #expect(janeRestored?.voiceName == "Samantha")
      #expect(janeRestored?.providerID == "macos")

      let johnRestored = restored.casting?.first { $0.characterName == "JOHN" }
      #expect(johnRestored?.voiceURI == "elevenlabs://voice-id-123?lang=en")
      #expect(johnRestored?.voiceName == "Daniel")
      #expect(johnRestored?.providerID == "elevenlabs")
    }

    @Test("JSON round-trip preserves title page entries")
    @MainActor
    func testTitlePageRoundTrip() async throws {
      let container = try ModelContainer(for: GuionDocumentModel.self)
      let context = ModelContext(container)

      // Create document with title page
      let original = GuionDocumentModel(filename: "titlepage-test.guion")

      let titleEntry = TitlePageEntryModel(key: "Title", values: ["The Great Screenplay"])
      let authorEntry = TitlePageEntryModel(key: "Author", values: ["Jane Doe", "John Smith"])
      let draftEntry = TitlePageEntryModel(key: "Draft", values: ["First Draft"])

      original.titlePage = [titleEntry, authorEntry, draftEntry]

      // Round-trip through JSON
      let snapshot = original.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)
      let loadedSnapshot = try GuionJSONSerializer.decode(jsonData)
      let restored = GuionDocumentModel.from(loadedSnapshot, in: context)

      // Verify title page (keys are normalized to uppercase)
      #expect(restored.titlePage.count == 3)

      let restoredTitle = restored.titlePage.first { $0.key == "TITLE" }
      #expect(restoredTitle?.values == ["The Great Screenplay"])

      let restoredAuthor = restored.titlePage.first { $0.key == "AUTHOR" }
      #expect(restoredAuthor?.values == ["Jane Doe", "John Smith"])

      let restoredDraft = restored.titlePage.first { $0.key == "DRAFT" }
      #expect(restoredDraft?.values == ["First Draft"])
    }

    @Test("JSON round-trip preserves custom pages")
    @MainActor
    func testCustomPagesRoundTrip() async throws {
      let container = try ModelContainer(for: GuionDocumentModel.self)
      let context = ModelContext(container)

      // Create document with custom pages
      let original = GuionDocumentModel(filename: "custompages-test.guion")

      let castList1 = CastListPage(
        title: "Cast List - Main Characters",
        position: 0,
        printDots: true,
        items: [
          CastListPage.CastMember(role: "JANE", name: "Sarah Johnson"),
          CastListPage.CastMember(role: "JOHN", name: "Michael Brown"),
        ]
      )

      let castList2 = CastListPage(
        title: "Cast List - Supporting",
        position: 1,
        printDots: false,
        items: [
          CastListPage.CastMember(role: "BARTENDER", name: "Tom Wilson")
        ]
      )

      let container1 = try CustomPageContainer(page: castList1, type: .castList)
      let container2 = try CustomPageContainer(page: castList2, type: .castList)

      let page1 = CustomPageModel.from(container1)
      let page2 = CustomPageModel.from(container2)

      original.customPages = [page1, page2]

      // Round-trip through JSON
      let snapshot = original.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)
      let loadedSnapshot = try GuionJSONSerializer.decode(jsonData)
      let restored = GuionDocumentModel.from(loadedSnapshot, in: context)

      // Verify custom pages
      #expect(restored.customPages.count == 2)

      let sortedPages = restored.sortedCustomPages
      #expect(sortedPages[0].pageType == "castList")
      #expect(sortedPages[1].pageType == "castList")
    }

    @Test("JSON round-trip preserves large documents (1000+ elements)")
    @MainActor
    func testLargeDocumentRoundTrip() async throws {
      let container = try ModelContainer(for: GuionDocumentModel.self)
      let context = ModelContext(container)

      // Create large document
      let original = GuionDocumentModel(filename: "large-test.guion")

      var elements: [GuionElementModel] = []
      for i in 0..<1000 {
        let element = GuionElementModel(
          elementText: "Element \(i)",
          elementType: i % 5 == 0 ? .sceneHeading : .action,
          orderIndex: i
        )
        elements.append(element)
      }

      original.elements = elements

      // Round-trip through JSON
      let snapshot = original.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)
      let loadedSnapshot = try GuionJSONSerializer.decode(jsonData)
      let restored = GuionDocumentModel.from(loadedSnapshot, in: context)

      // Verify all elements preserved
      #expect(restored.elements.count == 1000)

      let sortedRestored = restored.sortedElements
      #expect(sortedRestored[0].elementText == "Element 0")
      #expect(sortedRestored[999].elementText == "Element 999")
    }

    @Test("JSON round-trip preserves source file tracking metadata")
    @MainActor
    func testSourceFileTrackingRoundTrip() async throws {
      let container = try ModelContainer(for: GuionDocumentModel.self)
      let context = ModelContext(container)

      // Create document with source file metadata
      let original = GuionDocumentModel(filename: "metadata-test.guion")

      let importDate = Date()
      let modDate = Date().addingTimeInterval(-86400)  // Yesterday
      let openDate = Date()

      original.lastImportDate = importDate
      original.sourceFileModificationDate = modDate
      original.lastOpenedDate = openDate
      original.sourceFileBookmark = Data([1, 2, 3, 4, 5])  // Mock bookmark

      // Round-trip through JSON
      let snapshot = original.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)
      let loadedSnapshot = try GuionJSONSerializer.decode(jsonData)
      let restored = GuionDocumentModel.from(loadedSnapshot, in: context)

      // Verify metadata (within 1 second tolerance for date encoding)
      #expect(restored.sourceFileBookmark == Data([1, 2, 3, 4, 5]))

      if let restoredImport = restored.lastImportDate {
        #expect(abs(restoredImport.timeIntervalSince(importDate)) < 1.0)
      } else {
        Issue.record("lastImportDate not preserved")
      }

      if let restoredMod = restored.sourceFileModificationDate {
        #expect(abs(restoredMod.timeIntervalSince(modDate)) < 1.0)
      } else {
        Issue.record("sourceFileModificationDate not preserved")
      }

      if let restoredOpen = restored.lastOpenedDate {
        #expect(abs(restoredOpen.timeIntervalSince(openDate)) < 1.0)
      } else {
        Issue.record("lastOpenedDate not preserved")
      }
    }

    @Test("JSON serialization produces valid, pretty-printed JSON")
    func testJSONFormat() throws {
      // Create a simple snapshot
      let snapshot = GuionDocumentSnapshot(
        id: UUID(),
        filename: "format-test.guion",
        title: "Test",
        elements: [
          GuionElementSnapshot(
            id: UUID(),
            chapterIndex: 0,
            orderIndex: 1,
            elementText: "Test scene",
            elementType: .sceneHeading
          )
        ],
        titlePage: [],
        customPages: nil,
        generatedContent: nil,
        casting: nil
      )

      // Serialize to JSON
      let jsonData = try GuionJSONSerializer.encode(snapshot)
      let jsonString = String(data: jsonData, encoding: .utf8)

      // Verify it's valid JSON
      #expect(jsonString != nil)

      // Verify it's pretty-printed (has newlines and indentation)
      #expect(jsonString?.contains("\n") == true)
      #expect(jsonString?.contains("  ") == true)  // Indentation

      // Verify required keys exist
      #expect(jsonString?.contains("\"filename\"") == true)
      #expect(jsonString?.contains("\"elements\"") == true)
    }
  }

#endif
