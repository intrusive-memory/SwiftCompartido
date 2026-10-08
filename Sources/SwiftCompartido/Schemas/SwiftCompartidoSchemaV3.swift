//
//  SwiftCompartidoSchemaV3.swift
//  SwiftCompartido
//
//  Schema version 3 — Complete production model snapshot with the speaker field
//
//  CRITICAL: This schema must mirror ALL stored properties from production models
//  to prevent data loss during migration. See "Critical: Complete Model Mirroring"
//  in ``SwiftCompartidoSchemaV2``.
//

import Foundation
@preconcurrency import SwiftData

/// SwiftData schema version 3 (complete snapshot with the `speaker` field).
///
/// ## Purpose
///
/// This schema captures the **complete shape** of SwiftCompartido models after
/// adding a stored `speaker` field to `GuionElementModel` (requirement CP-P1).
/// The speaker field lets a SwiftData predicate select a character's lines
/// directly, instead of walking back to the nearest character cue.
///
/// ## Critical: Complete Model Mirroring
///
/// As with V1 and V2, every model here mirrors **every stored property** of its
/// production counterpart. Undeclared fields are dropped during migration.
/// See ``SwiftCompartidoSchemaV2`` for the full explanation and history.
///
/// ## Models Included
///
/// - ``GuionElementModel`` - ~31 stored properties (includes 5 glosa fields and `speaker`)
/// - ``GuionDocumentModel`` - ~7 properties + 5 relationships
/// - ``TypedDataStorage`` - ~35 properties + 1 relationship
/// - ``CharacterVoiceMapping`` - 4 properties + 1 relationship
/// - ``CustomOutlineElement`` - ~20 properties + 2 relationships
/// - ``TitlePageEntryModel`` - 2 properties + 1 relationship
/// - ``CustomPageModel`` - 5 properties + 1 relationship
///
/// ## Changes from V2
///
/// The V2 → V3 migration adds **one optional field** to `GuionElementModel`:
/// - `speaker: String?` - Cleaned speaker name (cue with extensions such as
///   `(V.O.)` and `(CONT'D)` removed) on dialogue and parenthetical elements.
///
/// No other model changes.
///
/// ## Null Speaker Values Are Expected for Migrated Data
///
/// This is an **intentional design choice**. The V2 → V3 migration is
/// lightweight and does **not** backfill `speaker`:
///
/// - Every `GuionElementModel` record that existed before the migration will
///   have `speaker == nil` afterwards, including dialogue and parentheticals.
/// - Only content parsed after adopting V3 populates the field.
/// - Character data derived from `speaker` (counts, scenes, first lines) will be
///   incomplete for documents that were parsed under V1 or V2.
///
/// Callers that need complete speaker data for older documents should re-parse
/// them (for example, from `GuionDocumentModel.rawContent` or the source file).
/// `nil` on a non-dialogue element (action, scene heading, etc.) is also the
/// normal, permanent state.
///
/// ## Migration from V2
///
/// The V2 → V3 migration is **lightweight**: `speaker` is optional and defaults
/// to `nil`, so existing data migrates without transformation.
///
/// ## Usage
///
/// Consumer apps that adopt this version must include V1, V2 and V3 in their
/// `SchemaMigrationPlan.schemas` array and reference both migration stages:
///
/// ```swift
/// enum MyAppMigrationPlan: SchemaMigrationPlan {
///   static var schemas: [any VersionedSchema.Type] {
///     [SwiftCompartidoSchemaV1.self, SwiftCompartidoSchemaV2.self, SwiftCompartidoSchemaV3.self]
///   }
///
///   static var stages: [MigrationStage] {
///     [SwiftCompartidoSchemaV2.migrationStage, SwiftCompartidoSchemaV3.migrationStage]
///   }
/// }
/// ```
///
/// - SeeAlso: ``SwiftCompartidoSchemaV2``, ``SwiftCompartidoSchemaV1``
public enum SwiftCompartidoSchemaV3: VersionedSchema {
  public static let versionIdentifier: Schema.Version = .init(3, 0, 0)

  public static let models: [any PersistentModel.Type] = [
    GuionElementModel.self, GuionDocumentModel.self, TypedDataStorage.self,
    CharacterVoiceMapping.self, CustomOutlineElement.self,
    TitlePageEntryModel.self, CustomPageModel.self,
  ]

  /// Lightweight migration stage from V2 → V3.
  ///
  /// Adds one optional field to `GuionElementModel`:
  /// - `speaker`
  ///
  /// The field defaults to `nil` and is **not** backfilled. Records migrated
  /// from V2 keep `speaker == nil`; only newly parsed content populates it.
  public static let migrationStage: MigrationStage =
    MigrationStage.lightweight(
      fromVersion: SwiftCompartidoSchemaV2.self,
      toVersion: SwiftCompartidoSchemaV3.self
    )

  /// V3 shape of GuionElementModel (glosa fields plus `speaker`).
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

    // MARK: - Speaker (NEW in V3)

    /// Cleaned speaker name for dialogue and parenthetical elements.
    ///
    /// `nil` for non-dialogue elements, and `nil` for **every** record migrated
    /// from V2 (no backfill — intentional). Only newly parsed content sets it.
    public var speaker: String? = nil

    public init(
      elementText: String, elementTypeString: String, isCentered: Bool = false,
      isDualDialogue: Bool = false, sceneNumber: String? = nil, sectionDepth: Int = 0,
      summary: String? = nil, sceneId: String? = nil, chapterIndex: Int = 0, orderIndex: Int = 0,
      speaker: String? = nil, uuid: UUID = UUID()
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
      self.speaker = speaker
    }
  }

  // Related models — complete mirrors of production, unchanged from V2

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

    // Recent Items Tracking
    public var lastOpenedDate: Date?

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
