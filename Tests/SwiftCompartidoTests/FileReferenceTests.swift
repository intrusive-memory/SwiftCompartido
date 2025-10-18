//
//  FileReferenceTests.swift
//  SwiftHablareTests
//
//  Phase 6A: Tests for StorageAreaReference and TypedDataFileReference
//

import XCTest
@testable import SwiftCompartido

@available(macOS 15.0, iOS 17.0, *)
final class StorageAreaReferenceTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")

        let storage = StorageAreaReference(
            requestID: requestID,
            baseURL: baseURL,
            bundleIdentifier: "test-bundle"
        )

        XCTAssertEqual(storage.requestID, requestID)
        XCTAssertEqual(storage.baseURL, baseURL)
        XCTAssertEqual(storage.bundleIdentifier, "test-bundle")
    }

    // MARK: - File URL Construction Tests

    func testFileURL() {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")
        let storage = StorageAreaReference(requestID: requestID, baseURL: baseURL)

        let fileURL = storage.fileURL(for: "data.json")
        XCTAssertEqual(fileURL.lastPathComponent, "data.json")
        XCTAssertTrue(fileURL.absoluteString.contains(baseURL.path))
    }

    func testFileURL_WithExtension() {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")
        let storage = StorageAreaReference(requestID: requestID, baseURL: baseURL)

        let fileURL = storage.fileURL(baseName: "audio", fileExtension: "mp3")
        XCTAssertEqual(fileURL.lastPathComponent, "audio.mp3")
    }

    func testDefaultDataFileURL() {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")
        let storage = StorageAreaReference(requestID: requestID, baseURL: baseURL)

        let fileURL = storage.defaultDataFileURL(extension: "json")
        XCTAssertEqual(fileURL.lastPathComponent, "data.json")
    }

    // MARK: - Directory Operations Tests

    func testCreateDirectoryIfNeeded() throws {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")
        let storage = StorageAreaReference(requestID: requestID, baseURL: baseURL)

        XCTAssertFalse(storage.directoryExists())

        try storage.createDirectoryIfNeeded()
        XCTAssertTrue(storage.directoryExists())
    }

    func testCreateDirectoryIfNeeded_Idempotent() throws {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")
        let storage = StorageAreaReference(requestID: requestID, baseURL: baseURL)

        try storage.createDirectoryIfNeeded()
        try storage.createDirectoryIfNeeded() // Should not throw

        XCTAssertTrue(storage.directoryExists())
    }

    func testListFiles() throws {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")
        let storage = StorageAreaReference(requestID: requestID, baseURL: baseURL)

        try storage.createDirectoryIfNeeded()

        // Write some test files
        let file1 = storage.fileURL(for: "file1.txt")
        let file2 = storage.fileURL(for: "file2.txt")
        try "Content 1".write(to: file1, atomically: true, encoding: .utf8)
        try "Content 2".write(to: file2, atomically: true, encoding: .utf8)

        let files = try storage.listFiles()
        let filePaths = files.map { $0.lastPathComponent }.sorted()
        XCTAssertEqual(filePaths.count, 2)
        XCTAssertTrue(filePaths.contains("file1.txt"))
        XCTAssertTrue(filePaths.contains("file2.txt"))
    }

    // MARK: - Convenience Constructors Tests

    func testTemporaryStorageArea() {
        let storage = StorageAreaReference.temporary()

        XCTAssertNotNil(storage.requestID)
        XCTAssertTrue(storage.baseURL.path.contains("SwiftHablare"))
        XCTAssertNil(storage.bundleIdentifier)
    }

    func testTemporaryStorageArea_WithRequestID() {
        let requestID = UUID()
        let storage = StorageAreaReference.temporary(requestID: requestID)

        XCTAssertEqual(storage.requestID, requestID)
    }

    func testInBundleStorageArea() {
        let requestID = UUID()
        let bundleURL = tempDirectory.appendingPathComponent("test.guion")
        let storage = StorageAreaReference.inBundle(
            requestID: requestID,
            bundleURL: bundleURL,
            bundleIdentifier: "test-bundle"
        )

        XCTAssertEqual(storage.requestID, requestID)
        XCTAssertTrue(storage.baseURL.path.contains("assets"))
        XCTAssertTrue(storage.baseURL.path.contains(requestID.uuidString))
        XCTAssertEqual(storage.bundleIdentifier, "test-bundle")
    }

    // MARK: - Codable Tests

    func testCodableRoundTrip() throws {
        let original = StorageAreaReference(
            requestID: UUID(),
            baseURL: tempDirectory.appendingPathComponent("test"),
            bundleIdentifier: "test-bundle"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StorageAreaReference.self, from: encoded)

        XCTAssertEqual(decoded.requestID, original.requestID)
        XCTAssertEqual(decoded.baseURL.path, original.baseURL.path)
        XCTAssertEqual(decoded.bundleIdentifier, original.bundleIdentifier)
    }

    // MARK: - Equatable Tests

    func testEquality() {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")

        let storage1 = StorageAreaReference(requestID: requestID, baseURL: baseURL)
        let storage2 = StorageAreaReference(requestID: requestID, baseURL: baseURL)

        XCTAssertEqual(storage1, storage2)
    }

    func testInequality_DifferentRequestID() {
        let baseURL = tempDirectory.appendingPathComponent("test")

        let storage1 = StorageAreaReference(requestID: UUID(), baseURL: baseURL)
        let storage2 = StorageAreaReference(requestID: UUID(), baseURL: baseURL)

        XCTAssertNotEqual(storage1, storage2)
    }

    // MARK: - Sendable Conformance Tests

    func testSendableConformance() async {
        let storage = StorageAreaReference.temporary()

        await Task {
            XCTAssertNotNil(storage.requestID)
        }.value
    }

    // MARK: - CustomStringConvertible Tests

    func testDescription() {
        let storage = StorageAreaReference(
            requestID: UUID(),
            baseURL: tempDirectory,
            bundleIdentifier: "test-bundle"
        )

        let description = storage.description
        XCTAssertTrue(description.contains("StorageAreaReference"))
        XCTAssertTrue(description.contains("test-bundle"))
    }
}

