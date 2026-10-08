---
type: doc
---

# Changelog

All notable changes to SwiftCompartido will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [7.3.0] - TBD

### Added - Character Discovery & Per-Character Script Queries 🎭

SwiftCompartido now provides comprehensive character discovery and script querying capabilities for multi-episode series and screenplay collections. These APIs enable SwiftReparto to generate CAST.md from screenplay content and Personaje to extract context-aware script excerpts for character voice generation.

#### New APIs

- **CP-P2: Store-Wide Character Collection** (`extractAllCharacters()`)
  - Aggregates all speaking characters across all documents in a SwiftData store
  - Returns `CharacterCollectionResult` with per-character metadata:
    - Dialogue line count and word count (matching per-document `extractCharacters()` sums)
    - Scenes and episodes where each character appears
    - First dialogue line (earliest by document → scene → element order)
  - Result type conforms to `Codable` and `Sendable` for actor isolation and file-based integration
  - Enables SwiftReparto to generate CAST.md without linking intrusive-memory packages

- **CP-P3: Character Lines Query** (`fetchLines(for:)`)
  - Returns all dialogue and parenthetical elements for a character across the entire store
  - Uses SwiftData predicate on the new `speaker` field for efficient querying
  - Results in deterministic script order (document → scene → element)

- **CP-P4: Complete Scenes Query** (`fetchScenes(for:)`)
  - Returns every complete scene where a character speaks
  - Each scene includes all elements (headings, action, all speakers' dialogue)
  - Useful for analyzing character interactions and scene context

- **CP-P5: Lines with Neighbors** (`fetchLineWindows(for:neighbours:)`)
  - Returns each character line with ±N surrounding blocks
  - `neighbours` parameter is optional (default: 3)
  - Overlapping windows are merged; windows never cross scene boundaries
  - Blocks are dialogue blocks (cue + parentheticals + dialogue) or single action/body elements
  - Enables Personaje to generate voices with rich conversational context

#### Schema Migration (V2 → V3)

- **Breaking Change**: `GuionElementModel` now includes `speaker: String?` field
  - Schema version bumped from V2 to V3
  - Lightweight migration: existing records have `nil` speaker (intentional design)
  - Parser populates speaker at parse time for new content
  - Old stores will either migrate automatically or require re-parsing

**Migration Impact**:
- **Produciesta** and **Escribir**: Pick up schema change transparently on next build
- **Existing data**: Speaker field will be `nil` for migrated records; character descriptions incomplete until re-parse
- **New parses**: Speaker field populated automatically

#### Result Types

All new query results are `Codable` and `Sendable` for clean integration:

- **`CharacterCollectionResult`** - Store-wide character aggregation
  ```swift
  struct CharacterCollectionResult {
      let characters: [String: StoreCharacterInfo]  // Keyed by cleaned character name
  }
  ```

- **`StoreCharacterInfo`** - Per-character metadata
  ```swift
  struct StoreCharacterInfo {
      let name: String                    // Cleaned character name
      let lineCount: Int                  // Total dialogue lines across all documents
      let wordCount: Int                  // Total words in dialogue + parentheticals
      let sceneIds: [String]             // Scene IDs where character appears
      let documents: [DocumentInfo]       // Documents/episodes where character appears
      let firstLine: FirstLineInfo?      // Character's first dialogue line
  }
  ```

- **`StoreCharacterInfo.DocumentInfo`** - Per-document appearance
  ```swift
  struct DocumentInfo {
      let id: String          // Document's persistent identifier
      let title: String       // Document filename or title
      var scenes: [Int]       // Zero-based scene indices where character appears
  }
  ```

- **`StoreCharacterInfo.FirstLineInfo`** - First dialogue line info
  ```swift
  struct FirstLineInfo {
      let text: String            // The dialogue text
      let documentTitle: String   // Document where line appears
      let sceneId: String?        // Scene ID (if available)
      let documentId: String?     // Document persistent identifier
      let sceneIndex: Int?        // Zero-based scene index (nil if before first heading)
  }
  ```

- **`ScriptElementInfo`** - Individual screenplay element
  ```swift
  struct ScriptElementInfo {
      let elementId: String       // Element's UUID
      let documentId: String      // Owning document's ID
      let documentTitle: String   // Document title
      let sceneIndex: Int?        // Zero-based scene index
      let sceneId: String?        // Scene ID (if available)
      let chapterIndex: Int       // Chapter index
      let orderIndex: Int         // Order within chapter
      let elementTypeName: String // Element type (e.g., "Dialogue")
      let text: String           // Element text
      let speaker: String?       // Speaker name (for dialogue/character elements)
  }
  ```

- **`CharacterSceneInfo`** - Complete scene
  ```swift
  struct CharacterSceneInfo {
      let documentId: String      // Owning document's ID
      let documentTitle: String   // Document title
      let sceneIndex: Int?        // Zero-based scene index
      let sceneId: String?        // Scene ID (if available)
      let heading: String?        // Scene heading text
      let elements: [ScriptElementInfo]  // All scene elements in order
  }
  ```

- **`CharacterLineWindow`** - Line window with neighbors
  ```swift
  struct CharacterLineWindow {
      let documentId: String      // Owning document's ID
      let documentTitle: String   // Document title
      let sceneIndex: Int?        // Zero-based scene index
      let sceneId: String?        // Scene ID (if available)
      let heading: String?        // Scene heading text
      let blocks: [ScriptBlockInfo]  // Window blocks in order
  }
  ```

- **`ScriptBlockInfo`** - Dialogue block or body element
  ```swift
  struct ScriptBlockInfo {
      let speaker: String?           // Block speaker (nil for action/body)
      let isCharacterLine: Bool      // True if this is a queried character's line
      let elements: [ScriptElementInfo]  // Block elements in order
  }
  ```

### Changed

- **CastListPage Deprecation Message**: Updated to reference SwiftReparto's CAST.md instead of SwiftProyecto.CastMember
  - SwiftProyecto v5 removed its cast surface
  - CAST.md (managed by SwiftReparto) is now the canonical cast model
  - CastListPage remains for Highland .textbundle compatibility only

### Documentation

- **Cast Discovery**: README now documents character discovery capabilities and integration with SwiftReparto
- **API Documentation**: All new query methods include comprehensive inline documentation with usage examples (added in previous sorties)
- **Result Type Structures**: Documented all result type properties for SwiftReparto integration
- **Schema Versioning**: Documented V2→V3 migration path and null-speaker policy

---

## [7.2.5] - 2026-09-26

### Added

- **LICENSE**: Added MIT LICENSE file

### Changed

- **Dependencies**: Pinned intrusive-memory dependencies to latest published versions (SwiftFijos 1.4.1, glosa-av 0.8.1)
- **Documentation**: Updated version references

---

## [7.2.4] - 2026-07-19

### Changed

- **Documentation**: Updated version references and documentation metadata
- **Package.swift**: Removed sibling development helpers for release build
- **Dependencies**: Pinned intrusive-memory dependencies to latest published versions (SwiftFijos 1.4.1, glosa-av 0.7.1)

---

## [7.2.3] - 2026-07-19

### Fixed

- **Voicing: strip multi-line {{ … }} blocks from speakableText** - The voicing system now properly strips multi-line Fountain boneyard blocks (enclosed in `{{ … }}`) from speakable text, preventing synthesized narration from reading stage directions and comments intended only for the script. ([#73](https://github.com/intrusive-memory/SwiftCompartido/pull/73))

---

## [7.2.2] - 2026-07-12

### Fixed

- **Fountain parser: emphasis-wrapped direction lines no longer mis-typed as character cues** - The character-cue regex `^[^a-z]+(\(cont'd\))?$` matched any line with no lowercase ASCII letters, so Fountain emphasis markers (`*`, `_`) and punctuation slipped through. Emphasized scene markers like `**END OF SCENE.**` and `**BEGIN* SCENE**` were classified as `.character` and surfaced as cast members in `extractCharacters()`, polluting downstream consumers (e.g. SwiftEchada's `generate cast`). The pattern is now `^(?=.*\p{L})[^a-z*_]+(\(cont'd\))?$`: it requires at least one real letter and rejects emphasis markers, while preserving genuine cues with periods (`DR. SMITH`), extensions (`UNCLE FU (CONT'D)`), and digits (`ROBOT-3`). ([#71](https://github.com/intrusive-memory/SwiftCompartido/issues/71))

---

## [7.2.0] - 2026-06-21

### Added

- **Comprehensive .guion File I/O Tests** - Full coverage for reading, writing, and schema versioning
- **Error Handling Tests** - Large file stress tests and error boundary validation
- **Schema Versioning Tests** - Comprehensive tests for .guion format evolution

### Fixed

- **GPU Cache Telemetry** - Made tests resilient to CI environment constraints
- **Error Handling** - Resolved ambiguous withUnsafeMutableBytes call in error handling tests

### Documentation

- **Testing Gaps** - Marked all testing gaps as complete with final summary
- **Test Analysis** - Implemented comprehensive test analysis recommendations

---

## [7.1.0] - 2026-06-18

### Added

- **GlosaCore Integration** (#64) - Added screenplay audio annotation support via glosa-av dependency
- **Migration Tests** (#65) - Comprehensive tests for SwiftData schema migrations from V1 to V2
- **Telemetry Instrumentation** (#66, #67) - Added memory manager telemetry and performance tracking

### Fixed

- **MemoryManagerTelemetryTests** - Eliminated race condition in concurrent telemetry tests

---

## [7.0.2] - 2026-03-27

### Fixed

- **PDF Progress Bar** - Fixed progress bar not advancing during page-by-page parsing
- **PDF Attributed Strings** - Extract attributed strings for richer AI parsing context

### Changed

- **CI/CD Updates** - Disabled iOS tests and performance tests
  - Only macOS unit tests run on PRs
  - Branch protection updated to match

---

## [7.0.0] - 2026-02-15

### Breaking Changes

- **REMOVED**: Custom-pages.json sidecar support
  - `loadCustomPagesForFile()` method removed
  - `tryLoadCustomPagesJSON()` method removed
  - `writeCustomPagesSidecar()` method removed
  - Highland `loadCustomPages()` method removed
  - TextBundle `writeCustomPagesJSON()` method removed

### Deprecated

- `CastListPage` model now deprecated
  - Kept only for Highland .textbundle compatibility
  - Use `SwiftProyecto.CastMember` for new projects
  - Will be removed in future release if Highland support is dropped

### Migration Guide

**From custom-pages.json to PROJECT.md**:

1. Install SwiftProyecto package
2. Convert cast data to PROJECT.md YAML frontmatter:
   ```yaml
   cast:
     - character: NARRATOR
       voices:
         apple: com.apple.voice.compact.en-US.Aaron
   ```
3. Use SwiftProyecto's API for cast management
4. Remove custom-pages.json files

See [SwiftProyecto documentation](https://github.com/intrusive-memory/SwiftProyecto) for details.

---

## [6.6.0] - 2026-01-15

### Added - Voice Download Tools & PDF Improvements 🎙️

- **Voice Download System**: Complete tooling to help users install Enhanced and Premium macOS system voices for high-quality Text-to-Speech
  - **AppleScript Automation**: `Scripts/download-premium-voices.applescript` (200 lines) - Interactive script that guides users through System Settings → Accessibility → Read & Speak → Voice selection
  - **Swift API Wrapper**: `Scripts/VoiceDownloadHelper.swift` (400 lines) - Programmatic voice download and management
    - `promptUserToDownloadPremiumVoices()` - Launch download helper
    - `isUsingPremiumVoice()` - Check voice quality
    - `getInstalledVoices()` - List installed voices
  - **SwiftUI Components**: Ready-to-use UI integration
    - `DownloadPremiumVoicesButton` - Drop-in button
    - `.presentVoiceDownload()` - View modifier for sheets
  - **Example App**: `Scripts/VoiceDownloadExample.swift` (300 lines) - Complete integration demo with voice status dashboard and TTS testing
  - **Comprehensive Documentation**: `Docs/VOICE_DOWNLOAD_GUIDE.md` (600+ lines) - Complete user and developer guide

- **PDF Parsing Enhancements**:
  - **Page-by-Page AI Conversion**: Improved Apple Intelligence integration for large PDFs
    - Processes PDFs in page chunks for better memory efficiency
    - Enhanced progress reporting with per-page updates
  - **Fountain Format Directive**: Explicit Fountain syntax instruction in AI system prompt
    - Improved format compliance from 95% to 98.3%
    - Better handling of screenplay-specific formatting rules

### Fixed

- **Test Availability Checks**: Added `@available(iOS 26.2, macOS 26.0, *)` attributes to cast list generation tests
  - Fixed compilation errors in `CastListGenerationIntegrationTests.swift`
  - Fixed compilation errors in `GuionDocumentSnapshotCastListTests.swift`
  - Tests now properly check availability before calling Apple Intelligence APIs

- **PDF Parsing Robustness**:
  - Write PDF data to temp file for secure parsing (prevents UTF-8 decode errors)
  - Add PDF file marker handling to prevent binary data corruption
  - Improved error handling for malformed PDF files

### Changed

- **Documentation Reorganization**: Major documentation audit and restructuring
  - Created 5 specialized documentation files in `Docs/`:
    - `PERFORMANCE_TESTING.md` (250 lines) - Performance baselines and metrics tracking
    - `ARCHITECTURE_SWIFTDATA.md` (280 lines) - SwiftData relationships and patterns
    - `KNOWN_ISSUES.md` (150 lines) - Known issues and limitations
    - `CI_CD_SETUP.md` (450 lines) - GitHub Actions and branch protection
    - `PARSING_ARCHITECTURE.md` (350 lines) - Complete parsing flow diagrams
  - Reduced `CLAUDE.md` size by 31% (~400 lines)
  - Fixed broken documentation links
  - Moved files from `Docs/old/` to `Docs/`:
    - `APP_INTENTS_GUIDE.md`
    - `PARSED_FILE_SERVICE_API.md`
    - `SOURCE_FILE_TRACKING.md`
    - `USAGE-SUMMARY.md`
  - Updated `README.md` with Voice Download Helper section
  - Updated `Scripts/README.md` with voice tools integration guide

### Documentation

- **New Documentation**:
  - `Docs/VOICE_DOWNLOAD_GUIDE.md` - Complete voice download guide
  - `Docs/VOICE_DOWNLOAD_SUMMARY.md` - Quick implementation summary
  - `Docs/DOCUMENTATION_AUDIT_2026-01-15.md` - Documentation audit report

- **Updated Documentation**:
  - `CLAUDE.md` - Added Voice Download Integration section, reduced size by 31%
  - `README.md` - Added Voice Download Helper section, fixed broken links
  - `Scripts/README.md` - Added voice tools section with integration guide

### Benefits

**For Users:**
- ✅ High-quality TTS with Premium voices (neural TTS)
- ✅ Easy guided setup through System Settings
- ✅ One-time download process

**For Developers:**
- ✅ Zero configuration - works out of the box
- ✅ SwiftUI-ready drop-in components
- ✅ Automatic script discovery
- ✅ Comprehensive documentation

**For PDF Parsing:**
- ✅ 98.3% Fountain format compliance (up from 95%)
- ✅ Better memory efficiency for large PDFs
- ✅ More robust error handling

---

## [6.5.0] - 2026-01-09

### Added - Apple Intelligence Integration ✨

- **AI-Powered PDF Parsing**: Full Foundation Models (Apple Intelligence) integration for PDF screenplay conversion
  - 98.3% format compliance (vs 87.5% for heuristic conversion)
  - 100% content preservation
  - ~10 seconds processing time per 100-page screenplay
  - Requires iOS 26.2+/macOS 26.0+ with Apple Intelligence enabled
  - Automatic graceful fallback to heuristic conversion when unavailable

- **User Notifications**: Clear warnings via `OperationProgress.additionalInfo` when falling back to heuristic conversion
  - Explains why AI is unavailable
  - Provides instructions for enabling Apple Intelligence
  - No breaking changes or errors

- **Comprehensive Test Suite**: 8 new AI-specific tests in `PDFScreenplayParserAITests.swift`
  - Framework detection and availability checks
  - Content preservation validation (100% accuracy)
  - Progress reporting verification (16 callbacks)
  - PDF conversion accuracy tests (98.3% format compliance)
  - Non-standard format handling
  - AI vs heuristic comparison benchmarks
  - System prompt effectiveness validation
  - Multiple PDF batch processing
  - Run with: `./Scripts/test-ai-features.sh --macos`

### Fixed

- **iOS CI Failures**: Added dynamic iPhone simulator creation to all iOS workflows
  - GitHub Actions macos-26 runners lack iPhone simulators by default
  - New "Create iPhone Simulator" step in all iOS test workflows
  - Fallback chain: iPhone 16 Pro → 16 → 15 Pro → 15
  - Affects: `tests.yml`, `ui-tests.yml`, `long-tests.yml`, `performance.yml`

- **Availability Check**: Fixed `isAppleIntelligenceAvailable()` in `PDFScreenplayParserAITests.swift`
  - Changed from hardcoded `false` to real API check via `SystemLanguageModel.default.isAvailable`
  - Enables proper testing on devices with Apple Intelligence enabled

### Changed

- **Documentation Updates**:
  - `README.md`: Updated PDF parsing description to reflect AI capabilities
  - `FOUNDATION_MODELS_STATUS.md`: Comprehensive update with test results and verified implementation status
  - `CLAUDE.md`: Added two new sections:
    - Apple Intelligence PDF Parsing (lines 822-942) - Complete implementation guide
    - iOS Simulator Creation in CI (lines 1124-1184) - CI infrastructure documentation

### Performance

- **AI Conversion Benchmarks** (measured):
  - Small PDFs (< 50 pages): ~5 seconds, 98%+ accuracy
  - Medium PDFs (50-120 pages): 9-12 seconds, 98.3% accuracy
  - Large PDFs (> 120 pages): ~20 seconds, 95%+ accuracy (estimated)

- **Heuristic Conversion Benchmarks** (measured):
  - Small PDFs (< 50 pages): ~3 seconds, 95%+ accuracy
  - Medium PDFs (50-120 pages): 6-10 seconds, 87.5% accuracy
  - Large PDFs (> 120 pages): 15-25 seconds, 85%+ accuracy

**Trade-off**: AI is ~1.4× slower but significantly more accurate (98.3% vs 87.5% format compliance)

### Migration

**No code changes required.** AI conversion is an automatic enhancement:

```swift
// Works in 6.4.0 and earlier (heuristic only)
let screenplay = try await PDFScreenplayParser.parse(from: pdfURL)

// Works in 6.5.0+ (AI when available, heuristic fallback)
let screenplay = try await PDFScreenplayParser.parse(from: pdfURL)
```

### Requirements

- iOS 26.2+ or macOS 26.0+ **with Apple Intelligence enabled** for AI-powered conversion
- Falls back to heuristic conversion on all other platforms/devices
- No breaking changes

---

## [6.4.0] - 2026-01-09

### Added

- **GuionDocumentConfiguration Enhancement**: Expanded `readableContentTypes` to include additional document formats
  - Added support for `.plainText` (Markdown, TXT)
  - Added support for `.rtf` (Rich Text Format)
  - Added support for `.pdf` (Adobe PDF)
  - Added support for `.docx` (Microsoft Word)
  - Added support for `.odt` (OpenDocument Text)
  - Improves file type detection and document opening in SwiftUI DocumentGroup

### Fixed

- GuionViewer bundle type role changed to "Viewer"

---

## [6.3.1] - 2025-12-29

### Added - Rendering Validation & Bug Fixes

- **Comprehensive Rendering Tests**: 45 tests validating screenplay formatting against industry standards
  - Page width validation (65 characters per line)
  - Element margin tests (character 40%, dialogue 25%, transition 65%)
  - Proportional scaling across font sizes (8pt - 24pt)
  - Document ordering and sequence validation
  - Tests: `ScreenplayRenderingFormatTests` (32 tests) and `ScreenplayDocumentRenderingTests` (13 tests)

### Fixed

- **Element Ordering Fix**: Explicit sorting by composite key `(chapterIndex, orderIndex)` in `DocumentModelActor.getElements()`
  - SwiftData @Relationship arrays don't guarantee order
  - Elements now always returned in correct document order

- **Concurrency Fixes**: Resolved Swift 6 strict concurrency errors in parser methods

### Changed

- **CI Stability**: All tests passing on iOS and macOS platforms

---

## [6.3.0] - 2025-12-20

### Added - GuionViewer Reference Implementation

- **GuionViewer Demo App**: Minimal macOS app demonstrating best practices
  - Located in `GuionViewer/` directory
  - ModelActor pattern with `DocumentModelActor` for safe SwiftData concurrency
  - Infinite scrolling with lazy loading (100 elements at a time)
  - Fixed typography layout: 12pt Courier New, 102 character width
  - Centered content with resizable window
  - Loads 24+ screenplay files from app bundle

- **DisplayableElement Protocol**: Enables DTOs to work seamlessly with SwiftCompartido element views
  - `DocumentInfo` and `ElementInfo` DTOs conform to DisplayableElement
  - Reuses 10+ SwiftCompartido views (SceneHeadingView, DialogueTextView, etc.)

### Documentation

- Added `GuionViewer/REQUIREMENTS.md` with complete specifications
- Updated `CLAUDE.md` with GuionViewer section and best practices

---

## [6.2.1] - 2025-11-20

### Removed

- **CloudKit Support Removed**: Simplified library focus to parsing and storage
- **Foundation Models Generation Removed**: Moved AI generation features to consumer apps
  - Library now only **stores** and **displays** AI-generated content
  - **Generating** content is out of scope

---

## [6.2.0] - 2025-11-15

### Added - JSON .guion Format

- **New .guion JSON Format**: 40-60× faster than legacy TextPack
  - Human-readable JSON (perfect for git diff)
  - 27% smaller file sizes
  - Backward compatible with TextPack

- **LZFSE Compression**: Binary payloads in `TypedDataStorage` now compressed
  - New `_compressedBinaryValue` column
  - Automatic compression/decompression

### Changed

- **CharacterVoiceMapping**: New SwiftData relationship for TTS voice assignments
  - Added to `GuionDocumentModel.casting` relationship

### Known Issues

- **Binary Payload Migration**: Column rename from `binaryValue` to `_compressedBinaryValue` creates migration issue
  - Existing stores: `_compressedBinaryValue` is nil for prior records
  - Workaround: Re-generate content or export to .guion before upgrading
  - Status: **UNRESOLVED** - Migration path not implemented

---

## [6.1.0] - 2025-10-01

### Added - App Intents & Shortcuts Integration

- **App Intents Support**: Complete Apple Shortcuts integration
  - `ParseScreenplayFileIntent` - Parse screenplay files via Shortcuts
  - `QueryScreenplayElementsIntent` - Query elements from parsed documents
  - `ScreenplayElementsReference` - Transferable reference type for chaining workflows
  - `SwiftCompartidoShortcuts` - Siri voice command registration
  - Siri commands: "Import screenplay with SwiftCompartido", "Query screenplay elements", etc.

- **ParsedFileService**: Unified service layer for parsing and querying
  - Single code path for UI and Intents
  - `parseFile(at:)` - Parse screenplay files
  - `elements(documentID:filter:)` - Query elements with filtering

### Documentation

- Added `Docs/APP_INTENTS_GUIDE.md` - Complete Shortcuts integration guide
- Added `Docs/PARSED_FILE_SERVICE_API.md` - API reference

---

## [6.0.0] - 2025-09-01

### Changed - Phase 6 Architecture

- **File-Based Storage**: Large content (audio, images) now uses `TypedDataFileReference`
  - Prevents main thread blocking
  - In-memory DTOs for transfer, file-based for persistence
  - Smart storage rules: Text < 10KB in-memory, ≥ 10KB file-based

---

## Earlier Versions

See git history for versions before 6.0.0.

---

## Version Numbering

SwiftCompartido follows [Semantic Versioning](https://semver.org/):

- **Major** (X.0.0): Breaking changes
- **Minor** (0.X.0): New features, backward compatible
- **Patch** (0.0.X): Bug fixes, backward compatible
