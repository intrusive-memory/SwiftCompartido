# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftCompartido is a Swift package for screenplay management, AI-generated content storage, and document serialization. The library uses **Phase 6 Architecture** - a file-based storage pattern that separates in-memory data transfer objects (DTOs) from file-persisted content to prevent main thread blocking.

## Core Architecture Patterns

### Model Pairs Pattern

The codebase uses **intentional model duplication** where each data type has TWO models serving different purposes:

1. **DTO Models** (in-memory, Sendable): `GeneratedTextData`, `GeneratedAudioData`, `GeneratedImageData`, `GeneratedEmbeddingData`
   - Used for transferring data between actors/threads
   - Always `Sendable` for Swift 6 concurrency
   - Short-lived, never persisted

2. **SwiftData Models** (persistent): `GeneratedTextRecord`, `GeneratedAudioRecord`, `GeneratedImageRecord`, `GeneratedEmbeddingRecord`
   - Decorated with `@Model` macro
   - Managed by SwiftData/ModelContext
   - Can reference files instead of storing large data in-memory

**DO NOT consolidate these model pairs** - they serve different purposes in the architecture.

### Phase 6 Storage Architecture

Large content (audio, images) follows this pattern:

1. Background thread: Generate content → Write to file in `StorageAreaReference`
2. Create lightweight `TypedDataFileReference` (metadata only: filename, size, checksum)
3. Main thread: Store file reference in SwiftData model (NOT the actual data)
4. Playback/display: Load from file URL directly

**Storage decision tree:**
- Text < 10KB: Store in `GeneratedTextRecord.text` property (in-memory)
- Text ≥ 10KB: Write to file, store `TypedDataFileReference`
- Audio/Images: ALWAYS use file storage with `TypedDataFileReference`
- Embeddings: Can be in-memory (small vectors) or file-based (large vectors)

### Storage Areas

`StorageAreaReference` provides request-scoped file storage:

```
MyDocument.guion/              # TextPack bundle
├── info.json                  # Bundle metadata
├── text.txt                   # Main screenplay text
└── assets/                    # AI-generated files
    ├── {requestID}/           # One directory per request
    │   ├── speech.mp3         # Generated audio
    │   └── metadata.json      # Request metadata
    └── {requestID}/
        └── image.png          # Generated image
```

Two storage types:
- `.temporary(requestID:)` - For testing/temporary processing
- `.inBundle(requestID:bundleURL:)` - For document-owned persistent storage

## Essential Commands

### Building and Testing

```bash
# Build the package
swift build

# Run all tests (176 tests)
swift test

# Run specific test suite
swift test --filter AIResponseDataTests
swift test --filter AudioPlayerManagerTests

# Run tests with code coverage
swift test --enable-code-coverage

# Generate coverage report
xcrun llvm-cov report \
  .build/debug/SwiftCompartidoPackageTests.xctest/Contents/MacOS/SwiftCompartidoPackageTests \
  -instr-profile .build/debug/codecov/default.profdata

# List all available tests
swift test --list-tests
```

### Development Workflow

```bash
# View current branch protection
gh api repos/intrusive-memory/SwiftCompartido/branches/main/protection | jq

# Create a feature branch
git checkout -b feature/my-feature

# Run tests before committing
swift test

# View test coverage
xcrun llvm-cov report .build/debug/SwiftCompartidoPackageTests.xctest/Contents/MacOS/SwiftCompartidoPackageTests \
  -instr-profile .build/debug/codecov/default.profdata
```

## Code Organization

### Key Directories

- `Sources/SwiftCompartido/Models/` - All data models (screenplay, AI, storage)
- `Sources/SwiftCompartido/UI/` - SwiftUI components
- `Tests/SwiftCompartidoTests/` - Test suites using Swift Testing framework

### Model Categories

**Screenplay Models:**
- `GuionElement`, `ElementType` - Screenplay element tree
- `FountainParser`, `FDXParser` - Format parsing
- `FountainWriter`, `FDXDocumentWriter` - Format export
- `GuionParsedScreenplay` - Main screenplay container

**AI Response Models:**
- `AIResponseData` - Primary response type with typed content
- `ResponseContent` - Enum for text/audio/image/structured data
- `UsageStats` - Consolidated token/cost tracking
- `AIServiceError` - Comprehensive error handling

