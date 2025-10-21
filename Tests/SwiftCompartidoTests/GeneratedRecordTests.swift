//
//  GeneratedRecordTests.swift
//  SwiftCompartidoTests
//
//  Tests for TypedDataStorage (formerly GeneratedAudioRecord, GeneratedTextRecord, etc.)
//
//  Note: These tests use the deprecated type aliases which map to TypedDataStorage.
//  The API has changed - use mimeType, textValue, binaryValue instead of old property names.
//

import XCTest
import SwiftData
@testable import SwiftCompartido

final class GeneratedRecordTests: XCTestCase {

    // MARK: - GeneratedAudioRecord Tests (Type Alias to TypedDataStorage)

    func testGeneratedAudioRecordInitialization() {
        // GIVEN
        let audioData = Data("test audio".utf8)
        let id = UUID()

        // WHEN
        let record = GeneratedAudioRecord(
            id: id,
            providerId: "elevenlabs",
            requestorID: "elevenlabs.tts.rachel",
            mimeType: "audio/mpeg",
            binaryValue: audioData,
            prompt: "Generate speech",
            audioFormat: "mp3",
            durationSeconds: 2.5,
            sampleRate: 44100,
            bitRate: 128000,
            channels: 2,
            voiceID: "voice-123",
            voiceName: "Rachel"
        )

        // THEN
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.providerId, "elevenlabs")
        XCTAssertEqual(record.requestorID, "elevenlabs.tts.rachel")
        XCTAssertEqual(record.binaryValue, audioData)
        XCTAssertEqual(record.audioFormat, "mp3")
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
        XCTAssertEqual(record.binaryValue, audioData)
        XCTAssertEqual(record.audioFormat, "mp3")
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
            mimeType: "audio/mpeg",
            binaryValue: nil,
            prompt: "Test",
            fileReference: fileRef,
            audioFormat: "mp3",
            durationSeconds: 2.0,
            voiceID: "voice-1",
            voiceName: "Test"
        )

        // THEN
        XCTAssertTrue(record.isFileStored)
        XCTAssertEqual(record.contentSize, 1024, "Content size comes from file reference")
    }

    func testGeneratedAudioRecordTouch() {
        // GIVEN
        let record = GeneratedAudioRecord(
            providerId: "test",
            requestorID: "test.tts",
            mimeType: "audio/mpeg",
            binaryValue: Data("test".utf8),
            prompt: "Test",
            audioFormat: "mp3",
            durationSeconds: 1.0,
            voiceID: "voice-1",
            voiceName: "Test"
        )
        let originalModifiedAt = record.modifiedAt

        // WHEN
        Thread.sleep(forTimeInterval: 0.01)
        record.touch()

        // THEN
        XCTAssertGreaterThan(record.modifiedAt, originalModifiedAt)
    }

    // MARK: - GeneratedTextRecord Tests (Type Alias to TypedDataStorage)

    func testGeneratedTextRecordInitialization() {
        // GIVEN
        let id = UUID()
        let text = "This is generated text content."

        // WHEN
        let record = GeneratedTextRecord(
            id: id,
            providerId: "openai",
            requestorID: "openai.text.gpt4",
            mimeType: "text/plain",
            textValue: text,
            prompt: "Generate text",
            modelIdentifier: "gpt-4",
            wordCount: 5,
            characterCount: text.count,
            languageCode: "en",
            tokenCount: 10,
            completionTokens: 7,
            promptTokens: 3
        )

        // THEN
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.providerId, "openai")
        XCTAssertEqual(record.requestorID, "openai.text.gpt4")
        XCTAssertEqual(record.textValue, text)
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
        XCTAssertEqual(record.textValue, typedData.text)
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
            mimeType: "text/plain",
            textValue: nil,  // Stored in file
            prompt: "Generate long text",
            fileReference: fileRef,
            wordCount: 5000,
            characterCount: 50000
        )

        // THEN
        XCTAssertTrue(record.isFileStored)
        XCTAssertNil(record.textValue, "Text should be nil when file-stored")
    }

    func testGeneratedTextRecordGetTextFromMemory() throws {
        // GIVEN
        let text = "In-memory text"
        let record = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            mimeType: "text/plain",
            textValue: text,
            prompt: "Test",
            wordCount: 2,
            characterCount: text.count
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
            mimeType: "text/plain",
            textValue: nil,
            prompt: "Test",
            wordCount: 0,
            characterCount: 0
        )

        // WHEN/THEN
        XCTAssertThrowsError(try record.getText())
    }

    // MARK: - GeneratedImageRecord Tests (Type Alias to TypedDataStorage)

    func testGeneratedImageRecordInitialization() {
        // GIVEN
        let imageData = Data("fake image data".utf8)
        let id = UUID()

        // WHEN
        let record = GeneratedImageRecord(
            id: id,
            providerId: "openai",
            requestorID: "openai.image.dalle3",
            mimeType: "image/png",
            binaryValue: imageData,
            prompt: "A beautiful sunset",
            modelIdentifier: "dall-e-3",
            imageFormat: "png",
            width: 1024,
            height: 1024,
            revisedPrompt: "A vivid beautiful sunset over mountains"
        )

        // THEN
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.providerId, "openai")
        XCTAssertEqual(record.requestorID, "openai.image.dalle3")
        XCTAssertEqual(record.binaryValue, imageData)
        XCTAssertEqual(record.imageFormat, "png")
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
        XCTAssertEqual(record.binaryValue, imageData)
        XCTAssertEqual(record.imageFormat, "jpg")
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
            mimeType: "image/png",
            binaryValue: nil,
            prompt: "Large image",
            fileReference: fileRef,
            imageFormat: "png",
            width: 2048,
            height: 2048
        )

        // THEN
        XCTAssertTrue(record.isFileStored)
        XCTAssertNil(record.binaryValue, "Image data should be nil when file-stored")
    }

    func testGeneratedImageRecordFileSize() {
        // GIVEN
        let imageData = Data(repeating: 0xFF, count: 5000)
        let record = GeneratedImageRecord(
            providerId: "test",
            requestorID: "test.image",
            mimeType: "image/png",
            binaryValue: imageData,
            prompt: "Test",
            imageFormat: "png",
            width: 512,
            height: 512
        )

        // WHEN
        let fileSize = record.contentSize

        // THEN
        XCTAssertEqual(fileSize, 5000)
    }

    func testGeneratedImageRecordGetImageDataFromMemory() throws {
        // GIVEN
        let imageData = Data("image bytes".utf8)
        let record = GeneratedImageRecord(
            providerId: "test",
            requestorID: "test.image",
            mimeType: "image/png",
            binaryValue: imageData,
            prompt: "Test",
            imageFormat: "png",
            width: 512,
            height: 512
        )

        // WHEN
        let retrievedData = try record.getBinary()

        // THEN
        XCTAssertEqual(retrievedData, imageData)
    }

    // MARK: - GeneratedEmbeddingRecord Tests (Type Alias to TypedDataStorage)

    func testGeneratedEmbeddingRecordInitialization() {
        // GIVEN
        let embeddingData = Data([0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x40]) // [1.0, 2.0] as floats
        let id = UUID()

        // WHEN
        let record = GeneratedEmbeddingRecord(
            id: id,
            providerId: "openai",
            requestorID: "openai.embedding.ada002",
            mimeType: "application/x-embedding",
            binaryValue: embeddingData,
            prompt: "Embed text",
            modelIdentifier: "text-embedding-ada-002",
            tokenCount: 2,
            dimensions: 2,
            inputText: "Test input"
        )

        // THEN
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.providerId, "openai")
        XCTAssertEqual(record.requestorID, "openai.embedding.ada002")
        XCTAssertEqual(record.binaryValue, embeddingData)
        XCTAssertEqual(record.dimensions, 2)
        XCTAssertEqual(record.inputText, "Test input")
        XCTAssertEqual(record.tokenCount, 2)
        XCTAssertEqual(record.modelIdentifier, "text-embedding-ada-002")
        XCTAssertNotNil(record.generatedAt)
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
        XCTAssertNotNil(record.binaryValue)
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
            mimeType: "application/x-embedding",
            binaryValue: nil,
            prompt: "Embed",
            modelIdentifier: "text-embedding-ada-002",
            fileReference: fileRef,
            tokenCount: 3,
            dimensions: 1536,
            inputText: "Large embedding"
        )

        // THEN
        XCTAssertTrue(record.isFileStored)
        XCTAssertNil(record.binaryValue, "Embedding data should be nil when file-stored")
        XCTAssertEqual(record.contentSize, 6144, "Content size comes from file reference")
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
            mimeType: "application/x-embedding",
            binaryValue: embeddingData,
            prompt: "Test",
            modelIdentifier: "test-model",
            tokenCount: 1,
            dimensions: 3,
            inputText: "Test"
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
            mimeType: "application/x-embedding",
            binaryValue: embeddingData,
            prompt: "Test",
            modelIdentifier: "test-model",
            tokenCount: 1,
            dimensions: 5,
            inputText: "Test"
        )

        // WHEN
        let dataSize = record.contentSize

        // THEN
        XCTAssertEqual(dataSize, 5 * MemoryLayout<Float>.size)
    }

    // MARK: - Edge Cases

    func testRecordWithEstimatedCost() {
        // GIVEN
        let record = GeneratedTextRecord(
            providerId: "openai",
            requestorID: "openai.text",
            mimeType: "text/plain",
            textValue: "Test",
            prompt: "Test",
            estimatedCost: 0.002,
            wordCount: 1,
            characterCount: 4
        )

        // THEN
        XCTAssertEqual(record.estimatedCost, 0.002)
    }

    func testMultipleRecordTypes() {
        // GIVEN - Create one of each record type
        let audioRecord = GeneratedAudioRecord(
            providerId: "test",
            requestorID: "test.audio",
            mimeType: "audio/mpeg",
            binaryValue: Data("audio".utf8),
            prompt: "Test",
            audioFormat: "mp3",
            durationSeconds: 1.0,
            voiceID: "v1",
            voiceName: "V1"
        )

        let textRecord = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            mimeType: "text/plain",
            textValue: "Text content",
            prompt: "Test",
            wordCount: 2,
            characterCount: 12
        )

        let imageRecord = GeneratedImageRecord(
            providerId: "test",
            requestorID: "test.image",
            mimeType: "image/png",
            binaryValue: Data("image".utf8),
            prompt: "Test",
            imageFormat: "png",
            width: 512,
            height: 512
        )

        let embeddingRecord = GeneratedEmbeddingRecord(
            providerId: "test",
            requestorID: "test.embedding",
            mimeType: "application/x-embedding",
            binaryValue: Data([0x00, 0x00, 0x80, 0x3F]),
            prompt: "Test",
            modelIdentifier: "test",
            tokenCount: 1,
            dimensions: 1,
            inputText: "Embed"
        )

        // THEN - Verify all records were created successfully
        XCTAssertNotNil(audioRecord.id)
        XCTAssertNotNil(textRecord.id)
        XCTAssertNotNil(imageRecord.id)
        XCTAssertNotNil(embeddingRecord.id)
    }

    // MARK: - Owner Reference Tests

    func testTypedDataStorageWithOwningElement() {
        // GIVEN
        let element = GuionElementModel(
            elementText: "INT. ROOM - DAY",
            elementType: .sceneHeading
        )

        let record = TypedDataStorage(
            providerId: "test",
            requestorID: "test.audio",
            mimeType: "audio/mpeg",
            binaryValue: Data("audio".utf8),
            prompt: "Generate audio for scene"
        )

        // WHEN
        record.owningElement = element

        // THEN
        XCTAssertNotNil(record.owningElement)
        XCTAssertEqual(record.owningElement?.elementText, "INT. ROOM - DAY")
    }

    func testTypedDataStorageWithOwnerIdentifier() {
        // GIVEN
        let record = TypedDataStorage(
            providerId: "test",
            requestorID: "test",
            mimeType: "text/plain",
            textValue: "Test",
            prompt: "Test"
        )

        // WHEN
        record.ownerIdentifier = "x-coredata://store-id/Model/p12345"

        // THEN
        XCTAssertEqual(record.ownerIdentifier, "x-coredata://store-id/Model/p12345")
    }
}
