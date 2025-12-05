//
//  GeneratedImageDataTests.swift
//  SwiftHablareTests
//
//  Phase 5: Tests for GeneratedImageData and ImageGenerationConfig
//

import Testing
@testable import SwiftCompartido

struct GeneratedImageDataTests {

    // MARK: - ImageFormat Tests

    @Test func testImageFormatMimeTypes() {
        // THEN
        #expect(GeneratedImageData.ImageFormat.png.mimeType == "image/png")
        #expect(GeneratedImageData.ImageFormat.jpg.mimeType == "image/jpeg")
        #expect(GeneratedImageData.ImageFormat.jpeg.mimeType == "image/jpeg")
        #expect(GeneratedImageData.ImageFormat.webp.mimeType == "image/webp")
        #expect(GeneratedImageData.ImageFormat.heic.mimeType == "image/heic")
    }

    @Test func testImageFormatFileExtensions() {
        // THEN
        #expect(GeneratedImageData.ImageFormat.png.fileExtension == "png")
        #expect(GeneratedImageData.ImageFormat.jpg.fileExtension == "jpg")
        #expect(GeneratedImageData.ImageFormat.jpeg.fileExtension == "jpeg")
        #expect(GeneratedImageData.ImageFormat.webp.fileExtension == "webp")
        #expect(GeneratedImageData.ImageFormat.heic.fileExtension == "heic")
    }

    @Test func testImageFormatRawValues() {
        // THEN
        #expect(GeneratedImageData.ImageFormat.png.rawValue == "png")
        #expect(GeneratedImageData.ImageFormat.jpg.rawValue == "jpg")
        #expect(GeneratedImageData.ImageFormat.jpeg.rawValue == "jpeg")
        #expect(GeneratedImageData.ImageFormat.webp.rawValue == "webp")
        #expect(GeneratedImageData.ImageFormat.heic.rawValue == "heic")
    }

    // MARK: - GeneratedImageData Initialization Tests

    @Test func testGeneratedImageDataInitialization() {
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
        #expect(generated.imageData == imageData)
        #expect(generated.format == .png)
        #expect(generated.width == 1024)
        #expect(generated.height == 1024)
        #expect(generated.model == model)
        #expect(generated.revisedPrompt == "A test image")
    }

    @Test func testGeneratedImageDataWithOptionalParameters() {
        // WHEN
        let generated = GeneratedImageData(
            imageData: Data("test".utf8),
            format: .jpg,
            width: 512,
            height: 512,
            model: "test-model"
        )

        // THEN
        #expect(generated.imageData == Data("test".utf8))
        #expect(generated.format == .jpg)
        #expect(generated.width == 512)
        #expect(generated.height == 512)
        #expect(generated.model == "test-model")
        #expect(generated.revisedPrompt == nil)
    }

    @Test func testGeneratedImageDataFileSize() {
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
        #expect(generated.fileSize == imageData.count)
    }

    @Test func testGeneratedImageDataWithNilImageData() {
        // WHEN
        let generated = GeneratedImageData(
            imageData: nil,
            format: .png,
            width: 1024,
            height: 1024,
            model: "test-model"
        )

        // THEN
        #expect(generated.imageData == nil)
        #expect(generated.fileSize == 0, "File size should be 0 when imageData is nil")
    }

    // MARK: - SerializableTypedData Conformance Tests

    @Test func testPreferredFormat() {
        // GIVEN
        let generated = GeneratedImageData(
            imageData: Data("test".utf8),
            format: .png,
            width: 1024,
            height: 1024,
            model: "test-model"
        )

        // THEN
        #expect(generated.preferredFormat == .plist)
    }

    // MARK: - Codable Tests

    @Test func testGeneratedImageDataCodable() throws {
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

        #expect(decoded.imageData == original.imageData)
        #expect(decoded.format == original.format)
        #expect(decoded.width == original.width)
        #expect(decoded.height == original.height)
        #expect(decoded.model == original.model)
        #expect(decoded.revisedPrompt == original.revisedPrompt)
    }

    @Test func testGeneratedImageDataCodableWithNilValues() throws {
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
        #expect(decoded.imageData == nil)
        #expect(decoded.revisedPrompt == nil)
    }

    // MARK: - ImageGenerationConfig.ImageSize Tests

    @Test func testImageSizeSquare1024() {
        // WHEN
        let size = ImageGenerationConfig.ImageSize.square1024

        // THEN
        #expect(size.width == 1024)
        #expect(size.height == 1024)
        #expect(size.aspectRatioDescription == "1:1 (Square)")
    }

