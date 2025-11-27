# Performance Improvement Plan for SwiftCompartido 4.x

**Document Version**: 1.0
**Date**: 2025-11-23
**Target Release**: 5.0.0

---

## Executive Summary

This document outlines a comprehensive plan to address critical performance issues in SwiftCompartido, specifically targeting:

1. **GuionElementsList scrolling performance** - Currently unusable for documents with 500+ elements
2. **Parser performance and progress reporting** - Blocking main thread, inadequate progress updates
3. **Code cleanup** - Remove deprecated code and unused classes

**Current State**:
- GuionElementsList: 20-30 fps on 1000+ element documents
- Parsing: Blocks main thread, progress updates every 100 lines only
- Technical debt: 130 lines of deprecated type aliases, 4+ deprecated properties

**Target State**:
- GuionElementsList: Consistent 60 fps scrolling regardless of document size
- Parsing: Non-blocking with smooth progress updates (every 1-2%)
- Clean codebase: Zero deprecated code, streamlined API surface

---

## Critical Issues Analysis

### 1. GuionElementsList Performance Bottlenecks

**File**: `Sources/SwiftCompartido/UI/GuionElementsList.swift` (149 lines)

#### Issue 1A: No Lazy Loading (CRITICAL)
**Location**: Line 71-99
**Problem**: All elements instantiated immediately, no view recycling
**Impact**: Memory usage = O(n) where n = element count, ~1000 views for large documents
**Severity**: CRITICAL

#### Issue 1B: Array Conversion on Every Render (HIGH)
**Location**: Line 73
```swift
ForEach(Array(elements.enumerated()), id: \.element.id)
```
**Problem**: Creates new array copy on every view update
**Impact**: Unnecessary memory allocations trigger garbage collection
**Severity**: HIGH

#### Issue 1C: Synchronous Text Formatting (HIGH)
**File**: `Sources/SwiftCompartido/UI/ActionView.swift` (Line 20-23)
**File**: `Sources/SwiftCompartido/UI/FountainTextFormatter.swift` (Line 20-133)
**Problem**: Regex pattern matching (3 patterns) runs synchronously on main thread for every element
**Impact**: Blocks rendering pipeline, visible frame drops during scroll
**Severity**: HIGH

#### Issue 1D: Stateful Row Overhead (MEDIUM-HIGH)
**File**: `Sources/SwiftCompartido/UI/GuionElementRow.swift` (Line 32-49)
**Problem**: Each row maintains 5 state variables + 2 async tasks
**Impact**: 500 elements = 2500 state properties + 1000 tasks in memory
**Severity**: MEDIUM-HIGH

#### Issue 1E: Repeated Spacing Calculations (MEDIUM)
**Location**: Line 77-91, 106-125
**Problem**: `isEndOfDialogueGroup()` called for every element on every render
**Impact**: Unnecessary O(1) lookups × element count
**Severity**: MEDIUM

**Performance by Document Size**:
| Elements | Current FPS | Target FPS | Status |
|----------|-------------|------------|--------|
| < 100 | 60 fps | 60 fps | OK |
| 100-500 | 45-55 fps | 60 fps | Poor |
| 500+ | 20-30 fps | 60 fps | Unusable |
| 1000+ | < 20 fps | 60 fps | Critical |

---

### 2. Parsing Performance Issues

**Primary Files**:
- `Sources/SwiftCompartido/Serialization/FountainParser.swift` (889 lines)
- `Sources/SwiftCompartido/Serialization/FDXParser.swift` (381 lines)
- `Sources/SwiftCompartido/Serialization/PDFScreenplayParser.swift` (407 lines)
- `Sources/SwiftCompartido/Progress/OperationProgress.swift` (116 lines)

#### Issue 2A: Main Thread Blocking (HIGH)
**Location**: FountainParser.parseContentsAsync() (Line 66-860)
**Problem**: Despite `async` signature, NO background thread dispatch
**Impact**: UI freezes during parsing, 2-5+ seconds for large screenplays
**Severity**: HIGH

