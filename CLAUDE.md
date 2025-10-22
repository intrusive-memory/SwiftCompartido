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

2. **SwiftData Models** (persistent):
   - **NEW in 2.1.0**: `TypedDataStorage` - **Unified storage model (recommended for new code)**
     - Single model for all AI-generated content types
     - MIME-type driven storage routing (text/*, image/*, audio/*, video/*, application/x-embedding)
     - Supports both text and binary storage
     - Full Phase 6 file-based storage support
   - **LEGACY (deprecated)**: `GeneratedTextRecord`, `GeneratedAudioRecord`, `GeneratedImageRecord`, `GeneratedEmbeddingRecord`
     - Kept for backward compatibility with existing code
     - Will be removed in a future major version
     - Use `TypedDataStorage` for new code

**DO NOT consolidate DTO models** - they serve a different purpose (in-memory transfer) from SwiftData models (persistence).

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

### TypedDataStorage Migration (v2.0.1)

**NEW in v2.0.1**: Unified `TypedDataStorage` model replaces 4 separate record types.

**What Changed:**
- `GeneratedTextRecord`, `GeneratedAudioRecord`, `GeneratedImageRecord`, `GeneratedEmbeddingRecord` are now **type aliases** to `TypedDataStorage`
- All functionality preserved - zero breaking changes
- Existing code continues to work without modifications

**Key Features:**
- **MIME-type routing**: Automatically handles text/*, image/*, audio/*, application/x-embedding
- **Smart storage**: In-memory for small content (<10KB text), file-based for large content
- **CloudKit support**: Automatic asset management for .cloudKit and .hybrid storage modes
- **Progress reporting**: Chunked I/O (1MB chunks) with byte-level progress for large files
- **Convenience initializers**: Direct creation from DTO types (GeneratedTextData, etc.)

**Usage Pattern:**
```swift
// Option 1: Use type alias (backward compatible)
let record = GeneratedAudioRecord(
    providerId: "elevenlabs",
    requestorID: "tts.rachel",
    mimeType: "audio/mpeg",
    binaryValue: audioData,
    prompt: "Test",
    audioFormat: "mp3",
    voiceID: "voice-1",
    voiceName: "Rachel"
)

// Option 2: Use TypedDataStorage directly (recommended for new code)
let record = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "tts.rachel",
    mimeType: "audio/mpeg",
    binaryValue: audioData,
    prompt: "Test",
    audioFormat: "mp3",
    voiceID: "voice-1",
    voiceName: "Rachel"
)

// Option 3: Use convenience initializer from DTO
let audioDTO = GeneratedAudioData(/* ... */)
let record = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "tts.rachel",
    data: audioDTO,
    prompt: "Test"
)
```

**Migration Notes:**
- No database migration needed - models are identical
- Existing SwiftData stores work unchanged
- Type aliases will be removed in v3.0.0
- Migrate to TypedDataStorage for future-proofing

## Essential Commands

### Building and Testing

```bash
# Build the package
swift build

# Run all tests (390 tests across 26 suites)
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
- **Primary Model**: `TypedDataStorage` - Unified SwiftData model for all AI-generated content
- **Legacy Aliases (deprecated)**: `GeneratedTextRecord`, `GeneratedAudioRecord`, `GeneratedImageRecord`, `GeneratedEmbeddingRecord`
  - Type aliases to TypedDataStorage for backward compatibility
  - Use TypedDataStorage directly for new code

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

### Composite Key Ordering (chapterIndex, orderIndex)

Elements use composite key ordering for flexible chapter management:

- **Pre-chapter elements**: `chapterIndex=0`, `orderIndex=1, 2, 3...`
- **Chapter 1 elements**: `chapterIndex=1`, `orderIndex=1, 2, 3...` (chapter heading at orderIndex=1)
- **Chapter 2 elements**: `chapterIndex=2`, `orderIndex=1, 2, 3...` (chapter heading at orderIndex=1)
- **Chapter 3 elements**: `chapterIndex=3`, `orderIndex=1, 2, 3...` (chapter heading at orderIndex=1)
- And so on...

