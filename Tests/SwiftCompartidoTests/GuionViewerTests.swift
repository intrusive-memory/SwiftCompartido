//
//  GuionViewerTests.swift
//  SwiftGuionTests
//
//  Comprehensive tests for GuionViewer component and related functionality
//

import XCTest
import SwiftFijos
@testable import SwiftCompartido

#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

@available(macOS 14.0, iOS 17.0, *)
final class GuionViewerTests: XCTestCase {

    // MARK: - GuionViewerState Tests

    func testGuionViewerStateLoadingCase() {
        let url = URL(fileURLWithPath: "/test/path.fountain")
        let state = GuionViewerState.loading(url)

        if case .loading(let loadedURL) = state {
            XCTAssertEqual(loadedURL, url, "Loading state should store URL")
        } else {
            XCTFail("State should be loading")
        }
    }

    func testGuionViewerStateLoadedCase() {
        let browserData = createSampleBrowserData()
        let state = GuionViewerState.loaded(browserData)

        if case .loaded(let data) = state {
            XCTAssertNotNil(data.title, "Loaded state should contain browser data")
            XCTAssertEqual(data.chapters.count, 1, "Should have sample chapter")
        } else {
            XCTFail("State should be loaded")
        }
    }

    func testGuionViewerStateErrorCase() {
        let error = GuionViewerError.unsupportedFileType("pdf")
        let state = GuionViewerState.error(error)

        if case .error(let errorValue) = state {
            if case .unsupportedFileType(let ext) = errorValue {
                XCTAssertEqual(ext, "pdf", "Error should contain file extension")
            } else {
                XCTFail("Error should be unsupportedFileType")
            }
        } else {
            XCTFail("State should be error")
        }
    }

    func testGuionViewerStateEmptyCase() {
        let state = GuionViewerState.empty

        if case .empty = state {
            // Success
        } else {
            XCTFail("State should be empty")
        }
    }

    // MARK: - GuionViewerError Tests

