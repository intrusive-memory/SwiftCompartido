//
//  ElementOrderingTests.swift
//  SwiftCompartido
//
//  Copyright (c) 2025
//
//  Tests to ensure screenplay elements maintain their exact sequence order
//

import Testing
import Foundation
import SwiftData
@testable import SwiftCompartido

/// Tests to ensure screenplay elements always maintain their original sequence
///
/// **Critical**: Screenplay elements MUST appear in the exact order they were written.
/// These tests verify that the orderIndex field and sorting mechanisms work correctly
/// for screenplays with many elements (100+).
@Suite("Element Ordering Tests")
struct ElementOrderingTests {

    // MARK: - Helper Methods

    @MainActor
    private func createInMemoryModelContext() throws -> ModelContext {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @MainActor
    private func createTestScreenplay(elementCount: Int) -> GuionParsedElementCollection {
        var elements: [GuionElement] = []

        for i in 0..<elementCount {
            // Vary element types to simulate real screenplay
            let elementType: ElementType
            let text: String

            switch i % 5 {
            case 0:
                elementType = .sceneHeading
                text = "INT. LOCATION \(i) - DAY"
            case 1:
                elementType = .action
                text = "Action line number \(i)."
            case 2:
                elementType = .character
                text = "CHARACTER \(i)"
            case 3:
                elementType = .dialogue
                text = "Dialogue line number \(i)."
            case 4:
                elementType = .transition
                text = "CUT TO:"
            default:
                elementType = .action
                text = "Default action \(i)."
            }

            elements.append(GuionElement(
                elementType: elementType,
                elementText: text
            ))
        }

        return GuionParsedElementCollection(
            filename: "test.fountain",
            elements: elements
        )
    }

    // MARK: - Order Index Assignment Tests

    @Test("Elements receive sequential orderIndex during conversion")
    @MainActor
    func testOrderIndexAssignment() async throws {
        let context = try createInMemoryModelContext()
        let screenplay = createTestScreenplay(elementCount: 100)

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        #expect(document.elements.count == 100, "Should have 100 elements")

        // Verify each element has the correct orderIndex
        for (index, element) in document.elements.enumerated() {
            #expect(element.orderIndex == index, "Element at position \(index) should have orderIndex \(index)")
        }
    }

    @Test("OrderIndex starts at 0")
    @MainActor
    func testOrderIndexStartsAtZero() async throws {
        let context = try createInMemoryModelContext()
        let screenplay = createTestScreenplay(elementCount: 10)

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        #expect(document.elements.first?.orderIndex == 0, "First element should have orderIndex 0")
    }

    @Test("OrderIndex is continuous with no gaps")
    @MainActor
    func testOrderIndexIsContinuous() async throws {
        let context = try createInMemoryModelContext()
        let screenplay = createTestScreenplay(elementCount: 200)

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Check for continuous sequence
        for i in 0..<200 {
            let element = document.elements[i]
            #expect(element.orderIndex == i, "OrderIndex should be continuous without gaps")
        }
    }

    // MARK: - Ordering Preservation Tests

    @Test("Element order matches original screenplay order")
    @MainActor
    func testElementOrderMatchesOriginal() async throws {
        let context = try createInMemoryModelContext()

        // Create screenplay with distinctive text for each element
        let originalTexts = (0..<50).map { "Element number \($0)" }
        let elements = originalTexts.map { text in
            GuionElement(elementType: .action, elementText: text)
        }

        let screenplay = GuionParsedElementCollection(
            filename: "order-test.fountain",
            elements: elements
        )

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Verify order is preserved
        for (index, element) in document.elements.enumerated() {
            #expect(element.elementText == originalTexts[index],
                    "Element at position \(index) should have original text")
        }
    }