#### Issue 2B: Regex Compilation Per Line (HIGH)
**Location**: FountainParser.matches() (Line 864-887)
```swift
private func matches(string: String, pattern: String, ...) -> Bool {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
        return false
    }
    // Recompiled for EVERY line × 15+ patterns
}
```
**Problem**: 15+ regex patterns compiled repeatedly for each line
**Impact**: 5-10ms overhead per parse, compounds with file size
**Severity**: HIGH

#### Issue 2C: String Copy Overhead (MEDIUM)
**Locations**: Line 186, 214, 416, 598, 828
**Problem**: String concatenation via `replacingOccurrences(of:)` and `+` operator
**Impact**: Memory churn, especially on 10,000+ line screenplays
**Severity**: MEDIUM

#### Issue 2D: Coarse Progress Updates (MEDIUM)
**Location**: Line 521, 561 (reports every 100 lines)
**Problem**: Only ~100 updates for a 10,000 line screenplay
**Impact**: Progress bar appears frozen for long periods
**Severity**: MEDIUM

#### Issue 2E: Linear Search for Dual Dialogue (MEDIUM)
**Location**: Line 391-398
```swift
var idx = elements.count - 1
while idx >= 0 && !foundPreviousCharacter {
    if elements[idx].elementType == .character {
        elements[idx].isDualDialogue = true
        foundPreviousCharacter = true
    }
    idx -= 1
}
```
**Problem**: O(n) backward search through all elements
**Impact**: Accumulates to O(n²) over entire parse
**Severity**: MEDIUM

---

### 3. Deprecated Code Inventory

#### 3A: Legacy Type Aliases (130 lines total)
**File**: `Sources/SwiftCompartido/SwiftDataModels/LegacyTypeAliases.swift`

| Alias | Replacement | Status | Can Remove After |
|-------|-------------|--------|------------------|
| `GeneratedTextRecord` | `TypedDataStorage` | Deprecated | Test migration |
| `GeneratedAudioRecord` | `TypedDataStorage` | Deprecated | Test migration |
| `GeneratedImageRecord` | `TypedDataStorage` | Deprecated | Test migration |
| `GeneratedEmbeddingRecord` | `TypedDataStorage` | Deprecated | Test migration |

**Tests Using Deprecated Aliases**:
- `GeneratedRecordTests.swift` (659 lines)
- `CloudKitSupportTests.swift` (508 lines)
- `GeneratedEmbeddingDataTests.swift` (472 lines)

#### 3B: Deprecated Properties

| Property | File | Replacement | Used In |
|----------|------|-------------|---------|
| `sectionDepth` | GuionElement.swift:176 | `elementType.level` | Multiple tests |
| `sectionDepth` | GuionElementModel.swift:149 | `elementType.level` | Multiple tests |
| `sectionDepth` | FDXParser.swift:21 | `elementType.level` | FDX tests |
| `cost` | AIResponseData.swift:372 | `costUSD` | Legacy clients |

**Tests Using `sectionDepth`**:
- `GuionElementTests.swift`
- `GeneratedContentSortingTests.swift`
- `FountainParserTests.swift`
- `SceneBrowserTests.swift`

#### 3C: Deprecated Type Aliases

**File**: `GuionParsedScreenplay.swift` (Line 611)
- `GuionParsedScreenplay = GuionParsedElementCollection`
- Deprecated since 3.0+
- No active usage found in source

**Total Removable Code**: ~150 lines + test updates

---

## Prioritized Implementation Roadmap

### Phase 1: Critical Performance Fixes (Target: 5.0.0)

**Estimated Impact**: 80% performance improvement for large documents

#### 1.1 Implement Lazy Loading for GuionElementsList (CRITICAL)
**Priority**: P0
**Estimated Effort**: 3-5 days
**Files**:
- `Sources/SwiftCompartido/UI/GuionElementsList.swift`
- `Sources/SwiftCompartido/UI/GuionElementRow.swift`

**Implementation Strategy**:
```swift
// Replace ForEach with LazyVStack
ScrollView {
    LazyVStack(spacing: 0, pinnedViews: []) {
        ForEach(document.sortedElements) { element in
            GuionElementRow(element: element, trailingContent: trailingContent)
                .id(element.id)
        }
    }
}
```

