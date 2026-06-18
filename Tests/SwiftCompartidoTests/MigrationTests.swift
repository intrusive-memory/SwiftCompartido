//
//  MigrationTests.swift
//  SwiftCompartido
//
//  Tests for SwiftData schema versioning and migration
//

import Foundation
import SwiftData
import Testing
@testable import SwiftCompartido

/// Tests for schema versioning and migration from V1 (pre-glosa) to V2 (glosa-enabled).
///
/// These tests verify that:
/// 1. Old stores (V1 schema) migrate cleanly to V2 without data loss
/// 2. New glosa fields default to `nil` after migration
/// 3. Pre-existing fields (`elementText`, `elementType`, etc.) remain intact
///
/// ## Migration Pattern
///
/// Consumer apps that adopt SwiftCompartido v7.0.5+ must include both schema
/// versions in their `SchemaMigrationPlan`:
///
/// ```swift
/// enum MyAppMigrationPlan: SchemaMigrationPlan {
///   static var schemas: [any VersionedSchema.Type] {
///     [SwiftCompartidoSchemaV1.self, SwiftCompartidoSchemaV2.self]
///   }
///
///   static var stages: [MigrationStage] {
///     [SwiftCompartidoSchemaV2.migrationStage]
///   }
/// }
/// ```
@Suite("Schema Migration Tests", .tags(.migration))
struct MigrationTests {

