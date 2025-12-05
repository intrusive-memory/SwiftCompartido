//
//  ParsedFileServiceTests.swift
//  SwiftCompartidoTests
//
//  Unit tests for ParsedFileService
//

import Testing
import SwiftData
import Foundation
@testable import SwiftCompartido

/// Test suite for ParsedFileService
///
/// Tests the core parsing and querying functionality of the unified service layer.
/// Uses in-memory ModelContainer and existing test fixtures from Fixtures/ directory.
@Suite("ParsedFileService Tests")
@MainActor
struct ParsedFileServiceTests {

    // MARK: - Test Fixtures

    /// Get URL for a test fixture file
    private func fixtureURL(named filename: String) throws -> URL {
        let fixturesPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // SwiftCompartidoTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // SwiftCompartido
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: fixturesPath.path) else {
            throw TestError.fixtureNotFound(filename)
        }

        return fixturesPath
    }

    /// Create an in-memory test container
    private func makeTestContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: GuionDocumentModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return container
    }

    // MARK: - Parsing Tests

    @Test("Parse Fountain file returns valid document ID")
    func testParseFountainFile() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")

        let documentID = try await service.parseFile(at: fileURL)

        // Verify document was created
        let document = try await service.document(id: documentID)
        let title = document.title
        let elementCount = document.sortedElements.count
        let filename = document.filename

        #expect(title != nil)
        #expect(elementCount > 0)
        #expect(filename == "bigfish.fountain")
    }

    @Test("Parse FDX file returns valid document ID")
    func testParseFDXFile() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fdx")

        let documentID = try await service.parseFile(at: fileURL)

        // Verify document was created
        let document = try await service.document(id: documentID)
        let elementCount = document.sortedElements.count
        let filename = document.filename

        #expect(elementCount > 0)
        #expect(filename == "bigfish.fdx")
    }

    @Test("Parse PDF file returns valid document ID")
    func testParsePDFFile() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "BULLITT.pdf")

        let documentID = try await service.parseFile(at: fileURL)

        // Verify document was created
        let document = try await service.document(id: documentID)
        let elementCount = document.sortedElements.count

        #expect(elementCount > 0)
    }

    @Test("Parse Highland file returns valid document ID")
    func testParseHighlandFile() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.highland")

        let documentID = try await service.parseFile(at: fileURL)

        // Verify document was created
        let document = try await service.document(id: documentID)
        let elementCount = document.sortedElements.count

        #expect(elementCount > 0)
    }

    @Test("Parse non-existent file throws error")
    func testParseNonExistentFile() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let badURL = URL(fileURLWithPath: "/nonexistent/file.fountain")

        var didThrow = false
        do {
            _ = try await service.parseFile(at: badURL)
        } catch is ParsedFileServiceError {
            didThrow = true
        }
        #expect(didThrow)
    }

    // MARK: - Document Retrieval Tests

    @Test("Retrieve document by ID returns correct document")
    func testRetrieveDocumentByID() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)

        // Retrieve document
        let document = try await service.document(id: documentID)
        let retrievedID = document.persistentModelID
        let filename = document.filename

        #expect(retrievedID == documentID)
        #expect(filename == "bigfish.fountain")
    }

    @Test("Retrieve non-existent document throws error")
    func testRetrieveNonExistentDocument() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        // Parse a document and get its ID
        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)

        // Delete the document to make the ID invalid
        let modelContext = ModelContext(container)
        if let document = modelContext.model(for: documentID) as? GuionDocumentModel {
            modelContext.delete(document)
            try modelContext.save()
        }

        // Try to retrieve the deleted document
        var didThrow = false
        do {
            _ = try await service.document(id: documentID)
        } catch is ParsedFileServiceError {
            didThrow = true
        }
        #expect(didThrow)
    }

    // MARK: - Element Query Tests

    @Test("Query all elements returns complete list")
    func testQueryAllElements() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)

        // Query without filter
        let elements = try await service.elements(documentID: documentID, filter: nil)

        let document = try await service.document(id: documentID)
        let elementsCount = elements.count
        let sortedElementsCount = document.sortedElements.count

        #expect(elementsCount == sortedElementsCount)
    }

    @Test("Query elements with dialogue filter")
    func testQueryDialogueFilter() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)

        // Query with dialogue filter
        let filter = ElementFilter(elementTypes: [.dialogue])
        let elements = try await service.elements(documentID: documentID, filter: filter)

        // Verify all returned elements are dialogue
        #expect(elements.allSatisfy { $0.elementType == .dialogue })
        #expect(elements.count > 0)
    }

    @Test("Query elements with scene heading filter")
    func testQuerySceneHeadingFilter() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)

        // Query with scene heading filter
        let filter = ElementFilter(elementTypes: [.sceneHeading])
        let elements = try await service.elements(documentID: documentID, filter: filter)

        // Verify all returned elements are scene headings
        #expect(elements.allSatisfy { $0.elementType == .sceneHeading })
        #expect(elements.count > 0)
    }

    @Test("Query elements with action filter")
    func testQueryActionFilter() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)

        // Query with action filter
        let filter = ElementFilter(elementTypes: [.action])
        let elements = try await service.elements(documentID: documentID, filter: filter)

        // Verify all returned elements are action
        #expect(elements.allSatisfy { $0.elementType == .action })
    }

    @Test("Query elements with multiple types")
    func testQueryMultipleTypes() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)

        // Query with multiple types
        let filter = ElementFilter(elementTypes: [.dialogue, .action])
        let elements = try await service.elements(documentID: documentID, filter: filter)

        // Verify all returned elements are either dialogue or action
        #expect(elements.allSatisfy { $0.elementType == .dialogue || $0.elementType == .action })
        #expect(elements.count > 0)
    }

    @Test("Query elements with chapter filter")
    func testQueryChapterFilter() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)

        // Query with chapter filter (chapter 0)
        let filter = ElementFilter(chapterIndex: 0)
        let elements = try await service.elements(documentID: documentID, filter: filter)

        // Verify all returned elements are from chapter 0
        #expect(elements.allSatisfy { $0.chapterIndex == 0 })
    }

    @Test("Query elements with search text")
    func testQuerySearchText() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)

        // Query with search text
        let filter = ElementFilter(searchText: "Edward")
        let elements = try await service.elements(documentID: documentID, filter: filter)

        // Verify all returned elements contain "Edward" (case-insensitive)
        #expect(elements.allSatisfy { $0.elementText.localizedCaseInsensitiveContains("Edward") })
        #expect(elements.count > 0)
    }

    @Test("Query elements with combined filters")
    func testQueryCombinedFilters() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)

        // Query with combined filters
        let filter = ElementFilter(
            elementTypes: [.dialogue],
            searchText: "Edward"
        )
        let elements = try await service.elements(documentID: documentID, filter: filter)

        // Verify all returned elements match both criteria
        #expect(elements.allSatisfy {
            $0.elementType == .dialogue &&
            $0.elementText.localizedCaseInsensitiveContains("Edward")
        })
    }

    @Test("Query with empty filter returns all elements")
    func testQueryEmptyFilter() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)

        // Query with empty filter
        let filter = ElementFilter() // All fields nil
        let elements = try await service.elements(documentID: documentID, filter: filter)

        let document = try await service.document(id: documentID)
        let elementsCount = elements.count
        let sortedElementsCount = document.sortedElements.count

        #expect(elementsCount == sortedElementsCount)
    }

    // MARK: - Progress Tracking Tests

    @Test("Parse with progress tracking reports progress")
    func testParseWithProgress() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        // Use actor for thread-safe progress tracking
        actor ProgressTracker {
            var updates: [ProgressUpdate] = []

            func append(_ update: ProgressUpdate) {
                updates.append(update)
            }

            func count() -> Int {
                updates.count
            }
        }

        let tracker = ProgressTracker()
        let progress = OperationProgress(totalUnits: nil) { update in
            Task {
                await tracker.append(update)
            }
        }

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL, progress: progress)

        // Verify we got progress updates
        let updateCount = await tracker.count()
        #expect(updateCount > 0)

        // Verify document was created
        let document = try await service.document(id: documentID)
        let elementCount = document.sortedElements.count
        #expect(elementCount > 0)
    }

    // MARK: - Element Ordering Tests

    @Test("Elements maintain correct order")
    func testElementOrdering() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)

        let elements = try await service.elements(documentID: documentID, filter: nil)

        // Verify elements are ordered by (chapterIndex, orderIndex)
        for i in 0..<(elements.count - 1) {
            let current = elements[i]
            let next = elements[i + 1]

            if current.chapterIndex == next.chapterIndex {
                #expect(current.orderIndex <= next.orderIndex)
            } else {
                #expect(current.chapterIndex < next.chapterIndex)
            }
        }
    }
}

// MARK: - Test Errors

enum TestError: Error {
    case fixtureNotFound(String)
}
