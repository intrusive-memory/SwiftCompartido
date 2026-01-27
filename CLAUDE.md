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
  - ✅ **Foundation Models PDF parsing** (fully implemented - uses on-device Apple Intelligence for enhanced accuracy)
  - ✅ **Storing** generated content (TypedDataStorage) is OK
  - ✅ **Displaying** generated content (GeneratedContentListView) is OK
  - ❌ **Generating** content does NOT belong here (except on-device parsing enhancements)

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
| Foundation Models PDF parsing | Mission 1 (Parsing) | ✅ YES - Fully implemented |
| OpenAI API client | Generation | ❌ NO - Spin off |
| ElevenLabs TTS | Generation | ❌ NO - Spin off |
| CloudKit sync | Cloud Sync | ❌ NO - Removed in 6.2.1 |

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

## File Format Parsing

SwiftCompartido supports **8 screenplay formats** with automatic format detection and unified output.

**Supported Formats:**
- Fountain (`.fountain`) - 99%+ accuracy
- Final Draft (`.fdx`) - 99%+ accuracy
- PDF (`.pdf`) - 95-98.3% accuracy (AI-powered or heuristic)
- Markdown (`.md`) - 99%+ accuracy
- Highland (`.highland`) - 99%+ accuracy
- TextBundle (`.textbundle`) - 99%+ accuracy
- Pandoc (`.docx`, `.odt`, `.rtf`) - 95%+ accuracy (macOS only)

**Critical Parsing Rules:**
1. **Standalone .md files** → Markdown parser with YAML front matter
2. **Highland .md files** → **Always Fountain parser** (Highland uses Fountain syntax)
3. **PDF files** → AI-powered (98.3%) or heuristic (95%) extraction with automatic fallback

**See [Docs/PARSING_ARCHITECTURE.md](./Docs/PARSING_ARCHITECTURE.md) for:**
- Complete parsing flow diagram (Mermaid)
- Parser-specific implementation details
- Error handling and progress reporting
- Test coverage and fixtures

## Performance Testing & Benchmarking

SwiftCompartido includes comprehensive performance testing to track rendering speed and detect regressions.

**Quick Summary:**
- **Performance Test Suite**: Measures parsing, conversion, and formatting performance
- **Current Baselines**: 1.2s for 1000 elements, 24s for 5000 elements
- **Primary Bottleneck**: SwiftData conversion (94-99% of total time)
- **Tracking**: JSON reports exported to `/tmp/performance_results/`
- **CI Integration**: Non-blocking performance tests with artifact upload

**See [Docs/PERFORMANCE_TESTING.md](./Docs/PERFORMANCE_TESTING.md) for:**
- Detailed performance baselines
- Running performance tests
- Build-to-build tracking
- Optimization targets
- Regression detection

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

**Quick Summary:**
- **Cascade Delete**: Deleting a document cascades to all elements and generated content
- **Element Ordering**: Always use `document.sortedElements` (relationship arrays are unordered)
- **No inverse: parameters**: Prevents circular reference errors in Swift 6 macro expansion
- **Model Pairs Pattern**: Separate DTO models (Sendable) from SwiftData models (persistent)

**See [Docs/ARCHITECTURE_SWIFTDATA.md](./Docs/ARCHITECTURE_SWIFTDATA.md) for:**
- Complete relationship graph
- Cascade delete behavior
- DocumentModelActor pattern
- Phase 6 storage architecture
- Proper relationship usage examples

## ⚠️ Known Issues

See [Docs/KNOWN_ISSUES.md](./Docs/KNOWN_ISSUES.md) for complete list of known issues and limitations.

### DocumentModelActor Element Ordering (RESOLVED)

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

SwiftCompartido uses **test plans** (.xctestplan files) to organize tests into five categories:

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
- `ScreenplayRenderingFormatTests`, `ScreenplayDocumentRenderingTests`

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

#### 5. **AITests.xctestplan** (Manual only - Requires Apple Intelligence)
- **Apple Intelligence (Foundation Models) tests**
- Tests AI-powered PDF parsing when available
- Requires iOS 26.2+, Apple Intelligence enabled, M1+/A17 Pro+ device
- **NOT run in CI** (Apple Intelligence unavailable in headless runners)
- Run manually with: `./Scripts/test-ai-features.sh`

**Examples:**
- `PDFScreenplayParserAITests`

**Why separate from CI:**
- Apple Intelligence requires user opt-in (System Settings)
- Headless CI runners can't enable Apple Intelligence
- Foundation Models API availability needs verification (iOS 26.2 is shipping)
- All PDF parsing tests in LongTests validate heuristic conversion (production baseline)

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

# Run Apple Intelligence tests (requires Apple Intelligence enabled)
./Scripts/test-ai-features.sh
# Or: ./Scripts/test-ai-features.sh --macos
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

