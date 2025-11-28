//
//  CustomPageModelTests.swift
//  SwiftCompartidoTests
//
//  Copyright (c) 2025
//

import Foundation
import SwiftData
import Testing
@testable import SwiftCompartido

@Suite("CustomPageModel Tests")
struct CustomPageModelTests {

    // MARK: - Initialization Tests

    @Test("Creates CustomPageModel from CustomPageContainer")
    func testCreateFromContainer() throws {
        let castList = CastListPage(
            id: "cast-id",
            title: "Main Cast",
            position: 0,
            printDots: true,
            items: []
        )

        let container = try CustomPageContainer(page: castList, type: .castList)
        let model = CustomPageModel.from(container)

        #expect(model.id == "cast-id")
        #expect(model.title == "Main Cast")
        #expect(model.position == 0)
        #expect(model.pageType == "castList")
    }

    @Test("Creates model with unknown type")
    func testCreateWithUnknownType() throws {
        let dict: [String: Any] = [
            "id": "unknown-id",
            "type": "future-type",
            "title": "Future Page",
            "position": 5
        ]

        let container = try CustomPageContainer(from: dict)
        let model = CustomPageModel.from(container)

        #expect(model.pageType == "unknown")
        #expect(model.id == "unknown-id")
    }

    // MARK: - Conversion Tests

    @Test("Converts model back to container")
    func testToDTO() throws {
        let castList = CastListPage(
            id: "cast-id",
            title: "Main Cast",
            position: 2,
            printDots: false,
            items: [
                CastListPage.CastMember(
                    role: "HAMLET",
                    name: "Actor",
                    position: 0
                )
            ]
        )

        let originalContainer = try CustomPageContainer(page: castList, type: .castList)
        let model = CustomPageModel.from(originalContainer)

        let restoredContainer = try model.toDTO()

        #expect(restoredContainer.type == .castList)
        #expect(restoredContainer.id == "cast-id")
        #expect(restoredContainer.title == "Main Cast")
        #expect(restoredContainer.positionValue == 2)
    }

    @Test("Round-trip conversion preserves data")
    func testRoundTripConversion() throws {
        let castList = CastListPage(
            id: "cast-id",
            title: "Supporting Cast",
            position: 1,
            printDots: true,
            items: [
                CastListPage.CastMember(
                    id: "member-1",
                    role: "BERNARD",
                    name: "Jason Manino",
                    position: 0
                ),
                CastListPage.CastMember(
                    id: "member-2",
                    role: "SYLVIA",
                    name: "Lisa McMillan",
                    position: 1
                )
            ]
        )

        // Original -> Container -> Model -> Container -> CastList
        let container1 = try CustomPageContainer(page: castList, type: .castList)
        let model = CustomPageModel.from(container1)
        let container2 = try model.toDTO()
        let restoredCastList = try container2.asCastList()

        #expect(restoredCastList?.id == castList.id)
        #expect(restoredCastList?.title == castList.title)
        #expect(restoredCastList?.printDots == castList.printDots)
        #expect(restoredCastList?.items.count == 2)
        #expect(restoredCastList?.items[0].role == "BERNARD")
        #expect(restoredCastList?.items[1].role == "SYLVIA")
    }

    // MARK: - Cast List Convenience Tests

    @Test("asCastList returns CastListPage for cast list type")
    func testAsCastList() throws {
        let castList = CastListPage(
            title: "Main Cast",
            position: 0,
            items: []
        )

        let container = try CustomPageContainer(page: castList, type: .castList)
        let model = CustomPageModel.from(container)

        let extracted = try model.asCastList()

        #expect(extracted != nil)
        #expect(extracted?.title == "Main Cast")
    }

    @Test("asCastList returns nil for non-cast list type")
    func testAsCastListReturnsNilForWrongType() throws {
        let dict: [String: Any] = [
            "id": "test-id",
            "type": "advanced",
            "title": "Advanced Page",
            "position": 0
        ]

        let container = try CustomPageContainer(from: dict)
        let model = CustomPageModel.from(container)

        let extracted = try model.asCastList()

        #expect(extracted == nil)
    }

    // MARK: - Raw JSON Tests

    @Test("asRawJSON returns dictionary")
    func testAsRawJSON() throws {
        let dict: [String: Any] = [
            "id": "test-id",
            "type": "advanced",
            "title": "Advanced Page",
            "position": 3,
            "customField": "custom value"
        ]

        let container = try CustomPageContainer(from: dict)
        let model = CustomPageModel.from(container)

        let rawJSON = try model.asRawJSON()

        #expect(rawJSON["id"] as? String == "test-id")
        #expect(rawJSON["type"] as? String == "advanced")
        #expect(rawJSON["customField"] as? String == "custom value")
    }

