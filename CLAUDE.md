# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftCompartido is a Swift package for screenplay management, AI-generated content storage, and document serialization. The library uses **Phase 6 Architecture** - a file-based storage pattern that separates in-memory data transfer objects (DTOs) from file-persisted content to prevent main thread blocking.

**Platforms**: iOS 26.0+, macOS 26.0+

## ⚠️ CRITICAL: Library Scope and Focus

**SwiftCompartido has exactly TWO core missions. Every file, class, and function must directly support one of these:**

### Mission 1: Parsing & Storage
**Parse and store screenplay documents and AI-generated content**

✅ **BELONGS IN THIS LIBRARY:**
- Screenplay parsers (Fountain, FDX, PDF, Markdown, Highland, TextBundle, Pandoc)
- SwiftData models (GuionDocumentModel, GuionElementModel, TypedDataStorage, CharacterVoiceMapping)
- Storage infrastructure (TypedDataFileReference, StorageAreaReference, Phase 6 architecture)
- Serialization (JSON .guion format, TextPack, snapshots)
- MIME type routing and content type handling
- File I/O with progress reporting

### Mission 2: UI Display
**Display screenplay documents and AI-generated content with SwiftUI widgets**

✅ **BELONGS IN THIS LIBRARY:**
- Screenplay viewers (GuionTextEditor, GuionViewer, GuionElementsList)
- TypedDataStorage display (GeneratedContentListView, TypedDataDetailView, TypedDataRowView)
- Element widgets (ElementProgressBar, ElementProgressState, ElementProgressTracker)
- Audio playback UI (AudioPlayerManager with waveform visualization)
- Configuration UI (AppleTTSVoiceProviderPane, TextConfigurationView)
- Query-based list widgets with filtering and grouping

### ❌ DOES NOT BELONG IN THIS LIBRARY

If a file, class, or function does any of the following, it should be **deprecated, removed, or spun off into a separate library**:

- **AI Content Generation**: Text generation, TTS synthesis, image generation, embedding generation
  - ❌ OpenAI/Anthropic API clients
  - ❌ ElevenLabs TTS integration
  - ❌ DALL-E image generation
  - ❌ Foundation Models prompts
  - ✅ **Storing** generated content (TypedDataStorage) is OK
  - ✅ **Displaying** generated content (GeneratedContentListView) is OK
  - ❌ **Generating** content does NOT belong here

- **Cloud Sync**: CloudKit, Firebase, iCloud sync
  - ❌ Already removed in 6.2.1

- **External Service Integration**: API clients, service wrappers
  - ❌ These belong in consumer apps or separate service libraries

- **Business Logic**: Workflow orchestration, state machines, complex automation
  - ❌ App-specific logic belongs in consumer apps
  - ✅ Library-specific logic (parsing workflows, storage routing) is OK

### Decision Framework

**When adding or modifying code, ask:**

1. **Does this parse or store screenplay/content data?**
   - YES → Belongs in Mission 1 ✅
   - NO → Continue to question 2

2. **Does this display screenplay/content data in SwiftUI?**
   - YES → Belongs in Mission 2 ✅
   - NO → Continue to question 3

3. **Does this support parsing, storage, or display?**
   - YES (file I/O, MIME routing, progress reporting) → OK ✅
   - NO → **REMOVE IT** ❌

**Examples:**

| Feature | Mission | Belongs? |
|---------|---------|----------|
| Fountain parser | Mission 1 (Parsing) | ✅ YES |
| TypedDataStorage model | Mission 1 (Storage) | ✅ YES |
| GuionTextEditor | Mission 2 (Display) | ✅ YES |
| GeneratedContentListView | Mission 2 (Display) | ✅ YES |
| File I/O with progress | Support (Mission 1) | ✅ YES |
| OpenAI API client | Generation | ❌ NO - Spin off |
| ElevenLabs TTS | Generation | ❌ NO - Spin off |
| CloudKit sync | Cloud Sync | ❌ NO - Removed in 6.2.1 |
| Foundation Models prompts | Generation | ❌ NO - Removed in 6.2.1 |

### Enforcement

**When reviewing code:**
- If a file/class doesn't clearly map to Mission 1 or Mission 2, flag it for removal
- If a feature involves external services (API calls, cloud sync), it doesn't belong here
- If a feature generates content (vs. storing/displaying it), it doesn't belong here

**This library is NOT:**
- An AI service wrapper
- A cloud sync framework
- A TTS/image generation toolkit
- A workflow orchestration engine

**This library IS:**
- A screenplay parser and storage system
- A TypedDataStorage system for AI-generated content
- A SwiftUI widget library for displaying screenplays and content

## GuionViewer Reference Implementation

**Location**: `GuionViewer/` (in repository root)