@available(macOS 15.0, iOS 17.0, *)
final class TypedDataFileReferenceTests: XCTestCase {

    var tempDirectory: URL!
    var storageArea: StorageAreaReference!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        storageArea = StorageAreaReference(
            requestID: UUID(),
            baseURL: tempDirectory
        )
    }

    override func tearDown() {
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        let requestID = UUID()
        let createdAt = Date()

        let fileRef = TypedDataFileReference(
            requestID: requestID,
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json",
            createdAt: createdAt,
            checksum: "abc123"
        )

        XCTAssertEqual(fileRef.requestID, requestID)
        XCTAssertEqual(fileRef.fileName, "data.json")
        XCTAssertEqual(fileRef.fileSize, 1024)
        XCTAssertEqual(fileRef.mimeType, "application/json")
        XCTAssertEqual(fileRef.createdAt, createdAt)
        XCTAssertEqual(fileRef.checksum, "abc123")
    }

    func testFileExtension() {
        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "audio.mp3",
            fileSize: 1024,
            mimeType: "audio/mpeg"
        )

        XCTAssertEqual(fileRef.fileExtension, "mp3")
    }

    // MARK: - File Path Construction Tests

    func testRelativePath() {
        let requestID = UUID()
        let fileRef = TypedDataFileReference(
            requestID: requestID,
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json"
        )

        let relativePath = fileRef.relativePath
        XCTAssertTrue(relativePath.contains("assets"))
        XCTAssertTrue(relativePath.contains(requestID.uuidString))
        XCTAssertTrue(relativePath.contains("data.json"))
    }

    func testFileURL_InStorageArea() {
        let fileRef = TypedDataFileReference(
            requestID: storageArea.requestID,
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json"
        )

        let fileURL = fileRef.fileURL(in: storageArea)
        XCTAssertEqual(fileURL.lastPathComponent, "data.json")
    }

    func testFileURL_InBundle() {
        let requestID = UUID()
        let bundleURL = tempDirectory.appendingPathComponent("test.guion")

        let fileRef = TypedDataFileReference(
            requestID: requestID,
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json"
        )

        let fileURL = fileRef.fileURL(in: bundleURL)
        XCTAssertTrue(fileURL.path.contains("assets"))
        XCTAssertTrue(fileURL.path.contains(requestID.uuidString))
        XCTAssertEqual(fileURL.lastPathComponent, "data.json")
    }

    // MARK: - File Operations Tests

    func testReadData() throws {
        try storageArea.createDirectoryIfNeeded()

        let testData = "Test content".data(using: .utf8)!
        let fileURL = storageArea.fileURL(for: "data.txt")
        try testData.write(to: fileURL)

        let fileRef = TypedDataFileReference(
            requestID: storageArea.requestID,
            fileName: "data.txt",
            fileSize: Int64(testData.count),
            mimeType: "text/plain"
        )

        let readData = try fileRef.readData(from: storageArea)
        XCTAssertEqual(readData, testData)
    }

    func testFileExists() throws {
        try storageArea.createDirectoryIfNeeded()

        let fileRef = TypedDataFileReference(
            requestID: storageArea.requestID,
            fileName: "data.txt",
            fileSize: 1024,
            mimeType: "text/plain"
        )

        XCTAssertFalse(fileRef.fileExists(in: storageArea))

        let fileURL = storageArea.fileURL(for: "data.txt")
        try "Test".write(to: fileURL, atomically: true, encoding: .utf8)

        XCTAssertTrue(fileRef.fileExists(in: storageArea))
    }

    func testVerifySizeMatches() throws {
        try storageArea.createDirectoryIfNeeded()

        let testData = "Test content".data(using: .utf8)!
        let fileURL = storageArea.fileURL(for: "data.txt")
        try testData.write(to: fileURL)

        let fileRef = TypedDataFileReference(
            requestID: storageArea.requestID,
            fileName: "data.txt",
            fileSize: Int64(testData.count),
            mimeType: "text/plain"
        )

        XCTAssertTrue(try fileRef.verifySizeMatches(in: storageArea))
    }

    func testVerifySizeMatches_Mismatch() throws {
        try storageArea.createDirectoryIfNeeded()

        let testData = "Test content".data(using: .utf8)!
        let fileURL = storageArea.fileURL(for: "data.txt")
        try testData.write(to: fileURL)

        let fileRef = TypedDataFileReference(
            requestID: storageArea.requestID,
            fileName: "data.txt",
            fileSize: 9999, // Wrong size
            mimeType: "text/plain"
        )

        XCTAssertFalse(try fileRef.verifySizeMatches(in: storageArea))
    }

    // MARK: - Convenience Constructors Tests

    func testFromData() {
        let requestID = UUID()
        let testData = "Test content".data(using: .utf8)!

        let fileRef = TypedDataFileReference.from(
            requestID: requestID,
            fileName: "data.txt",
            data: testData,
            mimeType: "text/plain",
            includeChecksum: false
        )

        XCTAssertEqual(fileRef.requestID, requestID)
        XCTAssertEqual(fileRef.fileName, "data.txt")
        XCTAssertEqual(fileRef.fileSize, Int64(testData.count))
        XCTAssertEqual(fileRef.mimeType, "text/plain")
        XCTAssertNil(fileRef.checksum)
    }

    func testFromData_WithChecksum() {
        let requestID = UUID()
        let testData = "Test content".data(using: .utf8)!

        let fileRef = TypedDataFileReference.from(
            requestID: requestID,
            fileName: "data.txt",
            data: testData,
            mimeType: "text/plain",
            includeChecksum: true
        )

        XCTAssertNotNil(fileRef.checksum)
    }

    func testFromFileURL() throws {
        try storageArea.createDirectoryIfNeeded()

        let testData = "Test content".data(using: .utf8)!
        let fileURL = storageArea.fileURL(for: "data.txt")
        try testData.write(to: fileURL)

        let fileRef = try TypedDataFileReference.from(
            requestID: storageArea.requestID,
            fileURL: fileURL,
            mimeType: "text/plain",
            includeChecksum: false
        )

        XCTAssertEqual(fileRef.fileName, "data.txt")
        XCTAssertEqual(fileRef.fileSize, Int64(testData.count))
    }

    // MARK: - Codable Tests

    func testCodableRoundTrip() throws {
        let original = TypedDataFileReference(
            requestID: UUID(),
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json",
            checksum: "abc123"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TypedDataFileReference.self, from: encoded)

        XCTAssertEqual(decoded.requestID, original.requestID)
        XCTAssertEqual(decoded.fileName, original.fileName)
        XCTAssertEqual(decoded.fileSize, original.fileSize)
        XCTAssertEqual(decoded.mimeType, original.mimeType)
        XCTAssertEqual(decoded.checksum, original.checksum)
    }

    // MARK: - Equatable Tests

    func testEquality() {
        let requestID = UUID()
        let createdAt = Date()
        let fileRef1 = TypedDataFileReference(
            requestID: requestID,
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json",
            createdAt: createdAt,
            checksum: "abc123"
        )
        let fileRef2 = TypedDataFileReference(
            requestID: requestID,
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json",
            createdAt: createdAt,
            checksum: "abc123"
        )

        XCTAssertEqual(fileRef1, fileRef2)
    }

    // MARK: - Sendable Conformance Tests

    func testSendableConformance() async {
        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json"
        )

        await Task {
            XCTAssertEqual(fileRef.fileName, "data.json")
        }.value
    }

    // MARK: - CustomStringConvertible Tests

    func testDescription() {
        let requestID = UUID()
        let fileRef = TypedDataFileReference(
            requestID: requestID,
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json"
        )

        let description = fileRef.description
        XCTAssertTrue(description.contains("TypedDataFileReference"))
        XCTAssertTrue(description.contains("data.json"))
        XCTAssertTrue(description.contains("1024"))
    }
}
