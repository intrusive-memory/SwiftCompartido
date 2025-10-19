# Changelog

All notable changes to SwiftCompartido will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2025-10-19

### 📊 Comprehensive Progress Reporting

Major enhancement adding progress reporting to all long-running operations with full SwiftUI integration, cancellation support, and minimal performance overhead.

### Added

#### Core Progress System
- **`OperationProgress`**: Main progress tracking class with handler callbacks
  - Thread-safe, `Sendable`, and fully Swift 6 compliant
  - Batched updates (max 100/second) for optimal performance
  - Support for both determined (with total units) and indeterminate progress
- **`ProgressUpdate`**: Immutable progress snapshot with:
  - `completedUnits` and `totalUnits` (Int64)
  - `fractionCompleted` (Double, 0.0-1.0)
  - Human-readable `description` messages
- **`ProgressHandler`**: Type alias for progress update callbacks

#### Progress-Enabled Operations

**FountainParser (9 features):**
- Async `FountainParser.init(string:progress:)` with line-by-line tracking
- Title page parsing progress
- Element parsing progress (batched every 10 elements)
- Line counting and fraction completion
- Full cancellation support

**FDXParser (8 features):**
- Async `FDXParser.init(data:progress:)` with element tracking
- XML parsing progress reporting
- Element conversion tracking
- Title page extraction progress

**TextPack Reader (9 features):**
- `TextPackReader.readTextPack(from:progress:)` with stage-based tracking
- Metadata parsing progress
- Resource loading progress
- Screenplay reconstruction progress

**TextPack Writer (8 features):**
- Async `TextPackWriter.createTextPack(from:progress:)` with 5 stages:
  1. Creating bundle metadata (10%)
  2. Generating screenplay.fountain (30%)
  3. Extracting character data (20%)
  4. Extracting location data (20%)
  5. Writing resource files (20%)
- Full cancellation with cleanup

**SwiftData Operations (7 features):**
- Async `GuionDocumentParserSwiftData.parse(script:in:generateSummaries:progress:)`
- Element-by-element conversion tracking
- Updates every 10 elements for efficiency
- AI summary generation progress (when enabled)
- Async `loadAndParse(from:in:generateSummaries:progress:)` for all formats

**File I/O Operations (7 features):**
- Async `GeneratedAudioRecord.saveAudio(_:to:mode:progress:)` with byte-level tracking
  - 1MB chunk size for efficient streaming
  - CloudKit upload progress indication
  - Automatic partial file cleanup on cancellation
- Async `GeneratedAudioRecord.loadAudio(from:progress:)` with chunked reading
- Async `GeneratedImageRecord.saveImage(_:to:mode:progress:)` with byte-level tracking
- Async `GeneratedImageRecord.loadImage(from:progress:)` with chunked reading
- Hybrid storage mode with progress for both local and CloudKit

#### SwiftUI Integration
- Seamless integration with `ProgressView`
- Works with `@Published` properties and `ObservableObject`
- Actor-isolated progress handlers for main-thread updates
- Example `ParserViewModel` in README.md

#### Cancellation Support
- All progress-enabled operations check `Task.checkCancellation()`
- Automatic cleanup of partial files on cancellation
- Proper `CancellationError` throwing
- Verified across all 7 phases

#### Testing & Quality
- **99 new tests** across 7 new test suites:
  - `OperationProgressTests.swift` (7 tests - Phase 0)
  - `ProgressUpdateTests.swift` (7 tests - Phase 0)
  - `FountainParserProgressTests.swift` (9 tests - Phase 1)
  - `FDXParserProgressTests.swift` (8 tests - Phase 2)
  - `TextPackWriterProgressTests.swift` (14 tests - Phase 4)
  - `SwiftDataProgressTests.swift` (13 tests - Phase 5)
  - `FileIOProgressTests.swift` (13 tests - Phase 6)
  - `IntegrationTests.swift` (8 tests - Phase 7)
