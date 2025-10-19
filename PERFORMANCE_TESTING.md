# Performance Testing Guide

## Overview

SwiftCompartido uses a **separate, non-blocking performance testing system** to track performance metrics over time without blocking PRs or merges.

**Version**: 1.1.0
**Last Updated**: 2025-10-19

---

## Key Principles

1. **Non-Blocking**: Performance tests NEVER block PRs or merges
2. **Separate Execution**: Performance tests run in a dedicated GitHub Actions workflow
3. **Historical Tracking**: Results are stored and trended over time
4. **Alerting**: Significant regressions (>20%) trigger notifications
5. **Release Mode**: Performance tests always run in release configuration

---

## Writing Performance Tests

### Naming Convention

All performance test functions must include `performance` in their name:

```swift
func testParsingPerformance() async throws { }
func testImportVsNativePerformance() async throws { }
func testLargeFilePerformance() async throws { }
```

This naming convention allows the test framework to filter and run them separately.

### Performance Test Structure

```swift
import Testing
@testable import SwiftCompartido

struct ParserPerformanceTests {

    @Test("FountainParser performance with 10K lines")
    func testFountainParserPerformance() async throws {
        // 1. Setup - Create test data
        let largeScreenplay = createLargeScreenplay(lines: 10_000)

        // 2. Measure - Track execution time
        let startTime = Date()

        let parser = FountainParser(string: largeScreenplay)
        #expect(parser.elements.count > 0)

        let duration = Date().timeIntervalSince(startTime)

        // 3. Report - Use standardized format for GitHub Actions parsing
        print("📊 PERFORMANCE METRICS:")
        print("   FountainParser 10K lines: \(String(format: "%.3f", duration))s")

        // 4. Optional sanity check (not a hard requirement)
        // This ensures the test still validates correctness
        #expect(duration < 5.0, "Parser should complete in under 5 seconds")
    }

    // Helper function
    private func createLargeScreenplay(lines: Int) -> String {
        var screenplay = "Title: Performance Test\n\n"
        for i in 1...lines {
            if i % 10 == 0 {
                screenplay += "INT. LOCATION \(i) - DAY\n\n"
            } else {
                screenplay += "Action line \(i)\n\n"
            }
        }
        return screenplay
    }
}
```

### Performance Metric Output Format

**CRITICAL**: Use this exact format for metrics to be captured by GitHub Actions:

```swift
print("📊 PERFORMANCE METRICS:")
print("   <metric name>: <value>s")
```

Examples:
```swift
print("📊 PERFORMANCE METRICS:")
print("   FountainParser 10K lines: 0.234s")
print("   TextPack load 5MB: 1.456s")
print("   SwiftData conversion 1000 elements: 0.789s")
```

The GitHub Actions workflow parses these lines to extract benchmark data.

---

## Running Performance Tests

### Locally

Run all performance tests:
```bash
swift test -c release --filter '.*performance.*'
```

Run specific performance test:
```bash
swift test -c release --filter 'testFountainParserPerformance'
```

### In CI/CD

Performance tests run automatically:
- **On every PR**: Results are posted as a comment (non-blocking)
- **On merge to main**: Results are stored in gh-pages branch (dev/bench)
- **On release**: Results are stored permanently in releases/bench with release tag
- **Weekly**: Sunday at 00:00 UTC for trend analysis

**Important**: Performance tests NEVER block PRs or releases from being merged/published.

---

## Viewing Performance Results

### PR Comments

When you open a PR, the performance workflow will add a comment showing:
- Current performance metrics
- Comparison to main branch
- Alert if regression > 20%

### Historical Trends

View long-term performance trends:

**Development Benchmarks**: https://intrusive-memory.github.io/SwiftCompartido/dev/bench/

This page shows:
- Performance over time (line charts)
- Regression alerts
- Commit-by-commit comparisons

**Release Benchmarks**: https://intrusive-memory.github.io/SwiftCompartido/releases/bench/

This page shows:
- Performance metrics for each release version
- Release-to-release comparisons
- Official performance characteristics per version

### Artifacts

Every run uploads detailed results as artifacts:
- Retention: 90 days
- Location: GitHub Actions → Run → Artifacts
- Files: `performance-results-<release-tag>` or `performance-results-dev`

---

## Release Performance Tracking

### Automatic Release Benchmarking

When a new release is published on GitHub:

1. **Trigger**: Performance tests run automatically on `release` events (published/created)
2. **Execution**: Tests run in release mode (`-c release`)
3. **Storage**: Results stored in separate `releases/bench` directory
4. **Tagging**: Artifacts named with release tag (e.g., `performance-results-v1.2.0`)
5. **Permanent**: Release benchmarks are never overwritten

### Viewing Release Performance

**URL**: https://intrusive-memory.github.io/SwiftCompartido/releases/bench/

This page provides:
- Performance metrics for each released version
- Comparison between releases
- Official performance characteristics
- Historical performance evolution across versions

