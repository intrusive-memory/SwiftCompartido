//
//  OutputFileTypeTests.swift
//  SwiftHablareTests
//
//  Phase 6A: Tests for OutputFileType struct
//

import Foundation
import Testing
import UniformTypeIdentifiers

@testable import SwiftCompartido

struct OutputFileTypeTests {

  // MARK: - Initialization Tests

  @Test("Custom initialization")
  func customInitialization() {
    let fileType = OutputFileType(
      mimeType: "application/json",
      fileExtension: "json",
      utType: .json,
      category: .text,
      serializationFormat: .json,
      storeAsFileThreshold: 50_000
    )

    #expect(fileType.mimeType == "application/json")
    #expect(fileType.fileExtension == "json")
    #expect(fileType.utType == .json)
    #expect(fileType.category == .text)
    #expect(fileType.serializationFormat == .json)
    #expect(fileType.storeAsFileThreshold == 50_000)
  }

  // MARK: - Common File Types Tests

  @Test("Plain text file type")
  func plainTextFileType() {
    let fileType = OutputFileType.plainText()
    #expect(fileType.mimeType == "text/plain")
    #expect(fileType.fileExtension == "txt")
    #expect(fileType.category == .text)
    #expect(fileType.serializationFormat == .json)
  }

  @Test("JSON file type")
  func jsonFileType() {
    let fileType = OutputFileType.json()
    #expect(fileType.mimeType == "application/json")
    #expect(fileType.fileExtension == "json")
    #expect(fileType.category == .text)
    #expect(fileType.serializationFormat == .json)
  }

  @Test("MP3 file type")
  func mp3FileType() {
    let fileType = OutputFileType.mp3()
    #expect(fileType.mimeType == "audio/mpeg")
    #expect(fileType.fileExtension == "mp3")
    #expect(fileType.category == .audio)
    #expect(fileType.serializationFormat == .binary)
  }

  @Test("WAV file type")
  func wavFileType() {
    let fileType = OutputFileType.wav()
    #expect(fileType.mimeType == "audio/wav")
    #expect(fileType.fileExtension == "wav")
    #expect(fileType.category == .audio)
  }

  @Test("M4A file type")
  func m4aFileType() {
    let fileType = OutputFileType.m4a()
    #expect(fileType.mimeType == "audio/mp4")
    #expect(fileType.fileExtension == "m4a")
    #expect(fileType.category == .audio)
  }

  @Test("PNG file type")
  func pngFileType() {
    let fileType = OutputFileType.png()
    #expect(fileType.mimeType == "image/png")
    #expect(fileType.fileExtension == "png")
    #expect(fileType.category == .image)
  }

  @Test("JPEG file type")
  func jpegFileType() {
    let fileType = OutputFileType.jpeg()
    #expect(fileType.mimeType == "image/jpeg")
    #expect(fileType.fileExtension == "jpg")
    #expect(fileType.category == .image)
  }

  @Test("MP4 file type")
  func mp4FileType() {
    let fileType = OutputFileType.mp4()
    #expect(fileType.mimeType == "video/mp4")
    #expect(fileType.fileExtension == "mp4")
    #expect(fileType.category == .video)
  }

  @Test("MOV file type")
  func movFileType() {
    let fileType = OutputFileType.mov()
    #expect(fileType.mimeType == "video/quicktime")
    #expect(fileType.fileExtension == "mov")
    #expect(fileType.category == .video)
  }

  @Test("Plist file type")
  func plistFileType() {
    let fileType = OutputFileType.plist()
    #expect(fileType.mimeType == "application/x-plist")
    #expect(fileType.fileExtension == "plist")
    #expect(fileType.serializationFormat == .plist)
  }

  @Test("Binary file type")
  func binaryFileType() {
    let fileType = OutputFileType.binary(category: .embedding)
    #expect(fileType.mimeType == "application/octet-stream")
    #expect(fileType.fileExtension == "bin")
    #expect(fileType.category == .embedding)
    #expect(fileType.serializationFormat == .binary)
  }

  // MARK: - Storage Decision Tests

