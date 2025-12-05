//
//  ExportDocumentStructTests.swift
//  SwiftGuionTests
//
//  Tests for export document wrapper types
//

import Testing
import Foundation
import UniformTypeIdentifiers
@testable import SwiftCompartido

struct ExportDocumentStructTests {

    @Test func testExportFormatDisplayNames() {
        #expect(ExportFormat.fountain.displayName == "Fountain Format")
        #expect(ExportFormat.fdx.displayName == "Final Draft Format")
    }

    @Test func testExportFormatExtensions() {
        #expect(ExportFormat.fountain.fileExtension == "fountain")
        #expect(ExportFormat.fdx.fileExtension == "fdx")
    }

    @Test func testExportFormatContentTypes() {
        #expect(ExportFormat.fountain.contentType == .fountainDocument)
        #expect(ExportFormat.fdx.contentType == .fdxDocument)
    }

    @Test func testExportFormatAllCases() {
        let allCases = ExportFormat.allCases
        #expect(allCases.count == 2)
        #expect(allCases.contains(.fountain))
        #expect(allCases.contains(.fdx))
    }

    @Test func testExportFormatRawValues() {
        #expect(ExportFormat.fountain.rawValue == "fountain")
        #expect(ExportFormat.fdx.rawValue == "fdx")
    }

    @Test func testFountainExportDocumentContentTypes() {
        #expect(FountainExportDocument.readableContentTypes.isEmpty)
        #expect(FountainExportDocument.writableContentTypes == [.fountainDocument])
    }

    @Test func testFDXExportDocumentContentTypes() {
        #expect(FDXExportDocument.readableContentTypes.isEmpty)
        #expect(FDXExportDocument.writableContentTypes == [.fdxDocument])
    }

    @Test func testExportErrorDescriptions() {
        let readError = ExportError.readNotSupported
        #expect(readError.errorDescription == "Export documents cannot be opened")

        let invalidError = ExportError.invalidDocument
        #expect(invalidError.errorDescription == "The document is invalid or empty")

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "test error" }
        }
        let conversionError = ExportError.conversionFailed(TestError())
        #expect(conversionError.errorDescription?.contains("Failed to convert document") == true)
    }

    @Test func testFountainExportDocumentInit() {
        let doc = GuionDocumentModel()
        doc.filename = "test.fountain"
        doc.rawContent = "INT. TEST LOCATION - DAY\n\nSome action."

        let exportDoc = FountainExportDocument(sourceDocument: doc)
        #expect(exportDoc.sourceDocument === doc)
    }

    @Test func testFDXExportDocumentInit() {
        let doc = GuionDocumentModel()
        doc.filename = "test.fdx"
        doc.rawContent = "INT. TEST LOCATION - DAY\n\nSome action."

        let exportDoc = FDXExportDocument(sourceDocument: doc)
        #expect(exportDoc.sourceDocument === doc)
    }
}
