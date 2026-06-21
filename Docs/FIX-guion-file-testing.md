# FIX: .guion File Format Testing Gaps

**Date**: 2026-06-21  
**Version**: SwiftCompartido 7.1.0-dev  
**Status**: 🔴 Critical gaps identified

---

## Executive Summary

The `.guion` file format has **excellent in-memory serialization tests** (95% coverage) but **zero file I/O integration tests**. This is a serious gap — the format is designed to be a file format, but we've never actually tested reading/writing files to disk.

**Overall Test Coverage**: 40% (F grade)

**Critical Issues**:
- 🚨 **GAP 1**: No actual file I/O tests (HIGH PRIORITY)
- 🚨 **GAP 2**: No schema version testing (HIGH PRIORITY)
- 🚨 **GAP 3**: No corruption/malformed file handling (MEDIUM PRIORITY)

---

## Current Test Coverage

### ✅ What's Well Tested (Strong Coverage)

#### 1. Core Serialization — Excellent (95%)
**File**: `Tests/SwiftCompartidoTests/GuionJSONSerializerTests.swift`

- ✅ **24 test methods** with 47 assertions
- ✅ Round-trip fidelity (encode → decode → identical)
- ✅ Pretty-printing & sorted keys
- ✅ ISO8601 date handling
- ✅ UTF-8 & special characters (`🎬`, quotes, newlines, `<>&`)
- ✅ Empty documents, large documents (1000 elements), 120-page screenplays
- ✅ Performance benchmarks (encode/decode/round-trip)

#### 2. Snapshot Data Structures — Excellent (90%)
**Files**: 
- `GuionDocumentSnapshotTests.swift` — 17+ tests covering all fields
- `GuionElementSnapshotTests.swift` — All element types, dual dialogue, centered text
- `TypedDataStorageSnapshotTests.swift` — Text, audio, image, embedding content

- ✅ Voice casting mappings
- ✅ Generated content storage
- ✅ Title page entries
- ✅ Scene locations
- ✅ All element types

#### 3. Backward Compatibility — Good (70%)
**File**: `Phase2BackwardCompatibilityTests.swift`

- ✅ TextPack → JSON migration path tested
- ✅ Legacy format fallback verified
- ✅ `rawContent` field preservation documented

---

## ❌ Critical Testing Gaps (7 Issues)

### GAP 1: No Actual File I/O Tests 🚨 HIGH PRIORITY

**Problem**: All tests use in-memory `Data` objects. **ZERO tests actually write/read `.guion` files from disk.**

```swift
// ❌ What's tested now:
let data = try GuionJSONSerializer.encode(snapshot)  // In-memory only
let decoded = try GuionJSONSerializer.decode(data)

// ❌ What's NOT tested:
try data.write(to: url, options: .atomic)  // File write
let loaded = try Data(contentsOf: url)     // File read
```

**Risk**: 
- File permissions issues undetected
- Atomic write failures not caught
- File system edge cases (long paths, special chars in filenames, symlinks)
- `.guion` extension handling not verified
- Actual disk I/O performance unknown

**Missing Test Cases**:
- ❌ Save snapshot → write to temp file → verify file exists
- ❌ Load `.guion` file from disk → decode → verify content
- ❌ Round-trip: save → close → reopen → identical
- ❌ Atomic write verification (`.guion~` temp file cleanup)
- ❌ File size verification (matches expected ~330 bytes/element)
- ❌ Special characters in filename (`screenplay-émojis-日本語.guion`)
- ❌ Long file paths (>255 chars)
- ❌ Read-only file system error handling
- ❌ Disk full error handling
- ❌ Symlink following/resolution

**Fix**: Create `Tests/SwiftCompartidoTests/GuionJSONSerializerFileIOTests.swift`

**Estimated Work**: 2-3 hours

---

### GAP 2: No Schema Version Testing 🚨 HIGH PRIORITY

**Problem**: No tests verify `.guion` files survive schema migrations.

**Missing Coverage**:
- ❌ V1 `.guion` file (SwiftCompartido 7.0.4) → load with V2 code (7.1.0+)
- ❌ Forward compatibility (V2 file with unknown fields → graceful degradation in V1)
- ❌ Schema version mismatch detection
- ❌ New field defaults (`glosaSpokenText` etc. default to `nil` on V1 import)
- ❌ Complete field preservation during migration

**Risk**: 
- Data loss when users upgrade SwiftCompartido versions
- Broken files when old/new versions of apps share `.guion` files
- Silent field truncation

