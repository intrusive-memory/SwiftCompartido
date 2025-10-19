# Progress Reporting Requirements

## Document Overview

This document specifies the requirements for adding progress reporting capabilities to SwiftCompartido for resource-intensive operations.

**Version:** 1.2.0
**Date:** 2025-10-19
**Status:** Draft - Ready for Phase 0 Implementation

---

## 1. Executive Summary

SwiftCompartido requires a unified progress reporting system to provide user feedback during long-running operations such as parsing large screenplay files, serializing documents, and performing file I/O operations. This feature will improve the user experience by providing visibility into operation progress and estimated completion times.

---

## 2. Goals and Objectives

### Primary Goals
1. **Visibility**: Users can track progress of resource-intensive operations
2. **Consistency**: Uniform API across all supported operations
3. **Flexibility**: Support both determinate (known total) and indeterminate (unknown total) progress
4. **Cancellation**: Allow users to cancel long-running operations
5. **Swift Concurrency**: Full compatibility with async/await and actors
6. **Backward Compatibility**: Existing code continues to work without modifications

### Non-Goals
1. Real-time progress UI components (library provides data, apps provide UI)
2. Network progress tracking (not applicable to this library)
3. Background processing coordination (app-level concern)

---

## 3. Use Cases

### 3.1 Parsing Large Screenplays

**Scenario**: User opens a 300-page screenplay (12,000+ lines)

**Current Behavior**: Application freezes/blocks with no feedback

**Desired Behavior**:
- Progress bar shows "Parsing screenplay... 42%"
- Estimated time remaining: "~3 seconds"
- User can cancel if needed

**Operations Affected**:
- `FountainParser.parse(_:)` - line-by-line processing
- `FDXParser.parse(data:filename:)` - XML parsing and element extraction
- `GuionDocumentParserSwiftData.loadAndParse(from:in:generateSummaries:)` - multi-stage parsing

### 3.2 TextPack Bundle Reading

**Scenario**: User imports a .guion bundle with large resource files

**Current Behavior**: Silent operation, unclear if app is frozen

**Desired Behavior**:
- Progress shows "Loading screenplay.fountain... 1/5"
- Progress shows "Loading characters.json... 2/5"
- Progress shows "Loading Resources... 5/5"

**Operations Affected**:
- `TextPackReader.readTextPack(from:)` - multi-file reading
- `TextPackReader.readCharacters(from:)` - JSON parsing
- `TextPackReader.readLocations(from:)` - JSON parsing

### 3.3 TextPack Bundle Writing

**Scenario**: User exports a screenplay with extensive metadata

**Current Behavior**: No feedback during file generation

**Desired Behavior**:
- Progress shows "Generating screenplay.fountain... 33%"
- Progress shows "Extracting characters... 66%"
- Progress shows "Writing bundle... 100%"

**Operations Affected**:
- `TextPackWriter.createTextPack(from:)` - multi-stage export
- `TextPackWriter.extractCharacterData(from:)` - data extraction
- `TextPackWriter.extractLocationData(from:)` - location analysis

### 3.4 CloudKit Sync Operations

**Scenario**: User syncs large audio files to CloudKit

**Current Behavior**: Silent upload/download

**Desired Behavior**:
- Progress shows "Syncing audio (5.2 MB)... 47%"
- Upload/download speed displayed
- Cancellable

**Operations Affected**:
- `GeneratedAudioRecord.saveAudio(_:to:mode:)` - file writing + CloudKit upload
- `GeneratedImageRecord.saveImage(_:to:mode:)` - file writing + CloudKit upload
- CloudKit batch operations

### 3.5 AI Summary Generation

**Scenario**: User requests AI summaries for 50 scenes

**Current Behavior**: Long wait with no feedback

**Desired Behavior**:
- Progress shows "Generating summaries... 23/50 scenes"
- Estimated completion time shown
- Can cancel and keep partial results

**Operations Affected**:
- `GuionDocumentParserSwiftData.parse(script:in:generateSummaries:)` - scene-by-scene processing
- `SceneSummarizer` operations (if implemented)

---

## 4. Functional Requirements

### 4.1 Progress Reporting Protocol

**FR-1.1**: Define a `ProgressReporting` protocol for all operations that support progress

```swift
public protocol ProgressReporting {
    /// Current progress (0.0 to 1.0, or nil if indeterminate)
    var fractionCompleted: Double? { get }

    /// Total units of work (nil if unknown)
    var totalUnitCount: Int64? { get }

    /// Completed units of work
    var completedUnitCount: Int64 { get }

    /// Human-readable description of current operation
    var localizedDescription: String? { get }

    /// Optional additional information
    var localizedAdditionalDescription: String? { get }

    /// Whether operation can be cancelled
    var isCancellable: Bool { get }

    /// Cancel the operation
    func cancel() throws
}
```

### 4.2 Progress Observer Pattern

**FR-2.1**: Support callback-based progress updates

```swift
public typealias ProgressHandler = @Sendable (ProgressUpdate) -> Void

public struct ProgressUpdate: Sendable {
    public let fractionCompleted: Double?
    public let completedUnits: Int64
    public let totalUnits: Int64?
    public let description: String
    public let additionalInfo: String?
    public let timestamp: Date
}
```

**FR-2.2**: Support AsyncSequence-based progress updates

```swift
public struct ProgressSequence: AsyncSequence {
    public typealias Element = ProgressUpdate
    // ... implementation
}
```

### 4.3 Parser Progress Tracking

**FR-3.1**: FountainParser progress by lines processed

```swift
// Existing
public init(string: String)

// New with progress
public init(string: String, progressHandler: ProgressHandler? = nil) async throws
```

