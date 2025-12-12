# UI Testing Strategy for SwiftCompartido

## Overview

This document defines the UI testing strategy for SwiftCompartido. UI tests validate that UI components correctly display screenplay elements and TypedDataStorage content, aligning with **Mission 2: UI Display**.

## Current Status

- **UI Source Files**: ~52 files
- **Existing UI Tests**: 12 test suites (TextConfigurationViewTests removed)
- **Coverage**: ~23% (12 of 52 components tested)
- **Test Plan**: `UITests.xctestplan`

## Testing Philosophy

### What to Test

**✅ DO TEST:**
1. **View initialization** - Views create without crashing
2. **Data binding** - Views correctly reflect model state
3. **View hierarchy** - Child views render as expected
4. **Conditional rendering** - Views show/hide based on state
5. **Layout behavior** - Views respond to size changes
6. **User interaction logic** - State changes from button taps, gestures
7. **Error states** - Views handle nil/empty data gracefully

**❌ DON'T TEST:**
1. **Exact pixel positioning** - Too brittle, changes with OS updates
2. **Font rendering** - System behavior, not our responsibility
3. **Animation timing** - Flaky in CI, hard to test reliably
4. **Visual appearance** - Use snapshot tests if needed (not included here)

### SwiftUI Testing Approach

Since SwiftUI views are declarative, we test:
1. **View creation** - Can we instantiate the view without crashing?
2. **Observable state** - Does changing @State/@Binding update the view?
3. **View logic** - Helper methods and computed properties work correctly
4. **Integration** - Views work with real SwiftData models

## Test Organization

### Test Plan Structure

SwiftCompartido uses Xcode Test Plans to organize tests:

**UnitTests.xctestplan** - Fast model/logic tests (~300 tests, 2-5 min)
- Parsers, models, serialization, storage logic

**UITests.xctestplan** - UI component tests (~12 suites currently, target: ~30 suites)
- Element views, list widgets, TypedDataStorage display
- **Run in parallel with UnitTests**

**PerformanceTests.xctestplan** - Performance benchmarks (runs separately)
- GuionTextEditor rendering, parsing speed

**LongTests.xctestplan** - Slow integration tests (weekends only)
- Complex workflows, file I/O with progress, large documents

### Parallel Execution Strategy

UI tests run **simultaneously** with unit tests to maximize CI throughput:

```yaml
# .github/workflows/tests.yml
jobs:
  unit-tests-ios:
    runs-on: macos-26
    steps:
      - run: xcodebuild test -testPlan UnitTests ...

  unit-tests-macos:
    runs-on: macos-26
    steps:
      - run: xcodebuild test -testPlan UnitTests ...

  ui-tests-ios:  # NEW - runs in parallel
    runs-on: macos-26
    steps:
      - run: xcodebuild test -testPlan UITests ...

  ui-tests-macos:  # NEW - runs in parallel
    runs-on: macos-26
    steps:
      - run: xcodebuild test -testPlan UITests ...
```

**Benefits:**
- ✅ Faster CI (tests run concurrently)
- ✅ Separate failure reporting (UI vs unit test failures)
- ✅ Independent code coverage (UI vs logic coverage)
- ✅ Clearer test output (no mixing of test types)

## Test Priority Matrix

### Priority 1: Main Viewers (CRITICAL - 5 components)

**GuionViewer.swift** - List-based screenplay viewer
```swift
@Test("GuionViewer displays elements from document")
func testGuionViewerDisplaysElements() { }

@Test("GuionViewer handles empty document")
func testGuionViewerEmptyDocument() { }

@Test("GuionViewer respects font size environment")
func testGuionViewerFontSize() { }
```

**GuionTextEditor.swift** - TextKit 2 high-performance viewer
```swift
@Test("GuionTextEditor renders document without crashing")
func testGuionTextEditorRenders() { }

@Test("GuionTextEditor handles font size changes")
func testGuionTextEditorFontSizeUpdate() { }

@Test("GuionTextEditor handles document updates")
func testGuionTextEditorDocumentUpdate() { }
```