**Missing Test Cases**:
- ❌ Load V1 fixture file with V2 schema → all fields preserved
- ❌ V2 glosa fields decode as `nil` from V1 file
- ❌ Unknown fields in future V3 file → gracefully ignored by V2 decoder
- ❌ Schema version metadata in JSON (future: add `"schemaVersion": "2.0"`)

**Fix**: Create `Tests/SwiftCompartidoTests/GuionFormatVersioningTests.swift` + fixture files

**Estimated Work**: 3-4 hours (includes creating V1/V2 fixture files)

---

### GAP 3: No Corruption/Malformed File Handling 🚨 MEDIUM PRIORITY

**Problem**: Only **one** error test (`testDecode_InvalidJSON`). Needs comprehensive error coverage.

**Missing Error Cases**:
- ❌ Truncated JSON (incomplete file, cut off mid-object)
- ❌ Missing required fields (`id`, `elements`, `titlePage`, `suppressSceneNumbers`)
- ❌ Invalid UUID format (`"id": "not-a-uuid"`)
- ❌ Invalid element types (`"elementType": "INVALID"`)
- ❌ Negative indices (`"chapterIndex": -1`, `"orderIndex": -5`)
- ❌ Circular references in custom pages
- ❌ Binary data corruption (invalid Base64 in `binaryValue`)
- ❌ Oversized fields (gigabyte-sized `textValue`)
- ❌ Null values in non-optional fields
- ❌ Type mismatches (`"suppressSceneNumbers": "yes"` instead of `true`)
- ❌ Malformed dates (`"created": "not-a-date"`)
- ❌ Empty element text (`"elementText": ""`)
- ❌ Duplicate element IDs

**Risk**: 
- App crashes on user-modified or corrupted `.guion` files
- No graceful error messages
- Silent data corruption acceptance

**Missing Test Cases**:
- ❌ Each error case above should throw `DecodingError` with clear message
- ❌ Validation errors should be distinguishable from parse errors
- ❌ Partial decode should fail atomically (no half-loaded state)

**Fix**: Create `Tests/SwiftCompartidoTests/GuionFormatErrorHandlingTests.swift`

**Estimated Work**: 2-3 hours

---

### GAP 4: No Large File Stress Tests 🚨 MEDIUM PRIORITY

**Problem**: Performance tests create in-memory snapshots but don't test actual large file I/O.