**FR-3.2**: FDXParser progress by XML elements processed

**FR-3.3**: Progress granularity: Update every 100 lines or 100ms, whichever is less frequent

### 4.4 File I/O Progress Tracking

**FR-4.1**: TextPackReader progress by files read

```swift
// Existing
public static func readTextPack(from fileWrapper: FileWrapper) throws -> GuionParsedScreenplay

// New with progress
public static func readTextPack(
    from fileWrapper: FileWrapper,
    progressHandler: ProgressHandler? = nil
) async throws -> GuionParsedScreenplay
```

**FR-4.2**: TextPackWriter progress by stages completed

**FR-4.3**: Large file operations (>1MB) report byte-level progress

### 4.5 SwiftData Operation Progress

**FR-5.1**: Bulk insert/update operations report record counts

**FR-5.2**: GuionDocumentModel conversion reports element counts

### 4.6 Cancellation Support

**FR-6.1**: All progress-enabled operations support cancellation via `Task.isCancelled`

**FR-6.2**: Cancellation leaves data in consistent state (atomic operations or rollback)

**FR-6.3**: Cancelled operations throw `CancellationError`

### 4.7 Backward Compatibility

**FR-7.1**: All existing synchronous APIs remain unchanged

**FR-7.2**: New async progress-enabled APIs are additive only

**FR-7.3**: Progress parameter defaults to nil (no progress reporting)

---

## 5. Non-Functional Requirements

### 5.1 Performance

**NFR-1.1**: Progress reporting overhead < 2% of operation time

**NFR-1.2**: Progress updates batched to avoid excessive callbacks (max 100 updates/sec)

**NFR-1.3**: No main thread blocking for progress calculations

### 5.2 Concurrency

**NFR-2.1**: All progress APIs are `Sendable` and thread-safe

**NFR-2.2**: Progress handlers can be called from any thread/actor

**NFR-2.3**: Full Swift 6 concurrency compliance

### 5.3 Testing

**NFR-3.1**: 95%+ test coverage for all new progress reporting code

**NFR-3.2**: Unit tests for all progress-enabled operations

**NFR-3.3**: Integration tests for multi-stage operations

**NFR-3.4**: Performance tests verify <2% overhead

**NFR-3.5**: All new code must have passing tests before phase gate approval

**NFR-3.6**: Each phase gate requires 95%+ coverage of code added in that phase

### 5.4 Documentation

**NFR-4.1**: All progress APIs fully documented with examples

**NFR-4.2**: Migration guide for adding progress to existing code

**NFR-4.3**: Sample code showing progress UI integration

**NFR-4.4**: Performance testing guide (see `PERFORMANCE_TESTING.md`)

### 5.5 Performance Testing Infrastructure

**NFR-5.1**: Separate, non-blocking performance test workflow

**NFR-5.2**: Performance tests run in release mode (`-c release`)

**NFR-5.3**: Results tracked over time in gh-pages branch

**NFR-5.4**: Alerts on performance regression >20%

**NFR-5.5**: Performance tests never block PRs or merges

**NFR-5.6**: All performance tests follow naming convention (`*performance*`)

**NFR-5.7**: Metrics reported in standardized format for GitHub Actions parsing

---

## 6. Technical Design

### 6.1 Core Progress Types

```swift
/// Progress reporter for operations
public final class OperationProgress: @unchecked Sendable {
    public private(set) var totalUnitCount: Int64?
    public private(set) var completedUnitCount: Int64 = 0

    private let handler: ProgressHandler?
    private let updateInterval: TimeInterval = 0.1  // 100ms
    private var lastUpdateTime: Date?

    public init(totalUnits: Int64? = nil, handler: ProgressHandler? = nil)

    public func update(completedUnits: Int64, description: String)
    public func increment(by delta: Int64 = 1, description: String)
    public func complete()
}
```

### 6.2 Progress-Enabled Parser Pattern

```swift
public class FountainParser {
    // Existing
    public init(string: String) { }

    // New - async with progress
    public init(
        string: String,
        progress: OperationProgress? = nil
    ) async throws {
        let lines = string.components(separatedBy: .newlines)
        progress?.totalUnitCount = Int64(lines.count)

        for (index, line) in lines.enumerated() {
            if Task.isCancelled {
                throw CancellationError()
            }

            // Parse line...

            if index % 100 == 0 {
                progress?.update(
                    completedUnits: Int64(index),
                    description: "Parsing screenplay..."
                )
            }
        }

        progress?.complete()
    }
}
```

### 6.3 Multi-Stage Progress

```swift
public class CompositProgress {
    private let stages: [String: Double]  // stage name -> weight
    private var currentStage: String?

    public func beginStage(_ name: String)
    public func updateStage(fractionCompleted: Double)
    public func completeStage()
}
```

### 6.4 Integration with Foundation.Progress

**Optional**: Provide bridge to `Foundation.Progress` for AppKit/UIKit integration

```swift
extension OperationProgress {
    public var foundationProgress: Progress { get }
}
```

---

## 7. Integration Points

### 7.1 Serialization Operations

| Class/Struct | Method | Progress Type | Granularity |
|-------------|--------|---------------|-------------|
| `FountainParser` | `init(string:)` | Line count | Per 100 lines |
| `FDXParser` | `parse(data:filename:)` | Element count | Per element |
| `FountainWriter` | `write(_:)` | Element count | Per element |
| `FDXDocumentWriter` | `makeFDX(from:)` | Element count | Per element |

### 7.2 TextPack Operations