**GuionElementsList.swift** - Element list widget
```swift
@Test("GuionElementsList displays all elements")
func testGuionElementsListDisplaysAll() { }

@Test("GuionElementsList filters by document")
func testGuionElementsListFiltersByDocument() { }

@Test("GuionElementsList preserves order")
func testGuionElementsListPreservesOrder() { }
```

**GuionElementsListHierarchy.swift** - Hierarchical list
```swift
@Test("GuionElementsListHierarchy shows chapters")
func testGuionElementsListHierarchyChapters() { }

@Test("GuionElementsListHierarchy collapses sections")
func testGuionElementsListHierarchyCollapse() { }
```

**GuionElementsListFromReference.swift** - Reference-based list
```swift
@Test("GuionElementsListFromReference displays filtered elements")
func testGuionElementsListFromReferenceFilters() { }
```

### Priority 2: TypedDataStorage Display (HIGH - 6 components)

**GeneratedContentListView.swift** - Content browser with filtering
```swift
@Test("GeneratedContentListView displays content")
func testGeneratedContentListViewDisplays() { }

@Test("GeneratedContentListView filters by MIME type")
func testGeneratedContentListViewFiltersByMIME() { }

@Test("GeneratedContentListView handles empty state")
func testGeneratedContentListViewEmptyState() { }
```

**TypedDataDetailView.swift** - Auto-routing content viewer
```swift
@Test("TypedDataDetailView routes text content")
func testTypedDataDetailViewRoutesText() { }

@Test("TypedDataDetailView routes audio content")
func testTypedDataDetailViewRoutesAudio() { }

@Test("TypedDataDetailView routes image content")
func testTypedDataDetailViewRoutesImage() { }

@Test("TypedDataDetailView routes video content")
func testTypedDataDetailViewRoutesVideo() { }
```

**TypedDataRowView.swift** - List row display
```swift
@Test("TypedDataRowView displays text metadata")
func testTypedDataRowViewTextMetadata() { }

@Test("TypedDataRowView displays audio metadata")
func testTypedDataRowViewAudioMetadata() { }

@Test("TypedDataRowView displays image metadata")
func testTypedDataRowViewImageMetadata() { }
```

**TypedDataAudioView.swift** - Audio content view
```swift
@Test("TypedDataAudioView displays audio record")
func testTypedDataAudioViewDisplays() { }

@Test("TypedDataAudioView handles missing file")
func testTypedDataAudioViewMissingFile() { }
```

**TypedDataTextView.swift** - Text content view
```swift
@Test("TypedDataTextView displays text content")
func testTypedDataTextViewDisplaysText() { }

@Test("TypedDataTextView handles long text")
func testTypedDataTextViewLongText() { }
```

**TypedDataVideoView.swift** - Video content view
```swift
@Test("TypedDataVideoView displays video record")
func testTypedDataVideoViewDisplays() { }

@Test("TypedDataVideoView handles missing file")
func testTypedDataVideoViewMissingFile() { }
```

### Priority 3: Widget Components (MEDIUM - 4 components)

**ElementProgressBar.swift** - Progress bar widget
```swift
@Test("ElementProgressBar displays progress")
func testElementProgressBarDisplaysProgress() { }

@Test("ElementProgressBar hides when complete")
func testElementProgressBarHidesComplete() { }

@Test("ElementProgressBar shows error state")
func testElementProgressBarErrorState() { }
```

**DialogueBlockView.swift** - Dialogue container
```swift
@Test("DialogueBlockView renders character and dialogue")
func testDialogueBlockViewRenders() { }

@Test("DialogueBlockView handles parenthetical")
func testDialogueBlockViewParenthetical() { }
```

**PreSceneBox.swift** - Scene pre-formatting
```swift
@Test("PreSceneBox displays over black transitions")
func testPreSceneBoxOverBlack() { }
```

**SpectrogramVisualizerView.swift** - Audio visualization
```swift
@Test("SpectrogramVisualizerView displays waveform data")
func testSpectrogramVisualizerViewDisplays() { }

@Test("SpectrogramVisualizerView handles empty data")
func testSpectrogramVisualizerViewEmpty() { }
```

### Priority 4: Markdown Views (LOW - 4 components)

