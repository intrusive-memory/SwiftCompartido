//
//  SwiftCompartidoSchemaV1.swift
//  SwiftCompartido
//
//  Schema version 1 (baseline) — Complete production model snapshot before glosa fields
//
//  CRITICAL: This schema must mirror ALL stored properties from production models
//  to prevent data loss during migration. See SwiftCompartidoSchemaV2.swift for details.
//

import Foundation
@preconcurrency import SwiftData

/// SwiftData schema version 1 (baseline snapshot before glosa integration).
///
/// ## Purpose
///
/// This schema captures the **complete shape** of SwiftCompartido models as they existed
/// before the addition of glosa annotation fields in v7.0.5. It serves as the migration
/// baseline for V1 → V2 lightweight migration.
///
/// ## Critical: Complete Model Mirroring
///
/// **IMPORTANT**: All versioned schema models MUST mirror **every stored property** from
/// their production counterparts. Missing fields cause **data loss** during migration because:
///
/// 1. SwiftData creates the target schema with only declared fields
/// 2. Migration copies only declared fields from source
/// 3. **Undeclared fields are dropped as "not in schema"**
///
/// ## Models Included
///
/// This schema includes complete definitions for:
/// - ``GuionElementModel`` - ~25 stored properties (no glosa fields)
/// - ``GuionDocumentModel`` - ~7 properties + 5 relationships
/// - ``TypedDataStorage`` - ~35 properties + 1 relationship
/// - ``CharacterVoiceMapping`` - 4 properties + 1 relationship
/// - ``CustomOutlineElement`` - ~20 properties + 2 relationships
/// - ``TitlePageEntryModel`` - 2 properties + 1 relationship
/// - ``CustomPageModel`` - 5 properties + 1 relationship
///
/// ## Computed Properties
///
/// Computed properties (e.g., `sortedElements`, `binaryValue`) are NOT included in
/// versioned schemas because:
/// - They are not stored in the database
/// - They have no migration impact
/// - Including them causes SwiftData schema conflicts
///
/// This schema captures the shape of SwiftCompartido models before adding
/// glosa annotation fields in v7.0.5. It serves as the migration baseline
/// for the V1 → V2 lightweight migration that adds optional glosa storage.
///
/// ## Migration Path
///
/// V1 (this schema) → V2 (``SwiftCompartidoSchemaV2``) via lightweight migration.
/// The migration adds five optional fields to `GuionElementModel` with no data
/// transformation required (all new fields default to `nil`).
///
/// ## Usage
///
/// Consumer apps that adopt SwiftCompartido v7.0.5+ must include both V1 and V2
/// in their `SchemaMigrationPlan.schemas` array:
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
///
/// - SeeAlso: ``SwiftCompartidoSchemaV2``
public enum SwiftCompartidoSchemaV1: VersionedSchema {
  public static let versionIdentifier: Schema.Version = .init(1, 0, 0)

  public static let models: [any PersistentModel.Type] = [
    GuionElementModel.self, GuionDocumentModel.self, TypedDataStorage.self,
    CharacterVoiceMapping.self, CustomOutlineElement.self,
    TitlePageEntryModel.self, CustomPageModel.self
  ]

  /// V1 shape of GuionElementModel (no glosa fields).
  ///
  /// This mirrors the model shape from SwiftCompartido v7.0.4 and earlier,
  /// before the addition of glosa annotation storage in v7.0.5.
  @Model
  public final class GuionElementModel {
    @Attribute(.unique) public var uuid: UUID
    public var chapterIndex: Int
    public var orderIndex: Int
    public var elementText: String
    private var _elementTypeString: String
    public var isCentered: Bool
    public var isDualDialogue: Bool
    public var sceneNumber: String?
    private var _sectionDepth: Int
    public var sceneId: String?
    public var summary: String?

    @Relationship(deleteRule: .nullify)
    public var document: GuionDocumentModel?

    @Relationship(deleteRule: .cascade)
    public var generatedContent: [TypedDataStorage]?

    @Relationship(deleteRule: .cascade)
    public var customElements: [CustomOutlineElement]?

    // Cached scene location fields
    public var locationLighting: String?
    public var locationScene: String?
    public var locationSetup: String?
    public var locationTimeOfDay: String?
    public var locationModifiers: [String]?

    // Pre-computed formatted text (NEW in 5.4.0)
    private var formattedTextData: Data?

    public init(
      elementText: String, elementTypeString: String, isCentered: Bool = false,
      isDualDialogue: Bool = false, sceneNumber: String? = nil, sectionDepth: Int = 0,
      summary: String? = nil, sceneId: String? = nil, chapterIndex: Int = 0, orderIndex: Int = 0,
      uuid: UUID = UUID()
    ) {
      self.uuid = uuid
      self.chapterIndex = chapterIndex
      self.orderIndex = orderIndex
      self.elementText = elementText
      self._elementTypeString = elementTypeString
      self.isCentered = isCentered
      self.isDualDialogue = isDualDialogue
      self.sceneNumber = sceneNumber
      self._sectionDepth = sectionDepth
      self.summary = summary
      self.sceneId = sceneId
    }
  }

  // Placeholder types for related models (minimal definitions for schema only)

  @Model
  public final class GuionDocumentModel {
    @Attribute(.unique) public var uuid: UUID

    // Document Properties
    public var filename: String?
    public var rawContent: String?
    public var suppressSceneNumbers: Bool
    public var title: String?

    // Source File Tracking
    public var sourceFileBookmark: Data?
    public var lastImportDate: Date?
    public var sourceFileModificationDate: Date?

