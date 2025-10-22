//
//  GeneratedContentSortingTests.swift
//  SwiftCompartidoTests
//
//  Tests for sorted generated content access on GuionDocumentModel
//

import Testing
import Foundation
import SwiftData
@testable import SwiftCompartido

/// Tests for accessing TypedDataStorage items sorted by owning element's order indices
@MainActor
struct GeneratedContentSortingTests {

    // MARK: - Test Helpers

    /// Creates a test document with elements and generated content
    private func createTestDocument(in context: ModelContext) throws -> GuionDocumentModel {
        let document = GuionDocumentModel()
        document.filename = "Test Screenplay"

        // Chapter 0 (pre-chapter) - 2 elements
        let preElement1 = GuionElementModel(
            elementText: "Title Page",
            elementType: .action,
            chapterIndex: 0,
            orderIndex: 1
        )
        let preElement2 = GuionElementModel(
            elementText: "FADE IN:",
            elementType: .action,
            chapterIndex: 0,
            orderIndex: 2
        )

        // Chapter 1 - 4 elements
        let chapter1Heading = GuionElementModel(
            elementText: "Chapter 1",
            elementType: .sectionHeading(level: 2),
            sectionDepth: 2,
            chapterIndex: 1,
            orderIndex: 1
        )
        let scene1 = GuionElementModel(
            elementText: "INT. COFFEE SHOP - DAY",
            elementType: .sceneHeading,
            chapterIndex: 1,
            orderIndex: 2
        )
        let dialogue1 = GuionElementModel(
            elementText: "Hello, how are you?",
            elementType: .dialogue,
            chapterIndex: 1,
            orderIndex: 3
        )
        let action1 = GuionElementModel(
            elementText: "She smiles warmly.",
            elementType: .action,
            chapterIndex: 1,
            orderIndex: 4
        )

        // Chapter 2 - 3 elements
        let chapter2Heading = GuionElementModel(
            elementText: "Chapter 2",
            elementType: .sectionHeading(level: 2),
            sectionDepth: 2,
            chapterIndex: 2,
            orderIndex: 1
        )
        let scene2 = GuionElementModel(
            elementText: "EXT. PARK - DAY",
            elementType: .sceneHeading,
            chapterIndex: 2,
            orderIndex: 2
        )
        let dialogue2 = GuionElementModel(
            elementText: "What a beautiful day!",
            elementType: .dialogue,
            chapterIndex: 2,
            orderIndex: 3
        )

        // Add elements to document
        document.elements = [
            preElement1, preElement2,
            chapter1Heading, scene1, dialogue1, action1,
            chapter2Heading, scene2, dialogue2
        ]

        // Set document reference on all elements
        for element in document.elements {
            element.document = document
        }

        // Add generated content to various elements
        // Pre-chapter audio
        let preAudio = TypedDataStorage(
            providerId: "test",
            requestorID: "test.tts",
            mimeType: "audio/mpeg",
            binaryValue: Data([0x01, 0x02]),
            prompt: "Pre-chapter audio"
        )
        preAudio.owningElement = preElement1
        preElement1.generatedContent = [preAudio]

        // Chapter 1 dialogue audio
        let dialogue1Audio = TypedDataStorage(
            providerId: "elevenlabs",
            requestorID: "tts.rachel",
            mimeType: "audio/mpeg",
            binaryValue: Data([0x03, 0x04]),
            prompt: dialogue1.elementText,
            audioFormat: "mp3",
            voiceID: "rachel",
            voiceName: "Rachel"
        )
        dialogue1Audio.owningElement = dialogue1
        dialogue1.generatedContent = [dialogue1Audio]

        // Chapter 1 scene image
        let scene1Image = TypedDataStorage(
            providerId: "openai",
            requestorID: "dalle.3",
            mimeType: "image/png",
            binaryValue: Data([0x05, 0x06]),
            prompt: "Coffee shop interior",
            imageFormat: "png",
            width: 1024,
            height: 1024
        )
        scene1Image.owningElement = scene1
        scene1.generatedContent = [scene1Image]

        // Chapter 2 dialogue audio
        let dialogue2Audio = TypedDataStorage(
            providerId: "elevenlabs",
            requestorID: "tts.rachel",
            mimeType: "audio/mpeg",
            binaryValue: Data([0x07, 0x08]),
            prompt: dialogue2.elementText,
            audioFormat: "mp3",
            voiceID: "rachel",
            voiceName: "Rachel"
        )
        dialogue2Audio.owningElement = dialogue2
        dialogue2.generatedContent = [dialogue2Audio]

        // Chapter 2 scene embedding
        let scene2Embedding = TypedDataStorage(
            providerId: "openai",
            requestorID: "embeddings",
            mimeType: "application/x-embedding",
            binaryValue: Data([0x09, 0x0A]),
            prompt: scene2.elementText,
            dimensions: 1536
        )
        scene2Embedding.owningElement = scene2
        scene2.generatedContent = [scene2Embedding]

        // Add document-level content (should not appear in element-based queries)
        let documentSummary = TypedDataStorage(
            providerId: "openai",
            requestorID: "gpt-4",
            mimeType: "text/plain",
            textValue: "A heartwarming story about connection.",
            prompt: "Summarize the screenplay",
            wordCount: 6,
            characterCount: 42
        )
        documentSummary.owningDocument = document
        document.generatedContent = [documentSummary]

        // Insert all items
        context.insert(document)
        for element in document.elements {
            context.insert(element)
            if let content = element.generatedContent {
                for item in content {
                    context.insert(item)
                }
            }
        }
        if let docContent = document.generatedContent {
            for item in docContent {
                context.insert(item)
            }
        }

        try context.save()
        return document
    }

