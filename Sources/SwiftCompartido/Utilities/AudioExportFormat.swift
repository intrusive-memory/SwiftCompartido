//
//  AudioExportFormat.swift
//  SwiftCompartido
//
//  Audio export format options for converting uncompressed audio to various output formats.
//

import Foundation
import UniformTypeIdentifiers
import AVFoundation

/// Audio export formats supported by AVFoundation
public enum AudioExportFormat: String, CaseIterable, Identifiable, Sendable {
    case m4a = "M4A (AAC)"
    case aiff = "AIFF"
    case wav = "WAV"
    case caf = "CAF (Core Audio)"
    case mp3 = "MP3"

    public var id: String { rawValue }

    /// UTType for the export format
    public var utType: UTType {
        switch self {
        case .m4a:
            return .mpeg4Audio
        case .aiff:
            return .aiff
        case .wav:
            return .wav
        case .caf:
            // CAF doesn't have a predefined UTType, use custom
            return UTType(filenameExtension: "caf") ?? .audio
        case .mp3:
            return .mp3
        }
    }

    /// File extension for the format
    public var fileExtension: String {
        switch self {
        case .m4a:
            return "m4a"
        case .aiff:
            return "aiff"
        case .wav:
            return "wav"
        case .caf:
            return "caf"
        case .mp3:
            return "mp3"
        }
    }

    /// AVFoundation file type identifier
    public var avFileType: AVFileType {
        switch self {
        case .m4a:
            return .m4a
        case .aiff:
            return .aiff
        case .wav:
            return .wav
        case .caf:
            return .caf
        case .mp3:
            #if os(macOS)
            // MP3 export is macOS-only via AVAssetExportSession
            return .mp3
            #else
            // iOS doesn't support direct MP3 export
            return .m4a
            #endif
        }
    }

    /// Audio settings for AVAudioFile export
    public var audioSettings: [String: Any] {
        switch self {
        case .m4a:
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000
            ]
        case .mp3:
            return [
                AVFormatIDKey: kAudioFormatMPEGLayer3,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 192000
            ]
        case .aiff:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: true
            ]
        case .wav:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
        case .caf:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false
            ]
        }
    }

    /// User-friendly description for the format
    public var description: String {
        switch self {
        case .m4a:
            return "M4A (AAC) - Compressed, good quality, widely supported"
        case .aiff:
            return "AIFF - Uncompressed, highest quality, large file size"
        case .wav:
            return "WAV - Uncompressed, widely supported, large file size"
        case .caf:
            return "CAF - Apple's Core Audio Format, flexible"
        case .mp3:
            #if os(macOS)
            return "MP3 - Compressed, universal compatibility"
            #else
            return "MP3 - Not available on iOS, use M4A instead"
            #endif
        }
    }

    /// Check if format is available on current platform
    public var isAvailable: Bool {
        #if os(iOS)
        // MP3 export not available on iOS
        return self != .mp3
        #else
        return true
        #endif
    }
}