| Method | Progress Type | Stages |
|--------|---------------|--------|
| `TextPackReader.readTextPack(from:)` | File count | 1. Read info.json<br>2. Read screenplay.fountain<br>3. Parse screenplay<br>4. Read resources (4 files) |
| `TextPackWriter.createTextPack(from:)` | Stage count | 1. Create info.json<br>2. Generate screenplay.fountain<br>3. Extract characters<br>4. Extract locations<br>5. Create resources |

### 7.3 SwiftData Operations

| Method | Progress Type | Granularity |
|--------|---------------|-------------|
| `GuionDocumentParserSwiftData.parse(script:in:generateSummaries:)` | Element count | Per element + scene summaries |
| `GuionDocumentModel.from(_:in:generateSummaries:)` | Combined | Parsing + conversion stages |

### 7.4 File Storage Operations

| Method | Progress Type | Granularity |
|--------|---------------|-------------|
| `GeneratedAudioRecord.saveAudio(_:to:mode:)` | Byte count | Per 1MB chunk |
| `GeneratedImageRecord.saveImage(_:to:mode:)` | Byte count | Per 1MB chunk |
| `StorageAreaReference` file operations | Byte count | Per write operation |

---

## 8. Error Handling

### 8.1 Cancellation Errors

```swift
public enum ProgressError: LocalizedError {
    case cancelled
    case invalidState(String)
    case progressReportingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Operation was cancelled"
        case .invalidState(let message):
            return "Invalid progress state: \(message)"
        case .progressReportingFailed(let error):
            return "Progress reporting failed: \(error.localizedDescription)"
        }
    }
}
```

### 8.2 Error Recovery

**ER-1**: If progress handler throws, operation continues without progress

**ER-2**: Cancelled operations clean up partial state

**ER-3**: Progress errors don't affect operation success

---

## 9. Testing Requirements

### 9.1 Unit Tests

- [ ] Progress calculation accuracy
- [ ] Progress callback invocation
- [ ] Cancellation handling
- [ ] Indeterminate progress
- [ ] Multi-stage progress
- [ ] Error handling

### 9.2 Integration Tests

- [ ] FountainParser with large file (10,000+ lines)
- [ ] TextPackReader with complete bundle
- [ ] TextPackWriter export
- [ ] SwiftData conversion with progress
- [ ] Cancelled operations cleanup

### 9.3 Performance Tests

**IMPORTANT**: Performance tests run separately in `.github/workflows/performance.yml` and are **non-blocking**. See `PERFORMANCE_TESTING.md` for complete guide.

Performance tests must:
- Include `performance` in the function name (e.g., `testParsingPerformance()`)
- Run in release mode (`-c release`)
- Report metrics in standardized format: `print("📊 PERFORMANCE METRICS:")`
- Compare WITH and WITHOUT progress to measure overhead

Required performance test coverage:
- [ ] Progress overhead measurement (<2%)
- [ ] Memory usage with progress enabled
- [ ] Callback frequency verification (max 100 updates/sec)
- [ ] Large file handling (100MB+)
- [ ] Baseline performance for all progress-enabled operations
- [ ] Performance regression detection (alert on >20% degradation)

Performance test requirements:
- **Non-Blocking**: Never block PRs or merges
- **Tracked**: Results stored in gh-pages branch for trending
- **Alerting**: Notify on >20% regression
- **Separate**: Run in dedicated GitHub Actions workflow
- **Release Mode**: Always `-c release` for production-like performance

---

## 10. Documentation Deliverables

### 10.1 API Documentation

- [ ] Full DocC documentation for all progress APIs
- [ ] Code examples for each operation type
- [ ] Migration guide for existing code
- [ ] Best practices guide

### 10.2 Sample Code

```swift
// Example: Parsing with progress
let parser = FountainParser()
let progress = OperationProgress(totalUnits: nil) { update in
    print("Progress: \(update.description) \(update.fractionCompleted ?? 0)%")
}

do {
    try await parser.parse(string: screenplay, progress: progress)
    print("Parsing complete!")
} catch is CancellationError {
    print("Parsing cancelled")
} catch {
    print("Parsing failed: \(error)")
}
```

### 10.3 UI Integration Examples

**SwiftUI Progress View**:
```swift
@State private var progress: Double = 0.0
@State private var description: String = ""

ProgressView(value: progress) {
    Text(description)
}
.task {
    let handler: ProgressHandler = { update in
        Task { @MainActor in
            self.progress = update.fractionCompleted ?? 0
            self.description = update.description
        }
    }

    try await parser.parse(string: screenplay, progress: handler)
}
```

---

## 11. Phased Implementation with Gate Criteria

This section defines the implementation phases with explicit, testable gate criteria. Each phase must pass its gates before proceeding to the next phase.

---

### Phase 0: Foundation Setup

**Duration**: 2 days

**Objective**: Establish progress reporting infrastructure and testing framework

#### Deliverables

1. **Core Types** (Sources/SwiftCompartido/Progress/)
   - [ ] `ProgressUpdate.swift` - Sendable struct with all fields
   - [ ] `ProgressHandler.swift` - Typealias and documentation
   - [ ] `ProgressError.swift` - Error types for progress operations
   - [ ] `OperationProgress.swift` - Main progress tracking class

2. **Testing Infrastructure**
   - [ ] `ProgressUpdateTests.swift` - Struct initialization and Sendable compliance
   - [ ] `OperationProgressTests.swift` - Progress calculation and threading tests
   - [ ] Test fixtures for mock operations
   - [ ] Performance test harness

3. **Documentation**
   - [ ] DocC documentation for all types
   - [ ] Architecture decision record (ADR) for progress design

#### Testable Functionality

