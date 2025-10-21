# Changelog

All notable changes to SwiftCompartido will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.1] - 2025-10-21

### 🔄 TypedDataStorage Migration & Enhanced CloudKit Support

This release completes the migration to a unified `TypedDataStorage` model for all AI-generated content, replacing four separate record types while maintaining complete backward compatibility. Enhanced CloudKit support with automatic asset management and comprehensive progress reporting for file I/O operations.

### Changed

#### Unified Storage Architecture
- **TypedDataStorage replaces 4 separate models** (zero breaking changes)
  - `GeneratedTextRecord`, `GeneratedAudioRecord`, `GeneratedImageRecord`, `GeneratedEmbeddingRecord` are now type aliases to `TypedDataStorage`
  - All existing code continues to work without modifications
  - Type aliases will be removed in v3.0.0 - migrate to `TypedDataStorage` for future-proofing
  - MIME-type routing: Automatically handles `text/*`, `image/*`, `audio/*`, `application/x-embedding`

```swift
// Backward compatible (still works)
let record = GeneratedAudioRecord(/* ... */)

// Recommended for new code
let record = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "tts.rachel",
    mimeType: "audio/mpeg",
    binaryValue: audioData,
    prompt: "Generate speech",
    audioFormat: "mp3"
)

// Convenience initializer from DTO
let audioDTO = GeneratedAudioData(/* ... */)
let record = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "tts.rachel",
    data: audioDTO,
    prompt: "Generate speech"
)
```

#### Smart Storage Optimization
- **Automatic storage routing based on content size**
  - Text < 10KB: Stored in-memory (`textValue` property)
  - Text ≥ 10KB: File-based storage with `TypedDataFileReference`
  - Audio/Images: Always file-based storage (Phase 6 architecture)
  - Embeddings: Flexible in-memory or file-based

```swift
// Small text - stored in memory automatically
try record.saveText("Short text", mode: .local)  // No storage area needed

// Large text - saved to file automatically
try record.saveText(largeText, to: storage, fileName: "text.txt", mode: .local)
```

### Added

#### Enhanced CloudKit Integration
- **Automatic asset management for CloudKit sync**
  - Automatically populates `cloudKitAsset` field for `.cloudKit` and `.hybrid` storage modes
  - Auto-updates `syncStatus` from `.localOnly` to `.pending` when CloudKit is enabled
  - Seamless integration with SwiftData sync infrastructure
  - No manual asset management required

```swift
// CloudKit asset automatically populated
let record = TypedDataStorage(/* ... */)
try record.saveBinary(audioData, to: storage, fileName: "audio.mp3", mode: .cloudKit)

// cloudKitAsset is now populated
// syncStatus automatically set to .pending
// Ready for CloudKit sync
```

#### Chunked File I/O with Progress Reporting
- **Large file operations with byte-level progress tracking**
  - Chunk size: 1MB (1,048,576 bytes)
  - Progress updates during write operations
  - Progress updates during read operations
  - Works with files > 1MB
  - Force-flush final progress update for reliability

```swift
// Save with progress tracking
let progress = OperationProgress(totalUnits: Int64(audioData.count)) { update in
    print("\(update.description) - \(Int((update.fractionCompleted ?? 0) * 100))%")
}

try record.saveBinary(audioData, to: storage, fileName: "audio.mp3", mode: .local, progress: progress)

// Load with progress tracking
let loadProgress = OperationProgress(totalUnits: nil)
let loaded = try record.getBinary(from: storage, progress: loadProgress)
```

#### Content Retrieval Enhancements
- **Intelligent content loading with fallback chain**
  - Priority 1: CloudKit asset (if available)
  - Priority 2: In-memory content (`textValue` or `binaryValue`)
  - Priority 3: File-based storage (via `fileReference`)
  - Progress reporting supported for all sources
  - Transparent to caller - automatically selects best source

```swift
// Automatically tries CloudKit first, then in-memory, then file
let data = try record.getBinary(from: storage, progress: progress)
```

#### Convenience Initializers
- **Direct creation from DTO types**
  - `TypedDataStorage.init(data: GeneratedTextData, ...)`
  - `TypedDataStorage.init(data: GeneratedAudioData, ...)`
  - `TypedDataStorage.init(data: GeneratedImageData, ...)`
  - `TypedDataStorage.init(data: GeneratedEmbeddingData, ...)`
  - Automatically extracts all metadata from DTO
  - Simplifies record creation

#### Save Methods with Enhanced CloudKit Support
- **`saveBinary(_:to:fileName:mode:progress:)`** - Save binary content with optional CloudKit sync
- **`saveText(_:to:fileName:mode:progress:)`** - Save text with smart storage routing
- **`saveEmbedding(_:to:fileName:mode:progress:)`** - Save embedding vectors
- All methods support `.local`, `.cloudKit`, and `.hybrid` storage modes
- Automatic `cloudKitAsset` population for sync-enabled modes
- Progress reporting optional (nil-safe for backward compatibility)

### Fixed

#### File I/O and Progress Reporting
- **Test suite alignment with new APIs**
  - Updated 3 load progress tests to pass `progress` parameter to `getBinary()`
  - Fixed 2 filename tests to use `fileReference.fileURL(in:)` instead of default file paths
  - All 13 FileIOProgressTests now passing
  - All 17 CloudKitSupportTests now passing

#### CloudKit Asset Management
- **Automatic asset population for all sync modes**
  - `.cloudKit` mode: Populates `cloudKitAsset`, sets `syncStatus = .pending`
  - `.hybrid` mode: Saves both local file AND `cloudKitAsset`
  - `.local` mode: No CloudKit asset (unchanged behavior)

### Documentation

