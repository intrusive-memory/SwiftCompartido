//
//  PerformanceMetricsTracker.swift
//  SwiftCompartidoTests
//
//  Helper for tracking and comparing performance metrics across builds.
//

import Foundation

/// A single performance measurement
public struct PerformanceMetric: Codable, Sendable {
  let testName: String
  let timestamp: Date
  let gitCommit: String
  let branch: String
  let prNumber: String?
  let elementCount: Int
  let parseTime: TimeInterval
  let convertTime: TimeInterval
  let sortTime: TimeInterval
  let formatTime: TimeInterval
  let totalTime: TimeInterval
  let memoryPeakBytes: Int64?
  let platform: String
  let osVersion: String

  var elementsPerSecond: Double {
    elementCount > 0 ? Double(elementCount) / totalTime : 0
  }

  var averageTimePerElement: TimeInterval {
    elementCount > 0 ? totalTime / Double(elementCount) : 0
  }
}

/// Collection of performance metrics for a single test run
public struct PerformanceReport: Codable, Sendable {
  let reportID: String
  let timestamp: Date
  let platform: String
  let osVersion: String
  let gitCommit: String
  let branch: String
  let prNumber: String?
  let metrics: [PerformanceMetric]

  var summary: String {
    """
    Performance Report: \(reportID)
    Timestamp: \(timestamp)
    Platform: \(platform)
    OS: \(osVersion)
    Commit: \(gitCommit)
    Branch: \(branch)
    PR: \(prNumber ?? "N/A")
    Metrics: \(metrics.count) tests
    """
  }
}

