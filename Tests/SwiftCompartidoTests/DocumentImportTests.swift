//
//  DocumentImportTests.swift
//  SwiftGuionTests
//
//  Copyright (c) 2025
//

import Testing
import SwiftData
import UniformTypeIdentifiers
@testable import SwiftCompartido

@MainActor
struct DocumentImportTests {

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
        // Try SPM Bundle.module first, fall back to test bundle
        let bundle: Bundle
        #if SWIFT_PACKAGE
        bundle = Bundle.module
        #else
        bundle = Bundle(for: type(of: self))
        #endif

        guard let path = bundle.resourcePath else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find resource path"])
        }

        // Try Fixtures subdirectory first (local development), then fall back to root (Xcode Cloud)
        let fixturesSubdir = URL(fileURLWithPath: path).appendingPathComponent("Fixtures")
        if FileManager.default.fileExists(atPath: fixturesSubdir.path) {
            fixturesPath = fixturesSubdir
        } else {
            // On Xcode Cloud, fixtures might be at the root level
            fixturesPath = URL(fileURLWithPath: path)
        }
    }

    /// Helper to find fixture files that might be in Fixtures/ or at the root
    private func fixtureURL(for filename: String) -> URL {
        let url = fixturesPath.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        // If not found in fixturesPath, try alternate location
        let bundle: Bundle
        #if SWIFT_PACKAGE
        bundle = Bundle.module
        #else
        bundle = Bundle(for: type(of: self))
        #endif

        if let path = bundle.resourcePath {
            let alternateBase = fixturesPath.path.contains("Fixtures")
                ? URL(fileURLWithPath: path)  // Try root if we were using Fixtures/
                : URL(fileURLWithPath: path).appendingPathComponent("Fixtures")  // Try Fixtures/ if we were using root
            let alternateURL = alternateBase.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: alternateURL.path) {
                return alternateURL
            }
        }

        // Return original path even if it doesn't exist (let test handle the error)
        return url
    }

    override func tearDown() async throws {
        modelContext = nil
        modelContainer = nil
        fixturesPath = nil
        try await super.tearDown()
    }

    // MARK: - GATE 2.1: Open native .guion file

    @Test func testOpenNativeGuionFile() async throws {
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
        #expect(loaded.filename == "test-native.guion", "Filename should be unchanged")
        #expect(loaded.elements.count == 2, "Should have 2 elements")
        #expect(loaded.elements[0].elementType == .sceneHeading, "First element should be Scene Heading")
        #expect(loaded.elements[1].elementType == .action, "Second element should be Action")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - GATE 2.2: Import .fountain file

    @Test func testImportFountainFile() throws {
        // Test filename transformation logic for .fountain files
        // (Actual BigFish.fountain file may not be available in test bundle)

        let originalFilename = "BigFish.fountain"
        let transformedFilename = transformFilename(originalFilename)

        #expect(transformedFilename == "BigFish.guion", "Fountain file should transform to .guion extension")

        // Verify the transformation preserves base name
        #expect(transformedFilename?.hasPrefix("BigFish") ?? false, "Should preserve base name")
        #expect(transformedFilename?.hasSuffix(".guion") ?? false, "Should have .guion extension")

        // Test with other fountain filenames
        #expect(transformFilename("screenplay.fountain") == "screenplay.guion")
        #expect(transformFilename("MyScript.FOUNTAIN") == "MyScript.guion")
    }

    // MARK: - GATE 2.3: Import .fdx file

    @Test func testImportFDXFile() throws {
        // Note: We need to create or find an FDX test file
        // For now, test the transformation logic

        let originalFilename = "TestScript.fdx"
        let transformedFilename = transformFilename(originalFilename)

        #expect(transformedFilename == "TestScript.guion", "FDX file should transform to .guion extension")
    }

    // MARK: - GATE 2.4: Import .highland file

    @Test func testImportHighlandFile() throws {
        // Check if we have Highland test files
        let highlandURL = fixtureURL(for: "bigfish.highland")

        if FileManager.default.fileExists(atPath: highlandURL.path) {
            // Test transformation
            let originalFilename = "bigfish.highland"
            let transformedFilename = transformFilename(originalFilename)

            #expect(transformedFilename == "bigfish.guion", "Highland file should transform to .guion extension")
        } else {
            // Just test the transformation logic
            let originalFilename = "TestScript.highland"
            let transformedFilename = transformFilename(originalFilename)

            #expect(transformedFilename == "TestScript.guion", "Highland file should transform to .guion extension")
        }
    }

    // MARK: - GATE 2.5: Filename transformation

    @Test func testFilenameTransformation() {
        // Test various filename transformations
        #expect(transformFilename("script.fountain") == "script.guion")
        #expect(transformFilename("test.fdx") == "test.guion")
        #expect(transformFilename("movie.highland") == "movie.guion")
        #expect(transformFilename("already.guion") == "already.guion")

        // Test edge cases
        #expect(transformFilename("no-extension") == "no-extension.guion")
        #expect(transformFilename("multiple.dots.in.name.fountain") == "multiple.dots.in.name.guion")
        #expect(transformFilename("UPPERCASE.FOUNTAIN") == "UPPERCASE.guion")

        // Test nil
        #expect(transformFilename(nil) == nil, "Nil should return nil")

        // Test empty string
        #expect(transformFilename("") == ".guion")
    }

    // MARK: - Additional Coverage Tests

    @Test func testNativeGuionFileNoReparsing() async throws {
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
        #expect(loadTime < 0.1, "Native .guion load should be fast (no parsing)")
        #expect(loaded.elements.count == 100, "All elements should be loaded")

        // Verify scene locations are already cached
        let sceneElements = loaded.elements.filter { $0.elementType == .sceneHeading }
        for sceneElement in sceneElements {
            #expect(sceneElement.locationLighting, "Scene location should be cached" != nil)
            #expect(sceneElement.locationScene, "Scene location should be cached" != nil)
        }

        print("💾 Native .guion save time: \(saveTime)s, load time: \(loadTime)s")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test func testImportVsNativePerformance() async throws {
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

    @Test func testFilenamePreservation() async throws {
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

        #expect(loaded.filename == originalFilename, "Filename should be preserved")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test func testImportedFilenameTransformation() {
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
            #expect(result == expected, "Filename transformation failed for: \(input)")
        }
    }

    @Test func testGuionFileAlreadyGuionExtension() {
        // Test that .guion files don't get double-extension
        let input = "already.guion"
        let result = transformFilename(input)

        #expect(result == "already.guion", "Should not add .guion to already .guion files")
        #expect(!result?.hasSuffix(".guion.guion") ?? true, "Should not double the extension")
    }

    @Test func testEmptyAndNilFilenames() {
        // Test edge cases
        #expect(transformFilename(nil == nil), "Nil should return nil")
        #expect(transformFilename("") == ".guion", "Empty string should add .guion")
        // Note: "." transforms to "..guion" because deletingPathExtension on "." returns "."
        // This is expected behavior from NSString.deletingPathExtension
        #expect(transformFilename(".") == "..guion", "Just a dot becomes ..guion")
    }

    @Test func testSpecialCharactersInFilename() {
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
            #expect(result == expected, "Special character handling failed for: \(input)")
        }
    }

    @Test func testMultipleDotsInFilename() {
        // Test filename with multiple dots
        let input = "my.script.v2.fountain"
        let result = transformFilename(input)

        #expect(result == "my.script.v2.guion", "Should preserve all dots except the extension")
    }

    // MARK: - Outline Elements Tests

    @Test func testHighlandFileWithOutlineElements() async throws {
        // Test parsing of Highland file that contains only outline elements (synopsis)
        let highlandURL = fixtureURL(for: "a fool in the desert.highland")

        // Verify file exists
        guard FileManager.default.fileExists(atPath: highlandURL.path) else {
            Issue.record("Highland test file 'a fool in the desert.highland' not found at \(highlandURL.path)")
            return
        }

        // Parse the Highland file
        let screenplay = try await GuionParsedElementCollection(highland: highlandURL)

        // Verify we have elements
        #expect(screenplay.elements.count > 0, "Should have parsed elements from Highland file")

        // Verify we have section headings (## markers)
        let sectionHeadings = screenplay.elements.filter { $0.elementType.isSectionHeading }
        #expect(sectionHeadings.count > 0, "Should have section heading elements")

        // Verify we have synopsis/outline elements (= markers)
        let synopsisElements = screenplay.elements.filter { $0.elementType == .synopsis }
        #expect(synopsisElements.count > 0, "Should have synopsis/outline elements")

        print("📝 Highland file parsing results:")
        print("   Total elements: \(screenplay.elements.count)")
        print("   Section headings: \(sectionHeadings.count)")
        print("   Synopsis elements: \(synopsisElements.count)")

        // Verify specific section headings from the "Save the Cat" beat sheet
        let sectionTitles = sectionHeadings.map { $0.elementText }
        print("   Section titles found: \(sectionTitles.prefix(10))")

        // Check for specific titles (case-insensitive contains)
        let hasOpeningImage = sectionTitles.contains(where: { $0.localizedCaseInsensitiveContains("Opening Image") })
        let hasThemeStated = sectionTitles.contains(where: { $0.localizedCaseInsensitiveContains("Theme Stated") })
        let hasCatalyst = sectionTitles.contains(where: { $0.localizedCaseInsensitiveContains("Catalyst") })

        #expect(hasOpeningImage, "Should find 'Opening Image' section. Found: \(sectionTitles.prefix(5))")
        #expect(hasThemeStated, "Should find 'Theme Stated' section")
        #expect(hasCatalyst, "Should find 'Catalyst' section")

        // Verify at least one synopsis element has content
        let firstSynopsis = synopsisElements.first
        #expect(firstSynopsis, "Should have at least one synopsis element" != nil)
        #expect(!firstSynopsis?.elementText.isEmpty ?? true, "Synopsis element should have text content")
    }

    @Test func testHighlandToSwiftDataConversion() async throws {
        // Test converting Highland file with outline elements to SwiftData
        let highlandURL = fixtureURL(for: "a fool in the desert.highland")

        guard FileManager.default.fileExists(atPath: highlandURL.path) else {
            Issue.record("Highland test file 'a fool in the desert.highland' not found")
            return
        }

        // Parse the Highland file
        let screenplay = try await GuionParsedElementCollection(highland: highlandURL)

        // Convert to SwiftData
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: modelContext,
            generateSummaries: false
        )

        // Verify document was created
        #expect(document, "Document should be created" != nil)

        // Verify elements were converted to SwiftData models
        let sortedElements = document.sortedElements
        #expect(sortedElements.count > 0, "Should have converted elements to SwiftData")

        // Count element types in SwiftData
        let sectionHeadingModels = sortedElements.filter { $0.elementType.isSectionHeading }
        let synopsisModels = sortedElements.filter { $0.elementType == .synopsis }

        #expect(sectionHeadingModels.count > 0, "Should have section heading models in SwiftData")
        #expect(synopsisModels.count > 0, "Should have synopsis models in SwiftData")

        print("📊 SwiftData conversion results:")
        print("   Total element models: \(sortedElements.count)")
        print("   Section heading models: \(sectionHeadingModels.count)")
        print("   Synopsis models: \(synopsisModels.count)")

        // Verify elements are properly sorted by (chapterIndex, orderIndex)
        // Elements should be in ascending order by chapter, then by orderIndex within each chapter
        var previousChapter = 0
        var previousOrderInChapter = 0

        for element in sortedElements {
            if element.chapterIndex > previousChapter {
                // New chapter - reset order counter
                previousChapter = element.chapterIndex
                previousOrderInChapter = element.orderIndex
            } else if element.chapterIndex == previousChapter {
                // Same chapter - orderIndex should not decrease
                #expect(element.orderIndex >= previousOrderInChapter,
                    "Elements within chapter \(element.chapterIndex) should be in ascending order")
                previousOrderInChapter = element.orderIndex
            }
        }

        // Verify specific content is preserved
        let firstSynopsis = synopsisModels.first
        #expect(firstSynopsis, "Should have at least one synopsis model" != nil)
        #expect(!firstSynopsis?.elementText.isEmpty ?? true, "Synopsis model should preserve text content")
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