#### Updated Documentation Files
- **CLAUDE.md**: Added TypedDataStorage migration section with usage patterns
- **README.md**: Updated all examples to use TypedDataStorage
- **AI-REFERENCE.md**: Will be updated with TypedDataStorage API documentation (in progress)
- All code examples modernized to v2.0.1 patterns

### Testing

- **390 tests across 26 suites** (95%+ coverage)
  - Added FileIOProgressTests: 13 tests for chunked I/O with progress
  - CloudKitSupportTests: 17 tests for CloudKit sync patterns
  - All tests passing with new TypedDataStorage architecture
- **Comprehensive migration validation**
  - Type aliases work identically to TypedDataStorage
  - No SwiftData migration needed
  - Full backward compatibility verified

### Migration Guide

**No action required** - all existing code continues to work unchanged. However, for future-proofing:

#### Recommended Migration Steps

1. **Update direct usages (optional, recommended)**
   ```swift
   // Before (still works)
   let record = GeneratedAudioRecord(/* ... */)

   // After (recommended)
   let record = TypedDataStorage(
       providerId: "provider",
       requestorID: "requestor",
       mimeType: "audio/mpeg",
       binaryValue: audioData,
       prompt: "Generate",
       audioFormat: "mp3"
   )
   ```

2. **Use convenience initializers from DTOs**
   ```swift
   let audioDTO = GeneratedAudioData(/* ... */)
   let record = TypedDataStorage(
       providerId: "provider",
       requestorID: "requestor",
       data: audioDTO,
       prompt: "Generate"
   )
   ```

3. **Update save/load methods**
   ```swift
   // New unified API
   try record.saveBinary(audioData, to: storage, fileName: "audio.mp3", mode: .hybrid)
   let loaded = try record.getBinary(from: storage, progress: progress)
   ```

4. **Optional: Add progress reporting**
   ```swift
   let progress = OperationProgress(totalUnits: nil) { update in
       print(update.description)
   }
   try record.saveBinary(audioData, to: storage, fileName: "audio.mp3", progress: progress)
   ```

**Timeline**: Type aliases (`GeneratedTextRecord`, etc.) will be removed in v3.0.0. Migrate before then to avoid breaking changes.

## [2.0.0] - 2025-10-20

### 🎯 Element Ordering Architecture, Mac Catalyst Support & Critical Bug Fixes

Major release improving screenplay element ordering with chapter-based spacing, adding full Mac Catalyst compatibility, fixing critical ordering bugs, and reorganizing SwiftData models for better maintainability.

### Added

#### Chapter-Based Composite Ordering (chapterIndex, orderIndex)
- **Intelligent chapter detection with composite key ordering**
  - Pre-chapter elements: `chapterIndex=0`, `orderIndex=1,2,3...`
  - Chapter 1 elements: `chapterIndex=1`, `orderIndex=1,2,3...`
  - Chapter 2 elements: `chapterIndex=2`, `orderIndex=1,2,3...`
  - And so on...
  - Automatic chapter detection via section heading level 2
  - **No element limit per chapter** - orderIndex is sequential within each chapter
  - Elements sorted by `(chapterIndex, orderIndex)` composite key
  - Allows inserting elements within chapters while maintaining global order

```swift
// Chapter ordering automatically applied during conversion
let document = await GuionDocumentParserSwiftData.parse(
    script: screenplay,
    in: context
)

// Pre-chapter elements: chapter Index=0, orderIndex=1, 2, 3...
// Chapter 1 heading: chapterIndex=1, orderIndex=1
// Chapter 1 elements: chapterIndex=1, orderIndex=2, 3, 4...
// Chapter 2 heading: chapterIndex=2, orderIndex=1
// Chapter 2 elements: chapterIndex=2, orderIndex=2, 3, 4...

// Elements are always sorted by (chapterIndex, orderIndex)
for element in document.sortedElements {
    print("Chapter \(element.chapterIndex), Position \(element.orderIndex): \(element.elementText)")
}
```

#### SwiftData Model Organization
- **Extracted models into separate files for better maintainability**
  - `GuionElementModel.swift` (262 lines) - Individual screenplay elements
  - `TitlePageEntryModel.swift` (64 lines) - Title page metadata entries
  - `GuionDocumentModel.swift` reduced from 1,049 → 793 lines
  - Better code organization and navigation

#### OrderIndex Safety Features
- **`GuionDocumentModel.sortedElements` computed property**
  - Always returns elements in correct screenplay order
  - Protects against SwiftData relationship ordering issues
  - Comprehensive documentation with DO/DON'T examples

```swift
// ✅ DO: Use sortedElements for display/export
for element in document.sortedElements {
    displayElement(element)
}

// ❌ DON'T: Use elements directly (order not guaranteed)
for element in document.elements {  // Wrong - may be out of order
    displayElement(element)
}
```

#### Comprehensive Regression Testing
- **17 new tests preventing ordering bugs** (363 total tests)
  - 7 chapter-based ordering tests (`ElementOrderingTests`)
  - 10 UI regression tests (`UIOrderingRegressionTests`)
  - Tests cover: UI display, export, serialization, round-trip conversions
  - Large dataset tests (500+ elements)
  - Mixed content tests (dialogue/action/scenes)

#### Mac Catalyst Compatibility
- **Removed all macOS-specific conditional compilation**
  - `FDXParser.swift`: Removed `#if canImport(FoundationXML)` conditionals
  - `TextConfigurationView.swift`: Removed `#if os(macOS)` conditionals
  - `GuionDocumentModel.swift`: Replaced `.withSecurityScope` with `[]` for bookmarks
  - Library now builds seamlessly on Mac Catalyst without platform-specific code
  - All UI components work across macOS, iOS, and Mac Catalyst

