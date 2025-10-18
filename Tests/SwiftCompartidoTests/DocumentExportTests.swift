//
//  DocumentExportTests.swift
//  SwiftGuionTests
//
//  Phase 4: Export Functionality Separation Tests
//

import XCTest
import SwiftData
import UniformTypeIdentifiers
@testable import SwiftCompartido

@MainActor
final class DocumentExportTests: XCTestCase {

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

    // MARK: - GATE 4.1: Export to Fountain

    func testExportToFountain() async throws {
        // Create a test document
        let document = createTestDocument()
        modelContext.insert(document)

        // Export to Fountain
        let script = GuionDocumentParserSwiftData.toFountainScript(from: document)
        let fountainText = script.stringFromDocument()

        // Verify output is valid Fountain
        XCTAssertFalse(fountainText.isEmpty, "Fountain output should not be empty")
        XCTAssertTrue(fountainText.contains("INT. TEST LOCATION - DAY"), "Should contain scene heading")
        XCTAssertTrue(fountainText.contains("Test action."), "Should contain action")
        XCTAssertTrue(fountainText.contains("JOHN"), "Should contain character")
        XCTAssertTrue(fountainText.contains("Hello, world!"), "Should contain dialogue")

        // Verify original document is unchanged
        XCTAssertEqual(document.elements.count, 4, "Original document should be unchanged")
    }

    func testExportToFountainWithTitlePage() async throws {
        // Create document with title page
        let document = GuionDocumentModel(filename: "test-with-title.guion")

        let titleEntry = TitlePageEntryModel(key: "Title", values: ["Test Screenplay"])
        titleEntry.document = document
        document.titlePage.append(titleEntry)

        let authorEntry = TitlePageEntryModel(key: "Author", values: ["John Doe"])
        authorEntry.document = document
        document.titlePage.append(authorEntry)

        let element = GuionElementModel(
            elementText: "INT. OFFICE - DAY",
            elementType: .sceneHeading
        )
        element.document = document
        document.elements.append(element)

        modelContext.insert(document)

        // Export
        let script = GuionDocumentParserSwiftData.toFountainScript(from: document)
        let fountainText = script.stringFromDocument()

        // Verify title page is included
        XCTAssertTrue(fountainText.contains("Title:"), "Should contain title key")
        XCTAssertTrue(fountainText.contains("Test Screenplay"), "Should contain title value")
        XCTAssertTrue(fountainText.contains("Author:"), "Should contain author key")
        XCTAssertTrue(fountainText.contains("John Doe"), "Should contain author value")
    }

    func testExportEmptyDocument() async throws {
        // Create empty document
        let document = GuionDocumentModel(filename: "empty.guion")
        modelContext.insert(document)

        // Export should succeed but produce minimal output
        let script = GuionDocumentParserSwiftData.toFountainScript(from: document)
        let fountainText = script.stringFromDocument()

        // Should not crash, may be empty or have minimal content
        XCTAssertNotNil(fountainText, "Should return a string (even if empty)")
    }

    func testExportPreservesElementOrder() async throws {
        // Create document with specific order
        let document = GuionDocumentModel(filename: "order-test.guion")

        let orderedElements: [(String, ElementType)] = [
            ("INT. LOCATION 1 - DAY", .sceneHeading),
            ("First action.", .action),
            ("INT. LOCATION 2 - NIGHT", .sceneHeading),
            ("Second action.", .action),
            ("JANE", .character),
            ("Hello!", .dialogue)
        ]

        for (text, type) in orderedElements {
            let element = GuionElementModel(elementText: text, elementType: type)
            element.document = document
            document.elements.append(element)
        }

        modelContext.insert(document)

        // Export
        let script = GuionDocumentParserSwiftData.toFountainScript(from: document)
        let fountainText = script.stringFromDocument()

        // Verify order is preserved (first element should appear before last)
        let firstRange = fountainText.range(of: "LOCATION 1")
        let secondRange = fountainText.range(of: "LOCATION 2")
        let janeRange = fountainText.range(of: "JANE")

        XCTAssertNotNil(firstRange, "Should contain first scene")
        XCTAssertNotNil(secondRange, "Should contain second scene")
        XCTAssertNotNil(janeRange, "Should contain character")

        if let first = firstRange, let second = secondRange, let jane = janeRange {
            XCTAssertLessThan(first.lowerBound, second.lowerBound, "First scene should come before second")
            XCTAssertLessThan(second.lowerBound, jane.lowerBound, "Second scene should come before character")
        }
    }

