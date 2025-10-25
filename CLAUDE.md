# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftCompartido is a Swift package for screenplay management, AI-generated content storage, and document serialization. The library uses **Phase 6 Architecture** - a file-based storage pattern that separates in-memory data transfer objects (DTOs) from file-persisted content to prevent main thread blocking.

**Platforms**: iOS 26.0+, Mac Catalyst 26.0+ only. **No macOS standalone support.**

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

## Essential Build Commands

⚠️ **CRITICAL**: This is an iOS and Mac Catalyst library. **DO NOT use `swift build` or `swift test`** directly - they fail with macOS version errors.

**Use the build script:**
```bash
./build.sh                  # Build for iOS Simulator
./build.sh --action test    # Run all 412 tests
./build.sh --help           # Show all options
```

**Or use xcodebuild:**
```bash
# Build for iOS Simulator
xcodebuild build \
  -scheme SwiftCompartido \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO

# Run tests
xcodebuild test \
  -scheme SwiftCompartido \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -enableCodeCoverage YES \
  CODE_SIGNING_ALLOWED=NO

# Build for Mac Catalyst
xcodebuild build \
  -scheme SwiftCompartido \
  -destination 'generic/platform=macOS,variant=Mac Catalyst' \
  -arch arm64 \
  CODE_SIGNING_ALLOWED=NO
```

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

## Key Directories

- `Sources/SwiftCompartido/Models/` - All data models
- `Sources/SwiftCompartido/UI/` - SwiftUI components
- `Sources/SwiftCompartido/SwiftDataModels/` - SwiftData @Model classes
- `Tests/SwiftCompartidoTests/` - Test suites

## Testing Requirements

- **Minimum coverage**: 90% (current: 95%+)
- **Test framework**: Swift Testing for new tests, XCTest for legacy
- **Test count**: 412 tests across 28 suites
- Use `@Test("description")` macro, not `func test...`
- All tests must pass before merging PRs

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
  - iOS Tests: All 412 tests with coverage
  - Mac Catalyst Build Check: Platform compatibility
  - Code Quality: TODOs, large files, print statements

**Workflow:** Create PR → Tests run automatically → Merge when green

## Documentation Resources

- `README.md` - User-facing overview
- `CLAUDE.md` - This file - architecture guide
- `AI-REFERENCE.md` - Comprehensive API reference
- `Docs/PDF_CAPABILITIES.md` - PDF reading capabilities
- `SOURCE_FILE_TRACKING.md` - Source file tracking guide
- `CHANGELOG.md` - Version history

## Project Metadata

- **Version**: 3.0.0 (Voice provider models removed)
- **Swift**: 6.2+
- **Platforms**: iOS 26.0+, Mac Catalyst 26.0+ (macOS standalone removed in 3.0.0)
- **Dependencies**: TextBundle, SwiftFijos (test-only)
- **License**: MIT
- **Test Coverage**: 95%+ across 412 tests in 28 suites

## Important Reminders

- This is an iOS and Mac Catalyst library ONLY. Do not compile for macOS standalone.
- When tagging versions, tag the merge commit of the PR, push the tag, then create a GitHub release.
- ALWAYS use `GuionParsedElementCollection` for parsing - avoid calling parsers directly.
- ALWAYS use `document.sortedElements` for ordered element access.