#### AI Tests (AITests.xctestplan)
- ✅ **MUST** require Apple Intelligence to function
- ✅ Tests Foundation Models API integration
- ✅ Gracefully skip if Apple Intelligence unavailable
- ✅ Run manually with `./Scripts/test-ai-features.sh`
- ❌ **NEVER run in CI** (Apple Intelligence unavailable in headless runners)

**To add a test suite to a test plan:**
Edit the corresponding `.xctestplan` file and add the test suite name to `selectedTests` or `skippedTests`

**Decision tree:**
1. Does it require Apple Intelligence? → `AITests.xctestplan` (manual only)
2. Is it a performance benchmark? → `PerformanceTests.xctestplan`
3. Does it test SwiftUI views? → `UITests.xctestplan`
4. Does it do heavy I/O or take > 1 second? → `LongTests.xctestplan`
5. Otherwise → `UnitTests.xctestplan`

**Goal:** Keep unit tests under 5 minutes for fast PR feedback

### Screenplay Rendering Tests

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

### Apple Intelligence PDF Parsing (NEW in 6.5.0)

SwiftCompartido includes **full Apple Intelligence integration** for AI-powered PDF screenplay parsing using the Foundation Models framework.

#### Implementation Status: ✅ FULLY IMPLEMENTED

**Version**: 6.6.0
**Framework**: Foundation Models (iOS 26.2+, macOS 26.0+)
**Status**: Production-ready with graceful fallback

#### How It Works

```swift
#if canImport(FoundationModels)
import FoundationModels

// Check availability
let model = SystemLanguageModel.default
guard model.isAvailable else {
    throw PDFScreenplayParserError.foundationModelsUnavailable
}

// Create session with Fountain format system prompt
let session = LanguageModelSession(
    model: model,
    instructions: systemPrompt  // 390-line Fountain format guide
)

// Convert PDF text to Fountain format
let response = try await session.respond(to: Prompt(userPrompt))
return response.content  // Fountain-formatted screenplay
#endif
```

#### Automatic Fallback Strategy

1. **Try AI conversion** with `SystemLanguageModel.default.isAvailable`
2. **If unavailable/fails** → Notify user via `OperationProgress.additionalInfo`
3. **Fall back to heuristic parsing** (95%+ accuracy on standard formats)
4. **Return same type** (`GuionParsedElementCollection`) regardless of method

#### User Notifications

Users receive clear warnings through `OperationProgress` when falling back:

**When AI unavailable:**
```
⚠️ AI-powered parsing unavailable. Falling back to heuristic conversion.
Results may be less accurate for non-standard screenplay formats.
To enable AI parsing: 1) Enable Apple Intelligence in System Settings,
2) Ensure device has M1+/A17 Pro+ chip, 3) iOS 26.2+ or macOS 26.0+
```

**When platform unsupported:**
```
ℹ️ Apple Intelligence not available on this platform. Using heuristic conversion.
For AI-powered parsing, upgrade to iOS 26.2+ or macOS 26.0+ with M1+/A17 Pro+ chip.
```

#### Test Results (Validated with Apple Intelligence Enabled)

**All 8 AI tests PASSED** - Execution time: 38.9 seconds

| Test | Duration | Result |
|------|----------|--------|
| Framework detection | 0.001s | ✅ Apple Intelligence available |
| Content preservation | 4.0s | ✅ **100% accuracy** |
| Progress reporting | 8.3s | ✅ 16 updates delivered |
| PDF conversion | 9.1s | ✅ 128 scenes, 773 characters, 784 dialogue |
| Non-standard formats | 11.7s | ✅ TV script: 58 scenes, 570 dialogue |
| AI vs Heuristic | 27.1s | ✅ 256 scenes, 790 characters, 819 dialogue |
| System prompt effectiveness | 27.3s | ✅ **98.3% format compliance** |
| Multiple PDFs | 38.9s | ✅ 3 screenplays: 5,550 total elements |

#### Performance Comparison

| Method | Speed | Accuracy | Use Case |
|--------|-------|----------|----------|
| Heuristic | < 5s | 95%+ | Standard screenplay formats |
| AI-powered | 10-20s | **98.3%** | Non-standard formats, TV scripts, classic screenplays |

#### Key Benefits

- ✅ **98.3% Fountain format compliance** - Superior accuracy
- ✅ **100% content preservation** - No text loss
- ✅ **On-device processing** - Privacy-first, no cloud
- ✅ **Zero configuration** - Works automatically when enabled
- ✅ **Graceful degradation** - Always produces results
- ✅ **No API costs** - Completely free

#### Testing

**Run AI tests locally:**
```bash
./Scripts/test-ai-features.sh --macos
./Scripts/test-ai-features.sh --ios
```

