# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftCompartido is a Swift package for screenplay management, AI-generated content storage, and document serialization. The library uses **Phase 6 Architecture** - a file-based storage pattern that separates in-memory data transfer objects (DTOs) from file-persisted content to prevent main thread blocking.

**Platforms**: iOS 26.0+, macOS 26.0+

## ⚠️ Breaking Changes in 4.0.0

### Removed `parser` Parameter - Automatic Format Detection

The `parser` parameter has been **removed** from all `GuionParsedElementCollection` initializers. Parser selection is now automatic based on file extension:

- **Removed**: `ParserType` enum (`.fast` and `.regex` were redundant)
- **Changed**: All `GuionParsedElementCollection` initializers no longer accept `parser:` parameter
- **Auto-detection**: Parser automatically selected by file extension:
  - `.md` or `.markdown` → Markdown parser (supports YAML front matter)
  - `.highland` → Highland bundle handler → **Always Fountain parser**
  - `.textbundle` → TextBundle handler → Recursive format detection
  - `.fdx` → Final Draft FDX parser
  - `.pdf` → PDF parser (iOS 26.0+)
  - `.fountain` or default → Fountain parser

**Migration:**
```swift
// ❌ OLD (3.x)
let screenplay = try GuionParsedElementCollection(file: path, parser: .fast)
let screenplay2 = try await GuionParsedElementCollection(string: text, parser: .fast)

// ✅ NEW (4.0+)
let screenplay = try GuionParsedElementCollection(file: path)
let screenplay2 = try await GuionParsedElementCollection(string: text)
```

### File Format Parsing Flow

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

### New Features in 4.0.0

- **AppleTTSVoiceProviderPane**: SwiftUI configuration pane for Apple TTS voice provider
- **openVoiceSettings()**: Helper function to deep link to system voice settings
  - macOS: Opens System Settings → Accessibility → Spoken Content
  - iOS/Catalyst: Opens app settings with fallback guidance

## ✨ New Features in 4.1.0

### YAML Front Matter Support

- **Markdown Parser**: Full YAML front matter extraction from `.md` and `.markdown` files
  - Parses YAML metadata blocks enclosed in `---` delimiters
  - Extracts title, author, draft date, and other metadata
  - Supports single and multi-value fields (e.g., multiple authors)
  - Case-insensitive key handling with normalization to lowercase
  - Compatible with Jekyll/CommonMark conventions

```swift
let markdown = """
---
title: My Screenplay
author: Jane Doe
draft: First Draft
---

# Act One
...
"""

let screenplay = try await GuionParsedElementCollection(string: markdown)
// Title page automatically populated from front matter
```

### Stored Title Property

- **GuionDocumentModel.title**: Stored property (replaces computed property)
  - Automatically extracted during parsing from:
    1. Title page metadata (YAML front matter or Fountain title page)
    2. Filename without extension (fallback)
  - Persisted in SwiftData for better performance
  - Can be manually set or updated after creation

```swift
let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: modelContext)
print(document.title) // "My Screenplay" (from front matter or filename)

// Use in DocumentListView
struct DocumentListView: View {
    @Query var documents: [GuionDocumentModel]

    var body: some View {
        List(documents) { document in
            Text(document.title ?? "Untitled")
        }
    }
}
```


## ⚠️ Breaking Changes in 3.0.0

### Removed Functionality

The following voice provider models have been **removed** and moved to a separate library:
- ❌ `Voice` struct (Sendable DTO for TTS voice data)
- ❌ `VoiceModel` class (SwiftData model for caching voice information)
- ❌ `AppleTTSProvider` and related tests

### Migration Path

If your code uses `Voice` or `VoiceModel`:
1. Import the separate voice provider library (TBD - contact maintainers)
2. Remove direct references to `Voice` and `VoiceModel` from SwiftCompartido imports
3. Continue using audio metadata fields (`voiceID`, `voiceName`) in `TypedDataStorage`

## ✨ New Features in 3.2.0

### Progress Tracking System

- **ElementProgressState**: Observable state manager for tracking progress on multiple elements simultaneously
- **ElementProgressTracker**: Scoped progress tracker with convenience methods (`withProgress`, `withSteps`)
- **ElementProgressBar**: Auto-showing SwiftUI progress bar that appears below list items
- Auto-hide functionality (configurable delay, default 2 seconds)
- Thread-safe with `@MainActor` isolation
- 25 comprehensive tests (all passing)

```swift
// Get progress tracker for an element
let tracker = element.progressTracker(using: progressState)

// Use convenience method for automatic error handling
try await tracker.withProgress(
    startMessage: "Generating audio...",
    completeMessage: "Audio generated!"
) { updateProgress in
    updateProgress(0.5, "Processing...")
    try await generateAudio(element)
}
```

### GuionElementsList Trailing Columns

- Generic trailing column support via `trailingContent` parameter
- Each row can have custom buttons, actions, or metadata displays
- Maintains backward compatibility (trailing column is optional)

```swift
GuionElementsList(document: screenplay) { element in
    Button("Generate Audio") {
        Task {
            let tracker = element.progressTracker(using: progressState)
            try await tracker.withProgress(...) { ... }
        }
    }
}
.environment(progressState)
```

### Documentation

