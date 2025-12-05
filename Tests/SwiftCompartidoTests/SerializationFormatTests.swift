//
//  SerializationFormatTests.swift
//  SwiftHablareTests
//
//  Phase 6A: Tests for SerializationFormat enum
//

import Testing
@testable import SwiftCompartido

struct SerializationFormatTests {

    // MARK: - Basic Properties Tests

    @Test func testAllCasesArePresent() {
        let formats = SerializationFormat.allCases
        #expect(formats.count == 5, "Should have 5 serialization formats")
        #expect(formats.contains(.json))
        #expect(formats.contains(.plist))
        #expect(formats.contains(.binary))
        #expect(formats.contains(.protobuf))
        #expect(formats.contains(.messagepack))
    }

    @Test func testRawValuesAreCorrect() {
        #expect(SerializationFormat.json.rawValue == "json")
        #expect(SerializationFormat.plist.rawValue == "plist")
        #expect(SerializationFormat.binary.rawValue == "binary")
        #expect(SerializationFormat.protobuf.rawValue == "protobuf")
        #expect(SerializationFormat.messagepack.rawValue == "messagepack")
    }

    @Test func testIdentifiableConformance() {
        let format = SerializationFormat.json
        #expect(format.id == format.rawValue)
    }

    // MARK: - Display Properties Tests

    @Test func testDisplayNames() {
        #expect(SerializationFormat.json.displayName == "JSON")
        #expect(SerializationFormat.plist.displayName == "Property List")
        #expect(SerializationFormat.binary.displayName == "Binary")
        #expect(SerializationFormat.protobuf.displayName == "Protocol Buffers")
        #expect(SerializationFormat.messagepack.displayName == "MessagePack")
    }

    @Test func testDescriptions() {
        #expect(!SerializationFormat.json.description.isEmpty)
        #expect(!SerializationFormat.plist.description.isEmpty)
        #expect(!SerializationFormat.binary.description.isEmpty)
        #expect(!SerializationFormat.protobuf.description.isEmpty)
        #expect(!SerializationFormat.messagepack.description.isEmpty)
    }

    // MARK: - File Properties Tests

    @Test func testFileExtensions() {
        #expect(SerializationFormat.json.fileExtension == "json")
        #expect(SerializationFormat.plist.fileExtension == "plist")
        #expect(SerializationFormat.binary.fileExtension == "bin")
        #expect(SerializationFormat.protobuf.fileExtension == "pb")
        #expect(SerializationFormat.messagepack.fileExtension == "msgpack")
    }

    @Test func testMimeTypes() {
        #expect(SerializationFormat.json.mimeType == "application/json")
        #expect(SerializationFormat.plist.mimeType == "application/x-plist")
        #expect(SerializationFormat.binary.mimeType == "application/octet-stream")
        #expect(SerializationFormat.protobuf.mimeType == "application/x-protobuf")
        #expect(SerializationFormat.messagepack.mimeType == "application/x-msgpack")
    }

    // MARK: - Format Characteristics Tests

    @Test func testIsHumanReadable() {
        #expect(SerializationFormat.json.isHumanReadable)
        #expect(SerializationFormat.plist.isHumanReadable)
        #expect(!SerializationFormat.binary.isHumanReadable)
        #expect(!SerializationFormat.protobuf.isHumanReadable)
        #expect(!SerializationFormat.messagepack.isHumanReadable)
    }

    @Test func testHasDefaultImplementation() {
        #expect(SerializationFormat.json.hasDefaultImplementation)
        #expect(SerializationFormat.plist.hasDefaultImplementation)
        #expect(!SerializationFormat.binary.hasDefaultImplementation)
        #expect(!SerializationFormat.protobuf.hasDefaultImplementation)
        #expect(!SerializationFormat.messagepack.hasDefaultImplementation)
    }

    @Test func testIsImplemented() {
        #expect(SerializationFormat.json.isImplemented)
        #expect(SerializationFormat.plist.isImplemented)
        #expect(SerializationFormat.binary.isImplemented)
        #expect(!SerializationFormat.protobuf.isImplemented)
        #expect(!SerializationFormat.messagepack.isImplemented)
    }

    // MARK: - Format Selection Tests

    @Test func testRecommendForTextualData() {
        let format = SerializationFormat.recommend(
            isTextual: true,
            needsInspection: false,
            estimatedSize: 10_000
        )
        #expect(format == .json)
    }

    @Test func testRecommendForInspection() {
        let format = SerializationFormat.recommend(
            isTextual: false,
            needsInspection: true,
            estimatedSize: 100_000
        )
        #expect(format == .json)
    }

    @Test func testRecommendForLargeData() {
        let format = SerializationFormat.recommend(
            isTextual: false,
            needsInspection: false,
            estimatedSize: 2_000_000 // 2MB
        )
        #expect(format == .binary)
    }

    @Test func testRecommendForSmallBinaryData() {
        let format = SerializationFormat.recommend(
            isTextual: false,
            needsInspection: false,
            estimatedSize: 50_000 // 50KB
        )
        #expect(format == .json) // Default for small/medium data
    }

    @Test func testRecommendForUnknownSize() {
        let format = SerializationFormat.recommend(
            isTextual: false,
            needsInspection: false,
            estimatedSize: nil
        )
        #expect(format == .json) // Default
    }

    // MARK: - Codable Tests

    @Test func testCodableRoundTrip() throws {
        for format in SerializationFormat.allCases {
            let encoded = try JSONEncoder().encode(format)
            let decoded = try JSONDecoder().decode(SerializationFormat.self, from: encoded)
            #expect(decoded == format)
        }
    }

    @Test func testDecodingFromRawValue() throws {
        let json = "\"json\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SerializationFormat.self, from: json)
        #expect(decoded == .json)
    }

    // MARK: - Sendable Conformance Tests

    @Test func testSendableConformance() async {
        // Should be able to pass across actor boundaries
        let format = SerializationFormat.json

        await Task {
            #expect(format == .json)
        }.value
    }
}