    // MARK: - sortedElementGeneratedContent Tests

    @Test("sortedElementGeneratedContent returns all element-owned content in order")
    func testSortedElementGeneratedContent() throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
            TypedDataStorage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let document = try createTestDocument(in: context)

        let sorted = document.sortedElementGeneratedContent

        // Should have 5 items (not 6 - document-level content excluded)
        #expect(sorted.count == 5, "Should have 5 element-owned items")

        // Verify order by checking prompts
        #expect(sorted[0].prompt == "Pre-chapter audio", "First should be pre-chapter (0,1)")
        #expect(sorted[1].prompt.contains("Coffee shop") || sorted[1].mimeType.hasPrefix("image/"), "Second should be chapter 1 scene (1,2)")
        #expect(sorted[2].prompt == "Hello, how are you?" || sorted[2].mimeType.hasPrefix("audio/"), "Third should be chapter 1 dialogue (1,3)")
        #expect(sorted[3].mimeType == "application/x-embedding", "Fourth should be chapter 2 scene embedding (2,2)")
        #expect(sorted[4].prompt == "What a beautiful day!", "Fifth should be chapter 2 dialogue (2,3)")

        // Verify chapter indices are in order
        let chapterIndices = sorted.compactMap { $0.owningElement?.chapterIndex }
        #expect(chapterIndices == [0, 1, 1, 2, 2], "Chapter indices should be in order")