**Generated Content (Phase 6 Pattern):**
- DTOs: `GeneratedTextData`, `GeneratedAudioData`, `GeneratedImageData`, `GeneratedEmbeddingData`
- Records: `GeneratedTextRecord`, `GeneratedAudioRecord`, `GeneratedImageRecord`, `GeneratedEmbeddingRecord`

**Storage System:**
- `StorageAreaReference` - Request-scoped file storage areas
- `TypedDataFileReference` - Lightweight file references
- `SerializableTypedData` - Serialization wrapper

## Testing Requirements

- **Minimum coverage**: 90% (current: 95%+)
- **Test framework**: Swift Testing (NOT XCTest)
- **Test count**: 275 tests across 20 suites
- Use `@Test("description")` macro, not `func test...`
- All tests must pass before merging PRs

### Test Structure

```swift
import Testing
@testable import SwiftCompartido

struct MyFeatureTests {
    @Test("Feature does something correctly")
    func testFeature() throws {
        // Arrange
        let sut = MyFeature()

        // Act
        let result = try sut.doSomething()

        // Assert
        #expect(result == expectedValue)
    }
}
```

### Platform Availability

For tests using file storage features:

```swift
@Test("Description")
@available(macOS 15.0, iOS 17.0, *)
func testFileBasedFeature() throws {
    // Only apply @available to individual tests, NOT the struct
}
```

## Concurrency and Thread Safety

All code follows **Swift 6 concurrency** standards:

- All models are `Sendable`
- Use `@MainActor` for UI updates
- File I/O operations safe on background threads
- `StorageAreaReference` is thread-safe

### Audio Playback Pattern

`AudioPlayerManager` uses `AVAudioPlayer` with dual playback modes:

```swift
// File-based (preferred - efficient)
try playerManager.play(from: audioURL, format: "mp3", duration: 5.5)

// Record-based (automatic storage detection)
try playerManager.play(record: audioRecord, storageArea: storage)

// In-memory fallback
try playerManager.play(audioFile)
```

The manager automatically detects file references vs in-memory data.

## Branch Protection and CI/CD

**Main branch is protected:**
- Direct pushes blocked (PRs only)
- No PR review required
- GitHub Actions must pass:
  - Test job: Run all 176 tests with coverage
  - Lint job: Check for TODOs, large files, print statements
- Enforced for all users including admins

**Workflow:** Create PR → Tests run automatically → Merge when green

## Common Patterns

### Storing AI-Generated Audio

```swift
let requestID = UUID()
let storage = StorageAreaReference.temporary(requestID: requestID)
try storage.createDirectoryIfNeeded()

// Write audio to file
let audioURL = storage.fileURL(for: "speech.mp3")
try audioData.write(to: audioURL)

// Create file reference (lightweight)
let fileRef = TypedDataFileReference(
    requestID: requestID,
    fileName: "speech.mp3",
    fileSize: Int64(audioData.count),
    mimeType: "audio/mpeg"
)

// Create record (no in-memory data)
let record = GeneratedAudioRecord(
    providerId: "elevenlabs",
    requestorID: "tts.rachel",
    audioData: nil,  // File-based storage
    format: "mp3",
    fileReference: fileRef
)

modelContext.insert(record)
try modelContext.save()
```

### Parsing Screenplays

```swift
let parser = FountainParser()
let screenplay = parser.parse(fountainText)

// Access structured data
for element in screenplay.elements {
    switch element.elementType {
    case .sceneHeading: // Handle scene
    case .dialogue: // Handle dialogue
    case .character: // Handle character
    default: break
    }
}
```

## CloudKit Sync Patterns

### Storage Modes

SwiftCompartido supports three storage modes for AI-generated content:

- **`.local`** (default) - Traditional Phase 6 architecture, no CloudKit
- **`.cloudKit`** - Syncs to CloudKit, maintains local copy for performance
- **`.hybrid`** - Dual storage: both local Phase 6 files AND CloudKit sync

### Local-Only Mode (Backward Compatible)

