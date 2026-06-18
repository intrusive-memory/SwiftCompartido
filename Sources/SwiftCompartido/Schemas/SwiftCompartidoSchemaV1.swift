//
//  SwiftCompartidoSchemaV1.swift
//  SwiftCompartido
//
//  Schema version 1 (baseline) — GuionElementModel shape before glosa fields
//

import Foundation
@preconcurrency import SwiftData

/// SwiftData schema version 1 (baseline before glosa integration).
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
    CharacterVoiceMapping.self, CustomOutlineElement.self, OutlineItemModel.self
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
