//
//  ProviderCategoryTests.swift
//  SwiftHablareTests
//
//  Phase 6A: Tests for ProviderCategory enum
//

import Testing
@testable import SwiftCompartido

struct ProviderCategoryTests {

    // MARK: - Basic Properties Tests

    @Test func testAllCasesArePresent() {
        let categories = ProviderCategory.allCases
        #expect(categories.count == 7, "Should have 7 provider categories")
        #expect(categories.contains(.text))
        #expect(categories.contains(.audio))
        #expect(categories.contains(.image))
        #expect(categories.contains(.video))
        #expect(categories.contains(.embedding))
        #expect(categories.contains(.code))
        #expect(categories.contains(.structuredData))
    }

    @Test func testRawValuesAreCorrect() {
        #expect(ProviderCategory.text.rawValue == "text")
        #expect(ProviderCategory.audio.rawValue == "audio")
        #expect(ProviderCategory.image.rawValue == "image")
        #expect(ProviderCategory.video.rawValue == "video")
        #expect(ProviderCategory.embedding.rawValue == "embedding")
        #expect(ProviderCategory.code.rawValue == "code")
        #expect(ProviderCategory.structuredData.rawValue == "structuredData")
    }

    @Test func testIdentifiableConformance() {
        let category = ProviderCategory.text
        #expect(category.id == category.rawValue)
    }

    // MARK: - Display Properties Tests

    @Test func testDisplayNames() {
        #expect(ProviderCategory.text.displayName == "Text Generation")
        #expect(ProviderCategory.audio.displayName == "Audio Generation")
        #expect(ProviderCategory.image.displayName == "Image Generation")
        #expect(ProviderCategory.video.displayName == "Video Generation")
        #expect(ProviderCategory.embedding.displayName == "Embeddings")
        #expect(ProviderCategory.code.displayName == "Code Generation")
        #expect(ProviderCategory.structuredData.displayName == "Structured Data")
    }

    @Test func testSymbolNames() {
        #expect(ProviderCategory.text.symbolName == "text.bubble")
        #expect(ProviderCategory.audio.symbolName == "waveform")
        #expect(ProviderCategory.image.symbolName == "photo")
        #expect(ProviderCategory.video.symbolName == "video")
        #expect(ProviderCategory.embedding.symbolName == "point.3.filled.connected.trianglepath.dotted")
        #expect(ProviderCategory.code.symbolName == "chevron.left.forwardslash.chevron.right")
        #expect(ProviderCategory.structuredData.symbolName == "tablecells")
    }

    @Test func testDescriptions() {
        #expect(!ProviderCategory.text.description.isEmpty)
        #expect(!ProviderCategory.audio.description.isEmpty)
        #expect(!ProviderCategory.image.description.isEmpty)
        #expect(!ProviderCategory.video.description.isEmpty)
        #expect(!ProviderCategory.embedding.description.isEmpty)
        #expect(!ProviderCategory.code.description.isEmpty)
        #expect(!ProviderCategory.structuredData.description.isEmpty)
    }

    // MARK: - File Storage Hints Tests

    @Test func testTypicalSizeRanges() {
        // Text is small
        if let textRange = ProviderCategory.text.typicalSizeRange {
            #expect(textRange.upperBound > textRange.lowerBound)
            #expect(textRange.upperBound < 1_000_000) // < 1MB
        } else {
            Issue.record("Text should have a typical size range")
        }

        // Audio is large
        if let audioRange = ProviderCategory.audio.typicalSizeRange {
            #expect(audioRange.upperBound > 1_000_000) // > 1MB
        } else {
            Issue.record("Audio should have a typical size range")
        }

        // Video is very large
        if let videoRange = ProviderCategory.video.typicalSizeRange {
            #expect(videoRange.upperBound > 100_000) // > 100KB
        } else {
            Issue.record("Video should have a typical size range")
        }
    }

    @Test func testTypicallyNeedsFileStorage() {
        // Small categories don't need file storage
        #expect(!ProviderCategory.text.typicallyNeedsFileStorage)
        #expect(!ProviderCategory.code.typicallyNeedsFileStorage)

        // Large categories need file storage
        #expect(ProviderCategory.audio.typicallyNeedsFileStorage)
        #expect(ProviderCategory.image.typicallyNeedsFileStorage)
        #expect(ProviderCategory.video.typicallyNeedsFileStorage)

        // Variable-size categories depend on estimatedMaxSize
        #expect(!ProviderCategory.embedding.typicallyNeedsFileStorage)
        #expect(!ProviderCategory.structuredData.typicallyNeedsFileStorage)
    }

    // MARK: - Codable Tests

    @Test func testCodableRoundTrip() throws {
        for category in ProviderCategory.allCases {
            let encoded = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(ProviderCategory.self, from: encoded)
            #expect(decoded == category)
        }
    }

    @Test func testDecodingFromRawValue() throws {
        let json = "\"text\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ProviderCategory.self, from: json)
        #expect(decoded == .text)
    }

    // MARK: - Sendable Conformance Tests

    @Test func testSendableConformance() async {
        // Should be able to pass across actor boundaries
        let category = ProviderCategory.text

        await Task {
            #expect(category == .text)
        }.value
    }
}