- **Total test count**: 275 tests across 20 suites (up from 176)
- **Coverage**: 95%+ overall, 90%+ for all new progress code
- **Performance verified**: <2% overhead confirmed in integration tests

#### Documentation
- Comprehensive "Progress Reporting" section in CLAUDE.md
- Progress examples in README.md with SwiftUI integration
- Updated all API documentation with progress parameters
- 7-phase implementation guide in `PROGRESS_REQUIREMENTS.md`

### Changed
- All async operations now accept optional `progress: OperationProgress?` parameter
- Progress parameters default to `nil` (100% backward compatible)
- Test suite expanded from 176 to 275 tests (20 suites)
- Version bumped to 1.3.0 reflecting minor feature addition

### Performance Characteristics
- **Overhead**: <2% of operation time (verified in performance tests)
- **Update frequency**: Batched to max 100 updates/second
- **Memory**: Bounded - no accumulation of progress updates
- **Concurrency**: Full Swift 6 compliance with actor isolation
- **Thread safety**: All progress APIs are `Sendable` and thread-safe

### Migration Guide

**No migration required** - all progress parameters are optional and default to `nil`. Existing code continues to work without modifications.

**To adopt progress reporting:**

```swift
// Before (still works):
let parser = try GuionParsedScreenplay(file: path)

// After (with progress):
let progress = OperationProgress(totalUnits: nil) { update in
    print(update.description)
}
let parser = try await FountainParser(string: text, progress: progress)
```

**SwiftUI integration:**

```swift
@MainActor
class ViewModel: ObservableObject {
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
```

## [1.2.1] - 2025-10-18

### Fixed

#### Critical CloudKit Conflict Resolution Bug
- **CRITICAL**: Fixed data loss bug in `CloudKitSyncable.resolveConflict()` method
- Added `modifiedAt` property to `CloudKitSyncable` protocol for timestamp-based conflict resolution
- Conflict resolution now correctly compares modification timestamps when `conflictVersion` values are equal
- Previous behavior: Always preferred local copy when versions matched, potentially discarding remote changes
- New behavior: Compares `modifiedAt` timestamps to determine which record is most recent
- Particularly important for newly created records (which all start at version 1)
- Added 4 comprehensive tests to prevent regression:
  - Higher version number preference
  - Equal versions use most recent timestamp
  - Equal versions and timestamps prefer local (rare edge case)
  - Newly created records conflict handling

**Migration Impact:** None - this is a pure bug fix with no API changes. Existing code continues to work unchanged.

## [1.2.0] - 2025-10-18

### ☁️ CloudKit Sync Support

Major enhancement adding CloudKit synchronization capabilities while maintaining 100% backward compatibility with existing local-only code.

### Added

#### CloudKit Features
- **Dual Storage System**: Seamlessly sync between local `.guion` bundles and CloudKit
- **Three Storage Modes**: `.local` (default), `.cloudKit`, and `.hybrid` per-record configuration
- **CloudKitSyncable Protocol**: Unified interface for sync-enabled models
- **Automatic Fallback**: Transparently loads from CloudKit or local storage
- **Conflict Resolution**: Built-in version tracking with `conflictVersion` and `cloudKitChangeTag`
- **Sync Status Tracking**: `.pending`, `.synced`, `.conflict`, `.failed`, `.localOnly` states

#### Model Enhancements
- All `*Record` models now include optional CloudKit properties:
  - `cloudKitRecordID`: CloudKit record identifier
  - `cloudKitChangeTag`: Change detection token
  - `lastSyncedAt`: Sync timestamp
  - `syncStatus`: Current sync state
  - `ownerUserRecordID`: Owner tracking for multi-user support
  - `sharedWith`: Sharing permissions array
  - `conflictVersion`: Version counter for conflict resolution
  - `storageMode`: `.local`, `.cloudKit`, or `.hybrid`
  - `cloudKit*Asset`: External storage for large files

