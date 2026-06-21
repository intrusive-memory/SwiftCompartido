# SwiftCompartido

<p align="center">
    <img src="icon.jpg" alt="SwiftCompartido" width="200" />
</p>

<p align="center">
    <img src="https://img.shields.io/badge/Swift-6.2+-orange.svg" />
    <img src="https://img.shields.io/badge/Platform-iOS%2026.0+%20|%20macOS%2026.0+-lightgrey.svg" />
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" />
    <img src="https://img.shields.io/badge/Version-7.2.0--dev-blue.svg" />
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
- **Screenplay Viewers**: GuionTextEditor (TextKit 2, 400-1600x faster), GuionViewer (reference implementation)
- **Element Views**: SceneHeadingView, DialogueTextView, ActionView, and 10+ element-specific views
- **Element Widgets**: GuionElementsList for displaying screenplay elements
- **Content Browsers**: GeneratedContentListView, TypedDataDetailView, TypedDataRowView
- **List Widgets**: Query-based lists with filtering and grouping
- **DisplayableElement Protocol**: Enables DTOs to work seamlessly with element views

**Everything else** in this library should support these two goals. Features unrelated to parsing/storage or UI display should be deprecated or moved to separate libraries.

## ⚡ What's New

**Version 7.2.0-dev** (development) is the next release in progress. Latest release: **7.2.0** adds comprehensive testing infrastructure, error handling improvements, and GPU cache reliability enhancements. Key highlights:

- 🔧 **Swift 6 Concurrency**: Fixed actor isolation errors in HierarchyBuilder parameters
- 🔧 **Swift 6 Compliance**: Marked buildHierarchy parameters as `sending` for strict concurrency
- ⚠️ **AI PDF Tests**: Disabled flaky Foundation Models PDF parsing tests pending reliability improvements

See [CHANGELOG.md](./CHANGELOG.md) for complete version history and detailed release notes.

## Features

### 📝 Screenplay Parsing & Storage

**Supported Formats:**
- **Fountain** (`.fountain`) - Native screenplay format
- **Final Draft** (`.fdx`) - XML import/export
- **PDF** (`.pdf`) - AI-powered conversion with Apple Intelligence (98%+ accuracy), automatic heuristic fallback (95%+ accuracy) (see [Foundation Models Status](./Docs/FOUNDATION_MODELS_STATUS.md))
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

**JSON .guion Format**:
- 🚀 **40-60x faster** than legacy TextPack
- 📝 **Human-readable JSON** (perfect for git diff)
- 📦 **27% smaller** file sizes
- ✅ **Backward compatible**

### 🎭 Cast Management

Cast management has moved to **SwiftProyecto** for PROJECT.md-based workflows:

```swift
import SwiftProyecto

let discovery = ProjectDiscovery()
if let projectMd = discovery.findProjectMd(from: screenplayURL) {
    let cast = try discovery.readCast(from: projectMd)
    for member in cast {
        print("\(member.character): \(member.voices)")
    }
}
```

See [SwiftProyecto documentation](https://github.com/intrusive-memory/SwiftProyecto) for details.

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
    .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", from: "6.6.0")
]
```

Or in Xcode:
1. **File → Add Package Dependencies**
2. Enter: `https://github.com/intrusive-memory/SwiftCompartido.git`
3. Select version: **6.3.0** or later

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

## Reference Implementation

**GuionViewer** is a minimal macOS demo app (located in `GuionViewer/`) that demonstrates best practices for integrating SwiftCompartido with proper concurrency, performance, and UI patterns.

