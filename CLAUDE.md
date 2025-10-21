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

# Run all tests (363 tests across 25 suites)
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
  - `Sources/SwiftCompartido/UI/` - SwiftUI components for viewing parsed SwiftData
  - `Sources/SwiftCompartido/UI/Elements/` - Individual element view components
  - `Sources/SwiftCompartido/SwiftDataModels/` - SwiftData @Model classes (NEW in 1.6.0)
  - `Tests/SwiftCompartidoTests/` - Test suites using Swift Testing framework

### Model Categories

**Screenplay Models:**
- `GuionParsedElementCollection` - **Main screenplay container (recommended entry point)**
- `GuionElement`, `ElementType` - Screenplay element tree
- `FountainParser`, `FDXParser` - Format parsers (use via GuionParsedElementCollection)
- `FountainWriter`, `FDXDocumentWriter` - Format export

**✅ ALWAYS use `GuionParsedElementCollection` for parsing** - avoid calling parsers directly.

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

**SwiftUI Components (Flat Architecture):**
- `GuionViewer` - Thin wrapper around GuionElementsList for document viewing
- `GuionElementsList` - SwiftData @Query-based list view displaying elements in sequential order
- Element Views (in `UI/Elements/`) - Dedicated views for each element type:
  - `ActionView`, `DialogueTextView`, `DialogueCharacterView`, `DialogueParentheticalView`, `DialogueLyricsView`
  - `SceneHeadingView`, `TransitionView`, `SectionHeadingView`
  - `SynopsisView`, `CommentView`, `BoneyardView`, `PageBreakView`
- `AudioPlayerManager` - Audio playback manager for generated audio

**Display Architecture:**
- ✅ **Flat, sequential** - Elements displayed in document order
- ✅ **No hierarchy** - No grouping or nesting of elements
- ✅ **Simple switch/case** - Each element type rendered by its dedicated view
- ✅ **No visible separators** - Clean flow between elements (NEW in 1.6.0)
- ⚠️ **Removed**: SceneBrowserWidget, ChapterWidget, SceneGroupWidget (old hierarchical architecture)

## Element Ordering (NEW in 1.6.0)

### CRITICAL: Always Use sortedElements

**SwiftData @Relationship arrays do NOT guarantee order!**

```swift
// ❌ WRONG - Order not guaranteed
for element in document.elements {
    displayElement(element)  // May be scrambled!
}

// ✅ CORRECT - Always sorted by orderIndex
for element in document.sortedElements {
    displayElement(element)  // Perfect sequence
}
```

### Chapter-Based OrderIndex Spacing

Elements are assigned `orderIndex` values with intelligent chapter spacing:

- **Pre-chapter elements**: 0-99
- **Chapter 1 elements**: 100-199 (chapter heading at 100)
- **Chapter 2 elements**: 200-299 (chapter heading at 200)
- **Chapter 3 elements**: 300-399 (chapter heading at 300)
- And so on...

**Benefits:**
- Insert elements within chapters without renumbering
- Maintains global order across entire screenplay
- Supports multi-chapter screenplays (novels, series)

**Chapter Detection:**
Section headings with level 2 (`## Chapter 1`) automatically trigger chapter numbering.

### When to Use sortedElements

**ALWAYS use `document.sortedElements` for:**
- ✅ Displaying elements in UI
- ✅ Exporting to Fountain/FDX
- ✅ Serializing to JSON/TextPack
- ✅ Extracting scenes in order
- ✅ Processing elements sequentially

**Performance:** <1% overhead (thoroughly optimized)

### UI Components Use OrderIndex

`GuionElementsList` automatically sorts by orderIndex:

```swift
public struct GuionElementsList: View {
    @Query(sort: [SortDescriptor(\GuionElementModel.orderIndex)])
    private var elements: [GuionElementModel]

    public var body: some View {
        List {
            ForEach(elements) { element in
                // Element views...
            }
            .listRowSeparator(.hidden)  // NEW in 1.6.0
            .listRowInsets(EdgeInsets())  // NEW in 1.6.0
        }
    }
}
```

## Testing Requirements

