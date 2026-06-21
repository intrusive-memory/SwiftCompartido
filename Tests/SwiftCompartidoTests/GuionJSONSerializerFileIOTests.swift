//
//  GuionJSONSerializerFileIOTests.swift
//  SwiftCompartidoTests
//
//  File I/O integration tests for .guion file format
//  Tests actual disk operations (save/load/round-trip)
//

import Foundation
import XCTest

@testable import SwiftCompartido

/// File I/O integration tests for GuionJSONSerializer
///
/// These tests verify actual disk operations that were not covered by the
/// in-memory serialization tests. They address GAP 1 from FIX-guion-file-testing.md.
///
/// Coverage:
/// - Save snapshot to file
/// - Load .guion file from disk
/// - Round-trip save/load fidelity
/// - Atomic write behavior
/// - Special characters in filenames
/// - Error handling (permissions, disk full simulation)
final class GuionJSONSerializerFileIOTests: XCTestCase {

  // MARK: - Test Setup

  var tempDirectory: URL!

  override func setUp() async throws {
    try await super.setUp()

    // Create temp directory for test files
    tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("GuionFileIOTests-\(UUID().uuidString)")

    try FileManager.default.createDirectory(
      at: tempDirectory,
      withIntermediateDirectories: true
    )
  }

  override func tearDown() async throws {
    // Clean up temp directory
    if let tempDir = tempDirectory {
      try? FileManager.default.removeItem(at: tempDir)
    }

    try await super.tearDown()
  }

  // MARK: - Basic File I/O Tests

  func testSaveSnapshotToFile() throws {
    var snapshot = GuionDocumentSnapshot()
    snapshot.filename = "test.guion"
    snapshot.title = "Test Screenplay"
    snapshot.elements = [
      GuionElementSnapshot(
        elementText: "INT. COFFEE SHOP - DAY",
        elementType: .sceneHeading
      )
    ]

    let fileURL = tempDirectory.appendingPathComponent("test.guion")

    // Encode and write to file
    let data = try GuionJSONSerializer.encode(snapshot)
    try data.write(to: fileURL, options: .atomic)

    // Verify file exists
    XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

    // Verify file size is reasonable (> 100 bytes for this simple document)
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let fileSize = attributes[.size] as? Int ?? 0
    XCTAssertGreaterThan(fileSize, 100, "File should contain JSON data")
  }

  func testLoadGuionFileFromDisk() throws {
    // Create a .guion file
    var original = GuionDocumentSnapshot()
    original.filename = "load-test.guion"
    original.title = "Load Test"
    original.elements = [
      GuionElementSnapshot(
        elementText: "FADE IN:",
        elementType: .transition
      )
    ]

    let fileURL = tempDirectory.appendingPathComponent("load-test.guion")
    let data = try GuionJSONSerializer.encode(original)
    try data.write(to: fileURL, options: .atomic)

    // Load from disk
    let loadedData = try Data(contentsOf: fileURL)
    let loaded = try GuionJSONSerializer.decode(loadedData)

    // Verify content
    XCTAssertEqual(loaded.id, original.id)
    XCTAssertEqual(loaded.filename, "load-test.guion")
    XCTAssertEqual(loaded.title, "Load Test")
    XCTAssertEqual(loaded.elements.count, 1)
    XCTAssertEqual(loaded.elements.first?.elementText, "FADE IN:")
  }

  func testRoundTripSaveLoadIdentical() throws {
    // Create complex snapshot
    let original = createComplexSnapshot()

    let fileURL = tempDirectory.appendingPathComponent("roundtrip.guion")

    // Save to disk
    let saveData = try GuionJSONSerializer.encode(original)
    try saveData.write(to: fileURL, options: .atomic)

    // Load from disk
    let loadData = try Data(contentsOf: fileURL)
    let loaded = try GuionJSONSerializer.decode(loadData)

    // Verify complete round-trip fidelity
    XCTAssertEqual(loaded.id, original.id)
    XCTAssertEqual(loaded.filename, original.filename)
    XCTAssertEqual(loaded.title, original.title)
    XCTAssertEqual(loaded.suppressSceneNumbers, original.suppressSceneNumbers)
    XCTAssertEqual(loaded.elements.count, original.elements.count)
    XCTAssertEqual(loaded.titlePage.count, original.titlePage.count)
    XCTAssertEqual(loaded.casting?.count, original.casting?.count)

    // Verify first element
    XCTAssertEqual(loaded.elements.first?.elementText, "INT. COFFEE SHOP - DAY")
    XCTAssertEqual(loaded.elements.first?.elementType, .sceneHeading)
  }