| Feature | Test Case | Success Criteria |
|---------|-----------|------------------|
| ProgressUpdate creation | Create with all fields | Compiles and initializes correctly |
| ProgressUpdate Sendable | Pass across actor boundary | No compiler warnings |
| OperationProgress thread safety | Concurrent updates from 10 threads | No crashes, correct final count |
| Progress calculation | Update 0→100 units | fractionCompleted equals 1.0 |
| Progress batching | 1000 updates in 100ms | ≤10 handler callbacks |
| Indeterminate progress | Set totalUnits to nil | fractionCompleted is nil |
| Cancellation flag | Set cancelled state | isCancelled returns true |

#### Phase 0 Gate Criteria

**Must pass ALL criteria to proceed:**

- [ ] ✅ All Phase 0 code compiles without warnings
- [ ] ✅ 95%+ test coverage for Phase 0 code
- [ ] ✅ All 7 testable features have passing tests
- [ ] ✅ Thread safety test passes with TSan enabled
- [ ] ✅ Performance: OperationProgress overhead <1% (baseline)
- [ ] ✅ Documentation complete with code examples
- [ ] ✅ Code review approved by 1+ reviewer
- [ ] ✅ CI/CD pipeline passes all checks

**Gate Review**: Required before Phase 1

---

### Phase 1: FountainParser Progress Integration

**Duration**: 3 days

**Objective**: Add progress reporting to FountainParser with full cancellation support

#### Deliverables

1. **Parser Updates** (Sources/SwiftCompartido/Serialization/)
   - [ ] `FountainParser+Progress.swift` - Async initializer with progress
   - [ ] Update existing parser to support cancellation points
   - [ ] Add progress reporting every 100 lines

2. **Testing**
   - [ ] `FountainParserProgressTests.swift` - Progress accuracy tests
   - [ ] `FountainParserCancellationTests.swift` - Cancellation tests
   - [ ] Performance comparison tests
   - [ ] Large file test (10,000+ lines)

3. **Documentation**
   - [ ] API documentation with examples
   - [ ] Migration guide for existing FountainParser users

#### Testable Functionality

| Feature | Test Case | Success Criteria |
|---------|-----------|------------------|
| Line-by-line progress | Parse 1000 lines | Progress updates every 100 lines |
| Progress accuracy | Parse complete file | Final progress is 100% |
| Cancellation at 50% | Cancel task mid-parse | Parser throws CancellationError |
| No progress handler | Pass nil handler | Parser completes without errors |
| Large file performance | 10K lines with progress | <2% overhead vs without progress |
| Progress handler errors | Handler throws exception | Parser continues, no crash |
| Title page parsing | Parse with title page | Progress includes title page lines |
| Empty file | Parse empty string | Progress reports 0/0 complete |
| Multi-line elements | Parse action block | Progress counts all lines |

#### Phase 1 Gate Criteria

**Must pass ALL criteria to proceed:**

- [ ] ✅ All Phase 1 code compiles without warnings
- [ ] ✅ 95%+ test coverage for new FountainParser progress code
- [ ] ✅ All 9 testable features have passing tests
- [ ] ✅ Backward compatibility: Existing FountainParser tests still pass
- [ ] ✅ Performance: <2% overhead measured in benchmark
- [ ] ✅ Cancellation test verifies cleanup (no memory leaks)
- [ ] ✅ Documentation includes 2+ complete examples
- [ ] ✅ Integration test with real Big Fish screenplay
- [ ] ✅ Code review approved
- [ ] ✅ CI/CD pipeline passes

**Gate Review**: Required before Phase 2

---

### Phase 2: FDXParser Progress Integration

**Duration**: 3 days

**Objective**: Add progress reporting to FDXParser with XML parsing progress

#### Deliverables

1. **Parser Updates**
   - [ ] `FDXParser+Progress.swift` - Progress-enabled parsing
   - [ ] XML element counting for progress
   - [ ] Multi-stage progress (parse XML → convert elements)

2. **Testing**
   - [ ] `FDXParserProgressTests.swift` - Element-by-element progress
   - [ ] `FDXParserCancellationTests.swift` - Cancellation during XML parse
   - [ ] Multi-stage progress tests
   - [ ] Performance tests with large FDX files

3. **Documentation**
   - [ ] API documentation
   - [ ] Migration guide

#### Testable Functionality

| Feature | Test Case | Success Criteria |
|---------|-----------|------------------|
| XML element progress | Parse FDX with 100 elements | Progress updates per element |
| Two-stage progress | Parse → convert | Stage 1: 50%, Stage 2: 50% weight |
| Cancellation in XML parse | Cancel during parse | Throws CancellationError |
| Cancellation in conversion | Cancel during conversion | Throws CancellationError, no partial data |
| Invalid XML handling | Parse malformed XML | Error thrown, progress state valid |
| Title page elements | Parse FDX with title | Progress includes title elements |
| Large FDX performance | 5000+ elements | <2% overhead |
| Progress description | Check status strings | "Parsing XML" / "Converting elements" |

#### Phase 2 Gate Criteria

**Must pass ALL criteria to proceed:**

- [ ] ✅ All Phase 2 code compiles without warnings
- [ ] ✅ 95%+ test coverage for FDXParser progress code
- [ ] ✅ All 8 testable features have passing tests
- [ ] ✅ Backward compatibility maintained
- [ ] ✅ Performance: <2% overhead
- [ ] ✅ Multi-stage progress calculates correctly
- [ ] ✅ Documentation complete
- [ ] ✅ Code review approved
- [ ] ✅ CI/CD pipeline passes

**Gate Review**: Required before Phase 3

---

### Phase 3: TextPack Reader Progress Integration

**Duration**: 4 days

