# SwiftCompartido - Quick Usage Summary

> Fast reference for common patterns and code snippets

**Version**: 1.3.0 | [Full AI Reference](./AI-REFERENCE.md)

---

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", from: "1.0.0")
]
```

---

## 🚀 Quick Start

### Parse a Screenplay

```swift
import SwiftCompartido

let fountainText = try String(contentsOf: url)
let parser = FountainParser()
let screenplay = parser.parse(fountainText)

// Access elements
for element in screenplay.elements {
    print("\(element.elementType): \(element.text)")
}
```

### Store AI-Generated Text

```swift
let record = GeneratedTextRecord(
    providerId: "openai",
    requestorID: "gpt4",
    text: generatedText,
    wordCount: generatedText.split(separator: " ").count,
    characterCount: generatedText.count,
    prompt: userPrompt
)

modelContext.insert(record)
try modelContext.save()
```

### Store AI-Generated Audio (File-Based)

```swift
// 1. Create storage
let storage = StorageAreaReference.temporary(requestID: requestID)
try storage.createDirectoryIfNeeded()

// 2. Save audio file
let audioURL = storage.fileURL(for: "speech.mp3")
try audioData.write(to: audioURL)

// 3. Create file reference
let fileRef = TypedDataFileReference(
    requestID: requestID,
    fileName: "speech.mp3",
    fileSize: Int64(audioData.count),
    mimeType: "audio/mpeg"
)

// 4. Create record (no in-memory data)
let record = GeneratedAudioRecord(
    providerId: "elevenlabs",
    requestorID: "tts.rachel",
    audioData: nil,
    format: "mp3",
    durationSeconds: 5.5,
    voiceID: "rachel",
    voiceName: "Rachel",
    prompt: text,
    fileReference: fileRef
)

modelContext.insert(record)
try modelContext.save()
```

### Play Audio

```swift
let playerManager = AudioPlayerManager()

// Automatic storage detection
try playerManager.play(record: audioRecord, storageArea: storage)

// Or play directly from URL
try playerManager.play(from: audioURL, format: "mp3", duration: 5.5)

// Controls
playerManager.pause()
playerManager.resume()
playerManager.stop()
playerManager.seek(to: 30.0) // Seek to 30 seconds
```

### Parse with Progress Reporting (v1.3.0+)

```swift
// Simple progress handler
let progress = OperationProgress(totalUnits: nil) { update in
    print("\(update.description): \(update.fractionCompleted ?? 0.0)")
}

let parser = try await FountainParser(string: text, progress: progress)

// SwiftUI integration
@MainActor
class ParserViewModel: ObservableObject {
    @Published var progressMessage = ""
    @Published var progressFraction = 0.0

    func parse(_ text: String) async throws {
        let progress = OperationProgress(totalUnits: nil) { update in
            Task { @MainActor in
                self.progressMessage = update.description
                self.progressFraction = update.fractionCompleted ?? 0.0
            }
        }

        let parser = try await FountainParser(string: text, progress: progress)
    }
}

// In SwiftUI view:
ProgressView(value: viewModel.progressFraction) {
    Text(viewModel.progressMessage)
}
```

---

## 📋 Model Cheat Sheet

### AI Response Models

```swift
// AIResponseData - Primary response type
let response = AIResponseData(
    requestID: UUID(),
    providerID: "openai",
    content: .text("Generated text"),
    metadata: ["model": "gpt-4"],
    usage: UsageStats(
        promptTokens: 100,
        completionTokens: 50,
        totalTokens: 150,
        costUSD: 0.002,
        durationSeconds: 1.5
    )
)

// Access typed content
if let text = response.content?.text { /* ... */ }
if let audio = response.content?.audioContent { /* ... */ }
if let image = response.content?.imageContent { /* ... */ }

// Check status
if response.isSuccess { /* ... */ }
if let error = response.error { /* ... */ }
```

### Request Tracking

```swift
// Track request lifecycle
let tracked = TrackedRequest(
    request: aiRequest,
    status: .pending,
    providerID: "openai",
    submittedAt: Date()
)

// Update status
let executing = tracked.withStatus(.executing(progress: 0.5))
let completed = tracked.withStatus(.completed(response))
let failed = tracked.withStatus(.failed(error))
```

### Storage References

```swift
// Temporary storage
let storage = StorageAreaReference.temporary(requestID: requestID)

// Document bundle storage
let storage = StorageAreaReference.inBundle(
    requestID: requestID,
    bundleURL: documentURL,
    bundleIdentifier: "com.app.project"
)

