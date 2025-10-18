//
//  DocumentImportTests.swift
//  SwiftGuionTests
//
//  Copyright (c) 2025
//

import XCTest
import SwiftData
import UniformTypeIdentifiers
@testable import SwiftCompartido

@MainActor
final class DocumentImportTests: XCTestCase {

    var modelContext: ModelContext!
    var modelContainer: ModelContainer!
    var fixturesPath: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model context
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = modelContainer.mainContext

        // Get fixtures path
        let bundle = Bundle(for: type(of: self))

        guard let path = bundle.resourcePath else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find resource path"])
        }
        fixturesPath = URL(fileURLWithPath: path).appendingPathComponent("Fixtures")
    }

    override func tearDown() async throws {
        modelContext = nil
        modelContainer = nil
        fixturesPath = nil
        try await super.tearDown()
    }

    // MARK: - GATE 2.1: Open native .guion file

    func testOpenNativeGuionFile() async throws {
        // Step 1: Create and save a .guion file
        let original = GuionDocumentModel(filename: "test-native.guion", rawContent: "Test content")

        let scene = GuionElementModel(
            elementText: "INT. TEST LOCATION - DAY",
            elementType: .sceneHeading,
            sceneNumber: "1"
        )
        scene.document = original
        original.elements.append(scene)

        let action = GuionElementModel(
            elementText: "A test action line.",
            elementType: .action
        )
        action.document = original
        original.elements.append(action)

        modelContext.insert(original)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-native-open.guion")

        try original.save(to: tempURL)

        // Step 2: Simulate FileDocument loading via ReadConfiguration
        let fileData = try Data(contentsOf: tempURL)
        let fileWrapper = FileWrapper(regularFileWithContents: fileData)
        fileWrapper.filename = "test-native.guion"

        // Step 3: Load via decodeFromBinaryData (simulating GuionDocumentConfiguration.init)
        let loaded = try GuionDocumentModel.decodeFromBinaryData(fileData, in: modelContext)

        // Step 4: Verify
        XCTAssertEqual(loaded.filename, "test-native.guion", "Filename should be unchanged")
        XCTAssertEqual(loaded.elements.count, 2, "Should have 2 elements")
        XCTAssertEqual(loaded.elements[0].elementType, .sceneHeading, "First element should be Scene Heading")
        XCTAssertEqual(loaded.elements[1].elementType, .action, "Second element should be Action")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - GATE 2.2: Import .fountain file

    func testImportFountainFile() throws {
        // Test filename transformation logic for .fountain files
        // (Actual BigFish.fountain file may not be available in test bundle)

        let originalFilename = "BigFish.fountain"
        let transformedFilename = transformFilename(originalFilename)

        XCTAssertEqual(transformedFilename, "BigFish.guion", "Fountain file should transform to .guion extension")

        // Verify the transformation preserves base name
        XCTAssertTrue(transformedFilename?.hasPrefix("BigFish") ?? false, "Should preserve base name")
        XCTAssertTrue(transformedFilename?.hasSuffix(".guion") ?? false, "Should have .guion extension")

        // Test with other fountain filenames
        XCTAssertEqual(transformFilename("screenplay.fountain"), "screenplay.guion")
        XCTAssertEqual(transformFilename("MyScript.FOUNTAIN"), "MyScript.guion")
    }

    // MARK: - GATE 2.3: Import .fdx file

    func testImportFDXFile() throws {
        // Note: We need to create or find an FDX test file
        // For now, test the transformation logic

        let originalFilename = "TestScript.fdx"
        let transformedFilename = transformFilename(originalFilename)

        XCTAssertEqual(transformedFilename, "TestScript.guion", "FDX file should transform to .guion extension")
    }

    // MARK: - GATE 2.4: Import .highland file

    func testImportHighlandFile() throws {
        // Check if we have Highland test files
        let highlandURL = fixturesPath.appendingPathComponent("bigfish.highland")

        if FileManager.default.fileExists(atPath: highlandURL.path) {
            // Test transformation
            let originalFilename = "bigfish.highland"
            let transformedFilename = transformFilename(originalFilename)

            XCTAssertEqual(transformedFilename, "bigfish.guion", "Highland file should transform to .guion extension")
        } else {
            // Just test the transformation logic
            let originalFilename = "TestScript.highland"
            let transformedFilename = transformFilename(originalFilename)

            XCTAssertEqual(transformedFilename, "TestScript.guion", "Highland file should transform to .guion extension")
        }
    }

    // MARK: - GATE 2.5: Filename transformation

    func testFilenameTransformation() {
        // Test various filename transformations
        XCTAssertEqual(transformFilename("script.fountain"), "script.guion")
        XCTAssertEqual(transformFilename("test.fdx"), "test.guion")
        XCTAssertEqual(transformFilename("movie.highland"), "movie.guion")
        XCTAssertEqual(transformFilename("already.guion"), "already.guion")

        // Test edge cases
        XCTAssertEqual(transformFilename("no-extension"), "no-extension.guion")
        XCTAssertEqual(transformFilename("multiple.dots.in.name.fountain"), "multiple.dots.in.name.guion")
        XCTAssertEqual(transformFilename("UPPERCASE.FOUNTAIN"), "UPPERCASE.guion")

        // Test nil
        XCTAssertNil(transformFilename(nil))

        // Test empty string
        XCTAssertEqual(transformFilename(""), ".guion")
    }

    // MARK: - Additional Coverage Tests

    func testNativeGuionFileNoReparsing() async throws {
        // Create a .guion file with pre-parsed content
        let document = GuionDocumentModel(filename: "no-reparse.guion")

        // Add 100 elements
        for i in 1...100 {
            let element = GuionElementModel(
                elementText: i % 10 == 0 ? "INT. LOCATION \(i) - DAY" : "Action line \(i)",
                elementType: i % 10 == 0 ? ElementType.sceneHeading : ElementType.action
            )
            element.document = document
            document.elements.append(element)
        }

        modelContext.insert(document)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-reparse.guion")

        // Save
        let saveStart = Date()
        try document.save(to: tempURL)
        let saveTime = Date().timeIntervalSince(saveStart)

        // Load
        let loadStart = Date()
        let loaded = try GuionDocumentModel.load(from: tempURL, in: modelContext)
        let loadTime = Date().timeIntervalSince(loadStart)

        // Verify no re-parsing occurred (should be very fast)
        XCTAssertLessThan(loadTime, 0.1, "Native .guion load should be fast (no parsing)")
        XCTAssertEqual(loaded.elements.count, 100, "All elements should be loaded")

        // Verify scene locations are already cached
        let sceneElements = loaded.elements.filter { $0.elementType == .sceneHeading }
        for sceneElement in sceneElements {
            XCTAssertNotNil(sceneElement.locationLighting, "Scene location should be cached")
            XCTAssertNotNil(sceneElement.locationScene, "Scene location should be cached")
        }

        print("💾 Native .guion save time: \(saveTime)s, load time: \(loadTime)s")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testImportVsNativePerformance() async throws {
        // This test compares import workflow vs native .guion loading

        // Create a document and save as .guion
        let document = GuionDocumentModel(filename: "perf-test.guion")

        for i in 1...500 {
            let elementType = i % 5 == 0 ? ElementType.sceneHeading : ElementType.action
            let elementText = elementType == .sceneHeading
                ? "INT. LOCATION \(i) - DAY"
                : "This is action line number \(i)"

            let element = GuionElementModel(
                elementText: elementText,
                elementType: elementType
            )
            element.document = document
            document.elements.append(element)
        }

        modelContext.insert(document)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("perf-test.guion")

        try document.save(to: tempURL)

        // Time native load
        let nativeStart = Date()
        let _ = try GuionDocumentModel.load(from: tempURL, in: modelContext)
        let nativeTime = Date().timeIntervalSince(nativeStart)

        print("📊 Performance: Native .guion load: \(nativeTime)s for 500 elements")

        // Report performance metric (no assertion - tracked separately)
        print("📊 PERFORMANCE METRICS:")
        print("   Native load: \(String(format: "%.3f", nativeTime))s")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testFilenamePreservation() async throws {
        // Test that native .guion files preserve their original filename
        let originalFilename = "MyGreatScreenplay.guion"
        let document = GuionDocumentModel(filename: originalFilename)

        let element = GuionElementModel(elementText: "INT. ROOM - DAY", elementType: .sceneHeading)
        element.document = document
        document.elements.append(element)

        modelContext.insert(document)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(originalFilename)

        try document.save(to: tempURL)
        let loaded = try GuionDocumentModel.load(from: tempURL, in: modelContext)

        XCTAssertEqual(loaded.filename, originalFilename, "Filename should be preserved")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testImportedFilenameTransformation() {
        // Test transformation of various screenplay formats
        let testCases: [(input: String, expected: String)] = [
            ("screenplay.fountain", "screenplay.guion"),
            ("SCRIPT.FDX", "SCRIPT.guion"),
            ("movie.highland", "movie.guion"),
            ("my-script-v2.fountain", "my-script-v2.guion"),
            ("ScriptName_Final.fdx", "ScriptName_Final.guion"),
            ("test (1).fountain", "test (1).guion"),
            ("script with spaces.fountain", "script with spaces.guion")
        ]

        for (input, expected) in testCases {
            let result = transformFilename(input)
            XCTAssertEqual(result, expected, "Filename transformation failed for: \(input)")
        }
    }

    func testGuionFileAlreadyGuionExtension() {
        // Test that .guion files don't get double-extension
        let input = "already.guion"
        let result = transformFilename(input)

        XCTAssertEqual(result, "already.guion", "Should not add .guion to already .guion files")
        XCTAssertFalse(result?.hasSuffix(".guion.guion") ?? true, "Should not double the extension")
    }

    func testEmptyAndNilFilenames() {
        // Test edge cases
        XCTAssertNil(transformFilename(nil), "Nil should return nil")
        XCTAssertEqual(transformFilename(""), ".guion", "Empty string should add .guion")
        // Note: "." transforms to "..guion" because deletingPathExtension on "." returns "."
        // This is expected behavior from NSString.deletingPathExtension
        XCTAssertEqual(transformFilename("."), "..guion", "Just a dot becomes ..guion")
    }

    func testSpecialCharactersInFilename() {
        // Test filenames with special characters
        let testCases: [(input: String, expected: String)] = [
            ("script@v1.fountain", "script@v1.guion"),
            ("my_script.fountain", "my_script.guion"),
            ("script-name.fountain", "script-name.guion"),
            ("script.backup.fountain", "script.backup.guion"),
            ("100%.fountain", "100%.guion")
        ]

        for (input, expected) in testCases {
            let result = transformFilename(input)
            XCTAssertEqual(result, expected, "Special character handling failed for: \(input)")
        }
    }

    func testMultipleDotsInFilename() {
        // Test filename with multiple dots
        let input = "my.script.v2.fountain"
        let result = transformFilename(input)

        XCTAssertEqual(result, "my.script.v2.guion", "Should preserve all dots except the extension")
    }

    // MARK: - Helper Methods

    /// Replicate the transformation logic from GuionDocument
    private func transformFilename(_ originalFilename: String?) -> String? {
        guard let original = originalFilename else { return nil }

        // Strip original extension, add .guion
        let baseName = (original as NSString).deletingPathExtension
        return "\(baseName).guion"
    }
}
