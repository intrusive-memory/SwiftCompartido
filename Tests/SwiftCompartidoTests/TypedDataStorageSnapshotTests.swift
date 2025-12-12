//
//  TypedDataStorageSnapshotTests.swift
//  SwiftCompartidoTests
//
//  Unit tests for TypedDataStorageSnapshot (Phase 1)
//

import XCTest
@testable import SwiftCompartido

final class TypedDataStorageSnapshotTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInit_TextContent() {
        let snapshot = TypedDataStorageSnapshot(
            providerId: "openai",
            requestorID: "gpt-4",
            mimeType: "text/plain",
            prompt: "Generate text",
            textValue: "Hello, world!",
            wordCount: 2,
            characterCount: 13
        )

        XCTAssertNotNil(snapshot.id)
        XCTAssertEqual(snapshot.providerId, "openai")
        XCTAssertEqual(snapshot.requestorID, "gpt-4")
        XCTAssertEqual(snapshot.mimeType, "text/plain")
        XCTAssertEqual(snapshot.prompt, "Generate text")
        XCTAssertEqual(snapshot.textValue, "Hello, world!")
        XCTAssertEqual(snapshot.wordCount, 2)
        XCTAssertEqual(snapshot.characterCount, 13)
        XCTAssertNil(snapshot.binaryValue)
    }

    func testInit_AudioContent() {
        let audioData = Data([1, 2, 3, 4, 5])
        let snapshot = TypedDataStorageSnapshot(
            providerId: "elevenlabs",
            requestorID: "tts.rachel",
            mimeType: "audio/mpeg",
            prompt: "Generate speech",
            binaryValue: audioData,
            durationSeconds: 5.5,
            voiceID: "rachel",
            voiceName: "Rachel"
        )

        XCTAssertEqual(snapshot.mimeType, "audio/mpeg")
        XCTAssertEqual(snapshot.binaryValue, audioData)
        XCTAssertEqual(snapshot.durationSeconds, 5.5)
        XCTAssertEqual(snapshot.voiceID, "rachel")
        XCTAssertEqual(snapshot.voiceName, "Rachel")
        XCTAssertNil(snapshot.textValue)
    }

    func testInit_AudioContentConvenience() {
        let audioData = Data([1, 2, 3])
        let snapshot = TypedDataStorageSnapshot(
            audioData: audioData,
            duration: 3.5,
            voiceID: "voice-123",
            voiceName: "Samantha",
            providerId: "macos",
            requestorID: "tts",
            prompt: "Test"
        )

        XCTAssertEqual(snapshot.mimeType, "audio/mpeg")
        XCTAssertEqual(snapshot.binaryValue, audioData)
        XCTAssertEqual(snapshot.durationSeconds, 3.5)
        XCTAssertEqual(snapshot.voiceID, "voice-123")
        XCTAssertEqual(snapshot.voiceName, "Samantha")
    }

    func testInit_ImageContent() {
        let imageData = Data([0xFF, 0xD8, 0xFF]) // JPEG header
        let snapshot = TypedDataStorageSnapshot(
            providerId: "openai",
            requestorID: "dall-e-3",
            mimeType: "image/jpeg",
            prompt: "Generate image",
            binaryValue: imageData,
            imageFormat: "jpeg",
            width: 1024,
            height: 1024,
            revisedPrompt: "A beautiful sunset"
        )

        XCTAssertEqual(snapshot.mimeType, "image/jpeg")
        XCTAssertEqual(snapshot.imageFormat, "jpeg")
        XCTAssertEqual(snapshot.width, 1024)
        XCTAssertEqual(snapshot.height, 1024)
        XCTAssertEqual(snapshot.revisedPrompt, "A beautiful sunset")
    }

    func testInit_EmbeddingContent() {
        let embeddingData = Data(repeating: 0, count: 100)
        let snapshot = TypedDataStorageSnapshot(
            providerId: "openai",
            requestorID: "text-embedding-3-small",
            mimeType: "application/x-embedding",
            prompt: "Embed text",
            binaryValue: embeddingData,
            dimensions: 1536,
            inputText: "Text to embed"
        )

        XCTAssertEqual(snapshot.mimeType, "application/x-embedding")
        XCTAssertEqual(snapshot.dimensions, 1536)
        XCTAssertEqual(snapshot.inputText, "Text to embed")
    }

    // MARK: - Metadata Tests

    func testMetadata_TextSpecific() {
        let snapshot = TypedDataStorageSnapshot(
            providerId: "openai",
            requestorID: "gpt-4",
            mimeType: "text/plain",
            prompt: "Test",
            textValue: "Test content",
            wordCount: 2,
            characterCount: 12,
            languageCode: "en",
            tokenCount: 5,
            completionTokens: 3,
            promptTokens: 2
        )

        XCTAssertEqual(snapshot.wordCount, 2)
        XCTAssertEqual(snapshot.characterCount, 12)
        XCTAssertEqual(snapshot.languageCode, "en")
        XCTAssertEqual(snapshot.tokenCount, 5)
        XCTAssertEqual(snapshot.completionTokens, 3)
        XCTAssertEqual(snapshot.promptTokens, 2)
    }

    func testMetadata_AudioSpecific() {
        let snapshot = TypedDataStorageSnapshot(
            providerId: "elevenlabs",
            requestorID: "tts",
            mimeType: "audio/mpeg",
            prompt: "Test",
            binaryValue: Data([1, 2, 3]),
            audioFormat: "mp3",
            durationSeconds: 10.5,
            sampleRate: 44100,
            bitRate: 128000,
            channels: 2
        )

        XCTAssertEqual(snapshot.audioFormat, "mp3")
        XCTAssertEqual(snapshot.durationSeconds, 10.5)
        XCTAssertEqual(snapshot.sampleRate, 44100)
        XCTAssertEqual(snapshot.bitRate, 128000)
        XCTAssertEqual(snapshot.channels, 2)
    }

    func testMetadata_ModelAndCost() {
        let snapshot = TypedDataStorageSnapshot(
            providerId: "openai",
            requestorID: "gpt-4",
            mimeType: "text/plain",
            prompt: "Test",
            textValue: "Test",
            modelIdentifier: "gpt-4-0125-preview",
            estimatedCost: 0.05
        )

        XCTAssertEqual(snapshot.modelIdentifier, "gpt-4-0125-preview")
        XCTAssertEqual(snapshot.estimatedCost, 0.05)
    }

    // MARK: - Codable Tests

    func testCodable_TextContent() throws {
        let original = TypedDataStorageSnapshot(
            providerId: "openai",
            requestorID: "gpt-4",
            mimeType: "text/plain",
            prompt: "Test",
            textValue: "Hello, world!",
            wordCount: 2
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TypedDataStorageSnapshot.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.providerId, original.providerId)
        XCTAssertEqual(decoded.textValue, original.textValue)
        XCTAssertEqual(decoded.wordCount, original.wordCount)
    }

    func testCodable_AudioContent() throws {
        let audioData = Data([1, 2, 3, 4, 5])
        let original = TypedDataStorageSnapshot(
            providerId: "elevenlabs",
            requestorID: "tts.rachel",
            mimeType: "audio/mpeg",
            prompt: "Generate speech",
            binaryValue: audioData,
            durationSeconds: 5.5,
            voiceID: "rachel",
            voiceName: "Rachel"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TypedDataStorageSnapshot.self, from: data)

        XCTAssertEqual(decoded.binaryValue, audioData)
        XCTAssertEqual(decoded.durationSeconds, 5.5)
        XCTAssertEqual(decoded.voiceID, "rachel")
        XCTAssertEqual(decoded.voiceName, "Rachel")
    }

    func testCodable_ImageContent() throws {
        let imageData = Data([0xFF, 0xD8, 0xFF])
        let original = TypedDataStorageSnapshot(
            providerId: "openai",
            requestorID: "dall-e-3",
            mimeType: "image/png",
            prompt: "Generate image",
            binaryValue: imageData,
            imageFormat: "png",
            width: 1024,
            height: 1024
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TypedDataStorageSnapshot.self, from: data)

        XCTAssertEqual(decoded.binaryValue, imageData)
        XCTAssertEqual(decoded.width, 1024)
        XCTAssertEqual(decoded.height, 1024)
    }

    func testCodable_WithDates() throws {
        let generated = Date()
        let modified = Date().addingTimeInterval(3600)

        let original = TypedDataStorageSnapshot(
            providerId: "openai",
            requestorID: "gpt-4",
            mimeType: "text/plain",
            prompt: "Test",
            textValue: "Test",
            generatedAt: generated,
            modifiedAt: modified
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TypedDataStorageSnapshot.self, from: data)

        // Dates should be approximately equal
        XCTAssertEqual(decoded.generatedAt.timeIntervalSince1970,
                     generated.timeIntervalSince1970,
                     accuracy: 1.0)
        XCTAssertEqual(decoded.modifiedAt.timeIntervalSince1970,
                     modified.timeIntervalSince1970,
                     accuracy: 1.0)
    }

    func testCodable_AllMetadata() throws {
        let original = TypedDataStorageSnapshot(
            providerId: "openai",
            requestorID: "gpt-4",
            mimeType: "text/plain",
            prompt: "Test prompt",
            textValue: "Test content",
            modelIdentifier: "gpt-4-0125-preview",
            estimatedCost: 0.05,
            wordCount: 2,
            characterCount: 12,
            languageCode: "en",
            tokenCount: 5,
            completionTokens: 3,
            promptTokens: 2
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TypedDataStorageSnapshot.self, from: data)

        XCTAssertEqual(decoded.modelIdentifier, original.modelIdentifier)
        XCTAssertEqual(decoded.estimatedCost, original.estimatedCost)
        XCTAssertEqual(decoded.wordCount, original.wordCount)
        XCTAssertEqual(decoded.characterCount, original.characterCount)
        XCTAssertEqual(decoded.languageCode, original.languageCode)
        XCTAssertEqual(decoded.tokenCount, original.tokenCount)
    }

    func testCodable_RoundTrip() throws {
        let original = createComplexSnapshot()

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(original)

        let decoded = try JSONDecoder().decode(TypedDataStorageSnapshot.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.providerId, original.providerId)
        XCTAssertEqual(decoded.requestorID, original.requestorID)
        XCTAssertEqual(decoded.mimeType, original.mimeType)
        XCTAssertEqual(decoded.prompt, original.prompt)
    }

    // MARK: - Helper Methods

    private func createComplexSnapshot() -> TypedDataStorageSnapshot {
        TypedDataStorageSnapshot(
            providerId: "elevenlabs",
            requestorID: "tts.rachel",
            mimeType: "audio/mpeg",
            prompt: "Generate dialogue for JANE",
            binaryValue: Data(repeating: 0xFF, count: 1000),
            modelIdentifier: "eleven_multilingual_v2",
            estimatedCost: 0.15,
            audioFormat: "mp3",
            durationSeconds: 5.5,
            sampleRate: 44100,
            bitRate: 128000,
            channels: 1,
            voiceID: "rachel",
            voiceName: "Rachel"
        )
    }
}