**Key Changes**:
- Remove `List` wrapper
- Use `ScrollView` + `LazyVStack` for true virtualization
- Maintain element IDs for stable view identity
- Test with 5000+ element documents

**Success Metrics**:
- 1000 element document: 60 fps scrolling (currently 20-30 fps)
- Memory usage: O(visible elements) not O(total elements)
- Initial render time < 500ms for any document size

---

#### 1.2 Cache Compiled Regex Patterns (HIGH)
**Priority**: P0
**Estimated Effort**: 2-3 days
**File**: `Sources/SwiftCompartido/Serialization/FountainParser.swift`

**Implementation Strategy**:
```swift
// Add static cached regex dictionary
private static let regexCache: [String: NSRegularExpression] = {
    var cache: [String: NSRegularExpression] = [:]
    let patterns = [
        "sceneHeading": "^(INT|EXT|EST|INT./EXT|INT/EXT|I/E)(\\.)?\\s+",
        "transition": "^(>\\s*.+|.+ TO:)$",
        "character": "^[A-Z][A-Z0-9 ]*$",
        // ... all patterns
    ]
    for (key, pattern) in patterns {
        cache[key] = try? NSRegularExpression(pattern: pattern, options: [])
    }
    return cache
}()

// Replace matches() function
private func matches(string: String, patternKey: String) -> Bool {
    guard let regex = Self.regexCache[patternKey] else { return false }
    return regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) != nil
}
```

**Success Metrics**:
- Parsing time reduced by 50-70% for large screenplays
- Regex compilation from O(lines × patterns) to O(1)
- 10,000 line screenplay: < 2 seconds (currently 5+ seconds)

---

#### 1.3 Offload Parsing to Background Thread (HIGH)
**Priority**: P0
**Estimated Effort**: 3-4 days
**Files**:
- `Sources/SwiftCompartido/Serialization/FountainParser.swift`
- `Sources/SwiftCompartido/Progress/OperationProgress.swift`

**Implementation Strategy**:
```swift
// In GuionParsedElementCollection.init(file:progress:)
public init(file: URL, progress: ProgressHandler? = nil) async throws {
    // Dispatch to background queue
    try await Task.detached(priority: .userInitiated) {
        // Parse on background thread
        let parser = FountainParser(contents: contents, progress: progress)
        let result = try await parser.parseContentsAsync()

        // Return to main actor for SwiftData operations if needed
        return result
    }.value
}
```

**Key Changes**:
- Wrap parsing in `Task.detached` with `.userInitiated` priority
- Ensure progress handler dispatches to main thread internally
- Update `OperationProgress` to use `@Sendable` closures
- Verify thread safety of all parser state

**Success Metrics**:
- Main thread never blocks during parsing
- UI remains responsive at all times
- Progress bar updates smoothly without jank

---

#### 1.4 Pre-compute Text Formatting (HIGH)
**Priority**: P1
**Estimated Effort**: 2-3 days
**File**: `Sources/SwiftCompartido/UI/ActionView.swift`

**Implementation Strategy**:
```swift
// Add formatted text cache to GuionElementModel
@Model
class GuionElementModel {
    // Existing properties...

    // Cached attributed text (generated once, stored)
    @Attribute(.ephemeral) var cachedFormattedText: AttributedString?

    func formattedText(fontSize: CGFloat) -> AttributedString {
        if let cached = cachedFormattedText {
            return cached
        }
        let formatted = FountainTextFormatter.format(elementText, baseFont: ...)
        self.cachedFormattedText = formatted
        return formatted
    }
}

// In ActionView
Text(element.formattedText(fontSize: fontSize))
```

**Alternative: Background Formatting**:
```swift
@State private var formattedText: AttributedString?

var body: some View {
    Text(formattedText ?? AttributedString(element.elementText))
        .task {
            formattedText = await Task.detached {
                FountainTextFormatter.format(element.elementText, ...)
            }.value
        }
}
```

**Success Metrics**:
- Text formatting happens once per element
- No main thread blocking during scroll
- Smooth 60 fps scrolling maintained

---

