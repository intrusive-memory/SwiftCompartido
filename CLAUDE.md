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

# Run all tests (159 tests)
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
- **Test count**: 159 tests across 11 suites
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
  - Test job: Run all 159 tests with coverage
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

## Documentation Resources

- `README.md` - User-facing overview
- `USAGE-SUMMARY.md` - Quick reference (14KB, 500 lines)
- `AI-REFERENCE.md` - Comprehensive AI guide (45KB, 1,800 lines)
- `CONTRIBUTING.md` - Contribution guidelines
- `CHANGELOG.md` - Version history

## Project Metadata

- **Version**: 1.0.0
- **Swift**: 6.2+ (Swift 5.9+ compatible)
- **Platforms**: macOS 14.0+, iOS 17.0+ (file storage requires macOS 15.0+/iOS 17.0+)
- **Dependencies**: TextBundle, SwiftFijos (test-only)
- **License**: MIT
