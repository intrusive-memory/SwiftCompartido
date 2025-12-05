//
//  FileReferenceTests.swift
//  SwiftHablareTests
//
//  Phase 6A: Tests for StorageAreaReference and TypedDataFileReference
//

import Testing
@testable import SwiftCompartido

struct StorageAreaReferenceTests {

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

    @Test func testInitialization() {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")

        let storage = StorageAreaReference(
            requestID: requestID,
            baseURL: baseURL,
            bundleIdentifier: "test-bundle"
        )

        #expect(storage.requestID == requestID)
        #expect(storage.baseURL == baseURL)
        #expect(storage.bundleIdentifier == "test-bundle")
    }

    // MARK: - File URL Construction Tests

    @Test func testFileURL() {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")
        let storage = StorageAreaReference(requestID: requestID, baseURL: baseURL)

        let fileURL = storage.fileURL(for: "data.json")
        #expect(fileURL.lastPathComponent == "data.json")
        #expect(fileURL.absoluteString.contains(baseURL.path))
    }

    @Test func testFileURL_WithExtension() {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")
        let storage = StorageAreaReference(requestID: requestID, baseURL: baseURL)

        let fileURL = storage.fileURL(baseName: "audio", fileExtension: "mp3")
        #expect(fileURL.lastPathComponent == "audio.mp3")
    }

    @Test func testDefaultDataFileURL() {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")
        let storage = StorageAreaReference(requestID: requestID, baseURL: baseURL)

        let fileURL = storage.defaultDataFileURL(extension: "json")
        #expect(fileURL.lastPathComponent == "data.json")
    }

    // MARK: - Directory Operations Tests

    @Test func testCreateDirectoryIfNeeded() throws {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")
        let storage = StorageAreaReference(requestID: requestID, baseURL: baseURL)

        #expect(!storage.directoryExists())

        try storage.createDirectoryIfNeeded()
        #expect(storage.directoryExists())
    }

    @Test func testCreateDirectoryIfNeeded_Idempotent() throws {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")
        let storage = StorageAreaReference(requestID: requestID, baseURL: baseURL)

        try storage.createDirectoryIfNeeded()
        try storage.createDirectoryIfNeeded() // Should not throw

        #expect(storage.directoryExists())
    }

    @Test func testListFiles() throws {
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
        #expect(filePaths.count == 2)
        #expect(filePaths.contains("file1.txt"))
        #expect(filePaths.contains("file2.txt"))
    }

    // MARK: - Convenience Constructors Tests

    @Test func testTemporaryStorageArea() {
        let storage = StorageAreaReference.temporary()

        #expect(storage.requestID != nil)
        #expect(storage.baseURL.path.contains("SwiftHablare"))
        #expect(storage.bundleIdentifier == nil)
    }

    @Test func testTemporaryStorageArea_WithRequestID() {
        let requestID = UUID()
        let storage = StorageAreaReference.temporary(requestID: requestID)

        #expect(storage.requestID == requestID)
    }

    @Test func testInBundleStorageArea() {
        let requestID = UUID()
        let bundleURL = tempDirectory.appendingPathComponent("test.guion")
        let storage = StorageAreaReference.inBundle(
            requestID: requestID,
            bundleURL: bundleURL,
            bundleIdentifier: "test-bundle"
        )

        #expect(storage.requestID == requestID)
        #expect(storage.baseURL.path.contains("assets"))
        #expect(storage.baseURL.path.contains(requestID.uuidString))
        #expect(storage.bundleIdentifier == "test-bundle")
    }

    // MARK: - Codable Tests

    @Test func testCodableRoundTrip() throws {
        let original = StorageAreaReference(
            requestID: UUID(),
            baseURL: tempDirectory.appendingPathComponent("test"),
            bundleIdentifier: "test-bundle"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StorageAreaReference.self, from: encoded)

        #expect(decoded.requestID == original.requestID)
        #expect(decoded.baseURL.path == original.baseURL.path)
        #expect(decoded.bundleIdentifier == original.bundleIdentifier)
    }

    // MARK: - Equatable Tests

    @Test func testEquality() {
        let requestID = UUID()
        let baseURL = tempDirectory.appendingPathComponent("test")

        let storage1 = StorageAreaReference(requestID: requestID, baseURL: baseURL)
        let storage2 = StorageAreaReference(requestID: requestID, baseURL: baseURL)

        #expect(storage1 == storage2)
    }

    @Test func testInequality_DifferentRequestID() {
        let baseURL = tempDirectory.appendingPathComponent("test")

        let storage1 = StorageAreaReference(requestID: UUID(), baseURL: baseURL)
        let storage2 = StorageAreaReference(requestID: UUID(), baseURL: baseURL)

        #expect(storage1 != storage2)
    }

    // MARK: - Sendable Conformance Tests

    @Test func testSendableConformance() async {
        let storage = StorageAreaReference.temporary()

        await Task {
            #expect(storage.requestID != nil)
        }.value
    }

    // MARK: - CustomStringConvertible Tests

    @Test func testDescription() {
        let storage = StorageAreaReference(
            requestID: UUID(),
            baseURL: tempDirectory,
            bundleIdentifier: "test-bundle"
        )

        let description = storage.description
        #expect(description.contains("StorageAreaReference"))
        #expect(description.contains("test-bundle"))
    }
}

