//
//  FountainCustomPagesSidecarTests.swift
//  SwiftCompartidoTests
//
//  Copyright (c) 2025
//

import Foundation
import Testing
@testable import SwiftCompartido

@Suite("Fountain Custom Pages Sidecar Tests")
struct FountainCustomPagesSidecarTests {

    // MARK: - Helper Methods

    func createTempFountainFile(name: String = "test", withSidecar: Bool = false) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let fountainURL = tempDir.appendingPathComponent("\(name).fountain")

        // Create simple fountain content
        let content = """
        Title: Test Script

        INT. COFFEE SHOP - DAY

        Sarah enters.
        """

        try content.write(to: fountainURL, atomically: true, encoding: .utf8)

        // Create sidecar if requested
        if withSidecar {
            let sidecarURL = tempDir.appendingPathComponent("\(name)-custom-pages.json")
            let customPages = createTestCustomPages()
            let jsonArray = try customPages.map { try $0.toDictionary() }
            let jsonData = try JSONSerialization.data(withJSONObject: jsonArray, options: [.prettyPrinted])
            try jsonData.write(to: sidecarURL)
        }

        return fountainURL
    }

    func createTestCustomPages() -> [CustomPageContainer] {
        let castList = CastListPage(
            id: "test-cast-id",
            title: "Test Cast List",
            position: 0,
            printDots: true,
            items: [
                CastListPage.CastMember(
                    id: "member-1",
                    role: "SARAH",
                    name: "Emma Stone",
                    position: 0
                )
            ]
        )

        return [try! CustomPageContainer(page: castList, type: .castList)]
    }

    // MARK: - Reading Tests

    @Test("Reads Fountain file without sidecar")
    func testReadFountainWithoutSidecar() throws {
        let fountainURL = try createTempFountainFile(withSidecar: false)
        defer { try? FileManager.default.removeItem(at: fountainURL.deletingLastPathComponent()) }

        let screenplay = try GuionParsedElementCollection(file: fountainURL.path)

        #expect(screenplay.customPages.isEmpty)
        #expect(!screenplay.elements.isEmpty)
    }

    @Test("Reads Fountain file with document-specific sidecar")
    func testReadFountainWithDocumentSpecificSidecar() throws {
        let fountainURL = try createTempFountainFile(name: "myscript", withSidecar: true)
        defer { try? FileManager.default.removeItem(at: fountainURL.deletingLastPathComponent()) }

        let screenplay = try GuionParsedElementCollection(file: fountainURL.path)

        #expect(screenplay.customPages.count == 1)
        #expect(screenplay.customPages[0].type == .castList)
        #expect(screenplay.customPages[0].title == "Test Cast List")
    }

    @Test("Reads Fountain file with shared custom-pages.json")
    func testReadFountainWithSharedSidecar() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create fountain file
        let fountainURL = tempDir.appendingPathComponent("script.fountain")
        let content = "INT. SCENE - DAY\n\nAction."
        try content.write(to: fountainURL, atomically: true, encoding: .utf8)

        // Create SHARED custom-pages.json (not document-specific)
        let sharedSidecarURL = tempDir.appendingPathComponent("custom-pages.json")
        let customPages = createTestCustomPages()
        let jsonArray = try customPages.map { try $0.toDictionary() }
        let jsonData = try JSONSerialization.data(withJSONObject: jsonArray, options: [])
        try jsonData.write(to: sharedSidecarURL)

        // Read fountain file
        let screenplay = try GuionParsedElementCollection(file: fountainURL.path)

        #expect(screenplay.customPages.count == 1)
    }

    @Test("Document-specific sidecar takes precedence over shared")
    func testDocumentSpecificTakesPrecedence() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create fountain file
        let fountainURL = tempDir.appendingPathComponent("script.fountain")
        let content = "INT. SCENE - DAY\n\nAction."
        try content.write(to: fountainURL, atomically: true, encoding: .utf8)

        // Create document-specific sidecar
        let specificCastList = CastListPage(
            title: "Document-Specific Cast",
            position: 0,
            items: []
        )
        let specificSidecarURL = tempDir.appendingPathComponent("script-custom-pages.json")
        let specificPages = [try CustomPageContainer(page: specificCastList, type: .castList)]
        let specificJSON = try JSONSerialization.data(
            withJSONObject: specificPages.map { try $0.toDictionary() },
            options: []
        )
        try specificJSON.write(to: specificSidecarURL)

        // Create shared sidecar
        let sharedCastList = CastListPage(
            title: "Shared Cast",
            position: 0,
            items: []
        )
        let sharedSidecarURL = tempDir.appendingPathComponent("custom-pages.json")
        let sharedPages = [try CustomPageContainer(page: sharedCastList, type: .castList)]
        let sharedJSON = try JSONSerialization.data(
            withJSONObject: sharedPages.map { try $0.toDictionary() },
            options: []
        )
        try sharedJSON.write(to: sharedSidecarURL)

        // Read fountain file
        let screenplay = try GuionParsedElementCollection(file: fountainURL.path)

        #expect(screenplay.customPages.count == 1)
        let castList = try screenplay.customPages[0].asCastList()
        #expect(castList?.title == "Document-Specific Cast")
    }

    // MARK: - Writing Tests

    @Test("Writes Fountain with document-specific sidecar")
    func testWriteFountainWithSidecar() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let castList = CastListPage(
            title: "Main Cast",
            position: 0,
            printDots: true,
            items: [
                CastListPage.CastMember(role: "HAMLET", name: "Actor", position: 0)
            ]
        )

        let screenplay = GuionParsedElementCollection(
            filename: "myscript.fountain",
            elements: [
                GuionElement(elementType: .action, elementText: "Action.")
            ],
            titlePage: [],
            suppressSceneNumbers: false,
            customPages: [try CustomPageContainer(page: castList, type: .castList)]
        )

        let fountainURL = tempDir.appendingPathComponent("myscript.fountain")
        try screenplay.write(to: fountainURL)

        // Verify sidecar file was created
        let sidecarURL = tempDir.appendingPathComponent("myscript-custom-pages.json")
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))

        // Verify sidecar content
        let sidecarData = try Data(contentsOf: sidecarURL)
        let jsonArray = try JSONSerialization.jsonObject(with: sidecarData) as? [[String: Any]]
        #expect(jsonArray?.count == 1)
        #expect(jsonArray?[0]["type"] as? String == "castList")
    }

    @Test("Does not create sidecar when no custom pages")
    func testNoSidecarWhenNoCustomPages() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let screenplay = GuionParsedElementCollection(
            filename: "test.fountain",
            elements: [
                GuionElement(elementType: .action, elementText: "Action.")
            ]
        )

        let fountainURL = tempDir.appendingPathComponent("test.fountain")
        try screenplay.write(to: fountainURL)

        // Verify sidecar was NOT created
        let sidecarURL = tempDir.appendingPathComponent("test-custom-pages.json")
        #expect(!FileManager.default.fileExists(atPath: sidecarURL.path))
    }

    // MARK: - Round-Trip Tests

    @Test("Round-trip preserves custom pages via sidecar")
    func testRoundTripViaSidecar() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create original with custom pages
        let castList = CastListPage(
            id: "cast-id",
            title: "Original Cast",
            position: 0,
            printDots: true,
            items: [
                CastListPage.CastMember(
                    id: "member-1",
                    role: "LEAD",
                    name: "Actor A",
                    position: 0
                ),
                CastListPage.CastMember(
                    id: "member-2",
                    role: "SUPPORT",
                    name: "Actor B",
                    position: 1
                )
            ]
        )

        let original = GuionParsedElementCollection(
            filename: "screenplay.fountain",
            elements: [
                GuionElement(elementType: .sceneHeading, elementText: "INT. SCENE - DAY"),
                GuionElement(elementType: .action, elementText: "Action.")
            ],
            titlePage: [["title": ["Test"]]],
            suppressSceneNumbers: false,
            customPages: [try CustomPageContainer(page: castList, type: .castList)]
        )

        // Write
        let fountainURL = tempDir.appendingPathComponent("screenplay.fountain")
        try original.write(to: fountainURL)

        // Read back
        let reloaded = try GuionParsedElementCollection(file: fountainURL.path)

        // Verify custom pages preserved
        #expect(reloaded.customPages.count == 1)
        let reloadedCastList = try reloaded.customPages[0].asCastList()

        #expect(reloadedCastList?.id == "cast-id")
        #expect(reloadedCastList?.title == "Original Cast")
        #expect(reloadedCastList?.printDots == true)
        #expect(reloadedCastList?.items.count == 2)
        #expect(reloadedCastList?.items[0].role == "LEAD")
        #expect(reloadedCastList?.items[1].role == "SUPPORT")
    }

    // MARK: - Edge Cases

    @Test("Handles malformed sidecar JSON gracefully")
    func testMalformedSidecarJSON() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create fountain file
        let fountainURL = tempDir.appendingPathComponent("test.fountain")
        let content = "INT. SCENE - DAY\n\nAction."
        try content.write(to: fountainURL, atomically: true, encoding: .utf8)

        // Create malformed sidecar
        let sidecarURL = tempDir.appendingPathComponent("test-custom-pages.json")
        let malformedJSON = "{ this is not valid JSON }"
        try malformedJSON.write(to: sidecarURL, atomically: true, encoding: .utf8)

        // Should not crash, just return empty custom pages
        let screenplay = try GuionParsedElementCollection(file: fountainURL.path)
        #expect(screenplay.customPages.isEmpty)
    }

    @Test("Handles special characters in filename")
    func testSpecialCharactersInFilename() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create file with special characters in name
        let fountainURL = tempDir.appendingPathComponent("my script - draft 1.fountain")
        let content = "INT. SCENE - DAY\n\nAction."
        try content.write(to: fountainURL, atomically: true, encoding: .utf8)

        // Create corresponding sidecar
        let sidecarURL = tempDir.appendingPathComponent("my script - draft 1-custom-pages.json")
        let customPages = createTestCustomPages()
        let jsonData = try JSONSerialization.data(
            withJSONObject: customPages.map { try $0.toDictionary() },
            options: []
        )
        try jsonData.write(to: sidecarURL)

        // Read
        let screenplay = try GuionParsedElementCollection(file: fountainURL.path)

        #expect(screenplay.customPages.count == 1)
    }
}
