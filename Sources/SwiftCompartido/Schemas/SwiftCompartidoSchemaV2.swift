//
//  SwiftCompartidoSchemaV2.swift
//  SwiftCompartido
//
//  Schema version 2 — Complete production model snapshot with glosa annotation fields
//
//  CRITICAL: This schema must mirror ALL stored properties from production models
//  to prevent data loss during migration. See "Critical: Complete Model Mirroring" below.
//

import Foundation
@preconcurrency import SwiftData

/// SwiftData schema version 2 (complete snapshot with glosa integration).
///
/// ## Purpose
///
/// This schema captures the **complete shape** of SwiftCompartido models as they exist
/// in v7.0.5+, including glosa annotation fields added to `GuionElementModel`.
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
/// ### Example of Data Loss Bug (FIXED)
///
/// **Before fix** (placeholder models):
/// ```swift
/// // V1 Schema (WRONG - only uuid field)
/// @Model
/// public final class GuionDocumentModel {
///   @Attribute(.unique) public var uuid: UUID
///   public init(uuid: UUID = UUID()) { self.uuid = uuid }
/// }
/// ```
///
/// **Migration result**: All document properties (filename, rawContent, title, titlePage,
/// customPages, generatedContent, casting) **dropped** from database. Total data loss.
///
/// **After fix** (complete models):
/// ```swift
/// // V1 Schema (CORRECT - all 7 properties + 5 relationships)
/// @Model
/// public final class GuionDocumentModel {
///   @Attribute(.unique) public var uuid: UUID
///   public var filename: String?
///   public var rawContent: String?
///   public var suppressSceneNumbers: Bool
///   public var title: String?
///   public var sourceFileBookmark: Data?
///   public var lastImportDate: Date?
///   public var sourceFileModificationDate: Date?
///   @Relationship(deleteRule: .cascade) public var elements: [GuionElementModel]?
///   @Relationship(deleteRule: .cascade) public var titlePage: [TitlePageEntryModel]?
///   @Relationship(deleteRule: .cascade) public var customPages: [CustomPageModel]?
///   @Relationship(deleteRule: .cascade) public var generatedContent: [TypedDataStorage]?
///   @Relationship(deleteRule: .cascade) public var casting: [CharacterVoiceMapping]?
///   // ... init ...
/// }
/// ```
///
/// **Migration result**: All fields preserved. No data loss.
///
/// ## Models Included
///
/// This schema includes complete definitions for:
/// - ``GuionElementModel`` - ~30 stored properties (includes 5 glosa fields)
/// - ``GuionDocumentModel`` - ~7 properties + 5 relationships
/// - ``TypedDataStorage`` - ~35 properties + 1 relationship
/// - ``CharacterVoiceMapping`` - 4 properties + 1 relationship
/// - ``CustomOutlineElement`` - ~20 properties + 2 relationships
/// - ``TitlePageEntryModel`` - 2 properties + 1 relationship
/// - ``CustomPageModel`` - 5 properties + 1 relationship
///
/// ## Changes from V1
///
/// The V1 → V2 migration adds **five optional glosa annotation fields** to `GuionElementModel`:
/// - `glosaSpokenText: String?` - Notes-stripped spoken prose
/// - `glosaBreathOffsets: [Int]?` - Unicode-scalar boundary offsets for breath hints
/// - `glosaBreathStrengths: [String]?` - Raw BreathStrength values
/// - `glosaInstruct: String?` - Composed LLM performance-direction string
/// - `glosaPausePoints: Data?` - Encoded [PausePointDTO] timed-silence seam points
///
/// All new fields default to `nil`, so migration requires no data transformation.
///
/// ## Computed Properties
///
/// Computed properties (e.g., `sortedElements`, `binaryValue`) are NOT included in
/// versioned schemas because:
/// - They are not stored in the database
/// - They have no migration impact
/// - Including them causes SwiftData schema conflicts
///
/// This schema captures the shape of SwiftCompartido models after adding
/// glosa annotation fields in v7.0.5. It extends V1 with five optional fields
/// on `GuionElementModel` for storing compiled glosa annotation data.
///
/// ## Migration from V1
///
/// The V1 → V2 migration is **lightweight** — it adds five optional fields to
/// `GuionElementModel` with no data transformation:
/// - `glosaSpokenText: String?`
/// - `glosaBreathOffsets: [Int]?`
/// - `glosaBreathStrengths: [String]?`
/// - `glosaInstruct: String?`
/// - `glosaPausePoints: Data?`
///
/// All new fields default to `nil`, so existing data migrates without modification.
///
/// ## Usage
///
/// Consumer apps that adopt SwiftCompartido v7.0.5+ must include both V1 and V2
/// in their `SchemaMigrationPlan.schemas` array and reference the migration stage:
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
/// - SeeAlso: ``SwiftCompartidoSchemaV1``
public enum SwiftCompartidoSchemaV2: VersionedSchema {
  public static let versionIdentifier: Schema.Version = .init(2, 0, 0)

  public static let models: [any PersistentModel.Type] = [
    GuionElementModel.self, GuionDocumentModel.self, TypedDataStorage.self,
    CharacterVoiceMapping.self, CustomOutlineElement.self,
    TitlePageEntryModel.self, CustomPageModel.self
  ]

  /// Lightweight migration stage from V1 → V2.
  ///
  /// Adds five optional glosa annotation fields to `GuionElementModel`:
  /// - `glosaSpokenText`
  /// - `glosaBreathOffsets`
  /// - `glosaBreathStrengths`
  /// - `glosaInstruct`
  /// - `glosaPausePoints`
  ///
  /// All new fields default to `nil`, so no data transformation is required.
  public static let migrationStage: MigrationStage =
    MigrationStage.lightweight(
      fromVersion: SwiftCompartidoSchemaV1.self,
      toVersion: SwiftCompartidoSchemaV2.self
    )

  /// V2 shape of GuionElementModel (with glosa fields).
  ///
  /// This mirrors the current model shape from SwiftCompartido v7.0.5+,
  /// including glosa annotation storage fields added for audio integration.
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

    // MARK: - Glosa Annotation Storage (NEW in V2 / 7.0.5)

    /// Notes-stripped spoken prose for this element.
    public var glosaSpokenText: String? = nil

    /// Unicode-scalar boundary offsets in glosaSpokenText where breath hints are located.
    public var glosaBreathOffsets: [Int]? = nil

    /// Raw BreathStrength values parallel to glosaBreathOffsets.
    public var glosaBreathStrengths: [String]? = nil

    /// Composed LLM performance-direction string for this line, if any.
    public var glosaInstruct: String? = nil

    /// Encoded [PausePointDTO] timed-silence seam points for this line.
    public var glosaPausePoints: Data? = nil

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
    public var inputText: String?
    public var batchIndex: Int?

    // Timestamps
    public var generatedAt: Date
    public var modifiedAt: Date

    // Owner References
    @Relationship(deleteRule: .nullify) public var owningElement: GuionElementModel?
    @Relationship(deleteRule: .nullify) public var owningDocument: GuionDocumentModel?
    public var ownerIdentifier: String?

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