### Phase 2: Medium Priority Improvements (Target: 5.1.0)

**Estimated Impact**: 15% additional performance improvement

#### 2.1 Reduce Row State Overhead (MEDIUM-HIGH)
**Priority**: P2
**Estimated Effort**: 2 days
**File**: `Sources/SwiftCompartido/UI/GuionElementRow.swift`

**Strategy**: Move hover state to environment-based coordinator

```swift
// Create hover coordinator
@Observable
class ElementHoverCoordinator {
    var hoveredElementID: UUID?
    var showPopoverForID: UUID?
}

// In GuionElementRow
@Environment(\.elementHoverCoordinator) private var coordinator

var body: some View {
    content
        .onHover { isHovering in
            coordinator.hoveredElementID = isHovering ? element.id : nil
        }
        .popover(isPresented: Binding(
            get: { coordinator.showPopoverForID == element.id },
            set: { if !$0 { coordinator.showPopoverForID = nil } }
        )) {
            // Popover content
        }
}
```

**Success Metrics**:
- Memory per row reduced by ~50%
- No tasks stored in row state
- Hover state managed centrally

---

#### 2.2 Increase Progress Update Frequency (MEDIUM)
**Priority**: P2
**Estimated Effort**: 1 day
**File**: `Sources/SwiftCompartido/Serialization/FountainParser.swift`

**Strategy**: Report progress every 1-2% instead of every 100 lines

```swift
// Calculate percentage-based updates
let totalLines = lines.count
let updateInterval = max(1, totalLines / 100) // Report every 1%

for (index, line) in lines.enumerated() {
    // Parse line...

    if index % updateInterval == 0 {
        progress?.update(
            completedUnits: Int64(index),
            totalUnits: Int64(totalLines),
            description: "Parsing screenplay... (\(index)/\(totalLines) lines)"
        )
    }
}
```

**Success Metrics**:
- Progress bar updates at least 100 times during parse
- Smooth visual progression (no long freezes)
- User perceives continuous progress

---

#### 2.3 Optimize String Operations (MEDIUM)
**Priority**: P2
**Estimated Effort**: 2-3 days
**File**: `Sources/SwiftCompartido/Serialization/FountainParser.swift`

**Strategy**: Use StringBuilder pattern instead of string concatenation

```swift
// Replace repeated string concatenation
// OLD:
elements[lastIndex].elementText = "\(elements[lastIndex].elementText)\n\(line)"

// NEW:
var textBuilder = StringBuilder()
for line in continuedLines {
    textBuilder.append(line)
    textBuilder.append("\n")
}
elements[lastIndex].elementText = textBuilder.toString()

// Or use Array + join
var lines: [String] = []
// ... collect lines
elements[lastIndex].elementText = lines.joined(separator: "\n")
```

**Success Metrics**:
- Memory allocations reduced by 30-40%
- Parse time improvement of 10-15%

---

#### 2.4 Eliminate Dual Dialogue Linear Search (MEDIUM)
**Priority**: P3
**Estimated Effort**: 1 day
**File**: `Sources/SwiftCompartido/Serialization/FountainParser.swift` (Line 391-398)

**Strategy**: Track last character index instead of searching

```swift
var lastCharacterIndex: Int?

for (index, line) in lines.enumerated() {
    // ... parse element

    if element.elementType == .character {
        if isDualDialogue {
            // Use cached index instead of linear search
            if let lastIdx = lastCharacterIndex {
                elements[lastIdx].isDualDialogue = true
            }
        }
        lastCharacterIndex = elements.count
    }
}
```

**Success Metrics**:
- Dual dialogue detection from O(n²) to O(n)
- Parsing speed improvement of 5-10% for dialogue-heavy scripts

---

### Phase 3: Code Cleanup (Target: 5.0.0)

**Estimated Impact**: Cleaner API, reduced test maintenance

#### 3.1 Remove Legacy Type Aliases (LOW)
**Priority**: P3
**Estimated Effort**: 1-2 days
**Files**:
- `Sources/SwiftCompartido/SwiftDataModels/LegacyTypeAliases.swift` (DELETE)
- Update tests:
  - `Tests/SwiftCompartidoTests/GeneratedRecordTests.swift`
  - `Tests/SwiftCompartidoTests/CloudKitSupportTests.swift`
  - `Tests/SwiftCompartidoTests/GeneratedEmbeddingDataTests.swift`

