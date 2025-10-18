# SwiftCompartido

<p align="center">
    <img src="https://img.shields.io/badge/Swift-6.2+-orange.svg" />
    <img src="https://img.shields.io/badge/Platform-macOS%2014.0+%20|%20iOS%2017.0+-lightgrey.svg" />
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" />
    <img src="https://img.shields.io/badge/Version-1.0.0-green.svg" />
</p>

**SwiftCompartido** is a comprehensive Swift package for screenplay management, AI-generated content storage, and document serialization. Built with SwiftData, SwiftUI, and modern Swift concurrency.

## Features

### 📝 Screenplay Management
- **Fountain Format**: Full parsing and export support
- **FDX Format**: Final Draft XML import/export
- **TextPack**: Bundle screenplays with metadata and resources
- **Complete Element Support**: Scenes, dialogue, action, transitions, and more
- **Hierarchical Outlines**: Section headings with 6 levels

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

### 🎨 UI Components
- **GuionViewer**: Screenplay rendering with proper formatting
- **SceneBrowser**: Hierarchical scene navigation
- **TextConfigurationView**: AI text generation settings
- **AudioPlayerManager**: Waveform visualization and playback

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

let parser = FountainParser()
let screenplay = parser.parse(fountainText)

// Access elements
for element in screenplay.elements {
    print("\(element.elementType): \(element.text)")
}

// Get scenes only
let scenes = screenplay.scenes // Returns only scene headings
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

struct ScreenplayView: View {
    let screenplay: GuionParsedScreenplay

    var body: some View {
        GuionViewer(screenplay: screenplay)
    }
}
```

## Documentation

- **[Quick Usage Summary](./USAGE-SUMMARY.md)** - Fast reference and common patterns
- **[AI Reference Guide](./AI-REFERENCE.md)** - Comprehensive guide for AI assistants
- **[Contributing Guide](./CONTRIBUTING.md)** - How to contribute
- **[Changelog](./CHANGELOG.md)** - Version history

## Requirements

- **macOS**: 14.0+ (macOS 15.0+ for file storage features)
- **iOS**: 17.0+
- **Swift**: 6.2+
- **Xcode**: 16.0+

## Testing

SwiftCompartido has **95%+ test coverage** with **159 passing tests** across 11 test suites.

Run tests:

```bash
swift test
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
