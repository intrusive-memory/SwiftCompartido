# TODO: Fix SwiftData Schema Versioning Data Loss Bug

## Problem

The current schema versioning implementation (V1/V2) will cause **data loss** for any consumer app that follows the migration guidance. The versioned schemas use placeholder models with only `uuid` fields, but the real production models have many more fields. When SwiftData migrates from V1 to V2, it treats the versioned schema as the target schema, so all fields not declared in the version are **dropped**.

## Impact

**CRITICAL - RELEASE BLOCKER**

Any consumer app that:
1. Has an existing SwiftData store with GuionDocumentModel data
2. Follows the migration guidance in SwiftCompartidoSchemaV1/V2
3. Runs the migration

Will **lose all data** in these fields:
- Document metadata (filename, rawContent, title, etc.)
- Custom pages
- Title page entries  
- Generated content
- Voice casting mappings
- TypedDataStorage metadata (provider, MIME type, all audio/image/text metadata)

## Root Cause

The versioned schemas define placeholder models:

```swift
// Current (BROKEN):
@Model
public final class GuionDocumentModel {
  @Attribute(.unique) public var uuid: UUID
  public var title: String?
  @Relationship(deleteRule: .cascade) public var elements: [GuionElementModel]?
  public init(uuid: UUID = UUID()) { self.uuid = uuid }
}
```

But the real production model has ~15 stored properties and 5 relationships.

SwiftData doesn't know about the missing fields, so during migration it:
1. Creates the V2 schema with only the declared fields
2. Migrates existing data by copying declared fields
3. **Drops all undeclared fields as "not in schema"**

## Scope of Work

### Required Changes

Must mirror **every stored property and relationship** from production models into both V1 and V2 schemas:

#### 1. GuionElementModel ✅ 
**Status**: Already complete (V1 has all fields, V2 adds glosa fields)
- ~25 stored properties
- 3 relationships
- Location caching fields
- Formatted text data

#### 2. GuionDocumentModel ❌
**Current**: 3 properties (uuid, title, elements)
**Required**: ~15 properties + 5 relationships

**Stored Properties to Add**:
- `filename: String?`
- `rawContent: String?`
- `suppressSceneNumbers: Bool`
- `title: String?` (already present)
- `sourceFileBookmark: Data?`
- `lastImportDate: Date?`
- `sourceFileModificationDate: Date?`

**Relationships to Add**:
- `titlePage: [TitlePageEntryModel]` (.cascade)
- `customPages: [CustomPageModel]` (.cascade)
- `generatedContent: [TypedDataStorage]?` (.cascade)
- `casting: [CharacterVoiceMapping]?` (.cascade)
- `elements: [GuionElementModel]` (already present)

**Computed Properties** (NOT stored, no migration impact):
- `sortedElements`
- `sortedCustomPages`

**Estimated Lines**: ~80 lines per version = 160 lines total

---

#### 3. TypedDataStorage ❌
**Current**: 2 properties (uuid, elementUUID)
**Required**: ~35 properties + 1 relationship

**Core Properties to Add**:
- `id: UUID` (unique)
- `providerId: String`
- `requestorID: String`
- `mimeType: String`
- `prompt: String`
- `modelIdentifier: String?`
- `estimatedCost: Double?`

**Storage Properties to Add**:
- `textValue: String?`
- `_compressedBinaryValue: Data?` (.externalStorage)
- `fileReference: TypedDataFileReference?` (.externalStorage)

**Text Metadata**:
- `wordCount: Int?`
- `characterCount: Int?`
- `languageCode: String?`
- `tokenCount: Int?`
- `completionTokens: Int?`
- `promptTokens: Int?`

**Audio Metadata**:
- `audioFormat: String?`
- `durationSeconds: Double?`
- `sampleRate: Int?`
- `bitRate: Int?`
- `channels: Int?`
- `voiceID: String?`
- `voiceName: String?`

**Image Metadata**:
- `imageFormat: String?`
- `width: Int?`
- `height: Int?`
- `revisedPrompt: String?`

**Embedding Metadata**:
- `dimensions: Int?`

**Relationships to Add**:
- `element: GuionElementModel?` (inverse relationship)

**Computed Properties** (NOT stored):
- `binaryValue` (transparent compression wrapper over `_compressedBinaryValue`)

**Estimated Lines**: ~100 lines per version = 200 lines total

---

#### 4. CharacterVoiceMapping ❌
**Current**: 1 property (uuid)
**Required**: 4 properties + 1 relationship

**Properties to Add**:
- `characterName: String`
- `voiceURI: String`
- `voiceName: String`
- `providerID: String`

**Relationships to Add**:
- `document: GuionDocumentModel?` (.nullify)

**Estimated Lines**: ~30 lines per version = 60 lines total

---

#### 5. CustomOutlineElement ❌
**Current**: 1 property (uuid)
**Required**: ~20 properties + 2 relationships

**Properties to Add**:
- `id: UUID` (unique)
- `elementType: CustomElementType`
- `title: String`
- `notes: String?`
- `orderIndex: Int`
- `audioCueCategory: String?`
- `audioFileReference: String?`
- `volume: Float`
- `fadeInDuration: TimeInterval`
- `fadeOutDuration: TimeInterval`
- `playSpeed: Float`
- `loopEnabled: Bool`
- `cueDuration: TimeInterval?`
- `timingReference: String?`
- `createdAt: Date`
- `modifiedAt: Date`

**Relationships to Add**:
- `parentElement: GuionElementModel?` (inverse)
- `attachedMedia: [TypedDataStorage]?` (.cascade)

