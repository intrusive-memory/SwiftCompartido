//
//  ProviderCategoryTests.swift
//  SwiftHablareTests
//
//  Phase 6A: Tests for ProviderCategory enum
//

import XCTest
@testable import SwiftCompartido

@available(macOS 15.0, iOS 17.0, *)
final class ProviderCategoryTests: XCTestCase {

    // MARK: - Basic Properties Tests

    func testAllCasesArePresent() {
        let categories = ProviderCategory.allCases
        XCTAssertEqual(categories.count, 7, "Should have 7 provider categories")
        XCTAssertTrue(categories.contains(.text))
        XCTAssertTrue(categories.contains(.audio))
        XCTAssertTrue(categories.contains(.image))
        XCTAssertTrue(categories.contains(.video))
        XCTAssertTrue(categories.contains(.embedding))
        XCTAssertTrue(categories.contains(.code))
        XCTAssertTrue(categories.contains(.structuredData))
    }

    func testRawValuesAreCorrect() {
        XCTAssertEqual(ProviderCategory.text.rawValue, "text")
        XCTAssertEqual(ProviderCategory.audio.rawValue, "audio")
        XCTAssertEqual(ProviderCategory.image.rawValue, "image")
        XCTAssertEqual(ProviderCategory.video.rawValue, "video")
        XCTAssertEqual(ProviderCategory.embedding.rawValue, "embedding")
        XCTAssertEqual(ProviderCategory.code.rawValue, "code")
        XCTAssertEqual(ProviderCategory.structuredData.rawValue, "structuredData")
    }

    func testIdentifiableConformance() {
        let category = ProviderCategory.text
        XCTAssertEqual(category.id, category.rawValue)
    }

    // MARK: - Display Properties Tests

    func testDisplayNames() {
        XCTAssertEqual(ProviderCategory.text.displayName, "Text Generation")
        XCTAssertEqual(ProviderCategory.audio.displayName, "Audio Generation")
        XCTAssertEqual(ProviderCategory.image.displayName, "Image Generation")
        XCTAssertEqual(ProviderCategory.video.displayName, "Video Generation")
        XCTAssertEqual(ProviderCategory.embedding.displayName, "Embeddings")
        XCTAssertEqual(ProviderCategory.code.displayName, "Code Generation")
        XCTAssertEqual(ProviderCategory.structuredData.displayName, "Structured Data")
    }

    func testSymbolNames() {
        XCTAssertEqual(ProviderCategory.text.symbolName, "text.bubble")
        XCTAssertEqual(ProviderCategory.audio.symbolName, "waveform")
        XCTAssertEqual(ProviderCategory.image.symbolName, "photo")
        XCTAssertEqual(ProviderCategory.video.symbolName, "video")
        XCTAssertEqual(ProviderCategory.embedding.symbolName, "point.3.filled.connected.trianglepath.dotted")
        XCTAssertEqual(ProviderCategory.code.symbolName, "chevron.left.forwardslash.chevron.right")
        XCTAssertEqual(ProviderCategory.structuredData.symbolName, "tablecells")
    }

    func testDescriptions() {
        XCTAssertFalse(ProviderCategory.text.description.isEmpty)
        XCTAssertFalse(ProviderCategory.audio.description.isEmpty)
        XCTAssertFalse(ProviderCategory.image.description.isEmpty)
        XCTAssertFalse(ProviderCategory.video.description.isEmpty)
        XCTAssertFalse(ProviderCategory.embedding.description.isEmpty)
        XCTAssertFalse(ProviderCategory.code.description.isEmpty)
        XCTAssertFalse(ProviderCategory.structuredData.description.isEmpty)
    }

    // MARK: - File Storage Hints Tests

    func testTypicalSizeRanges() {
        // Text is small
        if let textRange = ProviderCategory.text.typicalSizeRange {
            XCTAssertGreaterThan(textRange.upperBound, textRange.lowerBound)
            XCTAssertLessThan(textRange.upperBound, 1_000_000) // < 1MB
        } else {
            XCTFail("Text should have a typical size range")
        }

        // Audio is large
        if let audioRange = ProviderCategory.audio.typicalSizeRange {
            XCTAssertGreaterThan(audioRange.upperBound, 1_000_000) // > 1MB
        } else {
            XCTFail("Audio should have a typical size range")
        }

        // Video is very large
        if let videoRange = ProviderCategory.video.typicalSizeRange {
            XCTAssertGreaterThan(videoRange.upperBound, 100_000) // > 100KB
        } else {
            XCTFail("Video should have a typical size range")
        }
    }

    func testTypicallyNeedsFileStorage() {
        // Small categories don't need file storage
        XCTAssertFalse(ProviderCategory.text.typicallyNeedsFileStorage)
        XCTAssertFalse(ProviderCategory.code.typicallyNeedsFileStorage)

        // Large categories need file storage
        XCTAssertTrue(ProviderCategory.audio.typicallyNeedsFileStorage)
        XCTAssertTrue(ProviderCategory.image.typicallyNeedsFileStorage)
        XCTAssertTrue(ProviderCategory.video.typicallyNeedsFileStorage)

        // Variable-size categories depend on estimatedMaxSize
        XCTAssertFalse(ProviderCategory.embedding.typicallyNeedsFileStorage)
        XCTAssertFalse(ProviderCategory.structuredData.typicallyNeedsFileStorage)
    }

    // MARK: - Codable Tests

    func testCodableRoundTrip() throws {
        for category in ProviderCategory.allCases {
            let encoded = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(ProviderCategory.self, from: encoded)
            XCTAssertEqual(decoded, category)
        }
    }

    func testDecodingFromRawValue() throws {
        let json = "\"text\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ProviderCategory.self, from: json)
        XCTAssertEqual(decoded, .text)
    }

    // MARK: - Sendable Conformance Tests

    func testSendableConformance() async {
        // Should be able to pass across actor boundaries
        let category = ProviderCategory.text

        await Task {
            XCTAssertEqual(category, .text)
        }.value
    }
}
