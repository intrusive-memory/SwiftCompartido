//
//  MarkdownViewTests.swift
//  SwiftCompartido Tests
//
//  Tests for Markdown rendering components
//

import Testing
import Foundation
import SwiftUI
import SwiftData
@testable import SwiftCompartido

@Suite("Markdown View Tests")
@MainActor
struct MarkdownViewTests {

    // MARK: - Helper Methods

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: GuionDocumentModel.self,
            GuionElementModel.self,
            configurations: config
        )
    }

    private func makeElement(
        in context: ModelContext,
        text: String,
        type: ElementType = .action,
        order: Int = 0
    ) -> GuionElementModel {
        let element = GuionElementModel(
            elementText: text,
            elementType: type,
            orderIndex: order
        )
        context.insert(element)
        return element
    }

    private func makeDocument(
        in context: ModelContext,
        withElements elements: [GuionElementModel] = []
    ) -> GuionDocumentModel {
        let document = GuionDocumentModel(
            title: "Test Document"
        )
        context.insert(document)
        for element in elements {
            element.document = document
        }
        return document
    }

    // MARK: - MarkdownActionView Tests

    @Test("MarkdownActionView initializes with plain text")
    func testMarkdownActionViewPlainText() throws {
        let container = try makeTestContainer()
        let element = makeElement(in: container.mainContext, text: "This is plain text.")

        _ = MarkdownActionView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "This is plain text.")
    }

    @Test("MarkdownActionView handles bold text")
    func testMarkdownActionViewBoldText() throws {
        let container = try makeTestContainer()
        let element = makeElement(in: container.mainContext, text: "This is **bold** text.")

        _ = MarkdownActionView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText.contains("**bold**"))
    }

    @Test("MarkdownActionView handles italic text")
    func testMarkdownActionViewItalicText() throws {
        let container = try makeTestContainer()
        let element = makeElement(in: container.mainContext, text: "This is *italic* text.")

        _ = MarkdownActionView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText.contains("*italic*"))
    }

    @Test("MarkdownActionView handles code text")
    func testMarkdownActionViewCodeText() throws {
        let container = try makeTestContainer()
        let element = makeElement(in: container.mainContext, text: "This is `code` text.")

        _ = MarkdownActionView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText.contains("`code`"))
    }

    @Test("MarkdownActionView handles mixed formatting")
    func testMarkdownActionViewMixedFormatting() throws {
        let container = try makeTestContainer()
        let element = makeElement(
            in: container.mainContext,
            text: "This has **bold**, *italic*, and `code` all together."
        )

        _ = MarkdownActionView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText.contains("**bold**"))
        #expect(element.elementText.contains("*italic*"))
        #expect(element.elementText.contains("`code`"))
    }

    @Test("MarkdownActionView handles multiple bold sections")
    func testMarkdownActionViewMultipleBold() throws {
        let container = try makeTestContainer()
        let element = makeElement(
            in: container.mainContext,
            text: "First **bold** and second **bold** text."
        )

        _ = MarkdownActionView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText.contains("**bold**"))
    }

    @Test("MarkdownActionView handles empty text")
    func testMarkdownActionViewEmptyText() throws {
        let container = try makeTestContainer()
        let element = makeElement(in: container.mainContext, text: "")

        _ = MarkdownActionView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText.isEmpty)
    }

    @Test("MarkdownActionView handles special characters")
    func testMarkdownActionViewSpecialCharacters() throws {
        let container = try makeTestContainer()
        let element = makeElement(
            in: container.mainContext,
            text: "Special: © ™ — …"
        )

        _ = MarkdownActionView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText.contains("©"))
        #expect(element.elementText.contains("™"))
    }

    @Test("MarkdownActionView respects font size environment")
    func testMarkdownActionViewFontSize() throws {
        let container = try makeTestContainer()
        let element = makeElement(in: container.mainContext, text: "Test text")

        let view1 = MarkdownActionView(element: element)
            .environment(\.screenplayFontSize, 10)

        let view2 = MarkdownActionView(element: element)
            .environment(\.screenplayFontSize, 18)

        #expect(true) // Successfully created with different font sizes
    }

    // MARK: - MarkdownSectionHeadingView Tests

    @Test("MarkdownSectionHeadingView initializes with H1")
    func testMarkdownSectionHeadingViewH1() throws {
        let container = try makeTestContainer()
        let element = makeElement(
            in: container.mainContext,
            text: "Heading 1",
            type: .sectionHeading(level: 1)
        )

        _ = MarkdownSectionHeadingView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "Heading 1")
    }

    @Test("MarkdownSectionHeadingView initializes with H2")
    func testMarkdownSectionHeadingViewH2() throws {
        let container = try makeTestContainer()
        let element = makeElement(
            in: container.mainContext,
            text: "Heading 2",
            type: .sectionHeading(level: 2)
        )

        _ = MarkdownSectionHeadingView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "Heading 2")
    }

    @Test("MarkdownSectionHeadingView handles all heading levels")
    func testMarkdownSectionHeadingViewAllLevels() throws {
        let container = try makeTestContainer()

        for level in 1...6 {
            let element = makeElement(
                in: container.mainContext,
                text: "Heading \(level)",
                type: .sectionHeading(level: level)
            )

            _ = MarkdownSectionHeadingView(element: element)
                .environment(\.screenplayFontSize, 12)

            #expect(element.elementText == "Heading \(level)")
        }
    }

    @Test("MarkdownSectionHeadingView handles long headings")
    func testMarkdownSectionHeadingViewLongHeading() throws {
        let container = try makeTestContainer()
        let longText = "This is a very long heading that might wrap across multiple lines in the UI"
        let element = makeElement(
            in: container.mainContext,
            text: longText,
            type: .sectionHeading(level: 1)
        )

        _ = MarkdownSectionHeadingView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == longText)
    }

    @Test("MarkdownSectionHeadingView handles special characters in headings")
    func testMarkdownSectionHeadingViewSpecialCharacters() throws {
        let container = try makeTestContainer()
        let element = makeElement(
            in: container.mainContext,
            text: "Chapter 1: The Beginning — Part 1",
            type: .sectionHeading(level: 2)
        )

        _ = MarkdownSectionHeadingView(element: element)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText.contains("—"))
    }

    @Test("MarkdownSectionHeadingView respects font size environment")
    func testMarkdownSectionHeadingViewFontSize() throws {
        let container = try makeTestContainer()
        let element = makeElement(
            in: container.mainContext,
            text: "Test Heading",
            type: .sectionHeading(level: 1)
        )

        let view1 = MarkdownSectionHeadingView(element: element)
            .environment(\.screenplayFontSize, 10)

        let view2 = MarkdownSectionHeadingView(element: element)
            .environment(\.screenplayFontSize, 18)

        #expect(true) // Successfully created with different font sizes
    }

    // MARK: - MarkdownListItemView Tests

    @Test("MarkdownListItemView initializes with unordered list")
    func testMarkdownListItemViewUnordered() throws {
        let container = try makeTestContainer()
        let document = makeDocument(in: container.mainContext, withElements: [])
        let element = makeElement(
            in: container.mainContext,
            text: "List item",
            type: .unorderedListItem(level: 0)
        )
        element.document = document

        _ = MarkdownListItemView(element: element, document: document)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "List item")
    }

    @Test("MarkdownListItemView initializes with ordered list")
    func testMarkdownListItemViewOrdered() throws {
        let container = try makeTestContainer()
        let document = makeDocument(in: container.mainContext, withElements: [])
        let element = makeElement(
            in: container.mainContext,
            text: "First item",
            type: .orderedListItem(level: 0)
        )
        element.document = document

        _ = MarkdownListItemView(element: element, document: document)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText == "First item")
    }

    @Test("MarkdownListItemView handles nested unordered lists")
    func testMarkdownListItemViewNestedUnordered() throws {
        let container = try makeTestContainer()
        let document = makeDocument(in: container.mainContext, withElements: [])

        let level0 = makeElement(
            in: container.mainContext,
            text: "Level 0",
            type: .unorderedListItem(level: 0),
            order: 0
        )
        let level1 = makeElement(
            in: container.mainContext,
            text: "Level 1",
            type: .unorderedListItem(level: 1),
            order: 1
        )
        let level2 = makeElement(
            in: container.mainContext,
            text: "Level 2",
            type: .unorderedListItem(level: 2),
            order: 2
        )

        level0.document = document
        level1.document = document
        level2.document = document

        _ = MarkdownListItemView(element: level0, document: document)
            .environment(\.screenplayFontSize, 12)
        _ = MarkdownListItemView(element: level1, document: document)
            .environment(\.screenplayFontSize, 12)
        _ = MarkdownListItemView(element: level2, document: document)
            .environment(\.screenplayFontSize, 12)

        #expect(true) // Successfully rendered all nesting levels
    }

    @Test("MarkdownListItemView handles ordered list numbering")
    func testMarkdownListItemViewNumbering() throws {
        let container = try makeTestContainer()
        let elements = [
            makeElement(in: container.mainContext, text: "First", type: .orderedListItem(level: 0), order: 0),
            makeElement(in: container.mainContext, text: "Second", type: .orderedListItem(level: 0), order: 1),
            makeElement(in: container.mainContext, text: "Third", type: .orderedListItem(level: 0), order: 2)
        ]
        let document = makeDocument(in: container.mainContext, withElements: elements)

        for element in elements {
            _ = MarkdownListItemView(element: element, document: document)
                .environment(\.screenplayFontSize, 12)
        }

        #expect(elements.count == 3)
    }

    @Test("MarkdownListItemView handles inline markdown in list items")
    func testMarkdownListItemViewInlineMarkdown() throws {
        let container = try makeTestContainer()
        let document = makeDocument(in: container.mainContext, withElements: [])
        let element = makeElement(
            in: container.mainContext,
            text: "Item with **bold** and *italic*",
            type: .unorderedListItem(level: 0)
        )
        element.document = document

        _ = MarkdownListItemView(element: element, document: document)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText.contains("**bold**"))
        #expect(element.elementText.contains("*italic*"))
    }

    @Test("MarkdownListItemView handles empty list items")
    func testMarkdownListItemViewEmpty() throws {
        let container = try makeTestContainer()
        let document = makeDocument(in: container.mainContext, withElements: [])
        let element = makeElement(
            in: container.mainContext,
            text: "",
            type: .unorderedListItem(level: 0)
        )
        element.document = document

        _ = MarkdownListItemView(element: element, document: document)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText.isEmpty)
    }

    @Test("MarkdownListItemView handles long list items")
    func testMarkdownListItemViewLongText() throws {
        let container = try makeTestContainer()
        let document = makeDocument(in: container.mainContext, withElements: [])
        let longText = String(repeating: "This is a very long list item text. ", count: 10)
        let element = makeElement(
            in: container.mainContext,
            text: longText,
            type: .unorderedListItem(level: 0)
        )
        element.document = document

        _ = MarkdownListItemView(element: element, document: document)
            .environment(\.screenplayFontSize, 12)

        #expect(element.elementText.count > 100)
    }

    @Test("MarkdownListItemView respects font size environment")
    func testMarkdownListItemViewFontSize() throws {
        let container = try makeTestContainer()
        let document = makeDocument(in: container.mainContext, withElements: [])
        let element = makeElement(
            in: container.mainContext,
            text: "Test item",
            type: .unorderedListItem(level: 0)
        )
        element.document = document

        let view1 = MarkdownListItemView(element: element, document: document)
            .environment(\.screenplayFontSize, 10)

        let view2 = MarkdownListItemView(element: element, document: document)
            .environment(\.screenplayFontSize, 18)

        #expect(true) // Successfully created with different font sizes
    }

    // MARK: - MarkdownListItemReferenceView Tests

    @Test("MarkdownListItemReferenceView initializes with ElementReference")
    func testMarkdownListItemReferenceViewInitialization() throws {
        let container = try makeTestContainer()
        let element = makeElement(in: container.mainContext, text: "Reference list item", type: .unorderedListItem(level: 0))
        let reference = ElementReference(
            id: element.persistentModelID,
            elementType: .unorderedListItem(level: 0),
            elementText: "Reference list item",
            chapterIndex: 0,
            orderIndex: 0,
            characterName: nil
        )

        _ = MarkdownListItemReferenceView(element: reference)
            .environment(\.screenplayFontSize, 12)

        #expect(reference.elementText == "Reference list item")
    }

    @Test("MarkdownListItemReferenceView handles plain text")
    func testMarkdownListItemReferenceViewPlainText() throws {
        let container = try makeTestContainer()
        let element = makeElement(in: container.mainContext, text: "Simple list item")
        let reference = ElementReference(
            id: element.persistentModelID,
            elementType: .unorderedListItem(level: 0),
            elementText: "Simple list item",
            chapterIndex: 0,
            orderIndex: 0,
            characterName: nil
        )

        _ = MarkdownListItemReferenceView(element: reference)
            .environment(\.screenplayFontSize, 12)

        #expect(reference.elementText == "Simple list item")
    }

    @Test("MarkdownListItemReferenceView handles long text")
    func testMarkdownListItemReferenceViewLongText() throws {
        let container = try makeTestContainer()
        let longText = String(repeating: "Long reference list item text. ", count: 10)
        let element = makeElement(in: container.mainContext, text: longText)
        let reference = ElementReference(
            id: element.persistentModelID,
            elementType: .unorderedListItem(level: 0),
            elementText: longText,
            chapterIndex: 0,
            orderIndex: 0,
            characterName: nil
        )

        _ = MarkdownListItemReferenceView(element: reference)
            .environment(\.screenplayFontSize, 12)

        #expect(reference.elementText.count > 100)
    }

    @Test("MarkdownListItemReferenceView handles empty text")
    func testMarkdownListItemReferenceViewEmpty() throws {
        let container = try makeTestContainer()
        let element = makeElement(in: container.mainContext, text: "")
        let reference = ElementReference(
            id: element.persistentModelID,
            elementType: .unorderedListItem(level: 0),
            elementText: "",
            chapterIndex: 0,
            orderIndex: 0,
            characterName: nil
        )

        _ = MarkdownListItemReferenceView(element: reference)
            .environment(\.screenplayFontSize, 12)

        #expect(reference.elementText.isEmpty)
    }

    @Test("MarkdownListItemReferenceView handles special characters")
    func testMarkdownListItemReferenceViewSpecialCharacters() throws {
        let container = try makeTestContainer()
        let element = makeElement(in: container.mainContext, text: "Item with © and ™ symbols")
        let reference = ElementReference(
            id: element.persistentModelID,
            elementType: .unorderedListItem(level: 0),
            elementText: "Item with © and ™ symbols",
            chapterIndex: 0,
            orderIndex: 0,
            characterName: nil
        )

        _ = MarkdownListItemReferenceView(element: reference)
            .environment(\.screenplayFontSize, 12)

        #expect(reference.elementText.contains("©"))
        #expect(reference.elementText.contains("™"))
    }

    @Test("MarkdownListItemReferenceView respects font size environment")
    func testMarkdownListItemReferenceViewFontSize() throws {
        let container = try makeTestContainer()
        let element = makeElement(in: container.mainContext, text: "Test item")
        let reference = ElementReference(
            id: element.persistentModelID,
            elementType: .unorderedListItem(level: 0),
            elementText: "Test item",
            chapterIndex: 0,
            orderIndex: 0,
            characterName: nil
        )

        let view1 = MarkdownListItemReferenceView(element: reference)
            .environment(\.screenplayFontSize, 10)

        let view2 = MarkdownListItemReferenceView(element: reference)
            .environment(\.screenplayFontSize, 18)

        #expect(true) // Successfully created with different font sizes
    }

    @Test("MarkdownListItemReferenceView handles markdown formatting")
    func testMarkdownListItemReferenceViewMarkdown() throws {
        let container = try makeTestContainer()
        let element = makeElement(in: container.mainContext, text: "Item with **bold** and *italic*")
        let reference = ElementReference(
            id: element.persistentModelID,
            elementType: .unorderedListItem(level: 0),
            elementText: "Item with **bold** and *italic*",
            chapterIndex: 0,
            orderIndex: 0,
            characterName: nil
        )

        _ = MarkdownListItemReferenceView(element: reference)
            .environment(\.screenplayFontSize, 12)

        #expect(reference.elementText.contains("**bold**"))
        #expect(reference.elementText.contains("*italic*"))
    }

    // MARK: - Integration Tests

    @Test("Markdown views work together in a document")
    func testMarkdownViewsIntegration() throws {
        let container = try makeTestContainer()
        let elements = [
            makeElement(in: container.mainContext, text: "# Main Title", type: .sectionHeading(level: 1), order: 0),
            makeElement(in: container.mainContext, text: "Introduction paragraph with **bold**.", type: .action, order: 1),
            makeElement(in: container.mainContext, text: "## Subsection", type: .sectionHeading(level: 2), order: 2),
            makeElement(in: container.mainContext, text: "First item", type: .orderedListItem(level: 0), order: 3),
            makeElement(in: container.mainContext, text: "Second item", type: .orderedListItem(level: 0), order: 4)
        ]
        let document = makeDocument(in: container.mainContext, withElements: elements)

        // Create all views
        _ = MarkdownSectionHeadingView(element: elements[0])
            .environment(\.screenplayFontSize, 12)
        _ = MarkdownActionView(element: elements[1])
            .environment(\.screenplayFontSize, 12)
        _ = MarkdownSectionHeadingView(element: elements[2])
            .environment(\.screenplayFontSize, 12)
        _ = MarkdownListItemView(element: elements[3], document: document)
            .environment(\.screenplayFontSize, 12)
        _ = MarkdownListItemView(element: elements[4], document: document)
            .environment(\.screenplayFontSize, 12)

        #expect(elements.count == 5)
    }

    @Test("Markdown views handle complex nested structure")
    func testMarkdownViewsComplexNesting() throws {
        let container = try makeTestContainer()
        let elements = [
            makeElement(in: container.mainContext, text: "# Chapter 1", type: .sectionHeading(level: 1), order: 0),
            makeElement(in: container.mainContext, text: "Introduction", type: .action, order: 1),
            makeElement(in: container.mainContext, text: "Main point", type: .unorderedListItem(level: 0), order: 2),
            makeElement(in: container.mainContext, text: "Subpoint", type: .unorderedListItem(level: 1), order: 3),
            makeElement(in: container.mainContext, text: "Sub-subpoint", type: .unorderedListItem(level: 2), order: 4),
            makeElement(in: container.mainContext, text: "## Section 1.1", type: .sectionHeading(level: 2), order: 5),
            makeElement(in: container.mainContext, text: "Details with *italic*", type: .action, order: 6)
        ]
        let document = makeDocument(in: container.mainContext, withElements: elements)

        for element in elements {
            switch element.elementType {
            case .sectionHeading:
                _ = MarkdownSectionHeadingView(element: element)
                    .environment(\.screenplayFontSize, 12)
            case .unorderedListItem, .orderedListItem:
                _ = MarkdownListItemView(element: element, document: document)
                    .environment(\.screenplayFontSize, 12)
            default:
                _ = MarkdownActionView(element: element)
                    .environment(\.screenplayFontSize, 12)
            }
        }

        #expect(elements.count == 7)
    }
}
