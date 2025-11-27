# Performance Tracking Strategy for SwiftCompartido

## Current State

The performance tests output metrics to console and save as text artifacts. This is useful for spot checks but doesn't provide:
- Historical trend analysis
- Regression detection
- Easy comparison between commits/PRs
- Visualization of performance over time

## Recommended Solutions

### Option 1: JSON Performance Logs (Immediate, Simple)

**What**: Export performance metrics as structured JSON
**Where**: Store in repository or upload to artifact storage
**How**: Parse and visualize with external tools

#### Implementation

```swift
// Add to GuionViewerPerformanceTests.swift

struct PerformanceMetrics: Codable {
    let testName: String
    let timestamp: Date
    let gitCommit: String
    let branch: String
    let elementCount: Int
    let parseTime: TimeInterval
    let convertTime: TimeInterval
    let sortTime: TimeInterval
    let formatTime: TimeInterval
    let totalTime: TimeInterval
    let elementsPerSecond: Double
    let memoryPeak: Int64?  // bytes

    var averageTimePerElement: TimeInterval {
        elementCount > 0 ? totalTime / Double(elementCount) : 0
    }
}

struct PerformanceReport: Codable {
    let timestamp: Date
    let platform: String  // "iOS Simulator" or "macOS"
    let osVersion: String
    let xcodeVersion: String
    let swiftVersion: String
    let gitCommit: String
    let branch: String
    let prNumber: Int?
    let metrics: [PerformanceMetrics]
}

func savePerformanceReport(_ report: PerformanceReport) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    let data = try encoder.encode(report)

    // Save to temp directory for CI artifact upload
    let filename = "performance_\(report.timestamp.timeIntervalSince1970).json"
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("performance_results")
        .appendingPathComponent(filename)

    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    try data.write(to: url)
    print("📊 Performance report saved: \(url.path)")
}
```

#### CI Integration

```yaml
# .github/workflows/tests.yml
- name: Run performance tests
  run: |
    # ... existing test command ...

    # Collect JSON performance reports
    mkdir -p performance_results
    cp /tmp/performance_results/*.json performance_results/ || true

- name: Upload performance results
  uses: actions/upload-artifact@v4
  with:
    name: performance-results-${{ github.sha }}
    path: performance_results/
    retention-days: 90  # Keep for 3 months
```

#### Advantages
- ✅ Easy to implement
- ✅ Version controlled or artifact storage
- ✅ Machine-readable for analysis
- ✅ Works with any CI system

#### Disadvantages
- ❌ No built-in visualization
- ❌ Manual comparison required
- ❌ No automatic regression detection

---

### Option 2: GitHub Actions Performance Monitoring (Recommended)

**What**: Use `benchmark-action` to track performance over time
**Where**: GitHub Actions with automatic comparison
**How**: Built-in visualization and regression detection

#### Implementation

```yaml
# .github/workflows/performance.yml
name: Performance Benchmarks

on:
  pull_request:
  push:
    branches: [main, development]

jobs:
  benchmark:
    name: Performance Benchmarks
    runs-on: macos-26

    steps:
      - uses: actions/checkout@v4

      - name: Run performance tests
        run: |
          xcodebuild test \
            -scheme SwiftCompartido \
            -sdk iphonesimulator \
            -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
            -only-testing:SwiftCompartidoTests/GuionViewerPerformanceTests \
            CODE_SIGNING_ALLOWED=NO \
            | tee performance_output.txt

          # Extract metrics to JSON
          # Parse console output and create benchmark.json

      - name: Store benchmark result
        uses: benchmark-action/github-action-benchmark@v1
        with:
          name: GuionViewer Performance
          tool: 'customSmallerIsBetter'
          output-file-path: benchmark.json
          github-token: ${{ secrets.GITHUB_TOKEN }}
          auto-push: true
          # Alert on 20% regression
          alert-threshold: '120%'
          comment-on-alert: true
          fail-on-alert: false
```

#### Advantages
- ✅ Automatic visualization (charts on GitHub Pages)
- ✅ Regression detection with alerts
- ✅ PR comments with performance comparison
- ✅ Historical tracking over time

#### Disadvantages
- ❌ Requires GitHub Pages setup
- ❌ More complex initial setup

---

### Option 3: Codecov + Custom Metrics (Advanced)

**What**: Use Codecov flags to track performance alongside code coverage
**Where**: Codecov dashboard
**How**: Custom metrics API

#### Implementation

