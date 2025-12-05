//
//  GeneratedAudioDataTests.swift
//  SwiftHablareTests
//
//  Phase 4: Tests for GeneratedAudioData and AudioGenerationConfig
//

import Foundation
import Testing
@testable import SwiftCompartido

struct GeneratedAudioDataTests {

    // MARK: - AudioFormat Tests

    @Test func testAudioFormatMimeTypes() {
        // THEN
        #expect(GeneratedAudioData.AudioFormat.mp3.mimeType == "audio/mpeg")
        #expect(GeneratedAudioData.AudioFormat.wav.mimeType == "audio/wav")
        #expect(GeneratedAudioData.AudioFormat.m4a.mimeType == "audio/mp4")
        #expect(GeneratedAudioData.AudioFormat.flac.mimeType == "audio/flac")
        #expect(GeneratedAudioData.AudioFormat.ogg.mimeType == "audio/ogg")
    }

    @Test func testAudioFormatFileExtensions() {
        // THEN
        #expect(GeneratedAudioData.AudioFormat.mp3.fileExtension == "mp3")
        #expect(GeneratedAudioData.AudioFormat.wav.fileExtension == "wav")
        #expect(GeneratedAudioData.AudioFormat.m4a.fileExtension == "m4a")
        #expect(GeneratedAudioData.AudioFormat.flac.fileExtension == "flac")
        #expect(GeneratedAudioData.AudioFormat.ogg.fileExtension == "ogg")
    }

    @Test func testAudioFormatRawValues() {
        // THEN
        #expect(GeneratedAudioData.AudioFormat.mp3.rawValue == "mp3")
        #expect(GeneratedAudioData.AudioFormat.wav.rawValue == "wav")
        #expect(GeneratedAudioData.AudioFormat.m4a.rawValue == "m4a")
        #expect(GeneratedAudioData.AudioFormat.flac.rawValue == "flac")
        #expect(GeneratedAudioData.AudioFormat.ogg.rawValue == "ogg")
    }

    // MARK: - GeneratedAudioData Initialization Tests

    @Test func testGeneratedAudioDataInitialization() {
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
        #expect(generated.audioData == audioData)
        #expect(generated.format == .mp3)
        #expect(generated.durationSeconds == 2.5)
        #expect(generated.sampleRate == 44100)
        #expect(generated.bitRate == 128000)
        #expect(generated.channels == 2)
        #expect(generated.voiceID == voiceID)
        #expect(generated.voiceName == voiceName)
        #expect(generated.model == model)
    }

    @Test func testGeneratedAudioDataWithNilAudioData() {
        // WHEN
        let generated = GeneratedAudioData(
            audioData: nil,
            format: .wav,
            voiceID: "voice-1",
            voiceName: "Voice 1",
            model: "model-1"
        )

        // THEN
        #expect(generated.audioData == nil)
        #expect(generated.fileSize == 0, "File size should be 0 when audioData is nil")
    }

    @Test func testGeneratedAudioDataWithOptionalParameters() {
        // WHEN
        let generated = GeneratedAudioData(
            audioData: Data("test".utf8),
            format: .mp3,
            voiceID: "voice-1",
            voiceName: "Voice 1",
            model: "model-1"
        )

        // THEN
        #expect(generated.durationSeconds == nil)
        #expect(generated.sampleRate == nil)
        #expect(generated.bitRate == nil)
        #expect(generated.channels == nil)
    }

    @Test func testGeneratedAudioDataFileSize() {
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
        #expect(generated.fileSize == audioData.count)
    }

    // MARK: - SerializableTypedData Conformance Tests

    @Test func testPreferredFormat() {
        // GIVEN
        let generated = GeneratedAudioData(
            audioData: Data("test".utf8),
            format: .mp3,
            voiceID: "voice-1",
            voiceName: "Voice 1",
            model: "model-1"
        )

        // THEN
        #expect(generated.preferredFormat == .plist)
    }