```swift
// Before: Platform-specific conditionals
#if os(macOS) || targetEnvironment(macCatalyst)
.formStyle(.grouped)
#endif

// After: Works on all platforms
.formStyle(.grouped)

// Before: Security-scoped bookmarks (macOS-only)
let bookmark = try url.bookmarkData(options: .withSecurityScope, ...)

// After: Standard bookmarks (cross-platform)
let bookmark = try url.bookmarkData(options: [], ...)
```

### Fixed

#### Critical Ordering Bugs
- **Bug 1**: `toGuionParsedElementCollection()` used unsorted elements
  - Elements could export in wrong order
  - Now uses `sortedElements` to maintain screenplay sequence

- **Bug 2**: `sceneLocations` returned scenes out of order
  - Scene extraction didn't respect orderIndex
  - Now uses `sortedElements` for correct sequence

- **Bug 3**: `reparseAllLocations()` iterated without order
  - Location reparsing was non-deterministic
  - Now uses `sortedElements` for predictable behavior

- **Bug 4**: Serialization lost element order
  - `GuionDocumentSnapshot` didn't preserve order
  - Now uses `sortedElements` when creating snapshots

### Changed

#### UI Improvements
- **Removed visible separators in GuionElementsList**
  - Clean, seamless flow between elements
  - No divider lines between screenplay elements
  - Traditional screenplay appearance maintained

- **Enhanced character name spacing in DialogueCharacterView**
  - Increased top padding (`fontSize * 1.5`) for more separation from previous element
  - Decreased bottom padding (`fontSize * 0.2`) to bring character name closer to dialogue
  - Follows traditional screenplay formatting conventions

```swift
// Applied to all element types in the list
.listRowSeparator(.hidden)
.listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

// Character name spacing
.padding(.top, fontSize * 1.5)    // More space above
.padding(.bottom, fontSize * 0.2)  // Closer to dialogue
```

#### API Improvements
- **Enhanced `GuionDocumentModel` with ordering guarantees**
  - `sceneLocations` now returns scenes in screenplay order
  - `reparseAllLocations()` processes scenes in order
  - All helper methods respect orderIndex

### Documentation

- **CHANGELOG.md**: This comprehensive v2.0.0 release notes
- **README.md**: Updated version badge to 2.0.0, chapter-based ordering examples, Mac Catalyst support
- **AI-REFERENCE.md**: Added orderIndex patterns, anti-patterns, and Catalyst guidance
- **CLAUDE.md**: Updated architecture guidance with ordering requirements and platform compatibility

### Testing

- **All 363 tests passing** across 25 test suites
  - ElementOrderingTests: 19 tests (12 existing + 7 new)
  - UIOrderingRegressionTests: 10 tests (NEW)
  - 95%+ code coverage maintained
  - No regressions in existing functionality

### Migration Guide

**No breaking changes** - all changes are backward compatible:

```swift
// Existing code continues to work
let document = await GuionDocumentParserSwiftData.parse(
    script: screenplay,
    in: context
)

// New: Use sortedElements for guaranteed order
let elements = document.sortedElements  // ✅ Always in order

// Chapter-based spacing applied automatically
// No code changes needed - works transparently
```

**Recommended Updates**:
```swift
// Before (may have ordering issues):
for element in document.elements {
    processElement(element)
}

// After (guaranteed order):
for element in document.sortedElements {
    processElement(element)
}
```

### Impact

- **Risk**: Very Low (backward compatible, extensive testing)
- **Breaking Changes**: None
- **Files Changed**: 14 files total
  - 8 source files (3 new, 5 modified)
  - 2 new test files
  - 4 documentation files updated
- **Performance**: Negligible (<1% overhead for sorting)
- **Test Coverage**: 95%+ maintained, 17 new tests added
- **Platform Expansion**: Now supports Mac Catalyst in addition to macOS and iOS

### Platform Support

- ✅ **macOS 26.0+**: Full support
- ✅ **iOS 26.0+**: Full support
- ✅ **Mac Catalyst 26.0+**: Full support

### What's Next

The orderIndex architecture and Catalyst support provide foundation for:
- Element insertion within chapters
- Screenplay reorganization tools
- Drag-and-drop reordering
- Multi-chapter screenplay management
- Cross-platform screenplay editing (macOS, iOS, Mac Catalyst)
- Universal SwiftUI apps with shared codebase


## [1.5.0] - 2025-10-20

### 📝 API Refinement: GuionParsedElementCollection

Minor release improving API naming consistency and adding async progress support to the main screenplay parsing entry point.

### Changed

#### Naming Consistency
- **GuionParsedScreenplay → GuionParsedElementCollection**
  - More accurate name reflecting that it's a collection of screenplay elements
  - `GuionParsedScreenplay` retained as deprecated typealias for backward compatibility
  - All documentation updated to emphasize `GuionParsedElementCollection`
  - Zero breaking changes - existing code continues to work with deprecation warnings

#### Enhanced Progress Support
- Added async convenience initializers to `GuionParsedElementCollection`:
  - `init(file:parser:progress:)` - Parse from file with optional progress tracking
  - `init(string:parser:progress:)` - Parse from string with optional progress tracking
  - Progress propagates to underlying `FountainParser` for seamless tracking
- All initializers include comprehensive documentation with DO/DON'T examples
- Emphasizes `GuionParsedElementCollection` as the recommended entry point over direct parser usage

### Documentation

- **README.md**: All examples updated to use `GuionParsedElementCollection`
  - Progress reporting examples enhanced
  - ✅ DO / ❌ DON'T patterns added
- **AI-REFERENCE.md**: Complete rewrite of parser guidance
  - Emphasizes `GuionParsedElementCollection` as primary API
  - Discourages direct `FountainParser`/`FDXParser` usage
  - Added comprehensive "Why GuionParsedElementCollection?" section
