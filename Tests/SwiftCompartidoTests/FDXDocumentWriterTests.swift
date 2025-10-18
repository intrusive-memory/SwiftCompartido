//
//  FDXDocumentWriterTests.swift
//  SwiftGuionTests
//
//  Tests for FDX document writing functionality
//

import Testing
import Foundation
@testable import SwiftCompartido
#if canImport(SwiftData)
import SwiftData

@Suite("FDXDocumentWriter Tests")
struct FDXDocumentWriterTests {

    @MainActor
    private func createModelContext() throws -> ModelContext {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test("Create FDX from empty document")
    @MainActor
    func testEmptyDocumentFDX() throws {
        let modelContext = try createModelContext()
        let document = GuionDocumentModel(filename: "test.fountain")
        modelContext.insert(document)

        let fdxData = FDXDocumentWriter.makeFDX(from: document)
        let fdxString = String(data: fdxData, encoding: .utf8)

        #expect(fdxString != nil, "Should generate FDX XML")
        #expect(fdxString!.contains("<?xml version="), "Should have XML header")
        #expect(fdxString!.contains("<FinalDraft"), "Should have FinalDraft root")
        #expect(fdxString!.contains("<Content>"), "Should have Content section")
        #expect(fdxString!.contains("<TitlePage>"), "Should have TitlePage section")
    }

    @Test("Create FDX with basic elements")
    @MainActor
    func testBasicElementsFDX() throws {
        let modelContext = try createModelContext()
        let document = GuionDocumentModel(filename: "test.fountain")
        modelContext.insert(document)

        // Add a scene heading
        let sceneHeading = GuionElementModel(
            elementText: "INT. OFFICE - DAY",
            elementType: .sceneHeading
        )
        sceneHeading.sceneNumber = "1"
        modelContext.insert(sceneHeading)
        document.elements.append(sceneHeading)

        // Add an action
        let action = GuionElementModel(
            elementText: "John enters the office.",
            elementType: .action
        )
        modelContext.insert(action)
        document.elements.append(action)

        // Add character and dialogue
        let character = GuionElementModel(
            elementText: "JOHN",
            elementType: .character
        )
        modelContext.insert(character)
        document.elements.append(character)

        let dialogue = GuionElementModel(
            elementText: "Hello, everyone!",
            elementType: .dialogue
        )
        modelContext.insert(dialogue)
        document.elements.append(dialogue)

        let fdxData = FDXDocumentWriter.makeFDX(from: document)
        let fdxString = String(data: fdxData, encoding: .utf8)!

        #expect(fdxString.contains("INT. OFFICE - DAY"), "Should contain scene heading text")
        #expect(fdxString.contains("Scene Heading"), "Should have Scene Heading type")
        #expect(fdxString.contains("Number=\"1\""), "Should include scene number")
        #expect(fdxString.contains("John enters the office."), "Should contain action text")
        #expect(fdxString.contains("JOHN"), "Should contain character name")
        #expect(fdxString.contains("Hello, everyone!"), "Should contain dialogue text")
    }

    @Test("FDX escapes special XML characters")
    @MainActor
    func testXMLEscaping() throws {
        let modelContext = try createModelContext()
        let document = GuionDocumentModel(filename: "test.fountain")
        modelContext.insert(document)

        let action = GuionElementModel(
            elementText: "Text with <brackets> & \"quotes\" and 'apostrophes'",
            elementType: .action
        )
        modelContext.insert(action)
        document.elements.append(action)

        let fdxData = FDXDocumentWriter.makeFDX(from: document)
        let fdxString = String(data: fdxData, encoding: .utf8)!

        #expect(fdxString.contains("&lt;"), "Should escape <")
        #expect(fdxString.contains("&gt;"), "Should escape >")
        #expect(fdxString.contains("&amp;"), "Should escape &")
        #expect(fdxString.contains("&quot;"), "Should escape \"")
        #expect(fdxString.contains("&apos;"), "Should escape '")
    }

    @Test("FDX with title page entries")
    @MainActor
    func testTitlePageFDX() throws {
        let modelContext = try createModelContext()
        let document = GuionDocumentModel(filename: "test.fountain")
        modelContext.insert(document)

        // Add title page entry
        let titleEntry = TitlePageEntryModel(key: "title", values: ["My Great Screenplay"])
        modelContext.insert(titleEntry)
        document.titlePage.append(titleEntry)

        let authorEntry = TitlePageEntryModel(key: "author", values: ["John Doe", "Jane Smith"])
        modelContext.insert(authorEntry)
        document.titlePage.append(authorEntry)

        let fdxData = FDXDocumentWriter.makeFDX(from: document)
        let fdxString = String(data: fdxData, encoding: .utf8)!

        #expect(fdxString.contains("<TitlePage>"), "Should have TitlePage section")
        #expect(fdxString.contains("My Great Screenplay"), "Should contain title")
        #expect(fdxString.contains("John Doe"), "Should contain first author")
        #expect(fdxString.contains("Jane Smith"), "Should contain second author")
    }

    @Test("FDX handles empty title page")
    @MainActor
    func testEmptyTitlePageFDX() throws {
        let modelContext = try createModelContext()
        let document = GuionDocumentModel(filename: "test.fountain")
        modelContext.insert(document)

        let fdxData = FDXDocumentWriter.makeFDX(from: document)
        let fdxString = String(data: fdxData, encoding: .utf8)!

        #expect(fdxString.contains("<TitlePage>"), "Should have TitlePage section")
        #expect(fdxString.contains("<Content/>"), "Empty title page should have empty Content")
    }

    @Test("FDX filters out whitespace-only title page values")
    @MainActor
    func testWhitespaceFilteringInTitlePage() throws {
        let modelContext = try createModelContext()
        let document = GuionDocumentModel(filename: "test.fountain")
        modelContext.insert(document)

        let titleEntry = TitlePageEntryModel(key: "title", values: ["Valid Title", "   ", "\n\n", "Another Valid"])
        modelContext.insert(titleEntry)
        document.titlePage.append(titleEntry)

        let fdxData = FDXDocumentWriter.makeFDX(from: document)
        let fdxString = String(data: fdxData, encoding: .utf8)!

        #expect(fdxString.contains("Valid Title"), "Should include non-empty values")
        #expect(fdxString.contains("Another Valid"), "Should include non-empty values")
        // Count the number of <Paragraph> elements in TitlePage
        let paragraphCount = fdxString.components(separatedBy: "<Paragraph").count - 1
        #expect(paragraphCount == 2, "Should only create paragraphs for non-empty values")
    }

    @Test("FDX round-trip test")
    @MainActor
    func testFDXRoundTrip() throws {
        let modelContext = try createModelContext()
        let document = GuionDocumentModel(filename: "test.fountain")
        modelContext.insert(document)

        // Create a simple script
        let elements = [
            ("Scene Heading", "INT. LIVING ROOM - DAY"),
            ("Action", "Sarah sits on the couch."),
            ("Character", "SARAH"),
            ("Dialogue", "I can't believe this is happening."),
            ("Transition", "CUT TO:")
        ]

        for (type, text) in elements {
            let element = GuionElementModel(
                elementText: text,
                elementType: ElementType(string: type)
            )
            modelContext.insert(element)
            document.elements.append(element)
        }

        // Write to FDX
        let fdxData = FDXDocumentWriter.makeFDX(from: document)

        // Parse it back
        let parser = FDXParser()
        let parsedDocument = try parser.parse(data: fdxData, filename: "test.fdx")

        // Verify content
        #expect(parsedDocument.elements.count == elements.count, "Should have same number of elements")

        for (index, (expectedType, expectedText)) in elements.enumerated() {
            let parsedElement = parsedDocument.elements[index]
            #expect(parsedElement.elementType == ElementType(string: expectedType), "Element type should match at index \(index)")
            #expect(parsedElement.elementText == expectedText, "Element text should match at index \(index)")
        }
    }

    @Test("FDX with complex scene numbers")
    @MainActor
    func testComplexSceneNumbers() throws {
        let modelContext = try createModelContext()
        let document = GuionDocumentModel(filename: "test.fountain")
        modelContext.insert(document)

        let scenes = [
            ("1", "INT. OFFICE - DAY"),
            ("2A", "EXT. PARKING LOT - DAY"),
            ("3", "INT. OFFICE - LATER"),
        ]

        for (number, text) in scenes {
            let scene = GuionElementModel(
                elementText: text,
                elementType: .sceneHeading
            )
            scene.sceneNumber = number
            modelContext.insert(scene)
            document.elements.append(scene)
        }

        let fdxData = FDXDocumentWriter.makeFDX(from: document)
        let fdxString = String(data: fdxData, encoding: .utf8)!

        #expect(fdxString.contains("Number=\"1\""), "Should contain scene number 1")
        #expect(fdxString.contains("Number=\"2A\""), "Should contain scene number 2A")
        #expect(fdxString.contains("Number=\"3\""), "Should contain scene number 3")
    }
}
#endif