**Benefits:**
- **No element limit per chapter** - orderIndex is sequential within each chapter
- Insert elements within chapters without affecting other chapters
- Maintains global order with simple composite key sort: `(chapterIndex, orderIndex)`
- Supports multi-chapter screenplays (novels, series)
- Clear semantic meaning: `(chapter=1, pos=5)` is intuitive

**Chapter Detection:**
Section headings with level 2 (`## Chapter 1`) automatically increment `chapterIndex` and reset `orderIndex` to 1.

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
- **Test framework**: Swift Testing (NOT XCTest) for new tests, XCTest for legacy
- **Test count**: 390 tests across 26 suites
  - ElementOrderingTests: 19 tests (chapter-based ordering)
  - UIOrderingRegressionTests: 10 tests (NEW in 1.6.0)
  - FileIOProgressTests: 13 tests (Phase 6 file I/O progress)
  - CloudKitSupportTests: 17 tests (CloudKit sync patterns)
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

## TypedDataStorage - Unified Content Storage (NEW in 2.1.0)

### Overview

`TypedDataStorage` consolidates the four separate Generated*Record models into a single flexible storage system. It uses MIME types to determine how content is stored and provides type-safe access methods.

### Supported MIME Types

- **Text content**: `text/*` (plain, html, markdown, csv, etc.)
  - Stored in `textValue` field
  - Examples: "text/plain", "text/html", "text/markdown"

- **Image content**: `image/*` (png, jpeg, webp, gif, etc.)
  - Stored in `binaryValue` field
  - Examples: "image/png", "image/jpeg", "image/webp"

- **Audio content**: `audio/*` (mpeg, wav, mp4, flac, ogg, etc.)
  - Stored in `binaryValue` field
  - Examples: "audio/mpeg", "audio/wav", "audio/mp4"

- **Video content**: `video/*` (mp4, mov, avi, etc.)
  - Stored in `binaryValue` field
  - Examples: "video/mp4", "video/quicktime"

- **Embedding vectors**: `application/x-embedding`
  - Stored in `binaryValue` field as Float array data
  - Only this specific application/* type is supported

**Unsupported types** (will throw `TypedDataStorageError.unsupportedMimeType`):
- Other application/* types (pdf, json, zip, etc.)
- Unknown MIME types

### Basic Usage

```swift
// Text storage
let textRecord = TypedDataStorage(
    providerId: "openai",
    requestorID: "gpt-4",
    mimeType: "text/plain",
    textValue: "Generated text content",
    prompt: "Write a story",
    wordCount: 100,
    characterCount: 550
)

// Image storage
let imageRecord = TypedDataStorage(
    providerId: "openai",
    requestorID: "dalle-3",
    mimeType: "image/png",
    binaryValue: imageData,
    prompt: "Generate an image",
    width: 1024,
    height: 1024,
    imageFormat: "png"
)

// Audio storage
let audioRecord = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "tts.rachel",
    mimeType: "audio/mpeg",
    binaryValue: audioData,
    prompt: "Speak this text",
    audioFormat: "mp3",
    durationSeconds: 5.5,
    voiceID: "rachel",
    voiceName: "Rachel"
)

// Embedding storage
let embeddingRecord = TypedDataStorage(
    providerId: "openai",
    requestorID: "text-embedding-3-small",
    mimeType: "application/x-embedding",
    binaryValue: embeddingData,  // Float array as Data
    prompt: "Embed this text",
    dimensions: 1536
)
```

### Convenience Initializers from DTOs

```swift
// From GeneratedTextData
let textData = GeneratedTextData(text: "Hello", model: "gpt-4")
let record = TypedDataStorage(
    providerId: "openai",
    requestorID: "gpt-4",
    data: textData,
    prompt: "Say hello"
)
// Automatically sets mimeType to "text/plain"

// From GeneratedAudioData
let audioData = GeneratedAudioData(
    audioData: mp3Data,
    format: .mp3,
    voiceID: "rachel",
    voiceName: "Rachel",
    model: "eleven_monolingual_v1"
)
let record = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "tts",
    data: audioData,
    prompt: "Speak"
)
// Automatically sets mimeType to "audio/mpeg" based on format

// From GeneratedImageData
let imageData = GeneratedImageData(
    imageData: pngData,
    format: .png,
    width: 1024,
    height: 1024,
    model: "dall-e-3"
)
let record = TypedDataStorage(
    providerId: "openai",
    requestorID: "dalle-3",
    data: imageData,
    prompt: "Generate"
)
// Automatically sets mimeType to "image/png" based on format
```

### Content Retrieval

```swift
// Get text (throws if not text/* MIME type)
let text = try record.getText()

// Get binary data (throws if text/* MIME type)
let data = try record.getBinary()

// Get embedding vector (throws if not application/x-embedding)
let embedding: [Float] = try record.getEmbedding()

// Generic content retrieval (returns Data for both text and binary)
let content = try record.getContent()
```

### File-Based Storage

```swift
// Save text to file
try record.saveText(
    largeText,
    to: storageArea,
    fileName: "content.txt"
)
// Automatically clears textValue, sets fileReference

// Save binary to file
try record.saveBinary(
    imageData,
    to: storageArea,
    fileName: "image.png"
)
// Automatically clears binaryValue, sets fileReference

// Save embedding to file
try record.saveEmbedding(
    embedding,
    to: storageArea,
    fileName: "vector.bin"
)
// Automatically clears binaryValue, sets fileReference
```

### MIME Type Validation

```swift
// Check if MIME type is supported
if TypedDataStorage.isMimeTypeSupported("text/plain") {
    // Supported
}

// Get storage field type for MIME type
let fieldType = try TypedDataStorage.storageFieldType(for: "image/png")
// Returns: "binary"

let fieldType = try TypedDataStorage.storageFieldType(for: "text/html")
// Returns: "text"

// Validate record's MIME type
try record.validateMimeType()
// Throws TypedDataStorageError.unsupportedMimeType if invalid
```

### Migration from Legacy Models

```swift
// Migrate existing records
let oldTextRecord: GeneratedTextRecord = /* ... */
let newRecord = TypedDataStorage.fromTextRecord(oldTextRecord)