struct TypedDataFileReferenceTests {

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

    @Test func testInitialization() {
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

        #expect(fileRef.requestID == requestID)
        #expect(fileRef.fileName == "data.json")
        #expect(fileRef.fileSize == 1024)
        #expect(fileRef.mimeType == "application/json")
        #expect(fileRef.createdAt == createdAt)
        #expect(fileRef.checksum == "abc123")
    }

    @Test func testFileExtension() {
        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "audio.mp3",
            fileSize: 1024,
            mimeType: "audio/mpeg"
        )

        #expect(fileRef.fileExtension == "mp3")
    }

    // MARK: - File Path Construction Tests

    @Test func testRelativePath() {
        let requestID = UUID()
        let fileRef = TypedDataFileReference(
            requestID: requestID,
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json"
        )

        let relativePath = fileRef.relativePath
        #expect(relativePath.contains("assets"))
        #expect(relativePath.contains(requestID.uuidString))
        #expect(relativePath.contains("data.json"))
    }

    @Test func testFileURL_InStorageArea() {
        let fileRef = TypedDataFileReference(
            requestID: storageArea.requestID,
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json"
        )

        let fileURL = fileRef.fileURL(in: storageArea)
        #expect(fileURL.lastPathComponent == "data.json")
    }

    @Test func testFileURL_InBundle() {
        let requestID = UUID()
        let bundleURL = tempDirectory.appendingPathComponent("test.guion")

        let fileRef = TypedDataFileReference(
            requestID: requestID,
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json"
        )

        let fileURL = fileRef.fileURL(in: bundleURL)
        #expect(fileURL.path.contains("assets"))
        #expect(fileURL.path.contains(requestID.uuidString))
        #expect(fileURL.lastPathComponent == "data.json")
    }

    // MARK: - File Operations Tests

    @Test func testReadData() throws {
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
        #expect(readData == testData)
    }

    @Test func testFileExists() throws {
        try storageArea.createDirectoryIfNeeded()

        let fileRef = TypedDataFileReference(
            requestID: storageArea.requestID,
            fileName: "data.txt",
            fileSize: 1024,
            mimeType: "text/plain"
        )

        #expect(!fileRef.fileExists(in: storageArea))

        let fileURL = storageArea.fileURL(for: "data.txt")
        try "Test".write(to: fileURL, atomically: true, encoding: .utf8)

        #expect(fileRef.fileExists(in: storageArea))
    }

    @Test func testVerifySizeMatches() throws {
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

        #expect(try fileRef.verifySizeMatches(in: storageArea))
    }

    @Test func testVerifySizeMatches_Mismatch() throws {
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

        #expect(try !fileRef.verifySizeMatches(in: storageArea))
    }

    // MARK: - Convenience Constructors Tests

    @Test func testFromData() {
        let requestID = UUID()
        let testData = "Test content".data(using: .utf8)!

        let fileRef = TypedDataFileReference.from(
            requestID: requestID,
            fileName: "data.txt",
            data: testData,
            mimeType: "text/plain",
            includeChecksum: false
        )

        #expect(fileRef.requestID == requestID)
        #expect(fileRef.fileName == "data.txt")
        #expect(fileRef.fileSize == Int64(testData.count))
        #expect(fileRef.mimeType == "text/plain")
        #expect(fileRef.checksum == nil)
    }

    @Test func testFromData_WithChecksum() {
        let requestID = UUID()
        let testData = "Test content".data(using: .utf8)!

        let fileRef = TypedDataFileReference.from(
            requestID: requestID,
            fileName: "data.txt",
            data: testData,
            mimeType: "text/plain",
            includeChecksum: true
        )

        #expect(fileRef.checksum != nil)
    }

    @Test func testFromFileURL() throws {
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

        #expect(fileRef.fileName == "data.txt")
        #expect(fileRef.fileSize == Int64(testData.count))
    }

    // MARK: - Codable Tests

    @Test func testCodableRoundTrip() throws {
        let original = TypedDataFileReference(
            requestID: UUID(),
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json",
            checksum: "abc123"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TypedDataFileReference.self, from: encoded)

        #expect(decoded.requestID == original.requestID)
        #expect(decoded.fileName == original.fileName)
        #expect(decoded.fileSize == original.fileSize)
        #expect(decoded.mimeType == original.mimeType)
        #expect(decoded.checksum == original.checksum)
    }

    // MARK: - Equatable Tests

    @Test func testEquality() {
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

        #expect(fileRef1 == fileRef2)
    }

    // MARK: - Sendable Conformance Tests

    @Test func testSendableConformance() async {
        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json"
        )

        await Task {
            #expect(fileRef.fileName == "data.json")
        }.value
    }

    // MARK: - CustomStringConvertible Tests

    @Test func testDescription() {
        let requestID = UUID()
        let fileRef = TypedDataFileReference(
            requestID: requestID,
            fileName: "data.json",
            fileSize: 1024,
            mimeType: "application/json"
        )

        let description = fileRef.description
        #expect(description.contains("TypedDataFileReference"))
        #expect(description.contains("data.json"))
        #expect(description.contains("1024"))
    }
}
