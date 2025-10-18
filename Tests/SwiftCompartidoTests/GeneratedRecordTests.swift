//
//  GeneratedRecordTests.swift
//  SwiftHablareTests
//
//  Phase 5: Tests for GeneratedAudioRecord, GeneratedTextRecord, GeneratedImageRecord, GeneratedEmbeddingRecord
//
//  Note: These tests focus on model initialization, properties, and methods.
//  SwiftData persistence is not tested here as it requires ValueTransformer setup.
//

import XCTest
import SwiftData
@testable import SwiftCompartido

@available(macOS 15.0, iOS 17.0, *)
final class GeneratedRecordTests: XCTestCase {

    // MARK: - GeneratedAudioRecord Tests

    func testGeneratedAudioRecordInitialization() {
        // GIVEN
        let audioData = Data("test audio".utf8)
        let id = UUID()

        // WHEN
        let record = GeneratedAudioRecord(
            id: id,
            providerId: "elevenlabs",
            requestorID: "elevenlabs.tts.rachel",
            audioData: audioData,
            format: "mp3",
            durationSeconds: 2.5,
            sampleRate: 44100,
            bitRate: 128000,
            channels: 2,
            voiceID: "voice-123",
            voiceName: "Rachel",
            prompt: "Generate speech"
        )

        // THEN
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.providerId, "elevenlabs")
        XCTAssertEqual(record.requestorID, "elevenlabs.tts.rachel")
        XCTAssertEqual(record.audioData, audioData)
        XCTAssertEqual(record.format, "mp3")
        XCTAssertEqual(record.durationSeconds, 2.5)
        XCTAssertEqual(record.sampleRate, 44100)
        XCTAssertEqual(record.bitRate, 128000)
        XCTAssertEqual(record.channels, 2)
        XCTAssertEqual(record.voiceID, "voice-123")
        XCTAssertEqual(record.voiceName, "Rachel")
        XCTAssertNotNil(record.generatedAt)
        XCTAssertNotNil(record.modifiedAt)
    }

    func testGeneratedAudioRecordFromTypedData() {
        // GIVEN
        let audioData = Data("test audio".utf8)
        let typedData = GeneratedAudioData(
            audioData: audioData,
            format: .mp3,
            durationSeconds: 3.0,
            sampleRate: 48000,
            bitRate: 192000,
            channels: 2,
            voiceID: "voice-456",
            voiceName: "John",
            model: "eleven_multilingual_v2"
        )

        // WHEN
        let record = GeneratedAudioRecord(
            providerId: "elevenlabs",
            requestorID: "elevenlabs.tts.john",
            data: typedData,
            prompt: "Generate audio"
        )

        // THEN
        XCTAssertEqual(record.audioData, audioData)
        XCTAssertEqual(record.format, "mp3")
        XCTAssertEqual(record.durationSeconds, 3.0)
        XCTAssertEqual(record.sampleRate, 48000)
        XCTAssertEqual(record.voiceID, "voice-456")
        XCTAssertEqual(record.voiceName, "John")
        XCTAssertEqual(record.modelIdentifier, "eleven_multilingual_v2")
    }

    func testGeneratedAudioRecordFileStored() {
        // GIVEN
        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "audio.mp3",
            fileSize: 1024,
            mimeType: "audio/mpeg"
        )

        // WHEN
        let record = GeneratedAudioRecord(
            providerId: "test",
            requestorID: "test.tts",
            audioData: nil,
            format: "mp3",
            durationSeconds: 2.0,
            voiceID: "voice-1",
            voiceName: "Test",
            prompt: "Test",
            fileReference: fileRef
        )

        // THEN
        XCTAssertTrue(record.isFileStored)
        XCTAssertEqual(record.fileSize, 0, "File size is 0 when audioData is nil")
    }

    func testGeneratedAudioRecordTouch() {
        // GIVEN
        let record = GeneratedAudioRecord(
            providerId: "test",
            requestorID: "test.tts",
            audioData: Data("test".utf8),
            format: "mp3",
            durationSeconds: 1.0,
            voiceID: "voice-1",
            voiceName: "Test",
            prompt: "Test"
        )
        let originalModifiedAt = record.modifiedAt

        // WHEN
        Thread.sleep(forTimeInterval: 0.01) // Small delay to ensure timestamp changes
        record.touch()

        // THEN
        XCTAssertGreaterThan(record.modifiedAt, originalModifiedAt)
    }

    // MARK: - GeneratedTextRecord Tests

    func testGeneratedTextRecordInitialization() {
        // GIVEN
        let id = UUID()
        let text = "This is generated text content."

        // WHEN
        let record = GeneratedTextRecord(
            id: id,
            providerId: "openai",
            requestorID: "openai.text.gpt4",
            text: text,
            wordCount: 5,
            characterCount: text.count,
            languageCode: "en",
            modelIdentifier: "gpt-4",
            tokenCount: 10,
            completionTokens: 7,
            promptTokens: 3,
            prompt: "Generate text"
        )

        // THEN
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.providerId, "openai")
        XCTAssertEqual(record.requestorID, "openai.text.gpt4")
        XCTAssertEqual(record.text, text)
        XCTAssertEqual(record.wordCount, 5)
        XCTAssertEqual(record.characterCount, text.count)
        XCTAssertEqual(record.languageCode, "en")
        XCTAssertEqual(record.modelIdentifier, "gpt-4")
        XCTAssertEqual(record.tokenCount, 10)
        XCTAssertNotNil(record.generatedAt)
        XCTAssertNotNil(record.modifiedAt)
    }

    func testGeneratedTextRecordFromTypedData() {
        // GIVEN
        let typedData = GeneratedTextData(
            text: "Generated text content here.",
            model: "gpt-4-turbo",
            completionTokens: 8,
            promptTokens: 5
        )

        // WHEN
        let record = GeneratedTextRecord(
            providerId: "openai",
            requestorID: "openai.text.gpt4turbo",
            data: typedData,
            prompt: "Create content"
        )

        // THEN
        XCTAssertEqual(record.text, typedData.text)
        XCTAssertEqual(record.wordCount, typedData.wordCount)
        XCTAssertEqual(record.characterCount, typedData.characterCount)
        XCTAssertEqual(record.modelIdentifier, "gpt-4-turbo")
        XCTAssertEqual(record.promptTokens, 5)
        XCTAssertEqual(record.completionTokens, 8)
    }

    func testGeneratedTextRecordFileStored() {
        // GIVEN
        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "text.txt",
            fileSize: 50000,
            mimeType: "text/plain"
        )

        // WHEN
        let record = GeneratedTextRecord(
            providerId: "openai",
            requestorID: "openai.text",
            text: nil,  // Stored in file
            wordCount: 5000,
            characterCount: 50000,
            prompt: "Generate long text",
            fileReference: fileRef
        )

        // THEN
        XCTAssertTrue(record.isFileStored)
        XCTAssertNil(record.text, "Text should be nil when file-stored")
    }

    func testGeneratedTextRecordGetTextFromMemory() throws {
        // GIVEN
        let text = "In-memory text"
        let record = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: text,
            wordCount: 2,
            characterCount: text.count,
            prompt: "Test"
        )

        // WHEN
        let retrievedText = try record.getText()

        // THEN
        XCTAssertEqual(retrievedText, text)
    }

    func testGeneratedTextRecordGetTextNoContent() {
        // GIVEN - Record with no text and no file reference
        let record = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: nil,
            wordCount: 0,
            characterCount: 0,
            prompt: "Test"
        )

        // WHEN/THEN
        XCTAssertThrowsError(try record.getText())
    }

    // MARK: - GeneratedImageRecord Tests

    func testGeneratedImageRecordInitialization() {
        // GIVEN
        let imageData = Data("fake image data".utf8)
        let id = UUID()

        // WHEN
        let record = GeneratedImageRecord(
            id: id,
            providerId: "openai",
            requestorID: "openai.image.dalle3",
            imageData: imageData,
            format: "png",
            width: 1024,
            height: 1024,
            prompt: "A beautiful sunset",
            revisedPrompt: "A vivid beautiful sunset over mountains",
            modelIdentifier: "dall-e-3"
        )

        // THEN
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.providerId, "openai")
        XCTAssertEqual(record.requestorID, "openai.image.dalle3")
        XCTAssertEqual(record.imageData, imageData)
        XCTAssertEqual(record.format, "png")
        XCTAssertEqual(record.width, 1024)
        XCTAssertEqual(record.height, 1024)
        XCTAssertEqual(record.prompt, "A beautiful sunset")
        XCTAssertEqual(record.revisedPrompt, "A vivid beautiful sunset over mountains")
        XCTAssertEqual(record.modelIdentifier, "dall-e-3")
        XCTAssertNotNil(record.generatedAt)
        XCTAssertNotNil(record.modifiedAt)
    }

    func testGeneratedImageRecordFromTypedData() {
        // GIVEN
        let imageData = Data("test image".utf8)
        let typedData = GeneratedImageData(
            imageData: imageData,
            format: .jpg,
            width: 1920,
            height: 1080,
            model: "dall-e-2",
            revisedPrompt: "Enhanced prompt"
        )

        // WHEN
        let record = GeneratedImageRecord(
            providerId: "openai",
            requestorID: "openai.image.dalle2",
            data: typedData,
            prompt: "Create image"
        )

        // THEN
        XCTAssertEqual(record.imageData, imageData)
        XCTAssertEqual(record.format, "jpg")
        XCTAssertEqual(record.width, 1920)
        XCTAssertEqual(record.height, 1080)
        XCTAssertEqual(record.modelIdentifier, "dall-e-2")
        XCTAssertEqual(record.revisedPrompt, "Enhanced prompt")
    }

    func testGeneratedImageRecordFileStored() {
        // GIVEN
        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "image.png",
            fileSize: 150000,
            mimeType: "image/png"
        )

        // WHEN
        let record = GeneratedImageRecord(
            providerId: "openai",
            requestorID: "openai.image",
            imageData: nil,
            format: "png",
            width: 2048,
            height: 2048,
            prompt: "Large image",
            fileReference: fileRef
        )

        // THEN
        XCTAssertTrue(record.isFileStored)
        XCTAssertNil(record.imageData, "Image data should be nil when file-stored")
    }

    func testGeneratedImageRecordFileSize() {
        // GIVEN
        let imageData = Data(repeating: 0xFF, count: 5000)
        let record = GeneratedImageRecord(
            providerId: "test",
            requestorID: "test.image",
            imageData: imageData,
            format: "png",
            width: 512,
            height: 512,
            prompt: "Test"
        )

        // WHEN
        let fileSize = record.fileSize

        // THEN
        XCTAssertEqual(fileSize, 5000)
    }

    func testGeneratedImageRecordGetImageDataFromMemory() throws {
        // GIVEN
        let imageData = Data("image bytes".utf8)
        let record = GeneratedImageRecord(
            providerId: "test",
            requestorID: "test.image",
            imageData: imageData,
            format: "png",
            width: 512,
            height: 512,
            prompt: "Test"
        )

        // WHEN
        let retrievedData = try record.getImageData()

        // THEN
        XCTAssertEqual(retrievedData, imageData)
    }

    // MARK: - GeneratedEmbeddingRecord Tests

    func testGeneratedEmbeddingRecordInitialization() {
        // GIVEN
        let embeddingData = Data([0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x40]) // [1.0, 2.0] as floats
        let id = UUID()

        // WHEN
        let record = GeneratedEmbeddingRecord(
            id: id,
            providerId: "openai",
            requestorID: "openai.embedding.ada002",
            embeddingData: embeddingData,
            dimensions: 2,
            inputText: "Test input",
            tokenCount: 2,
            modelIdentifier: "text-embedding-ada-002",
            prompt: "Embed text"
        )

        // THEN
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.providerId, "openai")
        XCTAssertEqual(record.requestorID, "openai.embedding.ada002")
        XCTAssertEqual(record.embeddingData, embeddingData)
        XCTAssertEqual(record.dimensions, 2)
        XCTAssertEqual(record.inputText, "Test input")
        XCTAssertEqual(record.tokenCount, 2)
        XCTAssertEqual(record.modelIdentifier, "text-embedding-ada-002")
        XCTAssertNotNil(record.createdAt)
        XCTAssertNotNil(record.modifiedAt)
    }

    func testGeneratedEmbeddingRecordFromTypedData() throws {
        // GIVEN
        let vector: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let typedData = GeneratedEmbeddingData(
            embedding: vector,
            dimensions: vector.count,
            model: "text-embedding-3-large",
            inputText: "Embed this",
            tokenCount: 2
        )

        // WHEN
        let record = GeneratedEmbeddingRecord(
            providerId: "openai",
            requestorID: "openai.embedding.large",
            data: typedData,
            prompt: "Create embedding"
        )

        // THEN
        XCTAssertEqual(record.dimensions, 5)
        XCTAssertEqual(record.inputText, "Embed this")
        XCTAssertEqual(record.tokenCount, 2)
        XCTAssertEqual(record.modelIdentifier, "text-embedding-3-large")
        XCTAssertNotNil(record.embeddingData)
    }

    func testGeneratedEmbeddingRecordFileStored() {
        // GIVEN
        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "embedding.bin",
            fileSize: 6144, // 1536 floats * 4 bytes
            mimeType: "application/octet-stream"
        )

        // WHEN
        let record = GeneratedEmbeddingRecord(
            providerId: "openai",
            requestorID: "openai.embedding",
            embeddingData: nil,
            dimensions: 1536,
            inputText: "Large embedding",
            tokenCount: 3,
            modelIdentifier: "text-embedding-ada-002",
            fileReference: fileRef,
            prompt: "Embed"
        )

        // THEN
        XCTAssertTrue(record.isFileStored)
        XCTAssertNil(record.embeddingData, "Embedding data should be nil when file-stored")
        XCTAssertEqual(record.dataSize, 6144, "Data size comes from file reference")
    }

    func testGeneratedEmbeddingRecordGetEmbeddingFromMemory() throws {
        // GIVEN
        let vector: [Float] = [1.0, 2.0, 3.0]
        let embeddingData = vector.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        let record = GeneratedEmbeddingRecord(
            providerId: "test",
            requestorID: "test.embedding",
            embeddingData: embeddingData,
            dimensions: 3,
            inputText: "Test",
            tokenCount: 1,
            modelIdentifier: "test-model",
            prompt: "Test"
        )

        // WHEN
        let retrievedVector = try record.getEmbedding()

        // THEN
        XCTAssertEqual(retrievedVector.count, 3)
        for (index, value) in retrievedVector.enumerated() {
            XCTAssertEqual(value, vector[index], accuracy: 0.0001)
        }
    }

    func testGeneratedEmbeddingRecordDataSize() {
        // GIVEN
        let vector: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let embeddingData = vector.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        let record = GeneratedEmbeddingRecord(
            providerId: "test",
            requestorID: "test.embedding",
            embeddingData: embeddingData,
            dimensions: 5,
            inputText: "Test",
            tokenCount: 1,
            modelIdentifier: "test-model",
            prompt: "Test"
        )

        // WHEN
        let dataSize = record.dataSize

        // THEN
        XCTAssertEqual(dataSize, 5 * MemoryLayout<Float>.size)
    }

    // MARK: - Edge Cases

    func testRecordWithEstimatedCost() {
        // GIVEN
        let record = GeneratedTextRecord(
            providerId: "openai",
            requestorID: "openai.text",
            text: "Test",
            wordCount: 1,
            characterCount: 4,
            prompt: "Test",
            estimatedCost: 0.002
        )

        // THEN
        XCTAssertEqual(record.estimatedCost, 0.002)
    }

    func testMultipleRecordTypes() {
        // GIVEN - Create one of each record type
        let audioRecord = GeneratedAudioRecord(
            providerId: "test",
            requestorID: "test.audio",
            audioData: Data("audio".utf8),
            format: "mp3",
            durationSeconds: 1.0,
            voiceID: "v1",
            voiceName: "V1",
            prompt: "Test"
        )

        let textRecord = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Text content",
            wordCount: 2,
            characterCount: 12,
            prompt: "Test"
        )

        let imageRecord = GeneratedImageRecord(
            providerId: "test",
            requestorID: "test.image",
            imageData: Data("image".utf8),
            format: "png",
            width: 512,
            height: 512,
            prompt: "Test"
        )

        let embeddingRecord = GeneratedEmbeddingRecord(
            providerId: "test",
            requestorID: "test.embedding",
            embeddingData: Data([0x00, 0x00, 0x80, 0x3F]),
            dimensions: 1,
            inputText: "Embed",
            tokenCount: 1,
            modelIdentifier: "test",
            prompt: "Test"
        )

        // THEN - Verify all records were created successfully
        XCTAssertNotNil(audioRecord.id)
        XCTAssertNotNil(textRecord.id)
        XCTAssertNotNil(imageRecord.id)
        XCTAssertNotNil(embeddingRecord.id)
    }
}
