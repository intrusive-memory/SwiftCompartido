# SwiftCompartido

<p align="center">
    <img src="https://img.shields.io/badge/Swift-6.2+-orange.svg" />
    <img src="https://img.shields.io/badge/Platform-iOS%2026.0+%20|%20macOS%2026.0+-lightgrey.svg" />
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" />
    <img src="https://img.shields.io/badge/Version-6.2.1-blue.svg" />
</p>

**SwiftCompartido** is a Swift package for parsing, storing, and displaying screenplays and AI-generated content. Built with SwiftData and SwiftUI.

## Core Focus

SwiftCompartido has **two core missions**:

### 1. 📝 Parsing & Storage
- **Screenplay Parsing**: Fountain, Final Draft (FDX), PDF, Markdown, Highland, TextBundle
- **TypedDataStorage**: Unified storage for AI-generated content (text, audio, images, embeddings)
- **SwiftData Models**: GuionDocumentModel, GuionElementModel, TypedDataStorage
- **File Architecture**: Smart storage (in-memory for small content, file-based for large)

### 2. 🎨 UI Display
- **Screenplay Viewers**: GuionTextEditor (TextKit 2, 400-1600x faster), GuionViewer (List-based)
- **Element Widgets**: GuionElementsList for displaying screenplay elements
- **Content Browsers**: GeneratedContentListView, TypedDataDetailView, TypedDataRowView
- **List Widgets**: Query-based lists with filtering and grouping

**Everything else** in this library should support these two goals. Features unrelated to parsing/storage or UI display should be deprecated or moved to separate libraries.

## ⚡ What's New in 6.2.1

**Simplified Focus** - Removed CloudKit sync and AI generation stubs:
- 🧹 **-4,000 lines** of non-functional code removed
- 📦 **Focused scope**: Parsing, storage, and display only
- ⚡ **Cleaner API**: Removed `mode` and `storageMode` parameters

See [CHANGELOG.md](./CHANGELOG.md) for complete details.

## Features

### 📝 Screenplay Parsing & Storage

**Supported Formats:**
- **Fountain** (`.fountain`) - Native screenplay format
- **Final Draft** (`.fdx`) - XML import/export
- **PDF** (`.pdf`) - AI-powered extraction (iOS 26+)
- **Markdown** (`.md`) - YAML front matter support
- **Highland** (`.highland`) - ZIP archives with Fountain content
- **TextBundle** (`.textbundle`) - Container format with auto-detection
- **Pandoc** (`.docx`, `.odt`, `.rtf`) - Document conversion (macOS only)

**Parsing API:**

```swift
import SwiftCompartido

// Parse any supported format
let screenplay = try await GuionParsedElementCollection(string: fountainText)

// Convert to SwiftData
let document = await GuionDocumentParserSwiftData.parse(
    script: screenplay,
    in: modelContext
)

// Access elements in order
for element in document.sortedElements {
    print("\(element.elementType): \(element.text)")
}
```

**JSON .guion Format** (NEW in 6.2.0):
- 🚀 **40-60x faster** than legacy TextPack
- 📝 **Human-readable JSON** (perfect for git diff)
- 📦 **27% smaller** file sizes
- ✅ **Backward compatible**

### 💾 TypedDataStorage

Unified storage model for all AI-generated content types:

**Content Types:**
- **Text** (`text/*`) - In-memory or file-based
- **Audio** (`audio/*`) - Always file-based with TypedDataFileReference
- **Images** (`image/*`) - Always file-based
- **Embeddings** (`application/x-embedding`) - Vector storage

**Storage API:**

```swift
import SwiftCompartido

// Store text content
let textRecord = TypedDataStorage(
    providerId: "openai",
    requestorID: "gpt-4",
    mimeType: "text/plain",
    textValue: "Generated text",
    prompt: "Write a story"
)

// Store audio with file reference
let audioRecord = TypedDataStorage(
    id: requestID,
    providerId: "elevenlabs",
    requestorID: "tts.rachel",
    mimeType: "audio/mpeg",
    prompt: "Speak this",
    fileReference: fileRef,
    audioFormat: "mp3",
    voiceID: "rachel"
)

modelContext.insert(textRecord)
modelContext.insert(audioRecord)
try modelContext.save()
```

**Smart Storage Rules:**
- Text < 10KB: In-memory (`textValue`)
- Text ≥ 10KB: File-based (`fileReference`)
- Audio/Images: Always file-based
- Embeddings: In-memory or file-based

### 🎨 UI Components

**Screenplay Display:**

```swift
import SwiftUI
import SwiftCompartido

// High-performance TextKit 2 viewer (400-1600x faster)
struct ScreenplayView: View {
    let document: GuionDocumentModel

    var body: some View {
        GuionTextEditor(document: document)
            .environment(\.screenplayFontSize, 12)
    }
}

// List-based element display
struct ElementsView: View {
    let document: GuionDocumentModel

    var body: some View {
        GuionElementsList(document: document)
    }
}
```

