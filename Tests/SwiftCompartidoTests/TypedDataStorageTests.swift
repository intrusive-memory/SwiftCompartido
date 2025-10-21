//
//  TypedDataStorageTests.swift
//  SwiftCompartido Tests
//
//  Tests for unified TypedDataStorage model
//

import Testing
import Foundation
import SwiftData
@testable import SwiftCompartido

@Suite("TypedDataStorage Tests")
struct TypedDataStorageTests {

    // MARK: - MIME Type Validation Tests

    @Test("MIME type validation - text types")
    func testTextMimeTypeValidation() throws {
        #expect(TypedDataStorage.isMimeTypeSupported("text/plain"))
        #expect(TypedDataStorage.isMimeTypeSupported("text/html"))
        #expect(TypedDataStorage.isMimeTypeSupported("text/markdown"))
        #expect(TypedDataStorage.isMimeTypeSupported("text/csv"))
    }

    @Test("MIME type validation - image types")
    func testImageMimeTypeValidation() throws {
        #expect(TypedDataStorage.isMimeTypeSupported("image/png"))
        #expect(TypedDataStorage.isMimeTypeSupported("image/jpeg"))
        #expect(TypedDataStorage.isMimeTypeSupported("image/webp"))
        #expect(TypedDataStorage.isMimeTypeSupported("image/gif"))
    }

    @Test("MIME type validation - audio types")
    func testAudioMimeTypeValidation() throws {
        #expect(TypedDataStorage.isMimeTypeSupported("audio/mpeg"))
        #expect(TypedDataStorage.isMimeTypeSupported("audio/wav"))
        #expect(TypedDataStorage.isMimeTypeSupported("audio/mp4"))
        #expect(TypedDataStorage.isMimeTypeSupported("audio/flac"))
    }

    @Test("MIME type validation - video types")
    func testVideoMimeTypeValidation() throws {
        #expect(TypedDataStorage.isMimeTypeSupported("video/mp4"))
        #expect(TypedDataStorage.isMimeTypeSupported("video/mov"))
        #expect(TypedDataStorage.isMimeTypeSupported("video/avi"))
    }

    @Test("MIME type validation - embedding type")
    func testEmbeddingMimeTypeValidation() throws {
        #expect(TypedDataStorage.isMimeTypeSupported("application/x-embedding"))
    }

    @Test("MIME type validation - unsupported types")
    func testUnsupportedMimeTypes() throws {
        #expect(!TypedDataStorage.isMimeTypeSupported("application/pdf"))
        #expect(!TypedDataStorage.isMimeTypeSupported("application/json"))
        #expect(!TypedDataStorage.isMimeTypeSupported("application/zip"))
        #expect(!TypedDataStorage.isMimeTypeSupported("unknown/type"))
    }

    @Test("Storage field type routing")
    func testStorageFieldTypeRouting() throws {
        #expect(try TypedDataStorage.storageFieldType(for: "text/plain") == "text")
        #expect(try TypedDataStorage.storageFieldType(for: "image/png") == "binary")
        #expect(try TypedDataStorage.storageFieldType(for: "audio/mpeg") == "binary")
        #expect(try TypedDataStorage.storageFieldType(for: "video/mp4") == "binary")
        #expect(try TypedDataStorage.storageFieldType(for: "application/x-embedding") == "binary")
    }

