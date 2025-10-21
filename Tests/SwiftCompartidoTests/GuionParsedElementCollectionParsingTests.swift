//
//  GuionParsedElementCollectionParsingTests.swift
//  SwiftCompartido
//
//  Copyright (c) 2025
//
//  Comprehensive tests for GuionParsedElementCollection parsing all supported file formats.
//

import Testing
import Foundation
import SwiftFijos
@testable import SwiftCompartido

/// Tests for GuionParsedElementCollection parsing all supported screenplay formats
///
/// This test suite ensures that GuionParsedElementCollection can successfully parse:
/// - Fountain files (.fountain)
/// - Highland bundles (.highland)
/// - TextBundle files (.textbundle)
/// - Fountain strings (in-memory)
///
/// Note: FDX files are not directly supported by GuionParsedElementCollection.
/// They should be parsed via GuionDocumentParserSwiftData.loadAndParse() instead.
@Suite("GuionParsedElementCollection Format Parsing Tests")
struct GuionParsedElementCollectionParsingTests {

    // MARK: - Fountain File Parsing

    @Test("Parse Fountain file synchronously")
    func testParseFountainFileSync() throws {
        let url = try Fijos.getFixture("bigfish", extension: "fountain")

        // Synchronous parsing
        let screenplay = try GuionParsedElementCollection(file: url.path)

        #expect(screenplay.elements.count > 0, "Should parse elements from Fountain file")
        #expect(screenplay.filename == "bigfish.fountain", "Should preserve filename")

        // Verify we have expected element types
        let sceneHeadings = screenplay.elements.filter { $0.elementType == .sceneHeading }
        #expect(sceneHeadings.count > 0, "Should have scene headings")
    }

    @Test("Parse Fountain file asynchronously")
    func testParseFountainFileAsync() async throws {
        let url = try Fijos.getFixture("bigfish", extension: "fountain")

        // Async parsing without progress
        let screenplay = try await GuionParsedElementCollection(file: url.path)

        #expect(screenplay.elements.count > 0, "Should parse elements from Fountain file")
        #expect(screenplay.filename == "bigfish.fountain", "Should preserve filename")

        // Verify title page if present
        if !screenplay.titlePage.isEmpty {
            #expect(screenplay.titlePage.count > 0, "Should parse title page")
        }
    }

    @Test("Parse Fountain file with progress")
    func testParseFountainFileWithProgress() async throws {
        let url = try Fijos.getFixture("bigfish", extension: "fountain")

        actor ProgressCollector {
            var updateCount: Int = 0
            var lastDescription: String = ""

            func recordUpdate(_ description: String) {
                updateCount += 1
                lastDescription = description
            }

            func getStats() -> (count: Int, lastDesc: String) {
                return (updateCount, lastDescription)
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.recordUpdate(update.description)
            }
        }

        let screenplay = try await GuionParsedElementCollection(
            file: url.path,
            progress: progress
        )

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let stats = await collector.getStats()

        #expect(screenplay.elements.count > 0, "Should parse elements")
        #expect(stats.count > 0, "Should receive progress updates")
    }

    // MARK: - Fountain String Parsing

    @Test("Parse Fountain string synchronously")
    func testParseFountainStringSync() throws {
        let fountainText = """
        Title: Test Screenplay
        Author: Test Author

        FADE IN:

        INT. COFFEE SHOP - DAY

        SARAH sits at a table, typing on her laptop.

        SARAH
        (muttering)
        This is going to work.

        JOHN enters and approaches her table.

        JOHN
        Sarah! I thought I'd find you here.

        FADE OUT.
        """

        let screenplay = try GuionParsedElementCollection(string: fountainText)

        #expect(screenplay.elements.count > 0, "Should parse elements from string")
        #expect(screenplay.filename == nil, "String parsing should have no filename")

        // Verify we got various element types
        let sceneHeadings = screenplay.elements.filter { $0.elementType == .sceneHeading }
        let characters = screenplay.elements.filter { $0.elementType == .character }
        let dialogue = screenplay.elements.filter { $0.elementType == .dialogue }
        let actions = screenplay.elements.filter { $0.elementType == .action }

        #expect(sceneHeadings.count > 0, "Should have scene headings")
        #expect(characters.count > 0, "Should have characters")
        #expect(dialogue.count > 0, "Should have dialogue")
        #expect(actions.count > 0, "Should have action lines")

        // Verify title page
        #expect(!screenplay.titlePage.isEmpty, "Should parse title page")
    }