**MarkdownActionView.swift**
```swift
@Test("MarkdownActionView renders markdown action")
func testMarkdownActionViewRenders() { }
```

**MarkdownSectionHeadingView.swift**
```swift
@Test("MarkdownSectionHeadingView renders heading levels")
func testMarkdownSectionHeadingViewLevels() { }
```

**MarkdownListItemView.swift**
```swift
@Test("MarkdownListItemView renders list items")
func testMarkdownListItemViewRenders() { }
```

**MarkdownListItemReferenceView.swift**
```swift
@Test("MarkdownListItemReferenceView renders references")
func testMarkdownListItemReferenceViewRenders() { }
```

### Priority 5: Helpers & Utilities (LOW - 6 components)

**FountainTextFormatter.swift** - Text formatting helper
```swift
@Test("FountainTextFormatter formats bold text")
func testFountainTextFormatterBold() { }

@Test("FountainTextFormatter formats italic text")
func testFountainTextFormatterItalic() { }

@Test("FountainTextFormatter formats underline text")
func testFountainTextFormatterUnderline() { }
```

**GuionElementContextMenuModifier.swift** - Context menu
```swift
@Test("GuionElementContextMenuModifier adds context menu")
func testGuionElementContextMenuModifierAdds() { }
```

## Test Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
**Goal**: Test critical user-facing viewers

1. Create test file structure:
   - `GuionViewerTests.swift`
   - `GuionTextEditorTests.swift`
   - `GuionElementsListTests.swift`

2. Implement Priority 1 tests (main viewers)
3. Update `UITests.xctestplan` with new test suites
4. Verify parallel execution in CI

**Success Criteria**: 5 new test suites, all main viewers tested

### Phase 2: TypedDataStorage Display (Weeks 3-4)
**Goal**: Test content display widgets

1. Create test files:
   - `GeneratedContentListViewTests.swift`
   - `TypedDataDetailViewTests.swift`
   - `TypedDataRowViewTests.swift`
   - `TypedDataAudioViewTests.swift`
   - `TypedDataTextViewTests.swift`
   - `TypedDataVideoViewTests.swift`

2. Implement Priority 2 tests
3. Update test plan

**Success Criteria**: 6 new test suites, TypedDataStorage display fully tested

### Phase 3: Widget Components (Week 5)
**Goal**: Test supporting widgets

1. Create test files:
   - `ElementProgressBarTests.swift`
   - `DialogueBlockViewTests.swift`
   - `PreSceneBoxTests.swift`
   - `SpectrogramVisualizerViewTests.swift`

2. Implement Priority 3 tests
3. Update test plan

**Success Criteria**: 4 new test suites, widget components tested

### Phase 4: Markdown & Helpers (Week 6)
**Goal**: Complete coverage for lower-priority components

1. Create test files:
   - `MarkdownViewTests.swift` (combined for all 4 markdown views)
   - `FountainTextFormatterTests.swift`
   - `GuionElementContextMenuTests.swift`

2. Implement Priority 4 & 5 tests
3. Update test plan

**Success Criteria**: Full UI coverage, all components tested

## Test Patterns

### Pattern 1: View Instantiation Test
```swift
@Test("View renders without crashing")
@MainActor
func testViewRenders() throws {
    let element = GuionElementModel(
        elementText: "Test",
        elementType: .action
    )

    let view = ActionView(element: element)
        .environment(\.screenplayFontSize, 12)

    // If we get here without crashing, the test passes
    #expect(element.elementText == "Test")
}
```

### Pattern 2: State-Driven Rendering Test
```swift
@Test("View updates when state changes")
@MainActor
func testViewStateUpdate() throws {
    let progressState = ElementProgressState()
    let elementID = PersistentIdentifier(/* ... */)

    // Set initial progress
    progressState.setProgress(0.5, for: elementID)

    // Verify state
    let progress = progressState.progress(for: elementID)
    #expect(progress?.progress == 0.5)

    // Update progress
    progressState.setComplete(for: elementID)

    // Verify updated state
    let updatedProgress = progressState.progress(for: elementID)
    #expect(updatedProgress?.isComplete == true)
}
```

