# AGENTS.md

This file provides comprehensive documentation for AI agents working with the SwiftCompartido codebase.

**Current Version**: 6.6.0 (February 2026)

---

## Project Overview

SwiftCompartido is a Swift package for screenplay management and AI-generated content storage built with SwiftData and SwiftUI.

**Architecture**: Phase 6 - file-based storage pattern that separates in-memory DTOs from file-persisted content to prevent main thread blocking.

## Core Missions

SwiftCompartido has **exactly TWO core missions**. Every feature must directly support one of these:

### Mission 1: Parsing & Storage
Parse and store screenplay documents and AI-generated content

**Includes**:
- Screenplay parsers (Fountain, FDX, PDF, Markdown, Highland, TextBundle, Pandoc)
- SwiftData models (GuionDocumentModel, GuionElementModel, TypedDataStorage, CharacterVoiceMapping)
- Storage infrastructure (TypedDataFileReference, StorageAreaReference, Phase 6 architecture)
- Serialization (JSON .guion format, TextPack, snapshots)
- MIME type routing and content type handling
- File I/O with progress reporting

### Mission 2: UI Display
Display screenplay documents and AI-generated content with SwiftUI widgets

**Includes**:
- Screenplay viewers (GuionTextEditor, GuionViewer, GuionElementsList)
- TypedDataStorage display (GeneratedContentListView, TypedDataDetailView, TypedDataRowView)
- Element widgets (ElementProgressBar, ElementProgressState, ElementProgressTracker)
- Audio playback UI (AudioPlayerManager with waveform visualization)
- Configuration UI (AppleTTSVoiceProviderPane, TextConfigurationView)
- Query-based list widgets with filtering and grouping

### What Does NOT Belong

❌ **AI Content Generation** - Text/TTS/image/embedding generation (external services)
❌ **Cloud Sync** - CloudKit, Firebase, iCloud (removed in 6.2.1)
❌ **External Service Integration** - API clients, service wrappers
❌ **Business Logic** - Workflow orchestration, state machines (belongs in consumer apps)

✅ **Exception**: Foundation Models PDF parsing uses on-device Apple Intelligence for enhanced accuracy (98%+)

## Project Structure

```
SwiftCompartido/
├── Sources/SwiftCompartido/
│   ├── Parsers/              # Screenplay format parsers
│   │   ├── Fountain/         # Fountain (.fountain) parsing
│   │   ├── FDX/             # Final Draft (.fdx) XML parsing
│   │   ├── PDF/             # PDF parsing (AI + heuristic)
│   │   ├── Markdown/        # Markdown (.md) with YAML front matter
│   │   ├── Highland/        # Highland (.highland) ZIP archives
│   │   └── TextBundle/      # TextBundle (.textbundle) containers
│   ├── Models/              # SwiftData models
│   │   ├── GuionDocumentModel.swift
│   │   ├── GuionElementModel.swift
│   │   └── TypedDataStorage.swift
│   ├── Storage/             # Phase 6 file storage
│   │   ├── TypedDataFileReference.swift
│   │   └── StorageAreaReference.swift
│   ├── Views/               # SwiftUI display components
│   │   ├── Elements/        # Element-specific views (SceneHeadingView, DialogueTextView, etc.)
│   │   ├── Viewers/         # GuionTextEditor, GuionViewer
│   │   └── Content/         # TypedDataStorage display views
│   └── Actors/              # DocumentModelActor for safe concurrency
├── GuionViewer/             # Reference implementation macOS app
└── Tests/
    └── SwiftCompartidoTests/
```

## Key Components

### Parsers

| Format | Extension | Parser | Accuracy |
|--------|-----------|--------|----------|
| Fountain | `.fountain` | Native | 100% |
| Final Draft | `.fdx` | XML | 99%+ |
| PDF | `.pdf` | AI + Heuristic | 98%+ (AI), 95%+ (Heuristic) |
| Markdown | `.md` | YAML front matter | 100% |
| Highland | `.highland` | ZIP with Fountain | 100% |
| TextBundle | `.textbundle` | Auto-detection | 100% |
| Pandoc | `.docx`, `.odt`, `.rtf` | Document conversion (macOS only) | 95%+ |

### SwiftData Models

| Model | Purpose |
|-------|---------|
| `GuionDocumentModel` | Top-level screenplay document with metadata |
| `GuionElementModel` | Individual screenplay elements (scene headings, dialogue, action, etc.) |
| `TypedDataStorage` | Unified storage for AI-generated content (text, audio, images, embeddings) |
| `CharacterVoiceMapping` | Character-to-voice associations |

### Display Components

| Component | Purpose |
|-----------|---------|
| `GuionTextEditor` | TextKit 2-based editor (400-1600x faster than legacy) |
| `GuionViewer` | Reference screenplay viewer implementation |
| `SceneHeadingView`, `DialogueTextView`, `ActionView`, etc. | Element-specific display views (12+ types) |
| `GeneratedContentListView` | TypedDataStorage browser |
| `TypedDataDetailView`, `TypedDataRowView` | Content detail and row displays |
| `AudioPlayerManager` | Audio playback with waveform visualization |

## Dependencies

| Package | Purpose |
|---------|---------|
| SwiftData | Model persistence |
| SwiftUI | UI framework |
| Foundation | Core utilities |
| UniformTypeIdentifiers | MIME type handling |
| PDFKit | PDF rendering |
| AVFoundation | Audio playback |