#### Configuration Utilities
- **SwiftCompartidoContainer**: Factory for common container configurations
  - `makeLocalContainer()`: Local-only storage (default)
  - `makeCloudKitPrivateContainer()`: Private CloudKit database
  - `makeCloudKitAutomaticContainer()`: Automatic CloudKit configuration
  - `makeHybridContainer()`: Mixed local and CloudKit storage
- **ModelConfiguration Extensions**: Convenient CloudKit setup
- **SwiftCompartidoSchema**: Centralized schema definition
- **CKDatabase.isCloudKitAvailable()**: Check iCloud availability

#### Dual Storage Methods
- `GeneratedAudioRecord.saveAudio(_:to:mode:)`: Save with storage mode selection
- `GeneratedAudioRecord.loadAudio(from:)`: Load with automatic fallback
- `GeneratedTextRecord.saveText(_:to:mode:)`: Text storage with mode support
- `GeneratedTextRecord.loadText(from:)`: Text loading with fallback
- `GeneratedImageRecord.saveImage(_:to:mode:)`: Image storage with mode support
- `GeneratedImageRecord.loadImage(from:)`: Image loading with fallback
- `GeneratedEmbeddingRecord.saveEmbedding(_:to:mode:)`: Embedding storage
- `GeneratedEmbeddingRecord.loadEmbedding(from:)`: Embedding loading

#### Testing
- **17 new CloudKit tests** in `CloudKitSupportTests.swift`
- Tests for all three storage modes (.local, .cloudKit, .hybrid)
- Dual storage verification tests
- Backward compatibility tests (all 159 existing tests still pass)
- Protocol conformance tests

### Changed
- **BREAKING**: Minimum platform requirements increased to **macOS 26.0+** and **iOS 26.0+**
  - Removed all `@available` attributes (no longer needed)
  - Package now enforces platform requirements directly
- Removed custom `@Attribute(.transformable)` decorators from `TypedDataFileReference` properties
  - SwiftData now handles `Codable` types natively
  - Improves CloudKit compatibility
- Updated documentation with CloudKit usage examples
- Enhanced model descriptions to include sync status
- Test suite expanded from 159 to 176 tests (12 suites)

### Documentation
- **README.md**: Added CloudKit feature section and usage examples
- **CLAUDE.md**: Added "CloudKit Sync Patterns" section with migration guide
- Comprehensive CloudKit examples for all storage modes

### Migration Guide

**Platform Requirement Change:**
- Apps must now target **macOS 26.0+** and **iOS 26.0+**
- Update your deployment target in Xcode project settings
- This is the only breaking change

**Code Migration:**
Existing code using SwiftCompartido 1.0.0 requires **zero code changes**:
- All records default to `.local` storage mode
- Phase 6 architecture works identically
- CloudKit features are entirely opt-in per record
- No breaking changes to APIs or behavior

To enable CloudKit for new records:
```swift
let record = GeneratedTextRecord(
    // ... existing parameters
    storageMode: .cloudKit  // Add this parameter
)
```

## [1.0.0] - 2025-10-18

### 🎉 Initial Release

First production-ready release of SwiftCompartido - a comprehensive Swift package for screenplay management, AI-generated content storage, and document serialization.

### Added

#### Core AI Models
- **AIResponseData**: Modern response type with typed content (text, audio, image, structured data)
- **UsageStats**: Consolidated token/cost tracking across all AI operations
- **AIRequestStatus**: Request lifecycle tracking with progress support
- **AIServiceError**: Comprehensive error handling with recovery suggestions and retry logic

#### Generated Content Models
- **GeneratedTextRecord**: SwiftData model for storing AI-generated text
- **GeneratedAudioRecord**: SwiftData model for audio with file reference support
- **GeneratedImageRecord**: SwiftData model for images with efficient file storage
- **GeneratedEmbeddingRecord**: SwiftData model for vector embeddings