    @Test("Parse Fountain string asynchronously")
    func testParseFountainStringAsync() async throws {
        let fountainText = """
        Title: Async Test

        INT. ROOM - NIGHT

        A simple test screenplay.
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)

        #expect(screenplay.elements.count > 0, "Should parse elements")
        #expect(!screenplay.titlePage.isEmpty, "Should parse title page")
    }

    @Test("Parse Fountain string with progress")
    func testParseFountainStringWithProgress() async throws {
        let fountainText = """
        Title: Progress Test

        """ + (1...100).map { "INT. LOCATION \($0) - DAY\n\nAction line \($0).\n" }.joined()

        actor ProgressCollector {
            var finalFraction: Double = 0.0

            func recordFraction(_ fraction: Double?) {
                if let f = fraction {
                    finalFraction = max(finalFraction, f)
                }
            }

            func getFraction() -> Double {
                return finalFraction
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.recordFraction(update.fractionCompleted)
            }
        }

        let screenplay = try await GuionParsedElementCollection(
            string: fountainText,
            progress: progress
        )

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let finalFraction = await collector.getFraction()

        #expect(screenplay.elements.count > 0, "Should parse elements")
        #expect(finalFraction > 0.0, "Should have progress")
    }

    // MARK: - Highland File Parsing

    @Test("Parse Highland file if available")
    func testParseHighlandFile() async throws {
        // Highland files may not be available in all test environments
        // This test will skip if the fixture is not found

        do {
            let url = try Fijos.getFixture("bigfish", extension: "highland")

            // Highland files are ZIP archives containing TextBundles
            let screenplay = try GuionParsedElementCollection(highland: url)

            #expect(screenplay.elements.count > 0, "Should parse elements from Highland file")

            // Verify we have screenplay content
            let sceneHeadings = screenplay.elements.filter { $0.elementType == .sceneHeading }
            #expect(sceneHeadings.count > 0, "Highland file should contain scenes")

        } catch {
            // If fixture not found, that's okay - Highland support is still tested
            // via the extension logic, just not with real data
            Issue.record("Highland fixture not available: \(error)")
        }
    }

    @Test("Highland extension supports plain Fountain files")
    func testHighlandPlainFountainFile() async throws {
        // Some .highland files are actually plain Fountain text files
        // Create a temporary .highland file that's actually Fountain
        let fountainText = """
        Title: Highland Test

        INT. ROOM - DAY

        Plain fountain file with .highland extension.
        """

        let tempDir = FileManager.default.temporaryDirectory
        let highlandURL = tempDir.appendingPathComponent("test.highland")

        try fountainText.write(to: highlandURL, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: highlandURL)
        }

        // Should parse as Fountain file
        let screenplay = try GuionParsedElementCollection(highland: highlandURL)

        #expect(screenplay.elements.count > 0, "Should parse plain Fountain .highland file")
        #expect(!screenplay.titlePage.isEmpty, "Should have title page")
    }

    // MARK: - TextBundle File Parsing

    @Test("Parse TextBundle file if available")
    func testParseTextBundleFile() async throws {
        // Create a test TextBundle programmatically
        let fountainText = """
        Title: TextBundle Test
        Author: Test Suite

        INT. TESTING LAB - DAY

        SCIENTIST examines the TextBundle format.

        SCIENTIST
        This format works!
        """

        let tempDir = FileManager.default.temporaryDirectory
        let bundleURL = tempDir.appendingPathComponent("test.textbundle")

        // Create textbundle directory structure
        try FileManager.default.createDirectory(
            at: bundleURL,
            withIntermediateDirectories: true
        )

        // Write fountain file inside the bundle
        let fountainURL = bundleURL.appendingPathComponent("screenplay.fountain")
        try fountainText.write(to: fountainURL, atomically: true, encoding: .utf8)

        // Write info.json
        let infoJSON = """
        {
            "version": 2,
            "type": "net.daringfireball.markdown",
            "creatorIdentifier": "com.test.swiftcompartido"
        }
        """
        let infoURL = bundleURL.appendingPathComponent("info.json")
        try infoJSON.write(to: infoURL, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        // Parse the TextBundle
        let screenplay = try GuionParsedElementCollection(textBundle: bundleURL)

        #expect(screenplay.elements.count > 0, "Should parse elements from TextBundle")
        #expect(!screenplay.titlePage.isEmpty, "Should have title page")

        let characters = screenplay.elements.filter { $0.elementType == .character }
        #expect(characters.count > 0, "Should parse character elements")
    }

    @Test("TextBundle with .md file instead of .fountain")
    func testTextBundleWithMarkdownFile() async throws {
        let fountainText = """
        Title: Markdown Test

        INT. ROOM - DAY

        Testing markdown extension support.
        """

        let tempDir = FileManager.default.temporaryDirectory
        let bundleURL = tempDir.appendingPathComponent("test-md.textbundle")

        try FileManager.default.createDirectory(
            at: bundleURL,
            withIntermediateDirectories: true
        )

        // Write .md file (some TextBundles use .md extension)
        let mdURL = bundleURL.appendingPathComponent("screenplay.md")
        try fountainText.write(to: mdURL, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        // Should find and parse the .md file
        let screenplay = try GuionParsedElementCollection(textBundle: bundleURL)

        #expect(screenplay.elements.count > 0, "Should parse .md file from TextBundle")
    }

    // MARK: - Empty and Edge Cases

    @Test("Parse empty Fountain string")
    func testParseEmptyString() async throws {
        let screenplay = try await GuionParsedElementCollection(string: "")

        #expect(screenplay.elements.count == 0, "Empty string should have no elements")
        #expect(screenplay.titlePage.isEmpty, "Empty string should have no title page")
    }

    @Test("Parse Fountain string with only title page")
    func testParseTitlePageOnly() async throws {
        let fountainText = """
        Title: Only Title
        Author: Test Author
        Draft date: 2025-10-20
        Contact: test@example.com
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)

