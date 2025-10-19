//
//  OutputFileTypeTests.swift
//  SwiftHablareTests
//
//  Phase 6A: Tests for OutputFileType struct
//

import XCTest
import UniformTypeIdentifiers
@testable import SwiftCompartido

final class OutputFileTypeTests: XCTestCase {

    // MARK: - Initialization Tests

    func testCustomInitialization() {
        let fileType = OutputFileType(
            mimeType: "application/json",
            fileExtension: "json",
            utType: .json,
            category: .text,
            serializationFormat: .json,
            storeAsFileThreshold: 50_000
        )

        XCTAssertEqual(fileType.mimeType, "application/json")
        XCTAssertEqual(fileType.fileExtension, "json")
        XCTAssertEqual(fileType.utType, .json)
        XCTAssertEqual(fileType.category, .text)
        XCTAssertEqual(fileType.serializationFormat, .json)
        XCTAssertEqual(fileType.storeAsFileThreshold, 50_000)
    }

    // MARK: - Common File Types Tests

    func testPlainTextFileType() {
        let fileType = OutputFileType.plainText()
        XCTAssertEqual(fileType.mimeType, "text/plain")
        XCTAssertEqual(fileType.fileExtension, "txt")
        XCTAssertEqual(fileType.category, .text)
        XCTAssertEqual(fileType.serializationFormat, .json)
    }

    func testJSONFileType() {
        let fileType = OutputFileType.json()
        XCTAssertEqual(fileType.mimeType, "application/json")
        XCTAssertEqual(fileType.fileExtension, "json")
        XCTAssertEqual(fileType.category, .text)
        XCTAssertEqual(fileType.serializationFormat, .json)
    }

    func testMP3FileType() {
        let fileType = OutputFileType.mp3()
        XCTAssertEqual(fileType.mimeType, "audio/mpeg")
        XCTAssertEqual(fileType.fileExtension, "mp3")
        XCTAssertEqual(fileType.category, .audio)
        XCTAssertEqual(fileType.serializationFormat, .binary)
    }

    func testWAVFileType() {
        let fileType = OutputFileType.wav()
        XCTAssertEqual(fileType.mimeType, "audio/wav")
        XCTAssertEqual(fileType.fileExtension, "wav")
        XCTAssertEqual(fileType.category, .audio)
    }

    func testM4AFileType() {
        let fileType = OutputFileType.m4a()
        XCTAssertEqual(fileType.mimeType, "audio/mp4")
        XCTAssertEqual(fileType.fileExtension, "m4a")
        XCTAssertEqual(fileType.category, .audio)
    }

    func testPNGFileType() {
        let fileType = OutputFileType.png()
        XCTAssertEqual(fileType.mimeType, "image/png")
        XCTAssertEqual(fileType.fileExtension, "png")
        XCTAssertEqual(fileType.category, .image)
    }

    func testJPEGFileType() {
        let fileType = OutputFileType.jpeg()
        XCTAssertEqual(fileType.mimeType, "image/jpeg")
        XCTAssertEqual(fileType.fileExtension, "jpg")
        XCTAssertEqual(fileType.category, .image)
    }

    func testMP4FileType() {
        let fileType = OutputFileType.mp4()
        XCTAssertEqual(fileType.mimeType, "video/mp4")
        XCTAssertEqual(fileType.fileExtension, "mp4")
        XCTAssertEqual(fileType.category, .video)
    }

    func testMOVFileType() {
        let fileType = OutputFileType.mov()
        XCTAssertEqual(fileType.mimeType, "video/quicktime")
        XCTAssertEqual(fileType.fileExtension, "mov")
        XCTAssertEqual(fileType.category, .video)
    }

    func testPlistFileType() {
        let fileType = OutputFileType.plist()
        XCTAssertEqual(fileType.mimeType, "application/x-plist")
        XCTAssertEqual(fileType.fileExtension, "plist")
        XCTAssertEqual(fileType.serializationFormat, .plist)
    }

