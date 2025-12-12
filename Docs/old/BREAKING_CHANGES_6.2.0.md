# Breaking Changes in SwiftCompartido 6.2.0

**Version:** 6.2.0 (Phase 1 & Phase 2)
**Date:** December 2025

## Summary

SwiftCompartido 6.2.0 introduces the **JSON .guion format** (Phase 1) and comprehensive testing (Phase 2). While backward compatibility is maintained for reading legacy files, the save format has changed.

## Critical Changes

### 1. File Format: TextPack → JSON

**Impact:** HIGH
**Affected:** All `.guion` file saves

#### Before (< 6.2.0)

```swift
// Saved as TextPack bundle (directory)
screenplay.guion/
├── info.json
├── screenplay.fountain
└── Resources/...
```

#### After (>= 6.2.0)

```swift
// Saved as single JSON file
screenplay.guion  // JSON file
```

**Migration:** Automatic on first save. See `TEXTPACK_TO_JSON_MIGRATION_GUIDE.md`

**Backward Compatibility:** ✅ Can **read** old TextPack bundles
**Forward Compatibility:** ❌ Old versions **cannot** read new JSON files

---

### 2. Deprecated APIs

**Impact:** MEDIUM
**Affected:** Code using TextPackWriter

#### Deprecated in 6.2.0

```swift
@available(*, deprecated, message: "Use GuionJSONSerializer instead")
TextPackWriter.createTextPack(from:)

@available(*, deprecated, message: "Use GuionJSONSerializer.encode() instead")
TextPackWriter.createTextPack(from: GuionParsedElementCollection)

@available(*, deprecated, message: "Use GuionJSONSerializer.save() instead")
TextPackWriter.createTextPack(from: GuionDocumentModel)
```

#### Replacement

```swift
// ✅ New API
let snapshot = document.toSnapshot()
let jsonData = try GuionJSONSerializer.encode(snapshot)
try jsonData.write(to: url)
```

**Timeline:**
- **6.2.0:** Deprecated with warnings
- **6.3.0:** Planned removal (TextPackWriter will be deleted)

---

### 3. Element UUID Preservation

**Impact:** LOW (Bug fix, but behavior change)
**Affected:** App Intents, Shortcuts, element references

#### Before (< 6.2.0)

```swift
// UUIDs were regenerated on every load
element.uuid  // Different after save/load
```

#### After (>= 6.2.0)

```swift
// UUIDs are stable across save/load cycles
element.uuid  // Same after save/load ✅
```

**Why This Matters:** App Intents and Shortcuts rely on stable UUIDs to reference specific elements. Without preservation, references break after reopening files.

**Migration:** Existing elements will get new UUIDs on first save (one-time only).

---

### 4. Title Page Key Normalization

**Impact:** LOW (Existing behavior, now documented)
**Affected:** Title page lookups

#### Behavior (All Versions)

```swift
// Keys are normalized to uppercase
TitlePageEntryModel(key: "Title", values: ["My Script"])
// Stored as: "TITLE"

// Lookups must use uppercase
titlePage.first { $0.key == "TITLE" }  // ✅ Works
titlePage.first { $0.key == "Title" }  // ❌ Won't find it
```

**Why:** Consistent lookup regardless of input casing.

**Migration:** Update any case-sensitive title page lookups to use uppercase keys.

---

### 5. Character Voice Casting (New Feature)

**Impact:** NONE (New feature, not breaking)
**Affected:** Apps using SwiftHablare integration

#### New in 6.2.0 (Phase 1.5)

```swift
// New property on GuionDocumentModel
document.casting: [CharacterVoiceMapping]?

// Example usage
let janeVoice = CharacterVoiceMapping(
    characterName: "JANE",
    voiceURI: "macos://Samantha",
    voiceName: "Samantha",
    providerID: "macos"
)
document.casting = [janeVoice]
```

**Migration:** None required. Casting is optional and defaults to `nil`.

---

## Database Migration

### SwiftData Schema Changes

**Impact:** LOW
**Affected:** Apps using SwiftData persistence

#### New Models in 6.2.0

```swift
@Model
class CharacterVoiceMapping {
    var characterName: String
    var voiceURI: String
    var voiceName: String
    var providerID: String
    var document: GuionDocumentModel?
}
```