let oldAudioRecord: GeneratedAudioRecord = /* ... */
let newRecord = TypedDataStorage.fromAudioRecord(oldAudioRecord)

let oldImageRecord: GeneratedImageRecord = /* ... */
let newRecord = TypedDataStorage.fromImageRecord(oldImageRecord)

let oldEmbeddingRecord: GeneratedEmbeddingRecord = /* ... */
let newRecord = TypedDataStorage.fromEmbeddingRecord(oldEmbeddingRecord)
```

### Owner Reference System

`TypedDataStorage` provides three flexible ways to relate generated content to its owning SwiftData models. This allows you to track which screenplay element, document, or custom model generated each piece of content.

#### 1. Typed Relationships (Recommended for GuionElement/GuionDocument)

For screenplay elements and documents, use the built-in typed relationships:

```swift
// Associate with a screenplay element
let element: GuionElementModel = /* ... */
let audioRecord = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "tts.character",
    mimeType: "audio/mpeg",
    binaryValue: audioData,
    prompt: element.elementText,
    audioFormat: "mp3"
)
audioRecord.owningElement = element
modelContext.insert(audioRecord)

// Later: Find all audio for this element
if let generatedAudio = element.generatedContent?.filter({ $0.mimeType.hasPrefix("audio/") }) {
    for audio in generatedAudio {
        print("Audio duration: \(audio.durationSeconds ?? 0)s")
    }
}
```

```swift
// Associate with a document
let document: GuionDocumentModel = /* ... */
let summaryRecord = TypedDataStorage(
    providerId: "openai",
    requestorID: "gpt-4",
    mimeType: "text/plain",
    textValue: "Document summary...",
    prompt: "Summarize this screenplay"
)
summaryRecord.owningDocument = document
modelContext.insert(summaryRecord)

// Later: Find all generated content for document
if let allContent = document.generatedContent {
    print("Generated \(allContent.count) items for this document")
}
```

**Relationship details:**
- Both relationships use `.nullify` delete rule - deleting TypedDataStorage won't delete the owner
- Bidirectional: Set `owningElement` and SwiftData automatically updates `element.generatedContent`
- Array-based: One element/document can have many TypedDataStorage records

#### 2. Generic Owner Identifier (For Custom Models)

For custom SwiftData models or cross-model references, use `ownerIdentifier`:

```swift
// Custom model
@Model
class CharacterProfile {
    var name: String
    var id: UUID
}