    // Relationships
    @Relationship(deleteRule: .cascade) public var elements: [GuionElementModel]?
    @Relationship(deleteRule: .cascade) public var titlePage: [TitlePageEntryModel]?
    @Relationship(deleteRule: .cascade) public var customPages: [CustomPageModel]?
    @Relationship(deleteRule: .cascade) public var generatedContent: [TypedDataStorage]?
    @Relationship(deleteRule: .cascade) public var casting: [CharacterVoiceMapping]?

    public init(
      uuid: UUID = UUID(),
      filename: String? = nil,
      rawContent: String? = nil,
      suppressSceneNumbers: Bool = false,
      title: String? = nil
    ) {
      self.uuid = uuid
      self.filename = filename
      self.rawContent = rawContent
      self.suppressSceneNumbers = suppressSceneNumbers
      self.title = title
    }
  }

  @Model
  public final class TypedDataStorage {
    // Identity
    @Attribute(.unique) public var id: UUID
    public var providerId: String
    public var requestorID: String

    // Content Storage
    public var textValue: String?
    @Attribute(.externalStorage) private var _compressedBinaryValue: Data?
    public var mimeType: String

    // Common Metadata
    public var prompt: String
    public var modelIdentifier: String?
    public var estimatedCost: Double?
    @Attribute(.externalStorage) public var fileReference: TypedDataFileReference?

    // Text-specific Metadata
    public var wordCount: Int?
    public var characterCount: Int?
    public var languageCode: String?
    public var tokenCount: Int?
    public var completionTokens: Int?
    public var promptTokens: Int?

    // Audio-specific Metadata
    public var audioFormat: String?
    public var durationSeconds: Double?
    public var sampleRate: Int?
    public var bitRate: Int?
    public var channels: Int?
    public var voiceID: String?
    public var voiceName: String?

    // Image-specific Metadata
    public var imageFormat: String?
    public var width: Int?
    public var height: Int?
    public var revisedPrompt: String?

    // Embedding-specific Metadata
    public var dimensions: Int?

    // Timestamps
    public var generatedAt: Date
    public var modifiedAt: Date

    // Owner Reference
    @Relationship(deleteRule: .nullify) public var element: GuionElementModel?

    public init(
      id: UUID = UUID(),
      providerId: String = "",
      requestorID: String = "",
      mimeType: String = "application/octet-stream",
      prompt: String = ""
    ) {
      self.id = id
      self.providerId = providerId
      self.requestorID = requestorID
      self.mimeType = mimeType
      self.prompt = prompt
      self.generatedAt = Date()
      self.modifiedAt = Date()
    }
  }

  @Model
  public final class CharacterVoiceMapping {
    @Attribute(.unique) public var uuid: UUID
    public var characterName: String
    public var voiceURI: String
    public var voiceName: String
    public var providerID: String

    @Relationship(deleteRule: .nullify) public var document: GuionDocumentModel?

    public init(
      uuid: UUID = UUID(),
      characterName: String = "",
      voiceURI: String = "",
      voiceName: String = "",
      providerID: String = ""
    ) {
      self.uuid = uuid
      self.characterName = characterName
      self.voiceURI = voiceURI
      self.voiceName = voiceName
      self.providerID = providerID
    }
  }

  @Model
  public final class CustomOutlineElement {
    // Identity
    @Attribute(.unique) public var id: UUID

    // Type & Metadata
    public var elementType: CustomElementType
    public var title: String
    public var notes: String?
    public var orderIndex: Int

    // Audio Cue Properties
    public var audioCueCategory: String?
    public var audioFileReference: String?
    public var volume: Float
    public var fadeInDuration: TimeInterval
    public var fadeOutDuration: TimeInterval
    public var playSpeed: Float
    public var loopEnabled: Bool
    public var cueDuration: TimeInterval?
    public var timingReference: String?

    // Timestamps
    public var createdAt: Date
    public var modifiedAt: Date

    // Relationships
    @Relationship(inverse: \GuionElementModel.customElements)
    public var parentElement: GuionElementModel?

    @Relationship(deleteRule: .cascade)
    public var attachedMedia: [TypedDataStorage]?

    public init(
      id: UUID = UUID(),
      elementType: CustomElementType = .genericMedia,
      title: String = "",
      orderIndex: Int = 0,
      volume: Float = 0.0,
      fadeInDuration: TimeInterval = 0.0,
      fadeOutDuration: TimeInterval = 0.0,
      playSpeed: Float = 100.0,
      loopEnabled: Bool = false
    ) {
      self.id = id
      self.elementType = elementType
      self.title = title
      self.orderIndex = orderIndex
      self.volume = volume
      self.fadeInDuration = fadeInDuration
      self.fadeOutDuration = fadeOutDuration
      self.playSpeed = playSpeed
      self.loopEnabled = loopEnabled
      self.createdAt = Date()
      self.modifiedAt = Date()
    }
  }

  @Model
  public final class TitlePageEntryModel {
    public var key: String
    public var values: [String]
    @Relationship(deleteRule: .nullify) public var document: GuionDocumentModel?

    public init(key: String = "", values: [String] = []) {
      self.key = key
      self.values = values
    }
  }

  @Model
  public final class CustomPageModel {
    public var id: String
    public var title: String
    public var position: Int
    public var pageType: String
    public var jsonData: Data

    @Relationship(deleteRule: .nullify) public var document: GuionDocumentModel?

    public init(
      id: String = "",
      title: String = "",
      position: Int = 0,
      pageType: String = "",
      jsonData: Data = Data()
    ) {
      self.id = id
      self.title = title
      self.position = position
      self.pageType = pageType
      self.jsonData = jsonData
    }
  }
}
