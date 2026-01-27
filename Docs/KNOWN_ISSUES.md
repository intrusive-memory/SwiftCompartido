# Known Issues

This document tracks known issues, limitations, and design constraints in SwiftCompartido.

## Resolved Issues

### DocumentModelActor Element Ordering

**Status**: ✅ **FIXED** in 6.3.0

#### Problem

Elements were potentially returned out of order from `getElements()` due to SwiftData relationship ordering not being guaranteed.

**Impact**: Screenplay elements displayed in wrong order in GuionViewer and other apps.

#### Solution

Added explicit sorting by composite key `(chapterIndex, orderIndex)` in `DocumentModelActor.getElements()`. Elements are now always returned in correct document order.

**Code**:
```swift
func getElements(for documentID: PersistentIdentifier, limit: Int) throws -> [ElementInfo] {
    guard let document = self[documentID, as: GuionDocumentModel.self] else {
        throw ActorError.documentNotFound
    }

    // ✅ Explicit sorting ensures correct order
    return document.sortedElements.prefix(limit).map { element in
        ElementInfo(from: element)
    }
}
```

#### References

- Fixed in: Version 6.3.0
- Related file: `Sources/SwiftCompartido/Actors/DocumentModelActor.swift`
- Related docs: [ARCHITECTURE_SWIFTDATA.md](./ARCHITECTURE_SWIFTDATA.md#element-ordering)

---

## Platform Limitations

### Apple Intelligence Availability

**Issue**: Apple Intelligence (Foundation Models) requires specific hardware and OS versions.

**Requirements**:
- **iOS**: 26.2+ on A17 Pro or later (iPhone 15 Pro, iPhone 16 series)
- **macOS**: 26.0+ on M1 or later
- **User action**: Must enable Apple Intelligence in System Settings

**Impact**:
- Apps using `PDFScreenplayParser` will fall back to heuristic parsing (95%+ accuracy) on:
  - Older devices (pre-M1 Macs, pre-A17 Pro iPhones)
  - Devices with Apple Intelligence disabled
  - CI/CD environments (headless runners)

**Workaround**: SwiftCompartido handles this automatically:
1. Attempts AI parsing if available
2. Falls back to heuristic parsing if unavailable
3. Notifies user via `OperationProgress.additionalInfo`

See [FOUNDATION_MODELS_STATUS.md](./FOUNDATION_MODELS_STATUS.md) for complete details.

### iOS Simulator Limitations in CI

**Issue**: GitHub Actions `macos-26` runners don't have iPhone simulators pre-installed.

**Available simulators**:
- ✅ Apple TV (tvOS)
- ✅ Apple Watch (watchOS)
- ✅ Apple Vision Pro (visionOS)
- ❌ iPhone simulators (must be created)

**Impact**: iOS tests fail without dynamic simulator creation.

**Solution**: All CI workflows include a "Create iPhone Simulator" step. See [CI_CD_SETUP.md](./CI_CD_SETUP.md#dynamic-simulator-creation) for implementation details.

---

## Design Limitations

### SwiftData Relationship Ordering

**Issue**: `@Relationship` arrays in SwiftData do **not** guarantee order.

**Impact**: Screenplay elements may be returned in wrong order if accessed via `document.elements` directly.

**Workaround**: **ALWAYS** use `document.sortedElements`:

```swift
// ❌ WRONG - Order not guaranteed
for element in document.elements {
    print(element.text)
}

// ✅ CORRECT - Always sorted
for element in document.sortedElements {
    print(element.text)
}
```

This is a **design limitation** of SwiftData, not a bug in SwiftCompartido.

### TextKit 2 Migration Incomplete

**Issue**: GuionViewer uses SwiftUI `Text` views with `AttributedString`, not TextKit 2.

**Impact**:
- Rendering large screenplays (5000+ elements) is slower than necessary
- TextKit 2 is **400-1600x faster** based on GuionTextEditor benchmarks

**Status**: Planned for future release. See [PERFORMANCE_TESTING.md](./PERFORMANCE_TESTING.md#future-optimization-targets) for roadmap.

---

## Reporting New Issues

If you encounter a bug or limitation not listed here:

1. **Search existing issues**: [GitHub Issues](https://github.com/intrusive-memory/SwiftCompartido/issues)
2. **Create new issue**: Include:
   - SwiftCompartido version
   - iOS/macOS version
   - Device/simulator details
   - Minimal reproduction steps
   - Expected vs. actual behavior
3. **Security issues**: Email security@intrusive-memory.com (do not open public issue)

---

## Version History

- **6.6.0**: Added Apple Intelligence integration docs
- **6.3.0**: Fixed DocumentModelActor element ordering
- **6.2.0**: Introduced binary payload migration issue (unresolved)
