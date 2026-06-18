# AGENTS.md

This file provides comprehensive documentation for AI agents working with the SwiftCompartido codebase.

**Current Version**: 7.1.0 (June 2026)

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

### Schema Versioning

SwiftCompartido uses SwiftData's `VersionedSchema` pattern for schema evolution. Consumer apps **must** include all schema versions in their `SchemaMigrationPlan` to ensure data migrations work correctly.

**Current Schema Version**: V2 (SwiftCompartido 7.0.5+)

**Schema Documentation**:
- [SwiftCompartidoSchemaV1](Sources/SwiftCompartido/Schemas/SwiftCompartidoSchemaV1.swift) - V1 baseline schema (complete production model snapshot)
- [SwiftCompartidoSchemaV2](Sources/SwiftCompartido/Schemas/SwiftCompartidoSchemaV2.swift) - V2 schema with glosa fields (complete production model snapshot)
- [MigrationTests](Tests/SwiftCompartidoTests/MigrationTests.swift) - Comprehensive migration test suite

**CRITICAL: Complete Model Mirroring**

All versioned schema models MUST mirror **every stored property** from their production counterparts. Missing fields cause **data loss** during migration because:
1. SwiftData creates the target schema with only declared fields
2. Migration copies only declared fields from source
3. **Undeclared fields are dropped as "not in schema"**

See [SwiftCompartidoSchemaV2](Sources/SwiftCompartido/Schemas/SwiftCompartidoSchemaV2.swift) for a detailed example of the data loss bug and fix.

**Migration History**:
- **V1** (baseline): SwiftCompartido ≤ 7.0.4 — Complete model snapshot without glosa fields (~640 lines)
- **V2** (current): SwiftCompartido ≥ 7.0.5 — Complete model snapshot with glosa annotation fields

**Required App Integration**:

Consumer apps that adopt SwiftCompartido v7.0.5+ must include both V1 and V2 in their `SchemaMigrationPlan`:

```swift
import SwiftData
import SwiftCompartido

enum MyAppMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    [
      SwiftCompartidoSchemaV1.self,
      SwiftCompartidoSchemaV2.self
    ]
  }

  static var stages: [MigrationStage] {
    [
      SwiftCompartidoSchemaV2.migrationStage
    ]
  }
}

// Use in ModelContainer initialization
let container = try ModelContainer(
  for: GuionDocumentModel.self, GuionElementModel.self, /* other models */,
  migrationPlan: MyAppMigrationPlan.self
)
```

**Migration Details**:
- **V1 → V2**: Lightweight migration adding five optional glosa fields to `GuionElementModel`
  - `glosaSpokenText: String?` — Notes-stripped dialogue text
  - `glosaBreathOffsets: [Int]?` — Unicode-scalar breath hint offsets
  - `glosaBreathStrengths: [String]?` — Breath strength values
  - `glosaInstruct: String?` — LLM performance direction
  - `glosaPausePoints: Data?` — Encoded pause point DTOs

All new fields default to `nil`, so existing data migrates without modification.

**Testing**: See `MigrationTests.swift` for migration verification patterns.

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

| Package | Purpose | Documentation |
|---------|---------|---------------|
| SwiftData | Model persistence | System framework |
| SwiftUI | UI framework | System framework |
| Foundation | Core utilities | System framework |
| UniformTypeIdentifiers | MIME type handling | System framework |
| PDFKit | PDF rendering | System framework |
| AVFoundation | Audio playback | System framework |
| **GlosaCore** (glosa-av) | **GLOSA screenplay annotation compiler** | **[Dependency Border](docs/glosa-av-dependency-border.md)** |

### GlosaCore Integration

SwiftCompartido uses **glosa-av's GlosaCore** to annotate screenplay dialogue with performance direction (instruct strings) and phrasing/pause seam points.

**API Surface**: Single boundary function `compileAnnotations(fountainNotes:rawDialogueLines:)` returns `[Int: GlosaLineAnnotation]` DTOs.

**Integration Point**: `DocumentModelActor.annotateGlosa(document:)` calls GlosaCore during screenplay import and persists results to five optional fields on `GuionElementModel`:
- `glosaSpokenText: String?` - Notes-stripped dialogue text
- `glosaBreathOffsets: [Int]?` - Phrasing hint offsets
- `glosaBreathStrengths: [String]?` - Breath strength values
- `glosaInstruct: String?` - LLM performance direction
- `glosaPausePoints: Data?` - JSON-encoded pause points

**Graceful Degradation**: Glosa annotation failure never aborts screenplay import; all glosa fields default to `nil` on error.

**Full Specification**: See [glosa-av Dependency Border](docs/glosa-av-dependency-border.md) for complete API contract, data flow, and offset conventions.

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

## Cast Management

**Deprecated**: SwiftCompartido no longer handles cast management via custom-pages.json files.

### Current Approach (Deprecated)

`CastListPage` is kept for Highland .textbundle compatibility only. This model is deprecated.

### Recommended Approach

Use **SwiftProyecto** for all cast management:

```swift
import SwiftProyecto

let discovery = ProjectDiscovery()
if let projectMd = discovery.findProjectMd(from: screenplayURL) {
    let cast = try discovery.readCast(from: projectMd)
}
```

See [SwiftProyecto documentation](https://github.com/intrusive-memory/SwiftProyecto) for details.

### Migration from custom-pages.json

If you have existing custom-pages.json files:
1. Convert cast data to PROJECT.md frontmatter (YAML format)
2. Use SwiftProyecto's `ProjectMarkdownParser` to read/write cast
3. Remove custom-pages.json files

**Breaking Changes**:
- Sidecar JSON loading removed (`loadCustomPagesForFile`, `tryLoadCustomPagesJSON`)
- Sidecar JSON writing removed (`writeCustomPagesSidecar`)
- Highland custom-pages loading removed (`loadCustomPages`)
- TextBundle custom-pages export removed (`writeCustomPagesJSON`)

## Version History

**7.0.5** (Current):
- Swift 6 concurrency: Fixed actor isolation errors in HierarchyBuilder
- Marked buildHierarchy parameters as `sending` for strict concurrency
- Disabled flaky Foundation Models PDF parsing tests

**7.0.4**:
- Memory telemetry instrumentation for MemoryManager
- Memory pressure event capture with system-wide stats
- CI concurrency control (one run per branch)
- SwiftFijos dependency updated to 1.4.1
- Improved GPU cache telemetry test robustness

**7.0.3**:
- Intermediate release (patch)

**7.0.2**:
- Fixed PDF progress bar not advancing during page-by-page parsing
- Extract PDF attributed strings for richer AI parsing context
- CI/CD updates: Disabled iOS tests and performance tests (macOS unit tests only)

**7.0.1**:
- Switch dependencies to main branch

**7.0.0**:
- Removed custom-pages.json sidecar support
- Deprecated CastListPage model (use SwiftProyecto for cast management)

**6.3.0**:
- Voice casting system for character-to-voice assignments
- CharacterVoiceMapping data model
- App Intents for Shortcuts automation (GetVoiceCasting, SetVoiceCasting)
- Support for multiple TTS providers (macOS, ElevenLabs, OpenAI)
- SwiftHablare integration ready

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