### Release Performance Use Cases

**For Users**:
- Compare performance between versions before upgrading
- Understand performance characteristics of specific releases
- Track performance improvements/regressions across versions

**For Developers**:
- Verify performance targets are met before release
- Document performance in release notes
- Track long-term performance trends
- Identify performance regressions in releases

### Release Performance vs. Development Performance

| Aspect | Development Benchmarks | Release Benchmarks |
|--------|------------------------|-------------------|
| Location | `dev/bench/` | `releases/bench/` |
| Frequency | Every commit to main | Every published release |
| Purpose | Track daily changes | Official version metrics |
| Retention | Continuous history | Permanent per release |
| Alerts | Yes (>20% regression) | No (informational) |

### Example Release Workflow

```bash
# 1. Create a release on GitHub
gh release create v1.3.0 --title "Release 1.3.0" --notes "Bug fixes and performance improvements"

# 2. GitHub Actions automatically:
#    - Runs performance tests in release mode
#    - Stores results in releases/bench/
#    - Tags artifacts with v1.3.0
#    - Generates performance summary

# 3. View release performance:
#    - Visit: https://intrusive-memory.github.io/SwiftCompartido/releases/bench/
#    - Compare with previous releases
#    - Include metrics in release notes if desired
```

---

## Performance Testing Best Practices

### 1. Test Realistic Workloads

❌ **Bad**: Test with 10 elements
```swift
let screenplay = "INT. ROOM - DAY\n\nAction.\n\n"
```

✅ **Good**: Test with realistic data sizes
```swift
let screenplay = createRealisticScreenplay(
    scenes: 50,
    charactersPerScene: 5,
    linesPerScene: 20
)
```

### 2. Warm Up Before Measuring

❌ **Bad**: Measure on first run (cold start)
```swift
let start = Date()
let parser = FountainParser(string: screenplay)
let duration = Date().timeIntervalSince(start)
```

✅ **Good**: Warm up, then measure
```swift
// Warm up
_ = FountainParser(string: smallSample)

// Measure
let start = Date()
let parser = FountainParser(string: screenplay)
let duration = Date().timeIntervalSince(start)
```

### 3. Multiple Iterations for Accuracy

✅ **Better**: Run multiple times and average
```swift
var durations: [TimeInterval] = []

for _ in 1...5 {
    let start = Date()
    let parser = FountainParser(string: screenplay)
    durations.append(Date().timeIntervalSince(start))
}

let avgDuration = durations.reduce(0, +) / Double(durations.count)
print("📊 PERFORMANCE METRICS:")
print("   FountainParser avg: \(String(format: "%.3f", avgDuration))s")
```

### 4. Clean Up Resources

```swift
func testLargeFilePerformance() async throws {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("perf-test.guion")

    defer {
        try? FileManager.default.removeItem(at: tempURL)
    }

    // Test code...
}
```

### 5. Test Release Mode Characteristics

Performance tests always run in release mode (`-c release`), which:
- Enables optimizations
- Removes debug symbols
- Provides production-like performance

---

## Performance Test Categories

### Parsing Performance
- FountainParser with varying file sizes
- FDXParser with complex XML
- TextPack multi-file loading

**Target**: 10K lines in <500ms

### File I/O Performance
- TextPack reading/writing
- Large file operations (audio, images)
- SwiftData persistence

**Target**: <2% overhead vs. direct I/O

### SwiftData Performance
- Bulk inserts
- Model conversions
- Query performance

**Target**: 1000 elements in <1s

### Progress Reporting Performance
- Overhead of progress tracking
- Callback frequency impact

**Target**: <2% overhead (per PROGRESS_REQUIREMENTS.md)

---

## Example: Complete Performance Test

