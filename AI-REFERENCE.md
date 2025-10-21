# SwiftCompartido - AI Reference Guide

> **For AI Assistants**: This document provides comprehensive guidance for understanding, using, and building upon the SwiftCompartido library.

**Version**: 1.6.0
**Swift Version**: 6.2+
**Platforms**: macOS 26.0+, iOS 26.0+, Mac Catalyst 26.0+
**Last Updated**: 2025-10-20

---

## Table of Contents

1. [Library Overview](#library-overview)
2. [Architecture & Design Patterns](#architecture--design-patterns)
3. [Element Ordering Architecture](#element-ordering-architecture) ⭐ NEW in 1.6.0
4. [Core Models Reference](#core-models-reference)
5. [Progress Reporting](#progress-reporting)
6. [Common Usage Patterns](#common-usage-patterns)
7. [Best Practices](#best-practices)
8. [Integration Examples](#integration-examples)
9. [Error Handling](#error-handling)
10. [Testing Guidance](#testing-guidance)
11. [Performance Considerations](#performance-considerations)

---

## Library Overview

### What is SwiftCompartido?

SwiftCompartido is a Swift package that provides:

1. **Screenplay Parsing**: Parse Fountain & FDX screenplay files into structured data
2. **SwiftData Conversion**: Convert parsed screenplays into SwiftData models for persistence
3. **UI Components**: SwiftUI views for displaying SwiftData screenplay documents
4. **AI Content Storage**: File-based storage for AI-generated text, audio, images, and embeddings
5. **Progress Reporting**: Comprehensive progress tracking for all long-running operations

**Core Purpose**: Parse screenplay files → Convert to SwiftData → Display with SwiftUI components

### Key Capabilities

```swift
// 1. Parse screenplays with progress reporting
let progress = OperationProgress(totalUnits: nil) { update in
    print("\(update.description): \(update.fractionCompleted ?? 0.0)")
}
let parser = try await FountainParser(string: fountainText, progress: progress)

// 2. Convert to SwiftData
let document = await GuionDocumentParserSwiftData.parse(
    script: parser.screenplay,
    in: modelContext,
    generateSummaries: false
)

// 3. Display in SwiftUI with automatic data binding
struct ContentView: View {
    let document: GuionDocumentModel

    var body: some View {
        GuionViewer(document: document)
        // GuionViewer uses @Query to display GuionElementModels from SwiftData
    }
}

// Store AI-generated audio with file-based storage
let record = GeneratedAudioRecord(
    providerId: "elevenlabs",
    audioData: nil, // Data stored in file
    fileReference: fileRef // Points to actual file
)

// Track AI request lifecycle
let status = RequestStatus.executing(progress: 0.5)
```

---

## Architecture & Design Patterns

### Phase 6 Architecture

**Principle**: Large data (audio, images, embeddings) is stored in files, not in-memory or in the database.

**Pattern**:
```
In-Memory DTO          SwiftData Model           File Storage
┌──────────────┐       ┌─────────────────┐      ┌──────────────┐
│ AudioData    │  ───> │ AudioRecord     │ ───> │ audio.mp3    │
│ (Codable)    │       │ + fileReference │      │ (on disk)    │
└──────────────┘       └─────────────────┘      └──────────────┘
```

### Model Pairs Pattern

The library uses paired models for different contexts:

| Context | Model Type | Purpose | Example |
|---------|------------|---------|---------|
| **Network/API** | Lightweight DTO | Transfer data | `Voice` |
| **Persistence** | SwiftData @Model | Database storage | `VoiceModel` |
| **In-Memory** | Codable struct | Processing | `GeneratedAudioData` |
| **Persistence** | SwiftData @Model | File references | `GeneratedAudioRecord` |

**Conversion Pattern**:
```swift
// DTO → SwiftData Model
let voiceModel = VoiceModel.from(voice)

// SwiftData Model → DTO
let voice = voiceModel.toVoice()
```

### Concurrency & Sendable

**All models are `Sendable`** for Swift 6 concurrency safety:

```swift
// Safe to use across actor boundaries
await Task {
    let response = AIResponseData(...)
    await processResponse(response) // ✅ Works
}.value
```

---

## Element Ordering Architecture

### Critical: Screenplay Sequence Must Be Preserved

**NEW in 1.6.0**: SwiftCompartido provides robust element ordering to ensure screenplay elements always appear in their original sequence.

### The OrderIndex System

Every `GuionElementModel` has an `orderIndex: Int` field that determines its position in the screenplay:

```swift
@Model
public final class GuionElementModel {
    public var orderIndex: Int  // CRITICAL for sequence
    public var elementText: String
    // ...
}
```

### Chapter-Based Spacing

Elements are assigned orderIndex values with intelligent chapter spacing:

| Position | orderIndex Range | Example |
|----------|-----------------|---------|
| Pre-chapter elements | 0-99 | Title page, opening action |
| Chapter 1 elements | 100-199 | Chapter heading at 100, elements 101-199 |
| Chapter 2 elements | 200-299 | Chapter heading at 200, elements 201-299 |
| Chapter 3 elements | 300-399 | Chapter heading at 300, elements 301-399 |

**Benefits**:
- Insert elements within chapters without renumbering
- Maintains global order across entire screenplay
- Supports multi-chapter screenplays (novels, series)
- Allows chapter reorganization without element conflicts

**How It Works**:
```swift
// Chapter detection: Section heading level 2
let chapterHeading = GuionElement(
    elementType: .sectionHeading(level: 2),
    elementText: "# Chapter 1"
)
// Automatically gets orderIndex 100

// Following elements get 101, 102, 103...
```

### ⚠️ CRITICAL: Always Use sortedElements

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

### GuionDocumentModel.sortedElements

**Always use this computed property for element access**:

```swift
public var sortedElements: [GuionElementModel] {
    elements.sorted { $0.orderIndex < $1.orderIndex }
}
```

**When to Use**:
- ✅ Displaying elements in UI
- ✅ Exporting to Fountain/FDX
- ✅ Serializing to JSON/TextPack
- ✅ Extracting scenes in order
- ✅ Processing elements sequentially
- ✅ ANY operation where order matters

**Performance**: <1% overhead for sorting (thoroughly optimized)

### Common Anti-Patterns (DON'T DO THESE!)

```swift
// ❌ ANTI-PATTERN 1: Direct elements access
let screenplay = document.toGuionParsedElementCollection()
// BUG: Uses elements instead of sortedElements
let elements = document.elements.map { GuionElement(from: $0) }

// ✅ CORRECT
let elements = document.sortedElements.map { GuionElement(from: $0) }

// ❌ ANTI-PATTERN 2: Scene extraction without order
let scenes = document.elements.filter { $0.elementType == .sceneHeading }
// BUG: Scenes may be out of order

// ✅ CORRECT
let scenes = document.sortedElements.filter { $0.elementType == .sceneHeading }

// ❌ ANTI-PATTERN 3: Snapshot creation without order
let snapshot = document.elements.map { ElementSnapshot(from: $0) }
// BUG: Serialization corrupts order

// ✅ CORRECT
let snapshot = document.sortedElements.map { ElementSnapshot(from: $0) }
```

### UI Components & Ordering

**GuionElementsList** uses `@Query` with `SortDescriptor`:

```swift
public struct GuionElementsList: View {
    @Query(sort: [SortDescriptor(\GuionElementModel.orderIndex)])
    private var elements: [GuionElementModel]

    public var body: some View {
        List {
            ForEach(elements) { element in
                // Element views...
            }
            .listRowSeparator(.hidden)  // NEW in 1.6.0: Seamless appearance
        }
    }
}
```

**Key Features (1.6.0)**:
- Automatic sorting via `SortDescriptor(\GuionElementModel.orderIndex)`
- No visible separators between elements (clean flow)
- Zero insets for traditional screenplay appearance

### Testing OrderIndex Correctness

**363 tests** ensure ordering works correctly, including:

```swift
// Test 1: Chapter-based spacing
#expect(elements[0].orderIndex == 0)      // Pre-chapter
#expect(elements[1].orderIndex == 100)    // Chapter 1 heading
#expect(elements[2].orderIndex == 101)    // Chapter 1 element
#expect(elements[3].orderIndex == 200)    // Chapter 2 heading

// Test 2: sortedElements vs elements
document.elements.shuffle()  // Deliberately scramble
let sorted = document.sortedElements
#expect(sorted[0].elementText == "Element 0")  // Still in order!

// Test 3: Round-trip preservation
let converted = document.toGuionParsedElementCollection()
#expect(converted.elements.count == originalElements.count)
for (index, element) in converted.elements.enumerated() {
    #expect(element.elementText == originalTexts[index])  // Order preserved
}
```

### Migration from Pre-1.6.0 Code

**No breaking changes** - but recommended updates:

```swift
// Before (may have bugs):
func processScreenplay(_ document: GuionDocumentModel) {
    for element in document.elements {  // ⚠️ Risky
        process(element)
    }
}

// After (safe):
func processScreenplay(_ document: GuionDocumentModel) {
    for element in document.sortedElements {  // ✅ Guaranteed order
        process(element)
    }
}
```

### File Organization (NEW in 1.6.0)

SwiftData models extracted to separate files:

```
Sources/SwiftCompartido/SwiftDataModels/
├── GuionDocumentModel.swift     (793 lines)
├── GuionElementModel.swift      (262 lines)
└── TitlePageEntryModel.swift    (64 lines)
```

**Benefits**:
- Better code navigation
- Clearer model boundaries
- Easier maintenance

---

## Core Models Reference

### 1. AI Response Models

#### AIResponseData

**Purpose**: Primary response type for all AI operations with typed content.

**Structure**:
```swift
public struct AIResponseData: Sendable {
    public let requestID: UUID
    public let providerID: String
    public let result: Result<ResponseContent, AIServiceError>
    public let receivedAt: Date
    public let metadata: [String: String]
    public let usage: UsageStats?

    // Convenience accessors
    public var content: ResponseContent? { /* ... */ }
    public var error: AIServiceError? { /* ... */ }
    public var isSuccess: Bool { /* ... */ }
}
```

**Content Types**:
```swift
public enum ResponseContent: Sendable {
    case text(String)
    case data(Data)
    case audio(Data, format: AudioFormat)
    case image(Data, format: ImageFormat)
    case structured([String: SendableValue])

    // Accessors
    public var text: String? { /* ... */ }
    public var audioContent: (data: Data, format: AudioFormat)? { /* ... */ }
}
```

**When to Use**:
- ✅ All AI provider responses
- ✅ Request status tracking (in `RequestStatus.completed`)
- ✅ Type-safe content handling
- ❌ Don't use for large file storage (use GeneratedAudioRecord instead)

**Example**:
```swift
// Success response
let response = AIResponseData(
    requestID: requestID,
    providerID: "openai",
    content: .text("Generated content"),
    metadata: ["model": "gpt-4"],
    usage: UsageStats(
        promptTokens: 100,
        completionTokens: 50,
        totalTokens: 150,
        costUSD: 0.002
    )
)

// Error response
let errorResponse = AIResponseData(
    requestID: requestID,
    providerID: "anthropic",
    error: .rateLimitExceeded("Rate limit hit", retryAfter: 60)
)
```

---

#### UsageStats

**Purpose**: Unified token/cost tracking across all AI operations.

**Structure**:
```swift
public struct UsageStats: Sendable, Equatable {
    public let promptTokens: Int?
    public let completionTokens: Int?
    public let totalTokens: Int?
    public let costUSD: Decimal?
    public let durationSeconds: TimeInterval?

    public var cost: Decimal? { costUSD } // Legacy compatibility
}
```

**When to Use**:
- ✅ Track token usage for all AI requests
- ✅ Calculate costs across providers
- ✅ Monitor API usage
- ✅ Display usage stats to users

**Example**:
```swift
let usage = UsageStats(
    promptTokens: 500,
    completionTokens: 1500,
    totalTokens: 2000,
    costUSD: 0.04, // 4 cents
    durationSeconds: 2.5
)

// Accumulate usage across requests
let totalUsage = requests.reduce(UsageStats()) { acc, request in
    guard let usage = request.usage else { return acc }
    return UsageStats(
        promptTokens: (acc.promptTokens ?? 0) + (usage.promptTokens ?? 0),
        completionTokens: (acc.completionTokens ?? 0) + (usage.completionTokens ?? 0),
        totalTokens: (acc.totalTokens ?? 0) + (usage.totalTokens ?? 0),
        costUSD: (acc.costUSD ?? 0) + (usage.costUSD ?? 0),
        durationSeconds: (acc.durationSeconds ?? 0) + (usage.durationSeconds ?? 0)
    )
}
```

---

#### AIRequestStatus & RequestStatus

**Purpose**: Track AI request lifecycle with progress.

**Structure**:
```swift
public enum RequestStatus: Sendable {
    case pending
    case executing(progress: Double?)
    case completed(AIResponseData)
    case failed(AIServiceError)
    case cancelled

    // Convenience properties
    public var isInProgress: Bool { /* ... */ }
    public var responseData: AIResponseData? { /* ... */ }
}

public struct TrackedRequest: Sendable, Identifiable {
    public let request: AIRequest
    public let status: RequestStatus
    public let providerID: String
    public let submittedAt: Date
    public let startedAt: Date?
    public let finishedAt: Date?
    public var duration: TimeInterval? { /* ... */ }
}
```

**When to Use**:
- ✅ Track long-running AI requests
- ✅ Show progress to users
- ✅ Implement retry logic
- ✅ Queue management

**Example**:
```swift
@Observable
class AIRequestTracker {
    var trackedRequests: [UUID: TrackedRequest] = [:]

    func submitRequest(_ request: AIRequest, to providerID: String) {
        let tracked = TrackedRequest(
            request: request,
            status: .pending,
            providerID: providerID,
            submittedAt: Date()
        )
        trackedRequests[request.id] = tracked
    }

    func updateProgress(_ requestID: UUID, progress: Double) {
        guard let tracked = trackedRequests[requestID] else { return }
        trackedRequests[requestID] = tracked.withProgress(progress)
    }

    func completeRequest(_ requestID: UUID, response: AIResponseData) {
        guard let tracked = trackedRequests[requestID] else { return }
        trackedRequests[requestID] = tracked.withStatus(.completed(response))
    }
}
```

---

### 2. Generated Content Models

#### GeneratedAudioRecord

**Purpose**: SwiftData model for storing AI-generated audio with file reference support.

**Structure**:
```swift
@Model
public final class GeneratedAudioRecord {
    public var requestID: UUID
    public var providerId: String
    public var requestorID: String

    // Audio data (optional - prefer file storage)
    public var audioData: Data?

    // Audio metadata
    public var format: String // "mp3", "wav", etc.
    public var durationSeconds: TimeInterval?
    public var sampleRate: Int?
    public var bitRate: Int?
    public var channels: Int?

    // Voice metadata
    public var voiceID: String?
    public var voiceName: String?
    public var prompt: String

    // File storage (Phase 6)
    public var fileReference: TypedDataFileReference?

    // Timestamps
    public var createdAt: Date
    public var modifiedAt: Date
}
```

**When to Use**:
- ✅ Store TTS audio from providers
- ✅ Persist audio with metadata
- ✅ Reference audio files on disk
- ❌ Don't use for streaming audio (use AVAudioPlayer directly)

**Storage Strategies**:

**Strategy 1: File-Based (Recommended)**
```swift
// 1. Save audio to file
let storage = StorageAreaReference.temporary(requestID: requestID)
try storage.createDirectoryIfNeeded()

let audioURL = storage.fileURL(for: "speech.mp3")
try audioData.write(to: audioURL)

// 2. Create file reference
let fileRef = TypedDataFileReference(
    requestID: requestID,
    fileName: "speech.mp3",
    fileSize: Int64(audioData.count),
    mimeType: "audio/mpeg",
    checksum: audioData.sha256Hash // Optional
)

// 3. Create record (no in-memory data)
let record = GeneratedAudioRecord(
    providerId: "elevenlabs",
    requestorID: "tts.rachel",
    audioData: nil, // ✅ Efficient
    format: "mp3",
    durationSeconds: 5.5,
    voiceID: "rachel",
    voiceName: "Rachel",
    prompt: "Hello, world!",
    fileReference: fileRef
)

modelContext.insert(record)
try modelContext.save()
```

**Strategy 2: In-Memory (Small Files Only)**
```swift
// For small files (<1MB)
let record = GeneratedAudioRecord(
    providerId: "openai",
    requestorID: "tts.alloy",
    audioData: smallAudioData, // ⚠️ Stored in database
    format: "mp3",
    durationSeconds: 2.0,
    voiceID: "alloy",
    voiceName: "Alloy",
    prompt: "Brief message"
)
```

**Playback**:
```swift
let playerManager = AudioPlayerManager()

// Automatic storage detection
try playerManager.play(record: record, storageArea: storage)
// → Uses file reference if available, falls back to in-memory
```

---

#### GeneratedTextRecord

**Purpose**: SwiftData model for storing AI-generated text.

**Structure**:
```swift
@Model
public final class GeneratedTextRecord {
    public var requestID: UUID
    public var providerId: String
    public var requestorID: String

    public var text: String?
    public var wordCount: Int?
    public var characterCount: Int?
    public var prompt: String

    public var fileReference: TypedDataFileReference?
    public var createdAt: Date
    public var modifiedAt: Date
}
```

**When to Use**:
- ✅ Store chat completions
- ✅ Store long-form generated text
- ✅ Track text generation history
- ✅ Associate text with prompts

**Example**:
```swift
// Short text (in-memory)
let record = GeneratedTextRecord(
    providerId: "anthropic",
    requestorID: "claude.sonnet",
    text: generatedText,
    wordCount: generatedText.split(separator: " ").count,
    characterCount: generatedText.count,
    prompt: userPrompt
)

// Long text (file-based)
let textURL = storage.fileURL(for: "generated.txt")
try generatedText.write(to: textURL, atomically: true, encoding: .utf8)

let fileRef = TypedDataFileReference(
    requestID: requestID,
    fileName: "generated.txt",
    fileSize: Int64(generatedText.utf8.count),
    mimeType: "text/plain"
)

let record = GeneratedTextRecord(
    providerId: "openai",
    requestorID: "gpt4",
    text: nil, // Stored in file
    prompt: userPrompt,
    fileReference: fileRef
)
```

---

#### GeneratedImageRecord

**Purpose**: SwiftData model for storing AI-generated images.

**Structure**:
```swift
@Model
public final class GeneratedImageRecord {
    public var requestID: UUID
    public var providerId: String
    public var requestorID: String

    public var imageData: Data?
    public var format: String // "png", "jpeg", etc.
    public var width: Int?
    public var height: Int?
    public var prompt: String

    public var fileReference: TypedDataFileReference?
    public var createdAt: Date
    public var modifiedAt: Date
}
```

**When to Use**:
- ✅ Store DALL-E, Midjourney, Stable Diffusion outputs
- ✅ Track image generation prompts
- ✅ Build image galleries
- ⚠️ Always use file storage for images (never in-memory in production)

**Example**:
```swift
// Generate image
let imageData = try await dalleProvider.generate(prompt: prompt)

// Save to file
let imageURL = storage.fileURL(for: "image.png")
try imageData.write(to: imageURL)

// Create reference
let fileRef = TypedDataFileReference(
    requestID: requestID,
    fileName: "image.png",
    fileSize: Int64(imageData.count),
    mimeType: "image/png"
)

// Store record
let record = GeneratedImageRecord(
    providerId: "openai",
    requestorID: "dall-e-3",
    imageData: nil,
    format: "png",
    width: 1024,
    height: 1024,
    prompt: prompt,
    fileReference: fileRef
)

modelContext.insert(record)
```

**Display in SwiftUI**:
```swift
struct GeneratedImageView: View {
    let record: GeneratedImageRecord
    let storage: StorageAreaReference

    var body: some View {
        if let fileRef = record.fileReference {
            let imageURL = fileRef.fileURL(in: storage)
            AsyncImage(url: imageURL) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
        }
    }
}
```

---

#### GeneratedEmbeddingRecord

**Purpose**: SwiftData model for storing vector embeddings.

**Structure**:
```swift
@Model
public final class GeneratedEmbeddingRecord {
    public var requestID: UUID
    public var providerId: String
    public var requestorID: String

    public var embedding: Data? // Binary vector data
    public var dimensions: Int?
    public var model: String?
    public var inputText: String

    public var fileReference: TypedDataFileReference?
    public var createdAt: Date
    public var modifiedAt: Date
}
```

**When to Use**:
- ✅ Store OpenAI embeddings
- ✅ Build semantic search
- ✅ RAG (Retrieval-Augmented Generation) systems
- ✅ Clustering and classification

**Example**:
```swift
// Generate embedding
let embeddingResponse = try await openai.createEmbedding(
    input: text,
    model: "text-embedding-3-large"
)

// Convert to binary data
let embedding: [Float] = embeddingResponse.data[0].embedding
let embeddingData = embedding.withUnsafeBytes { Data($0) }

// Store
let record = GeneratedEmbeddingRecord(
    providerId: "openai",
    requestorID: "text-embedding-3-large",
    embedding: embeddingData,
    dimensions: embedding.count,
    model: "text-embedding-3-large",
    inputText: text
)

// Retrieve and use
if let embeddingData = record.embedding {
    let vector = embeddingData.withUnsafeBytes {
        Array(UnsafeBufferPointer<Float>(
            start: $0.baseAddress!.assumingMemoryBound(to: Float.self),
            count: record.dimensions ?? 0
        ))
    }

    // Compute cosine similarity, etc.
    let similarity = cosineSimilarity(vector, queryVector)
}
```

---

### 3. Storage Models

#### TypedDataFileReference

**Purpose**: Lightweight reference to file-stored content.

**Structure**:
```swift
public struct TypedDataFileReference: Codable, Sendable, Hashable {
    public let requestID: UUID
    public let fileName: String
    public let fileSize: Int64
    public let mimeType: String
    public let checksum: String?
    public let createdAt: Date

    // Get file URL in storage area
    public func fileURL(in storageArea: StorageAreaReference) -> URL {
        storageArea.fileURL(for: fileName)
    }
}
```

**When to Use**:
- ✅ Reference large files stored on disk
- ✅ Track file metadata (size, type, checksum)
- ✅ Enable file integrity checks
- ✅ Support file migration/backup

**Example**:
```swift
// Create reference
let fileRef = TypedDataFileReference(
    requestID: requestID,
    fileName: "large-audio.mp3",
    fileSize: 5_000_000, // 5MB
    mimeType: "audio/mpeg",
    checksum: audioData.sha256Hash
)

// Use with GeneratedAudioRecord
record.fileReference = fileRef

// Later: retrieve file
let audioURL = fileRef.fileURL(in: storageArea)
let audioData = try Data(contentsOf: audioURL)

// Verify integrity
let currentChecksum = audioData.sha256Hash
if currentChecksum != fileRef.checksum {
    throw StorageError.checksumMismatch
}
```

---

#### StorageAreaReference

**Purpose**: Manage request-scoped file storage directories.

**Structure**:
```swift
public struct StorageAreaReference: Codable, Sendable, Hashable {
    public let requestID: UUID
    public let baseURL: URL
    public let bundleIdentifier: String?

    // Convenience constructors
    public static func temporary(requestID: UUID = UUID()) -> StorageAreaReference
    public static func inBundle(
        requestID: UUID,
        bundleURL: URL,
        bundleIdentifier: String
    ) -> StorageAreaReference

    // File operations
    public func fileURL(for fileName: String) -> URL
    public func createDirectoryIfNeeded() throws
    public func listFiles() throws -> [URL]
    public func directoryExists() -> Bool
}
```

**When to Use**:
- ✅ Organize files by request
- ✅ Temporary storage for processing
- ✅ Bundle files with documents
- ✅ Batch file operations

**Patterns**:

**Pattern 1: Temporary Storage**
```swift
// For ephemeral processing
let storage = StorageAreaReference.temporary(requestID: requestID)
try storage.createDirectoryIfNeeded()

let audioURL = storage.fileURL(for: "temp-audio.mp3")
try audioData.write(to: audioURL)

// Process...

// Cleanup when done
try FileManager.default.removeItem(at: storage.baseURL)
```

**Pattern 2: Document Bundle Storage**
```swift
// For persisted document bundles
let documentURL = URL(fileURLWithPath: "/path/to/project.guion")
let storage = StorageAreaReference.inBundle(
    requestID: requestID,
    bundleURL: documentURL,
    bundleIdentifier: "com.app.screenplay"
)

try storage.createDirectoryIfNeeded()

// Files are stored inside the document bundle
let assetURL = storage.fileURL(for: "narration.mp3")
```

**Pattern 3: List and Clean**
```swift
// List all files in storage area
let files = try storage.listFiles()
print("Storage contains \(files.count) files")

// Calculate total size
let totalSize = files.reduce(0) { size, url in
    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
    let fileSize = attrs?[.size] as? Int64 ?? 0
    return size + fileSize
}

// Clean old files
let now = Date()
for url in files {
    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
    if let modDate = attrs?[.modificationDate] as? Date {
        if now.timeIntervalSince(modDate) > 86400 * 7 { // 7 days
            try? FileManager.default.removeItem(at: url)
        }
    }
}
```

---

### 4. Screenplay Models

#### GuionParsedElementCollection

**Purpose**: Main screenplay container and **recommended entry point for all screenplay parsing**.

**✅ Recommended Practice**: Always use `GuionParsedElementCollection` instead of calling parsers (FountainParser, FDXParser) directly.

**Why GuionParsedElementCollection?**
- ✅ Unified API for all formats
- ✅ Built-in progress reporting
- ✅ Future-proof (new formats added here first)
- ✅ Comprehensive error handling

**Structure**:
```swift
public final class GuionParsedElementCollection: Sendable {
    public let filename: String?
    public let elements: [GuionElement]
    public let titlePage: [[String: [String]]]
    public let suppressSceneNumbers: Bool

    // Multiple init options with progress support
}
```

**✅ Parse Fountain (Recommended)**:
```swift
let fountainText = """
Title: My Screenplay
Author: John Doe

FADE IN:

EXT. BEACH - DAY

SARAH, 30s, walks along the shore.

SARAH
What a beautiful day.
"""

// ✅ Recommended: Use GuionParsedElementCollection with progress
let progress = OperationProgress(totalUnits: nil) { update in
    print("\(update.description): \(Int((update.fractionCompleted ?? 0) * 100))%")
}

let screenplay = try await GuionParsedElementCollection(
    string: fountainText,
    progress: progress
)

// Without progress (also valid)
let screenplay = try await GuionParsedElementCollection(string: fountainText)

// Access elements
for element in screenplay.elements {
    print("\(element.elementType): \(element.elementText)")
}

// Get scenes only
let scenes = screenplay.elements.filter { $0.elementType == .sceneHeading }
```

**❌ Avoid Direct Parser Usage**:
```swift
// DON'T do this - use GuionParsedElementCollection instead
let parser = try await FountainParser(string: text, progress: progress)
// Then manually work with parser.elements...
```

**Parse from File**:
```swift
// ✅ Recommended approach
let screenplay = try await GuionParsedElementCollection(
    file: "/path/to/script.fountain",
    progress: progress
)
```

**Export FDX**:
```swift
let writer = FDXDocumentWriter(screenplay: screenplay)
let fdxXML = writer.generateFDX()
try fdxXML.write(to: outputURL, atomically: true, encoding: .utf8)
```

---

#### GuionElement

**Purpose**: Single element in a screenplay (scene heading, dialogue, action, etc.).

**Structure**:
```swift
public struct GuionElement: Identifiable, Sendable {
    public let id: UUID
    public let elementType: ElementType
    public let elementText: String
    public let sceneNumber: String?
    public let isDualDialogue: Bool

    // Hierarchy
    public var children: [GuionElement]
    public var parent: GuionElement?
}
```

**ElementType** (12 display types):
```swift
public enum ElementType: Sendable {
    case sceneHeading      // INT./EXT. scene headings
    case action            // Action descriptions
    case character         // Character names in dialogue
    case dialogue          // Character dialogue text
    case parenthetical     // (parenthetical) directions
    case transition        // CUT TO:, FADE OUT, etc.
    case sectionHeading(level: Int) // # Section markers (1-6)
    case synopsis          // = Synopsis/summary lines (NEW in 1.4.x)
    case comment           // /* Comment text */
    case boneyard          // /*  Commented-out content */
    case lyrics            // ~ Song lyrics
    case pageBreak         // === Page break marker
    case titlePageKey(String)    // Title page metadata
    case titlePageValue(String)  // Title page values
}
```

**Example**:
```swift
// Create scene
let scene = GuionElement(
    elementType: .sceneHeading,
    elementText: "INT. OFFICE - DAY",
    sceneNumber: "1"
)

// Add action
let action = GuionElement(
    elementType: .action,
    elementText: "The phone rings."
)

// Add dialogue
let character = GuionElement(
    elementType: .character,
    elementText: "JOHN"
)

let dialogue = GuionElement(
    elementType: .dialogue,
    elementText: "Hello?"
)

// Build hierarchy
var sceneWithChildren = scene
sceneWithChildren.children = [action, character, dialogue]
```

---

## Progress Reporting

**Version Added**: 1.3.0

SwiftCompartido provides comprehensive progress reporting for all long-running operations. Progress reporting integrates seamlessly with SwiftUI, supports cancellation, and maintains backward compatibility.

### Core Progress Types

#### OperationProgress

**Purpose**: Main progress tracker that reports updates via a handler closure.

**Structure**:
```swift
public class OperationProgress {
    public let totalUnits: Int?
    public private(set) var completedUnits: Int
    public private(set) var currentStage: String?

    public init(
        totalUnits: Int? = nil,
        handler: ProgressHandler? = nil
    )

    public func updateProgress(
        completedUnits: Int,
        description: String
    )

    public func setStage(_ stage: String)
}
```

**When to Use**:
- ✅ Track parsing operations
- ✅ Monitor conversion processes
- ✅ Report export progress
- ✅ Update SwiftUI views with `@Published` properties
- ✅ Enable user cancellation

**Example**:
```swift
let progress = OperationProgress(totalUnits: 100) { update in
    print("\(update.description): \(update.fractionCompleted ?? 0.0)")
}

// Pass to async operations
let parser = try await FountainParser(string: text, progress: progress)
```

---

#### ProgressUpdate

**Purpose**: Immutable snapshot of progress state passed to handlers.

**Structure**:
```swift
public struct ProgressUpdate: Sendable {
    public let completedUnits: Int
    public let totalUnits: Int?
    public let description: String
    public let currentStage: String?

    public var fractionCompleted: Double? {
        guard let total = totalUnits, total > 0 else { return nil }
        return Double(completedUnits) / Double(total)
    }
}
```

**Properties**:
- `completedUnits`: Work completed so far
- `totalUnits`: Total work (nil for indeterminate progress)
- `description`: Human-readable status message
- `currentStage`: Current operation stage
- `fractionCompleted`: Progress as 0.0-1.0 (nil if indeterminate)

---

### Progress-Enabled Operations

All major operations support optional progress parameters:

#### 1. Fountain Parser

```swift
// Parse with progress
let progress = OperationProgress(totalUnits: nil) { update in
    print(update.description)
}

let parser = try await FountainParser(string: text, progress: progress)

// Backward compatible (nil progress)
let parser2 = try await FountainParser(string: text, progress: nil)
```

**Progress Stages**:
- Preparing to parse
- Parsing title page
- Processing elements (1 of N, 2 of N, ...)
- Finalizing screenplay

---

#### 2. FDX Parser

```swift
let progress = OperationProgress(totalUnits: nil) { update in
    print(update.description)
}

let screenplay = try await GuionParsedElementCollection(
    file: fdxPath,
    progress: progress
)
```

**Progress Stages**:
- Loading FDX file
- Parsing XML
- Processing paragraphs
- Extracting title page
- Finalizing screenplay

---

#### 3. TextPack Reader

```swift
let progress = OperationProgress(totalUnits: 4) { update in
    print("\(update.description) (\(update.fractionCompleted ?? 0.0))")
}

let screenplay = try await GuionParsedElementCollection.readTextPack(
    at: bundleURL,
    progress: progress
)
```

**Progress Stages** (4 total):
1. Reading bundle metadata (25%)
2. Reading screenplay text (25%)
3. Parsing screenplay content (25%)
4. Loading resources (25%)

---

#### 4. TextPack Writer

```swift
let progress = OperationProgress(totalUnits: 5) { update in
    print(update.description)
}

let bundle = try await TextPackWriter.createTextPack(
    from: screenplay,
    progress: progress
)
```

**Progress Stages** (5 total):
1. Creating bundle metadata (10%)
2. Generating screenplay.fountain (30%)
3. Extracting character data (20%)
4. Extracting location data (20%)
5. Writing resource files (20%)

---

#### 5. SwiftData Operations

```swift
#if canImport(SwiftData)
let progress = OperationProgress(totalUnits: nil) { update in
    print(update.description)
}

let document = await GuionDocumentParserSwiftData.parse(
    script: screenplay,
    in: modelContext,
    generateSummaries: false,
    progress: progress
)
```

**Progress Updates**:
- Converting title page
- Converting elements (batched every 10 elements)
- Processing element 10 of N, 20 of N, ...
- Finalizing document

---

#### 6. File I/O Operations

```swift
// Save audio with progress
let progress = OperationProgress(totalUnits: nil) { update in
    print(update.description)
}

try await record.saveAudio(
    audioData,
    to: storage,
    mode: .local,
    progress: progress
)

// Load with progress
let loadedData = try await record.loadAudio(
    from: storage,
    progress: progress
)
```

**Progress Updates**:
- Chunked writing/reading with 1MB chunks
- Progress update every chunk with 1ms yield
- Byte-level progress for large files

---

### SwiftUI Integration

#### Pattern 1: ProgressView with @Published

```swift
@MainActor
@Observable
class ParserViewModel {
    @Published var progressMessage = ""
    @Published var progressFraction = 0.0
    @Published var isProcessing = false

    func parseScreenplay(_ text: String) async throws {
        isProcessing = true
        defer { isProcessing = false }

        let progress = OperationProgress(totalUnits: nil) { update in
            Task { @MainActor in
                self.progressMessage = update.description
                self.progressFraction = update.fractionCompleted ?? 0.0
            }
        }

        let parser = try await FountainParser(string: text, progress: progress)
        // Use parser.elements...
    }
}

struct ParsingView: View {
    @StateObject var viewModel = ParserViewModel()

    var body: some View {
        VStack {
            if viewModel.isProcessing {
                ProgressView(value: viewModel.progressFraction) {
                    Text(viewModel.progressMessage)
                }
            }
            Button("Parse") {
                Task {
                    try await viewModel.parseScreenplay(largeScript)
                }
            }
        }
    }
}
```

---

#### Pattern 2: Indeterminate Progress

```swift
@MainActor
class DocumentProcessor: ObservableObject {
    @Published var statusMessage = "Ready"
    @Published var isProcessing = false

    func processDocument() async throws {
        isProcessing = true
        defer { isProcessing = false }

        let progress = OperationProgress(totalUnits: nil) { update in
            Task { @MainActor in
                self.statusMessage = update.description
            }
        }

        let document = try await parseAndConvert(progress: progress)
    }
}

struct DocumentView: View {
    @StateObject var processor = DocumentProcessor()

    var body: some View {
        VStack {
            if processor.isProcessing {
                ProgressView() // Indeterminate spinner
                Text(processor.statusMessage)
            }
            Button("Process") {
                Task {
                    try await processor.processDocument()
                }
            }
        }
    }
}
```

---

### Cancellation Support

All progress-enabled operations support `Task` cancellation:

```swift
@MainActor
class CancellableOperation: ObservableObject {
    @Published var progress = 0.0
    private var currentTask: Task<Void, Error>?

    func startOperation() {
        currentTask = Task {
            let progress = OperationProgress(totalUnits: nil) { update in
                Task { @MainActor in
                    self.progress = update.fractionCompleted ?? 0.0
                }
            }

            try await performLongOperation(progress: progress)
        }
    }

    func cancelOperation() {
        currentTask?.cancel()
        currentTask = nil
    }
}

// In SwiftUI
struct CancellableView: View {
    @StateObject var operation = CancellableOperation()

    var body: some View {
        VStack {
            ProgressView(value: operation.progress)

            if operation.currentTask != nil {
                Button("Cancel") {
                    operation.cancelOperation()
                }
            } else {
                Button("Start") {
                    operation.startOperation()
                }
            }
        }
    }
}
```

**How Cancellation Works**:
- All progress-enabled methods check `Task.checkCancellation()`
- Operations throw `CancellationError` when cancelled
- Partial files are cleaned up automatically
- Safe to cancel at any progress stage

---

### Performance Characteristics

#### Overhead

Progress reporting adds minimal overhead:
- **<2% performance impact** (verified with 600+ element screenplays)
- Batched updates (maximum 100 updates/second)
- No memory leaks or unbounded growth
- Thread-safe with actor isolation

#### Benchmarks

```swift
// Without progress: 1.23s
let screenplay = try await GuionParsedElementCollection(file: path, progress: nil)

// With progress: 1.25s (~1.6% overhead)
let progress = OperationProgress(totalUnits: nil)
let screenplay = try await GuionParsedElementCollection(file: path, progress: progress)
```

---

### Backward Compatibility

**100% backward compatible** - all progress parameters are optional:

```swift
// Before version 1.3.0 (still works)
let parser = try GuionParsedElementCollection(file: path)

// Version 1.3.0+ with progress (new)
let progress = OperationProgress(totalUnits: nil)
let parser = try await GuionParsedElementCollection(file: path, progress: progress)

// Version 1.3.0+ without progress (also works)
let parser = try await GuionParsedElementCollection(file: path, progress: nil)
```

**Migration**:
- No code changes required
- Add `progress` parameter only where needed
- Convert synchronous calls to `async` when using progress

---

### Testing Progress

```swift
import Testing
@testable import SwiftCompartido

struct ProgressTests {
    @Test("Progress reports all stages")
    func testProgressReporting() async throws {
        actor ProgressCollector {
            var updates: [ProgressUpdate] = []

            func add(_ update: ProgressUpdate) {
                updates.append(update)
            }

            func getUpdates() -> [ProgressUpdate] {
                return updates
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.add(update)
            }
        }

        let screenplay = """
        Title: Test

        INT. LOCATION - DAY

        Action.
        """

        let parser = try await FountainParser(string: screenplay, progress: progress)

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(100))

        let updates = await collector.getUpdates()
        #expect(updates.count > 0, "Should receive progress updates")
    }
}
```

---

### Best Practices

**DO ✅**:
- Use progress for operations > 1 second
- Update UI with `@MainActor` tasks
- Provide meaningful descriptions
- Support cancellation with `Task.checkCancellation()`
- Test with large files (100+ pages)

**DON'T ❌**:
- Block the main thread in progress handlers
- Create unbounded progress update storage
- Forget to handle cancellation
- Skip progress for quick operations
- Update progress too frequently (>100 times/second)

**Example**:
```swift
// ✅ GOOD
let progress = OperationProgress(totalUnits: screenplay.elements.count) { update in
    Task { @MainActor in
        self.progressView.update(update.fractionCompleted ?? 0.0)
    }
}

// Process with cancellation support
try await processScreenplay(progress: progress)

// ❌ BAD
let progress = OperationProgress { update in
    // Blocking main thread!
    DispatchQueue.main.sync {
        self.progressView.value = update.fractionCompleted ?? 0.0
    }
}
```

---

## Common Usage Patterns

### UI Architecture Overview

SwiftCompartido uses a **flat, list-based UI architecture** for displaying screenplay documents. This replaces the previous hierarchical widget system.

**Architecture Principles:**
- ✅ **Flat display** - Elements displayed sequentially in document order
- ✅ **No hierarchy** - No grouping or nesting of elements
- ✅ **Simple switch/case** - Each element type rendered by dedicated view
- ✅ **SwiftData @Query** - Direct database queries, no intermediate models

**Component Hierarchy:**
```
GuionViewer (thin wrapper)
  └── GuionElementsList (@Query-based list)
       └── Element Views (ActionView, DialogueTextView, etc.)
```

**Deprecated Components** (removed in 1.4.3):
- ❌ SceneBrowserWidget - Replaced by GuionElementsList
- ❌ ChapterWidget - No longer needed
- ❌ SceneGroupWidget - No longer needed
- ❌ Hierarchical grouping - Elements now flat

**GuionViewer** - Top-level viewer (simplified from 479 lines to 52 lines):
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

**GuionElementsList** - SwiftData @Query-based list (NEW in 1.4.3):
```swift
public struct GuionElementsList: View {
    @Query private var elements: [GuionElementModel]
    @Environment(\.screenplayFontSize) var fontSize

    // Display all elements
    public init() {
        _elements = Query()
    }

    // Filter to specific document
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
                switch element.elementType {
                case .action: ActionView(element: element)
                case .dialogue: DialogueTextView(element: element)
                case .sceneHeading: SceneHeadingView(element: element)
                case .character: DialogueCharacterView(element: element)
                case .parenthetical: DialogueParentheticalView(element: element)
                case .transition: TransitionView(element: element)
                case .sectionHeading: SectionHeadingView(element: element)
                case .synopsis: SynopsisView(element: element)
                case .comment: CommentView(element: element)
                case .boneyard: BoneyardView(element: element)
                case .lyrics: DialogueLyricsView(element: element)
                case .pageBreak: PageBreakView()
                }
            }
        }
        .listStyle(.plain)
    }
}
```

**Element Views** - Individual element components:

All element views follow a consistent pattern and use proper screenplay formatting:

```swift
// ActionView - 10% left/right margins
public struct ActionView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    public var body: some View {
        Text(element.elementText)
            .font(.custom("Courier New", size: fontSize))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40) // 10% margins
            .padding(.vertical, fontSize * 0.35)
    }
}

// DialogueTextView - 25% left/right margins
public struct DialogueTextView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    public var body: some View {
        HStack {
            Spacer().frame(minWidth: 100) // 25% left margin
            Text(element.elementText)
                .font(.custom("Courier New", size: fontSize))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(minWidth: 100) // 25% right margin
        }
        .padding(.horizontal, 20)
    }
}
```

**Available Element Views:**
- `ActionView` - Action descriptions
- `DialogueTextView` - Character dialogue
- `DialogueCharacterView` - Character names
- `DialogueParentheticalView` - (parenthetical) directions
- `DialogueLyricsView` - Song lyrics
- `SceneHeadingView` - Scene headings (INT./EXT.)
- `TransitionView` - Scene transitions (CUT TO:, FADE OUT)
- `SectionHeadingView` - Section markers
- `SynopsisView` - Synopsis/summary text
- `CommentView` - Comment/note text
- `BoneyardView` - Commented-out content
- `PageBreakView` - Page break marker

**Screenplay Formatting Environment:**

All views respect the `screenplayFontSize` environment value:

```swift
struct MyScreenplayView: View {
    @State private var fontSize: CGFloat = 12

    var body: some View {
        GuionViewer(document: document)
            .environment(\.screenplayFontSize, fontSize)
    }
}
```

---

### Source File Tracking (NEW in 1.4.3)

GuionDocumentModel now tracks the original source file and can detect when it has been modified, allowing you to prompt users to re-import the latest version.

**Features:**
- ✅ **Security-scoped bookmarks** - Maintains access across app launches
- ✅ **Modification detection** - Detects when source file changes
- ✅ **Automatic bookmark refresh** - Updates stale bookmarks automatically
- ✅ **Status reporting** - Clear status enum for UI display

**New Properties:**
```swift
@Model
public final class GuionDocumentModel {
    // Source file tracking (NEW in 1.4.3)
    public var sourceFileBookmark: Data?
    public var lastImportDate: Date?
    public var sourceFileModificationDate: Date?

    // ... existing properties
}
```

**New Methods:**
```swift
// Set source file (creates security-scoped bookmark)
public func setSourceFile(_ url: URL) -> Bool

// Resolve bookmark to URL
public func resolveSourceFileURL() -> URL?

// Check if source file has been modified
public func isSourceFileModified() -> Bool

// Get detailed status
public func sourceFileStatus() -> SourceFileStatus
```

**SourceFileStatus Enum:**
```swift
public enum SourceFileStatus: Sendable {
    case noSourceFile          // No source file set
    case fileNotAccessible     // Cannot resolve bookmark
    case fileNotFound          // File moved/deleted
    case modified              // File has been updated
    case upToDate              // File is current

    public var description: String { /* ... */ }
    public var shouldPromptForUpdate: Bool {
        return self == .modified
    }
}
```

**Usage Pattern - Set Source on Import:**
```swift
@MainActor
func importScreenplay(from url: URL) async throws {
    // 1. Parse the screenplay
    let fountainText = try String(contentsOf: url)
    let parser = FountainParser()
    let screenplay = parser.parse(fountainText)

    // 2. Convert to SwiftData
    let document = await GuionDocumentParserSwiftData.parse(
        script: screenplay,
        in: modelContext,
        generateSummaries: false
    )

    // 3. Set source file (creates bookmark and records dates)
    let success = document.setSourceFile(url)
    guard success else {
        throw ImportError.cannotCreateBookmark
    }

    // 4. Save
    try modelContext.save()
}
```

**Usage Pattern - Check for Updates:**
```swift
@MainActor
func checkForUpdates(document: GuionDocumentModel) async {
    let status = document.sourceFileStatus()

    switch status {
    case .modified:
        // Source file has changed - prompt user to update
        showUpdateAlert {
            try await reimportFromSource(document: document)
        }

    case .upToDate:
        showMessage("Document is up to date")

    case .noSourceFile:
        // Document wasn't imported from a file
        break

    case .fileNotAccessible:
        showError("Cannot access source file - permissions issue")

    case .fileNotFound:
        showError("Source file was moved or deleted")
    }
}
```

**Usage Pattern - Re-import from Source:**
```swift
@MainActor
func reimportFromSource(document: GuionDocumentModel) async throws {
    guard let sourceURL = document.resolveSourceFileURL() else {
        throw ImportError.sourceFileNotFound
    }

    // Start security-scoped access
    let accessing = sourceURL.startAccessingSecurityScopedResource()
    defer {
        if accessing {
            sourceURL.stopAccessingSecurityScopedResource()
        }
    }

    // Parse the updated file
    let fountainText = try String(contentsOf: sourceURL)
    let parser = FountainParser()
    let screenplay = parser.parse(fountainText)

    // Clear existing elements
    for element in document.elements {
        modelContext.delete(element)
    }
    document.elements.removeAll()

    // Import new elements
    for element in screenplay.elements {
        let newElement = GuionElementModel(from: element)
        newElement.document = document
        document.elements.append(newElement)
    }

    // Update source file metadata
    document.setSourceFile(sourceURL)

    try modelContext.save()
}
```

**SwiftUI Integration:**
```swift
struct DocumentUpdateAlert: View {
    let document: GuionDocumentModel
    @State private var showingAlert = false

    var body: some View {
        GuionViewer(document: document)
            .onAppear {
                checkForUpdates()
            }
            .alert("Update Available", isPresented: $showingAlert) {
                Button("Update Now") {
                    Task {
                        await reimportFromSource()
                    }
                }
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text("The source file has been modified. Would you like to update to the latest version?")
            }
    }

    func checkForUpdates() {
        showingAlert = document.isSourceFileModified()
    }
}

// Status badge for document list
struct DocumentStatusBadge: View {
    let document: GuionDocumentModel

    var body: some View {
        let status = document.sourceFileStatus()

        if status.shouldPromptForUpdate {
            Label("Update Available", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
```

**Security Considerations:**

For sandboxed macOS apps:
1. User must select file via open panel
2. Security-scoped bookmarks required to maintain access
3. Always use `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`

```swift
// Security-scoped access pattern
if let url = document.resolveSourceFileURL() {
    let accessing = url.startAccessingSecurityScopedResource()
    defer {
        if accessing {
            url.stopAccessingSecurityScopedResource()
        }
    }

    // Work with the file
    let data = try Data(contentsOf: url)
}
```

---

### Pattern 1: Complete AI Text Generation Workflow

```swift
import SwiftCompartido
import SwiftData

@MainActor
@Observable
class TextGenerationViewModel {
    let modelContext: ModelContext
    var trackedRequests: [UUID: TrackedRequest] = [:]

    func generateText(prompt: String, provider: String) async throws -> GeneratedTextRecord {
        // 1. Create request
        let requestID = UUID()
        let request = AIRequest(
            id: requestID,
            prompt: prompt,
            parameters: ["temperature": 0.7, "max_tokens": 1000]
        )

        // 2. Track request
        let tracked = TrackedRequest(
            request: request,
            status: .pending,
            providerID: provider,
            submittedAt: Date()
        )
        trackedRequests[requestID] = tracked

        // 3. Update to executing
        trackedRequests[requestID] = tracked.withStatus(.executing(progress: nil))

        // 4. Call provider (your implementation)
        let response = try await callProvider(provider, request: request)

        // 5. Extract text from response
        guard let text = response.content?.text else {
            throw AIServiceError.unexpectedResponseFormat("No text in response")
        }

        // 6. Create text record
        let record = GeneratedTextRecord(
            providerId: provider,
            requestorID: "\(provider).text",
            text: text,
            wordCount: text.split(separator: " ").count,
            characterCount: text.count,
            prompt: prompt
        )

        // 7. Save to database
        modelContext.insert(record)
        try modelContext.save()

        // 8. Update tracking to completed
        trackedRequests[requestID] = tracked.withStatus(.completed(response))

        return record
    }

    private func callProvider(_ provider: String, request: AIRequest) async throws -> AIResponseData {
        // Your provider implementation here
        fatalError("Implement provider call")
    }
}
```

---

### Pattern 2: TTS Audio Generation with File Storage

```swift
@MainActor
@Observable
class TTSViewModel {
    let modelContext: ModelContext
    let playerManager = AudioPlayerManager()

    func generateSpeech(
        text: String,
        voiceID: String,
        provider: String
    ) async throws -> GeneratedAudioRecord {
        let requestID = UUID()

        // 1. Setup storage
        let storage = StorageAreaReference.temporary(requestID: requestID)
        try storage.createDirectoryIfNeeded()

        // 2. Generate audio (your implementation)
        let audioData = try await callTTSProvider(provider, text: text, voiceID: voiceID)

        // 3. Save to file
        let audioURL = storage.fileURL(for: "speech.mp3")
        try audioData.write(to: audioURL)

        // 4. Create file reference
        let fileRef = TypedDataFileReference(
            requestID: requestID,
            fileName: "speech.mp3",
            fileSize: Int64(audioData.count),
            mimeType: "audio/mpeg"
        )

        // 5. Get audio duration (optional but recommended)
        let duration = try? getAudioDuration(from: audioURL)

        // 6. Create record
        let record = GeneratedAudioRecord(
            providerId: provider,
            requestorID: "\(provider).tts.\(voiceID)",
            audioData: nil, // File-based storage
            format: "mp3",
            durationSeconds: duration,
            voiceID: voiceID,
            voiceName: "Voice Name",
            prompt: text,
            fileReference: fileRef
        )

        // 7. Save to database
        modelContext.insert(record)
        try modelContext.save()

        return record
    }

    func playAudio(record: GeneratedAudioRecord) throws {
        guard let fileRef = record.fileReference else {
            throw AudioPlayerError.noAudioDataAvailable
        }

        let storage = StorageAreaReference.temporary(requestID: fileRef.requestID)
        try playerManager.play(record: record, storageArea: storage)
    }

    private func getAudioDuration(from url: URL) throws -> TimeInterval {
        let player = try AVAudioPlayer(contentsOf: url)
        return player.duration
    }
}
```

---

### Pattern 3: Screenplay Parsing and Viewing with SwiftData

```swift
@MainActor
struct ScreenplayView: View {
    @Environment(\.modelContext) private var modelContext
    let fountainURL: URL
    @State private var document: GuionDocumentModel?
    @State private var isLoading = false
    @State private var error: Error?

    var body: some View {
        Group {
            if let document {
                GuionViewer(document: document)
            } else if isLoading {
                ProgressView("Parsing screenplay...")
            } else if let error {
                Text("Error: \(error.localizedDescription)")
                    .foregroundStyle(.red)
            }
        }
        .task {
            await loadScreenplay()
        }
    }

    func loadScreenplay() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 1. Parse Fountain file
            let fountainText = try String(contentsOf: fountainURL)
            let parser = FountainParser()
            let screenplay = parser.parse(fountainText)

            // 2. Convert to SwiftData
            let doc = await GuionDocumentParserSwiftData.parse(
                script: screenplay,
                in: modelContext,
                generateSummaries: false
            )

            // 3. Save and display
            try modelContext.save()
            document = doc

        } catch {
            self.error = error
        }
    }
}
```

### Pattern 3b: Viewing Existing SwiftData Documents

```swift
struct DocumentListView: View {
    @Query private var documents: [GuionDocumentModel]

    var body: some View {
        List(documents) { document in
            NavigationLink(document.title ?? "Untitled") {
                GuionViewer(document: document)
            }
        }
    }
}
```

### Pattern 3c: Custom Element List View

```swift
struct CustomSceneView: View {
    let scene: SceneModel

    var body: some View {
        // GuionElementsList can filter to specific document
        GuionElementsList(document: scene.document)
            .navigationTitle(scene.heading)
    }
}

// Or display all elements without filtering
struct AllElementsView: View {
    var body: some View {
        GuionElementsList() // Shows all elements from all documents
    }
}
```

---

### Pattern 4: Batch Processing with Progress Tracking

```swift
@MainActor
@Observable
class BatchProcessor {
    var progress: Double = 0
    var currentItem: String = ""
    var results: [Result<GeneratedTextRecord, Error>] = []

    func processBatch(prompts: [String], provider: String) async {
        results = []
        let total = Double(prompts.count)

        for (index, prompt) in prompts.enumerated() {
            currentItem = "Processing \(index + 1) of \(prompts.count)"
            progress = Double(index) / total

            do {
                let record = try await generateText(prompt: prompt, provider: provider)
                results.append(.success(record))
            } catch {
                results.append(.failure(error))
            }
        }

        progress = 1.0
        currentItem = "Complete"
    }

    private func generateText(prompt: String, provider: String) async throws -> GeneratedTextRecord {
        // Implementation from Pattern 1
        fatalError("Implement")
    }
}

// Usage in SwiftUI
struct BatchProcessingView: View {
    @State private var processor = BatchProcessor()

    var body: some View {
        VStack {
            ProgressView(value: processor.progress) {
                Text(processor.currentItem)
            }

            Button("Start Batch") {
                Task {
                    await processor.processBatch(
                        prompts: ["Prompt 1", "Prompt 2", "Prompt 3"],
                        provider: "openai"
                    )
                }
            }
        }
    }
}
```

---

## Best Practices

### 1. File Storage Strategy

**DO ✅**:
- Use file storage for data > 1MB
- Store file references in SwiftData models
- Use `TypedDataFileReference` for metadata
- Implement checksums for integrity
- Clean up temporary files

**DON'T ❌**:
- Store large blobs in SwiftData
- Keep audio/images in memory unnecessarily
- Skip error handling for file operations
- Forget to create directories before writing

**Example**:
```swift
// ✅ GOOD
let storage = StorageAreaReference.temporary(requestID: requestID)
try storage.createDirectoryIfNeeded()

let fileURL = storage.fileURL(for: "large-file.dat")
try largeData.write(to: fileURL)

let fileRef = TypedDataFileReference(
    requestID: requestID,
    fileName: "large-file.dat",
    fileSize: Int64(largeData.count),
    mimeType: "application/octet-stream"
)

record.fileReference = fileRef
record.data = nil // Don't duplicate in memory

// ❌ BAD
record.data = largeData // 10MB blob in database!
```

---

### 2. Error Handling

**DO ✅**:
- Use `AIServiceError` for AI-specific errors
- Provide recovery suggestions
- Log errors with context
- Handle file I/O errors separately

**DON'T ❌**:
- Silently fail
- Use generic error messages
- Swallow errors in production

**Example**:
```swift
// ✅ GOOD
func generateContent() async throws -> GeneratedTextRecord {
    do {
        let response = try await provider.generate(prompt)

        guard let text = response.content?.text else {
            throw AIServiceError.unexpectedResponseFormat(
                "Response did not contain text content"
            )
        }

        let record = GeneratedTextRecord(/* ... */)

        do {
            modelContext.insert(record)
            try modelContext.save()
        } catch {
            throw AIServiceError.persistenceError(
                "Failed to save generated content: \(error.localizedDescription)"
            )
        }

        return record

    } catch let error as AIServiceError {
        // AI-specific error, rethrow
        throw error
    } catch {
        // Wrap unexpected errors
        throw AIServiceError.providerError(
            "Unexpected error: \(error.localizedDescription)"
        )
    }
}

// ❌ BAD
func generateContent() async -> GeneratedTextRecord? {
    do {
        let response = try await provider.generate(prompt)
        let text = response.content?.text ?? ""
        return GeneratedTextRecord(text: text, /* ... */)
    } catch {
        print("Error: \(error)") // Silent failure
        return nil
    }
}
```

---

### 3. SwiftData Patterns

**DO ✅**:
- Use `@Model` for persistent types
- Implement proper fetch descriptors
- Use predicates for filtering
- Handle threading properly with `@MainActor`

**DON'T ❌**:
- Access SwiftData off the main thread (without proper actor isolation)
- Forget to save context
- Create circular references

**Example**:
```swift
// ✅ GOOD
@MainActor
func fetchRecentAudio(limit: Int = 10) throws -> [GeneratedAudioRecord] {
    let descriptor = FetchDescriptor<GeneratedAudioRecord>(
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit

    return try modelContext.fetch(descriptor)
}

@MainActor
func fetchAudioByProvider(_ providerID: String) throws -> [GeneratedAudioRecord] {
    let descriptor = FetchDescriptor<GeneratedAudioRecord>(
        predicate: #Predicate { $0.providerId == providerID },
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )

    return try modelContext.fetch(descriptor)
}

// ❌ BAD
func fetchAudio() -> [GeneratedAudioRecord]? {
    // No error handling, no sorting, no isolation
    try? modelContext.fetch(FetchDescriptor<GeneratedAudioRecord>())
}
```

---

### 4. Concurrency & Sendable

**DO ✅**:
- Mark async functions appropriately
- Use `@MainActor` for UI updates
- Ensure all models are `Sendable`
- Use structured concurrency

**DON'T ❌**:
- Mix actor boundaries without care
- Block the main thread
- Use global mutable state

**Example**:
```swift
// ✅ GOOD
@MainActor
@Observable
class ContentGenerator {
    var isGenerating = false
    var progress = 0.0

    func generate() async throws {
        isGenerating = true
        defer { isGenerating = false }

        // Heavy work off main thread
        let result = await Task.detached {
            try await self.performGeneration()
        }.value

        // UI updates on main thread
        self.progress = 1.0
    }

    private func performGeneration() async throws -> AIResponseData {
        // Network/processing work
        return try await provider.generate()
    }
}

// ❌ BAD
class ContentGenerator {
    func generate() {
        DispatchQueue.global().async { // Old pattern
            let result = try? self.provider.generate() // Blocking
            DispatchQueue.main.async {
                self.progress = 1.0 // Data race
            }
        }
    }
}
```

---

## Integration Examples

### Example: Chat Application

```swift
import SwiftCompartido
import SwiftData
import SwiftUI

@Model
class ChatMessage {
    var id: UUID
    var role: String // "user" or "assistant"
    var content: String
    var textRecord: GeneratedTextRecord?
    var timestamp: Date

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

@MainActor
@Observable
class ChatViewModel {
    let modelContext: ModelContext
    var messages: [ChatMessage] = []
    var isGenerating = false

    func sendMessage(_ text: String) async {
        // Add user message
        let userMessage = ChatMessage(role: "user", content: text)
        modelContext.insert(userMessage)
        messages.append(userMessage)

        isGenerating = true
        defer { isGenerating = false }

        do {
            // Generate AI response
            let response = try await generateResponse(for: text)

            guard let responseText = response.content?.text else {
                throw AIServiceError.unexpectedResponseFormat("No text")
            }

            // Create text record
            let textRecord = GeneratedTextRecord(
                providerId: response.providerID,
                requestorID: "chat.assistant",
                text: responseText,
                wordCount: responseText.split(separator: " ").count,
                characterCount: responseText.count,
                prompt: text
            )

            modelContext.insert(textRecord)

            // Add assistant message
            let assistantMessage = ChatMessage(role: "assistant", content: responseText)
            assistantMessage.textRecord = textRecord
            modelContext.insert(assistantMessage)
            messages.append(assistantMessage)

            try modelContext.save()

        } catch {
            print("Error: \(error)")
        }
    }

    private func generateResponse(for prompt: String) async throws -> AIResponseData {
        // Your provider implementation
        fatalError("Implement")
    }
}

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var inputText = ""

    init(modelContext: ModelContext) {
        self.viewModel = ChatViewModel(modelContext: modelContext)
    }

    var body: some View {
        VStack {
            ScrollView {
                ForEach(viewModel.messages) { message in
                    MessageBubble(message: message)
                }
            }

            HStack {
                TextField("Message", text: $inputText)
                Button("Send") {
                    Task {
                        await viewModel.sendMessage(inputText)
                        inputText = ""
                    }
                }
                .disabled(viewModel.isGenerating || inputText.isEmpty)
            }
        }
    }
}
```

---

### Example: Audio Narration System

```swift
@MainActor
@Observable
class NarrationSystem {
    let modelContext: ModelContext
    let playerManager = AudioPlayerManager()

    var audioQueue: [GeneratedAudioRecord] = []
    var currentIndex = 0

    func narrateScreenplay(_ screenplay: GuionParsedElementCollection) async throws {
        // 1. Extract dialogue elements
        let dialogueElements = screenplay.elements.filter {
            $0.elementType == .dialogue
        }

        // 2. Generate audio for each
        for element in dialogueElements {
            let audio = try await generateNarration(
                text: element.text,
                voiceID: determineVoice(for: element)
            )
            audioQueue.append(audio)
        }

        // 3. Start playback
        try playNext()
    }

    func playNext() throws {
        guard currentIndex < audioQueue.count else { return }

        let record = audioQueue[currentIndex]
        let storage = StorageAreaReference.temporary(requestID: record.requestID)

        try playerManager.play(record: record, storageArea: storage)
        currentIndex += 1
    }

    private func generateNarration(text: String, voiceID: String) async throws -> GeneratedAudioRecord {
        // TTS generation implementation
        fatalError("Implement")
    }

    private func determineVoice(for element: GuionElement) -> String {
        // Voice selection logic
        return "default-voice"
    }
}
```

---

## Error Handling

### AIServiceError Reference

```swift
public enum AIServiceError: Error, LocalizedError {
    // Configuration
    case configurationError(String)
    case invalidAPIKey(String)
    case missingCredentials(String)

    // Network
    case networkError(String)
    case timeout(String)
    case connectionFailed(String)

    // Provider
    case providerError(String, code: String? = nil)
    case rateLimitExceeded(String, retryAfter: TimeInterval? = nil)
    case authenticationFailed(String)
    case invalidRequest(String)

    // Data
    case validationError(String)
    case unexpectedResponseFormat(String)
    case dataConversionError(String)
    case dataBindingError(String)

    // Storage
    case persistenceError(String)
    case modelNotFound(String)

    // Operations
    case unsupportedOperation(String)

    // Properties
    public var errorDescription: String { /* ... */ }
    public var category: ErrorCategory { /* ... */ }
    public var isRecoverable: Bool { /* ... */ }
    public var retryDelay: TimeInterval? { /* ... */ }
}
```

**Usage Pattern**:
```swift
do {
    let response = try await provider.generate(prompt)
    // Process response

} catch AIServiceError.rateLimitExceeded(let message, let retryAfter) {
    print("Rate limited: \(message)")
    if let delay = retryAfter {
        print("Retry after \(delay) seconds")
        try await Task.sleep(for: .seconds(delay))
        // Retry logic
    }

} catch AIServiceError.authenticationFailed(let message) {
    print("Auth failed: \(message)")
    // Prompt user to re-enter API key

} catch let error as AIServiceError where error.isRecoverable {
    print("Recoverable error: \(error.errorDescription)")
    if let delay = error.retryDelay {
        try await Task.sleep(for: .seconds(delay))
        // Retry
    }

} catch {
    print("Unhandled error: \(error)")
}
```

---

## Testing Guidance

### Testing Generated Content

```swift
import Testing
@testable import SwiftCompartido

@available(macOS 15.0, *)
struct GeneratedTextRecordTests {

    @Test("Create and retrieve text record")
    func testTextRecord() async throws {
        let container = try ModelContainer(
            for: GeneratedTextRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        let context = ModelContext(container)

        // Create record
        let record = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Test content",
            wordCount: 2,
            characterCount: 12,
            prompt: "Test prompt"
        )

        context.insert(record)
        try context.save()

        // Fetch
        let descriptor = FetchDescriptor<GeneratedTextRecord>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results[0].text == "Test content")
    }
}
```

### Testing Audio Playback

```swift
@MainActor
struct AudioPlayerTests {

    @Test("Play from URL")
    func testPlayFromURL() throws {
        let manager = AudioPlayerManager()

        // Create test audio file
        let audioURL = createTestAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }

        // Play (may not work in test environment without audio hardware)
        do {
            try manager.play(from: audioURL, format: "mp3", duration: 5.0)
            #expect(manager.isPlaying)
            manager.stop()
        } catch {
            // Expected in CI environment
            print("Audio not available: \(error)")
        }
    }
}
```

---

## Performance Considerations

### 1. File I/O Optimization

**Problem**: Writing large files can block the main thread.

**Solution**: Use background tasks for file operations.

```swift
// ✅ GOOD
func saveAudioToFile(_ audioData: Data, storage: StorageAreaReference) async throws -> URL {
    let audioURL = storage.fileURL(for: "audio.mp3")

    // Perform file write on background thread
    try await Task.detached {
        try audioData.write(to: audioURL)
    }.value

    return audioURL
}

// ❌ BAD
func saveAudioToFile(_ audioData: Data, storage: StorageAreaReference) throws -> URL {
    let audioURL = storage.fileURL(for: "audio.mp3")
    try audioData.write(to: audioURL) // Blocks main thread!
    return audioURL
}
```

---

### 2. SwiftData Fetch Optimization

**Problem**: Fetching large result sets can be slow.

**Solution**: Use fetch limits and predicates.

```swift
// ✅ GOOD
func fetchRecentRecords(limit: Int = 50) throws -> [GeneratedTextRecord] {
    var descriptor = FetchDescriptor<GeneratedTextRecord>(
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit

    return try modelContext.fetch(descriptor)
}

// With predicate
func fetchRecordsByProvider(_ provider: String, limit: Int = 50) throws -> [GeneratedTextRecord] {
    var descriptor = FetchDescriptor<GeneratedTextRecord>(
        predicate: #Predicate { $0.providerId == provider },
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit

    return try modelContext.fetch(descriptor)
}

// ❌ BAD
func fetchAllRecords() throws -> [GeneratedTextRecord] {
    // Fetches entire database!
    return try modelContext.fetch(FetchDescriptor<GeneratedTextRecord>())
}
```

---

### 3. Memory Management

**Problem**: Loading large files into memory.

**Solution**: Stream or use file references.

```swift
// ✅ GOOD - File reference approach
let record = GeneratedAudioRecord(
    audioData: nil, // Don't load into memory
    fileReference: fileRef
)

// When needed, stream or load on-demand
if let fileRef = record.fileReference {
    let audioURL = fileRef.fileURL(in: storage)
    try playerManager.play(from: audioURL, format: record.format)
}

// ❌ BAD - Loading large file into memory
let audioData = try Data(contentsOf: largeAudioURL) // 50MB in RAM!
let record = GeneratedAudioRecord(audioData: audioData, /* ... */)
```

---

## Version Compatibility

### Availability Annotations

When using features that require specific OS versions:

```swift
// File storage features require macOS 15.0+
@available(macOS 15.0, iOS 17.0, *)
func useFileStorage() {
    let storage = StorageAreaReference.temporary()
    // ...
}

// Fallback for older OS versions
func compatibleStorage() {
    if #available(macOS 15.0, iOS 17.0, *) {
        let storage = StorageAreaReference.temporary()
        // Use file storage
    } else {
        // Use in-memory approach
        let record = GeneratedTextRecord(text: "...", /* ... */)
    }
}
```

---

## Quick Reference

### Model Decision Tree

```
Need to store AI content?
│
├─ Text content?
│  ├─ < 10KB → GeneratedTextRecord (in-memory)
│  └─ > 10KB → GeneratedTextRecord + fileReference
│
├─ Audio content?
│  └─ Always use → GeneratedAudioRecord + fileReference
│
├─ Image content?
│  └─ Always use → GeneratedImageRecord + fileReference
│
└─ Vector embeddings?
   └─ Use → GeneratedEmbeddingRecord
```

### Storage Decision Tree

```
Storing content?
│
├─ Temporary processing?
│  └─ Use StorageAreaReference.temporary()
│
├─ Part of document bundle?
│  └─ Use StorageAreaReference.inBundle()
│
└─ Large file (> 1MB)?
   └─ Always use file storage + TypedDataFileReference
```

---

## Support & Resources

- **Repository**: https://github.com/intrusive-memory/SwiftCompartido
- **Issues**: https://github.com/intrusive-memory/SwiftCompartido/issues
- **Version**: 1.4.3
- **Test Coverage**: 314 tests in 22 suites, 95%+ coverage
- **License**: MIT

---

**End of AI Reference Guide**

Last updated: 2025-10-20
Document version: 1.4.3