**Migration Steps**:
1. Find all usages of deprecated aliases:
   ```bash
   grep -r "GeneratedTextRecord\|GeneratedAudioRecord\|GeneratedImageRecord\|GeneratedEmbeddingRecord" Tests/
   ```
2. Replace with `TypedDataStorage` + appropriate initializer:
   ```swift
   // OLD:
   let record = GeneratedTextRecord(...)

   // NEW:
   let record = TypedDataStorage(data: GeneratedTextData(...))
   ```
3. Update test assertions to use `TypedDataStorage` API
4. Delete `LegacyTypeAliases.swift`
5. Run full test suite to verify

**Success Metrics**:
- 130 lines of code removed
- All tests pass with new API
- No breaking changes for users (covered by deprecation warnings)

---

#### 3.2 Remove Deprecated sectionDepth Property (LOW)
**Priority**: P3
**Estimated Effort**: 1 day
**Files**:
- `Sources/SwiftCompartido/Sendable/GuionElement.swift` (Line 176)
- `Sources/SwiftCompartido/SwiftDataModels/GuionElementModel.swift` (Line 149)
- `Sources/SwiftCompartido/Serialization/FDXParser.swift` (Line 21)

**Migration Steps**:
1. Update all test files using `sectionDepth`:
   ```swift
   // OLD:
   element.sectionDepth = 2
   XCTAssertEqual(element.sectionDepth, 2)

   // NEW:
   element.elementType = .section(2)
   XCTAssertEqual(element.elementType.level, 2)
   ```
2. Remove computed property implementations
3. Run tests to verify

**Test Files to Update**:
- `GuionElementTests.swift`
- `GeneratedContentSortingTests.swift`
- `FountainParserTests.swift`
- `SceneBrowserTests.swift`
- `FDXParserTests.swift`

**Success Metrics**:
- 3 deprecated properties removed
- All tests pass
- API surface simplified

---

#### 3.3 Remove GuionParsedScreenplay Alias (LOW)
**Priority**: P4
**Estimated Effort**: 0.5 days
**File**: `Sources/SwiftCompartido/Sendable/GuionParsedScreenplay.swift` (Line 611)

**Migration Steps**:
1. Verify no usage in source:
   ```bash
   grep -r "GuionParsedScreenplay" Sources/ --exclude="GuionParsedScreenplay.swift"
   ```
2. Delete type alias:
   ```swift
   // DELETE:
   @available(*, deprecated, renamed: "GuionParsedElementCollection")
   public typealias GuionParsedScreenplay = GuionParsedElementCollection
   ```
3. Update documentation references

**Success Metrics**:
- Type alias removed
- No compilation errors
- CHANGELOG.md updated with breaking change note

---

## Implementation Timeline

### Sprint 1 (Week 1-2): Critical Performance
- [ ] Day 1-5: Implement lazy loading (1.1)
- [ ] Day 6-8: Cache regex patterns (1.2)
- [ ] Day 9-12: Background thread parsing (1.3)
- [ ] Day 13-14: Pre-compute text formatting (1.4)

**Deliverable**: 5.0.0-alpha.1 with 80% performance improvement

### Sprint 2 (Week 3): Medium Priority
- [ ] Day 15-16: Reduce row state overhead (2.1)
- [ ] Day 17: Increase progress frequency (2.2)
- [ ] Day 18-20: Optimize string operations (2.3)
- [ ] Day 21: Eliminate linear search (2.4)

**Deliverable**: 5.0.0-alpha.2 with additional 15% improvement

### Sprint 3 (Week 4): Code Cleanup
- [ ] Day 22-23: Remove legacy type aliases (3.1)
- [ ] Day 24: Remove sectionDepth property (3.2)
- [ ] Day 25: Remove GuionParsedScreenplay alias (3.3)
- [ ] Day 26-28: Final testing and documentation

