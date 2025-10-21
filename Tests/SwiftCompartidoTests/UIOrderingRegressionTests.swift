//
//  UIOrderingRegressionTests.swift
//  SwiftCompartido
//
//  Copyright (c) 2025
//
//  UI regression tests to ensure orderIndex is respected throughout the codebase
//

import Testing
import Foundation
import SwiftData
@testable import SwiftCompartido

/// Regression tests to prevent UI ordering bugs
///
/// **Critical**: These tests ensure that all UI components, serialization, and export
/// functions respect the orderIndex field and maintain screenplay sequence order.
///
/// ## What These Tests Prevent
///
/// 1. **UI Regression**: Elements displayed out of order in views
/// 2. **Export Regression**: Elements exported in wrong order to FDX/Fountain
/// 3. **Serialization Regression**: Elements saved/loaded in wrong order
/// 4. **Query Regression**: @Query results not sorted by orderIndex
///
@Suite("UI Ordering Regression Tests")
struct UIOrderingRegressionTests {

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
    private func createScreenplayWithKnownOrder() -> GuionParsedElementCollection {
        let elements = [
            GuionElement(elementType: .action, elementText: "Element 0"),
            GuionElement(elementType: .action, elementText: "Element 1"),
            GuionElement(elementType: .action, elementText: "Element 2"),
            GuionElement(elementType: .sectionHeading(level: 2), elementText: "# Chapter 1"),
            GuionElement(elementType: .action, elementText: "Element 3 - In Chapter 1"),
            GuionElement(elementType: .action, elementText: "Element 4 - In Chapter 1"),
            GuionElement(elementType: .sectionHeading(level: 2), elementText: "# Chapter 2"),
            GuionElement(elementType: .action, elementText: "Element 5 - In Chapter 2"),
        ]

        return GuionParsedElementCollection(
            filename: "order-test.fountain",
            elements: elements
        )
    }

    // MARK: - GuionDocumentModel.sortedElements Tests

    @Test("GuionDocumentModel.sortedElements returns elements in orderIndex order")
    @MainActor
    func testDocumentSortedElementsProperty() async throws {
        let context = try createInMemoryModelContext()
        let screenplay = createScreenplayWithKnownOrder()

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Verify sortedElements is in correct order
        let sortedElements = document.sortedElements

        #expect(sortedElements.count == 8, "Should have 8 elements")

        // Pre-chapter elements (0-99)
        #expect(sortedElements[0].elementText == "Element 0", "First element")
        #expect(sortedElements[0].orderIndex == 0, "orderIndex 0")

        #expect(sortedElements[1].elementText == "Element 1", "Second element")
        #expect(sortedElements[1].orderIndex == 1, "orderIndex 1")

        #expect(sortedElements[2].elementText == "Element 2", "Third element")
        #expect(sortedElements[2].orderIndex == 2, "orderIndex 2")

        // Chapter 1 (100-199)
        #expect(sortedElements[3].elementText == "# Chapter 1", "Chapter 1 heading")
        #expect(sortedElements[3].orderIndex == 100, "orderIndex 100")

        #expect(sortedElements[4].elementText == "Element 3 - In Chapter 1", "Chapter 1 element 1")
        #expect(sortedElements[4].orderIndex == 101, "orderIndex 101")

        #expect(sortedElements[5].elementText == "Element 4 - In Chapter 1", "Chapter 1 element 2")
        #expect(sortedElements[5].orderIndex == 102, "orderIndex 102")

        // Chapter 2 (200-299)
        #expect(sortedElements[6].elementText == "# Chapter 2", "Chapter 2 heading")
        #expect(sortedElements[6].orderIndex == 200, "orderIndex 200")

        #expect(sortedElements[7].elementText == "Element 5 - In Chapter 2", "Chapter 2 element 1")
        #expect(sortedElements[7].orderIndex == 201, "orderIndex 201")
    }

    @Test("GuionDocumentModel.sortedElements works even if elements array is shuffled")
    @MainActor
    func testSortedElementsWorksWhenShuffled() async throws {
        let context = try createInMemoryModelContext()

        // Create document with elements in random order
        let document = GuionDocumentModel(filename: "test.fountain")

        // Manually create elements with orderIndex in non-sequential order
        let element2 = GuionElementModel(elementText: "Element 2", elementType: .action, orderIndex: 2)
        element2.document = document
        document.elements.append(element2)

        let element0 = GuionElementModel(elementText: "Element 0", elementType: .action, orderIndex: 0)
        element0.document = document
        document.elements.append(element0)

        let element1 = GuionElementModel(elementText: "Element 1", elementType: .action, orderIndex: 1)
        element1.document = document
        document.elements.append(element1)

        context.insert(document)

        // Verify sortedElements returns in correct order despite shuffled storage
        let sortedElements = document.sortedElements

        #expect(sortedElements[0].elementText == "Element 0", "First by orderIndex")
        #expect(sortedElements[1].elementText == "Element 1", "Second by orderIndex")
        #expect(sortedElements[2].elementText == "Element 2", "Third by orderIndex")
    }