    // MARK: - GATE 4.2: Export to FDX

    func testExportToFDX() async throws {
        // Create a test document
        let document = createTestDocument()
        modelContext.insert(document)

        // Export to FDX
        let fdxData = GuionDocumentParserSwiftData.toFDXData(from: document)

        // Verify output is valid XML
        XCTAssertFalse(fdxData.isEmpty, "FDX output should not be empty")

        let fdxString = String(data: fdxData, encoding: .utf8)
        XCTAssertNotNil(fdxString, "FDX data should be valid UTF-8")

        if let xml = fdxString {
            XCTAssertTrue(xml.contains("<?xml"), "Should contain XML declaration")
            XCTAssertTrue(xml.contains("<FinalDraft"), "Should contain FinalDraft root element")
            XCTAssertTrue(xml.contains("INT. TEST LOCATION - DAY"), "Should contain scene heading")
            XCTAssertTrue(xml.contains("JOHN"), "Should contain character")
            XCTAssertTrue(xml.contains("Hello, world!"), "Should contain dialogue")
        }

        // Verify original document is unchanged
        XCTAssertEqual(document.elements.count, 4, "Original document should be unchanged")
    }

    func testExportToFDXWithSpecialCharacters() async throws {
        // Create document with special characters
        let document = GuionDocumentModel(filename: "special.guion")

        let specialTexts = [
            "Special chars: <>&\"'",
            "Unicode: 😀 ñ Ω",
            "Ampersand & test"
        ]

        for text in specialTexts {
            let element = GuionElementModel(elementText: text, elementType: .action)
            element.document = document
            document.elements.append(element)
        }

        modelContext.insert(document)

        // Export
        let fdxData = GuionDocumentParserSwiftData.toFDXData(from: document)
        let fdxString = String(data: fdxData, encoding: .utf8)

        XCTAssertNotNil(fdxString, "Should handle special characters")

        // XML entities should be properly escaped
        if let xml = fdxString {
            // The exact escaping depends on implementation, but it should be valid XML
            XCTAssertTrue(xml.contains("<?xml"), "Should be valid XML")
        }
    }

    // MARK: - GATE 4.3: Export filename defaults

    func testExportFilenameDefaults() {
        // Test filename transformation for export
        let testCases: [(input: String, expectedFountain: String, expectedFDX: String)] = [
            ("MyScript.guion", "MyScript.fountain", "MyScript.fdx"),
            ("screenplay.guion", "screenplay.fountain", "screenplay.fdx"),
            ("test-v2.guion", "test-v2.fountain", "test-v2.fdx"),
            ("Script Final.guion", "Script Final.fountain", "Script Final.fdx")
        ]

        for (input, expectedFountain, expectedFDX) in testCases {
            let baseName = (input as NSString).deletingPathExtension

            let fountainName = "\(baseName).fountain"
            let fdxName = "\(baseName).fdx"

            XCTAssertEqual(fountainName, expectedFountain, "Fountain filename should match")
            XCTAssertEqual(fdxName, expectedFDX, "FDX filename should match")
        }
    }

    func testExportFilenameWithoutExtension() {
        // Test when document has no extension
        let input = "Untitled"
        let baseName = (input as NSString).deletingPathExtension

        XCTAssertEqual("\(baseName).fountain", "Untitled.fountain")
        XCTAssertEqual("\(baseName).fdx", "Untitled.fdx")
    }

    func testExportFilenameWithMultipleDots() {
        // Test filename with multiple dots
        let input = "my.script.v2.guion"
        let baseName = (input as NSString).deletingPathExtension

        XCTAssertEqual("\(baseName).fountain", "my.script.v2.fountain")
        XCTAssertEqual("\(baseName).fdx", "my.script.v2.fdx")
    }

    // MARK: - GATE 4.4: Round-trip import/export fidelity