```swift
// Default behavior - unchanged from version 1.0.0
let record = GeneratedTextRecord(
    providerId: "openai",
    requestorID: "gpt-4",
    text: "Generated content",
    wordCount: 2,
    characterCount: 17
    // storageMode defaults to .local
)

// All Phase 6 patterns still work exactly as before
modelContext.insert(record)
try modelContext.save()
```

### CloudKit Private Database

```swift
// Setup CloudKit container
let container = try SwiftCompartidoContainer.makeCloudKitPrivateContainer(
    containerIdentifier: "iCloud.com.yourcompany.YourApp"
)

// Create record with CloudKit sync
let record = GeneratedTextRecord(
    providerId: "openai",
    requestorID: "gpt-4",
    text: "Synced content",
    wordCount: 2,
    characterCount: 13,
    storageMode: .cloudKit  // Enable sync
)

modelContext.insert(record)
try modelContext.save() // Automatically syncs to CloudKit
```

### Hybrid Storage (Best of Both Worlds)

```swift
// Hybrid mode: Local files for speed + CloudKit for sync
let requestID = UUID()
let storage = StorageAreaReference.temporary(requestID: requestID)
let audioData = Data(/* ... */)

let record = GeneratedAudioRecord(
    id: requestID,
    providerId: "elevenlabs",
    requestorID: "tts.rachel",
    audioData: nil,
    format: "mp3",
    voiceID: "rachel",
    voiceName: "Rachel"
)

// Saves to BOTH local .guion bundle AND CloudKit
try record.saveAudio(audioData, to: storage, mode: .hybrid)

// Loading tries CloudKit first, falls back to local
let loadedData = try record.loadAudio(from: storage)
```

### Checking CloudKit Availability

```swift
import CloudKit

Task {
    if await CKDatabase.isCloudKitAvailable() {
        // User is signed into iCloud
        enableCloudKitFeatures()
    } else {
        // Fall back to local-only
        useLocalStorage()
    }
}
```

### Conflict Resolution

All CloudKit-enabled records include built-in conflict tracking:

```swift
// Automatic version tracking
record.conflictVersion // Increments on each change
record.cloudKitChangeTag // CloudKit's change token
record.lastSyncedAt // When last synced
record.syncStatus // .pending, .synced, .conflict, .failed, .localOnly
```

### Migration from Local to CloudKit

Existing local-only apps can add CloudKit without breaking changes:

```swift
// Step 1: Existing records stay local
// No changes needed - they keep working

// Step 2: New records can opt into CloudKit
let newRecord = GeneratedTextRecord(
    // ...
    storageMode: .cloudKit  // Only new records sync
)

// Step 3: Optionally migrate existing records
existingRecord.storageMode = .hybrid
existingRecord.syncStatus = .pending
try modelContext.save() // Will sync on next save
```

### Container Configuration Options

```swift
// Local-only (default, no CloudKit)
let container = try SwiftCompartidoContainer.makeLocalContainer()

// CloudKit private database (user's private data)
let container = try SwiftCompartidoContainer.makeCloudKitPrivateContainer()

// Automatic CloudKit (SwiftData chooses configuration)
let container = try SwiftCompartidoContainer.makeCloudKitAutomaticContainer()

// Hybrid (some records local, some synced)
let container = try SwiftCompartidoContainer.makeHybridContainer()
```

## Progress Reporting

SwiftCompartido provides comprehensive progress reporting for long-running operations. All async parsing, conversion, and export operations support optional progress tracking.

### Core Progress Types

**OperationProgress** - Main progress tracking class:
```swift
let progress = OperationProgress(totalUnits: 100) { update in
    print("\(update.description) - \(Int((update.fractionCompleted ?? 0) * 100))%")
}
```

**ProgressUpdate** - Immutable progress snapshot:
- `completedUnits: Int64` - Units completed so far
- `totalUnits: Int64?` - Total units (if known)
- `fractionCompleted: Double?` - Completion percentage (0.0-1.0)
- `description: String` - Human-readable status message

### Progress-Enabled Operations

All major operations support progress reporting with `<2%` performance overhead:

**Fountain Parsing:**
```swift
let progress = OperationProgress(totalUnits: nil) { update in
    Task { @MainActor in
        statusLabel.text = update.description
        progressBar.doubleValue = update.fractionCompleted ?? 0.0
    }
}

let parser = try await FountainParser(string: fountainText, progress: progress)
```

