# SwiftCompartido - AI Reference Guide

> **For AI Assistants**: This document provides comprehensive guidance for understanding, using, and building upon the SwiftCompartido library.

**Version**: 1.0.0
**Swift Version**: 5.9+
**Platforms**: macOS 14.0+, iOS 17.0+
**Last Updated**: 2025-10-18

---

## Table of Contents

1. [Library Overview](#library-overview)
2. [Architecture & Design Patterns](#architecture--design-patterns)
3. [Core Models Reference](#core-models-reference)
4. [Common Usage Patterns](#common-usage-patterns)
5. [Best Practices](#best-practices)
6. [Integration Examples](#integration-examples)
7. [Error Handling](#error-handling)
8. [Testing Guidance](#testing-guidance)
9. [Performance Considerations](#performance-considerations)

---

## Library Overview

### What is SwiftCompartido?

SwiftCompartido is a Swift package that provides:

1. **Screenplay Management**: Parse, manipulate, and export screenplays (Fountain & FDX formats)
2. **AI Content Storage**: File-based storage for AI-generated text, audio, images, and embeddings
3. **SwiftData Integration**: Persistent models with Phase 6 architecture
4. **UI Components**: Ready-to-use SwiftUI views for screenplay rendering and audio playback

### Key Capabilities

```swift
// Parse screenplays
let parser = FountainParser()
let screenplay = parser.parse(fountainText)

// Store AI-generated audio with file-based storage
let record = GeneratedAudioRecord(
    providerId: "elevenlabs",
    audioData: nil, // Data stored in file
    fileReference: fileRef // Points to actual file
)

// Track AI request lifecycle
let status = RequestStatus.executing(progress: 0.5)

// Render screenplays in SwiftUI
GuionViewer(screenplay: screenplay)
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

#### GuionParsedScreenplay

**Purpose**: In-memory representation of a parsed screenplay.

**Structure**:
```swift
public struct GuionParsedScreenplay: Sendable {
    public let elements: [GuionElement]
    public let titlePage: [String: String]
    public let format: SerializationFormat

    // Computed properties
    public var scenes: [GuionElement] { /* ... */ }
    public var characters: [CharacterInfo] { /* ... */ }
    public var locations: [SceneLocation] { /* ... */ }
}
```

**Parse Fountain**:
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

let parser = FountainParser()
let screenplay = parser.parse(fountainText)

// Access elements
for element in screenplay.elements {
    print("\(element.elementType): \(element.text)")
}

// Get scenes only
let scenes = screenplay.scenes
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

**ElementType**:
```swift
public enum ElementType: Sendable {
    case sceneHeading
    case action
    case character
    case dialogue
    case parenthetical
    case transition
    case sectionHeading(level: Int) // 1-6
    case synopsis
    case comment
    case boneyard
    case lyrics
    case pageBreak
    case titlePageKey(String)
    case titlePageValue(String)
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

## Common Usage Patterns

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

### Pattern 3: Screenplay Parsing and Rendering

```swift
struct ScreenplayView: View {
    let fountainURL: URL
    @State private var screenplay: GuionParsedScreenplay?

    var body: some View {
        Group {
            if let screenplay {
                GuionViewer(screenplay: screenplay)
            } else {
                ProgressView("Loading screenplay...")
            }
        }
        .task {
            await loadScreenplay()
        }
    }

    func loadScreenplay() async {
        do {
            let fountainText = try String(contentsOf: fountainURL)
            let parser = FountainParser()
            screenplay = parser.parse(fountainText)
        } catch {
            print("Error loading screenplay: \(error)")
        }
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

    func narrateScreenplay(_ screenplay: GuionParsedScreenplay) async throws {
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
- **Version**: 1.0.0
- **License**: [Your License]

---

**End of AI Reference Guide**

Last updated: 2025-10-18
Document version: 1.0.0