```bash
# In CI after tests
curl -X POST https://codecov.io/api/v2/uploads/custom_metrics \
  -H "Authorization: Bearer $CODECOV_TOKEN" \
  -d '{
    "commit": "'$GITHUB_SHA'",
    "metrics": [
      {
        "name": "parse_time_1000_elements",
        "value": 0.016,
        "unit": "seconds"
      },
      {
        "name": "convert_time_1000_elements",
        "value": 1.127,
        "unit": "seconds"
      }
    ]
  }'
```

#### Advantages
- ✅ Unified dashboard with coverage
- ✅ Professional visualization
- ✅ API for custom analysis

#### Disadvantages
- ❌ Requires Codecov subscription
- ❌ Additional service dependency

---

### Option 4: Custom Database + Dashboard (Production-Grade)

**What**: PostgreSQL/SQLite + Grafana/custom dashboard
**Where**: Self-hosted or cloud service
**How**: POST metrics after each CI run

#### Schema

```sql
CREATE TABLE performance_metrics (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL,
    git_commit VARCHAR(40) NOT NULL,
    branch VARCHAR(255) NOT NULL,
    pr_number INTEGER,
    test_name VARCHAR(255) NOT NULL,
    element_count INTEGER NOT NULL,
    parse_time_ms REAL NOT NULL,
    convert_time_ms REAL NOT NULL,
    sort_time_ms REAL NOT NULL,
    format_time_ms REAL NOT NULL,
    total_time_ms REAL NOT NULL,
    memory_peak_bytes BIGINT,
    platform VARCHAR(50) NOT NULL,
    os_version VARCHAR(50) NOT NULL
);

CREATE INDEX idx_metrics_commit ON performance_metrics(git_commit);
CREATE INDEX idx_metrics_branch ON performance_metrics(branch);
CREATE INDEX idx_metrics_timestamp ON performance_metrics(timestamp DESC);
```

#### CI Integration

```bash
# After running tests, POST to API
curl -X POST https://metrics.yourcompany.com/api/performance \
  -H "Content-Type: application/json" \
  -d @performance_results.json
```

#### Advantages
- ✅ Full control over data
- ✅ Custom queries and analysis
- ✅ Real-time dashboards
- ✅ Long-term trend analysis
- ✅ Can track multiple branches/platforms

#### Disadvantages
- ❌ Requires infrastructure setup
- ❌ Maintenance overhead
- ❌ Overkill for small projects

---

## Recommendation for SwiftCompartido

**Start with Option 2 (GitHub Actions Benchmarking)**

### Why?
1. **Zero infrastructure**: Everything runs on GitHub
2. **Automatic visualization**: Charts on GitHub Pages
3. **PR integration**: Automatic comments with comparisons
4. **Regression alerts**: Configurable thresholds
5. **Free for open source**

### Migration Path
1. **Week 1**: Implement JSON export (Option 1) - quick win
2. **Week 2**: Set up GitHub Actions benchmark action
3. **Future**: Consider Option 4 if project scales significantly

---

## Quick Implementation: JSON Export

Here's the minimal code to add to your existing tests:

```swift
// Add this helper to GuionViewerPerformanceTests

private func recordMetric(
    testName: String,
    elementCount: Int,
    parseTime: TimeInterval,
    convertTime: TimeInterval,
    sortTime: TimeInterval,
    formatTime: TimeInterval
) {
    let metric = PerformanceMetrics(
        testName: testName,
        timestamp: Date(),
        gitCommit: getGitCommit(),
        branch: getGitBranch(),
        elementCount: elementCount,
        parseTime: parseTime,
        convertTime: convertTime,
        sortTime: sortTime,
        formatTime: formatTime,
        totalTime: parseTime + convertTime + sortTime + formatTime,
        elementsPerSecond: Double(elementCount) / (parseTime + convertTime + sortTime + formatTime),
        memoryPeak: nil
    )

    // Append to JSON file
    let metricsFile = FileManager.default.temporaryDirectory
        .appendingPathComponent("performance_results")
        .appendingPathComponent("metrics_\(Date().timeIntervalSince1970).json")

    // ... save logic ...
}

private func getGitCommit() -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    task.arguments = ["rev-parse", "HEAD"]
    let pipe = Pipe()
    task.standardOutput = pipe
    try? task.run()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
}

private func getGitBranch() -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    task.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
    let pipe = Pipe()
    task.standardOutput = pipe
    try? task.run()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
}
```

Then call it in your end-to-end tests:

```swift
func testEndToEnd_ParseAndRender_1000Elements() async throws {
    // ... existing test code ...

    // Record metrics for tracking
    recordMetric(
        testName: "ParseAndRender_1000",
        elementCount: elements.count,
        parseTime: parseTime,
        convertTime: convertTime,
        sortTime: sortTime,
        formatTime: formatTime
    )
}
```

This gives you structured data that can be analyzed with any tool!
