# SwiftCompartido

<p align="center">
    <img src="https://img.shields.io/badge/Swift-6.2+-orange.svg" />
    <img src="https://img.shields.io/badge/Platform-macOS%2026.0+%20|%20iOS%2026.0+%20|%20Mac%20Catalyst-lightgrey.svg" />
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" />
    <img src="https://img.shields.io/badge/Version-1.6.0-green.svg" />
</p>

**SwiftCompartido** is a comprehensive Swift package for screenplay management, AI-generated content storage, and document serialization. Built with SwiftData, SwiftUI, and modern Swift concurrency.

## Features

### 📝 Screenplay Management
- **Fountain Format**: Full parsing and export support
- **FDX Format**: Final Draft XML import/export
- **TextPack**: Bundle screenplays with metadata and resources
- **Complete Element Support**: Scenes, dialogue, action, transitions, and more
- **Hierarchical Outlines**: Section headings with 6 levels
- **Chapter-Based Ordering**: Intelligent orderIndex spacing (Chapter 1: 100-199, Chapter 2: 200-299, etc.)
- **Order Guarantees**: `sortedElements` property ensures screenplay sequence is always maintained

### 🤖 AI Content Storage
- **Type-Safe Responses**: `AIResponseData` with typed content (text, audio, image, structured)
- **Usage Tracking**: Consolidated `UsageStats` for tokens and costs
- **Request Lifecycle**: Track AI requests with progress and status
- **Comprehensive Errors**: `AIServiceError` with recovery suggestions

### 💾 Generated Content Models
- **File-Based Architecture**: Efficient storage for large audio, images, and embeddings
- **SwiftData Integration**: Persistent models with Phase 6 architecture
- **Flexible Storage**: Support both in-memory and file-based approaches
- **Complete Metadata**: Track prompts, providers, usage, and timestamps

### ☁️ CloudKit Sync Support
- **Dual Storage**: Seamlessly sync between local `.guion` bundles and CloudKit
- **Storage Modes**: Choose local-only, CloudKit-only, or hybrid storage per record
- **Automatic Fallback**: Loads from CloudKit or local storage transparently
- **Conflict Resolution**: Built-in version tracking and conflict detection
- **Zero Breaking Changes**: Fully backward compatible with existing local-only code

### 🎨 UI Components
- **GuionViewer**: Screenplay rendering with proper formatting (simplified in 1.4.3)
- **GuionElementsList**: Flat, @Query-based element list display (NEW in 1.4.3)
- **Source File Tracking**: Automatic detection of external file changes (NEW in 1.4.3)
- **TextConfigurationView**: AI text generation settings
- **AudioPlayerManager**: Waveform visualization and playback
- **No Visible Separators**: Clean flow between screenplay elements (NEW in 1.6.0)

### 📊 Progress Reporting
- **Comprehensive Tracking**: Progress for all parsing, conversion, and export operations
- **SwiftUI Integration**: Works seamlessly with `ProgressView` and `@Published` properties
- **Cancellation Support**: All operations support `Task` cancellation with cleanup
- **Performance Optimized**: <2% overhead, batched updates, thread-safe
- **Backward Compatible**: Optional progress parameter - existing code unchanged
- **314 Tests**: Full test coverage across 22 test suites

## Quick Start

### Installation

#### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", from: "1.0.0")
]
```

Or in Xcode:
1. **File → Add Package Dependencies**
2. Enter: `https://github.com/intrusive-memory/SwiftCompartido.git`
3. Select version: **1.0.0**

### Usage Examples

#### Parse a Fountain Screenplay

```swift
import SwiftCompartido

let fountainText = """
Title: My Screenplay
Author: Jane Doe

FADE IN:

EXT. BEACH - DAY

SARAH walks along the shore.

SARAH
What a beautiful day.
"""

// ✅ Recommended: Use GuionParsedElementCollection
let screenplay = try await GuionParsedElementCollection(string: fountainText)

// Access elements
for element in screenplay.elements {
    print("\(element.elementType): \(element.text)")
}

// Get scenes only
let scenes = screenplay.elements.filter { $0.elementType == .sceneHeading }
```

#### Store AI-Generated Text

```swift
import SwiftCompartido
import SwiftData

@MainActor
func storeGeneratedText(_ text: String, prompt: String, modelContext: ModelContext) throws {
    let record = GeneratedTextRecord(
        providerId: "openai",
        requestorID: "gpt-4",
        text: text,
        wordCount: text.split(separator: " ").count,
        characterCount: text.count,
        prompt: prompt
    )

    modelContext.insert(record)
    try modelContext.save()
}
```

#### Generate and Play TTS Audio

```swift
import SwiftCompartido

@MainActor
@available(macOS 15.0, iOS 17.0, *)
func generateAndPlayAudio(text: String) async throws {
    let requestID = UUID()

    // 1. Setup storage
    let storage = StorageAreaReference.temporary(requestID: requestID)
    try storage.createDirectoryIfNeeded()

    // 2. Generate audio (your TTS provider)
    let audioData = try await yourTTSProvider.generate(text: text)

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

    // 5. Create record
    let record = GeneratedAudioRecord(
        providerId: "elevenlabs",
        requestorID: "tts.rachel",
        audioData: nil, // File-based storage
        format: "mp3",
        voiceID: "rachel",
        voiceName: "Rachel",
        prompt: text,
        fileReference: fileRef
    )

    // 6. Save to database
    modelContext.insert(record)
    try modelContext.save()

    // 7. Play audio
    let playerManager = AudioPlayerManager()
    try playerManager.play(record: record, storageArea: storage)
}
```

