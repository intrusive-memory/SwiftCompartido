//
//  TypedDataImageViewTests.swift
//  SwiftCompartidoTests
//
//  Tests for cross-platform TypedDataImageView
//

import Foundation
import Testing
import SwiftData
@testable import SwiftCompartido

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
struct TypedDataImageViewTests {

    // MARK: - Image Data Creation Tests

    @Test func testCreateValidImageData() throws {
        let imageData = createTestImageData()
        #expect(!imageData.isEmpty, "Test image data should not be empty")
        #expect(imageData.count > 100, "Image data should be substantial")
    }

    @Test func testImageDataCanBeDecoded() throws {
        let imageData = createTestImageData()

        #if canImport(UIKit)
        let image = UIImage(data: imageData)
        #expect(image != nil, "UIImage should be able to decode test data")
        #elseif canImport(AppKit)
        let image = NSImage(data: imageData)
        #expect(image != nil, "NSImage should be able to decode test data")
        #endif
    }

    // MARK: - TypedDataStorage Tests

    @Test func testTypedDataStorageWithImageData() throws {
        let imageData = createTestImageData()

        let storage = TypedDataStorage(
            providerId: "test",
            requestorID: "test-generator",
            mimeType: "image/png",
            binaryValue: imageData,
            prompt: "Test image",
            imageFormat: "png",
            width: 100,
            height: 100
        )

        #expect(storage.mimeType == "image/png")
        #expect(storage.imageFormat == "png")
        #expect(storage.width == 100)
        #expect(storage.height == 100)
        #expect(!(storage.binaryValue?.isEmpty ?? true), "Binary value should not be empty")
    }

    @Test func testTypedDataStorageGetBinary() throws {
        let imageData = createTestImageData()

        let storage = TypedDataStorage(
            providerId: "test",
            requestorID: "test-generator",
            mimeType: "image/png",
            binaryValue: imageData
        )

        let retrievedData = try storage.getBinary(from: nil)
        #expect(retrievedData == imageData, "Retrieved data should match original")
    }

    // MARK: - Platform Image Type Tests

    #if canImport(UIKit)
    @Test func testUIImageCreation() throws {
        let imageData = createTestImageData()
        let uiImage = UIImage(data: imageData)

        #expect(uiImage != nil, "Should create UIImage from data")
        #expect(uiImage?.size.width ?? 0 > 0, "Image should have width")
        #expect(uiImage?.size.height ?? 0 > 0, "Image should have height")
    }

    @Test func testUIImageRoundTrip() throws {
        // Create image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50))
        let originalImage = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
        }

        // Convert to data
        guard let imageData = originalImage.pngData() else {
            Issue.record("Should create PNG data")
            return
        }

        // Recreate image
        let recreatedImage = UIImage(data: imageData)
        #expect(recreatedImage != nil, "Should recreate image from data")
    }
    #endif

    #if canImport(AppKit)
    @Test func testNSImageCreation() throws {
        let imageData = createTestImageData()
        let nsImage = NSImage(data: imageData)

        #expect(nsImage != nil, "Should create NSImage from data")
        #expect(nsImage?.size.width ?? 0 > 0, "Image should have width")
        #expect(nsImage?.size.height ?? 0 > 0, "Image should have height")
    }

    @Test func testNSImageRoundTrip() throws {
        // Create image
        let image = NSImage(size: NSSize(width: 50, height: 50))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 50, height: 50).fill()
        image.unlockFocus()

        // Convert to data
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let imageData = bitmap.representation(using: .png, properties: [:]) else {
            Issue.record("Should create PNG data")
            return
        }

        // Recreate image
        let recreatedImage = NSImage(data: imageData)
        #expect(recreatedImage != nil, "Should recreate image from data")
    }
    #endif

    // MARK: - Image Format Tests

    @Test func testPNGFormat() throws {
        let imageData = createTestImageData(format: "png")

        #if canImport(UIKit)
        let image = UIImage(data: imageData)
        #expect(image != nil, "Should decode PNG format")
        #elseif canImport(AppKit)
        let image = NSImage(data: imageData)
        #expect(image != nil, "Should decode PNG format")
        #endif
    }

    @Test func testJPEGFormat() throws {
        let imageData = createTestImageData(format: "jpeg")

        #if canImport(UIKit)
        let image = UIImage(data: imageData)
        #expect(image != nil, "Should decode JPEG format")
        #elseif canImport(AppKit)
        let image = NSImage(data: imageData)
        #expect(image != nil, "Should decode JPEG format")
        #endif
    }

    // MARK: - Error Cases

    @Test func testInvalidImageData() throws {
        let invalidData = Data([0xFF, 0xFF, 0xFF, 0xFF]) // Invalid image data

        #if canImport(UIKit)
        let image = UIImage(data: invalidData)
        #expect(image == nil, "Should not create image from invalid data")
        #elseif canImport(AppKit)
        let image = NSImage(data: invalidData)
        #expect(image == nil, "Should not create image from invalid data")
        #endif
    }

    @Test func testEmptyImageData() throws {
        let emptyData = Data()

        #if canImport(UIKit)
        let image = UIImage(data: emptyData)
        #expect(image == nil, "Should not create image from empty data")
        #elseif canImport(AppKit)
        let image = NSImage(data: emptyData)
        #expect(image == nil, "Should not create image from empty data")
        #endif
    }

    // MARK: - Helper Methods

    /// Creates test image data in the specified format
    private func createTestImageData(format: String = "png") -> Data {
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }

        if format == "jpeg" {
            return image.jpegData(compressionQuality: 0.8) ?? Data()
        } else {
            return image.pngData() ?? Data()
        }

        #elseif canImport(AppKit)
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return Data()
        }

        if format == "jpeg" {
            return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) ?? Data()
        } else {
            return bitmap.representation(using: .png, properties: [:]) ?? Data()
        }
        #endif
    }
}