**FDX Parsing:**
```swift
let progress = OperationProgress(totalUnits: nil)
let parser = try await FDXParser(data: fdxData, progress: progress)
```

**SwiftData Conversion:**
```swift
let progress = OperationProgress(totalUnits: nil)
let document = await GuionDocumentParserSwiftData.parse(
    script: screenplay,
    in: modelContext,
    generateSummaries: false,
    progress: progress
)
```

**TextPack Export:**
```swift
let progress = OperationProgress(totalUnits: 5) // 5 stages
let bundle = try await TextPackWriter.createTextPack(
    from: screenplay,
    progress: progress
)
```

**File I/O Operations:**
```swift
let progress = OperationProgress(totalUnits: Int64(audioData.count))
try await record.saveAudio(audioData, to: storage, mode: .local, progress: progress)
```

### SwiftUI Integration

Progress works seamlessly with SwiftUI's `@Published` properties:

```swift
@MainActor
class DocumentViewModel: ObservableObject {
    @Published var progressMessage = ""
    @Published var progressFraction = 0.0

    func parseScreenplay() async {
        let progress = OperationProgress(totalUnits: nil) { update in
            Task { @MainActor in
                self.progressMessage = update.description
                self.progressFraction = update.fractionCompleted ?? 0.0
            }
        }

        let parser = try await FountainParser(string: text, progress: progress)
        // ...
    }
}

// In SwiftUI view:
ProgressView(value: viewModel.progressFraction) {
    Text(viewModel.progressMessage)
}
```

### Cancellation Support

All progress-enabled operations support cancellation via `Task.checkCancellation()`:

```swift
let parseTask = Task {
    let progress = OperationProgress(totalUnits: nil)
    return try await FountainParser(string: largeScript, progress: progress)
}

// Cancel from UI
parseTask.cancel()

do {
    let result = try await parseTask.value
} catch is CancellationError {
    print("Operation cancelled by user")
}
```

### Performance Characteristics

- **Overhead**: <2% of operation time
- **Update frequency**: Batched to max 100 updates/second
- **Thread safety**: All progress APIs are `Sendable` and thread-safe
- **Memory**: Bounded - no accumulation of progress updates
- **Concurrency**: Fully Swift 6 compliant with actor isolation

### Progress Reporting Phases

The implementation follows a 7-phase architecture:

1. **Phase 0**: Foundation (`OperationProgress`, `ProgressUpdate`)
2. **Phase 1**: FountainParser progress (9 features)
3. **Phase 2**: FDXParser progress (8 features)
4. **Phase 3**: TextPack Reader progress (9 features)
5. **Phase 4**: TextPack Writer progress (8 features)
6. **Phase 5**: SwiftData operations progress (7 features)
7. **Phase 6**: File I/O progress (7 features)
8. **Phase 7**: Integration tests (8 tests)

**Total**: 275 tests across 20 test suites with 95%+ coverage.

### Backward Compatibility

All progress parameters default to `nil` - existing code continues to work without modifications:

```swift
// Old code - still works
let parser = try GuionParsedScreenplay(file: path)

// New code - with progress
let progress = OperationProgress(totalUnits: nil)
let parser = try await FountainParser(string: text, progress: progress)
```

## Documentation Resources

- `README.md` - User-facing overview
- `USAGE-SUMMARY.md` - Quick reference (14KB, 500 lines)
- `AI-REFERENCE.md` - Comprehensive AI guide (45KB, 1,800 lines)
- `CONTRIBUTING.md` - Contribution guidelines
- `CHANGELOG.md` - Version history

## Project Metadata

- **Version**: 1.3.2 (with Mac Catalyst Compatibility)
- **Swift**: 6.2+
- **Platforms**: macOS 26.0+, iOS 26.0+, Mac Catalyst 26.0+
- **Dependencies**: TextBundle, SwiftFijos (test-only)
- **CI/CD**: GitHub Actions on macOS-latest with Xcode 16.0+
  - Automated Mac Catalyst build checks
  - Platform API compatibility validation
- **License**: MIT
