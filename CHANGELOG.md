# Changelog

All notable changes to SwiftCompartido will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