- **CLAUDE.md**: Architecture guide updated
  - Model categories updated with new name
  - All code examples use `GuionParsedElementCollection`
  - Pattern guidance reinforced

### Testing

- **All 314 tests updated and passing** across 22 test suites
- Fixed async initialization calls across all test files
- No test coverage regression
- 95%+ coverage maintained

### Migration Guide

**No migration required** - `GuionParsedScreenplay` is a deprecated typealias that continues to work:

```swift
// Old API (deprecated, but still works):
let screenplay = try GuionParsedScreenplay(file: path)

// New API (recommended):
let screenplay = try await GuionParsedElementCollection(file: path)

// With progress tracking:
let progress = OperationProgress(totalUnits: nil) { update in
    print(update.description)
}
let screenplay = try await GuionParsedElementCollection(
    string: fountainText,
    progress: progress
)
```

### Deprecated

- **GuionParsedScreenplay**: Deprecated in favor of `GuionParsedElementCollection`
  - Compiler will show deprecation warning with migration message
  - Full backward compatibility maintained via typealias

### Impact

- **Risk**: Very Low (typealias ensures 100% backward compatibility)
- **Breaking Changes**: None (typealias preserves old name)
- **Files Changed**: 1 core file, 6 extensions, 11 source files, 3 documentation files, all test files
- **Performance**: No change (naming only)

### Platform Support

- ✅ **macOS 26.0+**: Full support
- ✅ **iOS 26.0+**: Full support
- ✅ **Mac Catalyst 26.0+**: Full support

## [1.4.3] - 2025-10-20

### 🎨 UI Architecture Simplification & Source File Tracking

Major release simplifying UI architecture to a flat, list-based display pattern and adding comprehensive source file tracking for screenplay documents.

### Added

#### Source File Tracking (NEW)
- **Security-Scoped Bookmarks**: Track original screenplay source files across app launches
- **Automatic Change Detection**: Detect when imported files are modified externally
- **Three New Properties** on `GuionDocumentModel`:
  - `sourceFileBookmark: Data?` - Security-scoped bookmark to source file
  - `lastImportDate: Date?` - When document was last imported
  - `sourceFileModificationDate: Date?` - Mod date of source at import time
- **Four New Methods** on `GuionDocumentModel`:
  - `setSourceFile(_ url: URL) -> Bool` - Create bookmark and record dates
  - `resolveSourceFileURL() -> URL?` - Resolve bookmark to URL
  - `isSourceFileModified() -> Bool` - Quick check for changes
  - `sourceFileStatus() -> SourceFileStatus` - Detailed status information
- **SourceFileStatus Enum**: `.noSourceFile`, `.fileNotAccessible`, `.fileNotFound`, `.modified`, `.upToDate`
- **Documentation**: Comprehensive SOURCE_FILE_TRACKING.md guide (430 lines)
- **Platform Support**: Works seamlessly with macOS sandboxing and file permissions

#### New UI Component
- **GuionElementsList**: Flat, @Query-based SwiftData list component (NEW - 73 lines)
  - Replaces hierarchical SceneBrowserWidget architecture
  - Simple switch/case for each element type
  - Displays elements sequentially in document order
  - Optional document filtering via `init(document:)` or all elements via `init()`
  - Direct SwiftData @Query - no intermediate models

### Changed

#### UI Architecture Simplification
- **GuionViewer**: Simplified from **479 lines to 52 lines** (89% reduction)
  - Removed complex file loading, error handling, browser data
  - Now just a thin wrapper around GuionElementsList
  - Takes `document: GuionDocumentModel` instead of screenplay
  - API change: `GuionViewer(document: model)` replaces `GuionViewer(screenplay: parsed)`
- **Display Pattern**: Changed from hierarchical to flat
  - Elements displayed sequentially in document order
  - No grouping or nesting
  - Simple, predictable layout
  - Better performance with large documents

### Fixed

#### Text Truncation Bug
- **ActionView.swift**: Fixed multi-line action truncation with "..."
  - Removed GeometryReader causing height collapse in VStack
  - Now uses simple padding-based layout (10% margins)
  - Full multi-line paragraphs display correctly
- **DialogueTextView.swift**: Fixed dialogue truncation
  - Removed GeometryReader causing height collapse
  - Now uses HStack with spacers (25% left/right margins)
  - Multi-line dialogue displays without truncation

### Removed

#### Deprecated Components
- **SceneBrowserWidget**: Replaced by GuionElementsList
  - Was complex hierarchical display with 400+ lines
  - Grouped elements by scene and chapter
  - Required intermediate BrowserData model
- **ChapterWidget**: No longer needed
  - Part of hierarchical architecture
  - Grouped scenes into chapters
- **SceneGroupWidget**: No longer needed
  - Grouped dialogue blocks within scenes
  - Added complexity without clear benefit
- **DialogueBlockView**: No longer needed
  - Grouped character+dialogue+parenthetical
  - Now individual elements displayed sequentially

### Testing

- **Test Count**: 314 tests across 22 suites (up from 275/20)
  - Added comprehensive source file tracking tests
  - All existing tests pass with new flat architecture
- **Coverage**: 95%+ overall coverage maintained
- **Parallel Testing**: CI now uses 80% of available CPUs
  - FAST_TESTING.md guide added
  - 2-3x faster test execution

### Documentation

- **SOURCE_FILE_TRACKING.md** (NEW - 430 lines): Comprehensive guide
  - Complete API documentation
  - Usage patterns (on launch, periodic, user-initiated)
  - SwiftUI integration examples
  - Security considerations for sandboxed apps
  - Example re-import flow
- **FAST_TESTING.md** (NEW): Parallel testing guide
  - Performance comparisons
  - Configuration examples
  - CI integration
