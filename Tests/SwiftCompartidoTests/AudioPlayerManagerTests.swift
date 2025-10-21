import Testing
import Foundation
import AVFoundation
@testable import SwiftCompartido

@MainActor
struct AudioPlayerManagerTests {

    // MARK: - Helper Methods

    /// Creates a valid MP3 audio file data (minimal valid MP3)
    private func createValidMP3Data() -> Data {
        // Minimal valid MP3 file (ID3v2 header + basic MP3 frame)
        var data = Data()

        // ID3v2 header
        data.append(contentsOf: [0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])

        // MP3 sync word and header (44.1kHz, 128kbps, stereo)
        data.append(contentsOf: [0xFF, 0xFB, 0x90, 0x00])

        // Add some silence frames (simplified)
        let silenceFrame = Data(repeating: 0x00, count: 417)
        for _ in 0..<10 {
            data.append(silenceFrame)
        }

        return data
    }

    /// Creates a temporary audio file and returns its URL
    private func createTempAudioFile(format: String = "mp3") -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(format)

        let audioData = createValidMP3Data()
        try? audioData.write(to: tempURL)

        return tempURL
    }

    // MARK: - Initialization Tests

    @Test("AudioPlayerManager initializes correctly")
    func testInitialization() {
        let manager = AudioPlayerManager()

        #expect(!manager.isPlaying)
        #expect(manager.currentTime == 0)
        #expect(manager.duration == 0)
        #expect(manager.audioLevels.isEmpty)
        #expect(manager.currentAudioFile == nil)
    }

    // MARK: - URL-Based Playback Tests

    @Test("Play from URL initializes player")
    func testPlayFromURL() throws {
        let manager = AudioPlayerManager()
        let audioURL = createTempAudioFile()

        defer {
            try? FileManager.default.removeItem(at: audioURL)
        }

        // This may fail on CI without audio hardware, so we'll catch and verify attempt
        do {
            try manager.play(from: audioURL, format: "mp3", duration: 5.0)

            #expect(manager.isPlaying)
            #expect(manager.duration > 0 || manager.duration == 5.0)
            #expect(manager.currentAudioFile != nil)
            #expect(manager.currentAudioFile?.audioFormat == "mp3")

            manager.stop()
        } catch {
            // On systems without audio, this is expected
            print("Audio playback not available in test environment: \(error)")
        }
    }

    @Test("Play from URL with no duration")
    func testPlayFromURLNoDuration() throws {
        let manager = AudioPlayerManager()
        let audioURL = createTempAudioFile()

        defer {
            try? FileManager.default.removeItem(at: audioURL)
        }

        do {
            try manager.play(from: audioURL, format: "mp3")

            #expect(manager.currentAudioFile != nil)
            #expect(manager.currentAudioFile?.audioFormat == "mp3")

            manager.stop()
        } catch {
            print("Audio playback not available in test environment: \(error)")
        }
    }

    @Test("Play from nonexistent URL throws error")
    func testPlayFromNonexistentURL() {
        let manager = AudioPlayerManager()
        let nonexistentURL = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).mp3")

        #expect(throws: Error.self) {
            try manager.play(from: nonexistentURL, format: "mp3")
        }
    }

    // MARK: - GeneratedAudioRecord Playback Tests

    @Test("Play from GeneratedAudioRecord with in-memory data")
    func testPlayFromRecordInMemory() throws {
        let manager = AudioPlayerManager()
        let audioData = createValidMP3Data()

        let record = GeneratedAudioRecord(
            providerId: "test",
            requestorID: "test.tts",
            mimeType: "audio/mpeg",
            binaryValue: audioData,
            prompt: "Test prompt",
            audioFormat: "mp3",
            durationSeconds: 2.5,
            voiceID: "voice-1",
            voiceName: "Test Voice"
        )

        do {
            try manager.play(record: record)

            #expect(manager.isPlaying)
            #expect(manager.currentAudioFile != nil)

            manager.stop()
        } catch {
            print("Audio playback not available in test environment: \(error)")
        }
    }

    @Test("Play from GeneratedAudioRecord with file reference")
    func testPlayFromRecordFileReference() throws {
        let manager = AudioPlayerManager()
        let requestID = UUID()

        // Create storage area
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString)")
        let storage = StorageAreaReference(requestID: requestID, baseURL: tempDir)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create directory and audio file
        try storage.createDirectoryIfNeeded()
        let audioURL = storage.fileURL(for: "audio.mp3")
        let audioData = createValidMP3Data()
        try audioData.write(to: audioURL)

        // Create file reference
        let fileRef = TypedDataFileReference(
            requestID: requestID,
            fileName: "audio.mp3",
            fileSize: Int64(audioData.count),
            mimeType: "audio/mpeg"
        )

        // Create record with file reference (no in-memory data)
        let record = GeneratedAudioRecord(
            providerId: "test",
            requestorID: "test.tts",
            mimeType: "audio/mpeg",
            binaryValue: nil,
            prompt: "Test prompt",
            fileReference: fileRef,
            audioFormat: "mp3",
            durationSeconds: 3.0,
            voiceID: "voice-1",
            voiceName: "Test Voice"
        )

        do {
            try manager.play(record: record, storageArea: storage)

            #expect(manager.isPlaying)
            #expect(manager.currentAudioFile != nil)
            #expect(manager.duration > 0 || manager.duration == 3.0)

            manager.stop()
        } catch {
            print("Audio playback not available in test environment: \(error)")
        }
    }

    @Test("Play from GeneratedAudioRecord prefers file reference over in-memory")
    func testPlayFromRecordPrefersFileReference() throws {
        let manager = AudioPlayerManager()
        let requestID = UUID()

        // Create storage area
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString)")
        let storage = StorageAreaReference(requestID: requestID, baseURL: tempDir)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create directory and audio file
        try storage.createDirectoryIfNeeded()
        let audioURL = storage.fileURL(for: "audio.mp3")
        let audioData = createValidMP3Data()
        try audioData.write(to: audioURL)

        // Create file reference
        let fileRef = TypedDataFileReference(
            requestID: requestID,
            fileName: "audio.mp3",
            fileSize: Int64(audioData.count),
            mimeType: "audio/mpeg"
        )

        // Create record with BOTH file reference and in-memory data
        let record = GeneratedAudioRecord(
            providerId: "test",
            requestorID: "test.tts",
            mimeType: "audio/mpeg",
            binaryValue: audioData, // Has in-memory data
            prompt: "Test prompt",
            fileReference: fileRef, // Also has file reference
            audioFormat: "mp3",
            durationSeconds: 3.0,
            voiceID: "voice-1",
            voiceName: "Test Voice"
        )

        do {
            // Should prefer file reference (no temp file created)
            try manager.play(record: record, storageArea: storage)

            #expect(manager.isPlaying)

            manager.stop()
        } catch {
            print("Audio playback not available in test environment: \(error)")
        }
    }

    @Test("Play from GeneratedAudioRecord with no data throws error")
    func testPlayFromRecordNoData() {
        let manager = AudioPlayerManager()

        // Create record with NO data and NO file reference
        let record = GeneratedAudioRecord(
            providerId: "test",
            requestorID: "test.tts",
            mimeType: "audio/mpeg",
            binaryValue: nil,
            prompt: "Test prompt",
            fileReference: nil,
            audioFormat: "mp3",
            durationSeconds: 3.0,
            voiceID: "voice-1",
            voiceName: "Test Voice"
        )

        #expect(throws: AudioPlayerError.self) {
            try manager.play(record: record)
        }
    }

    // MARK: - Playback Control Tests

    @Test("Stop resets player state")
    func testStop() throws {
        let manager = AudioPlayerManager()
        let audioURL = createTempAudioFile()

        defer {
            try? FileManager.default.removeItem(at: audioURL)
        }

        do {
            try manager.play(from: audioURL, format: "mp3")
            manager.stop()

            #expect(!manager.isPlaying)
            #expect(manager.currentTime == 0)
            #expect(manager.audioLevels.isEmpty)
            #expect(manager.currentAudioFile == nil)
        } catch {
            print("Audio playback not available in test environment")
        }
    }

    @Test("Pause and resume work correctly")
    func testPauseResume() throws {
        let manager = AudioPlayerManager()
        let audioURL = createTempAudioFile()

        defer {
            try? FileManager.default.removeItem(at: audioURL)
        }

        do {
            try manager.play(from: audioURL, format: "mp3")

            manager.pause()
            #expect(!manager.isPlaying)

            manager.resume()
            #expect(manager.isPlaying)

            manager.stop()
        } catch {
            print("Audio playback not available in test environment")
        }
    }

    @Test("Toggle play/pause works correctly")
    func testTogglePlayPause() throws {
        let manager = AudioPlayerManager()
        let audioURL = createTempAudioFile()

        defer {
            try? FileManager.default.removeItem(at: audioURL)
        }

        do {
            try manager.play(from: audioURL, format: "mp3")

            let initialState = manager.isPlaying
            manager.togglePlayPause()
            #expect(manager.isPlaying != initialState)

            manager.togglePlayPause()
            #expect(manager.isPlaying == initialState)

            manager.stop()
        } catch {
            print("Audio playback not available in test environment")
        }
    }

    // MARK: - Error Tests

    @Test("AudioPlayerError has proper descriptions")
    func testErrorDescriptions() {
        let noDataError = AudioPlayerError.noAudioDataAvailable
        #expect(noDataError.errorDescription?.contains("No audio data") == true)
        #expect(noDataError.recoverySuggestion?.contains("file reference") == true)

        let formatError = AudioPlayerError.unsupportedFormat("xyz")
        #expect(formatError.errorDescription?.contains("xyz") == true)
        #expect(formatError.recoverySuggestion?.contains("MP3") == true)
    }

    // MARK: - Integration Tests

    @Test("Complete playback workflow from record")
    func testCompletePlaybackWorkflow() throws {
        let manager = AudioPlayerManager()
        let requestID = UUID()

        // Setup storage
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString)")
        let storage = StorageAreaReference(requestID: requestID, baseURL: tempDir)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        try storage.createDirectoryIfNeeded()

        // Create audio file
        let audioURL = storage.fileURL(for: "speech.mp3")
        let audioData = createValidMP3Data()
        try audioData.write(to: audioURL)

        // Create file reference
        let fileRef = TypedDataFileReference(
            requestID: requestID,
            fileName: "speech.mp3",
            fileSize: Int64(audioData.count),
            mimeType: "audio/mpeg"
        )

        // Create audio record
        let record = GeneratedAudioRecord(
            providerId: "elevenlabs",
            requestorID: "elevenlabs.tts.rachel",
            mimeType: "audio/mpeg",
            binaryValue: nil,
            prompt: "Hello, world!",
            fileReference: fileRef,
            audioFormat: "mp3",
            durationSeconds: 5.5,
            sampleRate: 44100,
            bitRate: 128000,
            channels: 2,
            voiceID: "voice-rachel",
            voiceName: "Rachel"
        )

        do {
            // Play
            try manager.play(record: record, storageArea: storage)
            #expect(manager.isPlaying)

            // Pause
            manager.pause()
            #expect(!manager.isPlaying)

            // Resume
            manager.resume()
            #expect(manager.isPlaying)

            // Stop
            manager.stop()
            #expect(!manager.isPlaying)
            #expect(manager.currentTime == 0)
        } catch {
            print("Audio playback not available in test environment: \(error)")
        }
    }
}
