//
//  HighlandCustomPagesTests.swift
//  SwiftCompartidoTests
//
//  Copyright (c) 2025
//

import Foundation
import Testing
@testable import SwiftCompartido

@Suite("Highland Custom Pages Tests")
struct HighlandCustomPagesTests {

    // MARK: - Helper Methods

    func createTempHighlandFile(withCustomPages: Bool = false) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create a simple screenplay
        let screenplay = GuionParsedElementCollection(
            filename: "test.fountain",
            elements: [
                GuionElement(elementType: .sceneHeading, elementText: "INT. COFFEE SHOP - DAY"),
                GuionElement(elementType: .action, elementText: "Sarah enters.")
            ],
            titlePage: [["title": ["Test Script"]]],
            suppressSceneNumbers: false,
            customPages: withCustomPages ? createTestCustomPages() : []
        )

        // Write to Highland format
        let highlandURL = try screenplay.writeToHighland(
            destinationURL: tempDir,
            name: "test",
            includeResources: true
        )

        return highlandURL
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
                ),
                CastListPage.CastMember(
                    id: "member-2",
                    role: "BARISTA",
                    name: "John Doe",
                    position: 1
                )
            ]
        )

        return [try! CustomPageContainer(page: castList, type: .castList)]
    }

    // MARK: - Reading Tests

    @Test("Reads Highland file without custom pages")
    func testReadHighlandWithoutCustomPages() throws {
        let highlandURL = try createTempHighlandFile(withCustomPages: false)
        defer { try? FileManager.default.removeItem(at: highlandURL.deletingLastPathComponent()) }

        let screenplay = try GuionParsedElementCollection(highland: highlandURL)

        #expect(screenplay.customPages.isEmpty)
        #expect(screenplay.elements.count == 2)
    }

    @Test("Reads Highland file with custom pages")
    func testReadHighlandWithCustomPages() throws {
        let highlandURL = try createTempHighlandFile(withCustomPages: true)
        defer { try? FileManager.default.removeItem(at: highlandURL.deletingLastPathComponent()) }

        let screenplay = try GuionParsedElementCollection(highland: highlandURL)

        #expect(screenplay.customPages.count == 1)
        #expect(screenplay.customPages[0].type == .castList)
        #expect(screenplay.customPages[0].title == "Test Cast List")
    }

    @Test("Preserves cast list data when reading Highland")
    func testPreservesCastListData() throws {
        let highlandURL = try createTempHighlandFile(withCustomPages: true)
        defer { try? FileManager.default.removeItem(at: highlandURL.deletingLastPathComponent()) }

        let screenplay = try GuionParsedElementCollection(highland: highlandURL)
        let castList = try screenplay.customPages[0].asCastList()

        #expect(castList?.id == "test-cast-id")
        #expect(castList?.printDots == true)
        #expect(castList?.items.count == 2)
        #expect(castList?.items[0].role == "SARAH")
        #expect(castList?.items[0].name == "Emma Stone")
        #expect(castList?.items[1].role == "BARISTA")
    }

    // MARK: - Writing Tests

    @Test("Writes Highland file without custom pages")
    func testWriteHighlandWithoutCustomPages() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let screenplay = GuionParsedElementCollection(
            filename: "test.fountain",
            elements: [
                GuionElement(elementType: .action, elementText: "Test action.")
            ]
        )

        let highlandURL = try screenplay.writeToHighland(
            destinationURL: tempDir,
            name: "test",
            includeResources: true
        )

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: highlandURL.path))

        // Read it back and verify no custom pages
        let reloaded = try GuionParsedElementCollection(highland: highlandURL)
        #expect(reloaded.customPages.isEmpty)
    }

    @Test("Writes Highland file with custom pages")
    func testWriteHighlandWithCustomPages() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let castList = CastListPage(
            title: "Main Cast",
            position: 0,
            printDots: true,
            items: [
                CastListPage.CastMember(role: "HAMLET", name: "Actor 1", position: 0)
            ]
        )

        let screenplay = GuionParsedElementCollection(
            filename: "test.fountain",
            elements: [
                GuionElement(elementType: .action, elementText: "Test action.")
            ],
            titlePage: [],
            suppressSceneNumbers: false,
            customPages: [try CustomPageContainer(page: castList, type: .castList)]
        )

        let highlandURL = try screenplay.writeToHighland(
            destinationURL: tempDir,
            name: "test",
            includeResources: true
        )

        // Read it back
        let reloaded = try GuionParsedElementCollection(highland: highlandURL)

        #expect(reloaded.customPages.count == 1)
        #expect(reloaded.customPages[0].type == .castList)

        let reloadedCastList = try reloaded.customPages[0].asCastList()
        #expect(reloadedCastList?.title == "Main Cast")
        #expect(reloadedCastList?.items.count == 1)
        #expect(reloadedCastList?.items[0].role == "HAMLET")
    }

    // MARK: - Round-Trip Tests

    @Test("Round-trip preserves custom pages")
    func testRoundTripPreservation() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create original with multiple custom pages
        let castList1 = CastListPage(
            id: "cast-1",
            title: "Main Cast",
            position: 0,
            printDots: true,
            items: [
                CastListPage.CastMember(role: "LEAD", name: "Actor A", position: 0)
            ]
        )

        let castList2 = CastListPage(
            id: "cast-2",
            title: "Supporting Cast",
            position: 1,
            printDots: false,
            items: [
                CastListPage.CastMember(role: "EXTRA 1", name: "Actor B", position: 0),
                CastListPage.CastMember(role: "EXTRA 2", name: "Actor C", position: 1)
            ]
        )

        let original = GuionParsedElementCollection(
            filename: "test.fountain",
            elements: [
                GuionElement(elementType: .action, elementText: "Action.")
            ],
            titlePage: [],
            suppressSceneNumbers: false,
            customPages: [
                try CustomPageContainer(page: castList1, type: .castList),
                try CustomPageContainer(page: castList2, type: .castList)
            ]
        )

        // Write and read back
        let highlandURL = try original.writeToHighland(
            destinationURL: tempDir,
            name: "test",
            includeResources: true
        )

        let reloaded = try GuionParsedElementCollection(highland: highlandURL)

        // Verify all custom pages preserved
        #expect(reloaded.customPages.count == 2)

        let reloadedCast1 = try reloaded.customPages[0].asCastList()
        let reloadedCast2 = try reloaded.customPages[1].asCastList()

        #expect(reloadedCast1?.id == "cast-1")
        #expect(reloadedCast1?.title == "Main Cast")
        #expect(reloadedCast1?.printDots == true)
        #expect(reloadedCast1?.items.count == 1)

        #expect(reloadedCast2?.id == "cast-2")
        #expect(reloadedCast2?.title == "Supporting Cast")
        #expect(reloadedCast2?.printDots == false)
        #expect(reloadedCast2?.items.count == 2)
    }

    // MARK: - Unsupported Type Preservation Tests

    @Test("Preserves unsupported custom page types")
    func testPreservesUnsupportedTypes() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a custom page with unsupported type using raw JSON
        let advancedPageDict: [String: Any] = [
            "id": "advanced-1",
            "type": "advanced",
            "title": "Concept Art",
            "position": 0,
            "cc": [
                "text": "Center Image",
                "assetFilename": "concept.png"
            ]
        ]

        let original = GuionParsedElementCollection(
            filename: "test.fountain",
            elements: [
                GuionElement(elementType: .action, elementText: "Action.")
            ],
            titlePage: [],
            suppressSceneNumbers: false,
            customPages: [
                try CustomPageContainer(from: advancedPageDict)
            ]
        )

        // Write and read back
        let highlandURL = try original.writeToHighland(
            destinationURL: tempDir,
            name: "test",
            includeResources: true
        )

        let reloaded = try GuionParsedElementCollection(highland: highlandURL)

        #expect(reloaded.customPages.count == 1)
        #expect(reloaded.customPages[0].type == .advanced)

        // Verify raw JSON preserved
        let rawJSON = try reloaded.customPages[0].asRawJSON()
        #expect(rawJSON["id"] as? String == "advanced-1")
        #expect(rawJSON["title"] as? String == "Concept Art")

        let cc = rawJSON["cc"] as? [String: Any]
        #expect(cc?["assetFilename"] as? String == "concept.png")
    }
}