- **CLAUDE.md**: Updated with flat architecture and source tracking
- **AI-REFERENCE.md**: Updated with new APIs and deprecated components
- **README.md**: Updated examples and test counts

### Migration Guide

#### UI Components (BREAKING CHANGE)

**Old API (deprecated):**
```swift
let screenplay = parser.parse(text)
GuionViewer(screenplay: screenplay)
```

**New API (1.4.3):**
```swift
// Parse and convert to SwiftData
let screenplay = parser.parse(text)
let document = await GuionDocumentParserSwiftData.parse(
    script: screenplay,
    in: modelContext
)

// Display using document model
GuionViewer(document: document)
```

**Flat vs Hierarchical:**
- Elements now display in document order (no grouping)
- To customize display, create your own view using GuionElementsList as example
- For hierarchical navigation, implement custom filtering on @Query

#### Source File Tracking (OPTIONAL - Non-Breaking)

**To enable tracking on import:**
```swift
let document = await GuionDocumentParserSwiftData.parse(
    script: screenplay,
    in: modelContext
)

// Set source file
let success = document.setSourceFile(sourceURL)
try modelContext.save()

// Later: check for updates
if document.isSourceFileModified() {
    showUpdatePrompt()
}
```

**No code changes required** if you don't need source file tracking.

### Impact

- **Risk**: Medium (UI API change)
- **Breaking Changes**: GuionViewer API change (screenplay → document parameter)
- **Backward Compatibility**: Source file tracking is fully backward compatible
- **Files Changed**: 5 source files, 4 documentation files
- **Performance**: Improved (simpler code path, fewer intermediate objects)

### Platform Support

- ✅ **macOS 26.0+**: Full support including security-scoped bookmarks
- ✅ **iOS 26.0+**: Full support including security-scoped bookmarks
- ✅ **Mac Catalyst 26.0+**: Full support

## [1.3.2] - 2025-10-19

### 🔧 Mac Catalyst Compatibility

Minor patch release fixing Mac Catalyst compatibility in UI components and adding automated CI checks.

### Fixed
- **SceneBrowserWidget.swift**: Added platform-specific background color handling
  - macOS: Uses `.windowBackgroundColor`
  - iOS/Catalyst: Uses `.systemBackground`
  - Prevents `windowBackgroundColor` compilation errors on Catalyst

### Added
- **CI/CD Enhancement**: Automated Mac Catalyst build validation
  - New `catalyst-build` job in GitHub Actions workflow
  - Builds for both x86_64 and arm64 Mac Catalyst targets
  - Intelligent API compatibility checker using Python script
  - Detects unguarded macOS-specific APIs (`windowBackgroundColor`, `NSColor`, `NSFont`)
  - Handles nested `#if/#endif` blocks correctly
  - Non-blocking (continues even if SwiftData limitations cause build failures)
  - Uploads build logs as artifacts for debugging
  - Generates detailed summary with known platform limitations

### Platform Support
- ✅ **macOS 26.0+**: Full native support
- ✅ **iOS 26.0+**: Full native support
- ⚠️ **Mac Catalyst 26.0+**: UI components compatible where platform allows
  - Known limitation: SwiftData has limited Catalyst support (platform issue, not code issue)
  - All UI components properly guarded for Catalyst compatibility

### Testing
- All 275 tests pass on macOS/iOS native builds
- No regressions introduced
- CI validates Catalyst API compatibility on every PR

### Impact
- **Risk**: Very Low
- **Breaking Changes**: None
- **Backward Compatibility**: 100% maintained
- **Files Changed**: 2 (1 source file + 1 CI workflow)

## [1.3.0] - 2025-10-19

### 📊 Comprehensive Progress Reporting

Major enhancement adding progress reporting to all long-running operations with full SwiftUI integration, cancellation support, and minimal performance overhead.

### Added

#### Core Progress System
- **`OperationProgress`**: Main progress tracking class with handler callbacks
  - Thread-safe, `Sendable`, and fully Swift 6 compliant
  - Batched updates (max 100/second) for optimal performance
  - Support for both determined (with total units) and indeterminate progress
- **`ProgressUpdate`**: Immutable progress snapshot with:
  - `completedUnits` and `totalUnits` (Int64)
  - `fractionCompleted` (Double, 0.0-1.0)
  - Human-readable `description` messages
- **`ProgressHandler`**: Type alias for progress update callbacks

#### Progress-Enabled Operations

**FountainParser (9 features):**
- Async `FountainParser.init(string:progress:)` with line-by-line tracking
- Title page parsing progress
- Element parsing progress (batched every 10 elements)
- Line counting and fraction completion
- Full cancellation support

**FDXParser (8 features):**
- Async `FDXParser.init(data:progress:)` with element tracking
- XML parsing progress reporting
- Element conversion tracking
- Title page extraction progress

**TextPack Reader (9 features):**
- `TextPackReader.readTextPack(from:progress:)` with stage-based tracking
- Metadata parsing progress
- Resource loading progress
- Screenplay reconstruction progress

**TextPack Writer (8 features):**
- Async `TextPackWriter.createTextPack(from:progress:)` with 5 stages:
  1. Creating bundle metadata (10%)
  2. Generating screenplay.fountain (30%)
  3. Extracting character data (20%)
  4. Extracting location data (20%)
  5. Writing resource files (20%)
- Full cancellation with cleanup

**SwiftData Operations (7 features):**
- Async `GuionDocumentParserSwiftData.parse(script:in:generateSummaries:progress:)`
- Element-by-element conversion tracking
- Updates every 10 elements for efficiency
- AI summary generation progress (when enabled)
- Async `loadAndParse(from:in:generateSummaries:progress:)` for all formats

**File I/O Operations (7 features):**
- Async `GeneratedAudioRecord.saveAudio(_:to:mode:progress:)` with byte-level tracking
  - 1MB chunk size for efficient streaming
  - CloudKit upload progress indication
  - Automatic partial file cleanup on cancellation