        // Verify order indices within chapters
        if let owner0 = sorted[0].owningElement {
            #expect(owner0.chapterIndex == 0 && owner0.orderIndex == 1)
        }
        if let owner1 = sorted[1].owningElement {
            #expect(owner1.chapterIndex == 1 && owner1.orderIndex == 2)
        }
        if let owner2 = sorted[2].owningElement {
            #expect(owner2.chapterIndex == 1 && owner2.orderIndex == 3)
        }
    }

    @Test("sortedElementGeneratedContent excludes document-level content")
    func testExcludesDocumentContent() throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
            TypedDataStorage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let document = try createTestDocument(in: context)

        let sorted = document.sortedElementGeneratedContent

        // Should not include document-level summary
        let hasSummary = sorted.contains { $0.prompt == "Summarize the screenplay" }
        #expect(!hasSummary, "Should not include document-level content")

        // All items should have owningElement
        let allHaveOwner = sorted.allSatisfy { $0.owningElement != nil }
        #expect(allHaveOwner, "All items should have owningElement")
    }

    // MARK: - MIME Type Filtering Tests

    @Test("sortedElementGeneratedContent filters by MIME type prefix")
    func testFilterByMimeType() throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
            TypedDataStorage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let document = try createTestDocument(in: context)

        // Test audio filtering
        let audioContent = document.sortedElementGeneratedContent(mimeTypePrefix: "audio/")
        #expect(audioContent.count == 3, "Should have 3 audio items")
        #expect(audioContent.allSatisfy { $0.mimeType.hasPrefix("audio/") }, "All should be audio")

        // Test image filtering
        let imageContent = document.sortedElementGeneratedContent(mimeTypePrefix: "image/")
        #expect(imageContent.count == 1, "Should have 1 image item")
        #expect(imageContent.allSatisfy { $0.mimeType.hasPrefix("image/") }, "All should be images")

        // Test embedding filtering
        let embeddingContent = document.sortedElementGeneratedContent(mimeTypePrefix: "application/x-embedding")
        #expect(embeddingContent.count == 1, "Should have 1 embedding item")

        // Verify audio is in order
        let audioChapters = audioContent.compactMap { $0.owningElement?.chapterIndex }
        #expect(audioChapters == [0, 1, 2], "Audio should be ordered by chapter")
    }

    // MARK: - Element Type Filtering Tests

    @Test("sortedElementGeneratedContent filters by element type")
    func testFilterByElementType() throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
            TypedDataStorage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let document = try createTestDocument(in: context)

        // Test dialogue filtering
        let dialogueContent = document.sortedElementGeneratedContent(for: ElementType.dialogue)
        #expect(dialogueContent.count == 2, "Should have 2 dialogue items")
        #expect(dialogueContent.allSatisfy {
            if case .dialogue = $0.owningElement?.elementType { return true }
            return false
        }, "All should be dialogue")

        // Verify dialogue is in order
        if dialogueContent.count == 2 {
            let chapter1Dialogue = dialogueContent[0]
            let chapter2Dialogue = dialogueContent[1]

            #expect(chapter1Dialogue.owningElement?.chapterIndex == 1)
            #expect(chapter2Dialogue.owningElement?.chapterIndex == 2)
        }

        // Test scene heading filtering
        let sceneContent = document.sortedElementGeneratedContent(for: ElementType.sceneHeading)
        #expect(sceneContent.count == 2, "Should have 2 scene items (image + embedding)")
        #expect(sceneContent.allSatisfy {
            if case .sceneHeading = $0.owningElement?.elementType { return true }
            return false
        }, "All should be scene headings")

        // Test action filtering
        let actionContent = document.sortedElementGeneratedContent(for: ElementType.action)
        #expect(actionContent.count == 1, "Should have 1 action item (pre-chapter)")
    }

    // MARK: - Empty Document Tests

    @Test("sortedElementGeneratedContent returns empty array for document with no content")
    func testEmptyDocument() throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
            TypedDataStorage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let document = GuionDocumentModel()
        document.filename = "Empty"
        context.insert(document)
        try context.save()

        let sorted = document.sortedElementGeneratedContent
        #expect(sorted.isEmpty, "Empty document should have no generated content")

        let audio = document.sortedElementGeneratedContent(mimeTypePrefix: "audio/")
        #expect(audio.isEmpty, "Empty document should have no audio content")

        let dialogue = document.sortedElementGeneratedContent(for: ElementType.dialogue)
        #expect(dialogue.isEmpty, "Empty document should have no dialogue content")
    }

    // MARK: - Multiple Content Per Element Tests

    @Test("sortedElementGeneratedContent handles multiple items per element")
    func testMultipleItemsPerElement() throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
            TypedDataStorage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let document = GuionDocumentModel()
        let element = GuionElementModel(
            elementText: "Hello there!",
            elementType: .dialogue,
            chapterIndex: 1,
            orderIndex: 1
        )
        element.document = document
        document.elements = [element]

        // Add multiple content items to the same element
        let audio1 = TypedDataStorage(
            providerId: "elevenlabs",
            requestorID: "tts.rachel",
            mimeType: "audio/mpeg",
            binaryValue: Data([0x01]),
            prompt: "Audio version 1"
        )
        audio1.owningElement = element

        let audio2 = TypedDataStorage(
            providerId: "elevenlabs",
            requestorID: "tts.josh",
            mimeType: "audio/mpeg",
            binaryValue: Data([0x02]),
            prompt: "Audio version 2"
        )
        audio2.owningElement = element

        let image = TypedDataStorage(
            providerId: "openai",
            requestorID: "dalle",
            mimeType: "image/png",
            binaryValue: Data([0x03]),
            prompt: "Character portrait"
        )
        image.owningElement = element

        element.generatedContent = [audio1, audio2, image]

        context.insert(document)
        context.insert(element)
        context.insert(audio1)
        context.insert(audio2)
        context.insert(image)
        try context.save()

        let sorted = document.sortedElementGeneratedContent
        #expect(sorted.count == 3, "Should have all 3 items")

        // All should have the same chapter and order index
        let allSameElement = sorted.allSatisfy { item in
            item.owningElement?.chapterIndex == 1 && item.owningElement?.orderIndex == 1
        }
        #expect(allSameElement, "All items should belong to the same element")
    }

    // MARK: - Performance Test

    @Test("sortedElementGeneratedContent performs well with large document")
    func testPerformanceWithLargeDocument() throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
            TypedDataStorage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let document = GuionDocumentModel()

        // Create 100 elements with generated content
        for chapterIndex in 0..<10 {
            for orderIndex in 1...10 {
                let element = GuionElementModel(
                    elementText: "Element \(chapterIndex).\(orderIndex)",
                    elementType: .dialogue,
                    chapterIndex: chapterIndex,
                    orderIndex: orderIndex
                )
                element.document = document

                let audio = TypedDataStorage(
                    providerId: "test",
                    requestorID: "test.tts",
                    mimeType: "audio/mpeg",
                    binaryValue: Data([UInt8(chapterIndex), UInt8(orderIndex)]),
                    prompt: "Prompt \(chapterIndex).\(orderIndex)"
                )
                audio.owningElement = element
                element.generatedContent = [audio]

                context.insert(element)
                context.insert(audio)
            }
        }

        document.elements = try context.fetch(FetchDescriptor<GuionElementModel>())
        context.insert(document)
        try context.save()

        let startTime = Date()
        let sorted = document.sortedElementGeneratedContent
        let duration = Date().timeIntervalSince(startTime)

        #expect(sorted.count == 100, "Should have 100 items")
        #expect(duration < 0.1, "Should complete in < 100ms")

        // Verify order is correct
        for i in 0..<sorted.count {
            let expectedChapter = i / 10
            let expectedOrder = (i % 10) + 1

            if let element = sorted[i].owningElement {
                #expect(element.chapterIndex == expectedChapter)
                #expect(element.orderIndex == expectedOrder)
            }
        }
    }
}
