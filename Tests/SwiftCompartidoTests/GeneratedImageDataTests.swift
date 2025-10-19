//
//  GeneratedImageDataTests.swift
//  SwiftHablareTests
//
//  Phase 5: Tests for GeneratedImageData and ImageGenerationConfig
//

import XCTest
@testable import SwiftCompartido

final class GeneratedImageDataTests: XCTestCase {

    // MARK: - ImageFormat Tests

    func testImageFormatMimeTypes() {
        // THEN
        XCTAssertEqual(GeneratedImageData.ImageFormat.png.mimeType, "image/png")
        XCTAssertEqual(GeneratedImageData.ImageFormat.jpg.mimeType, "image/jpeg")
        XCTAssertEqual(GeneratedImageData.ImageFormat.jpeg.mimeType, "image/jpeg")
        XCTAssertEqual(GeneratedImageData.ImageFormat.webp.mimeType, "image/webp")
        XCTAssertEqual(GeneratedImageData.ImageFormat.heic.mimeType, "image/heic")
    }

    func testImageFormatFileExtensions() {
        // THEN
        XCTAssertEqual(GeneratedImageData.ImageFormat.png.fileExtension, "png")
        XCTAssertEqual(GeneratedImageData.ImageFormat.jpg.fileExtension, "jpg")
        XCTAssertEqual(GeneratedImageData.ImageFormat.jpeg.fileExtension, "jpeg")
        XCTAssertEqual(GeneratedImageData.ImageFormat.webp.fileExtension, "webp")
        XCTAssertEqual(GeneratedImageData.ImageFormat.heic.fileExtension, "heic")
    }

    func testImageFormatRawValues() {
        // THEN
        XCTAssertEqual(GeneratedImageData.ImageFormat.png.rawValue, "png")
        XCTAssertEqual(GeneratedImageData.ImageFormat.jpg.rawValue, "jpg")
        XCTAssertEqual(GeneratedImageData.ImageFormat.jpeg.rawValue, "jpeg")
        XCTAssertEqual(GeneratedImageData.ImageFormat.webp.rawValue, "webp")
        XCTAssertEqual(GeneratedImageData.ImageFormat.heic.rawValue, "heic")
    }

    // MARK: - GeneratedImageData Initialization Tests

    func testGeneratedImageDataInitialization() {
        // GIVEN
        let imageData = Data("test image".utf8)
        let model = "dall-e-3"

        // WHEN
        let generated = GeneratedImageData(
            imageData: imageData,
            format: .png,
            width: 1024,
            height: 1024,
            model: model,
            revisedPrompt: "A test image"
        )

        // THEN
        XCTAssertEqual(generated.imageData, imageData)
        XCTAssertEqual(generated.format, .png)
        XCTAssertEqual(generated.width, 1024)
        XCTAssertEqual(generated.height, 1024)
        XCTAssertEqual(generated.model, model)
        XCTAssertEqual(generated.revisedPrompt, "A test image")
    }

    func testGeneratedImageDataWithOptionalParameters() {
        // WHEN
        let generated = GeneratedImageData(
            imageData: Data("test".utf8),
            format: .jpg,
            width: 512,
            height: 512,
            model: "test-model"
        )

        // THEN
        XCTAssertEqual(generated.imageData, Data("test".utf8))
        XCTAssertEqual(generated.format, .jpg)
        XCTAssertEqual(generated.width, 512)
        XCTAssertEqual(generated.height, 512)
        XCTAssertEqual(generated.model, "test-model")
        XCTAssertNil(generated.revisedPrompt)
    }

    func testGeneratedImageDataFileSize() {
        // GIVEN
        let imageData = Data("test image data with some length".utf8)

        // WHEN
        let generated = GeneratedImageData(
            imageData: imageData,
            format: .png,
            width: 1024,
            height: 1024,
            model: "test-model"
        )

        // THEN
        XCTAssertEqual(generated.fileSize, imageData.count)
    }

    func testGeneratedImageDataWithNilImageData() {
        // WHEN
        let generated = GeneratedImageData(
            imageData: nil,
            format: .png,
            width: 1024,
            height: 1024,
            model: "test-model"
        )

        // THEN
        XCTAssertNil(generated.imageData)
        XCTAssertEqual(generated.fileSize, 0, "File size should be 0 when imageData is nil")
    }

    // MARK: - SerializableTypedData Conformance Tests

