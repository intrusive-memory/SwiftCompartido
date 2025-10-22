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

        // Verify each element has the correct composite key
        for (index, element) in document.elements.enumerated() {
            #expect(element.chapterIndex == 0, "All elements should be in chapter 0")
            #expect(element.orderIndex == index + 1, "Element at position \(index) should have orderIndex \(index + 1) (1-based)")
        }
    }

    @Test("OrderIndex starts at 1 with chapterIndex 0")
    @MainActor
    func testOrderIndexStartsAtZero() async throws {
        let context = try createInMemoryModelContext()
        let screenplay = createTestScreenplay(elementCount: 10)

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        #expect(document.elements.first?.chapterIndex == 0, "First element should have chapterIndex 0")
        #expect(document.elements.first?.orderIndex == 1, "First element should have orderIndex 1 (1-based)")
    }

    @Test("OrderIndex is continuous with no gaps within chapter")
    @MainActor
    func testOrderIndexIsContinuous() async throws {
        let context = try createInMemoryModelContext()
        let screenplay = createTestScreenplay(elementCount: 200)

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Check for continuous sequence (chapterIndex=0, orderIndex 1-based)
        for i in 0..<200 {
            let element = document.elements[i]
            #expect(element.chapterIndex == 0, "All elements should be in chapter 0")
            #expect(element.orderIndex == i + 1, "OrderIndex should be continuous without gaps (1-based)")
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

        // Verify every element is in correct position with composite key
        for (index, element) in document.elements.enumerated() {
            #expect(element.elementText == originalTexts[index],
                    "Element \(index) should maintain original position")
            #expect(element.chapterIndex == 0,
                    "Element should be in chapter 0")
            #expect(element.orderIndex == index + 1,
                    "Element \(index) should have orderIndex \(index + 1) (1-based)")
        }
    }

    // MARK: - Query Sorting Tests

    @Test("Fetched elements are sorted by composite key (chapterIndex, orderIndex)")
    @MainActor
    func testQueriedElementsSortedByOrderIndex() async throws {
        let context = try createInMemoryModelContext()
        let screenplay = createTestScreenplay(elementCount: 100)

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        try context.save()

        // Fetch with explicit composite key sort (simulating @Query behavior)
        let descriptor = FetchDescriptor<GuionElementModel>(
            sortBy: [
                SortDescriptor(\.chapterIndex),
                SortDescriptor(\.orderIndex)
            ]
        )
        let fetchedElements = try context.fetch(descriptor)

        #expect(fetchedElements.count == 100, "Should fetch 100 elements")

        // Verify fetched elements are in order (chapterIndex=0, orderIndex 1-based)
        for (index, element) in fetchedElements.enumerated() {
            #expect(element.chapterIndex == 0,
                    "Elements without chapters should have chapterIndex=0")
            #expect(element.orderIndex == index + 1,
                    "Fetched element at position \(index) should have orderIndex \(index + 1)")
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
            sortBy: [
                SortDescriptor(\.chapterIndex),
                SortDescriptor(\.orderIndex)
            ]
        )

        let doc1Elements = try context.fetch(descriptor)

        #expect(doc1Elements.count == 50, "Should fetch only doc1's 50 elements")

        // Verify composite key order
        for (index, element) in doc1Elements.enumerated() {
            #expect(element.chapterIndex == 0,
                    "Elements without chapters should have chapterIndex=0")
            #expect(element.orderIndex == index + 1,
                    "Element should have correct orderIndex (1-based)")
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

    @Test("Single element has chapterIndex=0, orderIndex=1")
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
        #expect(document.elements.first?.chapterIndex == 0, "Single element should have chapterIndex 0")
        #expect(document.elements.first?.orderIndex == 1, "Single element should have orderIndex 1 (1-based)")
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

        // Verify order is exactly as written with composite key
        for (index, element) in document.elements.enumerated() {
            #expect(element.elementText == elements[index].elementText,
                    "Element type should not affect ordering")
            #expect(element.chapterIndex == 0,
                    "All elements should be in chapter 0")
            #expect(element.orderIndex == index + 1,
                    "Each element should have correct orderIndex (1-based)")
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
        #expect(elapsed < 4.0, "Should complete in under 4 seconds (accounts for CI environment variance)")

        // Verify all have correct composite key (chapterIndex=0, orderIndex=1-based)
        for (index, element) in document.elements.enumerated() {
            #expect(element.chapterIndex == 0,
                    "Large screenplay without chapters should have chapterIndex=0")
            #expect(element.orderIndex == index + 1,
                    "Large screenplay should maintain correct orderIndex (1-based)")
        }
    }

    // MARK: - Chapter-Based Ordering Tests

    @Test("Screenplay with no chapters: all elements have chapterIndex=0 with sequential orderIndex")
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

        // All elements should have chapterIndex=0 with sequential orderIndex
        for (index, element) in document.elements.enumerated() {
            #expect(element.chapterIndex == 0,
                    "Without chapters, all elements should have chapterIndex=0")
            #expect(element.orderIndex == index + 1,
                    "Without chapters, orderIndex should be sequential from 1")
        }
    }

    @Test("First element in Chapter 1 has chapterIndex=1, orderIndex=1")
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

        #expect(document.elements[0].chapterIndex == 0, "Pre-chapter element")
        #expect(document.elements[0].orderIndex == 1, "Pre-chapter element is position 1")
        #expect(document.elements[1].chapterIndex == 1, "Chapter 1 heading")
        #expect(document.elements[1].orderIndex == 1, "Chapter 1 heading is position 1")
        #expect(document.elements[2].chapterIndex == 1, "First scene in Chapter 1")
        #expect(document.elements[2].orderIndex == 2, "First scene is position 2")
        #expect(document.elements[3].chapterIndex == 1, "Second element in Chapter 1")
        #expect(document.elements[3].orderIndex == 3, "Second element is position 3")
    }

    @Test("Two chapters use composite key (chapterIndex, orderIndex)")
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
        #expect(document.elements[0].chapterIndex == 1, "Chapter 1 heading")
        #expect(document.elements[0].orderIndex == 1, "Chapter 1 heading is position 1")
        #expect(document.elements[1].chapterIndex == 1, "Chapter 1 element 1")
        #expect(document.elements[1].orderIndex == 2, "Chapter 1 element 1 is position 2")
        #expect(document.elements[2].chapterIndex == 1, "Chapter 1 element 2")
        #expect(document.elements[2].orderIndex == 3, "Chapter 1 element 2 is position 3")
        #expect(document.elements[3].chapterIndex == 1, "Chapter 1 element 3")
        #expect(document.elements[3].orderIndex == 4, "Chapter 1 element 3 is position 4")

        // Chapter 2 elements
        #expect(document.elements[4].chapterIndex == 2, "Chapter 2 heading")
        #expect(document.elements[4].orderIndex == 1, "Chapter 2 heading is position 1")
        #expect(document.elements[5].chapterIndex == 2, "Chapter 2 element 1")
        #expect(document.elements[5].orderIndex == 2, "Chapter 2 element 1 is position 2")
        #expect(document.elements[6].chapterIndex == 2, "Chapter 2 element 2")
        #expect(document.elements[6].orderIndex == 3, "Chapter 2 element 2 is position 3")
    }

    @Test("Five chapters maintain correct composite key ordering")
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

        // Verify each chapter's composite key (chapterIndex, orderIndex)
        for chapterNum in 1...5 {
            let baseIndex = (chapterNum - 1) * 4 // 4 elements per chapter

            // Chapter heading
            #expect(document.elements[baseIndex].chapterIndex == chapterNum,
                    "Chapter \(chapterNum) heading has chapterIndex=\(chapterNum)")
            #expect(document.elements[baseIndex].orderIndex == 1,
                    "Chapter \(chapterNum) heading is position 1")

            // Chapter elements
            for i in 1...3 {
                let elemIndex = baseIndex + i
                #expect(document.elements[elemIndex].chapterIndex == chapterNum,
                        "Chapter \(chapterNum) element \(i) has chapterIndex=\(chapterNum)")
                #expect(document.elements[elemIndex].orderIndex == i + 1,
                        "Chapter \(chapterNum) element \(i) is position \(i + 1)")
            }
        }
    }

    @Test("Elements before first chapter have chapterIndex=0")
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

        // Pre-chapter elements (chapterIndex=0)
        #expect(document.elements[0].chapterIndex == 0, "Pre-chapter element 1")
        #expect(document.elements[0].orderIndex == 1, "Pre-chapter element 1 is position 1")
        #expect(document.elements[1].chapterIndex == 0, "Pre-chapter element 2")
        #expect(document.elements[1].orderIndex == 2, "Pre-chapter element 2 is position 2")
        #expect(document.elements[2].chapterIndex == 0, "Pre-chapter element 3")
        #expect(document.elements[2].orderIndex == 3, "Pre-chapter element 3 is position 3")

        // Chapter 1 elements (chapterIndex=1)
        #expect(document.elements[3].chapterIndex == 1, "Chapter 1 heading")
        #expect(document.elements[3].orderIndex == 1, "Chapter 1 heading is position 1")
        #expect(document.elements[4].chapterIndex == 1, "Chapter 1 element")
        #expect(document.elements[4].orderIndex == 2, "Chapter 1 element is position 2")
    }

    @Test("Only section heading level 2 triggers new chapterIndex")
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

        // Non-chapter section headings remain in chapterIndex=0
        #expect(document.elements[0].chapterIndex == 0, "Level 1 section in pre-chapter")
        #expect(document.elements[0].orderIndex == 1, "Level 1 section is position 1")
        #expect(document.elements[1].chapterIndex == 0, "Action after level 1")
        #expect(document.elements[1].orderIndex == 2, "Action is position 2")
        #expect(document.elements[2].chapterIndex == 0, "Level 3 section")
        #expect(document.elements[2].orderIndex == 3, "Level 3 section is position 3")
        #expect(document.elements[3].chapterIndex == 0, "Action after level 3")
        #expect(document.elements[3].orderIndex == 4, "Action is position 4")

        // Only level 2 triggers chapterIndex increment
        #expect(document.elements[4].chapterIndex == 1, "Level 2 section starts Chapter 1")
        #expect(document.elements[4].orderIndex == 1, "Chapter 1 heading is position 1")
        #expect(document.elements[5].chapterIndex == 1, "Action in Chapter 1")
        #expect(document.elements[5].orderIndex == 2, "Action is position 2")
    }

    @Test("Large screenplay with chapters maintains composite key ordering")
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

        // Verify chapter headings
        #expect(document.elements[0].chapterIndex == 1, "Chapter 1 heading")
        #expect(document.elements[0].orderIndex == 1, "Chapter 1 heading is position 1")
        #expect(document.elements[31].chapterIndex == 2, "Chapter 2 heading")
        #expect(document.elements[31].orderIndex == 1, "Chapter 2 heading is position 1")
        #expect(document.elements[62].chapterIndex == 3, "Chapter 3 heading")
        #expect(document.elements[62].orderIndex == 1, "Chapter 3 heading is position 1")

        // Verify last elements in each chapter
        #expect(document.elements[30].chapterIndex == 1, "Last element of Chapter 1")
        #expect(document.elements[30].orderIndex == 31, "Last element is position 31")
        #expect(document.elements[61].chapterIndex == 2, "Last element of Chapter 2")
        #expect(document.elements[61].orderIndex == 31, "Last element is position 31")
        #expect(document.elements[92].chapterIndex == 3, "Last element of Chapter 3")
        #expect(document.elements[92].orderIndex == 31, "Last element is position 31")
    }
}