let character = CharacterProfile(name: "John", id: UUID())
modelContext.insert(character)

// Create voice sample for this character
let voiceRecord = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "voice.clone",
    mimeType: "audio/mpeg",
    binaryValue: voiceSample,
    prompt: "Voice sample for \(character.name)"
)

// Store persistent identifier
voiceRecord.ownerIdentifier = character.persistentModelID.uriRepresentation().absoluteString
modelContext.insert(voiceRecord)

// Later: Find all voice samples for this character
let characterID = character.persistentModelID.uriRepresentation().absoluteString
let descriptor = FetchDescriptor<TypedDataStorage>(
    predicate: #Predicate { $0.ownerIdentifier == characterID }
)
let voiceSamples = try modelContext.fetch(descriptor)
```

**Benefits:**
- Works with any SwiftData model
- String-based storage - no type coupling
- Can store any identifier format (UUID strings, URLs, etc.)

#### 3. No Owner (Standalone Content)

Not all generated content needs an owner:

```swift
// Standalone content (e.g., user uploaded file, temporary generation)
let standalone = TypedDataStorage(
    providerId: "user",
    requestorID: "manual.upload",
    mimeType: "image/png",
    binaryValue: imageData,
    prompt: "User uploaded image"
)
// No owner relationships set - perfectly valid
modelContext.insert(standalone)
```

#### Best Practices

**When to use each approach:**

| Use Case | Approach | Example |
|----------|----------|---------|
| Audio for dialogue element | `owningElement` | TTS audio for a character's line |
| Image for scene description | `owningElement` | AI-generated concept art for a scene |
| Document-level summary | `owningDocument` | Script analysis, character list |
| Character voice profile | `ownerIdentifier` | Voice samples associated with character model |
| Location reference images | `ownerIdentifier` | Images linked to custom Location model |
| Temporary/unassociated content | No owner | User uploads, ephemeral generations |

**Querying patterns:**

```swift
// Find all audio for an element
let audioForElement = element.generatedContent?.filter { content in
    content.mimeType.hasPrefix("audio/")
} ?? []

// Find all images for a document
let imagesForDocument = document.generatedContent?.filter { content in
    content.mimeType.hasPrefix("image/")
} ?? []

// Find content by owner identifier
let descriptor = FetchDescriptor<TypedDataStorage>(
    predicate: #Predicate { record in
        record.ownerIdentifier == specificOwnerID
    }
)
let relatedContent = try modelContext.fetch(descriptor)

// Find orphaned content (no owner)
let orphanDescriptor = FetchDescriptor<TypedDataStorage>(
    predicate: #Predicate { record in
        record.owningElement == nil &&
        record.owningDocument == nil &&
        record.ownerIdentifier == nil
    }
)
let orphanedRecords = try modelContext.fetch(orphanDescriptor)
```

**Migration from pre-2.1.0 code:**

If you had custom relationships in your models before TypedDataStorage, migrate them to use the built-in owner system:

```swift
// OLD: Custom relationship in your model
@Model
class MyCustomModel {
    var generatedAudio: [GeneratedAudioRecord]? // OLD
}

// NEW: Use ownerIdentifier instead
@Model
class MyCustomModel {
    var id: UUID = UUID()
    // No direct relationship needed
}

// When creating TypedDataStorage:
let record = TypedDataStorage(/* ... */)
record.ownerIdentifier = myModel.persistentModelID.uriRepresentation().absoluteString

// Query when needed:
let descriptor = FetchDescriptor<TypedDataStorage>(
    predicate: #Predicate {
        $0.ownerIdentifier == myModel.persistentModelID.uriRepresentation().absoluteString
    }
)
let content = try modelContext.fetch(descriptor)
```

## Common Patterns

### Storing AI-Generated Audio

**Recommended Pattern (v2.0.1+):**

```swift
let requestID = UUID()
let storage = StorageAreaReference.temporary(requestID: requestID)