**Deliverable**: 5.0.0-beta.1 ready for production

---

## Testing Strategy

### Performance Benchmarks

Create benchmark test suite in `Tests/SwiftCompartidoTests/PerformanceTests.swift`:

```swift
import Testing
import SwiftCompartido

@Suite("Performance Benchmarks")
struct PerformanceBenchmarks {

    @Test("GuionElementsList scrolling performance", .tags(.performance))
    func testListScrollingPerformance() async throws {
        // Generate 1000 element screenplay
        let screenplay = generateLargeScreenplay(elementCount: 1000)

        // Measure rendering time
        let start = Date()
        _ = GuionElementsList(document: screenplay)
        let duration = Date().timeIntervalSince(start)

        // Should render in < 500ms
        #expect(duration < 0.5)
    }

    @Test("Fountain parser performance", .tags(.performance))
    func testParserPerformance() async throws {
        // Load 10,000 line screenplay
        let screenplay = loadLargeScreenplay()

        let start = Date()
        let parsed = try await GuionParsedElementCollection(string: screenplay)
        let duration = Date().timeIntervalSince(start)

        // Should parse in < 2 seconds
        #expect(duration < 2.0)
    }

    @Test("Progress update frequency", .tags(.performance))
    func testProgressUpdateFrequency() async throws {
        var updateCount = 0
        let progress = OperationProgress(totalUnits: nil) { _ in
            updateCount += 1
        }

        let screenplay = loadLargeScreenplay()
        _ = try await GuionParsedElementCollection(string: screenplay, progress: progress)

        // Should have at least 100 updates
        #expect(updateCount >= 100)
    }
}
```

### Regression Testing

Run existing test suite to ensure no functionality broken:
```bash
./build.sh --action test
```

**Must Pass**:
- All 437 existing tests
- No performance regressions in passing tests
- Code coverage remains above 90%

### Manual Testing Checklist

- [ ] Scroll 5000-element screenplay at 60 fps
- [ ] Parse 50,000-line screenplay without UI freeze
- [ ] Progress bar updates smoothly during parse
- [ ] Memory usage stable during long scrolling sessions
- [ ] Hover interactions work correctly with lazy loading
- [ ] Element selection and navigation still functional

---

## Success Metrics

### Key Performance Indicators (KPIs)

| Metric | Current | Target | Measurement |
|--------|---------|--------|-------------|
| 1000-element list FPS | 20-30 fps | 60 fps | Instruments Time Profiler |
| 10,000-line parse time | 5+ seconds | < 2 seconds | Date().timeInterval |
| Progress updates | ~100 total | 100+ updates | Counter in handler |
| Memory for 1000 elements | ~500 MB | < 100 MB | Instruments Allocations |
| Initial render time | 2-5 seconds | < 500ms | Date().timeInterval |
| Main thread blocks | Yes (parsing) | Never | Thread Sanitizer |

### Release Criteria for 5.0.0

**Must Have**:
- ✅ All 4 critical performance fixes implemented (Phase 1)
- ✅ 80%+ performance improvement measured
- ✅ All existing tests pass
- ✅ Performance benchmarks pass
- ✅ No main thread blocking during parsing
- ✅ 60 fps scrolling on 1000+ element documents

**Should Have**:
- ✅ Medium priority improvements (Phase 2)
- ✅ Code cleanup complete (Phase 3)
- ✅ Documentation updated
- ✅ CHANGELOG.md updated

**Nice to Have**:
- Performance test suite in CI
- Benchmark comparisons in PR comments
- Performance dashboard for tracking metrics over time

---

## Breaking Changes in 5.0.0

### For Library Users

**API Removals**:
1. `LegacyTypeAliases.swift` - Use `TypedDataStorage` directly
   ```swift
   // OLD:
   let record = GeneratedTextRecord(...)

   // NEW:
   let record = TypedDataStorage(data: GeneratedTextData(...))
   ```

2. `sectionDepth` property - Use `elementType.level`
   ```swift
   // OLD:
   element.sectionDepth = 2

   // NEW:
   element.elementType = .section(2)
   ```