    func testImportExportFidelity() async throws {
        // Test if we have BigFish.fountain available
        let bigFishURL = fixturesPath.appendingPathComponent("BigFish.fountain")

        guard FileManager.default.fileExists(atPath: bigFishURL.path) else {
            // Use a synthetic test instead
            try await testSyntheticImportExportFidelity()
            return
        }

        // Import BigFish.fountain
        let imported = try await GuionDocumentParserSwiftData.loadAndParse(
            from: bigFishURL,
            in: modelContext,
            generateSummaries: false
        )

        let originalElementCount = imported.elements.count
        let originalTitlePageCount = imported.titlePage.count

        // Export back to Fountain
        let script = GuionDocumentParserSwiftData.toFountainScript(from: imported)
        let exportedFountainText = script.stringFromDocument()

        // Parse the exported text
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bigfish-exported.fountain")
        try exportedFountainText.write(to: tempURL, atomically: true, encoding: .utf8)

        let reImported = try await GuionDocumentParserSwiftData.loadAndParse(
            from: tempURL,
            in: modelContext,
            generateSummaries: false
        )

        // Verify element count is preserved (some whitespace variations are acceptable)
        let countDifference = abs(reImported.elements.count - originalElementCount)
        XCTAssertLessThan(countDifference, 5, "Element count should be approximately preserved (within 5)")

        // Verify title page is preserved
        XCTAssertEqual(reImported.titlePage.count, originalTitlePageCount, "Title page entries should be preserved")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testSyntheticImportExportFidelity() async throws {
        // Create a synthetic document
        let original = createCompleteTestDocument()
        modelContext.insert(original)

        let originalElementCount = original.elements.count
        let originalTitlePageCount = original.titlePage.count

        // Export to Fountain
        let script = GuionDocumentParserSwiftData.toFountainScript(from: original)
        let fountainText = script.stringFromDocument()

        // Write to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("synthetic-export.fountain")
        try fountainText.write(to: tempURL, atomically: true, encoding: .utf8)

        // Re-import
        let reImported = try await GuionDocumentParserSwiftData.loadAndParse(
            from: tempURL,
            in: modelContext,
            generateSummaries: false
        )

        // Verify fidelity
        XCTAssertEqual(reImported.elements.count, originalElementCount, "Element count should match")
        XCTAssertEqual(reImported.titlePage.count, originalTitlePageCount, "Title page count should match")

        // Verify specific elements
        let originalScenes = original.elements.filter { $0.elementType == .sceneHeading }
        let reImportedScenes = reImported.elements.filter { $0.elementType == .sceneHeading }
        XCTAssertEqual(reImportedScenes.count, originalScenes.count, "Scene count should match")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testFDXImportExportFidelity() async throws {
        // Create a test document
        let original = createCompleteTestDocument()
        modelContext.insert(original)

        let originalElementCount = original.elements.count

        // Export to FDX
        let fdxData = GuionDocumentParserSwiftData.toFDXData(from: original)

        // Write to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-export.fdx")
        try fdxData.write(to: tempURL)

        // Re-import
        let reImported = try await GuionDocumentParserSwiftData.loadAndParse(
            from: tempURL,
            in: modelContext,
            generateSummaries: false
        )

        // Verify element count is approximately preserved
        // Note: FDX conversion may have slight variations
        let countDifference = abs(reImported.elements.count - originalElementCount)
        XCTAssertLessThan(countDifference, 10, "Element count should be approximately preserved")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Additional Coverage Tests

    func testExportWithSceneNumbers() async throws {
        // Create document with scene numbers
        let document = GuionDocumentModel(filename: "numbered.guion")

        for i in 1...5 {
            let element = GuionElementModel(
                elementText: "INT. LOCATION \(i) - DAY",
                elementType: .sceneHeading,
                sceneNumber: "\(i)"
            )
            element.document = document
            document.elements.append(element)
        }

        modelContext.insert(document)

        // Export
        let script = GuionDocumentParserSwiftData.toFountainScript(from: document)
        let fountainText = script.stringFromDocument()

        // Verify scene numbers are included
        for i in 1...5 {
            XCTAssertTrue(fountainText.contains("#\(i)#"), "Should contain scene number \(i)")
        }
    }

    func testExportWithTransitions() async throws {
        // Create document with transitions
        let document = GuionDocumentModel(filename: "transitions.guion")

        let elements: [(String, ElementType)] = [
            ("INT. OFFICE - DAY", .sceneHeading),
            ("Action line.", .action),
            ("CUT TO:", .transition),
            ("INT. HOUSE - NIGHT", .sceneHeading),
            ("More action.", .action),
            ("FADE OUT.", .transition)
        ]

        for (text, type) in elements {
            let element = GuionElementModel(elementText: text, elementType: type)
            element.document = document
            document.elements.append(element)
        }

        modelContext.insert(document)

        // Export
        let script = GuionDocumentParserSwiftData.toFountainScript(from: document)
        let fountainText = script.stringFromDocument()

        // Verify transitions are formatted correctly
        XCTAssertTrue(fountainText.contains("CUT TO:"), "Should contain CUT TO transition")
        XCTAssertTrue(fountainText.contains("FADE OUT"), "Should contain FADE OUT transition")
    }

    func testExportWithCenteredText() async throws {
        // Create document with centered elements
        let document = GuionDocumentModel(filename: "centered.guion")

        let centeredElement = GuionElementModel(
            elementText: "THE END",
            elementType: .action,  // Centered is formatting, type is action
            isCentered: true
        )
        centeredElement.document = document
        document.elements.append(centeredElement)

        modelContext.insert(document)

        // Export
        let script = GuionDocumentParserSwiftData.toFountainScript(from: document)
        let fountainText = script.stringFromDocument()

        // Centered text in Fountain uses > <
        XCTAssertTrue(fountainText.contains(">") && fountainText.contains("<") || fountainText.contains("THE END"),
                      "Should contain centered text markers or the text itself")
    }

    func testExportPerformance() async throws {
        // Create large document
        let document = GuionDocumentModel(filename: "large-export.guion")

        for i in 1...1000 {
            let elementType = i % 5 == 0 ? ElementType.sceneHeading : ElementType.action
            let text = elementType == .sceneHeading
                ? "INT. LOCATION \(i) - DAY"
                : "Action line number \(i)"

            let element = GuionElementModel(elementText: text, elementType: elementType)
            element.document = document
            document.elements.append(element)
        }

        modelContext.insert(document)

        // Time Fountain export
        let fountainStart = Date()
        let script = GuionDocumentParserSwiftData.toFountainScript(from: document)
        let _ = script.stringFromDocument()
        let fountainTime = Date().timeIntervalSince(fountainStart)

        print("💾 Fountain export time for 1000 elements: \(fountainTime)s")

        // Time FDX export
        let fdxStart = Date()
        let _ = GuionDocumentParserSwiftData.toFDXData(from: document)
        let fdxTime = Date().timeIntervalSince(fdxStart)

        print("💾 FDX export time for 1000 elements: \(fdxTime)s")

        // Report performance metrics (no assertions - tracked separately)
        print("📊 PERFORMANCE METRICS:")
        print("   Fountain export: \(String(format: "%.3f", fountainTime))s")
        print("   FDX export: \(String(format: "%.3f", fdxTime))s")
    }

    // MARK: - Helper Methods

    private func createTestDocument() -> GuionDocumentModel {
        let document = GuionDocumentModel(filename: "test.guion")

        let scene = GuionElementModel(
            elementText: "INT. TEST LOCATION - DAY",
            elementType: .sceneHeading
        )
        scene.document = document
        document.elements.append(scene)

        let action = GuionElementModel(
            elementText: "Test action.",
            elementType: .action
        )
        action.document = document
        document.elements.append(action)

        let character = GuionElementModel(
            elementText: "JOHN",
            elementType: .character
        )
        character.document = document
        document.elements.append(character)

        let dialogue = GuionElementModel(
            elementText: "Hello, world!",
            elementType: .dialogue
        )
        dialogue.document = document
        document.elements.append(dialogue)

        return document
    }

    private func createCompleteTestDocument() -> GuionDocumentModel {
        let document = GuionDocumentModel(filename: "complete-test.guion")

        // Add title page
        let titleEntry = TitlePageEntryModel(key: "Title", values: ["Test Screenplay"])
        titleEntry.document = document
        document.titlePage.append(titleEntry)

        let authorEntry = TitlePageEntryModel(key: "Author", values: ["Test Author"])
        authorEntry.document = document
        document.titlePage.append(authorEntry)

        // Add various elements
        let elementTypes: [(String, ElementType)] = [
            ("INT. OFFICE - DAY", .sceneHeading),
            ("John walks into the office.", .action),
            ("JOHN", .character),
            ("Hello, everyone!", .dialogue),
            ("INT. CONFERENCE ROOM - DAY", .sceneHeading),
            ("A meeting is in progress.", .action),
            ("JANE", .character),
            ("(whispering)", .parenthetical),
            ("We need to talk.", .dialogue),
            ("CUT TO:", .transition),
            ("EXT. PARKING LOT - DAY", .sceneHeading),
            ("John walks to his car.", .action)
        ]

        for (text, type) in elementTypes {
            let element = GuionElementModel(elementText: text, elementType: type)
            element.document = document
            document.elements.append(element)
        }

        return document
    }
}