#### Updated Models

```swift
@Model
class GuionDocumentModel {
    // NEW in 6.2.0
    @Relationship(deleteRule: .cascade)
    var casting: [CharacterVoiceMapping]?
}
```

**Migration:** SwiftData handles schema migration automatically. No action required.

---

## Performance Changes

### Improved Performance in 6.2.0

| Operation | Before (TextPack) | After (JSON) | Improvement |
|-----------|-------------------|--------------|-------------|
| Load 1000 elements | ~0.8s | ~0.02s | **40x faster** |
| Save 1000 elements | ~1.2s | ~0.02s | **60x faster** |
| File size (1000 elements) | ~450 KB | ~330 KB | **27% smaller** |

**Why:** JSON serialization is faster and more efficient than bundle management.

---

## API Changes

### GuionDocumentModel

#### New Properties

```swift
// Phase 1.5: Voice casting
@Relationship(deleteRule: .cascade)
public var casting: [CharacterVoiceMapping]?
```

#### New Methods

```swift
// Phase 1: Snapshot conversion
public func toSnapshot() -> GuionDocumentSnapshot
public static func from(_ snapshot: GuionDocumentSnapshot, in context: ModelContext) -> GuionDocumentModel
```

### GuionJSONSerializer

#### New Type (Phase 1.2)

```swift
public enum GuionJSONSerializer {
    public static func encode(_ snapshot: GuionDocumentSnapshot) throws -> Data
    public static func decode(_ data: Data) throws -> GuionDocumentSnapshot
}
```

**Usage:**

```swift
// Save
let snapshot = document.toSnapshot()
let jsonData = try GuionJSONSerializer.encode(snapshot)
try jsonData.write(to: url)

// Load
let jsonData = try Data(contentsOf: url)
let snapshot = try GuionJSONSerializer.decode(jsonData)
let document = GuionDocumentModel.from(snapshot, in: context)
```

---

## Testing Changes

### New Test Suites (Phase 2)

- **Phase2IntegrationTests:** 8 tests validating JSON round-trip fidelity
- **Phase2BackwardCompatibilityTests:** 6 tests for TextPack compatibility
- **Phase2PerformanceTests:** 9 benchmarks establishing baseline metrics

**Total:** 23 new tests, all passing ✅

**Coverage:** Integration tests validate that all data round-trips correctly through JSON serialization.

---

## Deployment Checklist

### Before Upgrading to 6.2.0

- [ ] Backup all `.guion` files (TextPack bundles)
- [ ] Test migration on non-critical files first
- [ ] Update any code using `TextPackWriter` (will show deprecation warnings)
- [ ] Update title page lookups to use uppercase keys
- [ ] Run Phase 2 integration tests to verify round-trip fidelity

### After Upgrading to 6.2.0

- [ ] Open and save all `.guion` files to convert to JSON
- [ ] Verify file sizes reduced (~27% smaller)
- [ ] Verify performance improved (40-60x faster)
- [ ] Check App Intents/Shortcuts still work (UUID preservation)
- [ ] Remove deprecated `TextPackWriter` usage before 6.3.0

---

## Compatibility Matrix

| SwiftCompartido Version | Read TextPack | Write TextPack | Read JSON | Write JSON |
|-------------------------|---------------|----------------|-----------|------------|
| < 6.2.0 | ✅ Yes | ✅ Yes | ❌ No | ❌ No |
| 6.2.0 | ✅ Yes (fallback) | ⚠️ Deprecated | ✅ Yes | ✅ Yes (default) |
| 6.3.0+ (planned) | ✅ Yes (fallback) | ❌ Removed | ✅ Yes | ✅ Yes |

---

## Support & Resources

**Migration Guide:** `Docs/TEXTPACK_TO_JSON_MIGRATION_GUIDE.md`
**API Reference:** `AI-REFERENCE.md`
**Change Log:** `CHANGELOG.md`
**Issues:** https://github.com/intrusive-memory/SwiftCompartido/issues

**Phase 2 Tests:** Run these to verify your migration:
```bash
xcodebuild test \
  -scheme SwiftCompartido \
  -only-testing:SwiftCompartidoTests/Phase2IntegrationTests
```

---

**Last Updated:** December 11, 2025
**SwiftCompartido Version:** 6.2.0