**Missing Stress Tests**:
- ❌ 50MB `.guion` file with 50 audio clips (documented max size in `GuionJSONSerializer.FileFormat.maxRecommendedSize`)
- ❌ 5000+ element screenplay (performance test creates this but doesn't write it)
- ❌ Memory pressure during save/load (should stay under 100MB heap)
- ❌ Cancellation mid-save (partial file cleanup)
- ❌ Concurrent reads/writes to same file
- ❌ File locking behavior

**Risk**: 
- Users hit memory limits or file system limits that tests never exercise
- OOM crashes on large screenplays
- Partial writes leave corrupted files

**Missing Test Cases**:
- ❌ Write 50MB file → measure time, verify size
- ❌ Load 50MB file → measure time, verify no memory leaks
- ❌ Cancel save mid-operation → verify cleanup
- ❌ Progress reporting for large files (Phase 6 feature)

**Fix**: Add to `Tests/SwiftCompartidoPerformanceTests/Phase2PerformanceTests.swift`

**Estimated Work**: 2 hours

---

### GAP 5: No Custom Page Serialization Tests ⚠️ LOW PRIORITY

**Problem**: Custom pages use **raw JSON Data** storage (`customPagesData: [Data]?`), but no tests verify this encoding path works.

**Missing Coverage**:
- ❌ Custom page serialization round-trip (CastListPage → Data → JSON → Data → CastListPage)
- ❌ Failed deserialization warning log verification
- ❌ Cast list custom page with voice mappings → JSON → back
- ❌ Multiple custom pages in one document
- ❌ Custom page with invalid JSON data

**Risk**: 
- Custom pages silently fail to serialize
- Log spam on load from invalid custom pages
- Cast lists lost on save/load

**Code Reference**:
```swift
// GuionDocumentSnapshot.swift:133-150
private var customPagesData: [Data]?

public var customPages: [CustomPageSnapshot]? {
  get {
    guard let data = customPagesData else { return nil }
    // Deserialization logic with Logger warnings
  }
  set {
    // Serialization logic
  }
}
```

**Fix**: Add tests to `Tests/SwiftCompartidoTests/CustomPageContainerTests.swift`

**Estimated Work**: 1 hour

---

### GAP 6: No Glosa Field Round-Trip Tests ⚠️ LOW PRIORITY

**Problem**: V2 schema added 5 glosa fields but no dedicated `.guion` serialization tests.

**New Fields** (SwiftCompartidoSchemaV2):
- `glosaSpokenText: String?` — Notes-stripped dialogue
- `glosaBreathOffsets: [Int]?` — Breath hint positions
- `glosaBreathStrengths: [String]?` — Breath strength values
- `glosaInstruct: String?` — LLM performance direction
- `glosaPausePoints: Data?` — Encoded pause DTOs

**Missing Coverage**:
- ❌ Glosa fields serialize correctly to JSON
- ❌ Glosa fields survive encode → decode round-trip
- ❌ `nil` glosa fields omit from JSON (optional field handling)
- ❌ Non-nil glosa fields preserve exact values
- ❌ `glosaPausePoints` Data encoding (Base64 in JSON)

**Risk**: 
- Glosa data loss on save/load
- Breaking audio annotation pipeline

**Fix**: Add to `Tests/SwiftCompartidoTests/GuionElementSnapshotTests.swift`

**Estimated Work**: 1 hour

---

### GAP 7: No File Format Metadata Validation ⚠️ LOW PRIORITY

**Problem**: `GuionJSONSerializer.FileFormat` constants tested but not **validated against actual files or system integration**.

**File Format Metadata**:
```swift
public static let version = "1.0"
public static let fileExtension = "guion"
public static let uti = "com.swiftguion.screenplay"
public static let mimeType = "application/vnd.swiftguion+json"
```

**Missing Coverage**:
- ❌ MIME type matches HTTP Content-Type header
- ❌ UTI registered with macOS/iOS system
- ❌ File extension recognized by Finder/Files
- ❌ Quick Look integration
- ❌ Spotlight metadata indexing

**Risk**: 
- File association issues (double-click doesn't open app)
- MIME type mismatches in web contexts
- Spotlight can't find `.guion` files

**Fix**: Document-only fix (add to AGENTS.md) or integration test with `NSWorkspace` (macOS only)

**Estimated Work**: 30 minutes (documentation) or 2 hours (integration test)

---

## Test Coverage Scorecard

| Category | Current | Target | Grade |
|----------|---------|--------|-------|
| **In-Memory Serialization** | 95% | 95% | A |
| **Snapshot Structures** | 90% | 90% | A- |
| **File I/O** | **0%** | 90% | **F** 🚨 |
| **Error Handling** | 5% | 80% | **F** 🚨 |
| **Schema Versioning** | **0%** | 90% | **F** 🚨 |
| **Large Files** | 10% | 70% | F |
| **Custom Pages** | 20% | 70% | D |
| **Glosa Fields** | 30% | 80% | D |
| **Overall** | **40%** | **85%** | **F** |

---

## 🎯 Action Plan

### Phase 1: Critical Gaps (HIGH PRIORITY) — Do First

**Goal**: Fix the three F-grade gaps that could cause data loss

1. ✅ **GAP 1: File I/O Tests** (Est. 2-3 hours)
   - Create `GuionJSONSerializerFileIOTests.swift`
   - Test save/load round-trip to temp directory
   - Test atomic writes, special filenames, error handling
   - **Target**: 90% file I/O coverage

2. ✅ **GAP 2: Schema Versioning Tests** (Est. 3-4 hours)
   - Create `GuionFormatVersioningTests.swift`
   - Create V1 and V2 fixture `.guion` files
   - Test migration from V1 → V2
   - Test forward compatibility (unknown fields)
   - **Target**: 90% schema versioning coverage

3. ✅ **GAP 3: Error Handling Tests** (Est. 2-3 hours)
   - Create `GuionFormatErrorHandlingTests.swift`
   - Test all corruption/malformed cases
   - Verify clear error messages
   - **Target**: 80% error handling coverage

**Total Est. Time**: 7-10 hours

---

### Phase 2: Medium Priority — Do Next

**Goal**: Improve robustness and edge case coverage

4. ✅ **GAP 4: Large File Stress Tests** (Est. 2 hours)
   - Add to `Phase2PerformanceTests.swift`
   - Test 50MB file write/read
   - Test memory pressure
   - **Target**: 70% large file coverage

5. ✅ **GAP 6: Glosa Field Tests** (Est. 1 hour)
   - Add to `GuionElementSnapshotTests.swift`
   - Test all 5 glosa fields serialize/deserialize
   - **Target**: 80% glosa coverage

**Total Est. Time**: 3 hours

---

### Phase 3: Low Priority — Nice to Have

**Goal**: Polish and complete coverage

6. ✅ **GAP 5: Custom Page Tests** (Est. 1 hour)
   - Add to `CustomPageContainerTests.swift`
   - Test Data-based encoding
   - **Target**: 70% custom page coverage

7. ✅ **GAP 7: File Format Metadata** (Est. 30 min)
   - Document UTI/MIME type registration in AGENTS.md
   - **Target**: Documentation complete

**Total Est. Time**: 1.5 hours

---

## Success Criteria

After implementing all fixes:

- ✅ Overall test coverage ≥85%
- ✅ All critical gaps (GAP 1-3) at 80%+ coverage
- ✅ Zero data loss scenarios in test suite
- ✅ Clear error messages for all corruption cases
- ✅ File I/O tested on actual disk
- ✅ Schema migrations tested with fixture files
- ✅ Large file performance benchmarked

---

## Implementation Checklist

### GAP 1: File I/O Tests ✅ COMPLETE
- [x] Create `GuionJSONSerializerFileIOTests.swift`
- [x] Test: Save snapshot to temp file
- [x] Test: Load .guion file from disk
- [x] Test: Round-trip save/load
- [x] Test: Atomic write (.guion~ cleanup)
- [x] Test: Special chars in filename
- [x] Test: Long file paths
- [x] Test: Read-only filesystem
- [x] Test: Disk full error (simulated via read-only)
- [x] Test: Symlink handling

**Status**: ✅ Complete — 17 tests passing (0.033s)

### GAP 2: Schema Versioning Tests ✅ COMPLETE
- [x] Create `GuionFormatVersioningTests.swift`
- [x] Create fixture: `v1-screenplay.guion` (baseline format)
- [x] Create fixture: `v2-screenplay.guion` (with future fields)
- [x] Test: Load V1 file with current decoder
- [x] Test: V1 round-trip preserves all fields
- [x] Test: Unknown fields ignored gracefully
- [x] Test: All V1 fields preserved
- [x] Test: Forward compatibility (future fields)
- [x] Test: Optional fields handle nil/null
- [x] Test: ISO8601 date parsing
- [x] Test: Unknown element types throw errors (strict validation)

**Status**: ✅ Complete — 12 tests passing (0.014s)

### GAP 3: Error Handling Tests
- [ ] Create `GuionFormatErrorHandlingTests.swift`
- [ ] Test: Truncated JSON
- [ ] Test: Missing required fields
- [ ] Test: Invalid UUID
- [ ] Test: Invalid element type
- [ ] Test: Negative indices
- [ ] Test: Binary data corruption
- [ ] Test: Oversized fields
- [ ] Test: Type mismatches
- [ ] Test: Malformed dates
- [ ] Test: Empty element text
- [ ] Test: Duplicate IDs

### GAP 4: Large File Stress Tests
- [ ] Add to `Phase2PerformanceTests.swift`
- [ ] Test: Write 50MB file
- [ ] Test: Load 50MB file
- [ ] Test: Memory pressure
- [ ] Test: Cancellation cleanup
- [ ] Benchmark: Disk I/O time

### GAP 5: Custom Page Tests
- [ ] Add to `CustomPageContainerTests.swift`
- [ ] Test: CastListPage round-trip
- [ ] Test: Multiple custom pages
- [ ] Test: Invalid JSON data

### GAP 6: Glosa Field Tests
- [ ] Add to `GuionElementSnapshotTests.swift`
- [ ] Test: `glosaSpokenText` round-trip
- [ ] Test: `glosaBreathOffsets` round-trip
- [ ] Test: `glosaBreathStrengths` round-trip
- [ ] Test: `glosaInstruct` round-trip
- [ ] Test: `glosaPausePoints` Data encoding
- [ ] Test: nil glosa fields omit from JSON

### GAP 7: File Format Metadata
- [ ] Document UTI registration in AGENTS.md
- [ ] Document MIME type usage in AGENTS.md
- [ ] (Optional) macOS Quick Look integration test

---

## Notes

- **Test Isolation**: All file I/O tests must use temp directories and clean up after themselves
- **Performance**: Large file tests should be marked as performance tests (won't run in normal CI)
- **Fixtures**: Schema versioning fixtures checked into `Tests/Fixtures/` directory
- **CI Integration**: New tests must pass on GitHub Actions (macOS-26 runner)

---

## References

- **AGENTS.md**: Project documentation
- **GuionJSONSerializer.swift**: Serialization implementation
- **GuionDocumentSnapshot.swift**: Root snapshot type
- **SwiftCompartidoSchemaV2.swift**: V2 schema definition
- **MigrationTests.swift**: Existing schema migration tests (SwiftData models)