#### Display Screenplay in SwiftUI

```swift
import SwiftCompartido
import SwiftUI
import SwiftData

struct ScreenplayView: View {
    let document: GuionDocumentModel

    var body: some View {
        GuionViewer(document: document)
            .environment(\.screenplayFontSize, 12)
    }
}

// Or display all elements from all documents
struct AllElementsView: View {
    var body: some View {
        GuionElementsList() // No document filter
    }
}
```

#### Progress Reporting for Long Operations

```swift
import SwiftCompartido
import SwiftUI

@MainActor
class ParserViewModel: ObservableObject {
    @Published var progressMessage = ""
    @Published var progressFraction = 0.0
    @Published var isProcessing = false

    func parseScreenplay(_ text: String) async throws -> GuionParsedElementCollection {
        isProcessing = true
        defer { isProcessing = false }

        // Create progress tracker
        let progress = OperationProgress(totalUnits: nil) { update in
            Task { @MainActor in
                self.progressMessage = update.description
                self.progressFraction = update.fractionCompleted ?? 0.0
            }
        }

        // ✅ Recommended: Use GuionParsedElementCollection with progress
        return try await GuionParsedElementCollection(string: text, progress: progress)
    }
}

// In SwiftUI view:
struct ProgressParsingView: View {
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
                    _ = try await viewModel.parseScreenplay(largeScript)
                }
            }
        }
    }
}
```

#### CloudKit Sync - Local Only (Default)

```swift
import SwiftCompartido
import SwiftData

// Local-only container (no CloudKit)
let container = try SwiftCompartidoContainer.makeLocalContainer()

// Create record with default local storage
let record = GeneratedTextRecord(
    providerId: "openai",
    requestorID: "gpt-4",
    text: "Generated content",
    wordCount: 2,
    characterCount: 17
    // storageMode defaults to .local
)

// Works exactly as before - no CloudKit involved
modelContext.insert(record)
try modelContext.save()
```

#### CloudKit Sync - Private Database

```swift
import SwiftCompartido
import SwiftData

// CloudKit private database container
let container = try SwiftCompartidoContainer.makeCloudKitPrivateContainer(
    containerIdentifier: "iCloud.com.yourcompany.YourApp"
)

// Create record with CloudKit storage
let record = GeneratedTextRecord(
    providerId: "openai",
    requestorID: "gpt-4",
    text: "Synced content",
    wordCount: 2,
    characterCount: 13,
    storageMode: .cloudKit  // Enable CloudKit sync
)

modelContext.insert(record)
try modelContext.save() // Automatically syncs to CloudKit
```

#### CloudKit Sync - Hybrid Storage (Dual Mode)

```swift
@available(macOS 15.0, iOS 17.0, *)
func saveAudioWithCloudKitSync() throws {
    let requestID = UUID()
    let storage = StorageAreaReference.temporary(requestID: requestID)
    let audioData = Data(/* your audio data */)

    let record = GeneratedAudioRecord(
        id: requestID,
        providerId: "elevenlabs",
        requestorID: "tts.rachel",
        audioData: nil,
        format: "mp3",
        voiceID: "rachel",
        voiceName: "Rachel"
    )

    // Saves to BOTH local file AND CloudKit
    try record.saveAudio(audioData, to: storage, mode: .hybrid)

    modelContext.insert(record)
    try modelContext.save()
}

// Loading automatically tries CloudKit first, then falls back to local
let audioData = try record.loadAudio(from: storage)
```

#### CloudKit Sync - Check Availability

```swift
import CloudKit

Task {
    let isAvailable = await CKDatabase.isCloudKitAvailable()
    if isAvailable {
        // User is signed into iCloud, enable sync features
        setupCloudKitSync()
    } else {
        // Fall back to local-only storage
        setupLocalOnlyStorage()
    }
}
```

## Documentation

- **[Quick Usage Summary](./USAGE-SUMMARY.md)** - Fast reference and common patterns
- **[AI Reference Guide](./AI-REFERENCE.md)** - Comprehensive guide for AI assistants
- **[Contributing Guide](./CONTRIBUTING.md)** - How to contribute
- **[Changelog](./CHANGELOG.md)** - Version history

## Requirements

- **macOS**: 26.0+
- **iOS**: 26.0+
- **Swift**: 6.2+
- **Xcode**: 16.0+

## Testing

SwiftCompartido has **95%+ test coverage** with **314 passing tests** across 22 test suites.

Run tests:

```bash
# Run all tests
swift test

# Run tests in parallel (faster)
swift test --parallel --num-workers 10
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTING.md) for details.

## License

[MIT License](./LICENSE) - See LICENSE file for details

## Support

- **Issues**: [GitHub Issues](https://github.com/intrusive-memory/SwiftCompartido/issues)
- **Discussions**: [GitHub Discussions](https://github.com/intrusive-memory/SwiftCompartido/discussions)

## Acknowledgments

Built with assistance from [Claude Code](https://claude.com/claude-code) for model consolidation and comprehensive testing.

---

**SwiftCompartido** - Building better AI-powered applications with Swift.

<p align="center">Made with ❤️ by the SwiftCompartido team</p>
