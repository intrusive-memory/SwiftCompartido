# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftCompartido is a Swift package for screenplay management, AI-generated content storage, and document serialization. The library uses **Phase 6 Architecture** - a file-based storage pattern that separates in-memory data transfer objects (DTOs) from file-persisted content to prevent main thread blocking.

**Platforms**: iOS 26.0+, macOS 26.0+

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
try record.saveBinary(audioData, to: storage, fileName: "speech.mp3", mode: .local)

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
- `AI-REFERENCE.md` - Comprehensive API reference
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

- **Version**: 6.1.0
- **Swift**: 6.2+
- **Platforms**: iOS 26.0+, macOS 26.0+
- **Dependencies**: TextBundle, SwiftFijos (test-only)
- **License**: MIT
- **Test Coverage**: 95%+ across 471 tests in 31 suites

## Important Reminders

- This library supports iOS and macOS on Apple Silicon (arm64).
- When tagging versions, tag the merge commit of the PR, push the tag, then create a GitHub release.
- ALWAYS use `GuionParsedElementCollection` for parsing - avoid calling parsers directly.
- ALWAYS use `document.sortedElements` for ordered element access.
