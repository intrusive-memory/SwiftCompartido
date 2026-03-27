//
//  AudioConverter.swift
//  SwiftCompartido
//
//  Converts uncompressed audio (PCM/AIFF) to various output formats using AVFoundation.
//

import AVFoundation
import Foundation

/// Converts audio data between different formats using AVFoundation
public struct AudioConverter {

  /// Convert audio data from one format to another
  ///
  /// - Parameters:
  ///   - inputData: Raw audio data (PCM or AIFF)
  ///   - outputFormat: Desired output format
  /// - Returns: Converted audio data
  /// - Throws: Conversion errors
  public static func convert(_ inputData: Data, to outputFormat: AudioExportFormat) throws -> Data {
    // Create temporary URLs for input and output
    let inputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("input")

    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(outputFormat.fileExtension)

    defer {
      // Clean up temporary files
      try? FileManager.default.removeItem(at: inputURL)
      try? FileManager.default.removeItem(at: outputURL)
    }

    // Write input data to temporary file
    try inputData.write(to: inputURL)

    // Read input audio file
    let inputFile = try AVAudioFile(forReading: inputURL)

    // Create output file with desired format
    let outputFile = try AVAudioFile(
      forWriting: outputURL,
      settings: outputFormat.audioSettings,
      commonFormat: .pcmFormatInt16,
      interleaved: true
    )

    // Get buffer size
    let bufferSize: AVAudioFrameCount = 4096
    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: inputFile.processingFormat,
        frameCapacity: bufferSize
      )
    else {
      throw AudioConversionError.bufferCreationFailed
    }

    // Convert audio by reading and writing in chunks
    // AVAudioFile automatically handles format conversion
    while inputFile.framePosition < inputFile.length {
      let framesToRead = min(
        bufferSize, AVAudioFrameCount(inputFile.length - inputFile.framePosition))
      try inputFile.read(into: buffer, frameCount: framesToRead)

      // Write directly - AVAudioFile handles conversion
      try outputFile.write(from: buffer)
    }

    // Read converted data
    let convertedData = try Data(contentsOf: outputURL)
    return convertedData
  }

  /// Concatenate multiple audio files into a single file
  ///
  /// - Parameters:
  ///   - audioDataArray: Array of audio data to concatenate
  ///   - outputFormat: Desired output format
  /// - Returns: Concatenated audio data
  /// - Throws: Conversion errors
  public static func concatenate(_ audioDataArray: [Data], to outputFormat: AudioExportFormat)
    async throws -> Data
  {
    guard !audioDataArray.isEmpty else {
      throw AudioConversionError.emptyInput
    }

    // If only one file, just convert it
    if audioDataArray.count == 1, let data = audioDataArray.first {
      return try convert(data, to: outputFormat)
    }

    // Create output URL
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(outputFormat.fileExtension)

    defer {
      try? FileManager.default.removeItem(at: outputURL)
    }

    // Use AVAssetWriter for concatenation
    let composition = AVMutableComposition()
    var currentTime = CMTime.zero

    // Add each audio file to the composition
    var tempURLs: [URL] = []
    for (index, audioData) in audioDataArray.enumerated() {
      let inputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("input_\(index)")
        .appendingPathExtension("audio")

      tempURLs.append(inputURL)

      // Write temporary file
      try audioData.write(to: inputURL)

      // Create asset from file
      let asset = AVURLAsset(url: inputURL)

      // Get audio track
      let tracks = try await asset.loadTracks(withMediaType: .audio)
      guard let audioTrack = tracks.first else {
        continue
      }

      // Add to composition
      let compositionTrack = composition.addMutableTrack(
        withMediaType: .audio,
        preferredTrackID: kCMPersistentTrackID_Invalid
      )

      let duration = try await asset.load(.duration)
      let timeRange = CMTimeRange(start: .zero, duration: duration)
      try compositionTrack?.insertTimeRange(timeRange, of: audioTrack, at: currentTime)

      currentTime = CMTimeAdd(currentTime, duration)
    }

    // Clean up temp files after composition is built
    defer {
      for url in tempURLs {
        try? FileManager.default.removeItem(at: url)
      }
    }

    // Export composition
    // Choose preset based on output format
    let presetName: String
    switch outputFormat {
    case .m4a, .mp3:
      presetName = AVAssetExportPresetAppleM4A
    case .aiff, .wav, .caf:
      presetName = AVAssetExportPresetPassthrough
    }

    guard
      let exportSession = AVAssetExportSession(
        asset: composition,
        presetName: presetName
      )
    else {
      throw AudioConversionError.exportSessionCreationFailed
    }

    exportSession.outputURL = outputURL
    exportSession.outputFileType = outputFormat.avFileType

    // Set audio settings for compressed formats
    if outputFormat == .m4a || outputFormat == .mp3 {
      exportSession.audioMix = nil
      exportSession.audioTimePitchAlgorithm = .spectral
    }

    // Perform export
    try await exportSession.export(to: outputURL, as: outputFormat.avFileType)

    // Read concatenated data
    let concatenatedData = try Data(contentsOf: outputURL)
    return concatenatedData
  }

}

// MARK: - Errors

public enum AudioConversionError: LocalizedError {
  case emptyInput
  case bufferCreationFailed
  case exportSessionCreationFailed
  case exportFailed(String)

  public var errorDescription: String? {
    switch self {
    case .emptyInput:
      return "No audio data provided for conversion"
    case .bufferCreationFailed:
      return "Failed to create audio buffer"
    case .exportSessionCreationFailed:
      return "Failed to create export session"
    case .exportFailed(let reason):
      return "Audio export failed: \(reason)"
    }
  }
}