    @Test("Storage field type throws for unsupported types")
    func testStorageFieldTypeThrowsForUnsupported() throws {
        #expect(throws: TypedDataStorageError.self) {
            try TypedDataStorage.storageFieldType(for: "application/pdf")
        }
    }

    // MARK: - Text Storage Tests

    @Test("Create text storage record")
    func testCreateTextRecord() throws {
        let record = TypedDataStorage(
            providerId: "openai",
            requestorID: "gpt-4",
            mimeType: "text/plain",
            textValue: "Hello, world!",
            prompt: "Say hello",
            wordCount: 2,
            characterCount: 13
        )

        #expect(record.mimeType == "text/plain")
        #expect(record.textValue == "Hello, world!")
        #expect(record.binaryValue == nil)
        #expect(record.wordCount == 2)
        #expect(record.characterCount == 13)
        #expect(record.contentCategory == "text")
    }

    @Test("Get text content from memory")
    func testGetTextFromMemory() throws {
        let record = TypedDataStorage(
            providerId: "openai",
            requestorID: "gpt-4",
            mimeType: "text/plain",
            textValue: "Hello, world!",
            prompt: "Test"
        )

        let text = try record.getText()
        #expect(text == "Hello, world!")
    }

    @Test("Text content size calculation")
    func testTextContentSize() throws {
        let record = TypedDataStorage(
            providerId: "openai",
            requestorID: "gpt-4",
            mimeType: "text/plain",
            textValue: "Hello",
            prompt: "Test"
        )

        // "Hello" = 5 bytes in UTF-8
        #expect(record.contentSize == 5)
    }

    // MARK: - Binary Storage Tests

    @Test("Create image storage record")
    func testCreateImageRecord() throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        let record = TypedDataStorage(
            providerId: "openai",
            requestorID: "dalle-3",
            mimeType: "image/png",
            binaryValue: imageData,
            prompt: "Generate image",
            imageFormat: "png",
            width: 1024,
            height: 1024
        )

        #expect(record.mimeType == "image/png")
        #expect(record.binaryValue == imageData)
        #expect(record.textValue == nil)
        #expect(record.imageFormat == "png")
        #expect(record.width == 1024)
        #expect(record.height == 1024)
        #expect(record.contentCategory == "image")
    }

    @Test("Create audio storage record")
    func testCreateAudioRecord() throws {
        let audioData = Data([0xFF, 0xFB]) // MP3 header
        let record = TypedDataStorage(
            providerId: "elevenlabs",
            requestorID: "tts.rachel",
            mimeType: "audio/mpeg",
            binaryValue: audioData,
            prompt: "Speak this",
            audioFormat: "mp3",
            durationSeconds: 5.5,
            voiceID: "rachel",
            voiceName: "Rachel"
        )

        #expect(record.mimeType == "audio/mpeg")
        #expect(record.binaryValue == audioData)
        #expect(record.audioFormat == "mp3")
        #expect(record.durationSeconds == 5.5)
        #expect(record.voiceID == "rachel")
        #expect(record.contentCategory == "audio")
    }

    @Test("Get binary content from memory")
    func testGetBinaryFromMemory() throws {
        let testData = Data([0x01, 0x02, 0x03, 0x04])
        let record = TypedDataStorage(
            providerId: "test",
            requestorID: "test",
            mimeType: "image/png",
            binaryValue: testData,
            prompt: "Test"
        )

        let retrieved = try record.getBinary()
        #expect(retrieved == testData)
    }

    // MARK: - Embedding Storage Tests

    @Test("Create embedding storage record")
    func testCreateEmbeddingRecord() throws {
        let embedding: [Float] = [0.1, 0.2, 0.3, 0.4]
        let embeddingData = embedding.withUnsafeBufferPointer { Data(buffer: $0) }

        let record = TypedDataStorage(
            providerId: "openai",
            requestorID: "text-embedding-3-small",
            mimeType: "application/x-embedding",
            binaryValue: embeddingData,
            prompt: "Embed this",
            dimensions: 4,
            inputText: "Test input"
        )

        #expect(record.mimeType == "application/x-embedding")
        #expect(record.binaryValue == embeddingData)
        #expect(record.dimensions == 4)
        #expect(record.inputText == "Test input")
        #expect(record.contentCategory == "embedding")
    }

    @Test("Get embedding vector from memory")
    func testGetEmbeddingFromMemory() throws {
        let embedding: [Float] = [0.1, 0.2, 0.3, 0.4]
        let embeddingData = embedding.withUnsafeBufferPointer { Data(buffer: $0) }

        let record = TypedDataStorage(
            providerId: "openai",
            requestorID: "test",
            mimeType: "application/x-embedding",
            binaryValue: embeddingData,
            prompt: "Test",
            dimensions: 4
        )

        let retrieved = try record.getEmbedding()
        #expect(retrieved.count == 4)
        #expect(abs(retrieved[0] - 0.1) < 0.001)
        #expect(abs(retrieved[1] - 0.2) < 0.001)
        #expect(abs(retrieved[2] - 0.3) < 0.001)
        #expect(abs(retrieved[3] - 0.4) < 0.001)
    }

    // MARK: - Content Type Mismatch Tests

    @Test("getText throws for non-text MIME type")
    func testGetTextThrowsForNonText() throws {
        let record = TypedDataStorage(
            providerId: "test",
            requestorID: "test",
            mimeType: "image/png",
            binaryValue: Data([0x01]),
            prompt: "Test"
        )

        #expect(throws: (any Error).self) {
            try record.getText()
        }
    }

    @Test("getBinary throws for text MIME type")
    func testGetBinaryThrowsForText() throws {
        let record = TypedDataStorage(
            providerId: "test",
            requestorID: "test",
            mimeType: "text/plain",
            textValue: "Hello",
            prompt: "Test"
        )

        #expect(throws: (any Error).self) {
            try record.getBinary()
        }
    }

    @Test("getEmbedding throws for non-embedding MIME type")
    func testGetEmbeddingThrowsForNonEmbedding() throws {
        let record = TypedDataStorage(
            providerId: "test",
            requestorID: "test",
            mimeType: "image/png",
            binaryValue: Data([0x01]),
            prompt: "Test"
        )

        #expect(throws: (any Error).self) {
            try record.getEmbedding()
        }
    }

    // MARK: - Convenience Initializer Tests

    @Test("Create from GeneratedTextData")
    func testCreateFromTextData() throws {
        let textData = GeneratedTextData(
            text: "Generated content",
            model: "gpt-4",
            languageCode: "en",
            tokenCount: 10,
            completionTokens: 5,
            promptTokens: 5
        )

        let record = TypedDataStorage(
            providerId: "openai",
            requestorID: "gpt-4",
            data: textData,
            prompt: "Generate text"
        )

        #expect(record.mimeType == "text/plain")
        #expect(record.textValue == "Generated content")
        #expect(record.modelIdentifier == "gpt-4")
        #expect(record.wordCount == textData.wordCount)
        #expect(record.characterCount == textData.characterCount)
        #expect(record.languageCode == "en")
        #expect(record.tokenCount == 10)
    }

    @Test("Create from GeneratedAudioData")
    func testCreateFromAudioData() throws {
        let audioBytes = Data([0xFF, 0xFB])
        let audioData = GeneratedAudioData(
            audioData: audioBytes,
            format: .mp3,
            durationSeconds: 5.5,
            voiceID: "rachel",
            voiceName: "Rachel",
            model: "eleven_monolingual_v1"
        )

        let record = TypedDataStorage(
            providerId: "elevenlabs",
            requestorID: "tts",
            data: audioData,
            prompt: "Speak"
        )

        #expect(record.mimeType == "audio/mpeg")
        #expect(record.binaryValue == audioBytes)
        #expect(record.audioFormat == "mp3")
        #expect(record.durationSeconds == 5.5)
        #expect(record.voiceID == "rachel")
        #expect(record.voiceName == "Rachel")
    }

    @Test("Create from GeneratedImageData")
    func testCreateFromImageData() throws {
        let imageBytes = Data([0x89, 0x50, 0x4E, 0x47])
        let imageData = GeneratedImageData(
            imageData: imageBytes,
            format: .png,
            width: 1024,
            height: 1024,
            model: "dall-e-3"
        )

        let record = TypedDataStorage(
            providerId: "openai",
            requestorID: "dalle-3",
            data: imageData,
            prompt: "Generate"
        )

        #expect(record.mimeType == "image/png")
        #expect(record.binaryValue == imageBytes)
        #expect(record.imageFormat == "png")
        #expect(record.width == 1024)
        #expect(record.height == 1024)
    }

    @Test("Create from GeneratedEmbeddingData")
    func testCreateFromEmbeddingData() throws {
        let embedding: [Float] = [0.1, 0.2, 0.3]
        let embeddingData = GeneratedEmbeddingData(
            embedding: embedding,
            dimensions: 3,
            model: "text-embedding-3-small",
            inputText: "Test",
            tokenCount: 5
        )

        let record = TypedDataStorage(
            providerId: "openai",
            requestorID: "embedding",
            data: embeddingData,
            prompt: "Embed"
        )

        #expect(record.mimeType == "application/x-embedding")
        #expect(record.dimensions == 3)
        #expect(record.inputText == "Test")
        #expect(record.tokenCount == 5)
    }

    // MARK: - CloudKit Properties Tests

    @Test("CloudKit properties initialization")
    func testCloudKitPropertiesInit() throws {
        let record = TypedDataStorage(
            providerId: "test",
            requestorID: "test",
            mimeType: "text/plain",
            textValue: "Test",
            prompt: "Test",
            storageMode: .cloudKit
        )

        #expect(record.storageMode == .cloudKit)
        #expect(record.syncStatus == .pending)
        #expect(record.conflictVersion == 1)
        #expect(record.cloudKitRecordID == nil)
        #expect(record.isCloudKitEnabled == true)
    }

    @Test("Touch method updates modifiedAt and conflictVersion")
    func testTouchMethod() throws {
        let record = TypedDataStorage(
            providerId: "test",
            requestorID: "test",
            mimeType: "text/plain",
            textValue: "Test",
            prompt: "Test"
        )

        let originalModified = record.modifiedAt
        let originalVersion = record.conflictVersion

        // Sleep briefly to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)

        record.touch()

        #expect(record.modifiedAt > originalModified)
        #expect(record.conflictVersion == originalVersion + 1)
    }

    // MARK: - Description Tests

    @Test("CustomStringConvertible for text")
    func testTextDescription() throws {
        let record = TypedDataStorage(
            providerId: "openai",
            requestorID: "gpt-4",
            mimeType: "text/plain",
            textValue: "Test content",
            prompt: "Test",
            wordCount: 2
        )

        let desc = record.description
        #expect(desc.contains("text"))
        #expect(desc.contains("text/plain"))
        #expect(desc.contains("2 words"))
    }

    @Test("CustomStringConvertible for audio")
    func testAudioDescription() throws {
        let record = TypedDataStorage(
            providerId: "elevenlabs",
            requestorID: "tts",
            mimeType: "audio/mpeg",
            binaryValue: Data([0xFF]),
            prompt: "Test",
            durationSeconds: 5.5
        )

        let desc = record.description
        #expect(desc.contains("audio"))
        #expect(desc.contains("5.5s"))
    }

    @Test("CustomStringConvertible for image")
    func testImageDescription() throws {
        let record = TypedDataStorage(
            providerId: "openai",
            requestorID: "dalle-3",
            mimeType: "image/png",
            binaryValue: Data([0x89]),
            prompt: "Test",
            width: 1024,
            height: 768
        )

        let desc = record.description
        #expect(desc.contains("image"))
        #expect(desc.contains("1024x768"))
    }

    @Test("CustomStringConvertible for embedding")
    func testEmbeddingDescription() throws {
        let record = TypedDataStorage(
            providerId: "openai",
            requestorID: "embedding",
            mimeType: "application/x-embedding",
            binaryValue: Data([0x01]),
            prompt: "Test",
            dimensions: 1536
        )

        let desc = record.description
        #expect(desc.contains("embedding"))
        #expect(desc.contains("1536D"))
    }

    // MARK: - File Storage Flag Tests

    @Test("isFileStored returns false when no file reference")
    func testIsFileStoredWithoutReference() throws {
        let record = TypedDataStorage(
            providerId: "test",
            requestorID: "test",
            mimeType: "text/plain",
            textValue: "Test",
            prompt: "Test"
        )

        #expect(record.isFileStored == false)
    }

    @Test("isFileStored returns true when file reference exists")
    func testIsFileStoredWithReference() throws {
        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "test.txt",
            fileSize: 100,
            mimeType: "text/plain"
        )

        let record = TypedDataStorage(
            providerId: "test",
            requestorID: "test",
            mimeType: "text/plain",
            prompt: "Test",
            fileReference: fileRef
        )

        #expect(record.isFileStored == true)
    }
}