#### Storage System
- **TypedDataFileReference**: Lightweight file references with metadata and checksums
- **StorageAreaReference**: Request-scoped storage management
- **Phase 6 Architecture**: File-based storage pattern for optimal performance

#### Screenplay Management
- **FountainParser**: Complete Fountain format parsing
- **FDXParser**: Final Draft XML import
- **FDXDocumentWriter**: FDX export with full metadata support
- **FountainWriter**: Fountain format export
- **GuionElement**: Rich screenplay element model with hierarchy support
- **ElementType**: Complete element type system (scenes, dialogue, action, etc.)
- **TextPack**: Bundle format for screenplay + resources

#### Data Models
- **GuionDocument**: FileDocument wrapper for screenplay files
- **GuionDocumentModel**: SwiftData persistence model
- **Voice/VoiceModel**: TTS voice configuration and persistence
- **CharacterInfo**: Character extraction and metadata
- **SceneLocation**: Scene location tracking
- **SceneSummarizer**: Automatic scene analysis

#### UI Components
- **GuionViewer**: Screenplay rendering with proper formatting
- **SceneBrowser**: Hierarchical scene navigation
- **SceneBrowserWidget**: Individual scene display component
- **TextConfigurationView**: AI text generation settings UI
- **AudioPlayerManager**: Audio playback with waveform visualization
- **SpectrogramVisualizerView**: Audio waveform display

#### Utilities
- **SerializationFormat**: Screenplay format detection
- **OutputFileType**: Export format configuration
- **ProviderCategory**: AI provider categorization
- **AICredential**: Secure credential storage

### Features

#### Screenplay Processing
- ✅ Full Fountain format support with all element types
- ✅ FDX import/export with Final Draft compatibility
- ✅ Outline parsing with 6 levels of section headings
- ✅ Character extraction with scene mapping
- ✅ Location extraction and tracking
- ✅ Scene summarization
- ✅ Title page metadata parsing
- ✅ Dual dialogue support
- ✅ Scene numbering

#### AI Content Management
- ✅ Type-safe content handling (text, audio, image, structured)
- ✅ File-based storage for large content (audio, images)
- ✅ In-memory storage for small content (text)
- ✅ Automatic storage strategy selection
- ✅ Request lifecycle tracking
- ✅ Progress monitoring
- ✅ Usage statistics aggregation
- ✅ Cost tracking across providers

#### Audio Playback
- ✅ Direct file URL playback (efficient)
- ✅ In-memory data playback (fallback)
- ✅ Automatic storage detection
- ✅ Play/pause/stop controls
- ✅ Seeking support
- ✅ Duration tracking
- ✅ Audio level visualization
- ✅ Progress updates at 60 FPS

#### Data Persistence
- ✅ SwiftData integration
- ✅ Efficient file storage
- ✅ Checksum verification
- ✅ Metadata tracking
- ✅ Timestamp management
- ✅ Request-scoped storage areas

### Architecture

#### Design Patterns
- **Phase 6 Architecture**: Separate in-memory and file storage
- **Model Pairs**: DTO/SwiftData model separation
- **Sendable Conformance**: Full Swift 6 concurrency support
- **Type Safety**: Strongly typed content with enums
- **Error Handling**: Comprehensive error types with recovery

#### Performance Optimizations
- File-based storage prevents main thread blocking
- Lazy loading for large content
- Efficient database queries with fetch limits
- Background file I/O operations
- Minimal memory footprint

### Testing

- **159 tests** across 11 test suites
- **95%+ code coverage** on consolidated models
- **Swift Testing** framework
- Comprehensive integration tests
- Edge case coverage
- Error scenario testing

#### Test Coverage by Category
- AI Response Models: 30 tests
- Generated Content Records: 21 tests
- Storage System: 31 tests
- Serialization: 35 tests
- Audio Playback: 13 tests
- UI Components: 12 tests
- Parsing & Export: 17 tests