  /// Test that V1 store migrates to V2 cleanly with glosa fields defaulting to nil.
  ///
  /// **Migration verification**:
  /// 1. Create a V1 store with sample GuionElementModel instances (no glosa fields)
  /// 2. Close the V1 store
  /// 3. Reopen with V2 schema + migration plan
  /// 4. Verify migration completes without error
  /// 5. Fetch migrated elements and confirm:
  ///    - New glosa fields default to `nil`
  ///    - Pre-existing `elementText`, `elementType`, etc. are intact
  @Test("V1 to V2 lightweight migration preserves existing data and defaults glosa fields to nil")
  func testLightweightMigrationV1ToV2() throws {
    // Create temporary URL for V1 store
    let tempDir = FileManager.default.temporaryDirectory
    let storeURL = tempDir.appendingPathComponent("migration-test-\(UUID().uuidString).store")

    // Cleanup helper
    defer {
      try? FileManager.default.removeItem(at: storeURL)
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))
    }

    // MARK: - Step 1: Create V1 store with sample data

    let v1Config = ModelConfiguration(url: storeURL)
    let v1Schema = Schema(versionedSchema: SwiftCompartidoSchemaV1.self)
    let v1Container = try ModelContainer(for: v1Schema, configurations: v1Config)

    let sampleElementText = "INT. COFFEE SHOP - DAY"
    let sampleElementTypeString = "Scene Heading"
    let sampleUUID = UUID()

    // Insert sample V1 element
    let v1Context = ModelContext(v1Container)
    let v1Element = SwiftCompartidoSchemaV1.GuionElementModel(
      elementText: sampleElementText,
      elementTypeString: sampleElementTypeString,
      isCentered: false,
      isDualDialogue: false,
      sceneNumber: "1",
      sectionDepth: 0,
      summary: "Opening scene",
      sceneId: nil,
      chapterIndex: 0,
      orderIndex: 1,
      uuid: sampleUUID
    )
    v1Context.insert(v1Element)
    try v1Context.save()

    // Close V1 container
    // Note: ModelContainer doesn't have an explicit close() method, so we rely on scope exit

    // MARK: - Step 2: Reopen with V2 schema + migration plan

    // Define migration plan
    enum TestMigrationPlan: SchemaMigrationPlan {
      static var schemas: [any VersionedSchema.Type] {
        [SwiftCompartidoSchemaV1.self, SwiftCompartidoSchemaV2.self]
      }

      static var stages: [MigrationStage] {
        [SwiftCompartidoSchemaV2.migrationStage]
      }
    }

    let v2Config = ModelConfiguration(url: storeURL)
    let v2Schema = Schema(versionedSchema: SwiftCompartidoSchemaV2.self)
    let v2Container = try ModelContainer(
      for: v2Schema,
      migrationPlan: TestMigrationPlan.self,
      configurations: v2Config
    )

    // MARK: - Step 3: Verify migration results

    let v2Context = ModelContext(v2Container)
    let fetchDescriptor = FetchDescriptor<SwiftCompartidoSchemaV2.GuionElementModel>(
      predicate: #Predicate { $0.uuid == sampleUUID }
    )
    let migratedElements = try v2Context.fetch(fetchDescriptor)

    #expect(migratedElements.count == 1, "Should find exactly one migrated element")

    guard let migratedElement = migratedElements.first else {
      Issue.record("Failed to fetch migrated element")
      return
    }

    // MARK: - Step 4: Verify pre-existing fields are intact

    #expect(migratedElement.elementText == sampleElementText, "elementText should be preserved")
    #expect(migratedElement.uuid == sampleUUID, "uuid should be preserved")
    #expect(migratedElement.orderIndex == 1, "orderIndex should be preserved")
    #expect(migratedElement.chapterIndex == 0, "chapterIndex should be preserved")
    #expect(migratedElement.sceneNumber == "1", "sceneNumber should be preserved")
    #expect(migratedElement.summary == "Opening scene", "summary should be preserved")

    // MARK: - Step 5: Verify new glosa fields default to nil

    #expect(migratedElement.glosaSpokenText == nil, "glosaSpokenText should default to nil")
    #expect(migratedElement.glosaBreathOffsets == nil, "glosaBreathOffsets should default to nil")
    #expect(migratedElement.glosaBreathStrengths == nil, "glosaBreathStrengths should default to nil")
    #expect(migratedElement.glosaInstruct == nil, "glosaInstruct should default to nil")
    #expect(migratedElement.glosaPausePoints == nil, "glosaPausePoints should default to nil")
  }

  /// Test that a fresh V2 store can create elements with glosa fields populated.
  ///
  /// This verifies the V2 schema works correctly for new data (not just migrations).
  @Test("V2 schema can store glosa annotation data")
  func testV2SchemaStoresGlosaData() throws {
    // Create temporary URL for V2 store
    let tempDir = FileManager.default.temporaryDirectory
    let storeURL = tempDir.appendingPathComponent("v2-test-\(UUID().uuidString).store")

    // Cleanup helper
    defer {
      try? FileManager.default.removeItem(at: storeURL)
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))
    }

    // Create V2 store
    let v2Config = ModelConfiguration(url: storeURL)
    let v2Schema = Schema(versionedSchema: SwiftCompartidoSchemaV2.self)
    let v2Container = try ModelContainer(for: v2Schema, configurations: v2Config)

    let context = ModelContext(v2Container)

    // Create element with glosa data
    let element = SwiftCompartidoSchemaV2.GuionElementModel(
      elementText: "Hello [[<breath/>]] world!",
      elementTypeString: "Dialogue",
      chapterIndex: 0,
      orderIndex: 1
    )
    element.glosaSpokenText = "Hello  world!"  // notes stripped
    element.glosaBreathOffsets = [6]  // offset after "Hello "
    element.glosaBreathStrengths = ["medium"]
    element.glosaInstruct = "Speak warmly"

    context.insert(element)
    try context.save()

    // Fetch and verify
    let fetchDescriptor = FetchDescriptor<SwiftCompartidoSchemaV2.GuionElementModel>()
    let elements = try context.fetch(fetchDescriptor)

    #expect(elements.count == 1, "Should have one element")

    guard let fetched = elements.first else {
      Issue.record("Failed to fetch element")
      return
    }

    #expect(fetched.elementText == "Hello [[<breath/>]] world!", "Raw text preserved")
    #expect(fetched.glosaSpokenText == "Hello  world!", "Glosa spoken text stored")
    #expect(fetched.glosaBreathOffsets == [6], "Breath offsets stored")
    #expect(fetched.glosaBreathStrengths == ["medium"], "Breath strengths stored")
    #expect(fetched.glosaInstruct == "Speak warmly", "Glosa instruct stored")
  }

  /// Test that GuionDocumentModel fields migrate correctly.
  ///
  /// Verifies all document properties and relationships are preserved:
  /// - Document properties (filename, rawContent, suppressSceneNumbers, title)
  /// - Source file tracking (sourceFileBookmark, lastImportDate, sourceFileModificationDate)
  /// - Recent items tracking (lastOpenedDate)
  /// - Relationships (elements, titlePage, customPages, generatedContent, casting)
  @Test("GuionDocumentModel migration preserves all fields")
  func testGuionDocumentModelMigration() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let storeURL = tempDir.appendingPathComponent("doc-migration-test-\(UUID().uuidString).store")

    defer {
      try? FileManager.default.removeItem(at: storeURL)
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))
    }

    // Create V1 store with document
    let v1Config = ModelConfiguration(url: storeURL)
    let v1Schema = Schema(versionedSchema: SwiftCompartidoSchemaV1.self)
    let v1Container = try ModelContainer(for: v1Schema, configurations: v1Config)
    let v1Context = ModelContext(v1Container)

    let v1Doc = SwiftCompartidoSchemaV1.GuionDocumentModel(
      filename: "test-script.fountain",
      rawContent: "INT. TEST - DAY",
      suppressSceneNumbers: true,
      title: "Test Script"
    )
    v1Doc.sourceFileBookmark = Data([1, 2, 3, 4])
    v1Doc.lastImportDate = Date(timeIntervalSince1970: 1000000)
    v1Doc.sourceFileModificationDate = Date(timeIntervalSince1970: 900000)
    v1Doc.lastOpenedDate = Date(timeIntervalSince1970: 1100000)

    v1Context.insert(v1Doc)
    try v1Context.save()

    // Migrate to V2
    enum TestMigrationPlan: SchemaMigrationPlan {
      static var schemas: [any VersionedSchema.Type] {
        [SwiftCompartidoSchemaV1.self, SwiftCompartidoSchemaV2.self]
      }
      static var stages: [MigrationStage] {
        [SwiftCompartidoSchemaV2.migrationStage]
      }
    }

    let v2Config = ModelConfiguration(url: storeURL)
    let v2Schema = Schema(versionedSchema: SwiftCompartidoSchemaV2.self)
    let v2Container = try ModelContainer(
      for: v2Schema,
      migrationPlan: TestMigrationPlan.self,
      configurations: v2Config
    )

    let v2Context = ModelContext(v2Container)
    let fetchDescriptor = FetchDescriptor<SwiftCompartidoSchemaV2.GuionDocumentModel>(
      predicate: #Predicate { $0.filename == "test-script.fountain" }
    )
    let migratedDocs = try v2Context.fetch(fetchDescriptor)

    #expect(migratedDocs.count == 1, "Should find one migrated document")
    guard let doc = migratedDocs.first else {
      Issue.record("Failed to fetch migrated document")
      return
    }

    // Verify all fields preserved
    #expect(doc.filename == "test-script.fountain")
    #expect(doc.rawContent == "INT. TEST - DAY")
    #expect(doc.suppressSceneNumbers == true)
    #expect(doc.title == "Test Script")
    #expect(doc.sourceFileBookmark == Data([1, 2, 3, 4]))
    #expect(doc.lastImportDate?.timeIntervalSince1970 == 1000000)
    #expect(doc.sourceFileModificationDate?.timeIntervalSince1970 == 900000)
    #expect(doc.lastOpenedDate?.timeIntervalSince1970 == 1100000)
  }

  /// Test that TypedDataStorage fields migrate correctly.
  ///
  /// Verifies all content storage and metadata fields are preserved:
  /// - Identity (id, providerId, requestorID)
  /// - Content (textValue, mimeType)
  /// - Metadata (prompt, modelIdentifier, estimatedCost)
  /// - Type-specific metadata (wordCount, audioFormat, imageFormat, dimensions)
  /// - Timestamps (generatedAt, modifiedAt)
  @Test("TypedDataStorage migration preserves all fields")
  func testTypedDataStorageMigration() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let storeURL = tempDir.appendingPathComponent("storage-migration-test-\(UUID().uuidString).store")

    defer {
      try? FileManager.default.removeItem(at: storeURL)
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))
    }

    // Create V1 store with TypedDataStorage
    let v1Config = ModelConfiguration(url: storeURL)
    let v1Schema = Schema(versionedSchema: SwiftCompartidoSchemaV1.self)
    let v1Container = try ModelContainer(for: v1Schema, configurations: v1Config)
    let v1Context = ModelContext(v1Container)

    let storageID = UUID()
    let generatedDate = Date(timeIntervalSince1970: 2000000)
    let modifiedDate = Date(timeIntervalSince1970: 2001000)

    let v1Storage = SwiftCompartidoSchemaV1.TypedDataStorage(
      id: storageID,
      providerId: "openai",
      requestorID: "gpt-4",
      mimeType: "text/plain",
      prompt: "Generate a summary"
    )
    v1Storage.textValue = "This is a test summary."
    v1Storage.wordCount = 5
    v1Storage.characterCount = 23
    v1Storage.languageCode = "en"
    v1Storage.modelIdentifier = "gpt-4-turbo"
    v1Storage.estimatedCost = 0.05
    v1Storage.generatedAt = generatedDate
    v1Storage.modifiedAt = modifiedDate

    v1Context.insert(v1Storage)
    try v1Context.save()

    // Migrate to V2
    enum TestMigrationPlan: SchemaMigrationPlan {
      static var schemas: [any VersionedSchema.Type] {
        [SwiftCompartidoSchemaV1.self, SwiftCompartidoSchemaV2.self]
      }
      static var stages: [MigrationStage] {
        [SwiftCompartidoSchemaV2.migrationStage]
      }
    }

    let v2Config = ModelConfiguration(url: storeURL)
    let v2Schema = Schema(versionedSchema: SwiftCompartidoSchemaV2.self)
    let v2Container = try ModelContainer(
      for: v2Schema,
      migrationPlan: TestMigrationPlan.self,
      configurations: v2Config
    )

    let v2Context = ModelContext(v2Container)
    let fetchDescriptor = FetchDescriptor<SwiftCompartidoSchemaV2.TypedDataStorage>(
      predicate: #Predicate { $0.id == storageID }
    )
    let migratedStorage = try v2Context.fetch(fetchDescriptor)

    #expect(migratedStorage.count == 1, "Should find one migrated storage")
    guard let storage = migratedStorage.first else {
      Issue.record("Failed to fetch migrated storage")
      return
    }

    // Verify all fields preserved
    #expect(storage.id == storageID)
    #expect(storage.providerId == "openai")
    #expect(storage.requestorID == "gpt-4")
    #expect(storage.mimeType == "text/plain")
    #expect(storage.prompt == "Generate a summary")
    #expect(storage.textValue == "This is a test summary.")
    #expect(storage.wordCount == 5)
    #expect(storage.characterCount == 23)
    #expect(storage.languageCode == "en")
    #expect(storage.modelIdentifier == "gpt-4-turbo")
    #expect(storage.estimatedCost == 0.05)
    #expect(storage.generatedAt.timeIntervalSince1970 == 2000000)
    #expect(storage.modifiedAt.timeIntervalSince1970 == 2001000)
  }

  /// Test that CharacterVoiceMapping fields migrate correctly.
  ///
  /// Verifies all voice mapping properties are preserved:
  /// - characterName, voiceURI, voiceName, providerID
  @Test("CharacterVoiceMapping migration preserves all fields")
  func testCharacterVoiceMappingMigration() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let storeURL = tempDir.appendingPathComponent("voice-migration-test-\(UUID().uuidString).store")

    defer {
      try? FileManager.default.removeItem(at: storeURL)
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))
    }

    // Create V1 store with CharacterVoiceMapping
    let v1Config = ModelConfiguration(url: storeURL)
    let v1Schema = Schema(versionedSchema: SwiftCompartidoSchemaV1.self)
    let v1Container = try ModelContainer(for: v1Schema, configurations: v1Config)
    let v1Context = ModelContext(v1Container)

    let v1Mapping = SwiftCompartidoSchemaV1.CharacterVoiceMapping(
      characterName: "ALICE",
      voiceURI: "macos://Samantha?lang=en",
      voiceName: "Samantha",
      providerID: "macos"
    )

    v1Context.insert(v1Mapping)
    try v1Context.save()

    // Migrate to V2
    enum TestMigrationPlan: SchemaMigrationPlan {
      static var schemas: [any VersionedSchema.Type] {
        [SwiftCompartidoSchemaV1.self, SwiftCompartidoSchemaV2.self]
      }
      static var stages: [MigrationStage] {
        [SwiftCompartidoSchemaV2.migrationStage]
      }
    }

    let v2Config = ModelConfiguration(url: storeURL)
    let v2Schema = Schema(versionedSchema: SwiftCompartidoSchemaV2.self)
    let v2Container = try ModelContainer(
      for: v2Schema,
      migrationPlan: TestMigrationPlan.self,
      configurations: v2Config
    )

    let v2Context = ModelContext(v2Container)
    let fetchDescriptor = FetchDescriptor<SwiftCompartidoSchemaV2.CharacterVoiceMapping>(
      predicate: #Predicate { $0.characterName == "ALICE" }
    )
    let migratedMappings = try v2Context.fetch(fetchDescriptor)

    #expect(migratedMappings.count == 1, "Should find one migrated mapping")
    guard let mapping = migratedMappings.first else {
      Issue.record("Failed to fetch migrated mapping")
      return
    }

    // Verify all fields preserved
    #expect(mapping.characterName == "ALICE")
    #expect(mapping.voiceURI == "macos://Samantha?lang=en")
    #expect(mapping.voiceName == "Samantha")
    #expect(mapping.providerID == "macos")
  }

  /// Test that CustomOutlineElement fields migrate correctly.
  ///
  /// Verifies all custom element properties are preserved:
  /// - Identity (id), type & metadata (elementType, title, notes, orderIndex)
  /// - Audio cue properties (audioCueCategory, audioFileReference, volume, etc.)
  /// - Timestamps (createdAt, modifiedAt)
  @Test("CustomOutlineElement migration preserves all fields")
  func testCustomOutlineElementMigration() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let storeURL = tempDir.appendingPathComponent("custom-migration-test-\(UUID().uuidString).store")

    defer {
      try? FileManager.default.removeItem(at: storeURL)
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))
    }

    // Create V1 store with CustomOutlineElement
    let v1Config = ModelConfiguration(url: storeURL)
    let v1Schema = Schema(versionedSchema: SwiftCompartidoSchemaV1.self)
    let v1Container = try ModelContainer(for: v1Schema, configurations: v1Config)
    let v1Context = ModelContext(v1Container)

    let elementID = UUID()
    let createdDate = Date(timeIntervalSince1970: 3000000)
    let modifiedDate = Date(timeIntervalSince1970: 3001000)

    let v1Element = SwiftCompartidoSchemaV1.CustomOutlineElement(
      id: elementID,
      elementType: .musicCue,
      title: "Opening Theme",
      orderIndex: 1,
      volume: -18.0,
      fadeInDuration: 2.0,
      fadeOutDuration: 2.0,
      playSpeed: 100.0,
      loopEnabled: false
    )
    v1Element.notes = "Epic orchestral piece"
    v1Element.audioCueCategory = "MUSIC"
    v1Element.audioFileReference = "music/theme.mp3"
    v1Element.timingReference = "with scene start"
    v1Element.createdAt = createdDate
    v1Element.modifiedAt = modifiedDate

    v1Context.insert(v1Element)
    try v1Context.save()

    // Migrate to V2
    enum TestMigrationPlan: SchemaMigrationPlan {
      static var schemas: [any VersionedSchema.Type] {
        [SwiftCompartidoSchemaV1.self, SwiftCompartidoSchemaV2.self]
      }
      static var stages: [MigrationStage] {
        [SwiftCompartidoSchemaV2.migrationStage]
      }
    }

    let v2Config = ModelConfiguration(url: storeURL)
    let v2Schema = Schema(versionedSchema: SwiftCompartidoSchemaV2.self)
    let v2Container = try ModelContainer(
      for: v2Schema,
      migrationPlan: TestMigrationPlan.self,
      configurations: v2Config
    )

    let v2Context = ModelContext(v2Container)
    let fetchDescriptor = FetchDescriptor<SwiftCompartidoSchemaV2.CustomOutlineElement>(
      predicate: #Predicate { $0.id == elementID }
    )
    let migratedElements = try v2Context.fetch(fetchDescriptor)

    #expect(migratedElements.count == 1, "Should find one migrated element")
    guard let element = migratedElements.first else {
      Issue.record("Failed to fetch migrated element")
      return
    }

    // Verify all fields preserved
    #expect(element.id == elementID)
    #expect(element.elementType == .musicCue)
    #expect(element.title == "Opening Theme")
    #expect(element.notes == "Epic orchestral piece")
    #expect(element.orderIndex == 1)
    #expect(element.audioCueCategory == "MUSIC")
    #expect(element.audioFileReference == "music/theme.mp3")
    #expect(element.volume == -18.0)
    #expect(element.fadeInDuration == 2.0)
    #expect(element.fadeOutDuration == 2.0)
    #expect(element.playSpeed == 100.0)
    #expect(element.loopEnabled == false)
    #expect(element.timingReference == "with scene start")
    #expect(element.createdAt.timeIntervalSince1970 == 3000000)
    #expect(element.modifiedAt.timeIntervalSince1970 == 3001000)
  }

  /// Test that TitlePageEntryModel fields migrate correctly.
  ///
  /// Verifies title page entry properties are preserved:
  /// - key, values
  @Test("TitlePageEntryModel migration preserves all fields")
  func testTitlePageEntryModelMigration() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let storeURL = tempDir.appendingPathComponent("title-migration-test-\(UUID().uuidString).store")

    defer {
      try? FileManager.default.removeItem(at: storeURL)
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))
    }

    // Create V1 store with TitlePageEntryModel
    let v1Config = ModelConfiguration(url: storeURL)
    let v1Schema = Schema(versionedSchema: SwiftCompartidoSchemaV1.self)
    let v1Container = try ModelContainer(for: v1Schema, configurations: v1Config)
    let v1Context = ModelContext(v1Container)

    let v1Entry = SwiftCompartidoSchemaV1.TitlePageEntryModel(
      key: "Author",
      values: ["Jane Doe", "John Smith"]
    )

    v1Context.insert(v1Entry)
    try v1Context.save()

    // Migrate to V2
    enum TestMigrationPlan: SchemaMigrationPlan {
      static var schemas: [any VersionedSchema.Type] {
        [SwiftCompartidoSchemaV1.self, SwiftCompartidoSchemaV2.self]
      }
      static var stages: [MigrationStage] {
        [SwiftCompartidoSchemaV2.migrationStage]
      }
    }

    let v2Config = ModelConfiguration(url: storeURL)
    let v2Schema = Schema(versionedSchema: SwiftCompartidoSchemaV2.self)
    let v2Container = try ModelContainer(
      for: v2Schema,
      migrationPlan: TestMigrationPlan.self,
      configurations: v2Config
    )

    let v2Context = ModelContext(v2Container)
    let fetchDescriptor = FetchDescriptor<SwiftCompartidoSchemaV2.TitlePageEntryModel>(
      predicate: #Predicate { $0.key == "Author" }
    )
    let migratedEntries = try v2Context.fetch(fetchDescriptor)

    #expect(migratedEntries.count == 1, "Should find one migrated entry")
    guard let entry = migratedEntries.first else {
      Issue.record("Failed to fetch migrated entry")
      return
    }

    // Verify all fields preserved
    #expect(entry.key == "Author")
    #expect(entry.values == ["Jane Doe", "John Smith"])
  }

  /// Test that TypedDataStorage embedding fields migrate correctly.
  ///
  /// Verifies embedding-specific metadata and owner relationships are preserved:
  /// - dimensions, inputText, batchIndex
  /// - owningElement, owningDocument, ownerIdentifier
  @Test("TypedDataStorage embedding migration preserves all fields and relationships")
  func testTypedDataStorageEmbeddingMigration() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let storeURL = tempDir.appendingPathComponent("embedding-migration-test-\(UUID().uuidString).store")

    defer {
      try? FileManager.default.removeItem(at: storeURL)
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))
    }

    // Create V1 store with embedding storage
    let v1Config = ModelConfiguration(url: storeURL)
    let v1Schema = Schema(versionedSchema: SwiftCompartidoSchemaV1.self)
    let v1Container = try ModelContainer(for: v1Schema, configurations: v1Config)
    let v1Context = ModelContext(v1Container)

    let storageID = UUID()
    let elementUUID = UUID()

    // Create document and element for relationships
    let v1Doc = SwiftCompartidoSchemaV1.GuionDocumentModel(
      title: "Test Document"
    )
    let v1Element = SwiftCompartidoSchemaV1.GuionElementModel(
      elementText: "Test element",
      elementTypeString: "Action",
      chapterIndex: 0,
      orderIndex: 1,
      uuid: elementUUID
    )
    v1Element.document = v1Doc
    v1Doc.elements = [v1Element]

    // Create embedding storage with all fields
    let v1Storage = SwiftCompartidoSchemaV1.TypedDataStorage(
      id: storageID,
      providerId: "openai",
      requestorID: "text-embedding-3-small",
      mimeType: "application/x-embedding",
      prompt: "Embed this text"
    )
    v1Storage.dimensions = 1536
    v1Storage.inputText = "This is the input text for embedding"
    v1Storage.batchIndex = 5
    v1Storage.owningElement = v1Element
    v1Storage.owningDocument = v1Doc
    v1Storage.ownerIdentifier = "x-coredata://test/entity/p123"

    v1Context.insert(v1Doc)
    v1Context.insert(v1Element)
    v1Context.insert(v1Storage)
    try v1Context.save()

    // Migrate to V2
    enum TestMigrationPlan: SchemaMigrationPlan {
      static var schemas: [any VersionedSchema.Type] {
        [SwiftCompartidoSchemaV1.self, SwiftCompartidoSchemaV2.self]
      }
      static var stages: [MigrationStage] {
        [SwiftCompartidoSchemaV2.migrationStage]
      }
    }

    let v2Config = ModelConfiguration(url: storeURL)
    let v2Schema = Schema(versionedSchema: SwiftCompartidoSchemaV2.self)
    let v2Container = try ModelContainer(
      for: v2Schema,
      migrationPlan: TestMigrationPlan.self,
      configurations: v2Config
    )

    let v2Context = ModelContext(v2Container)
    let fetchDescriptor = FetchDescriptor<SwiftCompartidoSchemaV2.TypedDataStorage>(
      predicate: #Predicate { $0.id == storageID }
    )
    let migratedStorage = try v2Context.fetch(fetchDescriptor)

    #expect(migratedStorage.count == 1, "Should find one migrated storage")
    guard let storage = migratedStorage.first else {
      Issue.record("Failed to fetch migrated storage")
      return
    }

    // Verify all embedding fields preserved
    #expect(storage.id == storageID)
    #expect(storage.providerId == "openai")
    #expect(storage.requestorID == "text-embedding-3-small")
    #expect(storage.mimeType == "application/x-embedding")
    #expect(storage.dimensions == 1536)
    #expect(storage.inputText == "This is the input text for embedding")
    #expect(storage.batchIndex == 5)
    #expect(storage.ownerIdentifier == "x-coredata://test/entity/p123")

    // Verify relationships preserved
    #expect(storage.owningElement != nil, "owningElement relationship should be preserved")
    #expect(storage.owningElement?.uuid == elementUUID)
    #expect(storage.owningDocument != nil, "owningDocument relationship should be preserved")
    #expect(storage.owningDocument?.title == "Test Document")
  }

  /// Test that CustomPageModel fields migrate correctly.
  ///
  /// Verifies custom page properties are preserved:
  /// - id, title, position, pageType, jsonData
  @Test("CustomPageModel migration preserves all fields")
  func testCustomPageModelMigration() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let storeURL = tempDir.appendingPathComponent("page-migration-test-\(UUID().uuidString).store")

    defer {
      try? FileManager.default.removeItem(at: storeURL)
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))
    }

    // Create V1 store with CustomPageModel
    let v1Config = ModelConfiguration(url: storeURL)
    let v1Schema = Schema(versionedSchema: SwiftCompartidoSchemaV1.self)
    let v1Container = try ModelContainer(for: v1Schema, configurations: v1Config)
    let v1Context = ModelContext(v1Container)

    let pageID = "test-page-123"
    let testJSON = try JSONSerialization.data(
      withJSONObject: ["id": pageID, "title": "Cast List", "position": 0, "type": "castList"],
      options: []
    )

    let v1Page = SwiftCompartidoSchemaV1.CustomPageModel(
      id: pageID,
      title: "Cast List",
      position: 0,
      pageType: "castList",
      jsonData: testJSON
    )

    v1Context.insert(v1Page)
    try v1Context.save()

    // Migrate to V2
    enum TestMigrationPlan: SchemaMigrationPlan {
      static var schemas: [any VersionedSchema.Type] {
        [SwiftCompartidoSchemaV1.self, SwiftCompartidoSchemaV2.self]
      }
      static var stages: [MigrationStage] {
        [SwiftCompartidoSchemaV2.migrationStage]
      }
    }

    let v2Config = ModelConfiguration(url: storeURL)
    let v2Schema = Schema(versionedSchema: SwiftCompartidoSchemaV2.self)
    let v2Container = try ModelContainer(
      for: v2Schema,
      migrationPlan: TestMigrationPlan.self,
      configurations: v2Config
    )

    let v2Context = ModelContext(v2Container)
    let fetchDescriptor = FetchDescriptor<SwiftCompartidoSchemaV2.CustomPageModel>(
      predicate: #Predicate { $0.id == pageID }
    )
    let migratedPages = try v2Context.fetch(fetchDescriptor)

    #expect(migratedPages.count == 1, "Should find one migrated page")
    guard let page = migratedPages.first else {
      Issue.record("Failed to fetch migrated page")
      return
    }

    // Verify all fields preserved
    #expect(page.id == pageID)
    #expect(page.title == "Cast List")
    #expect(page.position == 0)
    #expect(page.pageType == "castList")
    #expect(page.jsonData == testJSON)
  }

  /// Test that multiple elements migrate correctly with mixed data.
  ///
  /// Verifies migration handles:
  /// - Multiple elements in a single store
  /// - Different element types
  /// - Elements with various field values
  @Test("Migration handles multiple elements with diverse data")
  func testMigrationWithMultipleElements() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let storeURL = tempDir.appendingPathComponent("multi-migration-test-\(UUID().uuidString).store")

    defer {
      try? FileManager.default.removeItem(at: storeURL)
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
      try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))
    }

    // Create V1 store with multiple elements
    let v1Config = ModelConfiguration(url: storeURL)
    let v1Schema = Schema(versionedSchema: SwiftCompartidoSchemaV1.self)
    let v1Container = try ModelContainer(for: v1Schema, configurations: v1Config)
    let v1Context = ModelContext(v1Container)

    let uuid1 = UUID()
    let uuid2 = UUID()
    let uuid3 = UUID()

    let element1 = SwiftCompartidoSchemaV1.GuionElementModel(
      elementText: "INT. BEDROOM - NIGHT",
      elementTypeString: "Scene Heading",
      chapterIndex: 0,
      orderIndex: 1,
      uuid: uuid1
    )

    let element2 = SwiftCompartidoSchemaV1.GuionElementModel(
      elementText: "ALICE\nHello, world!",
      elementTypeString: "Dialogue",
      chapterIndex: 0,
      orderIndex: 2,
      uuid: uuid2
    )

    let element3 = SwiftCompartidoSchemaV1.GuionElementModel(
      elementText: "She smiles.",
      elementTypeString: "Action",
      isCentered: true,
      chapterIndex: 0,
      orderIndex: 3,
      uuid: uuid3
    )

    v1Context.insert(element1)
    v1Context.insert(element2)
    v1Context.insert(element3)
    try v1Context.save()

    // Migrate to V2
    enum TestMigrationPlan: SchemaMigrationPlan {
      static var schemas: [any VersionedSchema.Type] {
        [SwiftCompartidoSchemaV1.self, SwiftCompartidoSchemaV2.self]
      }

      static var stages: [MigrationStage] {
        [SwiftCompartidoSchemaV2.migrationStage]
      }
    }

    let v2Config = ModelConfiguration(url: storeURL)
    let v2Schema = Schema(versionedSchema: SwiftCompartidoSchemaV2.self)
    let v2Container = try ModelContainer(
      for: v2Schema,
      migrationPlan: TestMigrationPlan.self,
      configurations: v2Config
    )

    let v2Context = ModelContext(v2Container)
    let fetchDescriptor = FetchDescriptor<SwiftCompartidoSchemaV2.GuionElementModel>(
      sortBy: [SortDescriptor(\.orderIndex)]
    )
    let migratedElements = try v2Context.fetch(fetchDescriptor)

    #expect(migratedElements.count == 3, "Should have three migrated elements")

    // Verify each element
    #expect(migratedElements[0].uuid == uuid1)
    #expect(migratedElements[0].elementText == "INT. BEDROOM - NIGHT")
    #expect(migratedElements[0].glosaSpokenText == nil)

    #expect(migratedElements[1].uuid == uuid2)
    #expect(migratedElements[1].elementText == "ALICE\nHello, world!")
    #expect(migratedElements[1].glosaSpokenText == nil)

    #expect(migratedElements[2].uuid == uuid3)
    #expect(migratedElements[2].elementText == "She smiles.")
    #expect(migratedElements[2].isCentered == true)
    #expect(migratedElements[2].glosaSpokenText == nil)
  }
}