    @Test("Large screenplay (500+ elements) maintains order")
    @MainActor
    func testLargeScreenplayOrderPreservation() async throws {
        let context = try createInMemoryModelContext()
        let screenplay = createTestScreenplay(elementCount: 500)

        // Record original order
        let originalTexts = screenplay.elements.map { $0.elementText }

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        #expect(document.elements.count == 500, "Should have 500 elements")

        // Verify every element is in correct position
        for (index, element) in document.elements.enumerated() {
            #expect(element.elementText == originalTexts[index],
                    "Element \(index) should maintain original position")
            #expect(element.orderIndex == index,
                    "Element \(index) should have orderIndex \(index)")
        }
    }

    // MARK: - Query Sorting Tests

    @Test("Fetched elements are sorted by orderIndex")
    @MainActor
    func testQueriedElementsSortedByOrderIndex() async throws {
        let context = try createInMemoryModelContext()
        let screenplay = createTestScreenplay(elementCount: 100)

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        try context.save()

        // Fetch with explicit sort (simulating @Query behavior)
        let descriptor = FetchDescriptor<GuionElementModel>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let fetchedElements = try context.fetch(descriptor)

        #expect(fetchedElements.count == 100, "Should fetch 100 elements")

        // Verify fetched elements are in order
        for (index, element) in fetchedElements.enumerated() {
            #expect(element.orderIndex == index,
                    "Fetched element at position \(index) should have orderIndex \(index)")
        }
    }

    @Test("Filtered query maintains order for specific document")
    @MainActor
    func testFilteredQueryMaintainsOrder() async throws {
        let context = try createInMemoryModelContext()

        // Create two documents
        let screenplay1 = createTestScreenplay(elementCount: 50)
        let screenplay2 = createTestScreenplay(elementCount: 50)

        let doc1 = await GuionDocumentParserSwiftData.parse(
            script: screenplay1,
            in: context
        )

        let doc2 = await GuionDocumentParserSwiftData.parse(
            script: screenplay2,
            in: context
        )

        try context.save()

        // Fetch only doc1's elements with sorting
        let doc1ID = doc1.persistentModelID
        let predicate = #Predicate<GuionElementModel> { element in
            element.document?.persistentModelID == doc1ID
        }

        let descriptor = FetchDescriptor<GuionElementModel>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.orderIndex)]
        )

        let doc1Elements = try context.fetch(descriptor)

        #expect(doc1Elements.count == 50, "Should fetch only doc1's 50 elements")

        // Verify order
        for (index, element) in doc1Elements.enumerated() {
            #expect(element.orderIndex == index,
                    "Element should have correct orderIndex")
            #expect(element.document === doc1,
                    "Element should belong to doc1")
        }
    }

    // MARK: - Conversion Fidelity Tests

    @Test("Converting to and from SwiftData preserves order")
    @MainActor
    func testRoundTripConversionPreservesOrder() async throws {
        let context = try createInMemoryModelContext()

        // Original screenplay
        let originalScreenplay = createTestScreenplay(elementCount: 100)
        let originalTexts = originalScreenplay.elements.map { $0.elementText }

        // Convert to SwiftData
        let document = await GuionDocumentParserSwiftData.parse(
            script: originalScreenplay,
            in: context
        )

        // Convert back to GuionParsedElementCollection
        let convertedBack = document.toGuionParsedElementCollection()

        #expect(convertedBack.elements.count == 100,
                "Should have same element count")

        // Verify order is preserved
        for (index, element) in convertedBack.elements.enumerated() {
            #expect(element.elementText == originalTexts[index],
                    "Round-trip conversion should preserve element order")
        }
    }

    // MARK: - Edge Cases

    @Test("Single element has orderIndex 0")
    @MainActor
    func testSingleElementOrder() async throws {
        let context = try createInMemoryModelContext()

        let screenplay = GuionParsedElementCollection(
            elements: [GuionElement(elementType: .action, elementText: "Single line.")]
        )

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        #expect(document.elements.count == 1, "Should have one element")
        #expect(document.elements.first?.orderIndex == 0, "Single element should have orderIndex 0")
    }

    @Test("Empty screenplay has no ordering issues")
    @MainActor
    func testEmptyScreenplayOrdering() async throws {
        let context = try createInMemoryModelContext()

        let screenplay = GuionParsedElementCollection(elements: [])

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        #expect(document.elements.isEmpty, "Empty screenplay should have no elements")
    }

    // MARK: - Mixed Element Types

    @Test("Different element types maintain order")
    @MainActor
    func testMixedElementTypesPreserveOrder() async throws {
        let context = try createInMemoryModelContext()

        let elements = [
            GuionElement(elementType: .sceneHeading, elementText: "INT. ROOM - DAY"),
            GuionElement(elementType: .action, elementText: "John enters."),
            GuionElement(elementType: .character, elementText: "JOHN"),
            GuionElement(elementType: .dialogue, elementText: "Hello!"),
            GuionElement(elementType: .transition, elementText: "CUT TO:"),
            GuionElement(elementType: .sceneHeading, elementText: "EXT. STREET - NIGHT"),
            GuionElement(elementType: .action, elementText: "Cars pass by."),
        ]

        let screenplay = GuionParsedElementCollection(elements: elements)
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Verify order is exactly as written
        for (index, element) in document.elements.enumerated() {
            #expect(element.elementText == elements[index].elementText,
                    "Element type should not affect ordering")
            #expect(element.orderIndex == index,
                    "Each element should have correct orderIndex")
        }
    }

    // MARK: - Performance Test

    @Test("Ordering 1000 elements completes quickly")
    @MainActor
    func testOrderingPerformance() async throws {
        let context = try createInMemoryModelContext()
        let screenplay = createTestScreenplay(elementCount: 1000)

        let startTime = Date()

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        let elapsed = Date().timeIntervalSince(startTime)

        #expect(document.elements.count == 1000, "Should have 1000 elements")
        #expect(elapsed < 2.0, "Should complete in under 2 seconds")

        // Verify all have correct orderIndex
        for (index, element) in document.elements.enumerated() {
            #expect(element.orderIndex == index,
                    "Large screenplay should maintain correct orderIndex")
        }
    }

    // MARK: - Chapter-Based Ordering Tests

    @Test("Screenplay with no chapters uses 0-99 range")
    @MainActor
    func testNoChaptersOrdering() async throws {
        let context = try createInMemoryModelContext()

        let elements = [
            GuionElement(elementType: .sceneHeading, elementText: "INT. ROOM - DAY"),
            GuionElement(elementType: .action, elementText: "Action 1."),
            GuionElement(elementType: .character, elementText: "ALICE"),
            GuionElement(elementType: .dialogue, elementText: "Hello."),
            GuionElement(elementType: .action, elementText: "Action 2."),
        ]

        let screenplay = GuionParsedElementCollection(elements: elements)
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // All elements should be in 0-99 range
        for (index, element) in document.elements.enumerated() {
            #expect(element.orderIndex == index,
                    "Without chapters, orderIndex should be sequential from 0")
            #expect(element.orderIndex < 100,
                    "Without chapters, all orderIndex values should be < 100")
        }
    }

    @Test("First element in Chapter 1 is exactly 100")
    @MainActor
    func testFirstChapterStartsAt100() async throws {
        let context = try createInMemoryModelContext()

        let elements = [
            GuionElement(elementType: .action, elementText: "Pre-chapter action."),
            GuionElement(elementType: .sectionHeading(level: 2), elementText: "# Chapter 1"),
            GuionElement(elementType: .sceneHeading, elementText: "INT. ROOM - DAY"),
            GuionElement(elementType: .action, elementText: "Chapter 1 action."),
        ]

        let screenplay = GuionParsedElementCollection(elements: elements)
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        #expect(document.elements[0].orderIndex == 0, "Pre-chapter element should be 0")
        #expect(document.elements[1].orderIndex == 100, "Chapter 1 heading should be 100")
        #expect(document.elements[2].orderIndex == 101, "First scene in Chapter 1 should be 101")
        #expect(document.elements[3].orderIndex == 102, "Second element in Chapter 1 should be 102")
    }

    @Test("Two chapters use 100-199 and 200-299 ranges")
    @MainActor
    func testTwoChaptersOrdering() async throws {
        let context = try createInMemoryModelContext()

        let elements = [
            GuionElement(elementType: .sectionHeading(level: 2), elementText: "# Chapter 1"),
            GuionElement(elementType: .action, elementText: "Chapter 1 line 1."),
            GuionElement(elementType: .action, elementText: "Chapter 1 line 2."),
            GuionElement(elementType: .action, elementText: "Chapter 1 line 3."),
            GuionElement(elementType: .sectionHeading(level: 2), elementText: "# Chapter 2"),
            GuionElement(elementType: .action, elementText: "Chapter 2 line 1."),
            GuionElement(elementType: .action, elementText: "Chapter 2 line 2."),
        ]

        let screenplay = GuionParsedElementCollection(elements: elements)
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Chapter 1 elements
        #expect(document.elements[0].orderIndex == 100, "Chapter 1 heading should be 100")
        #expect(document.elements[1].orderIndex == 101, "Chapter 1 element 1")
        #expect(document.elements[2].orderIndex == 102, "Chapter 1 element 2")
        #expect(document.elements[3].orderIndex == 103, "Chapter 1 element 3")

        // Chapter 2 elements
        #expect(document.elements[4].orderIndex == 200, "Chapter 2 heading should be 200")
        #expect(document.elements[5].orderIndex == 201, "Chapter 2 element 1")
        #expect(document.elements[6].orderIndex == 202, "Chapter 2 element 2")
    }

    @Test("Five chapters maintain correct orderIndex ranges")
    @MainActor
    func testFiveChaptersOrdering() async throws {
        let context = try createInMemoryModelContext()

        var elements: [GuionElement] = []

        // Create 5 chapters with 3 elements each
        for chapterNum in 1...5 {
            elements.append(GuionElement(
                elementType: .sectionHeading(level: 2),
                elementText: "# Chapter \(chapterNum)"
            ))
            for i in 1...3 {
                elements.append(GuionElement(
                    elementType: .action,
                    elementText: "Chapter \(chapterNum) line \(i)."
                ))
            }
        }

        let screenplay = GuionParsedElementCollection(elements: elements)
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Verify each chapter's range
        for chapterNum in 1...5 {
            let baseIndex = (chapterNum - 1) * 4 // 4 elements per chapter
            let expectedOrderBase = chapterNum * 100

            // Chapter heading
            #expect(document.elements[baseIndex].orderIndex == expectedOrderBase,
                    "Chapter \(chapterNum) heading should be \(expectedOrderBase)")

            // Chapter elements
            for i in 1...3 {
                let elemIndex = baseIndex + i
                let expectedOrder = expectedOrderBase + i
                #expect(document.elements[elemIndex].orderIndex == expectedOrder,
                        "Chapter \(chapterNum) element \(i) should be \(expectedOrder)")
            }
        }
    }

    @Test("Elements before first chapter use 0-99 range")
    @MainActor
    func testElementsBeforeFirstChapter() async throws {
        let context = try createInMemoryModelContext()

        let elements = [
            GuionElement(elementType: .action, elementText: "Pre-chapter 1."),
            GuionElement(elementType: .action, elementText: "Pre-chapter 2."),
            GuionElement(elementType: .action, elementText: "Pre-chapter 3."),
            GuionElement(elementType: .sectionHeading(level: 2), elementText: "# Chapter 1"),
            GuionElement(elementType: .action, elementText: "In Chapter 1."),
        ]

        let screenplay = GuionParsedElementCollection(elements: elements)
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Pre-chapter elements
        #expect(document.elements[0].orderIndex == 0, "Pre-chapter element 1 should be 0")
        #expect(document.elements[1].orderIndex == 1, "Pre-chapter element 2 should be 1")
        #expect(document.elements[2].orderIndex == 2, "Pre-chapter element 3 should be 2")

        // Chapter 1 elements
        #expect(document.elements[3].orderIndex == 100, "Chapter 1 heading should be 100")
        #expect(document.elements[4].orderIndex == 101, "Chapter 1 element should be 101")
    }

    @Test("Only section heading level 2 triggers chapter numbering")
    @MainActor
    func testOnlyLevel2TriggersChapter() async throws {
        let context = try createInMemoryModelContext()

        let elements = [
            GuionElement(elementType: .sectionHeading(level: 1), elementText: "# Act I"),
            GuionElement(elementType: .action, elementText: "Action 1."),
            GuionElement(elementType: .sectionHeading(level: 3), elementText: "### Scene Group"),
            GuionElement(elementType: .action, elementText: "Action 2."),
            GuionElement(elementType: .sectionHeading(level: 2), elementText: "## Chapter 1"),
            GuionElement(elementType: .action, elementText: "Action 3."),
        ]

        let screenplay = GuionParsedElementCollection(elements: elements)
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Non-chapter section headings should not trigger chapter numbering
        #expect(document.elements[0].orderIndex == 0, "Level 1 section should be 0")
        #expect(document.elements[1].orderIndex == 1, "Action after level 1 should be 1")
        #expect(document.elements[2].orderIndex == 2, "Level 3 section should be 2")
        #expect(document.elements[3].orderIndex == 3, "Action after level 3 should be 3")

        // Only level 2 triggers chapter numbering
        #expect(document.elements[4].orderIndex == 100, "Level 2 section (Chapter 1) should be 100")
        #expect(document.elements[5].orderIndex == 101, "Action in Chapter 1 should be 101")
    }

    @Test("Large screenplay with chapters maintains gaps")
    @MainActor
    func testLargeScreenplayWithChapters() async throws {
        let context = try createInMemoryModelContext()

        var elements: [GuionElement] = []

        // Add 3 chapters with 30 elements each
        for chapterNum in 1...3 {
            elements.append(GuionElement(
                elementType: .sectionHeading(level: 2),
                elementText: "# Chapter \(chapterNum)"
            ))

            for i in 1...30 {
                elements.append(GuionElement(
                    elementType: .action,
                    elementText: "Chapter \(chapterNum) line \(i)."
                ))
            }
        }

        let screenplay = GuionParsedElementCollection(elements: elements)
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Verify chapter gaps are maintained
        #expect(document.elements[0].orderIndex == 100, "Chapter 1 starts at 100")
        #expect(document.elements[31].orderIndex == 200, "Chapter 2 starts at 200")
        #expect(document.elements[62].orderIndex == 300, "Chapter 3 starts at 300")

        // Verify spacing within chapters
        #expect(document.elements[30].orderIndex == 130, "Last element of Chapter 1")
        #expect(document.elements[61].orderIndex == 230, "Last element of Chapter 2")
        #expect(document.elements[92].orderIndex == 330, "Last element of Chapter 3")
    }
}
