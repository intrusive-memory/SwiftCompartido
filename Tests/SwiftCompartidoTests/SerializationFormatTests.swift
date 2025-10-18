//
//  SerializationFormatTests.swift
//  SwiftHablareTests
//
//  Phase 6A: Tests for SerializationFormat enum
//

import XCTest
@testable import SwiftCompartido

@available(macOS 15.0, iOS 17.0, *)
final class SerializationFormatTests: XCTestCase {

    // MARK: - Basic Properties Tests

    func testAllCasesArePresent() {
        let formats = SerializationFormat.allCases
        XCTAssertEqual(formats.count, 5, "Should have 5 serialization formats")
        XCTAssertTrue(formats.contains(.json))
        XCTAssertTrue(formats.contains(.plist))
        XCTAssertTrue(formats.contains(.binary))
        XCTAssertTrue(formats.contains(.protobuf))
        XCTAssertTrue(formats.contains(.messagepack))
    }

    func testRawValuesAreCorrect() {
        XCTAssertEqual(SerializationFormat.json.rawValue, "json")
        XCTAssertEqual(SerializationFormat.plist.rawValue, "plist")
        XCTAssertEqual(SerializationFormat.binary.rawValue, "binary")
        XCTAssertEqual(SerializationFormat.protobuf.rawValue, "protobuf")
        XCTAssertEqual(SerializationFormat.messagepack.rawValue, "messagepack")
    }

    func testIdentifiableConformance() {
        let format = SerializationFormat.json
        XCTAssertEqual(format.id, format.rawValue)
    }

    // MARK: - Display Properties Tests

    func testDisplayNames() {
        XCTAssertEqual(SerializationFormat.json.displayName, "JSON")
        XCTAssertEqual(SerializationFormat.plist.displayName, "Property List")
        XCTAssertEqual(SerializationFormat.binary.displayName, "Binary")
        XCTAssertEqual(SerializationFormat.protobuf.displayName, "Protocol Buffers")
        XCTAssertEqual(SerializationFormat.messagepack.displayName, "MessagePack")
    }

    func testDescriptions() {
        XCTAssertFalse(SerializationFormat.json.description.isEmpty)
        XCTAssertFalse(SerializationFormat.plist.description.isEmpty)
        XCTAssertFalse(SerializationFormat.binary.description.isEmpty)
        XCTAssertFalse(SerializationFormat.protobuf.description.isEmpty)
        XCTAssertFalse(SerializationFormat.messagepack.description.isEmpty)
    }

    // MARK: - File Properties Tests

    func testFileExtensions() {
        XCTAssertEqual(SerializationFormat.json.fileExtension, "json")
        XCTAssertEqual(SerializationFormat.plist.fileExtension, "plist")
        XCTAssertEqual(SerializationFormat.binary.fileExtension, "bin")
        XCTAssertEqual(SerializationFormat.protobuf.fileExtension, "pb")
        XCTAssertEqual(SerializationFormat.messagepack.fileExtension, "msgpack")
    }

    func testMimeTypes() {
        XCTAssertEqual(SerializationFormat.json.mimeType, "application/json")
        XCTAssertEqual(SerializationFormat.plist.mimeType, "application/x-plist")
        XCTAssertEqual(SerializationFormat.binary.mimeType, "application/octet-stream")
        XCTAssertEqual(SerializationFormat.protobuf.mimeType, "application/x-protobuf")
        XCTAssertEqual(SerializationFormat.messagepack.mimeType, "application/x-msgpack")
    }

    // MARK: - Format Characteristics Tests

    func testIsHumanReadable() {
        XCTAssertTrue(SerializationFormat.json.isHumanReadable)
        XCTAssertTrue(SerializationFormat.plist.isHumanReadable)
        XCTAssertFalse(SerializationFormat.binary.isHumanReadable)
        XCTAssertFalse(SerializationFormat.protobuf.isHumanReadable)
        XCTAssertFalse(SerializationFormat.messagepack.isHumanReadable)
    }

    func testHasDefaultImplementation() {
        XCTAssertTrue(SerializationFormat.json.hasDefaultImplementation)
        XCTAssertTrue(SerializationFormat.plist.hasDefaultImplementation)
        XCTAssertFalse(SerializationFormat.binary.hasDefaultImplementation)
        XCTAssertFalse(SerializationFormat.protobuf.hasDefaultImplementation)
        XCTAssertFalse(SerializationFormat.messagepack.hasDefaultImplementation)
    }

    func testIsImplemented() {
        XCTAssertTrue(SerializationFormat.json.isImplemented)
        XCTAssertTrue(SerializationFormat.plist.isImplemented)
        XCTAssertTrue(SerializationFormat.binary.isImplemented)
        XCTAssertFalse(SerializationFormat.protobuf.isImplemented)
        XCTAssertFalse(SerializationFormat.messagepack.isImplemented)
    }

    // MARK: - Format Selection Tests

    func testRecommendForTextualData() {
        let format = SerializationFormat.recommend(
            isTextual: true,
            needsInspection: false,
            estimatedSize: 10_000
        )
        XCTAssertEqual(format, .json)
    }

    func testRecommendForInspection() {
        let format = SerializationFormat.recommend(
            isTextual: false,
            needsInspection: true,
            estimatedSize: 100_000
        )
        XCTAssertEqual(format, .json)
    }

    func testRecommendForLargeData() {
        let format = SerializationFormat.recommend(
            isTextual: false,
            needsInspection: false,
            estimatedSize: 2_000_000 // 2MB
        )
        XCTAssertEqual(format, .binary)
    }

    func testRecommendForSmallBinaryData() {
        let format = SerializationFormat.recommend(
            isTextual: false,
            needsInspection: false,
            estimatedSize: 50_000 // 50KB
        )
        XCTAssertEqual(format, .json) // Default for small/medium data
    }

    func testRecommendForUnknownSize() {
        let format = SerializationFormat.recommend(
            isTextual: false,
            needsInspection: false,
            estimatedSize: nil
        )
        XCTAssertEqual(format, .json) // Default
    }

    // MARK: - Codable Tests

    func testCodableRoundTrip() throws {
        for format in SerializationFormat.allCases {
            let encoded = try JSONEncoder().encode(format)
            let decoded = try JSONDecoder().decode(SerializationFormat.self, from: encoded)
            XCTAssertEqual(decoded, format)
        }
    }

    func testDecodingFromRawValue() throws {
        let json = "\"json\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SerializationFormat.self, from: json)
        XCTAssertEqual(decoded, .json)
    }

    // MARK: - Sendable Conformance Tests

    func testSendableConformance() async {
        // Should be able to pass across actor boundaries
        let format = SerializationFormat.json

        await Task {
            XCTAssertEqual(format, .json)
        }.value
    }
}