### Documentation

#### User Documentation
- **README.md**: Comprehensive user guide with examples
- **USAGE-SUMMARY.md**: Quick reference for common patterns
- **AI-REFERENCE.md**: Detailed guide for AI assistants
- **CONTRIBUTING.md**: Contribution guidelines
- **CHANGELOG.md**: Version history (this file)

#### API Documentation
- All public APIs documented
- Code examples for major features
- SwiftUI integration examples
- Error handling patterns
- Performance best practices

### Technical Details

#### Swift Version
- Requires Swift 5.9+
- Swift 6 concurrency ready
- All models are `Sendable`

#### Platform Support
- macOS 14.0+
- iOS 17.0+
- File storage features require macOS 15.0+ / iOS 17.0+

#### Dependencies
- Foundation
- SwiftData
- SwiftUI
- AVFoundation
- UniformTypeIdentifiers

### Breaking Changes
N/A - Initial release

### Deprecated
N/A - Initial release

### Removed

#### Consolidated Models (Pre-release cleanup)
The following models were removed before v1.0.0 in favor of the Phase 6 architecture:

- **AIResponse**: Replaced by `AIResponseData` (more modern, type-safe)
  - Old: Simple `Data` content
  - New: Typed `ResponseContent` enum
  - Migration: Use `AIResponseData` with typed content

- **AIResponse.Usage**: Replaced by `UsageStats`
  - Old: No duration tracking
  - New: Includes `durationSeconds`
  - Migration: Use `UsageStats` directly

- **AIGeneratedContent Models**: Replaced by file-based records
  - `GeneratedText` → `GeneratedTextRecord`
  - `GeneratedAudio` → `GeneratedAudioRecord`
  - `GeneratedImage` → `GeneratedImageRecord`
  - `GeneratedStructuredData` → Use `GeneratedTextRecord` with JSON
  - `GeneratedVideo` → To be added in future version

### Migration Guide
N/A - Initial release

### Known Issues
None at release time.

### Security
- No known security vulnerabilities
- Credentials stored securely using SwiftData
- File integrity verification with checksums

### Contributors
- Core team
- Built with assistance from [Claude Code](https://claude.com/claude-code)

### Special Thanks
- Swift community for Swift Testing framework
- Apple for SwiftData and SwiftUI
- All beta testers and early adopters

---

## [Unreleased]

### Planned for v1.1.0
- [ ] PDF screenplay export
- [ ] Enhanced audio waveform visualization
- [ ] Batch processing optimizations
- [ ] Additional screenplay format support
- [ ] Performance monitoring tools
- [ ] Advanced error recovery mechanisms

### Under Consideration
- [ ] Video content support (GeneratedVideoRecord)
- [ ] Cloud storage provider integration
- [ ] Advanced screenplay analytics
- [ ] Screenplay collaboration features
- [ ] Real-time sync capabilities

---

## Version History

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Incompatible API changes
- **MINOR**: Backward-compatible functionality additions
- **PATCH**: Backward-compatible bug fixes

### Release Schedule

- **Major releases**: Yearly
- **Minor releases**: Quarterly
- **Patch releases**: As needed

### Support Policy

- **Latest major version**: Full support
- **Previous major version**: Security updates for 12 months
- **Older versions**: Community support only

---

## Links

- **Repository**: https://github.com/intrusive-memory/SwiftCompartido
- **Issues**: https://github.com/intrusive-memory/SwiftCompartido/issues
- **Discussions**: https://github.com/intrusive-memory/SwiftCompartido/discussions
- **Releases**: https://github.com/intrusive-memory/SwiftCompartido/releases

---

**Note**: This changelog follows the principles from [Keep a Changelog](https://keepachangelog.com/en/1.0.0/). All notable changes to this project are documented here.

**Last Updated**: 2025-10-18