**TypedDataStorage Display:**

```swift
// Browse all generated content with filtering
struct ContentView: View {
    let document: GuionDocumentModel
    let storageArea: StorageAreaReference?
    @StateObject private var audioPlayer = AudioPlayerManager()

    var body: some View {
        GeneratedContentListView(
            document: document,
            storageArea: storageArea
        )
        .environmentObject(audioPlayer)
    }
}

// Features:
// - MIME type filtering (Text, Audio, Image, Video, Embedding)
// - Preview pane with automatic content routing
// - Automatic audio playback for audio items
```

**Query-Based Lists:**

```swift
// Display all dialogue elements across all documents
struct DialogueListView: View {
    @Query(filter: #Predicate<GuionElementModel> {
        $0.elementType == .dialogue
    }) var dialogueElements: [GuionElementModel]

    var body: some View {
        List(dialogueElements) { element in
            Text(element.text)
        }
    }
}

// Display all audio content
struct AudioListView: View {
    @Query(filter: #Predicate<TypedDataStorage> {
        $0.mimeType.hasPrefix("audio/")
    }) var audioRecords: [TypedDataStorage]

    var body: some View {
        List(audioRecords) { record in
            TypedDataRowView(record: record)
        }
    }
}
```

## Quick Start

### Installation

**Swift Package Manager:**

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", from: "6.2.1")
]
```

Or in Xcode:
1. **File → Add Package Dependencies**
2. Enter: `https://github.com/intrusive-memory/SwiftCompartido.git`
3. Select version: **6.2.1** or later

### Basic Usage

```swift
import SwiftCompartido
import SwiftUI
import SwiftData

// 1. Parse a screenplay
let screenplay = try await GuionParsedElementCollection(string: fountainText)
let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: modelContext)

// 2. Display in UI
struct ScreenplayApp: View {
    let document: GuionDocumentModel

    var body: some View {
        TabView {
            // Screenplay viewer
            GuionTextEditor(document: document)
                .tabItem { Label("Screenplay", systemImage: "doc.text") }

            // Elements list
            GuionElementsList(document: document)
                .tabItem { Label("Elements", systemImage: "list.bullet") }

            // Generated content
            GeneratedContentListView(document: document, storageArea: nil)
                .tabItem { Label("Generated", systemImage: "waveform") }
        }
    }
}
```

## Documentation

### User Guides
- **[Usage Summary](./USAGE-SUMMARY.md)** - Quick reference and common patterns
- **[App Intents Guide](./Docs/APP_INTENTS_GUIDE.md)** - Apple Shortcuts integration
- **[Changelog](./CHANGELOG.md)** - Version history

### API Documentation
- **[ParsedFileService API](./Docs/PARSED_FILE_SERVICE_API.md)** - Parsing and querying
- **[Source File Tracking](./SOURCE_FILE_TRACKING.md)** - External file change detection
- **[PDF Capabilities](./Docs/PDF_CAPABILITIES.md)** - PDF screenplay parsing

### Developer Documentation
- **[CLAUDE.md](./CLAUDE.md)** - Architecture guide and development patterns
- **[Workflow Guide](./.claude/WORKFLOW.md)** - Branch strategy, commits, PRs, releases

## Requirements

- **iOS**: 26.0+
- **macOS**: 26.0+
- **Swift**: 6.2+
- **Xcode**: 17.0+

## Testing

SwiftCompartido has **95%+ test coverage** with **437 passing tests** organized into **4 test plans**:

- **UnitTests** - Fast unit tests (runs on every PR) ⚡️
- **LongTests** - Integration tests (runs on weekends) 🔄
- **UITests** - SwiftUI view tests (manual or weekend) 🎨
- **PerformanceTests** - Benchmarks (non-blocking) 📊

```bash
# Run unit tests (default for PRs)
./build.sh --action test

# Run specific test plan
xcodebuild test -scheme SwiftCompartido -testPlan UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

See [CLAUDE.md](./CLAUDE.md#testing-requirements) for complete test plan documentation and categorization rules.

## Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTING.md) and [Workflow Guide](./.claude/WORKFLOW.md) for details.

**Key Rules:**
- ✅ Always work on `development` branch
- ✅ Never commit directly to `main`
- ✅ All changes require PR with CI passing
- ✅ Maintain 90%+ test coverage

## License

[MIT License](./LICENSE) - See LICENSE file for details

## Support

- **Issues**: [GitHub Issues](https://github.com/intrusive-memory/SwiftCompartido/issues)
- **Discussions**: [GitHub Discussions](https://github.com/intrusive-memory/SwiftCompartido/discussions)

---

**SwiftCompartido** - Parse, store, and display screenplays with Swift.

<p align="center">Made with ❤️ by the SwiftCompartido team</p>