- **Minimum coverage**: 90% (current: 95%+)
- **Test framework**: Swift Testing (NOT XCTest)
- **Test count**: 363 tests across 25 test suites
  - ElementOrderingTests: 19 tests (chapter-based ordering)
  - UIOrderingRegressionTests: 10 tests (NEW in 1.6.0)
- Use `@Test("description")` macro, not `func test...`
- ⚠️ **Removed**: SceneBrowserWidget, ChapterWidget, SceneGroupWidget (old hierarchical architecture)

## Testing Requirements

- **Minimum coverage**: 90% (current: 95%+)
- **Test framework**: Swift Testing (NOT XCTest) for new tests, XCTest for legacy
- **Test count**: 314 tests in 22 suites
- Use `@Test("description")` macro for new tests, not `func test...`
- All tests must pass before merging PRs
- Parallel testing enabled in CI (2-3x faster)

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
  - Test job: Run all 314 tests with coverage (parallel execution enabled)
  - Mac Catalyst Build Check: Verify platform compatibility
  - Code Quality: Check for TODOs, large files, print statements
- Enforced for all users including admins

**Workflow:** Create PR → Tests run automatically in parallel (2-3x faster) → Merge when green

**Parallel Testing:**
- CI uses 80% of available CPUs for test workers
- Local development: `swift test --parallel --num-workers 10 -j 12`
- See `FAST_TESTING.md` for full guide

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

### Parsing and Viewing Screenplays

The library provides a complete workflow for parsing screenplay files into SwiftData and displaying them:

```swift
// 1. Parse Fountain file
// ✅ Use GuionParsedElementCollection (recommended)
let screenplay = try await GuionParsedElementCollection(string: fountainText)

// 2. Convert to SwiftData
let document = await GuionDocumentParserSwiftData.parse(
    script: screenplay,
    in: modelContext,
    generateSummaries: false
)

// 3. Display in SwiftUI
struct ContentView: View {
    let document: GuionDocumentModel

    var body: some View {
        GuionViewer(document: document)
    }
}
```

### UI Component Architecture

SwiftCompartido uses a simplified, list-based UI architecture:

**GuionViewer** - Top-level viewer component:
```swift
public struct GuionViewer: View {
    private let document: GuionDocumentModel

    public init(document: GuionDocumentModel) {
        self.document = document
    }

    public var body: some View {
        GuionElementsList(document: document)
    }
}
```

**GuionElementsList** - SwiftData @Query-based list:
```swift
public struct GuionElementsList: View {
    @Query private var elements: [GuionElementModel]
    @Environment(\.screenplayFontSize) var fontSize

    // Filtered to specific document
    public init(document: GuionDocumentModel) {
        let documentID = document.persistentModelID
        _elements = Query(
            filter: #Predicate<GuionElementModel> { element in
                element.document?.persistentModelID == documentID
            }
        )
    }

    public var body: some View {
        List {
            ForEach(elements) { element in
                // Switch on element type to display appropriate view
                switch element.elementType {
                case .action: ActionView(element: element)
                case .dialogue: DialogueTextView(element: element)
                case .sceneHeading: SceneHeadingView(element: element)
                // ... other element types
                }
            }
        }
    }
}
```

**Element Views** - Individual element rendering:
- `ActionView` - Action lines with 10% margins
- `DialogueTextView` - Dialogue with 25% margins
- `DialogueCharacterView` - Character names
- `SceneHeadingView` - Scene headings
- `TransitionView` - Scene transitions
- Plus 7 more element types

All elements use Courier New font and proper screenplay formatting.

## Source File Tracking

GuionDocumentModel now tracks the original source file and can detect when it has been modified, allowing applications to prompt users to re-import updated versions.

### New Properties

```swift
/// Security-scoped bookmark to the original source file
public var sourceFileBookmark: Data?

/// Date when this document was last imported from source
public var lastImportDate: Date?

/// Modification date of source file at time of import
public var sourceFileModificationDate: Date?
```

### Setting Source File on Import