**Objective**: Multi-file progress tracking for TextPack bundle loading

#### Deliverables

1. **Reader Updates**
   - [ ] `TextPackReader+Progress.swift` - Progress-enabled reading
   - [ ] `CompositeProgress.swift` - Multi-stage progress coordinator
   - [ ] File-by-file progress tracking

2. **Testing**
   - [ ] `TextPackReaderProgressTests.swift` - Multi-file progress
   - [ ] `CompositeProgressTests.swift` - Stage coordination
   - [ ] Cancellation tests for each stage
   - [ ] Performance tests

3. **Documentation**
   - [ ] CompositeProgress API docs
   - [ ] Multi-stage progress guide

#### Testable Functionality

| Feature | Test Case | Success Criteria |
|---------|-----------|------------------|
| Multi-file progress | Read bundle with 5 files | 5 progress updates (1 per file) |
| Stage weighting | Read (10%) → Parse (40%) → Resources (50%) | Correct overall progress |
| Cancel during info.json | Cancel in stage 1 | CancellationError, no files read |
| Cancel during screenplay | Cancel in stage 2 | CancellationError, partial state cleaned |
| Cancel during resources | Cancel in stage 3 | CancellationError, partial state cleaned |
| Missing optional files | Bundle without resources | Progress still reaches 100% |
| Composite progress nesting | Stage contains sub-stages | Correct overall percentage |
| Large screenplay file | 10MB screenplay.fountain | Progress updates during parse |
| Stage descriptions | Check progress descriptions | "Reading info.json", etc. |

#### Phase 3 Gate Criteria

**Must pass ALL criteria to proceed:**

- [ ] ✅ All Phase 3 code compiles without warnings
- [ ] ✅ 95%+ test coverage for TextPackReader progress code
- [ ] ✅ All 9 testable features have passing tests
- [ ] ✅ CompositeProgress works correctly
- [ ] ✅ Backward compatibility maintained
- [ ] ✅ Performance: <2% overhead
- [ ] ✅ Cancellation properly cleans up across stages
- [ ] ✅ Documentation with multi-stage examples
- [ ] ✅ Code review approved
- [ ] ✅ CI/CD pipeline passes

**Gate Review**: Required before Phase 4

---

### Phase 4: TextPack Writer Progress Integration

**Duration**: 4 days

**Objective**: Progress tracking for TextPack bundle export operations

#### Deliverables

1. **Writer Updates**
   - [ ] `TextPackWriter+Progress.swift` - Progress-enabled writing
   - [ ] Character extraction progress
   - [ ] Location extraction progress
   - [ ] File writing progress

2. **Testing**
   - [ ] `TextPackWriterProgressTests.swift` - Export progress
   - [ ] Extraction operation progress tests
   - [ ] Cancellation tests
   - [ ] Performance tests

3. **Documentation**
   - [ ] API documentation
   - [ ] Export progress guide

#### Testable Functionality

| Feature | Test Case | Success Criteria |
|---------|-----------|------------------|
| Multi-stage export | info → screenplay → resources | 5 stages with correct weights |
| Character extraction | Extract 20 characters | Progress 0→100% |
| Location extraction | Extract 50 locations | Progress 0→100% |
| Large screenplay export | 10K elements | Progress updates smoothly |
| Cancel during extraction | Cancel in stage 2 | CancellationError, no partial files |
| Cancel during write | Cancel in stage 4 | CancellationError, cleanup temp files |
| Empty screenplay | Export empty screenplay | Progress reaches 100% |
| Progress descriptions | Check status strings | "Generating screenplay", etc. |

#### Phase 4 Gate Criteria

**Must pass ALL criteria to proceed:**

- [ ] ✅ All Phase 4 code compiles without warnings
- [ ] ✅ 95%+ test coverage for TextPackWriter progress code
- [ ] ✅ All 8 testable features have passing tests
- [ ] ✅ Backward compatibility maintained
- [ ] ✅ Performance: <2% overhead
- [ ] ✅ Cancellation cleans up temporary files
- [ ] ✅ Documentation complete
- [ ] ✅ Code review approved
- [ ] ✅ CI/CD pipeline passes

**Gate Review**: Required before Phase 5

---

### Phase 5: SwiftData Operations Progress

**Duration**: 4 days

**Objective**: Progress for SwiftData model conversions and bulk operations

#### Deliverables

1. **SwiftData Updates**
   - [ ] `GuionDocumentParserSwiftData+Progress.swift` - Progress-enabled parsing
   - [ ] `GuionDocumentModel+Progress.swift` - Conversion progress
   - [ ] Element-by-element conversion tracking

2. **Testing**
   - [ ] `SwiftDataProgressTests.swift` - Conversion progress
   - [ ] Bulk operation tests
   - [ ] Performance tests
   - [ ] Memory usage tests

3. **Documentation**
   - [ ] SwiftData progress patterns
   - [ ] Best practices for ModelContext operations

#### Testable Functionality

| Feature | Test Case | Success Criteria |
|---------|-----------|------------------|
| Element conversion | Convert 1000 elements | Progress 0→100% |
| AI summary generation | Generate 50 summaries | Progress per summary |
| Bulk insert progress | Insert 500 records | Progress per batch |
| Cancel during conversion | Cancel at 50% | CancellationError, no partial inserts |
| Memory efficient progress | Convert 10K elements | Memory stays constant |
| Progress with @MainActor | Conversion on main actor | No thread warnings |
| Nested model progress | Convert elements with children | Correct hierarchy progress |

#### Phase 5 Gate Criteria

**Must pass ALL criteria to proceed:**

