//
//  GuionSerializationErrorTests.swift
//  SwiftGuionTests
//
//  Tests for GuionSerializationError error descriptions and recovery suggestions
//

import Testing
import Foundation
@testable import SwiftCompartido

@Suite("GuionSerializationError Tests")
struct GuionSerializationErrorTests {

    @Test("Test encodingFailed error description")
    func testEncodingFailedDescription() {
        let underlyingError = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Encoding went wrong"])
        let error = GuionSerializationError.encodingFailed(underlyingError)

        let description = error.errorDescription
        #expect(description != nil, "Should have error description")
        #expect(description!.contains("Failed to encode document"), "Should mention encoding failure")
        #expect(description!.contains("Encoding went wrong"), "Should include underlying error description")
    }

    @Test("Test decodingFailed error description")
    func testDecodingFailedDescription() {
        let underlyingError = NSError(domain: "TestDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Decoding went wrong"])
        let error = GuionSerializationError.decodingFailed(underlyingError)

        let description = error.errorDescription
        #expect(description != nil, "Should have error description")
        #expect(description!.contains("Failed to decode document"), "Should mention decoding failure")
        #expect(description!.contains("Decoding went wrong"), "Should include underlying error description")
    }

    @Test("Test corruptedFile error description")
    func testCorruptedFileDescription() {
        let error = GuionSerializationError.corruptedFile("myScript.fountain")

        let description = error.errorDescription
        #expect(description != nil, "Should have error description")
        #expect(description!.contains("myScript.fountain"), "Should mention filename")
        #expect(description!.contains("corrupted"), "Should mention corruption")
        #expect(description!.contains("cannot be opened"), "Should mention inability to open")
    }

    @Test("Test unsupportedVersion error description")
    func testUnsupportedVersionDescription() {
        let error = GuionSerializationError.unsupportedVersion(5)

        let description = error.errorDescription
        #expect(description != nil, "Should have error description")
        #expect(description!.contains("newer version"), "Should mention newer version")
        #expect(description!.contains("5"), "Should mention version number")
    }

    @Test("Test missingData error description")
    func testMissingDataDescription() {
        let error = GuionSerializationError.missingData

        let description = error.errorDescription
        #expect(description != nil, "Should have error description")
        #expect(description!.contains("missing required data"), "Should mention missing data")
    }

    @Test("Test corruptedFile recovery suggestion")
    func testCorruptedFileRecoverySuggestion() {
        let error = GuionSerializationError.corruptedFile("test.fountain")

        let suggestion = error.recoverySuggestion
        #expect(suggestion != nil, "Should have recovery suggestion")
        #expect(suggestion!.contains("different application"), "Should suggest trying different application")
        #expect(suggestion!.contains("backup"), "Should mention restoring from backup")
    }

    @Test("Test unsupportedVersion recovery suggestion")
    func testUnsupportedVersionRecoverySuggestion() {
        let error = GuionSerializationError.unsupportedVersion(3)

        let suggestion = error.recoverySuggestion
        #expect(suggestion != nil, "Should have recovery suggestion")
        #expect(suggestion!.contains("update"), "Should suggest updating")
        #expect(suggestion!.contains("latest version"), "Should mention latest version")
    }

    @Test("Test encodingFailed recovery suggestion")
    func testEncodingFailedRecoverySuggestion() {
        let underlyingError = NSError(domain: "TestDomain", code: 1, userInfo: [:])
        let error = GuionSerializationError.encodingFailed(underlyingError)

        let suggestion = error.recoverySuggestion
        #expect(suggestion != nil, "Should have recovery suggestion")
        #expect(suggestion!.contains("try saving"), "Should suggest saving again")
        #expect(suggestion!.contains("contact support"), "Should mention support")
    }

    @Test("Test decodingFailed recovery suggestion")
    func testDecodingFailedRecoverySuggestion() {
        let underlyingError = NSError(domain: "TestDomain", code: 2, userInfo: [:])
        let error = GuionSerializationError.decodingFailed(underlyingError)

        let suggestion = error.recoverySuggestion
        #expect(suggestion != nil, "Should have recovery suggestion")
        #expect(suggestion!.contains("try saving"), "Should suggest saving again")
        #expect(suggestion!.contains("contact support"), "Should mention support")
    }

    @Test("Test missingData recovery suggestion")
    func testMissingDataRecoverySuggestion() {
        let error = GuionSerializationError.missingData

        let suggestion = error.recoverySuggestion
        #expect(suggestion != nil, "Should have recovery suggestion")
        #expect(suggestion!.contains("try saving"), "Should suggest saving again")
        #expect(suggestion!.contains("contact support"), "Should mention support")
    }
}