**Requirements:**
- iOS 26.2+ or macOS 26.0+
- M1+ Mac or A17 Pro+ device
- Apple Intelligence enabled in System Settings

**CI Behavior:** AI tests are **not run in CI** (Apple Intelligence unavailable in headless runners). CI displays informative notice instead.

#### Files

**Implementation:**
- `Sources/SwiftCompartido/Serialization/PDFScreenplayParser.swift:247-315`

**Tests:**
- `Tests/SwiftCompartidoTests/PDFScreenplayParserAITests.swift` (8 tests)
- `AITests.xctestplan`

**Scripts:**
- `Scripts/test-ai-features.sh` - Beautiful terminal UI for running AI tests

**Documentation:**
- `Docs/FOUNDATION_MODELS_STATUS.md` - Complete status and API usage
- `Docs/FOUNDATION_MODELS_VERIFICATION.md` - API verification results
- `Docs/AI_IMPLEMENTATION_COMPLETE.md` - Implementation summary

## Common Patterns

### Voice Download Integration

SwiftCompartido provides tools to help users download Enhanced and Premium system voices for high-quality Text-to-Speech.

**Quick Setup:**

1. **Bundle the AppleScript** in your app's Resources:
   ```
   YourApp.app/Contents/Resources/Scripts/download-premium-voices.applescript
   ```

2. **Use VoiceDownloadHelper** in your code:
   ```swift
   import SwiftCompartido

   VoiceDownloadHelper.promptUserToDownloadPremiumVoices { result in
       switch result {
       case .success:
           print("Voice download launched")
       case .failure(let error):
           print("Error: \(error)")
       }
   }
   ```

3. **Add to Info.plist**:
   ```xml
   <key>NSAppleEventsUsageDescription</key>
   <parameter name="string">This app automates System Settings to help you download Premium voices.</string>
   ```

**SwiftUI Integration:**
```swift
struct SettingsView: View {
    @State private var showVoiceDownload = false

    var body: some View {
        Button("Download Premium Voices") {
            showVoiceDownload = true
        }
        .presentVoiceDownload(isPresented: $showVoiceDownload)
    }
}
```

**See:**
- [Voice Download Guide](./Docs/VOICE_DOWNLOAD_GUIDE.md) - Complete documentation
- [Scripts/README.md](./Scripts/README.md) - Integration guide
- `Scripts/VoiceDownloadHelper.swift` - Swift API reference
- `Scripts/VoiceDownloadExample.swift` - Example implementation
- `Scripts/download-premium-voices.applescript` - AppleScript source

### App Intents & Shortcuts Integration

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
- See [Docs/APP_INTENTS_GUIDE.md](./Docs/APP_INTENTS_GUIDE.md) for complete user guide
- See [Docs/PARSED_FILE_SERVICE_API.md](./Docs/PARSED_FILE_SERVICE_API.md) for API reference

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

**Or use ParsedFileService:**
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

### CI/CD Configuration

#### Branch Protection

**Required status checks:**
- `iOS Tests (Short)` - Fast unit tests on iOS Simulator
- `macOS Tests (Short)` - Fast unit tests on macOS
- `Code Quality` - Linting and quality checks

**⚠️ IMPORTANT**: Update branch protections when CI workflow job names change.

#### iOS Simulator Creation

**⚠️ CRITICAL**: GitHub Actions `macos-26` runners don't have iPhone simulators pre-installed.

**Solution**: All iOS workflows include a "Create iPhone Simulator" step that dynamically creates and boots an "iPhone-Test" simulator before running tests.

**See [Docs/CI_CD_SETUP.md](./Docs/CI_CD_SETUP.md) for:**
- Complete workflow descriptions (tests, long-tests, ui-tests, performance)
- Branch protection update procedures
- Dynamic simulator creation implementation
- Codecov integration
- Troubleshooting guide

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
- `Docs/APP_INTENTS_GUIDE.md` - Complete guide to Shortcuts integration
- `Docs/USAGE-SUMMARY.md` - Quick reference and common patterns
- `CHANGELOG.md` - Version history

### API Documentation
- `Docs/PARSED_FILE_SERVICE_API.md` - Complete API reference for ParsedFileService
- `Docs/FOUNDATION_MODELS_STATUS.md` - Foundation Models integration status and roadmap
- `Docs/old/PDF_CAPABILITIES.md` - PDF reading/writing capabilities assessment
- `Docs/SOURCE_FILE_TRACKING.md` - Source file tracking guide

### Developer Documentation
- `CLAUDE.md` - This file - architecture guide
- `.claude/WORKFLOW.md` - Branch strategy, commits, PRs, and releases
- `.claude/docs/PRODUCIESTA_MIGRATION_GUIDE.md` - Migration guide for Produciesta app
- `.claude/skills/*.md` - Reusable development skills and patterns

## Project Metadata

- **Version**: 6.6.0
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