    func testBinaryFileType() {
        let fileType = OutputFileType.binary(category: .embedding)
        XCTAssertEqual(fileType.mimeType, "application/octet-stream")
        XCTAssertEqual(fileType.fileExtension, "bin")
        XCTAssertEqual(fileType.category, .embedding)
        XCTAssertEqual(fileType.serializationFormat, .binary)
    }

    // MARK: - Storage Decision Tests

    func testShouldStoreAsFile_ExceedsThreshold() {
        let fileType = OutputFileType.json(storeAsFileThreshold: 50_000)
        XCTAssertTrue(fileType.shouldStoreAsFile(estimatedSize: 100_000))
    }

    func testShouldStoreAsFile_BelowThreshold() {
        let fileType = OutputFileType.json(storeAsFileThreshold: 50_000)
        XCTAssertFalse(fileType.shouldStoreAsFile(estimatedSize: 10_000))
    }

    func testShouldStoreAsFile_EqualToThreshold() {
        let fileType = OutputFileType.json(storeAsFileThreshold: 50_000)
        XCTAssertTrue(fileType.shouldStoreAsFile(estimatedSize: 50_000))
    }

    func testShouldStoreAsFile_NoThreshold() {
        let fileType = OutputFileType.json(storeAsFileThreshold: nil)
        XCTAssertFalse(fileType.shouldStoreAsFile(estimatedSize: 1_000_000))
    }

    func testShouldStoreAsFile_UnknownSize_Audio() {
        let fileType = OutputFileType.mp3() // Audio typically needs storage
        XCTAssertTrue(fileType.shouldStoreAsFile(estimatedSize: nil))
    }

    func testShouldStoreAsFile_UnknownSize_Text() {
        let fileType = OutputFileType.json() // Text typically doesn't need storage
        XCTAssertFalse(fileType.shouldStoreAsFile(estimatedSize: nil))
    }

    // MARK: - Custom Threshold Tests

    func testCustomThreshold() {
        let customThreshold: Int64 = 1_000_000 // 1MB
        let fileType = OutputFileType.json(storeAsFileThreshold: customThreshold)
        XCTAssertEqual(fileType.storeAsFileThreshold, customThreshold)
    }

    // MARK: - Codable Tests

    func testCodableRoundTrip() throws {
        let original = OutputFileType.json(category: .text, storeAsFileThreshold: 50_000)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OutputFileType.self, from: encoded)

        XCTAssertEqual(decoded.mimeType, original.mimeType)
        XCTAssertEqual(decoded.fileExtension, original.fileExtension)
        XCTAssertEqual(decoded.category, original.category)
        XCTAssertEqual(decoded.serializationFormat, original.serializationFormat)
        XCTAssertEqual(decoded.storeAsFileThreshold, original.storeAsFileThreshold)
    }

    func testCodableWithNilUTType() throws {
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

        XCTAssertEqual(decoded.mimeType, original.mimeType)
        XCTAssertNil(decoded.utType)
    }

    // MARK: - Equatable Tests

    func testEquality() {
        let fileType1 = OutputFileType.json()
        let fileType2 = OutputFileType.json()
        XCTAssertEqual(fileType1, fileType2)
    }

    func testInequality_DifferentExtension() {
        let fileType1 = OutputFileType.json()
        let fileType2 = OutputFileType.mp3()
        XCTAssertNotEqual(fileType1, fileType2)
    }

    // MARK: - Hashable Tests

    func testHashable() {
        let fileType1 = OutputFileType.json()
        let fileType2 = OutputFileType.json()
        let fileType3 = OutputFileType.mp3()

        var set = Set<OutputFileType>()
        set.insert(fileType1)
        set.insert(fileType2)
        set.insert(fileType3)

        XCTAssertEqual(set.count, 2) // fileType1 and fileType2 are equal
    }

    // MARK: - Sendable Conformance Tests

    func testSendableConformance() async {
        // Should be able to pass across actor boundaries
        let fileType = OutputFileType.json()

        await Task {
            XCTAssertEqual(fileType.mimeType, "application/json")
        }.value
    }
}