- Async `GeneratedAudioRecord.loadAudio(from:progress:)` with chunked reading
- Async `GeneratedImageRecord.saveImage(_:to:mode:progress:)` with byte-level tracking
- Async `GeneratedImageRecord.loadImage(from:progress:)` with chunked reading
- Hybrid storage mode with progress for both local and CloudKit

#### SwiftUI Integration
- Seamless integration with `ProgressView`
- Works with `@Published` properties and `ObservableObject`
- Actor-isolated progress handlers for main-thread updates
- Example `ParserViewModel` in README.md

#### Cancellation Support
- All progress-enabled operations check `Task.checkCancellation()`
- Automatic cleanup of partial files on cancellation
- Proper `CancellationError` throwing
- Verified across all 7 phases

#### Testing & Quality
- **99 new tests** across 7 new test suites:
  - `OperationProgressTests.swift` (7 tests - Phase 0)
  - `ProgressUpdateTests.swift` (7 tests - Phase 0)
  - `FountainParserProgressTests.swift` (9 tests - Phase 1)
  - `FDXParserProgressTests.swift` (8 tests - Phase 2)
  - `TextPackWriterProgressTests.swift` (14 tests - Phase 4)
  - `SwiftDataProgressTests.swift` (13 tests - Phase 5)
  - `FileIOProgressTests.swift` (13 tests - Phase 6)
  - `IntegrationTests.swift` (8 tests - Phase 7)
- **Total test count**: 275 tests across 20 suites (up from 176)
- **Coverage**: 95%+ overall, 90%+ for all new progress code
- **Performance verified**: <2% overhead confirmed in integration tests

#### Documentation
- Comprehensive "Progress Reporting" section in CLAUDE.md
- Progress examples in README.md with SwiftUI integration
- Updated all API documentation with progress parameters
- 7-phase implementation guide in `PROGRESS_REQUIREMENTS.md`

### Changed
- All async operations now accept optional `progress: OperationProgress?` parameter
- Progress parameters default to `nil` (100% backward compatible)
- Test suite expanded from 176 to 275 tests (20 suites)
- Version bumped to 1.3.0 reflecting minor feature addition

### Performance Characteristics
- **Overhead**: <2% of operation time (verified in performance tests)
- **Update frequency**: Batched to max 100 updates/second
- **Memory**: Bounded - no accumulation of progress updates
- **Concurrency**: Full Swift 6 compliance with actor isolation
- **Thread safety**: All progress APIs are `Sendable` and thread-safe

### Migration Guide

**No migration required** - all progress parameters are optional and default to `nil`. Existing code continues to work without modifications.

**To adopt progress reporting:**

```swift
// Before (still works):
let parser = try GuionParsedScreenplay(file: path)

// After (with progress):
let progress = OperationProgress(totalUnits: nil) { update in
    print(update.description)
}
let parser = try await FountainParser(string: text, progress: progress)
```

**SwiftUI integration:**

```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var progressMessage = ""
    @Published var progressFraction = 0.0

    func parse(_ text: String) async throws {
        let progress = OperationProgress(totalUnits: nil) { update in
            Task { @MainActor in
                self.progressMessage = update.description
                self.progressFraction = update.fractionCompleted ?? 0.0
            }
        }
        let parser = try await FountainParser(string: text, progress: progress)
    }
}
```

## [1.2.1] - 2025-10-18

### Fixed

#### Critical CloudKit Conflict Resolution Bug
- **CRITICAL**: Fixed data loss bug in `CloudKitSyncable.resolveConflict()` method
- Added `modifiedAt` property to `CloudKitSyncable` protocol for timestamp-based conflict resolution
- Conflict resolution now correctly compares modification timestamps when `conflictVersion` values are equal
- Previous behavior: Always preferred local copy when versions matched, potentially discarding remote changes
- New behavior: Compares `modifiedAt` timestamps to determine which record is most recent
- Particularly important for newly created records (which all start at version 1)
- Added 4 comprehensive tests to prevent regression:
  - Higher version number preference
  - Equal versions use most recent timestamp
  - Equal versions and timestamps prefer local (rare edge case)
  - Newly created records conflict handling

**Migration Impact:** None - this is a pure bug fix with no API changes. Existing code continues to work unchanged.

## [1.2.0] - 2025-10-18

### ☁️ CloudKit Sync Support

Major enhancement adding CloudKit synchronization capabilities while maintaining 100% backward compatibility with existing local-only code.

### Added

#### CloudKit Features
- **Dual Storage System**: Seamlessly sync between local `.guion` bundles and CloudKit
- **Three Storage Modes**: `.local` (default), `.cloudKit`, and `.hybrid` per-record configuration
- **CloudKitSyncable Protocol**: Unified interface for sync-enabled models
- **Automatic Fallback**: Transparently loads from CloudKit or local storage
- **Conflict Resolution**: Built-in version tracking with `conflictVersion` and `cloudKitChangeTag`
- **Sync Status Tracking**: `.pending`, `.synced`, `.conflict`, `.failed`, `.localOnly` states

#### Model Enhancements
- All `*Record` models now include optional CloudKit properties:
  - `cloudKitRecordID`: CloudKit record identifier
  - `cloudKitChangeTag`: Change detection token
  - `lastSyncedAt`: Sync timestamp
  - `syncStatus`: Current sync state
  - `ownerUserRecordID`: Owner tracking for multi-user support
  - `sharedWith`: Sharing permissions array
  - `conflictVersion`: Version counter for conflict resolution
  - `storageMode`: `.local`, `.cloudKit`, or `.hybrid`
  - `cloudKit*Asset`: External storage for large files