- [ ] ✅ All Phase 5 code compiles without warnings
- [ ] ✅ 95%+ test coverage for SwiftData progress code
- [ ] ✅ All 7 testable features have passing tests
- [ ] ✅ Backward compatibility maintained
- [ ] ✅ Performance: <2% overhead
- [ ] ✅ Memory usage: <10% increase
- [ ] ✅ @MainActor compliance verified
- [ ] ✅ Documentation complete
- [ ] ✅ Code review approved
- [ ] ✅ CI/CD pipeline passes

**Gate Review**: Required before Phase 6

---

### Phase 6: File I/O Progress

**Duration**: 3 days

**Objective**: Byte-level progress for large file operations

#### Deliverables

1. **Storage Updates**
   - [ ] `GeneratedAudioRecord+Progress.swift` - Audio save/load progress
   - [ ] `GeneratedImageRecord+Progress.swift` - Image save/load progress
   - [ ] Byte-level progress tracking
   - [ ] CloudKit upload/download progress (if applicable)

2. **Testing**
   - [ ] `FileIOProgressTests.swift` - Large file progress
   - [ ] CloudKit sync progress tests
   - [ ] Cancellation tests
   - [ ] Performance tests

3. **Documentation**
   - [ ] File I/O progress patterns
   - [ ] CloudKit progress guide

#### Testable Functionality

| Feature | Test Case | Success Criteria |
|---------|-----------|------------------|
| Large audio save | Save 50MB audio file | Byte-level progress |
| Large image save | Save 20MB image | Byte-level progress |
| Chunked writing | Write in 1MB chunks | Progress per chunk |
| Cancel during write | Cancel at 40% | CancellationError, partial file deleted |
| CloudKit upload | Upload 10MB asset | Upload progress 0→100% |
| CloudKit download | Download 10MB asset | Download progress 0→100% |
| Hybrid storage | Local + CloudKit | Combined progress accurate |

#### Phase 6 Gate Criteria

**Must pass ALL criteria to proceed:**

- [ ] ✅ All Phase 6 code compiles without warnings
- [ ] ✅ 95%+ test coverage for file I/O progress code
- [ ] ✅ All 7 testable features have passing tests
- [ ] ✅ Backward compatibility maintained
- [ ] ✅ Performance: <2% overhead
- [ ] ✅ Cancellation cleans up partial files
- [ ] ✅ Documentation complete
- [ ] ✅ Code review approved
- [ ] ✅ CI/CD pipeline passes

**Gate Review**: Required before Phase 7

---

### Phase 7: Documentation & Integration

**Duration**: 3 days

**Objective**: Complete documentation, examples, and final integration testing

#### Deliverables

1. **Documentation**
   - [ ] Complete DocC documentation for all progress APIs
   - [ ] Migration guide from non-progress to progress APIs
   - [ ] Best practices guide
   - [ ] Performance optimization guide
   - [ ] Troubleshooting guide

2. **Examples**
   - [ ] SwiftUI ProgressView integration example
   - [ ] AppKit NSProgressIndicator example
   - [ ] Command-line progress bar example
   - [ ] Cancellation handling examples
   - [ ] Multi-stage progress example

3. **Integration Tests**
   - [ ] End-to-end import/export with progress
   - [ ] Multi-operation workflow test
   - [ ] Real-world screenplay test (Big Fish)
   - [ ] Memory leak tests
   - [ ] Performance regression tests

4. **CHANGELOG Update**
   - [ ] Document all new APIs
   - [ ] Note backward compatibility
   - [ ] Performance characteristics

#### Testable Functionality

| Feature | Test Case | Success Criteria |
|---------|-----------|------------------|
| Complete workflow | Import → Edit → Export with progress | All stages report progress |
| Documentation examples | Run all code examples | All compile and run correctly |
| Performance regression | Compare before/after | <2% overhead confirmed |
| Memory usage | Profile full workflow | No leaks detected |
| Thread safety | Run under TSan | No warnings |
| SwiftUI integration | Run example app | Progress updates smoothly |
| Cancellation workflow | Cancel at each stage | Proper cleanup verified |

#### Phase 7 Gate Criteria

**Must pass ALL criteria to proceed to release:**

- [ ] ✅ All documentation complete and reviewed
- [ ] ✅ All 5 example applications run successfully
- [ ] ✅ All 7 integration tests pass
- [ ] ✅ Overall test coverage ≥95% for all progress code
- [ ] ✅ Performance: <2% overhead verified across all operations
- [ ] ✅ Memory: No leaks detected with Instruments
- [ ] ✅ Thread safety: TSan clean
- [ ] ✅ CHANGELOG.md updated
- [ ] ✅ Version bumped appropriately (minor version)
- [ ] ✅ Final code review approved
- [ ] ✅ CI/CD pipeline passes
- [ ] ✅ Manual testing on macOS 26+ and iOS 26+

**Gate Review**: Required before release

---

### Phase Summary

| Phase | Duration | Lines of Code (est.) | Test Files | Gate Criteria Count |
|-------|----------|---------------------|------------|---------------------|
| Phase 0 | 2 days | ~300 | 2 | 8 |
| Phase 1 | 3 days | ~400 | 2 | 10 |
| Phase 2 | 3 days | ~350 | 2 | 9 |
| Phase 3 | 4 days | ~500 | 2 | 10 |
| Phase 4 | 4 days | ~450 | 1 | 9 |
| Phase 5 | 4 days | ~400 | 1 | 10 |
| Phase 6 | 3 days | ~350 | 2 | 9 |
| Phase 7 | 3 days | ~200 (docs) | 1 | 12 |
| **Total** | **26 days** | **~2,950 LOC** | **13 files** | **77 gates** |

---

### Gate Process

