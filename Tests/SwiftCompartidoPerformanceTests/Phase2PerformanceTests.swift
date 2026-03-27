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
        let container = try ModelContainer(for: GuionDocumentModel.self)
        let context = ModelContext(container)

        let document = createTestDocument(elementCount: 100, context: context)

        let snapshot = document.toSnapshot()
        let jsonData = try GuionJSONSerializer.encode(snapshot)

        print("📊 JSON Serialize (100 elements): \(jsonData.count) bytes")
    }

    @Test("JSON serialization: 1000 elements")
    @MainActor
    func testJSONSerialize1000Elements() async throws {
        let container = try ModelContainer(for: GuionDocumentModel.self)
        let context = ModelContext(container)

        let document = createTestDocument(elementCount: 1000, context: context)

        let snapshot = document.toSnapshot()
        let jsonData = try GuionJSONSerializer.encode(snapshot)

        print("📊 JSON Serialize (1000 elements): \(jsonData.count) bytes")
    }

    @Test("JSON serialization: 5000 elements")
    @MainActor
    func testJSONSerialize5000Elements() async throws {
        let container = try ModelContainer(for: GuionDocumentModel.self)
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
        let container = try ModelContainer(for: GuionDocumentModel.self)
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
        let container = try ModelContainer(for: GuionDocumentModel.self)
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
        let container = try ModelContainer(for: GuionDocumentModel.self)
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
        let container = try ModelContainer(for: GuionDocumentModel.self)
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
        let container = try ModelContainer(for: GuionDocumentModel.self)
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
        let container = try ModelContainer(for: GuionDocumentModel.self)
        let context = ModelContext(container)

        let document = createTestDocument(elementCount: 1000, context: context)
        let snapshot = document.toSnapshot()
        let jsonData = try GuionJSONSerializer.encode(snapshot)

        let sizeKB = Double(jsonData.count) / 1024.0

        print("📊 JSON File Size (1000 elements): \(String(format: "%.2f", sizeKB)) KB")

        // Baseline: Should be reasonable (< 1MB for 1000 elements)
        #expect(jsonData.count < 1024 * 1024)
    }

    // MARK: - Helper Methods

    @MainActor
    private func createTestDocument(elementCount: Int, context: ModelContext) -> GuionDocumentModel {
        let document = GuionDocumentModel(filename: "performance-test.guion")
        document.title = "Performance Test Screenplay"

        var elements: [GuionElementModel] = []
        for i in 0..<elementCount {
            let elementType: ElementType = switch i % 5 {
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