    func testPreferredFormat() {
        // GIVEN
        let generated = GeneratedImageData(
            imageData: Data("test".utf8),
            format: .png,
            width: 1024,
            height: 1024,
            model: "test-model"
        )

        // THEN
        XCTAssertEqual(generated.preferredFormat, .plist)
    }

    // MARK: - Codable Tests

    func testGeneratedImageDataCodable() throws {
        // GIVEN
        let imageData = Data("test image".utf8)
        let original = GeneratedImageData(
            imageData: imageData,
            format: .png,
            width: 1920,
            height: 1080,
            model: "dall-e-3",
            revisedPrompt: "A beautiful sunset"
        )

        // WHEN - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        // THEN - Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GeneratedImageData.self, from: data)

        XCTAssertEqual(decoded.imageData, original.imageData)
        XCTAssertEqual(decoded.format, original.format)
        XCTAssertEqual(decoded.width, original.width)
        XCTAssertEqual(decoded.height, original.height)
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.revisedPrompt, original.revisedPrompt)
    }

    func testGeneratedImageDataCodableWithNilValues() throws {
        // GIVEN
        let original = GeneratedImageData(
            imageData: nil,
            format: .jpg,
            width: 512,
            height: 512,
            model: "test-model"
        )

        // WHEN
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GeneratedImageData.self, from: data)

        // THEN
        XCTAssertNil(decoded.imageData)
        XCTAssertNil(decoded.revisedPrompt)
    }

    // MARK: - ImageGenerationConfig.ImageSize Tests

    func testImageSizeSquare1024() {
        // WHEN
        let size = ImageGenerationConfig.ImageSize.square1024

        // THEN
        XCTAssertEqual(size.width, 1024)
        XCTAssertEqual(size.height, 1024)
        XCTAssertEqual(size.aspectRatioDescription, "1:1 (Square)")
    }

    func testImageSizeSquare512() {
        // WHEN
        let size = ImageGenerationConfig.ImageSize.square512

        // THEN
        XCTAssertEqual(size.width, 512)
        XCTAssertEqual(size.height, 512)
    }

    func testImageSizeSquare256() {
        // WHEN
        let size = ImageGenerationConfig.ImageSize.square256

        // THEN
        XCTAssertEqual(size.width, 256)
        XCTAssertEqual(size.height, 256)
    }

    func testImageSizeWide16x9() {
        // WHEN
        let size = ImageGenerationConfig.ImageSize.wide16x9

        // THEN
        XCTAssertEqual(size.width, 1792)
        XCTAssertEqual(size.height, 1024)
        XCTAssertEqual(size.aspectRatioDescription, "16:9 (Widescreen)")
    }

    func testImageSizePortrait9x16() {
        // WHEN
        let size = ImageGenerationConfig.ImageSize.portrait9x16

        // THEN
        XCTAssertEqual(size.width, 1024)
        XCTAssertEqual(size.height, 1792)
        XCTAssertEqual(size.aspectRatioDescription, "9:16 (Portrait)")
    }

    func testImageSizeAspectRatio() {
        // Test aspect ratio calculations
        let square = ImageGenerationConfig.ImageSize.square1024
        let wide = ImageGenerationConfig.ImageSize.wide16x9
        let portrait = ImageGenerationConfig.ImageSize.portrait9x16

        XCTAssertEqual(square.aspectRatio, 1.0, accuracy: 0.01)
        XCTAssertGreaterThan(wide.aspectRatio, 1.0, "Wide should be > 1.0")
        XCTAssertLessThan(portrait.aspectRatio, 1.0, "Portrait should be < 1.0")
    }

    func testImageSizeUseCase() {
        // THEN
        XCTAssertFalse(ImageGenerationConfig.ImageSize.square1024.useCase.isEmpty)
        XCTAssertFalse(ImageGenerationConfig.ImageSize.wide16x9.useCase.isEmpty)
        XCTAssertFalse(ImageGenerationConfig.ImageSize.portrait9x16.useCase.isEmpty)
    }

    // MARK: - ImageGenerationConfig Tests

    func testImageGenerationConfigInitialization() {
        // WHEN
        let config = ImageGenerationConfig(
            size: .square1024,
            quality: .hd,
            style: .vivid,
            numberOfImages: 1
        )

        // THEN
        XCTAssertEqual(config.size, .square1024)
        XCTAssertEqual(config.quality, .hd)
        XCTAssertEqual(config.style, .vivid)
        XCTAssertEqual(config.numberOfImages, 1)
    }

    func testImageGenerationConfigDefaults() {
        // WHEN
        let config = ImageGenerationConfig()

        // THEN
        XCTAssertEqual(config.size, .square1024)
        XCTAssertEqual(config.quality, .standard)
        XCTAssertEqual(config.style, .vivid)
        XCTAssertEqual(config.numberOfImages, 1)
    }

    func testImageGenerationConfigQuality() {
        // Test quality options
        XCTAssertEqual(ImageGenerationConfig.Quality.standard.rawValue, "standard")
        XCTAssertEqual(ImageGenerationConfig.Quality.hd.rawValue, "hd")
    }

    func testImageGenerationConfigStyle() {
        // Test style options
        XCTAssertEqual(ImageGenerationConfig.Style.vivid.rawValue, "vivid")
        XCTAssertEqual(ImageGenerationConfig.Style.natural.rawValue, "natural")
    }

    func testImageGenerationConfigCodable() throws {
        // GIVEN
        let original = ImageGenerationConfig(
            size: .wide16x9,
            quality: .hd,
            style: .natural,
            numberOfImages: 1
        )

        // WHEN
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ImageGenerationConfig.self, from: data)

        // THEN
        XCTAssertEqual(decoded.size, original.size)
        XCTAssertEqual(decoded.quality, original.quality)
        XCTAssertEqual(decoded.style, original.style)
        XCTAssertEqual(decoded.numberOfImages, original.numberOfImages)
    }

    // MARK: - Edge Cases

    func testGeneratedImageDataWithAllFormats() {
        // Test each format
        let formats: [GeneratedImageData.ImageFormat] = [.png, .jpg, .jpeg, .webp, .heic]

        for format in formats {
            let generated = GeneratedImageData(
                imageData: Data("test".utf8),
                format: format,
                width: 1024,
                height: 1024,
                model: "test-model"
            )
            XCTAssertEqual(generated.format, format)
        }
    }

    func testGeneratedImageDataCustomDimensions() {
        // Test various custom dimensions
        let dimensions = [
            (width: 512, height: 512),
            (width: 1024, height: 768),
            (width: 2048, height: 2048),
            (width: 1792, height: 1024)
        ]

        for (width, height) in dimensions {
            let generated = GeneratedImageData(
                imageData: Data("test".utf8),
                format: .png,
                width: width,
                height: height,
                model: "test-model"
            )
            XCTAssertEqual(generated.width, width)
            XCTAssertEqual(generated.height, height)
        }
    }

    func testAllImageSizes() {
        // Test all available image sizes
        let sizes: [ImageGenerationConfig.ImageSize] = [
            .square256,
            .square512,
            .square1024,
            .wide16x9,
            .portrait9x16
        ]

        for size in sizes {
            XCTAssertGreaterThan(size.width, 0)
            XCTAssertGreaterThan(size.height, 0)
            XCTAssertGreaterThan(size.aspectRatio, 0)
            XCTAssertFalse(size.aspectRatioDescription.isEmpty)
            XCTAssertFalse(size.useCase.isEmpty)
        }
    }

    func testImageGenerationConfigWithDifferentSizes() {
        // Test with different sizes
        let sizes: [ImageGenerationConfig.ImageSize] = [
            .square256,
            .square512,
            .square1024,
            .wide16x9,
            .portrait9x16
        ]

        for size in sizes {
            let config = ImageGenerationConfig(size: size)
            XCTAssertEqual(config.size, size)
        }
    }

    func testImageGenerationConfigWithQualityAndStyle() {
        // Test combinations of quality and style
        let qualityStyleCombos: [(ImageGenerationConfig.Quality, ImageGenerationConfig.Style)] = [
            (.standard, .vivid),
            (.standard, .natural),
            (.hd, .vivid),
            (.hd, .natural)
        ]

        for (quality, style) in qualityStyleCombos {
            let config = ImageGenerationConfig(
                quality: quality,
                style: style
            )
            XCTAssertEqual(config.quality, quality)
            XCTAssertEqual(config.style, style)
        }
    }

    func testLargeImageData() {
        // GIVEN - Simulate a large image
        let largeData = Data(repeating: 0xFF, count: 1024 * 1024) // 1MB

        // WHEN
        let generated = GeneratedImageData(
            imageData: largeData,
            format: .png,
            width: 2048,
            height: 2048,
            model: "dall-e-3"
        )

        // THEN
        XCTAssertEqual(generated.fileSize, 1024 * 1024)
    }
}
