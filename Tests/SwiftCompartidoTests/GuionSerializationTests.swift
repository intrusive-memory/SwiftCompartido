//
//  GuionSerializationTests.swift
//  SwiftGuionTests
//
//  Copyright (c) 2025
//

import Foundation
import Testing
import SwiftData
@testable import SwiftCompartido

@MainActor
struct GuionSerializationTests {

    var modelContext: ModelContext
    var modelContainer: ModelContainer

    init() throws {
        // Create in-memory model container for testing
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = modelContainer.mainContext
    }

    // MARK: - Gate 1.1: Round-trip serialization

    @Test func testRoundTripSerialization() async throws {
        // Create a document with test data
        let original = GuionDocumentModel(filename: "test.guion", rawContent: "Test content")
        let sceneElement = GuionElementModel(
            elementText: "INT. TEST LOCATION - DAY",
            elementType: .sceneHeading,
            sceneNumber: "1"
        )
        sceneElement.document = original
        original.elements.append(sceneElement)

        let actionElement = GuionElementModel(
            elementText: "This is a test action.",
            elementType: .action
        )
        actionElement.document = original
        original.elements.append(actionElement)

        let titleEntry = TitlePageEntryModel(key: "Title", values: ["Test Screenplay"])
        titleEntry.document = original
        original.titlePage.append(titleEntry)

        modelContext.insert(original)

        // Save to file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_roundtrip.guion")

        try original.save(to: tempURL)
        #expect(FileManager.default.fileExists(atPath: tempURL.path), "File should be created")

        // Load from file
        let loaded = try GuionDocumentModel.load(from: tempURL, in: modelContext)

        // Verify data integrity
        #expect(loaded.filename == original.filename, "Filename should match")
        #expect(loaded.rawContent == original.rawContent, "Raw content should match")
        #expect(loaded.suppressSceneNumbers == original.suppressSceneNumbers, "suppressSceneNumbers should match")
        #expect(loaded.elements.count == original.elements.count, "Element count should match")
        #expect(loaded.titlePage.count == original.titlePage.count, "Title page count should match")

        // Verify first element
        #expect(loaded.elements[0].elementText == sceneElement.elementText, "Element text should match")
        #expect(loaded.elements[0].elementType == sceneElement.elementType, "Element type should match")
        #expect(loaded.elements[0].sceneNumber == sceneElement.sceneNumber, "Scene number should match")

        // Verify second element
        #expect(loaded.elements[1].elementText == actionElement.elementText, "Action text should match")
        #expect(loaded.elements[1].elementType == actionElement.elementType, "Action type should match")

        // Verify title page
        #expect(loaded.titlePage[0].key == titleEntry.key, "Title key should match")
        #expect(loaded.titlePage[0].values == titleEntry.values, "Title values should match")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Gate 1.2: Preserve relationships

    @Test func testPreserveRelationships() async throws {
        // Create document with multiple elements
        let document = GuionDocumentModel(filename: "relationships.guion")

        for i in 1...5 {
            let element = GuionElementModel(
                elementText: "Element \(i)",
                elementType: .action
            )
            element.document = document
            document.elements.append(element)
        }

        modelContext.insert(document)

        // Save and reload
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_relationships.guion")

        try document.save(to: tempURL)
        let loaded = try GuionDocumentModel.load(from: tempURL, in: modelContext)

        // Verify all elements have correct parent reference
        for (index, element) in loaded.elements.enumerated() {
            #expect(element.document != nil, "Element \(index) should have document reference")
            #expect(element.document === loaded, "Element \(index) should reference loaded document")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Gate 1.3: Preserve scene locations

    @Test func testPreserveSceneLocations() async throws {
        // Create document with scene headings
        let document = GuionDocumentModel(filename: "locations.guion")

        let scenes = [
            "INT. COFFEE SHOP - DAY",
            "EXT. PARK - NIGHT",
            "INT./EXT. CAR - DAWN",
            "INT. BEDROOM - CONTINUOUS"
        ]

        for scene in scenes {
            let element = GuionElementModel(
                elementText: scene,
                elementType: .sceneHeading
            )
            element.document = document
            document.elements.append(element)
        }

        modelContext.insert(document)

        // Verify locations are cached before save
        #expect(document.elements[0].locationLighting != nil, "Location lighting should be cached")
        #expect(document.elements[0].locationScene != nil, "Location scene should be cached")

        // Save and reload
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_locations.guion")

        try document.save(to: tempURL)
        let loaded = try GuionDocumentModel.load(from: tempURL, in: modelContext)

        // Verify all scene locations preserved
        for (index, element) in loaded.elements.enumerated() {
            #expect(element.elementType == .sceneHeading, "Element \(index) should be scene heading")
            #expect(element.locationLighting != nil, "Element \(index) should have cached lighting")
            #expect(element.locationScene != nil, "Element \(index) should have cached scene")

            let cachedLocation = element.cachedSceneLocation
            #expect(cachedLocation != nil, "Element \(index) should reconstruct cached location")
        }

        // Verify specific location details
        #expect(loaded.elements[0].locationLighting == "INT", "First scene should be INT")
        #expect(loaded.elements[0].locationScene == "COFFEE SHOP", "First scene should be COFFEE SHOP")
        #expect(loaded.elements[0].locationTimeOfDay == "DAY", "First scene should be DAY")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Gate 1.4: Handle large documents

    @Test func testLargeDocumentPerformance() async throws {
        // Create document with 1000 elements
        let document = GuionDocumentModel(filename: "large.guion")

        for i in 1...1000 {
            let elementType = i % 10 == 0 ? "Scene Heading" : "Action"
            let elementText = elementType == "Scene Heading"
                ? "INT. LOCATION \(i) - DAY"
                : "Action line number \(i)"

            let element = GuionElementModel(
                elementText: elementText,
                elementType: ElementType(string: elementType))
            element.document = document
            document.elements.append(element)
        }

        modelContext.insert(document)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_large.guion")

        // Ensure cleanup happens even if test fails
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Measure save time
        let saveStart = Date()
        try document.save(to: tempURL)
        let saveTime = Date().timeIntervalSince(saveStart)

        print("💾 Save time for 1000 elements: \(saveTime)s")

        // Measure load time
        let loadStart = Date()
        let loaded = try GuionDocumentModel.load(from: tempURL, in: modelContext)
        let loadTime = Date().timeIntervalSince(loadStart)

        print("📥 Load time for 1000 elements: \(loadTime)s")

        // Verify data
        #expect(loaded.elements.count == 1000, "Should have 1000 elements")

        // Report performance metrics (no assertions - tracked separately)
        print("📊 PERFORMANCE METRICS:")
        print("   Serialization save: \(String(format: "%.3f", saveTime))s")
        print("   Serialization load: \(String(format: "%.3f", loadTime))s")

        // Explicitly clean up loaded document from context to free memory
        modelContext.delete(loaded)
        modelContext.delete(document)

        // Process pending changes to ensure cleanup
        try modelContext.save()
    }

    // MARK: - Additional coverage tests

    @Test func testEmptyDocument() async throws {
        // Test serialization of empty document
        let document = GuionDocumentModel(filename: "empty.guion")
        modelContext.insert(document)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_empty.guion")

        try document.save(to: tempURL)
        let loaded = try GuionDocumentModel.load(from: tempURL, in: modelContext)

        #expect(loaded.elements.count == 0, "Should have no elements")
        #expect(loaded.titlePage.count == 0, "Should have no title page entries")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test func testDocumentWithAllElementTypes() async throws {
        // Test all element types
        let document = GuionDocumentModel(filename: "all_types.guion")

        let elementTypes = [
            ("Scene Heading", "INT. LOCATION - DAY"),
            ("Action", "Character walks into the room."),
            ("Character", "JOHN"),
            ("Dialogue", "Hello, world!"),
            ("Parenthetical", "(smiling)"),
            ("Transition", "CUT TO:"),
            ("Section", "# ACT ONE"),
            ("Synopsis", "= This is the first act"),
            ("Note", "[[ This is a note ]]"),
            ("Boneyard", "/* This is in the boneyard */")
        ]

        for (type, text) in elementTypes {
            let element = GuionElementModel(
                elementText: text,
                elementType: ElementType(string: type)
            )
            element.document = document
            document.elements.append(element)
        }

        modelContext.insert(document)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_all_types.guion")

        try document.save(to: tempURL)
        let loaded = try GuionDocumentModel.load(from: tempURL, in: modelContext)

        #expect(loaded.elements.count == elementTypes.count, "Should have all element types")

        for (index, (expectedType, expectedText)) in elementTypes.enumerated() {
            #expect(loaded.elements[index].elementType == ElementType(string: expectedType), "Element \(index) type should match")
            #expect(loaded.elements[index].elementText == expectedText, "Element \(index) text should match")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test func testDocumentWithSpecialCharacters() async throws {
        // Test handling of special characters
        let document = GuionDocumentModel(filename: "special_chars.guion")

        let specialTexts = [
            "Emoji: 😀🎬🎥",
            "Unicode: Ωmega ß ñ",
            "Quotes: \"Hello\" 'World'",
            "Newlines:\nMultiple\nLines",
            "Tabs:\tIndented\tText",
            "Symbols: @#$%^&*()"
        ]

        for text in specialTexts {
            let element = GuionElementModel(
                elementText: text,
                elementType: .action
            )
            element.document = document
            document.elements.append(element)
        }

        modelContext.insert(document)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_special.guion")

        try document.save(to: tempURL)
        let loaded = try GuionDocumentModel.load(from: tempURL, in: modelContext)

        for (index, expectedText) in specialTexts.enumerated() {
            #expect(loaded.elements[index].elementText == expectedText, "Special characters should be preserved")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test func testDocumentValidation() async throws {
        // Test validation logic
        let document = GuionDocumentModel(filename: "validation.guion")

        let element = GuionElementModel(
            elementText: "INT. TEST - DAY",
            elementType: .sceneHeading
        )
        element.document = document
        document.elements.append(element)

        modelContext.insert(document)

        // Validation should succeed
        try document.validate()

        // Test scene location re-parsing
        #expect(element.locationLighting != nil, "Should have cached location")
    }

    @Test func testEncodingErrors() async throws {
        // This test verifies error handling during encoding
        // Note: It's difficult to force an encoding error with valid models
        // This test primarily ensures the error path is compiled

        let document = GuionDocumentModel(filename: "error_test.guion")
        modelContext.insert(document)

        // Save should succeed for valid document
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_encoding.guion")

        _ = try document.save(to: tempURL)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test func testDecodingCorruptedFile() async throws {
        // Create a corrupted file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_corrupted.guion")

        let corruptedData = Data([0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE])
        try corruptedData.write(to: tempURL)

        // Attempt to load should throw error
        do { _ = try GuionDocumentModel.load(from: tempURL, in: modelContext); Issue.record("Expected error") } catch { /* Expected */ }

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test func testVersionCompatibility() async throws {
        // Test that current version is saved
        let document = GuionDocumentModel(filename: "version.guion")
        let element = GuionElementModel(elementText: "Test", elementType: .action)
        element.document = document
        document.elements.append(element)
        modelContext.insert(document)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_version.guion")

        try document.save(to: tempURL)

        // Read raw data to verify version number
        let data = try Data(contentsOf: tempURL)
        let decoder = PropertyListDecoder()
        let snapshot = try decoder.decode(GuionDocumentSnapshot.self, from: data)

        #expect(snapshot.version == GuionDocumentSnapshot.currentVersion, "Version should match")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test func testBinaryDataEncoding() async throws {
        // Test direct binary data encoding/decoding
        let document = GuionDocumentModel(filename: "binary.guion")
        let element = GuionElementModel(
            elementText: "INT. TEST - DAY",
            elementType: .sceneHeading
        )
        element.document = document
        document.elements.append(element)
        modelContext.insert(document)

        // Encode to binary data
        let data = try document.encodeToBinaryData()
        #expect(data.count > 0, "Encoded data should not be empty")

        // Decode from binary data
        let decoded = try GuionDocumentModel.decodeFromBinaryData(data, in: modelContext)

        #expect(decoded.filename == document.filename, "Decoded filename should match")
        #expect(decoded.elements.count == document.elements.count, "Decoded elements count should match")
        #expect(decoded.elements[0].elementText == element.elementText, "Decoded element text should match")
    }

    @Test func testMultipleTitlePageEntries() async throws {
        // Test multiple title page entries
        let document = GuionDocumentModel(filename: "title_page.guion")

        let entries = [
            ("Title", ["Test Screenplay"]),
            ("Author", ["John Doe", "Jane Smith"]),
            ("Draft", ["First Draft"]),
            ("Contact", ["john@example.com", "+1-555-1234"])
        ]

        for (key, values) in entries {
            let entry = TitlePageEntryModel(key: key, values: values)
            entry.document = document
            document.titlePage.append(entry)
        }

        modelContext.insert(document)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_title_page.guion")

        try document.save(to: tempURL)
        let loaded = try GuionDocumentModel.load(from: tempURL, in: modelContext)

        #expect(loaded.titlePage.count == entries.count, "Should have all title page entries")

        for (index, (expectedKey, expectedValues)) in entries.enumerated() {
            #expect(loaded.titlePage[index].key == expectedKey.uppercased(), "Title page key should match (normalized to uppercase)")
            #expect(loaded.titlePage[index].values == expectedValues, "Title page values should match")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test func testSceneNumberPreservation() async throws {
        // Test that scene numbers are preserved
        let document = GuionDocumentModel(filename: "scene_numbers.guion")

        for i in 1...10 {
            let element = GuionElementModel(
                elementText: "INT. LOCATION \(i) - DAY",
                elementType: .sceneHeading,
                sceneNumber: "\(i)"
            )
            element.document = document
            document.elements.append(element)
        }

        modelContext.insert(document)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_scene_numbers.guion")

        try document.save(to: tempURL)
        let loaded = try GuionDocumentModel.load(from: tempURL, in: modelContext)

        for (index, element) in loaded.elements.enumerated() {
            #expect(element.sceneNumber == "\(index + 1)", "Scene number should be preserved")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test func testValidationMissingData() async throws {
        // Test validation with missing required data
        let document = GuionDocumentModel()
        document.filename = nil
        document.rawContent = nil
        modelContext.insert(document)

        do { _ = try document.validate(); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testValidationSucceedsWithValidRelationships() async throws {
        // Test that validation succeeds when relationships are correct
        let document = GuionDocumentModel(filename: "valid.guion")

        let element = GuionElementModel(elementText: "Test", elementType: .action)
        element.document = document
        document.elements.append(element)

        let entry = TitlePageEntryModel(key: "Title", values: ["Test"])
        entry.document = document
        document.titlePage.append(entry)

        modelContext.insert(document)

        // Validation should succeed
        _ = try document.validate()
    }

    @Test func testLocationCachingForSceneHeadings() async throws {
        // Test that scene headings have their location data cached
        let document = GuionDocumentModel(filename: "locations.guion")

        let sceneElement = GuionElementModel(
            elementText: "INT. COFFEE SHOP - DAY",
            elementType: .sceneHeading
        )
        sceneElement.document = document
        document.elements.append(sceneElement)

        modelContext.insert(document)

        // Validate should ensure locations are cached
        try document.validate()

        #expect(sceneElement.locationLighting != nil, "Scene heading should have cached lighting")
        #expect(sceneElement.locationScene != nil, "Scene heading should have cached scene")
    }

    @Test func testValidationReparseMissingLocation() async throws {
        // Test validation triggers re-parsing for scene headings with missing location data
        let document = GuionDocumentModel(filename: "reparse.guion")

        let element = GuionElementModel(
            elementText: "INT. COFFEE SHOP - DAY",
            elementType: .sceneHeading
        )
        element.document = document
        document.elements.append(element)

        // Clear the cached location data
        element.locationLighting = nil
        element.locationScene = nil

        modelContext.insert(document)

        // Validate should trigger re-parsing
        try document.validate()

        // Location should now be cached
        #expect(element.locationLighting != nil, "Location should be re-parsed")
        #expect(element.locationScene != nil, "Location should be re-parsed")
    }

    @Test func testUnsupportedVersionError() async throws {
        // Create a document with future version number
        let document = GuionDocumentModel(filename: "future.guion")
        let element = GuionElementModel(elementText: "Test", elementType: .action)
        element.document = document
        document.elements.append(element)
        modelContext.insert(document)

        // Save and modify the version
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_future_version.guion")

        try document.save(to: tempURL)

        // Read and modify the data to have a future version
        var data = try Data(contentsOf: tempURL)

        // Manually construct a dictionary with future version
        var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String: Any]
        plist["version"] = 999
        data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        try data.write(to: tempURL)

        // Attempt to load should throw unsupportedVersion error
        do {
            _ = try GuionDocumentModel.load(from: tempURL, in: modelContext)
            Issue.record("Expected unsupportedVersion error")
        } catch {
            // Expected error
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test func testBinaryDataUnsupportedVersion() async throws {
        // Test unsupportedVersion error in binary data decoding
        let document = GuionDocumentModel(filename: "binary_future.guion")
        let element = GuionElementModel(elementText: "Test", elementType: .action)
        element.document = document
        document.elements.append(element)
        modelContext.insert(document)

        // Encode and modify to future version
        var data = try document.encodeToBinaryData()
        var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String: Any]
        plist["version"] = 999
        data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)

        // Attempt to decode should throw unsupportedVersion error
        do {
            _ = try GuionDocumentModel.decodeFromBinaryData(data, in: modelContext)
            Issue.record("Expected unsupportedVersion error")
        } catch {
            // Expected error
        }
    }

    @Test func testBinaryDataCorruptedData() async throws {
        // Test corrupted data in binary data decoding
        let corruptedData = Data([0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE])

        do { _ = try GuionDocumentModel.decodeFromBinaryData(corruptedData, in: modelContext); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testErrorDescriptions() {
        // Test error descriptions and recovery suggestions
        let encodingError = GuionSerializationError.encodingFailed(NSError(domain: "test", code: 1))
        #expect(encodingError.errorDescription != nil)
        #expect(encodingError.recoverySuggestion != nil)

        let decodingError = GuionSerializationError.decodingFailed(NSError(domain: "test", code: 2))
        #expect(decodingError.errorDescription != nil)
        #expect(decodingError.recoverySuggestion != nil)

        let corruptedError = GuionSerializationError.corruptedFile("test.guion")
        #expect(corruptedError.errorDescription != nil)
        #expect(corruptedError.recoverySuggestion != nil)

        let versionError = GuionSerializationError.unsupportedVersion(999)
        #expect(versionError.errorDescription != nil)
        #expect(versionError.recoverySuggestion != nil)

        let missingDataError = GuionSerializationError.missingData
        #expect(missingDataError.errorDescription != nil)
        #expect(missingDataError.recoverySuggestion != nil)
    }
}
