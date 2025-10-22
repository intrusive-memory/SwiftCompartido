//
//  AudioPlayerManager.swift
//  SwiftHablare
//
//  Audio player manager for playing audio from database
//

import AVFoundation
import Combine
import Foundation

/// Manages audio playback from database-stored audio files
@MainActor
public final class AudioPlayerManager: NSObject, ObservableObject {
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0
    @Published public var audioLevels: [Float] = []
    @Published public var currentAudioFile: AudioFile?

    private var audioPlayer: AVAudioPlayer?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var progressTimer: Timer?
    private var levelTimer: Timer?

    public override init() {
        super.init()
        setupAudioSession()
    }

    deinit {
        // Cleanup happens in stop()
    }

    private func setupAudioSession() {
        // macOS doesn't require AVAudioSession setup
    }

    /// Play audio from an AudioFile model
    public func play(_ audioFile: AudioFile) throws {
        // Stop any current playback
        stop()

        currentAudioFile = audioFile

        // Create temporary file URL for the audio data
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(audioFile.audioFormat)

        try audioFile.audioData.write(to: tempURL)

        // Initialize audio player
        audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.isMeteringEnabled = true

        duration = audioPlayer?.duration ?? audioFile.duration ?? 0

        // Start playback
        audioPlayer?.play()
        isPlaying = true

        // Start updating current time
        startDisplayLink()

        // Start monitoring audio levels for visualization
        startLevelMonitoring()
    }

    /// Play audio directly from a file URL
    ///
    /// This method is optimized for file-based storage and avoids creating temporary files.
    /// Use this when playing audio from `TypedDataFileReference`.
    ///
    /// - Parameters:
    ///   - url: The URL to the audio file
    ///   - format: The audio format (e.g., "mp3", "wav")
    ///   - duration: Optional duration in seconds (if known)
    /// - Throws: Audio player initialization errors
    public func play(from url: URL, format: String, duration: TimeInterval? = nil) throws {
        // Stop any current playback
        stop()

        // Create AudioFile model for tracking (with default values for unused fields)
        currentAudioFile = AudioFile(
            text: "",
            voiceId: "",
            providerId: "",
            audioData: Data(), // Empty since we're playing from URL
            audioFormat: format,
            duration: duration ?? 0
        )

        // Initialize audio player directly from URL
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.isMeteringEnabled = true

        self.duration = audioPlayer?.duration ?? duration ?? 0

        // Start playback
        audioPlayer?.play()
        isPlaying = true

        // Start updating current time
        startDisplayLink()

        // Start monitoring audio levels for visualization
        startLevelMonitoring()
    }

    /// Toggle play/pause
    public func togglePlayPause() {
        guard let player = audioPlayer else { return }

        if player.isPlaying {
            pause()
        } else {
            resume()
        }
    }

    /// Pause playback
    public func pause() {
        audioPlayer?.pause()
        isPlaying = false
        progressTimer?.invalidate()
        levelTimer?.invalidate()
    }

    /// Resume playback
    public func resume() {
        audioPlayer?.play()
        isPlaying = true
        startDisplayLink()
        startLevelMonitoring()
    }

    /// Stop playback
    public func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        audioLevels = []
        currentAudioFile = nil
        progressTimer?.invalidate()
        progressTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }

    /// Seek to specific time
    public func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = min(max(0, time), duration)
        currentTime = player.currentTime
    }

    private func startDisplayLink() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }

    @MainActor private func updateProgress() {
        currentTime = audioPlayer?.currentTime ?? 0
    }

    private func startLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevels()
            }
        }
    }

    private func updateAudioLevels() {
        guard let player = audioPlayer else { return }

        player.updateMeters()

        // Get average power for each channel and convert to normalized values
        var levels: [Float] = []
        for channel in 0..<player.numberOfChannels {
            let power = player.averagePower(forChannel: channel)
            // Convert decibels to normalized value (0-1)
            let normalized = powf(10.0, power / 20.0)
            levels.append(normalized)
        }

        // Store the levels for visualization
        audioLevels = levels
    }

    /// Play audio from a TypedDataStorage record with audio/* mimeType
    ///
    /// Automatically handles both file-based and in-memory storage.
    /// Prefers file-based storage when available for better performance.
    ///
    /// - Parameters:
    ///   - record: The audio record to play (TypedDataStorage with audio/* mimeType)
    ///   - storageArea: Storage area reference (required if using file-based storage)
    /// - Throws: Audio player initialization errors or missing data errors
    public func play(record: TypedDataStorage, storageArea: StorageAreaReference? = nil) throws {
        // Prefer file-based storage (Phase 6 architecture)
        if let fileRef = record.fileReference, let storage = storageArea {
            let fileURL = fileRef.fileURL(in: storage)
            let format = record.audioFormat ?? "mp3"  // Default to mp3 if not specified
            try play(from: fileURL, format: format, duration: record.durationSeconds)
            return
        }

        // Fallback to in-memory data
        if let audioData = record.binaryValue {
            let audioFile = AudioFile(
                text: record.prompt,
                voiceId: record.voiceID ?? "",
                providerId: record.providerId,
                audioData: audioData,
                audioFormat: record.audioFormat ?? "mp3",
                duration: record.durationSeconds,
                sampleRate: record.sampleRate,
                bitRate: record.bitRate,
                channels: record.channels
            )
            try play(audioFile)
            return
        }

        // No audio data available
        throw AudioPlayerError.noAudioDataAvailable
    }
}

// MARK: - Errors

/// Errors that can occur during audio playback
public enum AudioPlayerError: Error, LocalizedError {
    /// No audio data is available (neither file reference nor in-memory data)
    case noAudioDataAvailable

    /// Audio file format is not supported
    case unsupportedFormat(String)

    public var errorDescription: String? {
        switch self {
        case .noAudioDataAvailable:
            return "No audio data available. The record must have either audioData or a fileReference."
        case .unsupportedFormat(let format):
            return "Audio format '\(format)' is not supported by AVAudioPlayer."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .noAudioDataAvailable:
            return "Ensure the audio record has been properly saved with either in-memory data or a file reference."
        case .unsupportedFormat:
            return "Convert the audio to a supported format such as MP3, WAV, or AAC."
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerManager: @preconcurrency AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player decode error: \(error?.localizedDescription ?? "Unknown")")
        stop()
    }
}