#### Gate Review Meeting

Each phase concludes with a gate review meeting:

1. **Preparation** (1 day before)
   - Developer runs gate checklist
   - Generates coverage report
   - Prepares demo of new functionality
   - Documents any issues or blockers

2. **Review Meeting** (30-60 minutes)
   - Demo of testable functionality
   - Review test coverage report
   - Review performance benchmarks
   - Review documentation
   - Discuss any concerns
   - Decision: PASS or FAIL

3. **Decision Criteria**
   - **PASS**: All gate criteria met → Proceed to next phase
   - **FAIL**: One or more criteria not met → Fix and re-review
   - **CONDITIONAL PASS**: Minor issues → Proceed with action items

4. **Documentation**
   - Record decision in `PROGRESS_GATES.md`
   - Note any conditions or action items
   - Sign-off by reviewer(s)

#### Gate Enforcement

- [ ] No phase can begin until previous phase passes gate
- [ ] Failing gates require remediation before proceeding
- [ ] Gate criteria are non-negotiable (cannot be skipped)
- [ ] Coverage <95% is automatic FAIL
- [ ] Failing tests are automatic FAIL
- [ ] Breaking changes are automatic FAIL

---

## 12. Success Criteria

### Functional Success
- [ ] All identified operations support progress reporting
- [ ] Cancellation works for all operations
- [ ] Backward compatibility maintained
- [ ] All tests passing

### Quality Success
- [ ] 95%+ test coverage for all new code
- [ ] <2% performance overhead
- [ ] Zero breaking changes
- [ ] Complete documentation
- [ ] All 77 phase gate criteria passed

### User Success
- [ ] Progress updates are accurate
- [ ] Operations are cancellable
- [ ] UI integration is straightforward
- [ ] Migration is easy

---

## 13. Open Questions

1. **Q**: Should we use `Foundation.Progress` internally?
   - **Decision Needed**: Week 1

2. **Q**: How to handle nested progress (operation within operation)?
   - **Decision Needed**: Week 1

3. **Q**: Should progress be opt-in or opt-out for new async APIs?
   - **Decision Needed**: Week 1

4. **Q**: Do we need progress for CloudKit sync operations?
   - **Decision Needed**: Week 2

5. **Q**: Should we provide pre-built SwiftUI progress views?
   - **Decision Needed**: Week 6 (nice-to-have)

---

## 14. Dependencies

### Internal Dependencies
- Swift 6.2+
- SwiftData framework
- CloudKit framework (for sync operations)

### External Dependencies
None (progress is self-contained)

---

## 15. Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Performance degradation | High | Low | Benchmark continuously, batch updates |
| Breaking changes | Critical | Low | Maintain all existing APIs, add new only |
| Complex multi-stage progress | Medium | Medium | Use `CompositProgress` abstraction |
| Thread safety issues | High | Medium | Full Sendable compliance, actor isolation |
| Cancellation leaves corrupt state | High | Low | Atomic operations, proper cleanup |

---

## 16. Future Enhancements

### Post-V1 Features
- Real-time progress streaming via AsyncSequence
- Progress persistence (resume after app restart)
- Progress history/analytics
- Automatic time estimation based on historical data
- Progress aggregation for batch operations
- Remote progress monitoring (for CloudKit operations)

---

## 17. Acceptance Criteria

### Developer Acceptance
- [ ] API is intuitive and easy to use
- [ ] Examples cover common use cases
- [ ] Documentation is clear and complete
- [ ] Migration from non-progress to progress is straightforward

### User Acceptance
- [ ] Progress updates are smooth and responsive
- [ ] Estimated times are reasonably accurate
- [ ] Cancellation works reliably
- [ ] No perceived performance impact

### Technical Acceptance
- [ ] All tests pass (100% passing rate)
- [ ] Code coverage >= 95% for all new progress code
- [ ] Performance overhead < 2% across all operations
- [ ] Swift 6 concurrency compliance (no warnings)
- [ ] Zero breaking changes (all existing tests pass)
- [ ] All 7 phase gates passed
- [ ] 77 total gate criteria met

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-10-19 | Initial | Initial requirements document |
| 1.1.0 | 2025-10-19 | Update | Added phased gate criteria, increased test coverage to 95%, added 77 testable gate checkpoints across 7 phases |
| 1.2.0 | 2025-10-19 | Update | Added performance testing infrastructure, non-blocking performance workflow, GitHub Actions benchmarking integration |

---

## Appendix A: Complete Testable Functionality Checklist

This appendix provides a master checklist of all 57 testable features across all phases.

### Phase 0: Foundation (7 features)
- [ ] ProgressUpdate creation
- [ ] ProgressUpdate Sendable compliance
- [ ] OperationProgress thread safety
- [ ] Progress calculation accuracy
- [ ] Progress batching
- [ ] Indeterminate progress handling
- [ ] Cancellation flag

### Phase 1: FountainParser (9 features)
- [ ] Line-by-line progress tracking
- [ ] Progress accuracy (100% completion)
- [ ] Cancellation at 50%
- [ ] No progress handler (nil)
- [ ] Large file performance
- [ ] Progress handler error resilience
- [ ] Title page parsing progress
- [ ] Empty file handling
- [ ] Multi-line elements progress

### Phase 2: FDXParser (8 features)
- [ ] XML element progress
- [ ] Two-stage progress (parse + convert)
- [ ] Cancellation in XML parse
- [ ] Cancellation in conversion
- [ ] Invalid XML handling
- [ ] Title page elements progress
- [ ] Large FDX performance
- [ ] Progress description strings