    @Test func testImageSizeSquare512() {
        // WHEN
        let size = ImageGenerationConfig.ImageSize.square512

        // THEN
        #expect(size.width == 512)
        #expect(size.height == 512)
    }

    @Test func testImageSizeSquare256() {
        // WHEN
        let size = ImageGenerationConfig.ImageSize.square256

        // THEN
        #expect(size.width == 256)
        #expect(size.height == 256)
    }

    @Test func testImageSizeWide16x9() {
        // WHEN
        let size = ImageGenerationConfig.ImageSize.wide16x9

        // THEN
        #expect(size.width == 1792)
        #expect(size.height == 1024)
        #expect(size.aspectRatioDescription == "16:9 (Widescreen)")
    }

    @Test func testImageSizePortrait9x16() {
        // WHEN
        let size = ImageGenerationConfig.ImageSize.portrait9x16

        // THEN
        #expect(size.width == 1024)
        #expect(size.height == 1792)
        #expect(size.aspectRatioDescription == "9:16 (Portrait)")
    }

    @Test func testImageSizeAspectRatio() {
        // Test aspect ratio calculations
        let square = ImageGenerationConfig.ImageSize.square1024
        let wide = ImageGenerationConfig.ImageSize.wide16x9
        let portrait = ImageGenerationConfig.ImageSize.portrait9x16

        #expect(square.aspectRatio == 1.0, accuracy: 0.01)
        #expect(wide.aspectRatio > 1.0, "Wide should be > 1.0")
        #expect(portrait.aspectRatio < 1.0, "Portrait should be < 1.0")
    }

    @Test func testImageSizeUseCase() {
        // THEN
        #expect(!ImageGenerationConfig.ImageSize.square1024.useCase.isEmpty)
        #expect(!ImageGenerationConfig.ImageSize.wide16x9.useCase.isEmpty)
        #expect(!ImageGenerationConfig.ImageSize.portrait9x16.useCase.isEmpty)
    }

    // MARK: - ImageGenerationConfig Tests

    @Test func testImageGenerationConfigInitialization() {
        // WHEN
        let config = ImageGenerationConfig(
            size: .square1024,
            quality: .hd,
            style: .vivid,
            numberOfImages: 1
        )

        // THEN
        #expect(config.size == .square1024)
        #expect(config.quality == .hd)
        #expect(config.style == .vivid)
        #expect(config.numberOfImages == 1)
    }

    @Test func testImageGenerationConfigDefaults() {
        // WHEN
        let config = ImageGenerationConfig()

        // THEN
        #expect(config.size == .square1024)
        #expect(config.quality == .standard)
        #expect(config.style == .vivid)
        #expect(config.numberOfImages == 1)
    }

    @Test func testImageGenerationConfigQuality() {
        // Test quality options
        #expect(ImageGenerationConfig.Quality.standard.rawValue == "standard")
        #expect(ImageGenerationConfig.Quality.hd.rawValue == "hd")
    }

    @Test func testImageGenerationConfigStyle() {
        // Test style options
        #expect(ImageGenerationConfig.Style.vivid.rawValue == "vivid")
        #expect(ImageGenerationConfig.Style.natural.rawValue == "natural")
    }

    @Test func testImageGenerationConfigCodable() throws {
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
        #expect(decoded.size == original.size)
        #expect(decoded.quality == original.quality)
        #expect(decoded.style == original.style)
        #expect(decoded.numberOfImages == original.numberOfImages)
    }

    // MARK: - Edge Cases

    @Test func testGeneratedImageDataWithAllFormats() {
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
            #expect(generated.format == format)
        }
    }

    @Test func testGeneratedImageDataCustomDimensions() {
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
            #expect(generated.width == width)
            #expect(generated.height == height)
        }
    }

    @Test func testAllImageSizes() {
        // Test all available image sizes
        let sizes: [ImageGenerationConfig.ImageSize] = [
            .square256,
            .square512,
            .square1024,
            .wide16x9,
            .portrait9x16
        ]

        for size in sizes {
            #expect(size.width > 0)
            #expect(size.height > 0)
            #expect(size.aspectRatio > 0)
            #expect(!size.aspectRatioDescription.isEmpty)
            #expect(!size.useCase.isEmpty)
        }
    }

    @Test func testImageGenerationConfigWithDifferentSizes() {
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
            #expect(config.size == size)
        }
    }

    @Test func testImageGenerationConfigWithQualityAndStyle() {
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
            #expect(config.quality == quality)
            #expect(config.style == style)
        }
    }

    @Test func testLargeImageData() {
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
        #expect(generated.fileSize == 1024 * 1024)
    }
}