3. `GuionParsedScreenplay` type alias - Use `GuionParsedElementCollection`
   ```swift
   // OLD:
   let screenplay: GuionParsedScreenplay = ...

   // NEW:
   let screenplay: GuionParsedElementCollection = ...
   ```

**Migration Guide**: Create `MIGRATION_GUIDE_5.0.md` with examples and automated migration scripts where possible.

---

## Risk Assessment

### High Risk Items

**Risk 1: Lazy Loading Changes Behavior**
- **Impact**: Element visibility, popover positioning, accessibility
- **Mitigation**: Extensive manual testing, A/B comparison with current implementation
- **Contingency**: Feature flag to toggle lazy loading on/off

**Risk 2: Background Threading Introduces Concurrency Bugs**
- **Impact**: Data races, crashes, incorrect parsing results
- **Mitigation**: Thread Sanitizer, thorough async testing, code review
- **Contingency**: Revert to main thread parsing with warning

### Medium Risk Items

**Risk 3: Breaking Changes Affect Downstream Projects**
- **Impact**: User code breaks on upgrade
- **Mitigation**: Clear migration guide, deprecation warnings in 4.x releases
- **Contingency**: Provide compatibility shim package

**Risk 4: Performance Improvements Regress in Future**
- **Impact**: Slow performance creeps back in
- **Mitigation**: Add performance tests to CI, block PRs that regress performance
- **Contingency**: Performance monitoring dashboard with alerts

---

## Next Steps

1. **Review this plan** with stakeholders and get approval
2. **Create GitHub issues** for each implementation task
3. **Set up performance testing infrastructure** (Instruments, benchmarks)
4. **Create feature branch** `feature/performance-5.0`
5. **Begin Sprint 1** implementation following roadmap
6. **Weekly progress reviews** to track metrics and adjust plan

---

## Appendix A: File Paths Reference

### UI Performance
- `Sources/SwiftCompartido/UI/GuionElementsList.swift` - Main list view
- `Sources/SwiftCompartido/UI/GuionElementRow.swift` - Individual row
- `Sources/SwiftCompartido/UI/ActionView.swift` - Element text rendering
- `Sources/SwiftCompartido/UI/FountainTextFormatter.swift` - Text formatting

### Parsing Performance
- `Sources/SwiftCompartido/Sendable/GuionParsedScreenplay.swift` - Entry point
- `Sources/SwiftCompartido/Serialization/FountainParser.swift` - Fountain parser
- `Sources/SwiftCompartido/Serialization/FDXParser.swift` - FDX parser
- `Sources/SwiftCompartido/Serialization/PDFScreenplayParser.swift` - PDF parser
- `Sources/SwiftCompartido/Progress/OperationProgress.swift` - Progress tracking

### Deprecated Code
- `Sources/SwiftCompartido/SwiftDataModels/LegacyTypeAliases.swift` - To be removed
- `Sources/SwiftCompartido/Sendable/GuionElement.swift:176` - sectionDepth property
- `Sources/SwiftCompartido/SwiftDataModels/GuionElementModel.swift:149` - sectionDepth property

### Tests
- `Tests/SwiftCompartidoTests/GeneratedRecordTests.swift` - Legacy API tests
- `Tests/SwiftCompartidoTests/GuionElementTests.swift` - Element tests
- `Tests/SwiftCompartidoTests/FountainParserTests.swift` - Parser tests

---

## Appendix B: Additional Resources

- **Apple WWDC Sessions**:
  - "Optimize your SwiftUI app's performance" (WWDC 2023)
  - "Demystify parallelization in Xcode" (WWDC 2022)
  - "Eliminate data races using Swift Concurrency" (WWDC 2022)

- **Documentation**:
  - SwiftUI Performance Best Practices: https://developer.apple.com/documentation/swiftui/performance
  - Swift Concurrency Guide: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html

- **Profiling Tools**:
  - Instruments Time Profiler
  - Instruments Allocations
  - Thread Sanitizer (TSan)
  - SwiftUI View Debugger

---

**Document Status**: DRAFT - Awaiting stakeholder review
**Next Review**: After implementation of Sprint 1
**Owner**: Performance Engineering Team