### Pattern 3: Integration Test with SwiftData
```swift
@Test("View integrates with SwiftData models")
@MainActor
func testViewIntegration() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: GuionDocumentModel.self,
        configurations: config
    )

    let document = GuionDocumentModel()
    let element = GuionElementModel(
        elementText: "Test scene",
        elementType: .sceneHeading
    )
    document.elements.append(element)
    container.mainContext.insert(document)

    let view = GuionViewer(document: document)

    // Verify document has elements
    #expect(document.elements.count == 1)
}
```

### Pattern 4: Error State Test
```swift
@Test("View handles missing data gracefully")
@MainActor
func testViewHandlesMissingData() {
    let record = TypedDataStorage(
        providerId: "test",
        requestorID: "test",
        mimeType: "audio/mpeg",
        binaryValue: nil,
        prompt: "Test",
        fileReference: nil  // Missing file
    )

    // View should not crash with missing file
    let view = TypedDataAudioView(
        record: record,
        storageArea: nil
    )

    // If we get here, the view handled the error gracefully
    #expect(record.fileReference == nil)
}
```

## CI Integration

### Parallel Test Workflow

Create `.github/workflows/ui-tests.yml`:

```yaml
name: UI Tests

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  ui-tests-ios:
    name: iOS UI Tests
    runs-on: macos-26
    timeout-minutes: 15

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

      - name: Run UI tests on iOS Simulator
        run: |
          xcodebuild test \
            -scheme SwiftCompartido \
            -sdk iphonesimulator \
            -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' \
            -testPlan UITests \
            -enableCodeCoverage YES \
            -parallel-testing-enabled YES \
            CODE_SIGNING_ALLOWED=NO

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          flags: ui-tests-ios

  ui-tests-macos:
    name: macOS UI Tests
    runs-on: macos-26
    timeout-minutes: 15

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

      - name: Run UI tests on macOS
        run: |
          xcodebuild test \
            -scheme SwiftCompartido \
            -destination 'platform=macOS' \
            -testPlan UITests \
            -enableCodeCoverage YES \
            -parallel-testing-enabled YES \
            CODE_SIGNING_ALLOWED=NO

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          flags: ui-tests-macos
```

### Test Execution Flow

```
PR Created/Updated
    ├─► Code Quality (1 min)
    │
    ├─► Unit Tests iOS (parallel) ─────► 2-5 min
    │
    ├─► Unit Tests macOS (parallel) ───► 2-5 min
    │
    ├─► UI Tests iOS (parallel) ───────► 3-7 min
    │
    └─► UI Tests macOS (parallel) ─────► 3-7 min

Total Time: ~7 min (parallelized)
vs. Sequential: ~15 min
```

## Coverage Goals

**Current**: ~23% (12 of 52 UI components tested)

**Phase 1 Target**: ~33% (17 of 52 components)
**Phase 2 Target**: ~56% (29 of 52 components)
**Phase 3 Target**: ~64% (33 of 52 components)
**Phase 4 Target**: ~77% (40+ of 52 components)

**Final Goal**: **75%+ UI test coverage** (all user-facing components tested)

## Maintenance

### Adding New UI Components

When adding a new UI component:

1. **Create test file** in `Tests/SwiftCompartidoTests/`
2. **Add to UITests.xctestplan** under `selectedTests`
3. **Write minimum tests**:
   - View renders without crashing
   - View handles nil/empty data
   - View updates with state changes
4. **Run locally**: `xcodebuild test -testPlan UITests`
5. **Verify CI passes** before merging

### Test Maintenance

- **Review quarterly** - Remove obsolete tests, update for API changes
- **Monitor flakiness** - Tests that fail intermittently should be fixed or removed
- **Update documentation** - Keep this strategy doc in sync with reality

## Resources

- **Test Plans**: `UITests.xctestplan`, `UnitTests.xctestplan`
- **CI Workflows**: `.github/workflows/tests.yml`, `.github/workflows/ui-tests.yml`
- **Coverage Reports**: Codecov (separate flags for UI vs unit tests)
- **Test Documentation**: This file (`.claude/docs/UI_TESTING_STRATEGY.md`)