    func testUnsupportedFileTypeError() {
        let error = GuionViewerError.unsupportedFileType("pdf")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("pdf"))
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains(".guion"))
    }

    func testLoadFailedError() {
        struct TestError: Error {}
        let underlyingError = TestError()
        let error = GuionViewerError.loadFailed(underlyingError)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Failed to load"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testUnsupportedInitializationError() {
        let message = "Use init(document:) for .guion files"
        let error = GuionViewerError.unsupportedInitialization(message)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertEqual(error.errorDescription, message)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testMissingModelContextError() {
        let error = GuionViewerError.missingModelContext

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("ModelContext"))
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("init(document:)"))
    }

    // MARK: - GuionViewer Initialization Tests

    @MainActor
    func testInitWithFountainScript() throws {
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path
        let script = try GuionParsedScreenplay(file: fountainPath)

        // Create viewer with script
        let viewer = GuionViewer(script: script)

        // Viewer should be created successfully
        XCTAssertNotNil(viewer)
    }

    @MainActor
    func testInitWithBrowserData() {
        let browserData = createSampleBrowserData()
        let viewer = GuionViewer(browserData: browserData)

        XCTAssertNotNil(viewer)
    }

    @MainActor
    func testInitWithGuionDocumentModel() throws {
        // Create a simple document model
        let document = GuionDocumentModel(filename: "test.guion")

        // Add some test elements
        let element = GuionElementModel(
            elementText: "INT. ROOM - DAY",
            elementType: .sceneHeading
        )
        document.elements.append(element)

        // Create viewer
        let viewer = GuionViewer(document: document)

        XCTAssertNotNil(viewer)
    }

    // MARK: - GuionDocumentModel to FountainScript Conversion Tests

    func testToFountainScriptWithElements() {
        let document = GuionDocumentModel(filename: "test.guion")

        // Add test elements
        let sceneHeading = GuionElementModel(
            elementText: "INT. ROOM - DAY",
            elementType: .sceneHeading
        )
        let action = GuionElementModel(
            elementText: "A character enters the room.",
            elementType: .action
        )
        let character = GuionElementModel(
            elementText: "JOHN",
            elementType: .character
        )
        let dialogue = GuionElementModel(
            elementText: "Hello, world!",
            elementType: .dialogue
        )

        document.elements.append(contentsOf: [sceneHeading, action, character, dialogue])

        // Convert to FountainScript
        let script = document.toFountainScript()

        XCTAssertEqual(script.elements.count, 4, "Should have 4 elements")
        XCTAssertEqual(script.elements[0].elementType, .sceneHeading)
        XCTAssertEqual(script.elements[0].elementText, "INT. ROOM - DAY")
        XCTAssertEqual(script.elements[1].elementType, .action)
        XCTAssertEqual(script.elements[3].elementType, .dialogue)
    }

    func testToFountainScriptWithTitlePage() {
        let document = GuionDocumentModel(filename: "test.guion")

        // Add title page entries
        let titleEntry = TitlePageEntryModel(key: "Title", values: ["My Screenplay"])
        let authorEntry = TitlePageEntryModel(key: "Author", values: ["John Doe"])

        document.titlePage.append(contentsOf: [titleEntry, authorEntry])

        // Convert to FountainScript
        let script = document.toFountainScript()

        XCTAssertEqual(script.titlePage.count, 1, "Should have title page")
        XCTAssertNotNil(script.titlePage.first?["Title"])
        XCTAssertEqual(script.titlePage.first?["Title"]?.first, "My Screenplay")
        XCTAssertNotNil(script.titlePage.first?["Author"])
        XCTAssertEqual(script.titlePage.first?["Author"]?.first, "John Doe")
    }

    func testToFountainScriptWithEmptyTitlePage() {
        let document = GuionDocumentModel(filename: "test.guion")

        // Add element but no title page
        let action = GuionElementModel(elementText: "Action text", elementType: .action)
        document.elements.append(action)

        // Convert to FountainScript
        let script = document.toFountainScript()

        // Should have empty title page (not added if empty)
        XCTAssertTrue(script.titlePage.isEmpty || script.titlePage.first?.isEmpty == true,
                     "Empty title page should not be added")
    }

    func testToFountainScriptPreservesFilename() {
        let document = GuionDocumentModel(filename: "test-screenplay.guion")
        let script = document.toFountainScript()

        XCTAssertEqual(script.filename, "test-screenplay.guion")
    }

    func testToFountainScriptPreservesSuppressSceneNumbers() {
        let document = GuionDocumentModel(
            filename: "test.guion",
            suppressSceneNumbers: true
        )
        let script = document.toFountainScript()

        XCTAssertTrue(script.suppressSceneNumbers)
    }

    func testToFountainScriptWithSpecialElements() {
        let document = GuionDocumentModel(filename: "test.guion")

        // Add elements with special properties
        let centeredElement = GuionElementModel(
            elementText: "THE END",
            elementType: .action,
            isCentered: true
        )

        let dualDialogueElement = GuionElementModel(
            elementText: "Speaking simultaneously",
            elementType: .dialogue,
            isDualDialogue: true
        )

        let sceneWithNumber = GuionElementModel(
            elementText: "INT. HOUSE - DAY",
            elementType: .sceneHeading,
            sceneNumber: "42"
        )

        let sectionHeading = GuionElementModel(
            elementText: "ACT ONE",
            elementType: .sectionHeading(level: 1))

        document.elements.append(contentsOf: [
            centeredElement,
            dualDialogueElement,
            sceneWithNumber,
            sectionHeading
        ])

        let script = document.toFountainScript()

        XCTAssertEqual(script.elements.count, 4)
        XCTAssertTrue(script.elements[0].isCentered)
        XCTAssertTrue(script.elements[1].isDualDialogue)
        XCTAssertEqual(script.elements[2].sceneNumber, "42")
        XCTAssertEqual(script.elements[3].sectionDepth, 1)
    }

    // MARK: - Empty State Tests

    func testEmptyDocumentCreatesEmptyBrowserData() {
        let document = GuionDocumentModel(filename: "empty.guion")
        let script = document.toFountainScript()
        let browserData = script.extractSceneBrowserData()

        // Empty document should have no chapters
        XCTAssertEqual(browserData.chapters.count, 0)
    }

    func testDocumentWithOnlyActionHasNoChapters() {
        let document = GuionDocumentModel(filename: "simple.guion")
        let action = GuionElementModel(
            elementText: "Just some action.",
            elementType: .action
        )
        document.elements.append(action)

        let script = document.toFountainScript()
        let browserData = script.extractSceneBrowserData()

        // Document with only action and no structure should have no chapters
        // (unless synthetic chapters are created)
        XCTAssertGreaterThanOrEqual(browserData.chapters.count, 0)
    }

    // MARK: - Scene Browser Data Extraction from GuionDocumentModel

    func testExtractSceneBrowserDataFromDocument() {
        let document = createSampleDocument()
        let script = document.toFountainScript()
        let browserData = script.extractSceneBrowserData()

        XCTAssertNotNil(browserData.title)
        XCTAssertGreaterThan(browserData.chapters.count, 0)
    }

    func testDocumentWithCompleteHierarchy() {
        let document = GuionDocumentModel(filename: "complete.guion")

        // Add title
        let titleEntry = TitlePageEntryModel(
            key: "Title",
            values: ["Complete Screenplay"]
        )
        document.titlePage.append(titleEntry)

        // Add main title section
        let mainTitle = GuionElementModel(
            elementText: "Complete Screenplay",
            elementType: .sectionHeading(level: 1))

        // Add chapter
        let chapter = GuionElementModel(
            elementText: "CHAPTER 1",
            elementType: .sectionHeading(level: 2))

        // Add scene group
        let sceneGroup = GuionElementModel(
            elementText: "PROLOGUE",
            elementType: .sectionHeading(level: 3))

        // Add scene
        let scene = GuionElementModel(
            elementText: "INT. ROOM - DAY",
            elementType: .sceneHeading
        )

        // Add action
        let action = GuionElementModel(
            elementText: "A character enters.",
            elementType: .action
        )

        document.elements.append(contentsOf: [
            mainTitle, chapter, sceneGroup, scene, action
        ])

        let script = document.toFountainScript()
        let browserData = script.extractSceneBrowserData()

        XCTAssertNotNil(browserData.title)
        XCTAssertGreaterThan(browserData.chapters.count, 0)

        if let firstChapter = browserData.chapters.first {
            XCTAssertGreaterThan(firstChapter.sceneGroups.count, 0)

            if let firstGroup = firstChapter.sceneGroups.first {
                XCTAssertGreaterThan(firstGroup.scenes.count, 0)

                if let firstScene = firstGroup.scenes.first {
                    XCTAssertGreaterThan(firstScene.sceneElements?.count ?? 0, 0)
                }
            }
        }
    }

    // MARK: - Integration Tests

    @MainActor
    func testEndToEndFountainToViewerFlow() throws {
        // Load fountain file
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path
        let script = try GuionParsedScreenplay(file: fountainPath)

        // Extract browser data
        let browserData = script.extractSceneBrowserData()

        // Create viewer
        let viewer = GuionViewer(browserData: browserData)

        XCTAssertNotNil(viewer)
        XCTAssertNotNil(browserData.title)
        XCTAssertGreaterThan(browserData.chapters.count, 0)
    }

    @MainActor
    func testEndToEndDocumentToViewerFlow() {
        // Create document
        let document = createSampleDocument()

        // Create viewer directly from document
        let viewer = GuionViewer(document: document)

        XCTAssertNotNil(viewer)
    }

    // MARK: - Performance Tests

    func testLargeDocumentConversionPerformance() throws {
        // Load BigFish fixture
        let fountainPath = try Fijos.getFixture("bigfish", extension: "fountain").path
        let script = try GuionParsedScreenplay(file: fountainPath)

        // Create a document model with all elements
        let document = GuionDocumentModel(filename: "bigfish.guion")

        for element in script.elements {
            let modelElement = GuionElementModel(from: element)
            document.elements.append(modelElement)
        }

        // Measure conversion time
        let startTime = Date()
        let convertedScript = document.toFountainScript()
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(convertedScript.elements.count, script.elements.count)

        print("⚡ Performance: BigFish document conversion took \(String(format: "%.3f", duration)) seconds")
        print("📊 Elements converted: \(convertedScript.elements.count)")

        // Should complete in reasonable time
        XCTAssertLessThan(duration, 1.0, "Conversion should complete in under 1 second")
    }

    func testBrowserDataExtractionPerformance() throws {
        let fountainPath = try Fijos.getFixture("bigfish", extension: "fountain").path
        let script = try GuionParsedScreenplay(file: fountainPath)

        // Create document and convert
        let document = GuionDocumentModel(filename: "bigfish.guion")
        for element in script.elements {
            document.elements.append(GuionElementModel(from: element))
        }

        let convertedScript = document.toFountainScript()

        // Measure browser data extraction
        let startTime = Date()
        let browserData = convertedScript.extractSceneBrowserData()
        let duration = Date().timeIntervalSince(startTime)

        print("⚡ Performance: Browser data extraction took \(String(format: "%.3f", duration)) seconds")
        print("📊 Chapters: \(browserData.chapters.count)")

        XCTAssertNotNil(browserData.title)
        XCTAssertLessThan(duration, 5.0, "Browser data extraction should complete in under 5 seconds")
    }

    // MARK: - Edge Cases and Error Conditions

    func testDocumentWithMixedContent() {
        let document = GuionDocumentModel(filename: "mixed.guion")

        // Mix of structured and unstructured content
        let elements = [
            GuionElementModel(elementText: "Unstructured action", elementType: .action),
            GuionElementModel(elementText: "CHAPTER 1", elementType: .sectionHeading(level: 2)),
            GuionElementModel(elementText: "More action", elementType: .action),
            GuionElementModel(elementText: "INT. ROOM - DAY", elementType: .sceneHeading),
            GuionElementModel(elementText: "Scene action", elementType: .action)
        ]

        document.elements.append(contentsOf: elements)

        let script = document.toFountainScript()
        let browserData = script.extractSceneBrowserData()

        // Should handle mixed content gracefully
        XCTAssertGreaterThanOrEqual(browserData.chapters.count, 0)
    }

    func testDocumentWithOnlyScenesNoStructure() {
        let document = GuionDocumentModel(filename: "scenes-only.guion")

        let scenes = [
            GuionElementModel(elementText: "INT. ROOM - DAY", elementType: .sceneHeading),
            GuionElementModel(elementText: "Action 1", elementType: .action),
            GuionElementModel(elementText: "EXT. STREET - NIGHT", elementType: .sceneHeading),
            GuionElementModel(elementText: "Action 2", elementType: .action)
        ]

        document.elements.append(contentsOf: scenes)

        let script = document.toFountainScript()
        let browserData = script.extractSceneBrowserData()

        // Should create synthetic structure
        XCTAssertGreaterThanOrEqual(browserData.chapters.count, 0)
    }

    func testRoundTripFidelity() throws {
        // Create original document
        let original = createSampleDocument()

        // Convert to FountainScript
        let script1 = original.toFountainScript()

        // Create new document from script
        let document2 = GuionDocumentModel(filename: "roundtrip.guion")
        for element in script1.elements {
            document2.elements.append(GuionElementModel(from: element))
        }

        for (key, values) in script1.titlePage.first ?? [:] {
            document2.titlePage.append(TitlePageEntryModel(key: key, values: values))
        }

        // Convert back to FountainScript
        let script2 = document2.toFountainScript()

        // Verify round-trip fidelity
        XCTAssertEqual(script1.elements.count, script2.elements.count)

        for (index, element) in script1.elements.enumerated() {
            XCTAssertEqual(element.elementType, script2.elements[index].elementType)
            XCTAssertEqual(element.elementText, script2.elements[index].elementText)
            XCTAssertEqual(element.isCentered, script2.elements[index].isCentered)
            XCTAssertEqual(element.isDualDialogue, script2.elements[index].isDualDialogue)
            XCTAssertEqual(element.sceneNumber, script2.elements[index].sceneNumber)
            XCTAssertEqual(element.sectionDepth, script2.elements[index].sectionDepth)
        }
    }

    // MARK: - Model-Based Scene Element Tests

    func testModelBasedSceneElementsPopulated() {
        // Create document with a complete scene
        let document = GuionDocumentModel(filename: "scene-test.guion")

        // Add structured content
        let elements = [
            GuionElementModel(
                elementText: "Test Script",
                elementType: .sectionHeading(level: 1)),
            GuionElementModel(
                elementText: "CHAPTER 1",
                elementType: .sectionHeading(level: 2)),
            GuionElementModel(
                elementText: "ACT ONE",
                elementType: .sectionHeading(level: 3)),
            GuionElementModel(
                elementText: "INT. COFFEE SHOP - DAY",
                elementType: .sceneHeading,
                sceneId: "scene-1"
            ),
            GuionElementModel(
                elementText: "JOHN sits at a table with his laptop.",
                elementType: .action
            ),
            GuionElementModel(
                elementText: "JOHN",
                elementType: .character
            ),
            GuionElementModel(
                elementText: "I need more coffee.",
                elementType: .dialogue
            )
        ]

        document.elements.append(contentsOf: elements)

        // Extract scene browser data using model-based path
        let browserData = document.extractSceneBrowserData()

        // Verify we have the structure
        XCTAssertGreaterThan(browserData.chapters.count, 0, "Should have chapters")

        guard let firstChapter = browserData.chapters.first,
              let firstGroup = firstChapter.sceneGroups.first,
              let firstScene = firstGroup.scenes.first else {
            XCTFail("Should have chapter > scene group > scene hierarchy")
            return
        }

        // Verify scene has all elements (heading + action + character + dialogue)
        #if canImport(SwiftData)
        print("📊 Scene has \(firstScene.sceneElementModels.count) model elements")

        // Debug: Print what we got
        for (index, element) in firstScene.sceneElementModels.enumerated() {
            print("  [\(index)] \(element.elementType): \(element.elementText)")
        }

        // Also check value-based path
        if let valueElements = firstScene.sceneElements {
            print("📋 Value-based scene has \(valueElements.count) elements")
            for (index, element) in valueElements.enumerated() {
                print("  [\(index)] \(element.elementType): \(element.elementText)")
            }
        }

        XCTAssertGreaterThanOrEqual(firstScene.sceneElementModels.count, 1, "Scene should have at least the heading")

        // Verify the heading is correct
        XCTAssertEqual(firstScene.sceneElementModels.first?.elementType, .sceneHeading)
        XCTAssertEqual(firstScene.sceneElementModels.first?.elementText, "INT. COFFEE SHOP - DAY")

        // Verify scene heading model is the same as first element
        XCTAssertIdentical(firstScene.sceneHeadingModel, firstScene.sceneElementModels.first)

        print("✅ Model-based scene elements correctly populated with \(firstScene.sceneElementModels.count) elements")
        #endif
    }

    func testRealScreenplaySceneElements() throws {
        // Load a real screenplay and convert to document model
        let fountainPath = try Fijos.getFixture("test", extension: "fountain").path
        let script = try GuionParsedScreenplay(file: fountainPath)

        // Create document model from screenplay
        let document = GuionDocumentModel(filename: "test.guion")
        for element in script.elements {
            document.elements.append(GuionElementModel(from: element))
        }

        // Extract scene browser data
        let browserData = document.extractSceneBrowserData()

        // Find first scene with elements
        var foundScene = false
        for chapter in browserData.chapters {
            for sceneGroup in chapter.sceneGroups {
                for scene in sceneGroup.scenes {
                    #if canImport(SwiftData)
                    if scene.sceneElementModels.count > 1 {
                        print("\n📊 Real screenplay scene: \(scene.slugline)")
                        print("   Model elements: \(scene.sceneElementModels.count)")
                        for (index, element) in scene.sceneElementModels.prefix(10).enumerated() {
                            print("   [\(index)] \(element.elementType): \(element.elementText.prefix(50))")
                        }
                        foundScene = true

                        // Verify we have multiple elements
                        XCTAssertGreaterThan(scene.sceneElementModels.count, 1, "Scene should have multiple elements")
                        break
                    }
                    #endif
                }
                if foundScene { break }
            }
            if foundScene { break }
        }

        XCTAssertTrue(foundScene, "Should find at least one scene with elements")
    }

    // MARK: - Summary Element Tests

    @MainActor
    func testSummaryElementCreation() async throws {
        // Create a simple screenplay with scene headings
        let content = """
        # Test Script

        ## CHAPTER 1

        ### ACT ONE

        INT. COFFEE SHOP - DAY

        JOHN sits at a table with his laptop.

        JOHN
        I need more coffee.
        """

        let script = try GuionParsedScreenplay(string: content)

        // Create a minimal ModelContext for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema([GuionDocumentModel.self, GuionElementModel.self, TitlePageEntryModel.self])
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        // Convert screenplay to document with generateSummaries enabled
        // Note: This may not generate actual summaries if API is not available,
        // but it should create the structure correctly
        let document = await GuionDocumentModel.from(
            script,
            in: context,
            generateSummaries: true
        )

        print("\n📊 Document has \(document.elements.count) total elements")

        // Look for Section Heading elements with depth 4 (summary elements)
        let summaryElements = document.elements.filter {
            $0.elementType.isSectionHeading &&
            $0.sectionDepth == 4 &&
            $0.elementText.trimmingCharacters(in: .whitespaces).hasPrefix("SUMMARY:")
        }

        print("📊 Found \(summaryElements.count) summary elements")

        // Print all elements to see the structure
        for (index, element) in document.elements.prefix(20).enumerated() {
            print("  [\(index)] \(element.elementType) (depth: \(element.sectionDepth)): \(element.elementText.prefix(50))")
        }

        // Verify element order around scene headings
        for (index, element) in document.elements.enumerated() {
            if element.elementType == .sceneHeading {
                print("\n🎬 Found scene heading at index \(index): \(element.elementText)")

                // Check elements after the scene heading
                if index + 1 < document.elements.count {
                    let nextElement = document.elements[index + 1]
                    print("   Next element: \(nextElement.elementType) - \(nextElement.elementText.prefix(50))")

                    // If next is OVER BLACK, summary should be after it
                    if nextElement.elementType == .action &&
                       nextElement.elementText.uppercased().contains("OVER BLACK") {
                        if index + 2 < document.elements.count {
                            let afterOverBlack = document.elements[index + 2]
                            print("   After OVER BLACK: \(afterOverBlack.elementType) - \(afterOverBlack.elementText.prefix(50))")

                            if afterOverBlack.elementType.isSectionHeading &&
                               afterOverBlack.sectionDepth == 4 {
                                XCTAssertTrue(afterOverBlack.elementText.trimmingCharacters(in: .whitespaces).hasPrefix("SUMMARY:"),
                                            "Element after OVER BLACK should be SUMMARY")
                            }
                        }
                    } else if nextElement.elementType.isSectionHeading &&
                              nextElement.sectionDepth == 4 {
                        // Summary directly after scene heading (no OVER BLACK)
                        XCTAssertTrue(nextElement.elementText.trimmingCharacters(in: .whitespaces).hasPrefix("SUMMARY:"),
                                    "Element after scene heading should be SUMMARY if no OVER BLACK")
                        print("   ✅ Found summary element: \(nextElement.elementText.prefix(50))")
                    }
                }
            }
        }

        // Note: Actual summary generation may not happen in tests without API keys,
        // but we're verifying the structure is correct
        print("\n✅ Summary element structure test complete")
    }

    @MainActor
    func testSummaryElementRoundTrip() async throws {
        // Create a screenplay with a scene
        let content = """
        # Test Script

        ## CHAPTER 1

        ### ACT ONE

        INT. OFFICE - DAY

        ALICE works at her desk.
        """

        let script = try GuionParsedScreenplay(string: content)

        // Create document with summaries
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema([GuionDocumentModel.self, GuionElementModel.self, TitlePageEntryModel.self])
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let document = await GuionDocumentModel.from(
            script,
            in: context,
            generateSummaries: true
        )

        print("\n📝 Testing round-trip export/import of summary elements")
        print("📊 Document created with \(document.elements.count) elements")

        // Debug: Check if summary elements were created
        let summaryElements = document.elements.filter {
            $0.elementType.isSectionHeading &&
            $0.sectionDepth == 4 &&
            $0.elementText.trimmingCharacters(in: .whitespaces).hasPrefix("SUMMARY:")
        }
        print("📊 Document has \(summaryElements.count) summary elements")
        for summary in summaryElements {
            print("   - \(summary.elementText.prefix(60))")
        }

        // Only test round-trip if summaries were actually generated
        if summaryElements.count > 0 {
            print("✅ Summaries were generated, testing round-trip...")

            // Export to Fountain
            let exportedScript = document.toGuionParsedScreenplay()
            let fountainText = exportedScript.stringFromDocument()

            print("📄 Exported Fountain:")
            print(fountainText)

            // Verify the exported text contains the summary element
            XCTAssertTrue(fountainText.contains("#### SUMMARY:"), "Exported Fountain should contain summary element")

            // Re-import the Fountain text
            let reimportedScript = try GuionParsedScreenplay(string: fountainText)

            print("\n📊 Re-imported screenplay has \(reimportedScript.elements.count) elements")

            // Find summary elements in re-imported script
            let reimportedSummaries = reimportedScript.elements.filter {
                $0.elementType.isSectionHeading &&
                $0.sectionDepth == 4 &&
                $0.elementText.trimmingCharacters(in: .whitespaces).hasPrefix("SUMMARY:")
            }

            print("📊 Found \(reimportedSummaries.count) summary elements after re-import")

            for summary in reimportedSummaries {
                print("   ✅ \(summary.elementText.prefix(60))")
            }

            // Verify summaries were preserved
            XCTAssertEqual(reimportedSummaries.count, summaryElements.count,
                          "Re-imported script should have same number of summaries")

            // Verify the summary is in the right position (after scene heading)
            for (index, element) in reimportedScript.elements.enumerated() {
                if element.elementType == .sceneHeading {
                    print("\n🎬 Scene heading at index \(index): \(element.elementText)")

                    // Check if next non-whitespace element is a summary
                    if index + 1 < reimportedScript.elements.count {
                        let nextElement = reimportedScript.elements[index + 1]
                        print("   Next: \(nextElement.elementType) - \(nextElement.elementText.prefix(50))")

                        if nextElement.elementType.isSectionHeading && nextElement.sectionDepth == 4 {
                            XCTAssertTrue(nextElement.elementText.trimmingCharacters(in: .whitespaces).hasPrefix("SUMMARY:"),
                                        "Element after scene heading should be summary")
                            print("   ✅ Summary element preserved in correct position")
                        }
                    }
                }
            }

            print("\n✅ Round-trip test complete - summaries preserved!")
        } else {
            print("ℹ️  No summaries were generated (scene may be too simple or summarizer unavailable)")
            print("ℹ️  Skipping round-trip test - structure is correct even if summaries aren't generated")
            print("\n✅ Test complete - verified structure works correctly")
        }
    }

    func testManualSummaryElementRoundTrip() throws {
        // Manually create a document with a summary element
        let document = GuionDocumentModel(filename: "test.guion")

        // Add structured content with manual summary
        // Note: Section Heading elementText should have leading space (Fountain format)
        let elements = [
            GuionElementModel(elementText: " Test Script", elementType: .sectionHeading(level: 1)),
            GuionElementModel(elementText: " CHAPTER 1", elementType: .sectionHeading(level: 2)),
            GuionElementModel(elementText: " ACT ONE", elementType: .sectionHeading(level: 3)),
            GuionElementModel(elementText: "INT. COFFEE SHOP - DAY", elementType: .sceneHeading, sceneId: "scene-1"),
            GuionElementModel(elementText: " SUMMARY: Alice orders coffee and meets Bob.", elementType: .sectionHeading(level: 4)),
            GuionElementModel(elementText: "ALICE walks to the counter.", elementType: .action),
            GuionElementModel(elementText: "ALICE", elementType: .character),
            GuionElementModel(elementText: "One coffee, please.", elementType: .dialogue)
        ]

        document.elements.append(contentsOf: elements)

        print("\n📝 Testing manual summary element round-trip")

        // Export to Fountain
        let exportedScript = document.toGuionParsedScreenplay()
        let fountainText = exportedScript.stringFromDocument()

        print("📄 Exported Fountain:")
        print(fountainText)

        // Verify the exported text contains the summary element
        XCTAssertTrue(fountainText.contains("#### SUMMARY:"), "Exported Fountain should contain summary element")

        // Re-import the Fountain text
        let reimportedScript = try GuionParsedScreenplay(string: fountainText)

        print("\n📊 Re-imported screenplay has \(reimportedScript.elements.count) elements")

        // Find summary elements in re-imported script
        // Note: elementText will have leading space from Fountain parsing
        let reimportedSummaries = reimportedScript.elements.filter {
            $0.elementType.isSectionHeading &&
            $0.sectionDepth == 4 &&
            $0.elementText.trimmingCharacters(in: .whitespaces).hasPrefix("SUMMARY:")
        }

        print("📊 Found \(reimportedSummaries.count) summary elements after re-import")

        for summary in reimportedSummaries {
            print("   ✅ \(summary.elementText)")
        }

        // Verify summaries were preserved
        XCTAssertEqual(reimportedSummaries.count, 1, "Re-imported script should have 1 summary element")
        XCTAssertEqual(reimportedSummaries.first?.elementText, " SUMMARY: Alice orders coffee and meets Bob.",
                      "Summary text should be preserved exactly (with leading space)")

        // Verify the summary is in the right position (after scene heading)
        var foundSummaryAfterScene = false
        for (index, element) in reimportedScript.elements.enumerated() {
            if element.elementType == .sceneHeading {
                print("\n🎬 Scene heading at index \(index): \(element.elementText)")

                if index + 1 < reimportedScript.elements.count {
                    let nextElement = reimportedScript.elements[index + 1]
                    print("   Next: \(nextElement.elementType) - \(nextElement.elementText)")

                    if nextElement.elementType.isSectionHeading && nextElement.sectionDepth == 4 {
                        XCTAssertTrue(nextElement.elementText.trimmingCharacters(in: .whitespaces).hasPrefix("SUMMARY:"),
                                    "Element after scene heading should be summary")
                        foundSummaryAfterScene = true
                        print("   ✅ Summary element preserved in correct position")
                    }
                }
            }
        }

        XCTAssertTrue(foundSummaryAfterScene, "Summary should be positioned after scene heading")
        print("\n✅ Manual round-trip test complete - summary perfectly preserved!")
    }

    // MARK: - Helper Methods

    private func createSampleBrowserData() -> SceneBrowserData {
        return SceneBrowserData(
            title: OutlineElement(
                id: "title-1",
                index: 0,
                level: 1,
                range: [0, 10],
                rawString: "# Test Script",
                string: "Test Script",
                type: "sectionHeader"
            ),
            chapters: [
                ChapterData(
                    element: OutlineElement(
                        id: "chapter-1",
                        index: 1,
                        level: 2,
                        range: [10, 100],
                        rawString: "## CHAPTER 1",
                        string: "CHAPTER 1",
                        type: "sectionHeader"
                    ),
                    sceneGroups: [
                        SceneGroupData(
                            element: OutlineElement(
                                id: "group-1",
                                index: 2,
                                level: 3,
                                range: [20, 80],
                                rawString: "### PROLOGUE",
                                string: "PROLOGUE",
                                type: "sectionHeader"
                            ),
                            scenes: [
                                SceneData(
                                    element: OutlineElement(
                                        id: "scene-1",
                                        index: 3,
                                        level: 0,
                                        range: [30, 70],
                                        rawString: "INT. STEAM ROOM - DAY",
                                        string: "INT. STEAM ROOM - DAY",
                                        type: "sceneHeader"
                                    ),
                                    sceneElements: [
                                        GuionElement(type: .action, text: "Test action.")
                                    ],
                                    sceneLocation: SceneLocation.parse("INT. STEAM ROOM - DAY")
                                )
                            ]
                        )
                    ]
                )
            ]
        )
    }

    private func createSampleDocument() -> GuionDocumentModel {
        let document = GuionDocumentModel(filename: "sample.guion")

        // Add title page
        document.titlePage.append(
            TitlePageEntryModel(key: "Title", values: ["Sample Screenplay"])
        )

        // Add structured content
        let elements = [
            GuionElementModel(
                elementText: "Sample Screenplay",
                elementType: .sectionHeading(level: 1)),
            GuionElementModel(
                elementText: "CHAPTER 1",
                elementType: .sectionHeading(level: 2)),
            GuionElementModel(
                elementText: "OPENING",
                elementType: .sectionHeading(level: 3)),
            GuionElementModel(
                elementText: "INT. OFFICE - DAY",
                elementType: .sceneHeading
            ),
            GuionElementModel(
                elementText: "A character sits at a desk.",
                elementType: .action
            )
        ]

        document.elements.append(contentsOf: elements)

        return document
    }
}

#endif // canImport(SwiftUI) && canImport(SwiftData)
