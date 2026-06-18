//
//  SwiftCompartidoSchemaV2.swift
//  SwiftCompartido
//
//  Schema version 2 — GuionElementModel with glosa annotation fields
//

import Foundation
@preconcurrency import SwiftData

/// SwiftData schema version 2 (glosa integration).
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
    CharacterVoiceMapping.self, CustomOutlineElement.self, OutlineItemModel.self
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
    public var title: String?
    @Relationship(deleteRule: .cascade) public var elements: [GuionElementModel]?
    public init(uuid: UUID = UUID()) { self.uuid = uuid }
  }

  @Model
  public final class TypedDataStorage {
    @Attribute(.unique) public var uuid: UUID
    public var elementUUID: UUID?
    public init(uuid: UUID = UUID()) { self.uuid = uuid }
  }

  @Model
  public final class CharacterVoiceMapping {
    @Attribute(.unique) public var uuid: UUID
    public init(uuid: UUID = UUID()) { self.uuid = uuid }
  }

  @Model
  public final class CustomOutlineElement {
    @Attribute(.unique) public var uuid: UUID
    public init(uuid: UUID = UUID()) { self.uuid = uuid }
  }

  @Model
  public final class OutlineItemModel {
    @Attribute(.unique) public var uuid: UUID
    public init(uuid: UUID = UUID()) { self.uuid = uuid }
  }
}