    // MARK: - Update Tests

    @Test("Updates model from new container")
    func testUpdate() throws {
        // Create initial model
        let castList1 = CastListPage(
            id: "cast-id",
            title: "Original Title",
            position: 0,
            printDots: true,
            items: []
        )
        let container1 = try CustomPageContainer(page: castList1, type: .castList)
        let model = CustomPageModel.from(container1)

        // Update with new data
        let castList2 = CastListPage(
            id: "cast-id",
            title: "Updated Title",
            position: 5,
            printDots: false,
            items: [
                CastListPage.CastMember(role: "NEW ROLE", name: "New Actor", position: 0)
            ]
        )
        let container2 = try CustomPageContainer(page: castList2, type: .castList)

        try model.update(from: container2)

        #expect(model.title == "Updated Title")
        #expect(model.position == 5)

        let updated = try model.asCastList()
        #expect(updated?.printDots == false)
        #expect(updated?.items.count == 1)
    }

    // MARK: - Validation Tests

    @Test("validate succeeds for valid cast list")
    func testValidateSucceeds() throws {
        let castList = CastListPage(
            id: "cast-id",
            title: "Main Cast",
            position: 0,
            printDots: true,
            items: []
        )

        let container = try CustomPageContainer(page: castList, type: .castList)
        let model = CustomPageModel.from(container)

        try model.validate()
    }

    @Test("validate throws for missing id")
    func testValidateMissingID() throws {
        // Manually create invalid JSON (missing id)
        let invalidJSON = """
        {
            "title": "Test",
            "position": 0,
            "type": "castList"
        }
        """.data(using: .utf8)!

        let model = CustomPageModel(
            id: "generated-id",
            title: "Test",
            position: 0,
            pageType: "castList",
            jsonData: invalidJSON
        )

        #expect(throws: CustomPageError.self) {
            try model.validate()
        }
    }

    @Test("validate throws for missing type")
    func testValidateMissingType() throws {
        let invalidJSON = """
        {
            "id": "test-id",
            "title": "Test",
            "position": 0
        }
        """.data(using: .utf8)!

        let model = CustomPageModel(
            id: "test-id",
            title: "Test",
            position: 0,
            pageType: "unknown",
            jsonData: invalidJSON
        )

        #expect(throws: CustomPageError.self) {
            try model.validate()
        }
    }

    // MARK: - SwiftData Integration Tests

    @Test("Model can be inserted into SwiftData context")
    @MainActor
    func testSwiftDataInsertion() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CustomPageModel.self, GuionDocumentModel.self,
            configurations: config
        )
        let context = ModelContext(container)

        let castList = CastListPage(
            title: "Test Cast",
            position: 0,
            items: []
        )

        let pageContainer = try CustomPageContainer(page: castList, type: .castList)
        let model = CustomPageModel.from(pageContainer)

        context.insert(model)
        try context.save()

        // Fetch it back
        let descriptor = FetchDescriptor<CustomPageModel>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched[0].pageType == "castList")
    }

    @Test("Model relationship with GuionDocumentModel")
    @MainActor
    func testDocumentRelationship() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CustomPageModel.self, GuionDocumentModel.self,
            configurations: config
        )
        let context = ModelContext(container)

        let document = GuionDocumentModel(filename: "test.fountain")
        let castList = CastListPage(title: "Cast", position: 0, items: [])
        let pageContainer = try CustomPageContainer(page: castList, type: .castList)
        let pageModel = CustomPageModel.from(pageContainer)

        pageModel.document = document
        document.customPages.append(pageModel)

        context.insert(document)
        try context.save()

        // Verify relationship
        #expect(pageModel.document === document)
        #expect(document.customPages.count == 1)
        #expect(document.customPages[0] === pageModel)
    }

    @Test("Cascade delete removes custom pages when document deleted")
    @MainActor
    func testCascadeDelete() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CustomPageModel.self, GuionDocumentModel.self,
            configurations: config
        )
        let context = ModelContext(container)

        let document = GuionDocumentModel(filename: "test.fountain")
        let castList = CastListPage(title: "Cast", position: 0, items: [])
        let pageContainer = try CustomPageContainer(page: castList, type: .castList)
        let pageModel = CustomPageModel.from(pageContainer)

        pageModel.document = document
        document.customPages.append(pageModel)

        context.insert(document)
        try context.save()

        // Delete document
        context.delete(document)
        try context.save()

        // Verify custom page was cascade deleted
        let descriptor = FetchDescriptor<CustomPageModel>()
        let remaining = try context.fetch(descriptor)

        #expect(remaining.isEmpty)
    }
}