// Create record from DTO (convenience initializer)
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
// Automatically handles: directory creation, file write, file reference creation
try record.saveBinary(audioData, to: storage, fileName: "speech.mp3", mode: .local)

modelContext.insert(record)
try modelContext.save()
```

**Manual Pattern (full control):**

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
let record = TypedDataStorage(
    id: requestID,
    providerId: "elevenlabs",
    requestorID: "tts.rachel",
    mimeType: "audio/mpeg",
    binaryValue: nil,  // File-based storage
    prompt: "Generate speech",
    fileReference: fileRef,
    audioFormat: "mp3",
    voiceID: "rachel",
    voiceName: "Rachel"
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

### Generated Content UI Components (NEW in 2.1.0)

SwiftCompartido provides comprehensive UI components for browsing, filtering, and previewing AI-generated content.

**GeneratedContentListView** - Master-detail interface with filtering:
```swift
@available(macOS 15.0, iOS 17.0, *)
public struct GeneratedContentListView: View {
    let document: GuionDocumentModel
    let storageArea: StorageAreaReference?

    // Features:
    // - MIME type filtering (All, Text, Audio, Image, Video, Embedding)
    // - Preview pane at top showing selected item
    // - Scrollable list at bottom with compact rows
    // - Automatic audio playback when selecting audio items
    // - Content sorted by screenplay order (chapterIndex, orderIndex)
}
```

**TypedDataDetailView** - Automatic content viewer with MIME type routing:
- Displays header with metadata (icon, MIME type, provider, element position)
- Shows prompt
- Routes to appropriate viewer based on MIME type:
  - `text/*` → TypedDataTextView
  - `audio/*` → TypedDataAudioView
  - `image/*` → TypedDataImageView
  - `video/*` → TypedDataVideoView
  - `application/x-embedding` → Custom embedding metadata view

**TypedDataRowView** - Compact list row for generated content:
- Color-coded icon (blue=text, green=audio, orange=image, red=video, purple=embedding)
- Truncated prompt (2 lines max)
- Element position badge (Ch X, Pos Y)
- Type-specific metadata:
  - Audio: Duration (MM:SS)
  - Image: Dimensions (width×height)
  - Text: Word count
  - Embedding: Vector dimensions
- Selection indicator with checkmark

**Document-Level Content Access**:
```swift
// Get all element-owned generated content in screenplay order
let allContent = document.sortedElementGeneratedContent

// Filter by MIME type
let audioContent = document.sortedElementGeneratedContent(mimeTypePrefix: "audio/")

// Filter by element type
let dialogueContent = document.sortedElementGeneratedContent(for: .dialogue)

// All content is returned sorted by (chapterIndex, orderIndex)
// Performance: <100ms for 100+ elements
```

**Usage Example**:
```swift
@available(macOS 15.0, iOS 17.0, *)
struct GeneratedContentView: View {
    @StateObject private var audioPlayer = AudioPlayerManager()
    let document: GuionDocumentModel
    let storageArea: StorageAreaReference?

    var body: some View {
        GeneratedContentListView(document: document, storageArea: storageArea)
            .environmentObject(audioPlayer)
    }
}
```

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

### Generated Content UI Components (NEW in 2.1.0)

SwiftCompartido provides comprehensive UI components for browsing, filtering, and previewing AI-generated content.

**GeneratedContentListView** - Master-detail interface with filtering:
```swift
@available(macOS 15.0, iOS 17.0, *)
public struct GeneratedContentListView: View {
    let document: GuionDocumentModel
    let storageArea: StorageAreaReference?

    // Features:
    // - MIME type filtering (All, Text, Audio, Image, Video, Embedding)
    // - Preview pane at top showing selected item
    // - Scrollable list at bottom with compact rows
    // - Automatic audio playback when selecting audio items
    // - Content sorted by screenplay order (chapterIndex, orderIndex)
}
```

**TypedDataDetailView** - Automatic content viewer with MIME type routing:
- Displays header with metadata (icon, MIME type, provider, element position)
- Shows prompt
- Routes to appropriate viewer based on MIME type:
  - `text/*` → TypedDataTextView
  - `audio/*` → TypedDataAudioView
  - `image/*` → TypedDataImageView
  - `video/*` → TypedDataVideoView
  - `application/x-embedding` → Custom embedding metadata view

**TypedDataRowView** - Compact list row for generated content:
- Color-coded icon (blue=text, green=audio, orange=image, red=video, purple=embedding)
- Truncated prompt (2 lines max)
- Element position badge (Ch X, Pos Y)
- Type-specific metadata:
  - Audio: Duration (MM:SS)
  - Image: Dimensions (width×height)
  - Text: Word count
  - Embedding: Vector dimensions
- Selection indicator with checkmark

**Document-Level Content Access**:
```swift
// Get all element-owned generated content in screenplay order
let allContent = document.sortedElementGeneratedContent

// Filter by MIME type
let audioContent = document.sortedElementGeneratedContent(mimeTypePrefix: "audio/")

// Filter by element type
let dialogueContent = document.sortedElementGeneratedContent(for: .dialogue)

// All content is returned sorted by (chapterIndex, orderIndex)
// Performance: <100ms for 100+ elements
```

**Usage Example**:
```swift
@available(macOS 15.0, iOS 17.0, *)
struct GeneratedContentView: View {
    @StateObject private var audioPlayer = AudioPlayerManager()
    let document: GuionDocumentModel
    let storageArea: StorageAreaReference?

    var body: some View {
        GeneratedContentListView(document: document, storageArea: storageArea)
            .environmentObject(audioPlayer)
    }
}
```

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
let record = TypedDataStorage(
    providerId: "openai",
    requestorID: "gpt-4",
    mimeType: "text/plain",
    textValue: "Generated content",
    prompt: "Generate text",
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
let record = TypedDataStorage(
    providerId: "openai",
    requestorID: "gpt-4",
    mimeType: "text/plain",
    textValue: "Synced content",
    prompt: "Generate text",
    storageMode: .cloudKit,  // Enable sync
    wordCount: 2,
    characterCount: 13
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

let record = TypedDataStorage(
    id: requestID,
    providerId: "elevenlabs",
    requestorID: "tts.rachel",
    mimeType: "audio/mpeg",
    binaryValue: nil,
    prompt: "Generate speech",
    audioFormat: "mp3",
    voiceID: "rachel",
    voiceName: "Rachel"
)

// Saves to BOTH local .guion bundle AND CloudKit
// Automatically populates cloudKitAsset and sets syncStatus to .pending
try record.saveBinary(audioData, to: storage, fileName: "audio.mp3", mode: .hybrid)

// Loading tries CloudKit first, then in-memory, then file-based
let loadedData = try record.getBinary(from: storage)
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
let newRecord = TypedDataStorage(
    providerId: "openai",
    requestorID: "gpt-4",
    mimeType: "text/plain",
    textValue: "New content",
    prompt: "Generate",
    storageMode: .cloudKit,  // Only new records sync
    wordCount: 2,
    characterCount: 11
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

- **Version**: 2.1.0 (with Generated Content UI Components)
- **Swift**: 6.2+
- **Platforms**: macOS 26.0+, iOS 26.0+, Mac Catalyst 26.0+
- **Dependencies**: TextBundle, SwiftFijos (test-only)
- **CI/CD**: GitHub Actions on macOS-latest with Xcode 16.0+
  - Parallel test execution (80% of CPUs, 2-3x faster)
  - Automated Mac Catalyst build checks
  - Platform API compatibility validation
  - Code quality checks
- **License**: MIT
- **Test Coverage**: 95%+ across 397 tests in 27 suites
  - GeneratedContentListView: Master-detail UI with MIME type filtering
  - TypedDataDetailView: Automatic content viewer with MIME routing
  - TypedDataRowView: Compact list rows with type-specific metadata
  - Document-level content access: Sorted by screenplay order (chapterIndex, orderIndex)
  - TypedDataStorage migration: Complete with zero breaking changes
  - CloudKit support: Automatic asset management and conflict tracking
  - Progress reporting: Chunked I/O with byte-level progress for large files