  @Test("Should store as file when exceeds threshold")
  func shouldStoreAsFileExceedsThreshold() {
    let fileType = OutputFileType.json(storeAsFileThreshold: 50_000)
    #expect(fileType.shouldStoreAsFile(estimatedSize: 100_000))
  }

  @Test("Should not store as file when below threshold")
  func shouldStoreAsFileBelowThreshold() {
    let fileType = OutputFileType.json(storeAsFileThreshold: 50_000)
    #expect(!fileType.shouldStoreAsFile(estimatedSize: 10_000))
  }

  @Test("Should store as file when equal to threshold")
  func shouldStoreAsFileEqualToThreshold() {
    let fileType = OutputFileType.json(storeAsFileThreshold: 50_000)
    #expect(fileType.shouldStoreAsFile(estimatedSize: 50_000))
  }

  @Test("Should not store as file when no threshold")
  func shouldStoreAsFileNoThreshold() {
    let fileType = OutputFileType.json(storeAsFileThreshold: nil)
    #expect(!fileType.shouldStoreAsFile(estimatedSize: 1_000_000))
  }

  @Test("Should store as file for audio with unknown size")
  func shouldStoreAsFileUnknownSizeAudio() {
    let fileType = OutputFileType.mp3()  // Audio typically needs storage
    #expect(fileType.shouldStoreAsFile(estimatedSize: nil))
  }

  @Test("Should not store as file for text with unknown size")
  func shouldStoreAsFileUnknownSizeText() {
    let fileType = OutputFileType.json()  // Text typically doesn't need storage
    #expect(!fileType.shouldStoreAsFile(estimatedSize: nil))
  }

  // MARK: - Custom Threshold Tests

  @Test("Custom threshold")
  func customThreshold() {
    let customThreshold: Int64 = 1_000_000  // 1MB
    let fileType = OutputFileType.json(storeAsFileThreshold: customThreshold)
    #expect(fileType.storeAsFileThreshold == customThreshold)
  }

  // MARK: - Codable Tests

  @Test("Codable round trip")
  func codableRoundTrip() throws {
    let original = OutputFileType.json(category: .text, storeAsFileThreshold: 50_000)
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(OutputFileType.self, from: encoded)

    #expect(decoded.mimeType == original.mimeType)
    #expect(decoded.fileExtension == original.fileExtension)
    #expect(decoded.category == original.category)
    #expect(decoded.serializationFormat == original.serializationFormat)
    #expect(decoded.storeAsFileThreshold == original.storeAsFileThreshold)
  }

  @Test("Codable with nil UTType")
  func codableWithNilUTType() throws {
    let original = OutputFileType(
      mimeType: "application/x-custom",
      fileExtension: "custom",
      utType: nil,
      category: .structuredData,
      serializationFormat: .binary,
      storeAsFileThreshold: 10_000
    )

    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(OutputFileType.self, from: encoded)

    #expect(decoded.mimeType == original.mimeType)
    #expect(decoded.utType == nil)
  }

  // MARK: - Equatable Tests

  @Test("Equality")
  func equality() {
    let fileType1 = OutputFileType.json()
    let fileType2 = OutputFileType.json()
    #expect(fileType1 == fileType2)
  }

  @Test("Inequality with different extension")
  func inequalityDifferentExtension() {
    let fileType1 = OutputFileType.json()
    let fileType2 = OutputFileType.mp3()
    #expect(fileType1 != fileType2)
  }

  // MARK: - Hashable Tests

  @Test("Hashable")
  func hashable() {
    let fileType1 = OutputFileType.json()
    let fileType2 = OutputFileType.json()
    let fileType3 = OutputFileType.mp3()

    var set = Set<OutputFileType>()
    set.insert(fileType1)
    set.insert(fileType2)
    set.insert(fileType3)

    #expect(set.count == 2)  // fileType1 and fileType2 are equal
  }

  // MARK: - Sendable Conformance Tests

  @Test("Sendable conformance")
  func sendableConformance() async {
    // Should be able to pass across actor boundaries
    let fileType = OutputFileType.json()

    await Task {
      #expect(fileType.mimeType == "application/json")
    }.value
  }
}