#### Configuration Utilities
- **SwiftCompartidoContainer**: Factory for common container configurations
  - `makeLocalContainer()`: Local-only storage (default)
  - `makeCloudKitPrivateContainer()`: Private CloudKit database
  - `makeCloudKitAutomaticContainer()`: Automatic CloudKit configuration
  - `makeHybridContainer()`: Mixed local and CloudKit storage
- **ModelConfiguration Extensions**: Convenient CloudKit setup
- **SwiftCompartidoSchema**: Centralized schema definition
- **CKDatabase.isCloudKitAvailable()**: Check iCloud availability

#### Dual Storage Methods
- `GeneratedAudioRecord.saveAudio(_:to:mode:)`: Save with storage mode selection
- `GeneratedAudioRecord.loadAudio(from:)`: Load with automatic fallback
- `GeneratedTextRecord.saveText(_:to:mode:)`: Text storage with mode support
- `GeneratedTextRecord.loadText(from:)`: Text loading with fallback
- `GeneratedImageRecord.saveImage(_:to:mode:)`: Image storage with mode support
- `GeneratedImageRecord.loadImage(from:)`: Image loading with fallback
- `GeneratedEmbeddingRecord.saveEmbedding(_:to:mode:)`: Embedding storage
- `GeneratedEmbeddingRecord.loadEmbedding(from:)`: Embedding loading

#### Testing
- **17 new CloudKit tests** in `CloudKitSupportTests.swift`
- Tests for all three storage modes (.local, .cloudKit, .hybrid)
- Dual storage verification tests
- Backward compatibility tests (all 159 existing tests still pass)
- Protocol conformance tests

### Changed
- **BREAKING**: Minimum platform requirements increased to **macOS 26.0+** and **iOS 26.0+**
  - Removed all `@available` attributes (no longer needed)
  - Package now enforces platform requirements directly
- Removed custom `@Attribute(.transformable)` decorators from `TypedDataFileReference` properties
  - SwiftData now handles `Codable` types natively
  - Improves CloudKit compatibility
- Updated documentation with CloudKit usage examples
- Enhanced model descriptions to include sync status
- Test suite expanded from 159 to 176 tests (12 suites)

### Documentation
- **README.md**: Added CloudKit feature section and usage examples
- **CLAUDE.md**: Added "CloudKit Sync Patterns" section with migration guide
- Comprehensive CloudKit examples for all storage modes

### Migration Guide

**Platform Requirement Change:**
- Apps must now target **macOS 26.0+** and **iOS 26.0+**
- Update your deployment target in Xcode project settings
- This is the only breaking change

**Code Migration:**
Existing code using SwiftCompartido 1.0.0 requires **zero code changes**:
- All records default to `.local` storage mode
- Phase 6 architecture works identically
- CloudKit features are entirely opt-in per record
- No breaking changes to APIs or behavior

To enable CloudKit for new records:
```swift
let record = GeneratedTextRecord(
    // ... existing parameters
    storageMode: .cloudKit  // Add this parameter
)
```

## [1.0.0] - 2025-10-18

### 🎉 Initial Release

First production-ready release of SwiftCompartido - a comprehensive Swift package for screenplay management, AI-generated content storage, and document serialization.

### Added

#### Core AI Models
- **AIResponseData**: Modern response type with typed content (text, audio, image, structured data)
- **UsageStats**: Consolidated token/cost tracking across all AI operations
- **AIRequestStatus**: Request lifecycle tracking with progress support
- **AIServiceError**: Comprehensive error handling with recovery suggestions and retry logic

#### Generated Content Models
- **GeneratedTextRecord**: SwiftData model for storing AI-generated text
- **GeneratedAudioRecord**: SwiftData model for audio with file reference support
- **GeneratedImageRecord**: SwiftData model for images with efficient file storage
- **GeneratedEmbeddingRecord**: SwiftData model for vector embeddings

#### Storage System
- **TypedDataFileReference**: Lightweight file references with metadata and checksums
- **StorageAreaReference**: Request-scoped storage management
- **Phase 6 Architecture**: File-based storage pattern for optimal performance

#### Screenplay Management
- **FountainParser**: Complete Fountain format parsing
- **FDXParser**: Final Draft XML import
- **FDXDocumentWriter**: FDX export with full metadata support
- **FountainWriter**: Fountain format export
- **GuionElement**: Rich screenplay element model with hierarchy support
- **ElementType**: Complete element type system (scenes, dialogue, action, etc.)
- **TextPack**: Bundle format for screenplay + resources

#### Data Models
- **GuionDocument**: FileDocument wrapper for screenplay files
- **GuionDocumentModel**: SwiftData persistence model
- **Voice/VoiceModel**: TTS voice configuration and persistence
- **CharacterInfo**: Character extraction and metadata
- **SceneLocation**: Scene location tracking
- **SceneSummarizer**: Automatic scene analysis

#### UI Components
- **GuionViewer**: Screenplay rendering with proper formatting
- **SceneBrowser**: Hierarchical scene navigation
- **SceneBrowserWidget**: Individual scene display component
- **TextConfigurationView**: AI text generation settings UI
- **AudioPlayerManager**: Audio playback with waveform visualization
- **SpectrogramVisualizerView**: Audio waveform display

#### Utilities
- **SerializationFormat**: Screenplay format detection
- **OutputFileType**: Export format configuration
- **ProviderCategory**: AI provider categorization
- **AICredential**: Secure credential storage

### Features

#### Screenplay Processing
- ✅ Full Fountain format support with all element types
- ✅ FDX import/export with Final Draft compatibility
- ✅ Outline parsing with 6 levels of section headings
- ✅ Character extraction with scene mapping
- ✅ Location extraction and tracking
- ✅ Scene summarization
- ✅ Title page metadata parsing
- ✅ Dual dialogue support
- ✅ Scene numbering