GuionViewer is a minimal macOS demo app that serves as the **reference implementation** for SwiftCompartido. It demonstrates best practices for integrating the library with proper concurrency, performance, and UI patterns.

### Purpose
- **Showcase SwiftCompartido capabilities**: Parsing, storage, and display
- **Reference architecture**: Proper use of DocumentModelActor pattern
- **Integration example**: How to consume SwiftCompartido in real apps
- **Component reuse**: Demonstrates using SwiftCompartido's UI element views

### Architecture Highlights

1. **ModelActor Pattern**: Uses `DocumentModelActor` for all SwiftData operations
   - Actor isolation prevents data races
   - Returns Sendable DTOs (`DocumentInfo`, `ElementInfo`) to MainActor
   - Never passes Model instances across actor boundaries
   - Explicit sorting ensures elements are always in document order

2. **Infinite Scrolling**: Lazy-loads screenplay elements in batches
   - Starts with 100 elements, loads 100 more on scroll
   - Uses `LazyVStack` for performance
   - Smooth rendering of large documents (tested with 5000+ elements)

3. **Fixed Typography Layout**:
   - Fixed 12pt Courier New font (industry standard)
   - 102 character width (8.5" page equivalent)
   - Content centered in window (width: 734.4pt = 12pt × 0.6 × 102 chars)
   - Window resizable without affecting text size

4. **Component Reuse**: Uses SwiftCompartido's element views via DisplayableElement protocol
   - `SceneHeadingView<ElementInfo>`
   - `DialogueTextView<ElementInfo>`
   - `ActionView<ElementInfo>`
   - And 9+ other element-specific views
   - DTOs conform to DisplayableElement for seamless integration

5. **Bundle Resource Loading**: Dual-mode file discovery
   - Built app: Loads fixtures from app bundle Resources folder
   - Development: Falls back to project Fixtures folder
   - Filters for screenplay files only (fountain, fdx, pdf, highland, etc.)

### Key Files
- `GuionViewer/GuionViewer/GuionViewerApp.swift` - App entry point, ModelContainer setup
- `GuionViewer/GuionViewer/ContentView.swift` - Main UI with infinite scroll, fixed-width layout
- `Sources/SwiftCompartido/Actors/DocumentModelActor.swift` - Actor for safe SwiftData operations
- `GuionViewer/REQUIREMENTS.md` - Feature specifications

### Running GuionViewer
```bash
cd GuionViewer
xcodebuild build -scheme GuionViewer -destination 'platform=macOS'
open ~/Library/Developer/Xcode/DerivedData/GuionViewer-*/Build/Products/Debug/GuionViewer.app
```

### Code Example
```swift
// Initialize DocumentModelActor
let actor = DocumentModelActor(modelContainer: container)

// Parse screenplay in background
let documentID = try await actor.parseAndSaveDocument(from: url)

// Fetch Sendable DTOs for UI display
let docInfo = await actor.getDocumentInfo(documentID: documentID)
let elements = try await actor.getElements(for: documentID, limit: 100)

// Display with SwiftCompartido element views
ForEach(elements) { element in
    switch element.elementType {
    case .sceneHeading:
        SceneHeadingView(element: element)
    case .dialogue:
        DialogueTextView(element: element)
    // ... other element types
    }
}
```

**Use GuionViewer as a template when integrating SwiftCompartido into new apps.**

## ⚠️ CRITICAL: Platform Version Enforcement

**This library ONLY supports iOS 26.0+ and macOS 26.0+. NEVER add code that supports older platforms.**

### Rules for Platform Versions

1. **NEVER add `@available` attributes** for versions below iOS 26.0 or macOS 26.0
   - ❌ WRONG: `@available(iOS 15.0, macOS 12.0, *)`
   - ✅ CORRECT: No `@available` needed (package enforces iOS 26/macOS 26)

2. **NEVER add `#available` runtime checks** for versions below iOS 26.0 or macOS 26.0
   - ❌ WRONG: `if #available(iOS 15.0, *) { ... }`
   - ✅ CORRECT: No runtime checks needed (package enforces minimum versions)

3. **Platform-specific code is OK** (macOS vs iOS differences)
   - ✅ CORRECT: `#if os(macOS)` or `#if canImport(AppKit)`
   - ✅ CORRECT: `#if canImport(FoundationModels)` (framework availability)
   - ❌ WRONG: Checking for specific OS versions below 26

4. **Package.swift must always specify iOS 26 and macOS 26**
   ```swift
   platforms: [
       .iOS(.v26),
       .macOS(.v26)
   ]
   ```

5. **User-facing messages** must reflect iOS 26/macOS 26 requirements
   - ❌ WRONG: "Requires macOS 15 or iOS 18"
   - ✅ CORRECT: "Requires macOS 26 or iOS 26"

### Why This Matters

When this library is imported into apps that support older platforms (e.g., iOS 12), Xcode will show:
```
The package product 'SwiftCompartido' requires minimum platform version 26.0
for the iOS platform, but this target supports 12.0
```

This is **intentional and correct**. Apps using this library **must** update their deployment targets to iOS 26+ and macOS 26+.

**DO NOT lower the platform requirements to fix this error. Instead, consumers must raise their deployment targets.**

## File Format Parsing Flow

```mermaid
flowchart TD
    Start([GuionParsedElementCollection]) --> Detect{File Extension?}

    Detect -->|.md / .markdown| MD[Markdown Parser]
    Detect -->|.highland| Highland[Highland Handler]
    Detect -->|.textbundle| TextBundle[TextBundle Handler]
    Detect -->|.fdx| FDX[FDX Parser]
    Detect -->|.pdf| PDF[PDF Parser]
    Detect -->|.fountain / other| Fountain[Fountain Parser]

    MD --> YAMLExtract[Extract YAML Front Matter]
    YAMLExtract --> ConvertMD[Convert Markdown to Elements]
    ConvertMD --> Elements[screenplay.elements]

    FDX --> ParseXML[Parse Final Draft XML]
    ParseXML --> Elements

    PDF --> AIExtract[AI-Powered Extraction]
    AIExtract --> Elements

    Fountain --> ParseFountain[Parse Fountain Syntax]
    ParseFountain --> Elements

    Highland --> Extract[Extract ZIP Archive]
    Extract --> FindTB[Locate TextBundle Directory]
    FindTB --> FindFile{Find .fountain<br/>or .md file}
    FindFile -->|.fountain found| ForceFountain1[Use Fountain Parser]
    FindFile -->|.md found| ForceFountain2[Use Fountain Parser<br/>Highland .md = Fountain]
    ForceFountain1 --> ParseFountain
    ForceFountain2 --> ParseFountain

    TextBundle --> Discover[Find Content File]
    Discover --> RecursiveDetect{File Extension?}
    RecursiveDetect -->|.fountain| Fountain
    RecursiveDetect -->|.md| MD

    Elements --> Return([Return GuionParsedElementCollection])

    style Highland fill:#e1f5ff
    style ForceFountain2 fill:#fff3cd
    style MD fill:#d4edda
    style Elements fill:#f8d7da
```

**Critical Parsing Rules:**

1. **Standalone .md files** → Markdown parser with YAML front matter
2. **Highland .md files** → **Always Fountain parser** (Highland uses Fountain syntax)
3. **TextBundle .md files** → Markdown parser (recursive detection)
4. **TextBundle .fountain files** → Fountain parser (recursive detection)

## Performance Testing & Benchmarking

SwiftCompartido includes comprehensive performance testing to track rendering speed and detect regressions.

### Performance Test Suite

Located in `Tests/SwiftCompartidoTests/GuionViewerPerformanceTests.swift`, the suite measures:

- **Parsing performance**: GuionParsedElementCollection on 100-5000 element screenplays
- **SwiftData conversion**: Parse → SwiftData model creation time
- **Element access**: `sortedElements` retrieval performance
- **Text formatting**: FountainTextFormatter (bold, italic, underline) processing
- **End-to-end benchmarks**: Complete parse → render pipeline

**Run performance tests:**
```bash
xcodebuild test \
  -scheme SwiftCompartido \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Release \
  -only-testing:SwiftCompartidoTests/GuionViewerPerformanceTests \
  CODE_SIGNING_ALLOWED=NO
```

### Performance Baselines (Current)

**1000 Elements:**
- Parse: 0.016s
- Convert: 1.127s (94% of total) ← Primary bottleneck
- Format: 0.054s
- **Total: 1.200s**

**5000 Elements:**
- Parse: 0.072s
- Convert: 23.732s (99% of total) ← Primary bottleneck
- Format: 0.234s
- **Total: 24.050s**

**Bottleneck Analysis:**
1. SwiftData conversion scales poorly (1.1s → 23.7s for 5x elements)
2. Text formatting is efficient (~1% of total time)
3. Parsing is negligible (< 1% of total time)

### Build-to-Build Performance Tracking

**PerformanceMetricsTracker** automatically records metrics and exports JSON reports:

```swift
// Automatically tracked in tests
await PerformanceMetricsTracker.shared.recordMetric(
    testName: "ParseAndRender_1000",
    elementCount: 1000,
    parseTime: 0.016,
    convertTime: 1.127,
    sortTime: 0.003,
    formatTime: 0.054
)
```

**JSON Output Location:** `/tmp/performance_results/performance_*.json`

**Automatic Comparison:**
- Compares current run with previous baseline
- Detects regressions >10%
- Prints diff report in test output

**CI Integration:**
- Performance tests run after unit tests pass (non-blocking)
- JSON reports uploaded as artifacts (90-day retention)
- Available for download from GitHub Actions

**View Reports:**
```bash
# Local
ls /tmp/performance_results/
cat /tmp/performance_results/performance_*.json | jq '.'

# CI Artifacts
# Download from GitHub Actions → Artifacts → performance-results
```

### Future Optimization Targets

Based on current baselines, TextKit 2 implementation should target:
- **SwiftData conversion**: Pre-compute during parsing phase
- **Text rendering**: Viewport-based layout (only render visible elements)
- **Memory usage**: 30-50% reduction via lazy loading

See `.claude/skills/performance-tracking.md` for advanced tracking strategies.

## Essential Build Commands

⚠️ **CRITICAL**: This is an **Apple Silicon-only** iOS 26 and macOS 26 library.

**Build Requirements:**
- **Apple Silicon (arm64) Mac** required for development
- **macOS 26.0+** required
- **Xcode 17.0+** required
- **DO NOT use `swift build` or `swift test`** directly - they fail with macOS version errors

**Use the build script:**
```bash
./build.sh                  # Build for iOS Simulator (arm64)
./build.sh --action test    # Run all tests
./build.sh --help           # Show all options
```

**Or use xcodebuild:**
```bash
# Build for iOS Simulator (Apple Silicon only)
xcodebuild build \
  -scheme SwiftCompartido \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO

# Run tests on iOS Simulator (arm64)
xcodebuild test \
  -scheme SwiftCompartido \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -enableCodeCoverage YES \
  CODE_SIGNING_ALLOWED=NO

# Build for macOS (Apple Silicon only)
xcodebuild build \
  -scheme SwiftCompartido \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO

# Test on macOS (arm64)
xcodebuild test \
  -scheme SwiftCompartido \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES \
  CODE_SIGNING_ALLOWED=NO
```

**Architecture Notes:**
- All builds target **arm64 (Apple Silicon) only**
- Intel (x86_64) builds are **not supported**
- CI runs exclusively on **macos-26** (Apple Silicon GitHub runners)
- iOS Simulator tests use **iPhone 17 Pro** (arm64 simulator)

## Core Architecture Patterns

### Model Pairs Pattern

Each data type has TWO models:

1. **DTO Models** (in-memory, Sendable): `GeneratedTextData`, `GeneratedAudioData`, `GeneratedImageData`, `GeneratedEmbeddingData`
   - Used for transferring data between actors/threads
   - Short-lived, never persisted

2. **SwiftData Models** (persistent):
   - **Primary**: `TypedDataStorage` - Unified model for all AI-generated content
   - **Legacy**: `GeneratedTextRecord`, `GeneratedAudioRecord`, etc. (deprecated type aliases)

**DO NOT consolidate DTO models** - they serve different purposes.

### Phase 6 Storage Architecture

Large content (audio, images) follows this pattern:

1. Background thread: Generate content → Write to file in `StorageAreaReference`
2. Create lightweight `TypedDataFileReference` (metadata only)
3. Main thread: Store file reference in SwiftData (NOT the data)
4. Playback/display: Load from file URL directly

**Storage decision tree:**
- Text < 10KB: Store in `TypedDataStorage.textValue`
- Text ≥ 10KB: Write to file, store `TypedDataFileReference`
- Audio/Images: ALWAYS use file storage
- Embeddings: In-memory or file-based

### Element Ordering

**CRITICAL: Always use `document.sortedElements`** - SwiftData @Relationship arrays do NOT guarantee order!

```swift
// ❌ WRONG - Order not guaranteed
for element in document.elements { }

// ✅ CORRECT - Always sorted
for element in document.sortedElements { }
```

Elements use composite key ordering: `(chapterIndex, orderIndex)`

### SwiftData Relationships and Cascade Delete Strategy

**IMPORTANT**: All `@Relationship` decorators omit the `inverse:` parameter to avoid macro expansion circular reference errors. SwiftData automatically infers inverse relationships.

#### Relationship Graph

```
GuionDocumentModel (parent)
    ├─→ elements: [GuionElementModel] (@Relationship deleteRule: .cascade)
    ├─→ titlePage: [TitlePageEntryModel] (@Relationship deleteRule: .cascade)
    ├─→ customPages: [CustomPageModel] (@Relationship deleteRule: .cascade)
    ├─→ casting: [CharacterVoiceMapping] (@Relationship deleteRule: .cascade) [NEW in 6.2.0]
    └─→ generatedContent: [TypedDataStorage] (@Relationship deleteRule: .cascade)

GuionElementModel
    ├─→ document: GuionDocumentModel? (@Relationship deleteRule: .nullify)
    └─→ generatedContent: [TypedDataStorage] (@Relationship deleteRule: .cascade)

CharacterVoiceMapping (leaf node) [NEW in 6.2.0]
    └─→ document: GuionDocumentModel? (@Relationship deleteRule: .nullify)

TypedDataStorage (leaf node)
    ├─→ owningElement: GuionElementModel? (@Relationship deleteRule: .nullify)
    └─→ owningDocument: GuionDocumentModel? (@Relationship deleteRule: .nullify)

CustomPageModel (leaf node)
    └─→ document: GuionDocumentModel? (no @Relationship decorator)

TitlePageEntryModel (leaf node)
    └─→ document: GuionDocumentModel? (no @Relationship decorator)
```

#### Cascade Delete Behavior

**When a document is deleted:**
- ✅ All elements are automatically deleted (`.cascade`)
- ✅ All title page entries are automatically deleted (`.cascade`)
- ✅ All document-level generated content is automatically deleted (`.cascade`)
- ✅ Element-level generated content is deleted via element cascade

**When an element is deleted:**
- ✅ All element-level generated content is automatically deleted (`.cascade`)
- ❌ Parent document is NOT deleted (`.nullify`)

**When generated content is deleted:**
- ❌ Owning element is NOT deleted (`.nullify`)
- ❌ Owning document is NOT deleted (`.nullify`)

**Why no `inverse:` parameters?**

The `inverse:` parameter in `@Relationship` macros can cause circular reference errors during macro expansion in Swift 6. By omitting them:
1. SwiftData still correctly infers bidirectional relationships
2. All cascade delete rules work as expected
3. Macro expansion completes without circular reference errors
4. The relationship graph remains functionally identical

**Example: Proper relationship usage**

```swift
// ✅ CORRECT - Document owns elements
@Model
class GuionDocumentModel {
    @Relationship(deleteRule: .cascade)  // No inverse: parameter
    var elements: [GuionElementModel]
}

// ✅ CORRECT - Element references document
@Model
class GuionElementModel {
    @Relationship(deleteRule: .nullify)  // No inverse: parameter
    var document: GuionDocumentModel?
}

// Result: Deleting document cascades to elements, but deleting element doesn't affect document
```

## ⚠️ Known Issues and Migration Notes

### Binary Payload Migration (6.2.0+)

**CRITICAL DATA LOSS RISK**: The binary storage column was renamed from `binaryValue` to `_compressedBinaryValue` with LZFSE compression added in version 6.2.0. This creates a migration issue for existing SwiftData stores.

**Problem:**
- Old column: `binaryValue` (uncompressed binary data)
- New column: `_compressedBinaryValue` (LZFSE compressed)
- New accessor: `binaryValue` (computed property, decompresses `_compressedBinaryValue`)
- **Existing stores**: `_compressedBinaryValue` is nil for all prior records, even though data exists in old `binaryValue` column
- **Result**: Calls like `getContent()` return nil/throw for previously persisted audio/image/video payloads

**Affected Data:**
- All `TypedDataStorage` records with binary content (audio, images, video) created before 6.2.0
- `binaryValue` accessor returns nil because `_compressedBinaryValue` is nil
- Original data still exists in old column but is inaccessible

**Required Fix:**
```swift
// Migration pseudocode (needs implementation)
// 1. Read legacy binaryValue column (direct database access)
// 2. Compress with LZFSE
// 3. Write to _compressedBinaryValue
// 4. Clear old binaryValue column

// OR: Fallback approach
// Add computed property that checks both columns:
public var binaryValue: Data? {
    get {
        // Try new compressed column first
        if let compressed = _compressedBinaryValue {
            return try? decompress(compressed)
        }
        // Fallback to legacy uncompressed column
        return _legacyBinaryValue
    }
    set {
        // Always write to new compressed column
        _compressedBinaryValue = newValue.map { compress($0) }
    }
}
```

**Workaround Until Fixed:**
- Apps upgrading from pre-6.2.0 should re-generate all binary content
- OR: Export to .guion JSON format before upgrading (preserves data)
- OR: Implement custom migration code

**Status**: **UNRESOLVED** - Migration path not implemented

### DocumentModelActor Element Ordering

**Issue**: Elements were potentially returned out of order from `getElements()` due to SwiftData relationship ordering not being guaranteed.

**Fixed in**: 6.3.0

**Solution**: Added explicit sorting by composite key `(chapterIndex, orderIndex)` in `DocumentModelActor.getElements()`. Elements are now always returned in correct document order.

## Key Directories

- `Sources/SwiftCompartido/Models/` - All data models
- `Sources/SwiftCompartido/UI/` - SwiftUI components
- `Sources/SwiftCompartido/SwiftDataModels/` - SwiftData @Model classes
- `Sources/SwiftCompartido/Actors/` - Actor-based concurrency (DocumentModelActor)
- `Tests/SwiftCompartidoTests/` - Test suites
- `GuionViewer/` - Reference implementation demo app (macOS)

## Testing Requirements

- **Minimum coverage**: 90% (current: 95%+)
- **Test framework**: Swift Testing for new tests, XCTest for legacy
- Use `@Test("description")` macro, not `func test...`
- All tests must pass before merging PRs

### Test Plans Organization

SwiftCompartido uses **test plans** (.xctestplan files) to organize tests into four categories:

#### 1. **UnitTests.xctestplan** (Runs on every PR)
- **Fast unit tests** for basic functionality
- Tests models, enums, parsers (small inputs), serialization
- **Non-UI tests** focused on testing classes and structs
- Target: < 1 second per test, < 5 minutes total
- **Excludes**: UI tests, integration tests, performance tests

**Examples:**
- `CharacterInfoTests`, `ElementTypeEnumTests`, `FountainRegexesTests`
- `GeneratedAudioDataTests`, `GeneratedTextDataTests`
- `MarkdownParserTests`, `OutlineLevelParsingTests`
- `SerializationFormatTests`, `ProviderCategoryTests`
- `ScreenplayRenderingFormatTests`, `ScreenplayDocumentRenderingTests` (NEW in 6.3.1)

#### 2. **LongTests.xctestplan** (Runs on weekends)
- **Integration tests** with file I/O and complex workflows
- Tests with **large data sets** or **multiple iterations**
- **Progress callback tests** with delays
- Parser tests on large/real documents
- Runs: Saturdays and Sundays at 2 AM UTC

**Examples:**
- `IntegrationTests`, `FountainParserTests` (comprehensive)
- `PDFScreenplayParserTests`, `PandocIntegrationTests`
- `FountainParserProgressTests`, `FDXParserProgressTests`
- `SwiftDataProgressTests`, `FileIOProgressTests`
- `TypedDataStorageTests`, `TextPackTests`

#### 3. **UITests.xctestplan** (Optional, run manually or on weekends)
- **SwiftUI view tests** and UI component tests
- Gesture handling, hover states, popovers
- Accessibility tests

**Examples:**
- `ElementViewTests`, `SceneBrowserUITests`
- `TextConfigurationViewTests`, `TypedDataImageViewTests`
- `GuionElementPopoverProviderTests`, `InteractivePopoverTests`
- `LongPressGestureTests`, `HoverTimingTests`

#### 4. **PerformanceTests.xctestplan** (Runs after unit tests, non-blocking)
- **Performance benchmarks only**
- Tests in files with "Performance" in the class/struct name
- Runs in Release configuration for accurate measurements
- Results uploaded as CI artifacts (don't block PRs)

**Examples:**
- `GuionViewerPerformanceTests`, `GuionTextEditorPerformanceTests`
- `Phase2PerformanceTests`

### Running Tests Locally

```bash
# Run unit tests (default for PRs)
xcodebuild test -scheme SwiftCompartido -testPlan UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run long tests
xcodebuild test -scheme SwiftCompartido -testPlan LongTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run UI tests
xcodebuild test -scheme SwiftCompartido -testPlan UITests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run performance tests
xcodebuild test -scheme SwiftCompartido -testPlan PerformanceTests \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### ⚠️ Adding New Tests - IMPORTANT

When adding new tests, you **MUST** categorize them into the correct test plan:

#### Unit Tests (UnitTests.xctestplan)
- ✅ Fast (< 1 second per test)
- ✅ Tests basic functionality of non-UI classes/structs
- ✅ Model tests (Codable, initialization, validation)
- ✅ Small parser inputs (< 100 lines)
- ❌ NO file I/O or heavy operations
- ❌ NO SwiftUI view tests
- ❌ NO performance benchmarks

#### Long Tests (LongTests.xctestplan)
- ✅ Integration tests with file I/O
- ✅ Large data sets or many iterations
- ✅ Progress callback tests with delays
- ✅ Parser tests on realistic documents (1000+ lines)
- ✅ End-to-end workflow tests
- ❌ NO UI tests (move to UITests.xctestplan)
- ❌ NO performance tests (move to PerformanceTests.xctestplan)

#### UI Tests (UITests.xctestplan)
- ✅ SwiftUI view rendering tests
- ✅ Gesture handlers, hover states
- ✅ Accessibility tests
- ✅ Any test that imports SwiftUI for view testing

#### Performance Tests (PerformanceTests.xctestplan)
- ✅ **MUST** be in a separate file
- ✅ **MUST** have "Performance" in class/struct name
- ✅ Benchmarking parse/render/serialize operations
- ✅ Timing measurements and metrics

**To add a test suite to a test plan:**
Edit the corresponding `.xctestplan` file and add the test suite name to `selectedTests` or `skippedTests`

**Decision tree:**
1. Is it a performance benchmark? → `PerformanceTests.xctestplan`
2. Does it test SwiftUI views? → `UITests.xctestplan`
3. Does it do heavy I/O or take > 1 second? → `LongTests.xctestplan`
4. Otherwise → `UnitTests.xctestplan`

**Goal:** Keep unit tests under 5 minutes for fast PR feedback

### Screenplay Rendering Tests (NEW in 6.3.1)

SwiftCompartido includes comprehensive rendering validation tests that ensure screenplay elements render correctly according to industry standards.

**Two Test Suites (45 tests total):**

#### ScreenplayRenderingFormatTests (32 tests)
Validates individual element rendering against industry-standard formatting:

**Page Width & Layout:**
- 65 characters per line (industry standard)
- Courier aspect ratio: 0.6 (character width = 60% of font size)
- Page width consistency across font sizes (8pt - 24pt)
- 54 lines per page, 1.5x line spacing

**Element Margins** (as percentage of 65-character page width):
- Scene Heading: 0% left margin (full width)
- Action: 0% left margin (full width)
- Character: 40% left margin, 60% width
- Dialogue: 25% left margin, 50% width
- Parenthetical: 32% left margin, 38% width
- Transition: 65% left margin, 35% width (right-aligned)
- Lyrics: 25% left margin, 50% width

**Key Validation:**
- Margins maintain correct proportional relationships at any font size
- Character margin (40%) > Dialogue margin (25%)
- Transition margin (65%) > Character margin (40%)
- Margin ratios stay constant (e.g., 40/25 ≈ 1.6)

#### ScreenplayDocumentRenderingTests (13 tests)
End-to-end validation of complete screenplay documents:

- Element ordering and sequence preservation
- Dialogue blocks (character + parenthetical + dialogue)
- Multi-scene documents with transitions
- Chapter sections with proper element ordering
- Large screenplay handling (100+ elements)
- DocumentModelActor element ordering verification

**Tests are flexible about font sizes** - they validate that page width and margins maintain correct proportions regardless of the base font size used.

## Common Patterns

### App Intents & Shortcuts Integration (NEW in 6.1.0)

SwiftCompartido provides comprehensive App Intents support for Apple Shortcuts integration:

**Core Components:**
- `ParseScreenplayFileIntent` - Parse screenplay files via Shortcuts
- `QueryScreenplayElementsIntent` - Query elements from parsed documents
- `ScreenplayElementsReference` - Transferable reference type for chaining workflows
- `SwiftCompartidoShortcuts` - Siri voice command registration
- `ParsedFileService` - Unified service layer (single code path for UI and Intents)

**Example: Parse screenplay via Shortcuts**
```swift
// In Shortcuts app:
// 1. Get File → screenplay.fountain
// 2. Parse Screenplay File (filter: Dialogue)
// 3. Use result in voice generation workflow

// Programmatic usage:
@MainActor
func parseViaIntent(url: URL) async throws -> ScreenplayElementsReference {
    var intent = ParseScreenplayFileIntent()
    intent.fileURL = url
    intent.elementTypes = [ElementTypeEntity(id: "Dialogue", elementType: .dialogue)]

    let result = try await intent.perform()
    return result.value
}
```

**Siri Voice Commands:**
- "Import screenplay with SwiftCompartido"
- "Query screenplay elements in SwiftCompartido"
- "Get screenplay dialogue in SwiftCompartido"

**Architecture:** All App Intents delegate to `ParsedFileService.shared` for consistent behavior across Shortcuts, programmatic usage, and UI. This ensures a single code path for parsing and querying.

**Documentation:**
- See `Docs/APP_INTENTS_GUIDE.md` for complete user guide
- See `Docs/PARSED_FILE_SERVICE_API.md` for API reference

### Parsing Screenplays

```swift
// ✅ ALWAYS use GuionParsedElementCollection (recommended)
let screenplay = try await GuionParsedElementCollection(string: fountainText)

// Convert to SwiftData
let document = await GuionDocumentParserSwiftData.parse(
    script: screenplay,
    in: modelContext
)

// Display in SwiftUI
struct ContentView: View {
    var body: some View {
        GuionViewer(document: document)
    }
}
```

**Or use ParsedFileService (NEW in 6.1.0):**
```swift
@MainActor
func parseAndQuery(url: URL) async throws {
    let service = ParsedFileService.shared

    // Parse file
    let documentID = try await service.parseFile(at: url)

    // Query dialogue
    let filter = ElementFilter(elementTypes: [.dialogue])
    let elements = try await service.elements(documentID: documentID, filter: filter)

    print("Found \(elements.count) dialogue elements")
}
```

### Storing AI-Generated Audio

```swift
let requestID = UUID()
let storage = StorageAreaReference.temporary(requestID: requestID)

let audioDTO = GeneratedAudioData(
    audioData: audioData,
    model: "tts-1",
    format: .mp3,
    voiceID: "rachel",
    voiceName: "Rachel"
)

let record = TypedDataStorage(
    id: requestID,
    providerId: "elevenlabs",
    requestorID: "tts.rachel",
    data: audioDTO,
    prompt: "Generate speech"
)

// Save to file (automatic file reference creation)
try await record.saveBinary(audioData, to: storage, fileName: "speech.mp3")

modelContext.insert(record)
try modelContext.save()
```

## Development Workflow

**⚠️ CRITICAL: See [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) for complete development workflow.**

This project follows a **strict branch-based workflow**:

### Quick Reference

- **Development branch**: `development` (all work happens here)
- **Main branch**: `main` (protected, PR-only)
- **Workflow**: `development` → PR → CI passes → Merge → Tag → Release
- **NEVER** commit directly to `main`
- **NEVER** delete the `development` branch

### CI/CD Requirements

**Main branch is protected:**
- Direct pushes blocked (PRs only)
- No PR review required
- GitHub Actions must pass before merge:
  - iOS Tests (Short): Fast unit tests (~300 tests, 2-5 min)
  - macOS Tests (Short): Fast unit tests on macOS platform (~300 tests, 2-5 min)
  - Code Quality: TODOs, large files, print statements

**Weekend Testing:**
- Long tests run Saturday/Sunday at 2 AM UTC (~100 tests, integration/UI)
- Runs on both iOS Simulator and macOS platforms
- Can be triggered manually via GitHub Actions UI
- Includes coverage reporting to Codecov (separate flags for iOS and macOS)

### Branch Protection Configuration

**⚠️ IMPORTANT: When tests are changed or renamed, branch protections must be evaluated.**

The `main` branch has required status checks that must pass before PRs can be merged. These checks are configured in GitHub repository settings and must match the actual CI workflow job names.

**When to Update Branch Protections:**
- ✅ When CI workflow job names change
- ✅ When test jobs are added or removed
- ✅ When platforms are added or removed (iOS, macOS)
- ✅ When test structure is reorganized (short vs long tests)

**How to Update Branch Protections:**

View current protections:
```bash
gh api repos/intrusive-memory/SwiftCompartido/branches/main/protection/required_status_checks
```

Update required checks:
```bash
gh api --method PATCH repos/intrusive-memory/SwiftCompartido/branches/main/protection/required_status_checks \
  -H "Accept: application/vnd.github.v3+json" \
  --input - <<'EOF'
{
  "strict": true,
  "contexts": [
    "iOS Tests (Short)",
    "macOS Tests (Short)",
    "Code Quality"
  ]
}
EOF
```

**Best Practices:**
- Keep branch protection checks minimal but essential
- Align check names exactly with CI workflow job names
- Document protection changes in PR descriptions
- Test protection changes by creating a test PR

**See [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) for:**
- Complete branch strategy
- Commit message conventions
- PR creation templates
- Tagging and release process
- Version numbering (semver)
- Emergency hotfix procedures

## Documentation Resources

### User Guides
- `README.md` - User-facing overview
- `Docs/APP_INTENTS_GUIDE.md` - Complete guide to Shortcuts integration (NEW in 6.1.0)
- `USAGE-SUMMARY.md` - Quick reference and common patterns
- `CHANGELOG.md` - Version history

### API Documentation
- `Docs/PARSED_FILE_SERVICE_API.md` - Complete API reference for ParsedFileService (NEW in 6.1.0)
- `Docs/PDF_CAPABILITIES.md` - PDF reading capabilities
- `SOURCE_FILE_TRACKING.md` - Source file tracking guide

### Developer Documentation
- `CLAUDE.md` - This file - architecture guide
- `.claude/WORKFLOW.md` - Branch strategy, commits, PRs, and releases
- `.claude/docs/PRODUCIESTA_MIGRATION_GUIDE.md` - Migration guide for Produciesta app
- `.claude/skills/*.md` - Reusable development skills and patterns

## Project Metadata

- **Version**: 6.4.0
- **Swift**: 6.2+
- **Platforms**: iOS 26.0+, macOS 26.0+
- **Dependencies**: TextBundle, ZIPFoundation, swift-markdown, SwiftFijos (test-only)
- **License**: MIT
- **Test Coverage**: 95%+

## Important Reminders

- This library supports iOS and macOS on Apple Silicon (arm64).
- When tagging versions, tag the merge commit of the PR, push the tag, then create a GitHub release.
- ALWAYS use `GuionParsedElementCollection` for parsing - avoid calling parsers directly.
- ALWAYS use `document.sortedElements` for ordered element access.