## Build and Test

**CRITICAL**: Use `xcodebuild` for all builds and tests. This library requires SwiftData and SwiftUI which work best with Xcode's build system.

```bash
# Build library
xcodebuild build -scheme SwiftCompartido -destination 'platform=macOS'

# Run tests
xcodebuild test -scheme SwiftCompartido -destination 'platform=macOS'

# Build GuionViewer reference app
cd GuionViewer
xcodebuild build -scheme GuionViewer -destination 'platform=macOS'
open ~/Library/Developer/Xcode/DerivedData/GuionViewer-*/Build/Products/Debug/GuionViewer.app
```

## Platform Requirements

**CRITICAL**: iOS 26.0+ and macOS 26.0+ ONLY. NEVER add code for older platforms.

- **iOS 26.0+**
- **macOS 26.0+**
- **Swift 6.2+**
- **NEVER add `@available` attributes** for versions below iOS 26/macOS 26

## GuionViewer Reference Implementation

**Location**: `GuionViewer/` (repository root)

GuionViewer is a minimal macOS demo app demonstrating best practices for integrating SwiftCompartido.

### Architecture Highlights

1. **ModelActor Pattern**: `DocumentModelActor` for all SwiftData operations
   - Actor isolation prevents data races
   - Returns Sendable DTOs (`DocumentInfo`, `ElementInfo`) to MainActor
   - Never passes Model instances across actor boundaries

2. **Infinite Scrolling**: Lazy-loads screenplay elements in batches
   - Starts with 100 elements, loads 100 more on scroll
   - Uses `LazyVStack` for performance

3. **Fixed Typography Layout**:
   - Fixed 12pt Courier New (industry standard)
   - 102 character width (8.5" page equivalent)
   - Content centered in window (734.4pt width)

4. **Component Reuse**: Uses SwiftCompartido element views via `DisplayableElement` protocol

5. **Bundle Resource Loading**: Dual-mode file discovery (built app bundle vs. development)

### Usage Example

```swift
// Initialize DocumentModelActor
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

## Phase 6 Architecture

**File-based storage pattern** that separates in-memory DTOs from file-persisted content.

### Key Principles

1. **Small data in-memory**: Text, metadata stored directly in SwiftData
2. **Large data on disk**: Audio, images, embeddings stored as files with references
3. **DTO pattern**: Models return Sendable DTOs, never pass Model instances across actors
4. **Explicit sorting**: Elements always returned in document order
5. **Progress reporting**: All file operations report progress for UI updates

### Storage Hierarchy

```
TypedDataStorage (SwiftData model)
  └─> TypedDataFileReference (optional, for large content)
       └─> StorageAreaReference (file location)
            └─> Actual file on disk
```

## Design Patterns

- **Actor isolation**: All SwiftData operations through `DocumentModelActor`
- **DTO pattern**: Sendable transfer objects cross actor boundaries
- **DisplayableElement protocol**: Enables DTOs to work with element views
- **Lazy loading**: Batch loading for performance (100 elements at a time)
- **MIME type routing**: Automatic parser selection based on file type
- **Progress reporting**: Async sequences for file I/O progress

## Development Workflow

- **Branch**: `development` → PR → `main`
- **CI Required**: Tests must pass before merge
- **Never commit directly to `main`**
- **Platforms**: iOS 26+, macOS 26+ only (no backward compatibility)

## Testing

- **Unit tests**: Parser accuracy, model integrity, storage operations
- **Rendering validation**: 45 tests ensuring industry-standard screenplay formatting
- **Performance tests**: Large document handling (5000+ elements)
- **Integration tests**: GuionViewer reference app

## Supported Screenplay Elements

- Scene Heading (INT./EXT./EST./I/E.)
- Action
- Dialogue (Character, Parenthetical, Dialogue)
- Transition
- Shot
- Page Break
- Section Heading
- Synopsis
- Note
- Boneyard (omitted content)
- Centered Text
- Lyrics

## Version History

**6.6.0** (Current):
- Voice download tools (AppleScript automation)
- PDF parsing improvements (98.3% accuracy)
- Documentation reorganization
- AI cast list generation
- Rendering validation tests
- GuionViewer reference app

See [CHANGELOG.md](./CHANGELOG.md) for complete version history.

## Decision Framework

When adding or modifying code:

1. **Does this parse or store screenplay/content data?** → Mission 1 ✅
2. **Does this display screenplay/content data in SwiftUI?** → Mission 2 ✅
3. **Does this support parsing, storage, or display?** (file I/O, MIME routing, progress) → OK ✅
4. **Otherwise** → **REMOVE IT** ❌

## Important Files

| File | Purpose |
|------|---------|
| `GuionParsedElementCollection.swift` | Main parsing entry point |
| `GuionDocumentParserSwiftData.swift` | SwiftData conversion |
| `DocumentModelActor.swift` | Safe concurrency for SwiftData |
| `GuionTextEditor.swift` | High-performance TextKit 2 editor |
| `DisplayableElement.swift` | Protocol enabling DTO use with views |
| `TypedDataStorage.swift` | AI content storage model |
| `GuionViewer/ContentView.swift` | Reference implementation UI |
