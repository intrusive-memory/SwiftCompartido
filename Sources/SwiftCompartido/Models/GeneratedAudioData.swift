//
//  GeneratedAudioData.swift
//  SwiftHablare
//
//  Phase 6C: Typed audio data structures
//

import Foundation

/// Typed data structure for generated audio content.
///
/// This is the in-memory representation of generated audio that includes
/// metadata about the generation. Audio data is typically stored in files
/// due to size, so this struct holds metadata and optional data.
///
/// ## Example
/// ```swift
/// let audioData = GeneratedAudioData(
///     audioData: mp3Data,
///     format: .mp3,
///     voiceID: "21m00Tcm4TlvDq8ikWAM",
///     voiceName: "Rachel",
///     model: "eleven_monolingual_v1"
/// )
/// ```
public struct GeneratedAudioData: Codable, Sendable, SerializableTypedData {

    // MARK: - Audio Format

    /// Audio format enumeration
    public enum AudioFormat: String, Codable, Sendable {
        case mp3 = "mp3"
        case wav = "wav"
        case m4a = "m4a"
        case flac = "flac"
        case ogg = "ogg"

        public var mimeType: String {
            switch self {
            case .mp3: return "audio/mpeg"
            case .wav: return "audio/wav"
            case .m4a: return "audio/mp4"
            case .flac: return "audio/flac"
            case .ogg: return "audio/ogg"
            }
        }

        public var fileExtension: String {
            return rawValue
        }
    }

    // MARK: - Properties

    /// The audio data (may be nil if stored in file)
    ///
    /// For file-based storage, this will be nil and data loaded from file reference.
    public let audioData: Data?

    /// Audio format
    public let format: AudioFormat

    /// Duration in seconds (if available)
    public let durationSeconds: Double?

    /// Sample rate in Hz (e.g., 44100, 48000)
    public let sampleRate: Int?

    /// Bit rate in bps (if available)
    public let bitRate: Int?

    /// Number of channels (1 = mono, 2 = stereo)
    public let channels: Int?

    /// Voice ID used for generation
    public let voiceID: String

    /// Voice name (human-readable)
    public let voiceName: String

    /// Model identifier that generated this audio
    public let model: String

    /// File size in bytes (if audio data present)
    public var fileSize: Int {
        audioData?.count ?? 0
    }

    // MARK: - Initialization

    /// Creates generated audio data
    ///
    /// - Parameters:
    ///   - audioData: The audio data (nil if stored in file)
    ///   - format: Audio format
    ///   - durationSeconds: Duration in seconds (optional)
    ///   - sampleRate: Sample rate in Hz (optional)
    ///   - bitRate: Bit rate in bps (optional)
    ///   - channels: Number of channels (optional)
    ///   - voiceID: Voice ID used
    ///   - voiceName: Voice name
    ///   - model: Model identifier
    public init(
        audioData: Data?,
        format: AudioFormat,
        durationSeconds: Double? = nil,
        sampleRate: Int? = nil,
        bitRate: Int? = nil,
        channels: Int? = nil,
        voiceID: String,
        voiceName: String,
        model: String
    ) {
        self.audioData = audioData
        self.format = format
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.bitRate = bitRate
        self.channels = channels
        self.voiceID = voiceID
        self.voiceName = voiceName
        self.model = model
    }

    // MARK: - SerializableTypedData Conformance

    /// Prefers plist format for audio metadata
    public var preferredFormat: SerializationFormat {
        .plist
    }
}

/// Configuration for audio generation requests.
///
/// Contains parameters that control how audio is generated,
/// such as voice settings and model selection.
public struct AudioGenerationConfig: Codable, Sendable {

    /// Voice ID to use for generation
    public var voiceID: String

    /// Voice name (human-readable, for display)
    public var voiceName: String

    /// Model ID to use
    public var modelID: String

    /// Stability (0.0 = very variable, 1.0 = very stable)
    public var stability: Double

    /// Similarity boost / clarity boost (0.0 = low, 1.0 = high)
    public var similarityBoost: Double

    /// Output format
    public var outputFormat: GeneratedAudioData.AudioFormat

    /// Creates an audio generation configuration
    ///
    /// - Parameters:
    ///   - voiceID: Voice ID to use
    ///   - voiceName: Voice name (display)
    ///   - modelID: Model ID (default: eleven_monolingual_v1)
    ///   - stability: Stability setting (default: 0.5)
    ///   - similarityBoost: Clarity boost (default: 0.75)
    ///   - outputFormat: Output format (default: mp3)
    public init(
        voiceID: String,
        voiceName: String,
        modelID: String = "eleven_monolingual_v1",
        stability: Double = 0.5,
        similarityBoost: Double = 0.75,
        outputFormat: GeneratedAudioData.AudioFormat = .mp3
    ) {
        self.voiceID = voiceID
        self.voiceName = voiceName
        self.modelID = modelID
        self.stability = stability
        self.similarityBoost = similarityBoost
        self.outputFormat = outputFormat
    }

    /// Default configuration with Rachel voice
    public static let `default` = AudioGenerationConfig(
        voiceID: "21m00Tcm4TlvDq8ikWAM",
        voiceName: "Rachel"
    )

    /// Stable configuration (less variable)
    public static func stable(voiceID: String, voiceName: String) -> AudioGenerationConfig {
        AudioGenerationConfig(
            voiceID: voiceID,
            voiceName: voiceName,
            stability: 0.75,
            similarityBoost: 0.5
        )
    }

    /// Expressive configuration (more variable)
    public static func expressive(voiceID: String, voiceName: String) -> AudioGenerationConfig {
        AudioGenerationConfig(
            voiceID: voiceID,
            voiceName: voiceName,
            stability: 0.25,
            similarityBoost: 0.9
        )
    }
}