### Phase 3: TextPack Reader (9 features)
- [ ] Multi-file progress
- [ ] Stage weighting
- [ ] Cancel during info.json
- [ ] Cancel during screenplay
- [ ] Cancel during resources
- [ ] Missing optional files
- [ ] Composite progress nesting
- [ ] Large screenplay file
- [ ] Stage descriptions

### Phase 4: TextPack Writer (8 features)
- [ ] Multi-stage export
- [ ] Character extraction progress
- [ ] Location extraction progress
- [ ] Large screenplay export
- [ ] Cancel during extraction
- [ ] Cancel during write
- [ ] Empty screenplay export
- [ ] Progress descriptions

### Phase 5: SwiftData Operations (7 features)
- [ ] Element conversion progress
- [ ] AI summary generation progress
- [ ] Bulk insert progress
- [ ] Cancel during conversion
- [ ] Memory efficient progress
- [ ] Progress with @MainActor
- [ ] Nested model progress

### Phase 6: File I/O (7 features)
- [ ] Large audio save progress
- [ ] Large image save progress
- [ ] Chunked writing progress
- [ ] Cancel during write
- [ ] CloudKit upload progress
- [ ] CloudKit download progress
- [ ] Hybrid storage progress

### Phase 7: Integration (7 features)
- [ ] Complete workflow
- [ ] Documentation examples runnable
- [ ] Performance regression verification
- [ ] Memory usage profiling
- [ ] Thread safety (TSan)
- [ ] SwiftUI integration
- [ ] Cancellation workflow

### Summary Statistics
- **Total Testable Features**: 57
- **Total Gate Criteria**: 77
- **Total Test Files**: 13
- **Total Estimated LOC**: ~2,950
- **Required Coverage**: 95%+
- **Required Performance**: <2% overhead

---

## Appendix B: API Examples

### Example 1: Simple Progress Handler

```swift
import SwiftCompartido

let screenplay = """
Title: My Screenplay
Author: John Doe

INT. BEDROOM - NIGHT
...
"""

let progress = OperationProgress(totalUnits: nil) { update in
    if let fraction = update.fractionCompleted {
        print("Progress: \(Int(fraction * 100))% - \(update.description)")
    } else {
        print("Processing: \(update.description)")
    }
}

do {
    let parser = try await FountainParser(string: screenplay, progress: progress)
    print("Parsed \(parser.elements.count) elements")
} catch {
    print("Error: \(error)")
}
```

### Example 2: SwiftUI Integration

```swift
import SwiftUI
import SwiftCompartido

struct ScreenplayImportView: View {
    @State private var progress: Double = 0
    @State private var statusText: String = ""
    @State private var isImporting: Bool = false
    @State private var importTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 20) {
            if isImporting {
                ProgressView(value: progress) {
                    Text(statusText)
                }
                .padding()

                Button("Cancel") {
                    importTask?.cancel()
                }
            } else {
                Button("Import Screenplay") {
                    startImport()
                }
            }
        }
    }

    func startImport() {
        isImporting = true

        importTask = Task {
            let progressHandler: ProgressHandler = { update in
                Task { @MainActor in
                    self.progress = update.fractionCompleted ?? 0
                    self.statusText = update.description
                }
            }

            do {
                let screenplay = loadScreenplayText()
                let parser = try await FountainParser(
                    string: screenplay,
                    progress: OperationProgress(handler: progressHandler)
                )

                // Success
                await handleSuccess(parser)
            } catch is CancellationError {
                statusText = "Import cancelled"
            } catch {
                statusText = "Import failed: \(error.localizedDescription)"
            }

            isImporting = false
        }
    }

    @MainActor
    func handleSuccess(_ parser: FountainParser) {
        statusText = "Successfully imported \(parser.elements.count) elements"
    }

    func loadScreenplayText() -> String {
        // Load from file...
        return ""
    }
}
```

### Example 3: Multi-Stage Progress

```swift
// TextPack import with multi-stage progress
let stages = [
    "Reading bundle": 0.1,
    "Parsing screenplay": 0.4,
    "Loading resources": 0.3,
    "Converting to SwiftData": 0.2
]

let compositeProgress = CompositProgress(stages: stages) { update in
    print("\(update.description): \(Int(update.fractionCompleted! * 100))%")
}

compositeProgress.beginStage("Reading bundle")
let fileWrapper = try loadFileWrapper()
compositeProgress.completeStage()

compositeProgress.beginStage("Parsing screenplay")
let screenplay = try await TextPackReader.readTextPack(
    from: fileWrapper,
    progress: compositeProgress.stageProgress()
)
compositeProgress.completeStage()

// ... continue with other stages
```

---

## Appendix C: Performance Benchmarks

Target benchmarks for progress overhead:

| Operation | Without Progress | With Progress | Overhead | Status |
|-----------|-----------------|---------------|----------|--------|
| Parse 10K line screenplay | 500ms | <510ms | <2% | ✅ Target |
| Read TextPack bundle | 200ms | <204ms | <2% | ✅ Target |
| Write TextPack bundle | 300ms | <306ms | <2% | ✅ Target |
| Convert to SwiftData | 1000ms | <1020ms | <2% | ✅ Target |
| CloudKit sync 10MB | 5000ms | <5100ms | <2% | ✅ Target |

---

## Appendix D: Thread Safety Model

All progress APIs follow these thread safety rules:

1. **OperationProgress** is `@unchecked Sendable` with internal locking
2. **ProgressHandler** is `@Sendable` closure, can be called from any thread
3. **ProgressUpdate** is `Sendable` struct, safe to pass between threads
4. Progress callbacks never block the operation thread
5. UI updates from callbacks must be dispatched to `@MainActor`

---

*End of Requirements Document*