        #expect(!screenplay.titlePage.isEmpty, "Should parse title page")
        // May or may not have elements depending on parser behavior
    }

    @Test("Parse Fountain string with Unicode characters")
    func testParseUnicodeContent() async throws {
        let fountainText = """
        Title: Unicode Test

        INT. CAFÉ - DAY

        JOSÉ sits reading a book titled "東京物語".

        JOSÉ
        (en español)
        ¡Hola! Comment ça va? 你好！
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)

        #expect(screenplay.elements.count > 0, "Should parse Unicode content")

        // Find the dialogue with Unicode
        let dialogue = screenplay.elements.first { $0.elementType == .dialogue }
        #expect(dialogue != nil, "Should have dialogue element")
        #expect(dialogue?.elementText.contains("¡Hola!") ?? false, "Should preserve Unicode characters")
    }

    // MARK: - Parser Type Selection

    @Test("Parse with fast parser (default)")
    func testParseFastParser() throws {
        let fountainText = "Title: Fast Parser Test\n\nINT. ROOM - DAY"

        let screenplay = try GuionParsedElementCollection(
            string: fountainText,
            parser: .fast
        )

        #expect(screenplay.elements.count > 0, "Fast parser should work")
    }

    @Test("Parse with regex parser")
    func testParseRegexParser() throws {
        let fountainText = "Title: Regex Parser Test\n\nINT. ROOM - DAY"

        let screenplay = try GuionParsedElementCollection(
            string: fountainText,
            parser: .regex
        )

        #expect(screenplay.elements.count > 0, "Regex parser should work")
    }

    // MARK: - Error Cases

    @Test("Parse nonexistent file throws error")
    func testParseNonexistentFile() async throws {
        let nonexistentPath = "/tmp/nonexistent-screenplay-\(UUID()).fountain"

        #expect(throws: Error.self) {
            try GuionParsedElementCollection(file: nonexistentPath)
        }
    }

    @Test("Parse TextBundle with no content file throws error")
    func testTextBundleNoContentFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let bundleURL = tempDir.appendingPathComponent("empty.textbundle")

        try FileManager.default.createDirectory(
            at: bundleURL,
            withIntermediateDirectories: true
        )

        // Write info.json but no content file
        let infoJSON = """
        {
            "version": 2,
            "type": "net.daringfireball.markdown"
        }
        """
        let infoURL = bundleURL.appendingPathComponent("info.json")
        try infoJSON.write(to: infoURL, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        #expect(throws: FountainTextBundleError.self) {
            try GuionParsedElementCollection(textBundle: bundleURL)
        }
    }

    // MARK: - Integration with Extensions

    @Test("Parsed screenplay supports character extraction")
    func testCharacterExtractionFromParsed() async throws {
        let fountainText = """
        INT. OFFICE - DAY

        ALICE
        Hello!

        BOB
        Hi there!

        ALICE
        How are you?
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let characters = screenplay.extractCharacters()

        #expect(characters.count > 0, "Should extract characters")
        #expect(characters["ALICE"] != nil, "Should find ALICE")
        #expect(characters["BOB"] != nil, "Should find BOB")
    }

    @Test("Parsed screenplay contains scene headings for location parsing")
    func testSceneHeadingsFromParsed() async throws {
        let fountainText = """
        INT. COFFEE SHOP - DAY

        Action.

        EXT. PARK - NIGHT

        More action.
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let sceneHeadings = screenplay.elements.filter { $0.elementType == .sceneHeading }

        #expect(sceneHeadings.count > 0, "Should have scene headings")

        // Parse locations from scene headings
        for scene in sceneHeadings {
            let location = SceneLocation.parse(scene.elementText)
            #expect(!location.scene.isEmpty, "Should parse location from scene heading")
        }
    }

    @Test("Parsed screenplay supports outline extraction")
    func testOutlineExtractionFromParsed() async throws {
        let fountainText = """
        # Act One

        ## Scene 1

        INT. ROOM - DAY

        Action.
        """

        let screenplay = try await GuionParsedElementCollection(string: fountainText)
        let outline = screenplay.extractOutline()

        #expect(outline.count > 0, "Should extract outline")
    }
}