    // MARK: - Codable Tests

    @Test func testGeneratedAudioDataCodable() throws {
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

        #expect(decoded.audioData == original.audioData)
        #expect(decoded.format == original.format)
        #expect(decoded.durationSeconds == original.durationSeconds)
        #expect(decoded.sampleRate == original.sampleRate)
        #expect(decoded.bitRate == original.bitRate)
        #expect(decoded.channels == original.channels)
        #expect(decoded.voiceID == original.voiceID)
        #expect(decoded.voiceName == original.voiceName)
        #expect(decoded.model == original.model)
    }

    @Test func testGeneratedAudioDataCodableWithNilValues() throws {
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
        #expect(decoded.audioData == nil)
        #expect(decoded.durationSeconds == nil)
        #expect(decoded.sampleRate == nil)
        #expect(decoded.bitRate == nil)
        #expect(decoded.channels == nil)
    }

    // MARK: - AudioGenerationConfig Tests

    @Test func testAudioGenerationConfigInitialization() {
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
        #expect(config.voiceID == "voice-123")
        #expect(config.voiceName == "Rachel")
        #expect(config.modelID == "custom-model")
        #expect(config.stability == 0.6)
        #expect(config.similarityBoost == 0.8)
        #expect(config.outputFormat == .mp3)
    }

    @Test func testAudioGenerationConfigDefaults() {
        // WHEN
        let config = AudioGenerationConfig(
            voiceID: "voice-123",
            voiceName: "Rachel"
        )

        // THEN
        #expect(config.modelID == "eleven_monolingual_v1")
        #expect(config.stability == 0.5)
        #expect(config.similarityBoost == 0.75)
        #expect(config.outputFormat == .mp3)
    }

    @Test func testAudioGenerationConfigDefault() {
        // WHEN
        let config = AudioGenerationConfig.default

        // THEN
        #expect(config.voiceID == "21m00Tcm4TlvDq8ikWAM")
        #expect(config.voiceName == "Rachel")
        #expect(config.modelID == "eleven_monolingual_v1")
        #expect(config.stability == 0.5)
        #expect(config.similarityBoost == 0.75)
        #expect(config.outputFormat == .mp3)
    }

    @Test func testAudioGenerationConfigStable() {
        // WHEN
        let config = AudioGenerationConfig.stable(voiceID: "voice-123", voiceName: "Test")

        // THEN
        #expect(config.voiceID == "voice-123")
        #expect(config.voiceName == "Test")
        #expect(config.stability == 0.75, "Stable config should have higher stability")
        #expect(config.similarityBoost == 0.5, "Stable config should have lower similarity boost")
    }

    @Test func testAudioGenerationConfigExpressive() {
        // WHEN
        let config = AudioGenerationConfig.expressive(voiceID: "voice-123", voiceName: "Test")

        // THEN
        #expect(config.voiceID == "voice-123")
        #expect(config.voiceName == "Test")
        #expect(config.stability == 0.25, "Expressive config should have lower stability")
        #expect(config.similarityBoost == 0.9, "Expressive config should have higher similarity boost")
    }

    @Test func testAudioGenerationConfigCodable() throws {
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
        #expect(decoded.voiceID == original.voiceID)
        #expect(decoded.voiceName == original.voiceName)
        #expect(decoded.modelID == original.modelID)
        #expect(decoded.stability == original.stability)
        #expect(decoded.similarityBoost == original.similarityBoost)
        #expect(decoded.outputFormat == original.outputFormat)
    }

    // MARK: - Edge Cases

    @Test func testGeneratedAudioDataWithAllFormats() {
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
            #expect(generated.format == format)
        }
    }

    @Test func testAudioGenerationConfigBoundaryValues() {
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

        #expect(configMin.stability == 0.0)
        #expect(configMin.similarityBoost == 0.0)
        #expect(configMax.stability == 1.0)
        #expect(configMax.similarityBoost == 1.0)
    }
}