/// Tracks and persists performance metrics for build-to-build comparison
public actor PerformanceMetricsTracker {

  /// Shared instance
  public static let shared = PerformanceMetricsTracker()

  /// Storage directory for performance metrics
  private let storageDirectory: URL

  /// Current report being built
  private var currentReport: PerformanceReport?

  /// All metrics collected in current session
  private var collectedMetrics: [PerformanceMetric] = []

  private init() {
    // Use /tmp/performance_results for CI artifact collection
    self.storageDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("performance_results")

    // Ensure directory exists
    try? FileManager.default.createDirectory(
      at: storageDirectory,
      withIntermediateDirectories: true
    )
  }

  /// Records a performance metric
  public func recordMetric(
    testName: String,
    elementCount: Int,
    parseTime: TimeInterval,
    convertTime: TimeInterval,
    sortTime: TimeInterval,
    formatTime: TimeInterval,
    memoryPeakBytes: Int64? = nil
  ) {
    let metric = PerformanceMetric(
      testName: testName,
      timestamp: Date(),
      gitCommit: Self.getGitCommit(),
      branch: Self.getGitBranch(),
      prNumber: Self.getPRNumber(),
      elementCount: elementCount,
      parseTime: parseTime,
      convertTime: convertTime,
      sortTime: sortTime,
      formatTime: formatTime,
      totalTime: parseTime + convertTime + sortTime + formatTime,
      memoryPeakBytes: memoryPeakBytes,
      platform: Self.getPlatform(),
      osVersion: Self.getOSVersion()
    )

    collectedMetrics.append(metric)

    // Print summary for console output
    print(
      """

      📊 METRIC RECORDED: \(testName)
      Elements: \(elementCount)
      Total Time: \(String(format: "%.3f", metric.totalTime))s
      Elements/sec: \(String(format: "%.0f", metric.elementsPerSecond))
      Avg per element: \(String(format: "%.4f", metric.averageTimePerElement))s
      """)
  }

  /// Saves all collected metrics to JSON file
  public func saveReport() throws {
    guard !collectedMetrics.isEmpty else {
      print("⚠️  No metrics collected, skipping report")
      return
    }

    let report = PerformanceReport(
      reportID: UUID().uuidString,
      timestamp: Date(),
      platform: Self.getPlatform(),
      osVersion: Self.getOSVersion(),
      gitCommit: Self.getGitCommit(),
      branch: Self.getGitBranch(),
      prNumber: Self.getPRNumber(),
      metrics: collectedMetrics
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    let data = try encoder.encode(report)

    // Save with timestamp in filename for easy sorting
    let formatter = ISO8601DateFormatter()
    let timestamp = formatter.string(from: report.timestamp)
      .replacingOccurrences(of: ":", with: "-")

    let filename = "performance_\(timestamp)_\(Self.getGitCommit().prefix(7)).json"
    let fileURL = storageDirectory.appendingPathComponent(filename)

    try data.write(to: fileURL)

    print(
      """

      ✅ Performance report saved:
      \(fileURL.path)

      \(report.summary)
      """)
  }

  /// Loads and compares with previous report
  public func compareWithBaseline() throws -> PerformanceComparison? {
    let files = try FileManager.default.contentsOfDirectory(
      at: storageDirectory,
      includingPropertiesForKeys: [.creationDateKey],
      options: .skipsHiddenFiles
    )
    .filter { $0.pathExtension == "json" }
    .sorted { url1, url2 in
      let date1 =
        (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
      let date2 =
        (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
      return date1 > date2
    }

    guard files.count >= 2 else {
      print("ℹ️  Not enough reports for comparison (need at least 2)")
      return nil
    }

    // Compare current (newest) with baseline (second newest)
    let currentURL = files[0]
    let baselineURL = files[1]

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let currentData = try Data(contentsOf: currentURL)
    let baselineData = try Data(contentsOf: baselineURL)

    let current = try decoder.decode(PerformanceReport.self, from: currentData)
    let baseline = try decoder.decode(PerformanceReport.self, from: baselineData)

    return PerformanceComparison(current: current, baseline: baseline)
  }

  // MARK: - System Information Helpers

  private static func getGitCommit() -> String {
    executeCommand("/usr/bin/git", args: ["rev-parse", "HEAD"])
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func getGitBranch() -> String {
    executeCommand("/usr/bin/git", args: ["rev-parse", "--abbrev-ref", "HEAD"])
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func getPRNumber() -> String? {
    // Try to get from GitHub Actions environment
    if let prNumber = ProcessInfo.processInfo.environment["GITHUB_PR_NUMBER"] {
      return prNumber
    }

    // Try to extract from branch name (e.g., "pr/123")
    let branch = getGitBranch()
    if branch.hasPrefix("pr/"), let number = branch.split(separator: "/").last {
      return String(number)
    }

    return nil
  }

  private static func getPlatform() -> String {
    #if os(iOS)
      return "iOS Simulator"
    #elseif os(macOS)
      return "macOS"
    #else
      return "Unknown"
    #endif
  }

  private static func getOSVersion() -> String {
    let osVersion = ProcessInfo.processInfo.operatingSystemVersion
    return "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
  }

  private static func executeCommand(_ command: String, args: [String]) -> String {
    #if os(macOS)
      let task = Process()
      task.executableURL = URL(fileURLWithPath: command)
      task.arguments = args
      let pipe = Pipe()
      task.standardOutput = pipe
      task.standardError = Pipe()

      do {
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? "unknown"
      } catch {
        return "unknown"
      }
    #else
      // Process is not available on iOS
      return "unavailable on iOS"
    #endif
  }
}

/// Comparison between two performance reports
public struct PerformanceComparison: Sendable {
  let current: PerformanceReport
  let baseline: PerformanceReport

  /// Metrics grouped by test name for comparison
  var metricComparisons: [String: MetricComparison] {
    var comparisons: [String: MetricComparison] = [:]

    for currentMetric in current.metrics {
      if let baselineMetric = baseline.metrics.first(where: {
        $0.testName == currentMetric.testName
      }) {
        comparisons[currentMetric.testName] = MetricComparison(
          current: currentMetric,
          baseline: baselineMetric
        )
      }
    }

    return comparisons
  }

  /// Formatted comparison report
  var summary: String {
    var lines = [
      "═══════════════════════════════════════════════",
      "PERFORMANCE COMPARISON",
      "═══════════════════════════════════════════════",
      "Current:  \(current.gitCommit.prefix(7)) (\(current.branch))",
      "Baseline: \(baseline.gitCommit.prefix(7)) (\(baseline.branch))",
      "═══════════════════════════════════════════════",
      "",
    ]

    for (testName, comparison) in metricComparisons.sorted(by: { $0.key < $1.key }) {
      lines.append(contentsOf: comparison.formattedComparison(testName: testName))
      lines.append("")
    }

    return lines.joined(separator: "\n")
  }
}

/// Comparison between two metrics for the same test
public struct MetricComparison: Sendable {
  let current: PerformanceMetric
  let baseline: PerformanceMetric

  var totalTimeDelta: TimeInterval {
    current.totalTime - baseline.totalTime
  }

  var totalTimePercentChange: Double {
    baseline.totalTime > 0 ? (totalTimeDelta / baseline.totalTime) * 100 : 0
  }

  var isRegression: Bool {
    totalTimePercentChange > 10  // More than 10% slower
  }

  var isImprovement: Bool {
    totalTimePercentChange < -10  // More than 10% faster
  }

  func formattedComparison(testName: String) -> [String] {
    let icon = isRegression ? "⚠️  REGRESSION" : (isImprovement ? "✅ IMPROVEMENT" : "➡️  STABLE")
    let sign = totalTimeDelta >= 0 ? "+" : ""

    return [
      "\(icon): \(testName)",
      "  Total Time:    \(String(format: "%.3f", baseline.totalTime))s → \(String(format: "%.3f", current.totalTime))s (\(sign)\(String(format: "%.1f", totalTimePercentChange))%)",
      "  Parse:         \(String(format: "%.3f", baseline.parseTime))s → \(String(format: "%.3f", current.parseTime))s",
      "  Convert:       \(String(format: "%.3f", baseline.convertTime))s → \(String(format: "%.3f", current.convertTime))s",
      "  Elements/sec:  \(String(format: "%.0f", baseline.elementsPerSecond)) → \(String(format: "%.0f", current.elementsPerSecond))",
    ]
  }
}