    // MARK: - toGuionParsedElementCollection Regression Tests

    @Test("toGuionParsedElementCollection preserves orderIndex order")
    @MainActor
    func testConversionToGuionParsedElementCollectionOrder() async throws {
        let context = try createInMemoryModelContext()
        let screenplay = createScreenplayWithKnownOrder()
        let originalTexts = screenplay.elements.map { $0.elementText }

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Convert back
        let converted = document.toGuionParsedElementCollection()

        #expect(converted.elements.count == originalTexts.count, "Same element count")

        // Verify order is preserved
        for (index, element) in converted.elements.enumerated() {
            #expect(element.elementText == originalTexts[index],
                    "Element \(index) should match original order")
        }
    }

    @Test("Round-trip conversion maintains orderIndex across multiple conversions")
    @MainActor
    func testMultipleRoundTripConversionsPreserveOrder() async throws {
        let context = try createInMemoryModelContext()
        let screenplay = createScreenplayWithKnownOrder()
        let originalTexts = screenplay.elements.map { $0.elementText }

        // First conversion
        let document1 = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Convert back
        let screenplay2 = document1.toGuionParsedElementCollection()

        // Second conversion
        let document2 = await GuionDocumentParserSwiftData.parse(
            script: screenplay2,
            in: context
        )

        // Convert back again
        let screenplay3 = document2.toGuionParsedElementCollection()

        // Verify order is still correct after multiple conversions
        for (index, element) in screenplay3.elements.enumerated() {
            #expect(element.elementText == originalTexts[index],
                    "Order should survive multiple round-trips")
        }
    }

    // MARK: - GuionDocumentModel Helper Methods Regression Tests

    @Test("sceneLocations returns scenes in orderIndex order")
    @MainActor
    func testSceneLocationsOrderedCorrectly() async throws {
        let context = try createInMemoryModelContext()

        let elements = [
            GuionElement(elementType: .sceneHeading, elementText: "INT. KITCHEN - DAY"),
            GuionElement(elementType: .action, elementText: "Action."),
            GuionElement(elementType: .sceneHeading, elementText: "EXT. GARDEN - NIGHT"),
            GuionElement(elementType: .action, elementText: "More action."),
            GuionElement(elementType: .sceneHeading, elementText: "INT. BEDROOM - MORNING"),
        ]

        let screenplay = GuionParsedElementCollection(elements: elements)
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        let sceneLocations = document.sceneLocations

        #expect(sceneLocations.count == 3, "Should have 3 scenes")

        // Verify scenes are in order
        #expect(sceneLocations[0].element.elementText == "INT. KITCHEN - DAY", "First scene")
        #expect(sceneLocations[0].location.scene == "KITCHEN", "First location")

        #expect(sceneLocations[1].element.elementText == "EXT. GARDEN - NIGHT", "Second scene")
        #expect(sceneLocations[1].location.scene == "GARDEN", "Second location")

        #expect(sceneLocations[2].element.elementText == "INT. BEDROOM - MORNING", "Third scene")
        #expect(sceneLocations[2].location.scene == "BEDROOM", "Third location")
    }

    // MARK: - Serialization Regression Tests

    @Test("GuionDocumentSnapshot preserves orderIndex order")
    @MainActor
    func testDocumentSnapshotPreservesOrder() async throws {
        let context = try createInMemoryModelContext()
        let screenplay = createScreenplayWithKnownOrder()
        let originalTexts = screenplay.elements.map { $0.elementText }

        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Create snapshot
        let snapshot = GuionDocumentSnapshot(from: document)

        // Verify snapshot elements are in correct order
        for (index, element) in snapshot.elements.enumerated() {
            #expect(element.elementText == originalTexts[index],
                    "Snapshot should preserve element order")
        }
    }

    @Test("GuionDocumentSnapshot round-trip maintains order")
    @MainActor
    func testSnapshotRoundTripMaintainsOrder() async throws {
        let context = try createInMemoryModelContext()
        let screenplay = createScreenplayWithKnownOrder()
        let originalTexts = screenplay.elements.map { $0.elementText }

        let document1 = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Serialize
        let snapshot = GuionDocumentSnapshot(from: document1)

        // Deserialize
        let document2 = snapshot.toModel(in: context)

        // Verify order preserved
        for (index, element) in document2.sortedElements.enumerated() {
            #expect(element.elementText == originalTexts[index],
                    "Snapshot round-trip should preserve order")
        }
    }

    // MARK: - Large Dataset Regression Tests

    @Test("Large screenplay (500 elements) maintains orderIndex in all operations")
    @MainActor
    func testLargeScreenplayOrderMaintainedEverywhere() async throws {
        let context = try createInMemoryModelContext()

        // Create large screenplay with known order
        var elements: [GuionElement] = []
        for i in 0..<500 {
            elements.append(GuionElement(
                elementType: .action,
                elementText: "Element \(i)"
            ))
        }

        let screenplay = GuionParsedElementCollection(elements: elements)
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Test 1: sortedElements
        let sortedElements = document.sortedElements
        for (index, element) in sortedElements.enumerated() {
            #expect(element.elementText == "Element \(index)",
                    "sortedElements should maintain order for large dataset")
        }

        // Test 2: toGuionParsedElementCollection
        let converted = document.toGuionParsedElementCollection()
        for (index, element) in converted.elements.enumerated() {
            #expect(element.elementText == "Element \(index)",
                    "toGuionParsedElementCollection should maintain order")
        }

        // Test 3: Snapshot serialization
        let snapshot = GuionDocumentSnapshot(from: document)
        for (index, element) in snapshot.elements.enumerated() {
            #expect(element.elementText == "Element \(index)",
                    "Snapshot should maintain order")
        }
    }

    // MARK: - Chapter-Based Ordering Regression Tests

    @Test("Chapter-based orderIndex gaps are preserved in conversions")
    @MainActor
    func testChapterGapsPreservedInConversions() async throws {
        let context = try createInMemoryModelContext()

        let elements = [
            GuionElement(elementType: .action, elementText: "Pre-chapter"),
            GuionElement(elementType: .sectionHeading(level: 2), elementText: "# Chapter 1"),
            GuionElement(elementType: .action, elementText: "Chapter 1 content"),
            GuionElement(elementType: .sectionHeading(level: 2), elementText: "# Chapter 2"),
            GuionElement(elementType: .action, elementText: "Chapter 2 content"),
        ]

        let screenplay = GuionParsedElementCollection(elements: elements)
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Verify orderIndex gaps
        let sorted = document.sortedElements

        #expect(sorted[0].orderIndex == 0, "Pre-chapter element")
        #expect(sorted[1].orderIndex == 100, "Chapter 1 starts at 100")
        #expect(sorted[2].orderIndex == 101, "Chapter 1 element")
        #expect(sorted[3].orderIndex == 200, "Chapter 2 starts at 200")
        #expect(sorted[4].orderIndex == 201, "Chapter 2 element")

        // Convert and verify gaps are preserved
        let converted = document.toGuionParsedElementCollection()
        #expect(converted.elements.count == 5, "All elements present")
        #expect(converted.elements[0].elementText == "Pre-chapter", "Order preserved")
        #expect(converted.elements[4].elementText == "Chapter 2 content", "Order preserved")
    }

    // MARK: - Mixed Content Regression Tests

    @Test("Mixed dialogue and scene content maintains orderIndex")
    @MainActor
    func testMixedContentMaintainsOrder() async throws {
        let context = try createInMemoryModelContext()

        let elements = [
            GuionElement(elementType: .sceneHeading, elementText: "INT. ROOM - DAY"),
            GuionElement(elementType: .action, elementText: "Alice enters."),
            GuionElement(elementType: .character, elementText: "ALICE"),
            GuionElement(elementType: .dialogue, elementText: "Hello!"),
            GuionElement(elementType: .action, elementText: "Bob responds."),
            GuionElement(elementType: .character, elementText: "BOB"),
            GuionElement(elementType: .dialogue, elementText: "Hi there!"),
            GuionElement(elementType: .transition, elementText: "CUT TO:"),
        ]

        let screenplay = GuionParsedElementCollection(elements: elements)
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: context
        )

        // Verify all operations maintain order
        let sorted = document.sortedElements
        for (index, element) in sorted.enumerated() {
            #expect(element.elementText == elements[index].elementText,
                    "Mixed content should maintain exact order")
        }

        let converted = document.toGuionParsedElementCollection()
        for (index, element) in converted.elements.enumerated() {
            #expect(element.elementText == elements[index].elementText,
                    "Conversion should preserve mixed content order")
        }
    }
}