**Computed Properties** (NOT stored):
- `hasAttachedMedia`
- `attachedMediaCount`

**Estimated Lines**: ~60 lines per version = 120 lines total

---

#### 6. TitlePageEntryModel ❌ **MISSING FROM VERSIONED SCHEMAS**
**Current**: Not in V1/V2 models list
**Required**: 3 properties + 1 relationship

Must be **added to `models` array** in both V1 and V2:
```swift
public static let models: [any PersistentModel.Type] = [
  GuionElementModel.self,
  GuionDocumentModel.self,
  TypedDataStorage.self,
  CharacterVoiceMapping.self,
  CustomOutlineElement.self,
  TitlePageEntryModel.self,  // ADD THIS
  CustomPageModel.self,       // ADD THIS
  // Remove OutlineItemModel - doesn't exist
]
```

**Properties to Add**:
- `key: String`
- `values: [String]`

**Relationships to Add**:
- `document: GuionDocumentModel?` (inverse)

**Estimated Lines**: ~20 lines per version = 40 lines total

---

#### 7. CustomPageModel ❌ **MISSING FROM VERSIONED SCHEMAS**
**Current**: Not in V1/V2 models list
**Required**: 5 properties + 1 relationship

**Properties to Add**:
- `id: String`
- `title: String`
- `position: Int`
- `pageType: String`
- `jsonData: Data`

**Relationships to Add**:
- `document: GuionDocumentModel?` (.nullify)

**Estimated Lines**: ~30 lines per version = 60 lines total

---

#### 8. OutlineItemModel ❌ **DOESN'T EXIST**
**Current**: Listed in models array but file doesn't exist
**Action**: **Remove from both V1 and V2 `models` arrays**

---

### Total Estimated Code

| Model | Lines per Version | V1 + V2 Total |
|-------|------------------|---------------|
| GuionElementModel | ✅ Complete | 0 (done) |
| GuionDocumentModel | 80 | 160 |
| TypedDataStorage | 100 | 200 |
| CharacterVoiceMapping | 30 | 60 |
| CustomOutlineElement | 60 | 120 |
| TitlePageEntryModel | 20 | 40 |
| CustomPageModel | 30 | 60 |
| **Total** | | **640 lines** |

---

## Can We Extend Classes Instead of Mirroring?

**No.** SwiftData versioned schemas have specific constraints:

1. **Must be nested inside `VersionedSchema` enum**: Can't extend production classes
2. **Must be self-contained**: Can't reference external types
3. **SwiftData uses schema metadata, not runtime types**: Inheritance/extension wouldn't work for migration

Each versioned schema is a **snapshot** of the model shape at that version. They must be complete duplicates.

---

## Alternative Approaches

### Option A: Mirror All Models (Recommended)
- **Pros**: Correct migration, no data loss
- **Cons**: 640 lines of duplicate code, must be kept in sync
- **Effort**: ~4-6 hours

### Option B: Drop Schema Versioning Entirely
- **Pros**: No migration complexity, no data loss risk
- **Cons**: Consumers must handle migrations themselves
- **Effort**: ~1 hour (revert commits, update docs)

### Option C: Defer Until V3 (Band-aid)
- Add warnings to docs: "V1/V2 schemas incomplete - DO NOT USE for production stores"
- Ship V3 with complete schemas when next major change needed
- **Pros**: Buys time
- **Cons**: Broken feature shipped, confusing for consumers

---

## Recommended Action

**Option A**: Fix it properly now before release.

**Rationale**:
- Data loss is unacceptable for a library
- 640 lines is tedious but not complex (copy-paste + adjust)
- Once done, future migrations are easier (just add delta)
- The alternative (reverting) loses all the work already done

**Implementation Plan**:

1. Create a script to extract stored properties from production models ✅ (analysis done)
2. Update V1 schema with complete models (~320 lines)
3. Update V2 schema with complete models (~320 lines)
4. Add/remove models from `models` arrays:
   - Add `TitlePageEntryModel`
   - Add `CustomPageModel`
   - Remove `OutlineItemModel`
5. Update MigrationTests to verify all fields migrate correctly
6. Re-enable MigrationTests in CI once fixed
7. Document schema versioning best practices

**Testing**:
- Create V1 store with all fields populated
- Migrate to V2
- Verify all fields preserved
- Verify glosa fields default to nil

---

## Schema Versioning Best Practices (For Next Time)

1. **Start with complete schemas**: Always mirror production models exactly
2. **Use code generation**: Script to extract properties from `@Model` classes
3. **Test exhaustively**: Migration tests must verify every field
4. **Version carefully**: Only create V2/V3 when schema actually changes
5. **Document deltas**: Comment what changed between versions

---

## Related Files

- `Sources/SwiftCompartido/Schemas/SwiftCompartidoSchemaV1.swift`
- `Sources/SwiftCompartido/Schemas/SwiftCompartidoSchemaV2.swift`
- `Tests/SwiftCompartidoTests/MigrationTests.swift`
- Production models in `Sources/SwiftCompartido/SwiftDataModels/`

---

## Status

- [x] Decision made on approach (Option A: Mirror All Models)
- [x] V1 schema completed (all 7 models with complete fields)
- [x] V2 schema completed (all 7 models with complete fields)
- [x] MigrationTests updated (9 comprehensive tests covering all models)
- [x] MigrationTests re-enabled in CI (all tests passing)
- [x] Documentation updated (comprehensive docs in both schema files + AGENTS.md + README.md)