  // MARK: - Atomic Write Tests

  func testAtomicWriteCreatesNoPartialFiles() throws {
    var snapshot = GuionDocumentSnapshot()
    snapshot.filename = "atomic.guion"
    snapshot.title = "Atomic Write Test"

    let fileURL = tempDirectory.appendingPathComponent("atomic.guion")

    // Write atomically
    let data = try GuionJSONSerializer.encode(snapshot)
    try data.write(to: fileURL, options: .atomic)

    // Verify no temp files left behind (.guion~, .tmp, etc.)
    let contents = try FileManager.default.contentsOfDirectory(
      at: tempDirectory,
      includingPropertiesForKeys: nil
    )

    let tempFiles = contents.filter { url in
      url.lastPathComponent.contains("~")
        || url.lastPathComponent.contains(".tmp")
        || url.lastPathComponent.hasPrefix(".")
    }

    XCTAssertTrue(
      tempFiles.isEmpty,
      "Atomic write should clean up temp files, found: \(tempFiles)")
  }

  func testAtomicWriteOverwritesExisting() throws {
    let fileURL = tempDirectory.appendingPathComponent("overwrite.guion")

    // Write original version
    var v1 = GuionDocumentSnapshot()
    v1.filename = "overwrite.guion"
    v1.title = "Version 1"

    let data1 = try GuionJSONSerializer.encode(v1)
    try data1.write(to: fileURL, options: .atomic)

    // Verify v1 written
    let check1 = try Data(contentsOf: fileURL)
    let loaded1 = try GuionJSONSerializer.decode(check1)
    XCTAssertEqual(loaded1.title, "Version 1")

    // Overwrite with v2
    var v2 = GuionDocumentSnapshot()
    v2.filename = "overwrite.guion"
    v2.title = "Version 2"

    let data2 = try GuionJSONSerializer.encode(v2)
    try data2.write(to: fileURL, options: .atomic)

    // Verify v2 overwrote v1
    let check2 = try Data(contentsOf: fileURL)
    let loaded2 = try GuionJSONSerializer.decode(check2)
    XCTAssertEqual(loaded2.title, "Version 2")
  }

  // MARK: - Special Characters in Filenames

  func testSaveWithUTF8Filename() throws {
    var snapshot = GuionDocumentSnapshot()
    snapshot.filename = "screenplay-émojis-日本語.guion"
    snapshot.title = "UTF-8 Test"

    let fileURL = tempDirectory.appendingPathComponent("screenplay-émojis-日本語.guion")

    let data = try GuionJSONSerializer.encode(snapshot)
    try data.write(to: fileURL, options: .atomic)

    // Verify file exists with correct name
    XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

    // Load and verify
    let loadedData = try Data(contentsOf: fileURL)
    let loaded = try GuionJSONSerializer.decode(loadedData)
    XCTAssertEqual(loaded.filename, "screenplay-émojis-日本語.guion")
  }

  func testSaveWithSpacesInFilename() throws {
    var snapshot = GuionDocumentSnapshot()
    snapshot.filename = "My Great Screenplay v2.guion"

    let fileURL = tempDirectory.appendingPathComponent("My Great Screenplay v2.guion")

    let data = try GuionJSONSerializer.encode(snapshot)
    try data.write(to: fileURL, options: .atomic)

    XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

    let loaded = try GuionJSONSerializer.decode(Data(contentsOf: fileURL))
    XCTAssertEqual(loaded.filename, "My Great Screenplay v2.guion")
  }

  func testSaveWithSpecialCharacters() throws {
    // Test various special chars allowed in filenames
    let specialNames = [
      "screenplay & more.guion",
      "screenplay (draft).guion",
      "screenplay [v2].guion",
      "screenplay-2024.guion",
      "screenplay_final.guion",
    ]

    for name in specialNames {
      var snapshot = GuionDocumentSnapshot()
      snapshot.filename = name

      let fileURL = tempDirectory.appendingPathComponent(name)
      let data = try GuionJSONSerializer.encode(snapshot)

      XCTAssertNoThrow(
        try data.write(to: fileURL, options: .atomic),
        "Should save file with name: \(name)")
    }
  }