```swift
// When importing a screenplay
// ✅ Use GuionParsedElementCollection (recommended)
let screenplay = try await GuionParsedElementCollection(
    file: sourceURL.path,
    progress: nil
)
let document = await GuionDocumentModel.from(screenplay, in: modelContext)

// Set source file (creates security-scoped bookmark)
document.setSourceFile(sourceURL)
try modelContext.save()
```

### Checking for Updates

**GuionElementsList** - SwiftData @Query-based list:
```swift
// Quick check
if document.isSourceFileModified() {
    // Prompt user to re-import
    showUpdatePrompt()
}

// Detailed status
let status = document.sourceFileStatus()
switch status {
case .modified:
    // Source file has changed - prompt user
    showUpdateAlert()
case .upToDate:
    // All good
    break
case .noSourceFile:
    // Document wasn't imported from a file
    break
case .fileNotAccessible:
    // Permissions issue
    showPermissionsError()
case .fileNotFound:
    // File was moved or deleted
    showFileNotFoundError()
}
```

### Re-importing from Source

```swift
if let sourceURL = document.resolveSourceFileURL() {
    // Start security-scoped access
    let accessing = sourceURL.startAccessingSecurityScopedResource()
    defer {
        if accessing {
            sourceURL.stopAccessingSecurityScopedResource()
public struct GuionElementsList: View {
    @Query private var elements: [GuionElementModel]
    @Environment(\.screenplayFontSize) var fontSize

    // Filtered to specific document
    public init(document: GuionDocumentModel) {
        let documentID = document.persistentModelID
        _elements = Query(
            filter: #Predicate<GuionElementModel> { element in
                element.document?.persistentModelID == documentID
            }
        )
    }

    public var body: some View {
        List {
            ForEach(elements) { element in
                // Switch on element type to display appropriate view
                switch element.elementType {
                case .action: ActionView(element: element)
                case .dialogue: DialogueTextView(element: element)
                case .sceneHeading: SceneHeadingView(element: element)
                // ... other element types
                }
            }
        }
    }

    // Re-import the updated file
    // ✅ Use GuionParsedElementCollection (recommended)
    let screenplay = try await GuionParsedElementCollection(
        file: sourceURL.path,
        progress: nil
    )

    // Update document elements...
    document.setSourceFile(sourceURL)  // Update timestamps
    try modelContext.save()
}
```

### Source File Status Enum

```swift
public enum SourceFileStatus: Sendable {
    case noSourceFile          // No source file set
    case fileNotAccessible     // Cannot resolve bookmark
    case fileNotFound          // File moved/deleted
    case modified              // File has been updated
    case upToDate              // File is current

    var shouldPromptForUpdate: Bool  // True for .modified
}
```

**Element Views** - Individual element rendering:
- `ActionView` - Action lines with 10% margins
- `DialogueTextView` - Dialogue with 25% margins
- `DialogueCharacterView` - Character names
- `SceneHeadingView` - Scene headings
- `TransitionView` - Scene transitions
- Plus 7 more element types

All elements use Courier New font and proper screenplay formatting.

## Source File Tracking

GuionDocumentModel now tracks the original source file and can detect when it has been modified, allowing applications to prompt users to re-import updated versions.

### New Properties

```swift
/// Security-scoped bookmark to the original source file
public var sourceFileBookmark: Data?

/// Date when this document was last imported from source
public var lastImportDate: Date?

/// Modification date of source file at time of import
public var sourceFileModificationDate: Date?
```

### Setting Source File on Import

```swift
// When importing a screenplay
// ✅ Use GuionParsedElementCollection (recommended)
let screenplay = try await GuionParsedElementCollection(
    file: sourceURL.path,
    progress: nil
)
let document = await GuionDocumentModel.from(screenplay, in: modelContext)

// Set source file (creates security-scoped bookmark)
document.setSourceFile(sourceURL)
try modelContext.save()
```

### Checking for Updates

```swift
// Quick check
if document.isSourceFileModified() {
    // Prompt user to re-import
    showUpdatePrompt()
}

// Detailed status
let status = document.sourceFileStatus()
switch status {
case .modified:
    // Source file has changed - prompt user
    showUpdateAlert()
case .upToDate:
    // All good
    break
case .noSourceFile:
    // Document wasn't imported from a file
    break
case .fileNotAccessible:
    // Permissions issue
    showPermissionsError()
case .fileNotFound:
    // File was moved or deleted
    showFileNotFoundError()
}
```

