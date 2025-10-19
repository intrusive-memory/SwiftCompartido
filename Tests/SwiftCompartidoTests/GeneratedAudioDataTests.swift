//
//  GeneratedAudioDataTests.swift
//  SwiftHablareTests
//
//  Phase 4: Tests for GeneratedAudioData and AudioGenerationConfig
//

import XCTest
@testable import SwiftCompartido

final class GeneratedAudioDataTests: XCTestCase {

    // MARK: - AudioFormat Tests

    func testAudioFormatMimeTypes() {
        // THEN
        XCTAssertEqual(GeneratedAudioData.AudioFormat.mp3.mimeType, "audio/mpeg")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.wav.mimeType, "audio/wav")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.m4a.mimeType, "audio/mp4")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.flac.mimeType, "audio/flac")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.ogg.mimeType, "audio/ogg")
    }

    func testAudioFormatFileExtensions() {
        // THEN
        XCTAssertEqual(GeneratedAudioData.AudioFormat.mp3.fileExtension, "mp3")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.wav.fileExtension, "wav")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.m4a.fileExtension, "m4a")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.flac.fileExtension, "flac")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.ogg.fileExtension, "ogg")
    }

    func testAudioFormatRawValues() {
        // THEN
        XCTAssertEqual(GeneratedAudioData.AudioFormat.mp3.rawValue, "mp3")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.wav.rawValue, "wav")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.m4a.rawValue, "m4a")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.flac.rawValue, "flac")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.ogg.rawValue, "ogg")
    }

    // MARK: - GeneratedAudioData Initialization Tests

    func testGeneratedAudioDataInitialization() {
        // GIVEN
        let audioData = Data("test audio".utf8)
        let voiceID = "test-voice-123"
        let voiceName = "Test Voice"
        let model = "test-model"

        // WHEN
        let generated = GeneratedAudioData(
            audioData: audioData,
            format: .mp3,
            durationSeconds: 2.5,
            sampleRate: 44100,
            bitRate: 128000,
            channels: 2,
            voiceID: voiceID,
            voiceName: voiceName,
            model: model
        )

        // THEN
        XCTAssertEqual(generated.audioData, audioData)
        XCTAssertEqual(generated.format, .mp3)
        XCTAssertEqual(generated.durationSeconds, 2.5)
        XCTAssertEqual(generated.sampleRate, 44100)
        XCTAssertEqual(generated.bitRate, 128000)
        XCTAssertEqual(generated.channels, 2)
        XCTAssertEqual(generated.voiceID, voiceID)
        XCTAssertEqual(generated.voiceName, voiceName)
        XCTAssertEqual(generated.model, model)
    }

    func testGeneratedAudioDataWithNilAudioData() {
        // WHEN
        let generated = GeneratedAudioData(
            audioData: nil,
            format: .wav,
            voiceID: "voice-1",
            voiceName: "Voice 1",
            model: "model-1"
        )

        // THEN
        XCTAssertNil(generated.audioData)
        XCTAssertEqual(generated.fileSize, 0, "File size should be 0 when audioData is nil")
    }

    func testGeneratedAudioDataWithOptionalParameters() {
        // WHEN
        let generated = GeneratedAudioData(
            audioData: Data("test".utf8),
            format: .mp3,
            voiceID: "voice-1",
            voiceName: "Voice 1",
            model: "model-1"
        )

        // THEN
        XCTAssertNil(generated.durationSeconds)
        XCTAssertNil(generated.sampleRate)
        XCTAssertNil(generated.bitRate)
        XCTAssertNil(generated.channels)
    }

    func testGeneratedAudioDataFileSize() {
        // GIVEN
        let audioData = Data("test audio data with some length".utf8)

        // WHEN
        let generated = GeneratedAudioData(
            audioData: audioData,
            format: .mp3,
            voiceID: "voice-1",
            voiceName: "Voice 1",
            model: "model-1"
        )

        // THEN
        XCTAssertEqual(generated.fileSize, audioData.count)
    }

    // MARK: - SerializableTypedData Conformance Tests

    func testPreferredFormat() {
        // GIVEN
        let generated = GeneratedAudioData(
            audioData: Data("test".utf8),
            format: .mp3,
            voiceID: "voice-1",
            voiceName: "Voice 1",
            model: "model-1"
        )

        // THEN
        XCTAssertEqual(generated.preferredFormat, .plist)
    }

    // MARK: - Codable Tests

    func testGeneratedAudioDataCodable() throws {
        // GIVEN
        let audioData = Data("test audio".utf8)
        let original = GeneratedAudioData(
            audioData: audioData,
            format: .mp3,
            durationSeconds: 3.5,
            sampleRate: 48000,
            bitRate: 192000,
            channels: 2,
            voiceID: "voice-123",
            voiceName: "Rachel",
            model: "eleven_monolingual_v1"
        )

        // WHEN - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        // THEN - Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GeneratedAudioData.self, from: data)

        XCTAssertEqual(decoded.audioData, original.audioData)
        XCTAssertEqual(decoded.format, original.format)
        XCTAssertEqual(decoded.durationSeconds, original.durationSeconds)
        XCTAssertEqual(decoded.sampleRate, original.sampleRate)
        XCTAssertEqual(decoded.bitRate, original.bitRate)
        XCTAssertEqual(decoded.channels, original.channels)
        XCTAssertEqual(decoded.voiceID, original.voiceID)
        XCTAssertEqual(decoded.voiceName, original.voiceName)
        XCTAssertEqual(decoded.model, original.model)
    }

    func testGeneratedAudioDataCodableWithNilValues() throws {
        // GIVEN
        let original = GeneratedAudioData(
            audioData: nil,
            format: .wav,
            voiceID: "voice-1",
            voiceName: "Voice 1",
            model: "model-1"
        )

        // WHEN
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GeneratedAudioData.self, from: data)

        // THEN
        XCTAssertNil(decoded.audioData)
        XCTAssertNil(decoded.durationSeconds)
        XCTAssertNil(decoded.sampleRate)
        XCTAssertNil(decoded.bitRate)
        XCTAssertNil(decoded.channels)
    }

    // MARK: - AudioGenerationConfig Tests

    func testAudioGenerationConfigInitialization() {
        // WHEN
        let config = AudioGenerationConfig(
            voiceID: "voice-123",
            voiceName: "Rachel",
            modelID: "custom-model",
            stability: 0.6,
            similarityBoost: 0.8,
            outputFormat: .mp3
        )

        // THEN
        XCTAssertEqual(config.voiceID, "voice-123")
        XCTAssertEqual(config.voiceName, "Rachel")
        XCTAssertEqual(config.modelID, "custom-model")
        XCTAssertEqual(config.stability, 0.6)
        XCTAssertEqual(config.similarityBoost, 0.8)
        XCTAssertEqual(config.outputFormat, .mp3)
    }

    func testAudioGenerationConfigDefaults() {
        // WHEN
        let config = AudioGenerationConfig(
            voiceID: "voice-123",
            voiceName: "Rachel"
        )

        // THEN
        XCTAssertEqual(config.modelID, "eleven_monolingual_v1")
        XCTAssertEqual(config.stability, 0.5)
        XCTAssertEqual(config.similarityBoost, 0.75)
        XCTAssertEqual(config.outputFormat, .mp3)
    }

    func testAudioGenerationConfigDefault() {
        // WHEN
        let config = AudioGenerationConfig.default

        // THEN
        XCTAssertEqual(config.voiceID, "21m00Tcm4TlvDq8ikWAM")
        XCTAssertEqual(config.voiceName, "Rachel")
        XCTAssertEqual(config.modelID, "eleven_monolingual_v1")
        XCTAssertEqual(config.stability, 0.5)
        XCTAssertEqual(config.similarityBoost, 0.75)
        XCTAssertEqual(config.outputFormat, .mp3)
    }

    func testAudioGenerationConfigStable() {
        // WHEN
        let config = AudioGenerationConfig.stable(voiceID: "voice-123", voiceName: "Test")

        // THEN
        XCTAssertEqual(config.voiceID, "voice-123")
        XCTAssertEqual(config.voiceName, "Test")
        XCTAssertEqual(config.stability, 0.75, "Stable config should have higher stability")
        XCTAssertEqual(config.similarityBoost, 0.5, "Stable config should have lower similarity boost")
    }

    func testAudioGenerationConfigExpressive() {
        // WHEN
        let config = AudioGenerationConfig.expressive(voiceID: "voice-123", voiceName: "Test")

        // THEN
        XCTAssertEqual(config.voiceID, "voice-123")
        XCTAssertEqual(config.voiceName, "Test")
        XCTAssertEqual(config.stability, 0.25, "Expressive config should have lower stability")
        XCTAssertEqual(config.similarityBoost, 0.9, "Expressive config should have higher similarity boost")
    }

    func testAudioGenerationConfigCodable() throws {
        // GIVEN
        let original = AudioGenerationConfig(
            voiceID: "voice-123",
            voiceName: "Rachel",
            modelID: "test-model",
            stability: 0.7,
            similarityBoost: 0.6,
            outputFormat: .wav
        )

        // WHEN
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AudioGenerationConfig.self, from: data)

        // THEN
        XCTAssertEqual(decoded.voiceID, original.voiceID)
        XCTAssertEqual(decoded.voiceName, original.voiceName)
        XCTAssertEqual(decoded.modelID, original.modelID)
        XCTAssertEqual(decoded.stability, original.stability)
        XCTAssertEqual(decoded.similarityBoost, original.similarityBoost)
        XCTAssertEqual(decoded.outputFormat, original.outputFormat)
    }

    // MARK: - Edge Cases

    func testGeneratedAudioDataWithAllFormats() {
        // Test each format
        let formats: [GeneratedAudioData.AudioFormat] = [.mp3, .wav, .m4a, .flac, .ogg]

        for format in formats {
            let generated = GeneratedAudioData(
                audioData: Data("test".utf8),
                format: format,
                voiceID: "voice-1",
                voiceName: "Voice 1",
                model: "model-1"
            )
            XCTAssertEqual(generated.format, format)
        }
    }

    func testAudioGenerationConfigBoundaryValues() {
        // Test with boundary stability and similarity values
        let configMin = AudioGenerationConfig(
            voiceID: "voice-1",
            voiceName: "Test",
            stability: 0.0,
            similarityBoost: 0.0
        )

        let configMax = AudioGenerationConfig(
            voiceID: "voice-1",
            voiceName: "Test",
            stability: 1.0,
            similarityBoost: 1.0
        )

        XCTAssertEqual(configMin.stability, 0.0)
        XCTAssertEqual(configMin.similarityBoost, 0.0)
        XCTAssertEqual(configMax.stability, 1.0)
        XCTAssertEqual(configMax.similarityBoost, 1.0)
    }
}