// File operations
try storage.createDirectoryIfNeeded()
let fileURL = storage.fileURL(for: "data.mp3")
let files = try storage.listFiles()
```

---

## 🎯 Common Patterns

### Pattern: Complete TTS Workflow

```swift
@MainActor
func generateAndPlaySpeech(text: String, voiceID: String) async throws {
    let requestID = UUID()

    // 1. Setup storage
    let storage = StorageAreaReference.temporary(requestID: requestID)
    try storage.createDirectoryIfNeeded()

    // 2. Generate audio (your TTS provider)
    let audioData = try await ttsProvider.generate(text: text, voiceID: voiceID)

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

    // 5. Create and save record
    let record = GeneratedAudioRecord(
        providerId: "elevenlabs",
        requestorID: "tts.\(voiceID)",
        audioData: nil,
        format: "mp3",
        voiceID: voiceID,
        prompt: text,
        fileReference: fileRef
    )

    modelContext.insert(record)
    try modelContext.save()

    // 6. Play audio
    try playerManager.play(record: record, storageArea: storage)
}
```

### Pattern: Fetch Recent Records

```swift
@MainActor
func fetchRecentAudio(limit: Int = 10) throws -> [GeneratedAudioRecord] {
    var descriptor = FetchDescriptor<GeneratedAudioRecord>(
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit

    return try modelContext.fetch(descriptor)
}

func fetchByProvider(_ providerID: String) throws -> [GeneratedAudioRecord] {
    let descriptor = FetchDescriptor<GeneratedAudioRecord>(
        predicate: #Predicate { $0.providerId == providerID },
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )

    return try modelContext.fetch(descriptor)
}
```

### Pattern: Error Handling

```swift
do {
    let response = try await provider.generate(prompt)
    // Process response

} catch AIServiceError.rateLimitExceeded(let message, let retryAfter) {
    if let delay = retryAfter {
        try await Task.sleep(for: .seconds(delay))
        // Retry
    }

} catch AIServiceError.authenticationFailed(let message) {
    // Re-authenticate

} catch let error as AIServiceError where error.isRecoverable {
    if let delay = error.retryDelay {
        try await Task.sleep(for: .seconds(delay))
        // Retry
    }

} catch {
    print("Unhandled: \(error)")
}
```

### Pattern: Batch Processing with Progress

```swift
@MainActor
@Observable
class BatchProcessor {
    var progress = 0.0
    var results: [GeneratedTextRecord] = []

    func processBatch(_ prompts: [String]) async throws {
        let total = Double(prompts.count)

        for (index, prompt) in prompts.enumerated() {
            progress = Double(index) / total

            let record = try await generateText(prompt: prompt)
            results.append(record)
        }

        progress = 1.0
    }
}
```

---

## 🔧 SwiftUI Integration

### Display Generated Text

```swift
struct GeneratedTextView: View {
    let record: GeneratedTextRecord

    var body: some View {
        VStack(alignment: .leading) {
            Text(record.text ?? "No text")
                .font(.body)

            HStack {
                Label("\(record.wordCount ?? 0) words", systemImage: "textformat")
                Label("\(record.characterCount ?? 0) chars", systemImage: "character")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
```

### Display Generated Image

```swift
struct GeneratedImageView: View {
    let record: GeneratedImageRecord
    let storage: StorageAreaReference

    var body: some View {
        if let fileRef = record.fileReference {
            let imageURL = fileRef.fileURL(in: storage)

            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fit)
                case .failure:
                    Image(systemName: "exclamationmark.triangle")
                case .empty:
                    ProgressView()
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}
```

### Audio Player View

```swift
struct AudioPlayerView: View {
    let record: GeneratedAudioRecord
    let storage: StorageAreaReference
    @State private var manager = AudioPlayerManager()

    var body: some View {
        VStack {
            HStack {
                Button(action: { try? manager.play(record: record, storageArea: storage) }) {
                    Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                }

                Slider(value: Binding(
                    get: { manager.currentTime },
                    set: { manager.seek(to: $0) }
                ), in: 0...manager.duration)

                Text(formatTime(manager.currentTime))
                    .font(.caption)
            }

            // Waveform visualization
            if !manager.audioLevels.isEmpty {
                HStack(spacing: 2) {
                    ForEach(0..<manager.audioLevels.count, id: \.self) { i in
                        Rectangle()
                            .fill(.blue)
                            .frame(width: 3, height: CGFloat(manager.audioLevels[i]) * 50)
                    }
                }
            }
        }
    }

    func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
```

### Screenplay Viewer

```swift
struct ScreenplayView: View {
    let screenplay: GuionParsedScreenplay

    var body: some View {
        GuionViewer(screenplay: screenplay)
    }
}

// Or custom rendering
struct CustomScreenplayView: View {
    let screenplay: GuionParsedScreenplay

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(screenplay.elements) { element in
                    ElementView(element: element)
                }
            }
        }
    }
}

struct ElementView: View {
    let element: GuionElement

    var body: some View {
        switch element.elementType {
        case .sceneHeading:
            Text(element.text)
                .font(.headline)
                .textCase(.uppercase)

        case .character:
            Text(element.text)
                .font(.body)
                .textCase(.uppercase)
                .padding(.leading, 150)

        case .dialogue:
            Text(element.text)
                .font(.body)
                .padding(.leading, 100)
                .padding(.trailing, 100)

        case .action:
            Text(element.text)
                .font(.body)

        default:
            Text(element.text)
        }
    }
}
```

---

## 🎓 Best Practices

### ✅ DO

```swift
// Use file storage for large data
let fileRef = TypedDataFileReference(/* ... */)
record.fileReference = fileRef
record.audioData = nil

// Handle errors properly
do {
    try await operation()
} catch let error as AIServiceError {
    handleAIError(error)
} catch {
    handleGenericError(error)
}

// Use @MainActor for UI updates
@MainActor
@Observable
class ViewModel {
    var isLoading = false
}

// Limit fetch results
var descriptor = FetchDescriptor<T>(/* ... */)
descriptor.fetchLimit = 50
```

### ❌ DON'T

```swift
// Don't store large data in-memory
record.audioData = largeAudioData // 50MB in database!

// Don't silently fail
func doSomething() {
    try? riskyOperation() // Swallows errors
}

// Don't block main thread
func saveFile() {
    try data.write(to: url) // Blocks!
}

// Don't fetch all records
let all = try context.fetch(FetchDescriptor<T>()) // Loads entire DB
```

---

## 📊 Decision Trees

### Should I use file storage?

```
File size?
├─ < 100 KB   → In-memory OK
├─ 100 KB - 1 MB → Consider file storage
└─ > 1 MB     → Always use file storage
```

### Which model should I use?

```
Content type?
├─ Text
│  ├─ < 10 KB     → GeneratedTextRecord (in-memory)
│  └─ > 10 KB     → GeneratedTextRecord + fileReference
│
├─ Audio         → GeneratedAudioRecord + fileReference
│
├─ Image         → GeneratedImageRecord + fileReference
│
└─ Embeddings    → GeneratedEmbeddingRecord
```

### Which storage area?

```
Storage duration?
├─ Temporary processing  → StorageAreaReference.temporary()
├─ Document bundle       → StorageAreaReference.inBundle()
└─ Long-term persistence → Custom persistent location
```

---

## 🔍 Quick Lookup

### Common Imports

```swift
import SwiftCompartido        // Core models and parsing
import SwiftData              // For @Model and ModelContext
import AVFoundation           // For AudioPlayerManager
```

### Main Types

| Type | Purpose | Use When |
|------|---------|----------|
| `AIResponseData` | AI provider response | All AI operations |
| `UsageStats` | Token/cost tracking | Track usage |
| `GeneratedTextRecord` | Store text | AI text output |
| `GeneratedAudioRecord` | Store audio | TTS output |
| `GeneratedImageRecord` | Store images | Image generation |
| `TypedDataFileReference` | File reference | Large files |
| `StorageAreaReference` | File storage area | File organization |
| `AudioPlayerManager` | Audio playback | Play TTS/audio |
| `GuionParsedScreenplay` | Screenplay | Parse/render scripts |
| `OperationProgress` | Progress tracking | Long operations (v1.3.0+) |
| `ProgressUpdate` | Progress state | Handler closures (v1.3.0+) |

### Error Types

| Error | Recovery | Retry? |
|-------|----------|--------|
| `rateLimitExceeded` | Wait & retry | ✅ Yes |
| `networkError` | Check connection & retry | ✅ Yes |
| `timeout` | Retry with shorter timeout | ✅ Yes |
| `authenticationFailed` | Re-authenticate | ❌ No |
| `invalidAPIKey` | Update API key | ❌ No |
| `invalidRequest` | Fix request params | ❌ No |

---

## 📚 More Resources

- **Full AI Reference**: [AI-REFERENCE.md](./AI-REFERENCE.md)
- **Repository**: https://github.com/intrusive-memory/SwiftCompartido
- **Issues**: https://github.com/intrusive-memory/SwiftCompartido/issues

---

**Version**: 1.3.0
**Last Updated**: 2025-10-19

### What's New in 1.3.0

- **Progress Reporting**: All parsing, conversion, and export operations now support progress tracking
- **SwiftUI Integration**: Native `ProgressView` support with `@Published` properties
- **Cancellation Support**: All progress-enabled operations support `Task` cancellation
- **275 Tests**: 99 new tests covering progress reporting (7-phase implementation)
- **<2% Overhead**: Minimal performance impact with batched updates
- **100% Backward Compatible**: Optional progress parameters, existing code unchanged