#### AI Content Management
- ✅ Type-safe content handling (text, audio, image, structured)
- ✅ File-based storage for large content (audio, images)
- ✅ In-memory storage for small content (text)
- ✅ Automatic storage strategy selection
- ✅ Request lifecycle tracking
- ✅ Progress monitoring
- ✅ Usage statistics aggregation
- ✅ Cost tracking across providers

#### Audio Playback
- ✅ Direct file URL playback (efficient)
- ✅ In-memory data playback (fallback)
- ✅ Automatic storage detection
- ✅ Play/pause/stop controls
- ✅ Seeking support
- ✅ Duration tracking
- ✅ Audio level visualization
- ✅ Progress updates at 60 FPS

#### Data Persistence
- ✅ SwiftData integration
- ✅ Efficient file storage
- ✅ Checksum verification
- ✅ Metadata tracking
- ✅ Timestamp management
- ✅ Request-scoped storage areas

### Architecture

#### Design Patterns
- **Phase 6 Architecture**: Separate in-memory and file storage
- **Model Pairs**: DTO/SwiftData model separation
- **Sendable Conformance**: Full Swift 6 concurrency support
- **Type Safety**: Strongly typed content with enums
- **Error Handling**: Comprehensive error types with recovery

#### Performance Optimizations
- File-based storage prevents main thread blocking
- Lazy loading for large content
- Efficient database queries with fetch limits
- Background file I/O operations
- Minimal memory footprint

### Testing

- **159 tests** across 11 test suites
- **95%+ code coverage** on consolidated models
- **Swift Testing** framework
- Comprehensive integration tests
- Edge case coverage
- Error scenario testing

#### Test Coverage by Category
- AI Response Models: 30 tests
- Generated Content Records: 21 tests
- Storage System: 31 tests
- Serialization: 35 tests
- Audio Playback: 13 tests
- UI Components: 12 tests
- Parsing & Export: 17 tests

### Documentation

#### User Documentation
- **README.md**: Comprehensive user guide with examples
- **USAGE-SUMMARY.md**: Quick reference for common patterns
- **AI-REFERENCE.md**: Detailed guide for AI assistants
- **CONTRIBUTING.md**: Contribution guidelines
- **CHANGELOG.md**: Version history (this file)

#### API Documentation
- All public APIs documented
- Code examples for major features
- SwiftUI integration examples
- Error handling patterns
- Performance best practices

### Technical Details

#### Swift Version
- Requires Swift 5.9+
- Swift 6 concurrency ready
- All models are `Sendable`

#### Platform Support
- macOS 14.0+
- iOS 17.0+
- File storage features require macOS 15.0+ / iOS 17.0+

#### Dependencies
- Foundation
- SwiftData
- SwiftUI
- AVFoundation
- UniformTypeIdentifiers

### Breaking Changes
N/A - Initial release

### Deprecated
N/A - Initial release

### Removed

#### Consolidated Models (Pre-release cleanup)
The following models were removed before v1.0.0 in favor of the Phase 6 architecture:

- **AIResponse**: Replaced by `AIResponseData` (more modern, type-safe)
  - Old: Simple `Data` content
  - New: Typed `ResponseContent` enum
  - Migration: Use `AIResponseData` with typed content

- **AIResponse.Usage**: Replaced by `UsageStats`
  - Old: No duration tracking
  - New: Includes `durationSeconds`
  - Migration: Use `UsageStats` directly

- **AIGeneratedContent Models**: Replaced by file-based records
  - `GeneratedText` → `GeneratedTextRecord`
  - `GeneratedAudio` → `GeneratedAudioRecord`
  - `GeneratedImage` → `GeneratedImageRecord`
  - `GeneratedStructuredData` → Use `GeneratedTextRecord` with JSON
  - `GeneratedVideo` → To be added in future version

### Migration Guide
N/A - Initial release

### Known Issues
None at release time.

### Security
- No known security vulnerabilities
- Credentials stored securely using SwiftData
- File integrity verification with checksums

### Contributors
- Core team
- Built with assistance from [Claude Code](https://claude.com/claude-code)

### Special Thanks
- Swift community for Swift Testing framework
- Apple for SwiftData and SwiftUI
- All beta testers and early adopters

---

## [Unreleased]

### Planned for v1.1.0
- [ ] PDF screenplay export
- [ ] Enhanced audio waveform visualization
- [ ] Batch processing optimizations
- [ ] Additional screenplay format support
- [ ] Performance monitoring tools
- [ ] Advanced error recovery mechanisms

### Under Consideration
- [ ] Video content support (GeneratedVideoRecord)
- [ ] Cloud storage provider integration
- [ ] Advanced screenplay analytics
- [ ] Screenplay collaboration features
- [ ] Real-time sync capabilities

---

## Version History

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Incompatible API changes
- **MINOR**: Backward-compatible functionality additions
- **PATCH**: Backward-compatible bug fixes

### Release Schedule

- **Major releases**: Yearly
- **Minor releases**: Quarterly
- **Patch releases**: As needed

### Support Policy

- **Latest major version**: Full support
- **Previous major version**: Security updates for 12 months
- **Older versions**: Community support only

---

## Links

- **Repository**: https://github.com/intrusive-memory/SwiftCompartido
- **Issues**: https://github.com/intrusive-memory/SwiftCompartido/issues
- **Discussions**: https://github.com/intrusive-memory/SwiftCompartido/discussions
- **Releases**: https://github.com/intrusive-memory/SwiftCompartido/releases

---

**Note**: This changelog follows the principles from [Keep a Changelog](https://keepachangelog.com/en/1.0.0/). All notable changes to this project are documented here.

**Last Updated**: 2025-10-20
