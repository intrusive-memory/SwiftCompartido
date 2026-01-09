# Changelog

All notable changes to SwiftCompartido will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

- GuionDocument update (exact changes TBD)

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