  // MARK: - File Size Verification

  func testFileSizeMatchesExpectation() throws {
    // Create a document with 100 elements (~330 bytes each = ~33KB)
    var snapshot = GuionDocumentSnapshot()
    snapshot.filename = "size-test.guion"
    snapshot.title = "Size Test"

    snapshot.elements = (0..<100).map { index in
      GuionElementSnapshot(
        chapterIndex: index / 10,
        orderIndex: index,
        elementText: "This is element \(index) with some text content.",
        elementType: .action
      )
    }

    let fileURL = tempDirectory.appendingPathComponent("size-test.guion")
    let data = try GuionJSONSerializer.encode(snapshot)
    try data.write(to: fileURL, options: .atomic)

    // Verify file size is in expected range (20-50KB for 100 elements)
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let fileSize = attributes[.size] as? Int ?? 0

    XCTAssertGreaterThan(fileSize, 20_000, "File should be >20KB for 100 elements")
    XCTAssertLessThan(fileSize, 50_000, "File should be <50KB for 100 elements")
  }

  func testEmptyDocumentFileSize() throws {
    let snapshot = GuionDocumentSnapshot()
    let fileURL = tempDirectory.appendingPathComponent("empty.guion")

    let data = try GuionJSONSerializer.encode(snapshot)
    try data.write(to: fileURL, options: .atomic)

    // Empty document should be small (< 1KB)
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let fileSize = attributes[.size] as? Int ?? 0

    XCTAssertLessThan(fileSize, 1_000, "Empty document should be <1KB")
  }

  // MARK: - Error Handling Tests

  func testLoadNonExistentFile() {
    let nonExistentURL = tempDirectory.appendingPathComponent("does-not-exist.guion")

    XCTAssertThrowsError(try Data(contentsOf: nonExistentURL)) { error in
      // Should be a Cocoa error (file not found)
      XCTAssertTrue(error is CocoaError)
    }
  }

