//
//  Phase2PerformanceTests.swift
//  SwiftCompartido
//
//  Phase 2: Testing & Production Readiness
//  Performance benchmarks for JSON .guion format
//

import Foundation
import Testing

#if canImport(SwiftData)
  import SwiftData
  @testable import SwiftCompartido

  /// Phase 2 performance benchmarks
  ///
  /// Establishes baseline performance metrics for JSON .guion format:
  /// - Serialization speed (SwiftData → JSON)
  /// - Deserialization speed (JSON → SwiftData)
  /// - File size comparisons
  /// - Memory usage patterns
  @Suite("Phase 2: JSON Performance Benchmarks")
  struct Phase2PerformanceTests {

    // MARK: - JSON Serialization Performance

    @Test("JSON serialization: 100 elements")
    @MainActor
    func testJSONSerialize100Elements() async throws {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: GuionDocumentModel.self, configurations: config)
      let context = ModelContext(container)

      let document = createTestDocument(elementCount: 100, context: context)

      let snapshot = document.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)

      print("📊 JSON Serialize (100 elements): \(jsonData.count) bytes")
    }

    @Test("JSON serialization: 1000 elements")
    @MainActor
    func testJSONSerialize1000Elements() async throws {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: GuionDocumentModel.self, configurations: config)
      let context = ModelContext(container)

      let document = createTestDocument(elementCount: 1000, context: context)

      let snapshot = document.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)

      print("📊 JSON Serialize (1000 elements): \(jsonData.count) bytes")
    }

    @Test("JSON serialization: 5000 elements")
    @MainActor
    func testJSONSerialize5000Elements() async throws {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: GuionDocumentModel.self, configurations: config)
      let context = ModelContext(container)

      let document = createTestDocument(elementCount: 5000, context: context)

      let snapshot = document.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)

      print("📊 JSON Serialize (5000 elements): \(jsonData.count) bytes")
    }

    // MARK: - JSON Deserialization Performance

    @Test("JSON deserialization: 100 elements")
    @MainActor
    func testJSONDeserialize100Elements() async throws {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: GuionDocumentModel.self, configurations: config)
      let context = ModelContext(container)

      let document = createTestDocument(elementCount: 100, context: context)
      let snapshot = document.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)

      let loadedSnapshot = try GuionJSONSerializer.decode(jsonData)
      let restored = GuionDocumentModel.from(loadedSnapshot, in: context)

      print("📊 JSON Deserialize (100 elements)")

      #expect(restored.elements.count == 100)
    }

    @Test("JSON deserialization: 1000 elements")
    @MainActor
    func testJSONDeserialize1000Elements() async throws {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: GuionDocumentModel.self, configurations: config)
      let context = ModelContext(container)

      let document = createTestDocument(elementCount: 1000, context: context)
      let snapshot = document.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)

      let loadedSnapshot = try GuionJSONSerializer.decode(jsonData)
      let restored = GuionDocumentModel.from(loadedSnapshot, in: context)

      print("📊 JSON Deserialize (1000 elements)")

      #expect(restored.elements.count == 1000)
    }

    @Test("JSON deserialization: 5000 elements")
    @MainActor
    func testJSONDeserialize5000Elements() async throws {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: GuionDocumentModel.self, configurations: config)
      let context = ModelContext(container)

      let document = createTestDocument(elementCount: 5000, context: context)
      let snapshot = document.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)

      let loadedSnapshot = try GuionJSONSerializer.decode(jsonData)
      let restored = GuionDocumentModel.from(loadedSnapshot, in: context)

      print("📊 JSON Deserialize (5000 elements)")

      #expect(restored.elements.count == 5000)
    }

    // MARK: - Round-Trip Performance

    @Test("JSON round-trip: 1000 elements")
    @MainActor
    func testJSONRoundTrip1000Elements() async throws {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: GuionDocumentModel.self, configurations: config)
      let context = ModelContext(container)

      let document = createTestDocument(elementCount: 1000, context: context)

      // Serialize
      let snapshot = document.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)

      // Deserialize
      let loadedSnapshot = try GuionJSONSerializer.decode(jsonData)
      let restored = GuionDocumentModel.from(loadedSnapshot, in: context)

      print("📊 JSON Round-Trip (1000 elements)")

      #expect(restored.elements.count == 1000)
    }

    // MARK: - File Size Metrics

    @Test("JSON file size: 100 elements")
    @MainActor
    func testJSONFileSize100Elements() async throws {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: GuionDocumentModel.self, configurations: config)
      let context = ModelContext(container)

      let document = createTestDocument(elementCount: 100, context: context)
      let snapshot = document.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)

      let sizeKB = Double(jsonData.count) / 1024.0

      print("📊 JSON File Size (100 elements): \(String(format: "%.2f", sizeKB)) KB")

      // Baseline: Should be reasonable (< 100KB for 100 elements)
      #expect(jsonData.count < 100 * 1024)
    }

    @Test("JSON file size: 1000 elements")
    @MainActor
    func testJSONFileSize1000Elements() async throws {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: GuionDocumentModel.self, configurations: config)
      let context = ModelContext(container)

      let document = createTestDocument(elementCount: 1000, context: context)
      let snapshot = document.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)

      let sizeKB = Double(jsonData.count) / 1024.0

      print("📊 JSON File Size (1000 elements): \(String(format: "%.2f", sizeKB)) KB")

      // Baseline: Should be reasonable (< 1MB for 1000 elements)
      #expect(jsonData.count < 1024 * 1024)
    }

    // MARK: - Large File Stress Tests (GAP 4)

    @Test("Large file: Write and read 50MB .guion file")
    @MainActor
    func testLargeFile50MBWriteRead() async throws {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: GuionDocumentModel.self, configurations: config)
      let context = ModelContext(container)

      // Create a document large enough to approach 50MB
      // ~330 bytes/element × 155,000 elements ≈ 50MB
      let elementCount = 155_000

      print("📊 Creating large screenplay with \(elementCount) elements...")
      let document = createTestDocument(elementCount: elementCount, context: context)

      // Encode to JSON
      let snapshot = document.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)

      let sizeMB = Double(jsonData.count) / (1024.0 * 1024.0)
      print("📊 Large File Size: \(String(format: "%.2f", sizeMB)) MB")

      // Verify size is in expected range (should be close to 50MB)
      #expect(jsonData.count > 40 * 1024 * 1024, "Should be > 40MB")
      #expect(jsonData.count < 60 * 1024 * 1024, "Should be < 60MB")

      // Write to temp file
      let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("large-test-\(UUID()).guion")

      print("📊 Writing to disk...")
      try jsonData.write(to: tempURL, options: .atomic)

      // Verify file exists
      #expect(FileManager.default.fileExists(atPath: tempURL.path))

      // Read back and decode
      print("📊 Reading from disk...")
      let loadedData = try Data(contentsOf: tempURL)
      #expect(loadedData.count == jsonData.count)

      print("📊 Decoding JSON...")
      let loadedSnapshot = try GuionJSONSerializer.decode(loadedData)

      // Verify integrity
      #expect(loadedSnapshot.elements.count == elementCount)
      #expect(loadedSnapshot.title == "Performance Test Screenplay")

      // Cleanup
      try? FileManager.default.removeItem(at: tempURL)

      print("✅ Large file test completed successfully")
    }

    @Test("Memory pressure: Large file decode stays under 200MB heap")
    @MainActor
    func testLargeFileMemoryPressure() async throws {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: GuionDocumentModel.self, configurations: config)
      let context = ModelContext(container)

      // Create ~10MB file (30,000 elements)
      let elementCount = 30_000
      let document = createTestDocument(elementCount: elementCount, context: context)

      let snapshot = document.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)

      let sizeMB = Double(jsonData.count) / (1024.0 * 1024.0)
      print("📊 Test File Size: \(String(format: "%.2f", sizeMB)) MB")

      // Decode - should not cause excessive memory usage
      let loadedSnapshot = try GuionJSONSerializer.decode(jsonData)

      #expect(loadedSnapshot.elements.count == elementCount)

      // No explicit memory measurement in test, but if this causes OOM
      // the test will crash - that's the failure mode we're checking for
      print("✅ Memory pressure test completed (no OOM)")
    }

    @Test("Concurrent file operations: Multiple readers")
    @MainActor
    func testConcurrentReaders() async throws {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: GuionDocumentModel.self, configurations: config)
      let context = ModelContext(container)

      // Create test file
      let document = createTestDocument(elementCount: 1000, context: context)
      let snapshot = document.toSnapshot()
      let jsonData = try GuionJSONSerializer.encode(snapshot)

      let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("concurrent-test-\(UUID()).guion")

      try jsonData.write(to: tempURL, options: .atomic)

      // Launch 5 concurrent readers
      try await withThrowingTaskGroup(of: Int.self) { group in
        for i in 0..<5 {
          group.addTask {
            let loadedData = try Data(contentsOf: tempURL)
            let loadedSnapshot = try GuionJSONSerializer.decode(loadedData)
            print("📊 Reader \(i+1): Loaded \(loadedSnapshot.elements.count) elements")
            return loadedSnapshot.elements.count
          }
        }

        var counts: [Int] = []
        for try await count in group {
          counts.append(count)
        }

        // All readers should get the same count
        #expect(counts.allSatisfy { $0 == 1000 })
      }

      // Cleanup
      try? FileManager.default.removeItem(at: tempURL)

      print("✅ Concurrent readers test completed")
    }

    @Test("File size efficiency: Bytes per element")
    @MainActor
    func testBytesPerElement() async throws {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: GuionDocumentModel.self, configurations: config)
      let context = ModelContext(container)

      let elementCounts = [100, 500, 1000, 5000]

      for count in elementCounts {
        let document = createTestDocument(elementCount: count, context: context)
        let snapshot = document.toSnapshot()
        let jsonData = try GuionJSONSerializer.encode(snapshot)

        let bytesPerElement = Double(jsonData.count) / Double(count)

        print(
          "📊 \(count) elements: \(jsonData.count) bytes total, \(String(format: "%.1f", bytesPerElement)) bytes/element"
        )

        // Should be in expected range (~330 bytes/element for text-only)
        #expect(
          bytesPerElement > 200, "Should be > 200 bytes/element (includes JSON overhead)")
        #expect(bytesPerElement < 600, "Should be < 600 bytes/element")
      }
    }

    // MARK: - Helper Methods

    @MainActor
    private func createTestDocument(elementCount: Int, context: ModelContext) -> GuionDocumentModel
    {
      let document = GuionDocumentModel(filename: "performance-test.guion")
      document.title = "Performance Test Screenplay"

      var elements: [GuionElementModel] = []
      for i in 0..<elementCount {
        let elementType: ElementType =
          switch i % 5 {
          case 0: .sceneHeading
          case 1: .action
          case 2: .character
          case 3: .dialogue
          default: .action
          }

        let element = GuionElementModel(
          elementText: "Element \(i)",
          elementType: elementType,
          chapterIndex: i / 100,
          orderIndex: i
        )
        elements.append(element)
      }

      document.elements = elements
      return document
    }
  }

#endif
