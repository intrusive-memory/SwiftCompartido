# Performance Testing & Benchmarking

SwiftCompartido includes comprehensive performance testing to track rendering speed and detect regressions across builds.

## Performance Test Suite

**Location**: `Tests/SwiftCompartidoTests/GuionViewerPerformanceTests.swift`

The suite measures:
- **Parsing performance**: GuionParsedElementCollection on 100-5000 element screenplays
- **SwiftData conversion**: Parse → SwiftData model creation time
- **Element access**: `sortedElements` retrieval performance
- **Text formatting**: FountainTextFormatter (bold, italic, underline) processing
- **End-to-end benchmarks**: Complete parse → render pipeline

## Running Performance Tests

```bash
xcodebuild test \
  -scheme SwiftCompartido \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Release \
  -only-testing:SwiftCompartidoTests/GuionViewerPerformanceTests \
  CODE_SIGNING_ALLOWED=NO
```

**Important**: Performance tests **must** run in `Release` configuration for accurate measurements. Debug builds have ~10x slower performance due to optimizations being disabled.

## Current Performance Baselines

### 1000 Elements
- **Parse**: 0.016s (< 1% of total)
- **Convert**: 1.127s (94% of total) ← **Primary bottleneck**
- **Format**: 0.054s (< 5% of total)
- **Total**: 1.200s

### 5000 Elements
- **Parse**: 0.072s (< 1% of total)
- **Convert**: 23.732s (99% of total) ← **Primary bottleneck**
- **Format**: 0.234s (< 1% of total)
- **Total**: 24.050s

## Bottleneck Analysis

1. **SwiftData Conversion** (94-99% of time)
   - Scales poorly: 1.1s → 23.7s for 5x elements
   - Root cause: Individual model insertion + relationship management
   - Potential fix: Batch insertion API (when available in SwiftData)

2. **Text Formatting** (1-5% of time)
   - Efficient across all document sizes
   - No optimization needed

3. **Parsing** (< 1% of time)
   - Negligible impact
   - Already optimized

## Build-to-Build Performance Tracking

SwiftCompartido uses `PerformanceMetricsTracker` to automatically record metrics and export JSON reports for trend analysis.

### Automatic Tracking

Performance tests automatically record metrics:

```swift
await PerformanceMetricsTracker.shared.recordMetric(
    testName: "ParseAndRender_1000",
    elementCount: 1000,
    parseTime: 0.016,
    convertTime: 1.127,
    sortTime: 0.003,
    formatTime: 0.054
)
```

### JSON Output

**Location**: `/tmp/performance_results/performance_*.json`

**Schema**:
```json
{
  "timestamp": "2026-01-15T12:34:56Z",
  "testName": "ParseAndRender_1000",
  "elementCount": 1000,
  "parseTime": 0.016,
  "convertTime": 1.127,
  "sortTime": 0.003,
  "formatTime": 0.054,
  "totalTime": 1.200,
  "device": "iPhone 17 Pro Simulator",
  "swiftVersion": "6.2"
}
```

### Viewing Reports Locally

```bash
# List all performance reports
ls /tmp/performance_results/

# View latest report
cat /tmp/performance_results/performance_*.json | jq '.'

# Compare two runs
jq -s '.[0] as $old | .[1] as $new |
  {parseTimeChange: (($new.parseTime - $old.parseTime) / $old.parseTime * 100),
   convertTimeChange: (($new.convertTime - $old.convertTime) / $old.convertTime * 100),
   totalTimeChange: (($new.totalTime - $old.totalTime) / $old.totalTime * 100)}' \
  /tmp/performance_results/performance_2026-01-14*.json \
  /tmp/performance_results/performance_2026-01-15*.json
```

## CI Integration

### Workflow
1. **Unit tests** run first (blocking)
2. **Performance tests** run after unit tests pass (non-blocking)
3. JSON reports uploaded as GitHub Actions artifacts
4. Artifacts retained for **90 days**

### Downloading CI Artifacts

1. Navigate to GitHub Actions → Workflows → Performance Tests
2. Select a completed run
3. Download **performance-results** artifact (ZIP file)
4. Extract and view JSON reports

### Regression Detection

PerformanceMetricsTracker compares each run with the previous baseline:

```
✅ Parse time: 0.016s (baseline: 0.015s, +6.7%)
⚠️  Convert time: 1.350s (baseline: 1.127s, +19.8%) ← REGRESSION DETECTED
✅ Format time: 0.055s (baseline: 0.054s, +1.9%)
```

**Regression threshold**: 10% slower than previous baseline

## Future Optimization Targets

Based on current baselines:

### 1. SwiftData Conversion (High Priority)
**Current**: 23.7s for 5000 elements (99% of total time)
**Target**: < 5s (5x improvement)
**Approaches**:
- Batch insertion API (when available)
- Pre-compute during parsing phase (eliminate separate conversion step)
- Lazy loading (only convert visible elements)

### 2. Viewport-Based Rendering (Medium Priority)
**Current**: All elements loaded into memory
**Target**: 30-50% memory reduction
**Approach**: Only render elements visible in viewport + 1 screen buffer

### 3. TextKit 2 Implementation (Low Priority)
**Current**: SwiftUI Text with AttributedString
**Target**: 400-1600x faster rendering (based on GuionTextEditor benchmarks)
**Approach**: Migrate GuionElementsList to TextKit 2 backend

## Test Plan Configuration

Performance tests are configured in `PerformanceTests.xctestplan`:

```json
{
  "configurations": [
    {
      "name": "Release",
      "buildConfiguration": "Release"
    }
  ],
  "testTargets": [
    {
      "target": {
        "containerPath": "SwiftCompartido.xcodeproj",
        "identifier": "SwiftCompartidoTests",
        "name": "SwiftCompartidoTests"
      },
      "selectedTests": [
        "GuionViewerPerformanceTests",
        "GuionTextEditorPerformanceTests",
        "Phase2PerformanceTests"
      ]
    }
  ]
}
```

**Important**: Only test classes/structs with "Performance" in the name are included. This prevents performance tests from running alongside unit tests.

## Advanced Tracking Strategies

See `.claude/skills/performance-tracking.md` for:
- Custom metric collection
- Benchmark result analysis
- Statistical significance testing
- Regression trend analysis

## References

- Test Suite: `Tests/SwiftCompartidoTests/GuionViewerPerformanceTests.swift`
- Metrics Tracker: `Tests/SwiftCompartidoTests/Utilities/PerformanceMetricsTracker.swift`
- Test Plan: `PerformanceTests.xctestplan`
- CI Workflow: `.github/workflows/performance.yml`