  func testSaveToReadOnlyDirectory() throws {
    // Create a subdirectory and make it read-only
    let readOnlyDir = tempDirectory.appendingPathComponent("readonly")
    try FileManager.default.createDirectory(at: readOnlyDir, withIntermediateDirectories: true)

    // Make directory read-only
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o444],  // r--r--r--
      ofItemAtPath: readOnlyDir.path
    )

    // Attempt to write file
    let snapshot = GuionDocumentSnapshot()
    let fileURL = readOnlyDir.appendingPathComponent("test.guion")
    let data = try GuionJSONSerializer.encode(snapshot)

    XCTAssertThrowsError(try data.write(to: fileURL, options: .atomic)) { error in
      // Should fail with permission error
      XCTAssertTrue(error is CocoaError)
    }

    // Cleanup: restore permissions so tearDown can delete
    try? FileManager.default.setAttributes(
      [.posixPermissions: 0o755],  // rwxr-xr-x
      ofItemAtPath: readOnlyDir.path
    )
  }

  func testLoadCorruptedFile() throws {
    let corruptedURL = tempDirectory.appendingPathComponent("corrupted.guion")

    // Write invalid JSON
    let corruptedData = "{ not valid json".data(using: .utf8)!
    try corruptedData.write(to: corruptedURL, options: .atomic)

    // Verify file exists
    XCTAssertTrue(FileManager.default.fileExists(atPath: corruptedURL.path))

    // Attempt to decode
    let fileData = try Data(contentsOf: corruptedURL)
    XCTAssertThrowsError(try GuionJSONSerializer.decode(fileData)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  // MARK: - Symlink Handling

  func testLoadThroughSymlink() throws {
    // Create original file
    var snapshot = GuionDocumentSnapshot()
    snapshot.filename = "original.guion"
    snapshot.title = "Original"

    let originalURL = tempDirectory.appendingPathComponent("original.guion")
    let data = try GuionJSONSerializer.encode(snapshot)
    try data.write(to: originalURL, options: .atomic)

    // Create symlink
    let symlinkURL = tempDirectory.appendingPathComponent("link.guion")
    try FileManager.default.createSymbolicLink(
      at: symlinkURL,
      withDestinationURL: originalURL
    )

    // Load through symlink
    let loadedData = try Data(contentsOf: symlinkURL)
    let loaded = try GuionJSONSerializer.decode(loadedData)

    XCTAssertEqual(loaded.title, "Original")
  }

  func testSaveThroughSymlink() throws {
    // Create original file
    let originalURL = tempDirectory.appendingPathComponent("original.guion")
    var v1 = GuionDocumentSnapshot()
    v1.title = "V1"
    try GuionJSONSerializer.encode(v1).write(to: originalURL, options: .atomic)

    // Create symlink
    let symlinkURL = tempDirectory.appendingPathComponent("link.guion")
    try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: originalURL)

    // Save through symlink with non-atomic write
    // NOTE: Atomic writes break symlinks (expected macOS behavior)
    var v2 = GuionDocumentSnapshot()
    v2.title = "V2"
    let data = try GuionJSONSerializer.encode(v2)
    try data.write(to: symlinkURL, options: [])  // Non-atomic to follow symlink

    // Verify original file was updated (symlink was followed)
    let originalData = try Data(contentsOf: originalURL)
    let originalLoaded = try GuionJSONSerializer.decode(originalData)
    XCTAssertEqual(originalLoaded.title, "V2")
  }

  // MARK: - Long Path Tests

  func testSaveWithLongPath() throws {
    // Create nested directory structure (but stay under system limits)
    let longPath = "a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p"
    let longDir = tempDirectory.appendingPathComponent(longPath)
    try FileManager.default.createDirectory(at: longDir, withIntermediateDirectories: true)

    var snapshot = GuionDocumentSnapshot()
    snapshot.filename = "long-path-test.guion"

    let fileURL = longDir.appendingPathComponent("long-path-test.guion")
    let data = try GuionJSONSerializer.encode(snapshot)

    // Should succeed (path is long but valid)
    XCTAssertNoThrow(try data.write(to: fileURL, options: .atomic))

    // Verify can load
    let loaded = try GuionJSONSerializer.decode(Data(contentsOf: fileURL))
    XCTAssertEqual(loaded.filename, "long-path-test.guion")
  }

  // MARK: - Multiple Files in Same Directory

  func testSaveMultipleFilesInSameDirectory() throws {
    let fileCount = 10

    for i in 0..<fileCount {
      var snapshot = GuionDocumentSnapshot()
      snapshot.filename = "screenplay-\(i).guion"
      snapshot.title = "Screenplay \(i)"

      let fileURL = tempDirectory.appendingPathComponent("screenplay-\(i).guion")
      let data = try GuionJSONSerializer.encode(snapshot)
      try data.write(to: fileURL, options: .atomic)
    }

    // Verify all files exist
    let contents = try FileManager.default.contentsOfDirectory(
      at: tempDirectory,
      includingPropertiesForKeys: nil
    )

    let guionFiles = contents.filter { $0.pathExtension == "guion" }
    XCTAssertEqual(guionFiles.count, fileCount)
  }

  // MARK: - Helper Methods

  private func createComplexSnapshot() -> GuionDocumentSnapshot {
    var snapshot = GuionDocumentSnapshot()
    snapshot.filename = "complex.guion"
    snapshot.title = "Complex Screenplay"
    snapshot.suppressSceneNumbers = true

    snapshot.elements = [
      GuionElementSnapshot(
        chapterIndex: 0,
        orderIndex: 1,
        elementText: "INT. COFFEE SHOP - DAY",
        elementType: .sceneHeading,
        sceneNumber: "1"
      ),
      GuionElementSnapshot(
        chapterIndex: 0,
        orderIndex: 2,
        elementText: "JANE",
        elementType: .character
      ),
      GuionElementSnapshot(
        chapterIndex: 0,
        orderIndex: 3,
        elementText: "Hello, world!",
        elementType: .dialogue
      ),
    ]

    snapshot.titlePage = [
      TitlePageEntrySnapshot(key: "TITLE", values: ["Complex Screenplay"]),
      TitlePageEntrySnapshot(key: "AUTHOR", values: ["Test Author"]),
    ]

    snapshot.casting = [
      "JANE": CharacterVoiceMappingSnapshot(
        voiceURI: "macos://Samantha?lang=en",
        voiceName: "Samantha",
        providerID: "macos"
      )
    ]

    return snapshot
  }
}