### Key Features
- ✅ **ModelActor Pattern**: Proper actor isolation for SwiftData operations
- ✅ **Infinite Scrolling**: Lazy-loads large screenplays in batches (100 elements at a time)
- ✅ **Fixed Typography**: 12pt Courier New with 102 character width (8.5" page)
- ✅ **Centered Layout**: Content stays centered, window resizable without affecting text
- ✅ **Sendable DTOs**: Safe cross-actor communication with `DocumentInfo` and `ElementInfo`
- ✅ **Component Reuse**: Uses SwiftCompartido's element views via DisplayableElement protocol
- ✅ **Bundle Resources**: Loads 24+ screenplay files from app bundle

### Architecture Highlights
```swift
// DocumentModelActor handles all database operations
let actor = DocumentModelActor(modelContainer: container)

// Parse screenplay in background
let documentID = try await actor.parseAndSaveDocument(from: url)

// Fetch Sendable DTOs for UI display
let docInfo = await actor.getDocumentInfo(documentID: documentID)
let elements = try await actor.getElements(for: documentID, limit: 100)

// Display with SwiftCompartido element views
ForEach(elements) { element in
    switch element.elementType {
    case .sceneHeading:
        SceneHeadingView(element: element)
    case .dialogue:
        DialogueTextView(element: element)
    // ... other element types
    }
}
```

### Key Implementation Details

**Fixed-Width Layout:**
- Font: 12pt Courier New (fixed, never scales)
- Width: 734.4pt (12pt × 0.6 aspect ratio × 102 chars)
- Centered in window with `.frame(width: contentWidth).frame(maxWidth: .infinity)`

**Element Ordering:**
- Elements sorted by composite key `(chapterIndex, orderIndex)`
- Guaranteed document order regardless of SwiftData relationship ordering
- Chapter-aware positioning (0 = before chapters, 1 = Chapter 1, etc.)

**Component Pattern:**
- ElementInfo DTOs conform to DisplayableElement
- Reuses 10+ SwiftCompartido element views (SceneHeadingView, DialogueTextView, etc.)
- No duplicate view code - single source of truth for screenplay formatting

### Running GuionViewer
```bash
cd GuionViewer
xcodebuild build -scheme GuionViewer -destination 'platform=macOS'
open ~/Library/Developer/Xcode/DerivedData/GuionViewer-*/Build/Products/Debug/GuionViewer.app
```

**Use GuionViewer as a template when building apps with SwiftCompartido.**

See `GuionViewer/REQUIREMENTS.md` for complete specifications.

## Voice Download Helper

SwiftCompartido includes tools to help users download Enhanced and Premium system voices for high-quality Text-to-Speech:

```swift
// Prompt user to download Premium voices
VoiceDownloadHelper.promptUserToDownloadPremiumVoices { result in
    switch result {
    case .success:
        print("Voice download launched")
    case .failure(let error):
        print("Error: \(error)")
    }
}

// SwiftUI integration
Button("Download Premium Voices") {
    showVoiceDownload = true
}
.presentVoiceDownload(isPresented: $showVoiceDownload)
```

**See [Voice Download Guide](./Docs/VOICE_DOWNLOAD_GUIDE.md) for complete documentation.**

## Documentation

### User Guides
- **[Usage Summary](./Docs/USAGE-SUMMARY.md)** - Quick reference and common patterns
- **[App Intents Guide](./Docs/APP_INTENTS_GUIDE.md)** - Apple Shortcuts integration
- **[Changelog](./CHANGELOG.md)** - Version history

### API Documentation
- **[ParsedFileService API](./Docs/PARSED_FILE_SERVICE_API.md)** - Parsing and querying
- **[Source File Tracking](./Docs/SOURCE_FILE_TRACKING.md)** - External file change detection
- **[PDF Capabilities](./Docs/old/PDF_CAPABILITIES.md)** - PDF reading/writing assessment
- **[Foundation Models Status](./Docs/FOUNDATION_MODELS_STATUS.md)** - AI-powered PDF parsing roadmap

### Developer Documentation
- **[AGENTS.md](./AGENTS.md)** - Comprehensive AI agent documentation (architecture, models, patterns)
- **[CLAUDE.md](./CLAUDE.md)** - Claude Code specific instructions
- **[Workflow Guide](./.claude/WORKFLOW.md)** - Branch strategy, commits, PRs, releases

### Schema Versioning
- **[SwiftCompartidoSchemaV1](./Sources/SwiftCompartido/Schemas/SwiftCompartidoSchemaV1.swift)** - V1 baseline schema (complete production snapshot)
- **[SwiftCompartidoSchemaV2](./Sources/SwiftCompartido/Schemas/SwiftCompartidoSchemaV2.swift)** - V2 schema with glosa fields (complete production snapshot)
- **[MigrationTests](./Tests/SwiftCompartidoTests/MigrationTests.swift)** - Comprehensive migration test suite (9 tests covering all models)

**CRITICAL**: Versioned schemas must mirror **every stored property** from production models to prevent data loss during migration. See [SwiftCompartidoSchemaV2](./Sources/SwiftCompartido/Schemas/SwiftCompartidoSchemaV2.swift) for details.

## Requirements

- **iOS**: 26.0+
- **macOS**: 26.0+
- **Swift**: 6.2+
- **Xcode**: 17.0+

## Testing

SwiftCompartido has **95%+ test coverage** with **480+ passing tests** organized into **5 test plans**:

- **UnitTests** - Fast unit tests (runs on every PR) ⚡️
  - Includes 45 rendering validation tests for industry-standard screenplay formatting
- **LongTests** - Integration tests (runs on weekends) 🔄
- **UITests** - SwiftUI view tests (manual or weekend) 🎨
- **PerformanceTests** - Benchmarks (non-blocking) 📊
- **AITests** - Apple Intelligence tests (manual only, requires Apple Intelligence enabled) 🤖

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