- `ELEMENT_PROGRESS_TRACKER.md`: Complete API reference
- `PROGRESS_BARS.md`: User guide for progress bars
- `GUION_ELEMENTS_LIST_COLUMNS.md`: Trailing column documentation
- `TEST_COVERAGE_STATUS.md`: Test coverage analysis
- `.claude/skills/add-guion-element-button.md`: Skill for creating custom buttons

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
    └─→ generatedContent: [TypedDataStorage] (@Relationship deleteRule: .cascade)

GuionElementModel
    ├─→ document: GuionDocumentModel? (@Relationship deleteRule: .nullify)
    └─→ generatedContent: [TypedDataStorage] (@Relationship deleteRule: .cascade)

TypedDataStorage (leaf node)
    ├─→ owningElement: GuionElementModel? (@Relationship deleteRule: .nullify)
    └─→ owningDocument: GuionDocumentModel? (@Relationship deleteRule: .nullify)

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

## Key Directories

- `Sources/SwiftCompartido/Models/` - All data models
- `Sources/SwiftCompartido/UI/` - SwiftUI components
- `Sources/SwiftCompartido/SwiftDataModels/` - SwiftData @Model classes
- `Tests/SwiftCompartidoTests/` - Test suites

## Testing Requirements

- **Minimum coverage**: 90% (current: 95%+)
- **Test framework**: Swift Testing for new tests, XCTest for legacy
- **Test count**: 437 tests across 28 suites
- Use `@Test("description")` macro, not `func test...`
- All tests must pass before merging PRs

### Test Execution Strategy

Tests are split into **short** and **long** cycles to optimize CI performance:

**Short Tests (runs on every PR/push):**
- Timeout: 10 minutes
- Excludes 13 long-running test suites
- Expected completion: 2-5 minutes
- Purpose: Fast feedback for developers

**Long Tests (runs on weekend schedule):**
- Runs: Saturdays and Sundays at 2 AM UTC
- Timeout: 15 minutes
- Only runs these 13 suites:
  - `IntegrationTests`, `ElementViewTests`, `AudioPlayerManagerTests`
  - `TruncationDebugTests`, `GeneratedContentSortingTests`
  - `FountainParserProgressTests`, `FDXParserProgressTests`
  - `SwiftDataProgressTests`, `PDFScreenplayParserTests`
  - `DocumentImportTests`, `DocumentExportTests`
  - `FileIOProgressTests`, `TextPackWriterProgressTests`

### ⚠️ Adding New Tests - IMPORTANT

When adding new tests, you **MUST** evaluate whether they belong in short or long tests:

**Short tests should be:**
- Fast (< 1 second per test typically)
- Unit tests for individual functions/methods
- Model tests (Codable, initialization, validation)
- Simple integration tests without heavy I/O

**Long tests should be:**
- Integration tests with file I/O or complex workflows
- UI rendering tests (SwiftUI views)
- Progress callback tests with delays
- Parser tests on large documents
- End-to-end workflow tests

**Decision criteria:**
1. Run the test suite locally with timing
2. If a test suite averages > 5 seconds total, consider it for long tests
3. If individual tests take > 1 second, they likely belong in long tests
4. **Default to short tests** unless there's a clear reason for long tests

**To add a test suite to long tests:**
1. Add the suite name to `SKIP_TESTS` array in `.github/workflows/tests.yml`
2. Add the suite name to `LONG_TESTS` array in `.github/workflows/long-tests.yml`

**Goal:** Keep short tests completing in under 5 minutes to maintain fast PR feedback

## Common Patterns

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
try record.saveBinary(audioData, to: storage, fileName: "speech.mp3", mode: .local)

modelContext.insert(record)
try modelContext.save()
```

## Branch Protection and CI/CD

**Main branch is protected:**
- Direct pushes blocked (PRs only)
- No PR review required
- GitHub Actions must pass:
  - iOS Tests (Short): Fast unit tests (~300 tests, 2-5 min)
  - macOS Tests (Short): Fast unit tests on macOS platform (~300 tests, 2-5 min)
  - Code Quality: TODOs, large files, print statements

**Workflow:** Create PR → Short tests run automatically → Merge when green

**Weekend Testing:**
- Long tests run Saturday/Sunday at 2 AM UTC (~100 tests, integration/UI)
- Runs on both iOS Simulator and macOS platforms
- Can be triggered manually via GitHub Actions UI
- Includes coverage reporting to Codecov (separate flags for iOS and macOS)

## Documentation Resources

- `README.md` - User-facing overview
- `CLAUDE.md` - This file - architecture guide
- `AI-REFERENCE.md` - Comprehensive API reference
- `Docs/PDF_CAPABILITIES.md` - PDF reading capabilities
- `SOURCE_FILE_TRACKING.md` - Source file tracking guide
- `CHANGELOG.md` - Version history

## Project Metadata

- **Version**: 4.3.0 (Development version with automated version bump workflow)
- **Swift**: 6.2+
- **Platforms**: iOS 26.0+, macOS 26.0+
- **Dependencies**: TextBundle, SwiftFijos (test-only)
- **License**: MIT
- **Test Coverage**: 95%+ across 437 tests in 28 suites

## Important Reminders

- This library supports iOS and macOS on Apple Silicon (arm64).
- When tagging versions, tag the merge commit of the PR, push the tag, then create a GitHub release.
- ALWAYS use `GuionParsedElementCollection` for parsing - avoid calling parsers directly.
- ALWAYS use `document.sortedElements` for ordered element access.
