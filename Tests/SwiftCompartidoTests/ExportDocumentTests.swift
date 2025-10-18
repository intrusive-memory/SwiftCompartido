//
//  ExportDocumentStructTests.swift
//  SwiftGuionTests
//
//  Tests for export document wrapper types
//

import XCTest
import Foundation
import UniformTypeIdentifiers
@testable import SwiftCompartido

final class ExportDocumentStructTests: XCTestCase {

    func testExportFormatDisplayNames() {
        XCTAssertEqual(ExportFormat.fountain.displayName, "Fountain Format")
        XCTAssertEqual(ExportFormat.fdx.displayName, "Final Draft Format")
    }

    func testExportFormatExtensions() {
        XCTAssertEqual(ExportFormat.fountain.fileExtension, "fountain")
        XCTAssertEqual(ExportFormat.fdx.fileExtension, "fdx")
    }

    func testExportFormatContentTypes() {
        XCTAssertEqual(ExportFormat.fountain.contentType, .fountainDocument)
        XCTAssertEqual(ExportFormat.fdx.contentType, .fdxDocument)
    }

    func testExportFormatAllCases() {
        let allCases = ExportFormat.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.fountain))
        XCTAssertTrue(allCases.contains(.fdx))
    }

    func testExportFormatRawValues() {
        XCTAssertEqual(ExportFormat.fountain.rawValue, "fountain")
        XCTAssertEqual(ExportFormat.fdx.rawValue, "fdx")
    }

    func testFountainExportDocumentContentTypes() {
        XCTAssertTrue(FountainExportDocument.readableContentTypes.isEmpty)
        XCTAssertEqual(FountainExportDocument.writableContentTypes, [.fountainDocument])
    }

    func testFDXExportDocumentContentTypes() {
        XCTAssertTrue(FDXExportDocument.readableContentTypes.isEmpty)
        XCTAssertEqual(FDXExportDocument.writableContentTypes, [.fdxDocument])
    }

    func testExportErrorDescriptions() {
        let readError = ExportError.readNotSupported
        XCTAssertEqual(readError.errorDescription, "Export documents cannot be opened")

        let invalidError = ExportError.invalidDocument
        XCTAssertEqual(invalidError.errorDescription, "The document is invalid or empty")

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "test error" }
        }
        let conversionError = ExportError.conversionFailed(TestError())
        XCTAssertTrue(conversionError.errorDescription?.contains("Failed to convert document") == true)
    }

    func testFountainExportDocumentInit() {
        let doc = GuionDocumentModel()
        doc.filename = "test.fountain"
        doc.rawContent = "INT. TEST LOCATION - DAY\n\nSome action."

        let exportDoc = FountainExportDocument(sourceDocument: doc)
        XCTAssertTrue(exportDoc.sourceDocument === doc)
    }

    func testFDXExportDocumentInit() {
        let doc = GuionDocumentModel()
        doc.filename = "test.fdx"
        doc.rawContent = "INT. TEST LOCATION - DAY\n\nSome action."

        let exportDoc = FDXExportDocument(sourceDocument: doc)
        XCTAssertTrue(exportDoc.sourceDocument === doc)
    }
}