### Re-importing from Source

```swift
if let sourceURL = document.resolveSourceFileURL() {
    // Start security-scoped access
    let accessing = sourceURL.startAccessingSecurityScopedResource()
    defer {
        if accessing {
            sourceURL.stopAccessingSecurityScopedResource()
        }
    }

    // Re-import the updated file
    // ✅ Use GuionParsedElementCollection (recommended)
    let screenplay = try await GuionParsedElementCollection(
        file: sourceURL.path,
        progress: nil
    )

    // Update document elements...
    document.setSourceFile(sourceURL)  // Update timestamps
    try modelContext.save()
}
```

### Source File Status Enum

```swift
public enum SourceFileStatus: Sendable {
    case noSourceFile          // No source file set
    case fileNotAccessible     // Cannot resolve bookmark
    case fileNotFound          // File moved/deleted
    case modified              // File has been updated
    case upToDate              // File is current

    var shouldPromptForUpdate: Bool  // True for .modified
}
```

**See `SOURCE_FILE_TRACKING.md` for complete documentation including:**
- SwiftUI integration examples
- Security considerations for sandboxed apps
- Migration guide for existing documents
- Periodic checking patterns
- Testing strategies

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

// ✅ Use GuionParsedElementCollection (recommended)
let screenplay = try await GuionParsedElementCollection(
    string: fountainText,
    progress: progress
)
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

    func parseScreenplay(_ text: String) async throws -> GuionParsedElementCollection {
        let progress = OperationProgress(totalUnits: nil) { update in
            Task { @MainActor in
                self.progressMessage = update.description
                self.progressFraction = update.fractionCompleted ?? 0.0
            }
        }

        // ✅ Use GuionParsedElementCollection (recommended)
        return try await GuionParsedElementCollection(string: text, progress: progress)
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
    // ✅ Use GuionParsedElementCollection (recommended)
    return try await GuionParsedElementCollection(string: largeScript, progress: progress)
}

// Cancel from UI
parseTask.cancel()

do {
    let screenplay = try await parseTask.value
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

**Total**: 314 tests across 22 test suites with 95%+ coverage.

### Backward Compatibility

All progress parameters default to `nil` - existing code continues to work without modifications:

```swift
// Synchronous - still works (backward compatible)
let screenplay = try GuionParsedElementCollection(file: path)

// Async with optional progress - recommended
let progress = OperationProgress(totalUnits: nil)
let screenplay = try await GuionParsedElementCollection(string: text, progress: progress)

// Async without progress - also works
let screenplay = try await GuionParsedElementCollection(string: text)
```

## Documentation Resources

- `README.md` - User-facing overview
- `CLAUDE.md` - This file - architecture guide for Claude Code
- `AI-REFERENCE.md` - Comprehensive API reference
- `SOURCE_FILE_TRACKING.md` - Complete guide to source file tracking feature
- `FAST_TESTING.md` - Parallel testing guide for faster development
- `TRUNCATION_DEBUG.md` - Debugging guide for UI text truncation issues
- `QUICK_FIX.md` - Quick reference for common fixes
- `CHANGELOG.md` - Version history
- `CONTRIBUTING.md` - Contribution guidelines

## Project Metadata

- **Version**: 2.0.0 (with Chapter-Based Element Ordering, Mac Catalyst Support & UI Improvements)
- **Swift**: 6.2+
- **Platforms**: macOS 26.0+, iOS 26.0+, Mac Catalyst 26.0+
- **Dependencies**: TextBundle, SwiftFijos (test-only)
- **CI/CD**: GitHub Actions on macOS-latest with Xcode 16.0+
  - Parallel test execution (80% of CPUs, 2-3x faster)
  - Automated Mac Catalyst build checks
  - Platform API compatibility validation
  - Code quality checks
- **License**: MIT
- **Test Coverage**: 95%+ across 363 tests in 25 suites