```swift
import Testing
import Foundation
@testable import SwiftCompartido

struct TextPackPerformanceTests {

    @Test("TextPack load performance with large screenplay")
    func testTextPackLoadPerformance() async throws {
        // Create a large screenplay (300 pages ~ 12,000 lines)
        let largeScreenplay = createLargeScreenplay(
            scenes: 120,
            charactersPerScene: 6,
            actionLinesPerScene: 25
        )

        let screenplay = GuionParsedScreenplay(
            filename: "large-test.guion",
            elements: FountainParser(string: largeScreenplay).elements,
            titlePage: [],
            suppressSceneNumbers: false
        )

        // Create TextPack
        let bundle = try TextPackWriter.createTextPack(from: screenplay)

        // Warm-up run
        _ = try TextPackReader.readTextPack(from: bundle)

        // Measured runs
        var loadTimes: [TimeInterval] = []

        for iteration in 1...3 {
            let start = Date()
            let loaded = try TextPackReader.readTextPack(from: bundle)
            let duration = Date().timeIntervalSince(start)

            loadTimes.append(duration)

            // Validate correctness
            #expect(loaded.elements.count == screenplay.elements.count)
        }

        let avgLoadTime = loadTimes.reduce(0, +) / Double(loadTimes.count)
        let minLoadTime = loadTimes.min() ?? 0
        let maxLoadTime = loadTimes.max() ?? 0

        // Report metrics
        print("📊 PERFORMANCE METRICS:")
        print("   TextPack load avg: \(String(format: "%.3f", avgLoadTime))s")
        print("   TextPack load min: \(String(format: "%.3f", minLoadTime))s")
        print("   TextPack load max: \(String(format: "%.3f", maxLoadTime))s")

        // Sanity check - not a hard gate
        #expect(avgLoadTime < 2.0, "TextPack load should complete in under 2s")
    }

    private func createLargeScreenplay(
        scenes: Int,
        charactersPerScene: Int,
        actionLinesPerScene: Int
    ) -> String {
        var screenplay = """
        Title: Performance Test Screenplay
        Author: Test Suite

        """

        for sceneNum in 1...scenes {
            screenplay += "\nINT. LOCATION \(sceneNum) - DAY\n\n"

            for charNum in 1...charactersPerScene {
                screenplay += "CHARACTER \(charNum)\nDialogue line from character \(charNum).\n\n"
            }

            for actionNum in 1...actionLinesPerScene {
                screenplay += "Action description line \(actionNum) in scene \(sceneNum).\n\n"
            }
        }

        return screenplay
    }
}
```

---

## Troubleshooting

### Performance Test Not Detected

**Problem**: Test doesn't run in performance workflow

**Solution**: Ensure function name contains `performance`:
```swift
// ❌ Won't run
func testLargeFileLoad() { }

// ✅ Will run
func testLargeFileLoadPerformance() { }
```

### Metrics Not Captured

**Problem**: Results don't appear in GitHub Actions

**Solution**: Use exact format:
```swift
print("📊 PERFORMANCE METRICS:")
print("   <name>: <value>s")
```

Note the emoji, spacing, and "s" suffix.

### Performance Test Failing Builds

**Problem**: Performance test failure blocks PR

**Solution**: This should never happen. Performance workflow has `continue-on-error: true`. Check that test is in the performance workflow, not the standard test workflow.

---

## Integration with PROGRESS_REQUIREMENTS.md

The progress reporting feature (PROGRESS_REQUIREMENTS.md) includes:

**NFR-1.1**: Progress reporting overhead < 2% of operation time
**NFR-3.4**: Performance tests verify <2% overhead

All progress-related performance tests should:
1. Measure operation WITHOUT progress
2. Measure operation WITH progress
3. Calculate overhead percentage
4. Report both timings

Example:
```swift
func testProgressOverheadPerformance() async throws {
    let screenplay = createLargeScreenplay(lines: 10_000)

    // Without progress
    let startBase = Date()
    let parserBase = FountainParser(string: screenplay)
    let baseTime = Date().timeIntervalSince(startBase)

    // With progress (future implementation)
    let startProgress = Date()
    let parserProgress = try await FountainParser(
        string: screenplay,
        progress: OperationProgress(totalUnits: nil, handler: nil)
    )
    let progressTime = Date().timeIntervalSince(startProgress)

    let overhead = ((progressTime - baseTime) / baseTime) * 100

    print("📊 PERFORMANCE METRICS:")
    print("   Parser baseline: \(String(format: "%.3f", baseTime))s")
    print("   Parser with progress: \(String(format: "%.3f", progressTime))s")
    print("   Progress overhead: \(String(format: "%.1f", overhead))%")

    // Hard requirement from PROGRESS_REQUIREMENTS.md
    #expect(overhead < 2.0, "Progress overhead must be <2%")
}
```

---

## Benchmark Thresholds

Current performance targets:

| Operation | Size | Target | Alert Threshold |
|-----------|------|--------|-----------------|
| FountainParser | 10K lines | <500ms | >600ms (+20%) |
| FDXParser | 5K elements | <400ms | >480ms (+20%) |
| TextPack load | 5MB bundle | <1s | >1.2s (+20%) |
| TextPack write | 1K elements | <300ms | >360ms (+20%) |
| SwiftData conversion | 1K elements | <1s | >1.2s (+20%) |
| Progress overhead | Any operation | <2% | >2.4% (+20%) |

---

## Future Enhancements

- [ ] Automated baseline calibration for different hardware
- [ ] Performance regression in PR descriptions
- [ ] Flame graphs for profiling
- [ ] Memory usage tracking
- [ ] Comparison charts in PR comments

---

## References

- GitHub Actions Benchmark: https://github.com/benchmark-action/github-action-benchmark
- Swift Testing: https://github.com/apple/swift-testing
- PROGRESS_REQUIREMENTS.md: Performance testing requirements for progress feature

---

**Version History**:
- v1.1.0 (2025-10-19): Added release performance tracking
- v1.0.0 (2025-10-19): Initial performance testing guide

*Last Updated: 2025-10-19*
