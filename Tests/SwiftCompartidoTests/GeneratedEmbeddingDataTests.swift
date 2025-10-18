//
//  GeneratedEmbeddingDataTests.swift
//  SwiftHablareTests
//
//  Phase 5: Tests for GeneratedEmbeddingData and EmbeddingConfig
//

import XCTest
@testable import SwiftCompartido

@available(macOS 15.0, iOS 17.0, *)
final class GeneratedEmbeddingDataTests: XCTestCase {

    // MARK: - GeneratedEmbeddingData Initialization Tests

    func testGeneratedEmbeddingDataInitialization() {
        // GIVEN
        let vector: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let model = "text-embedding-ada-002"
        let inputText = "Test input"

        // WHEN
        let embedding = GeneratedEmbeddingData(
            embedding: vector,
            dimensions: vector.count,
            model: model,
            inputText: inputText,
            tokenCount: 2
        )

        // THEN
        XCTAssertEqual(embedding.embedding, vector)
        XCTAssertEqual(embedding.dimensions, vector.count)
        XCTAssertEqual(embedding.model, model)
        XCTAssertEqual(embedding.inputText, inputText)
        XCTAssertEqual(embedding.tokenCount, 2)
    }

    func testGeneratedEmbeddingDataWithOptionalParameters() {
        // WHEN
        let vector: [Float] = [0.1, 0.2, 0.3]
        let embedding = GeneratedEmbeddingData(
            embedding: vector,
            dimensions: vector.count,
            model: "test-model"
        )

        // THEN
        XCTAssertEqual(embedding.embedding, vector)
        XCTAssertEqual(embedding.dimensions, vector.count)
        XCTAssertEqual(embedding.model, "test-model")
        XCTAssertNil(embedding.inputText)
        XCTAssertNil(embedding.tokenCount)
    }

    func testGeneratedEmbeddingDataEmptyVector() {
        // WHEN
        let embedding = GeneratedEmbeddingData(
            embedding: [],
            dimensions: 0,
            model: "test-model"
        )

        // THEN
        XCTAssertTrue(embedding.embedding?.isEmpty ?? false)
        XCTAssertEqual(embedding.dimensions, 0)
    }

    func testGeneratedEmbeddingDataLargeVector() {
        // GIVEN - Typical embedding dimensions (1536 for OpenAI ada-002)
        let vector = (0..<1536).map { _ in Float.random(in: -1...1) }

        // WHEN
        let embedding = GeneratedEmbeddingData(
            embedding: vector,
            dimensions: vector.count,
            model: "text-embedding-ada-002"
        )

        // THEN
        XCTAssertEqual(embedding.embedding?.count, 1536)
        XCTAssertEqual(embedding.dimensions, 1536)
    }

    func testGeneratedEmbeddingDataWithNilEmbedding() {
        // WHEN
        let embedding = GeneratedEmbeddingData(
            embedding: nil,
            dimensions: 1536,
            model: "test-model"
        )

        // THEN
        XCTAssertNil(embedding.embedding)
        XCTAssertEqual(embedding.dimensions, 1536)
        XCTAssertEqual(embedding.dataSize, 0)
    }

    // MARK: - Serialization Tests

    func testSerializeToBinary() throws {
        // GIVEN
        let vector: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let embedding = GeneratedEmbeddingData(
            embedding: vector,
            dimensions: vector.count,
            model: "test-model"
        )

        // WHEN
        let binaryData = try embedding.serialize()

        // THEN
        XCTAssertFalse(binaryData.isEmpty)
        // Binary data should contain header + vector
        XCTAssertGreaterThan(binaryData.count, vector.count * MemoryLayout<Float>.size)
    }

    func testSerializeNilEmbeddingThrows() {
        // GIVEN
        let embedding = GeneratedEmbeddingData(
            embedding: nil,
            dimensions: 1536,
            model: "test-model"
        )

        // WHEN/THEN
        XCTAssertThrowsError(try embedding.serialize())
    }

    func testDeserializeFromBinary() throws {
        // GIVEN
        let originalVector: [Float] = [1.0, 2.5, 3.75, 4.25, 5.125]
        let original = GeneratedEmbeddingData(
            embedding: originalVector,
            dimensions: originalVector.count,
            model: "test-model",
            inputText: "Test input",
            tokenCount: 2
        )
        let binaryData = try original.serialize()

        // WHEN
        let reconstructed = try GeneratedEmbeddingData.deserialize(from: binaryData, format: .binary)

        // THEN
        XCTAssertEqual(reconstructed.embedding?.count, originalVector.count)
        XCTAssertEqual(reconstructed.dimensions, originalVector.count)
        XCTAssertEqual(reconstructed.model, "test-model")
        if let reVector = reconstructed.embedding {
            for (index, value) in reVector.enumerated() {
                XCTAssertEqual(value, originalVector[index], accuracy: 0.0001)
            }
        } else {
            XCTFail("Reconstructed embedding should not be nil")
        }
    }

    func testBinaryFormatRoundTrip() throws {
        // GIVEN
        let originalVector: [Float] = [-1.5, 0.0, 1.5, 2.25, -3.75, 4.125]
        let original = GeneratedEmbeddingData(
            embedding: originalVector,
            dimensions: originalVector.count,
            model: "test-model"
        )

        // WHEN - Serialize and deserialize
        let binaryData = try original.serialize()
        let reconstructed = try GeneratedEmbeddingData.deserialize(from: binaryData, format: .binary)

        // THEN
        XCTAssertEqual(reconstructed.embedding?.count, originalVector.count)
        if let reVector = reconstructed.embedding {
            for (index, value) in reVector.enumerated() {
                XCTAssertEqual(value, originalVector[index], accuracy: 0.0001,
                              "Value at index \(index) should match")
            }
        }
    }

    func testSerializeLargeVector() throws {
        // GIVEN - Large vector typical of embeddings
        let originalVector = (0..<1536).map { Float($0) / 1536.0 }
        let embedding = GeneratedEmbeddingData(
            embedding: originalVector,
            dimensions: originalVector.count,
            model: "test-model"
        )

        // WHEN
        let binaryData = try embedding.serialize()

        // THEN
        // Binary data should include header + vector data
        XCTAssertGreaterThan(binaryData.count, originalVector.count * 4)
    }

    // MARK: - SerializableTypedData Conformance Tests

    func testPreferredFormat() {
        // GIVEN
        let embedding = GeneratedEmbeddingData(
            embedding: [0.1, 0.2],
            dimensions: 2,
            model: "test-model"
        )

        // THEN
        XCTAssertEqual(embedding.preferredFormat, .binary)
    }

    // MARK: - Codable Tests

    func testGeneratedEmbeddingDataCodable() throws {
        // GIVEN
        let vector: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let original = GeneratedEmbeddingData(
            embedding: vector,
            dimensions: vector.count,
            model: "text-embedding-ada-002",
            inputText: "Test input",
            tokenCount: 2
        )

        // WHEN - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        // THEN - Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GeneratedEmbeddingData.self, from: data)

        XCTAssertEqual(decoded.embedding, original.embedding)
        XCTAssertEqual(decoded.dimensions, original.dimensions)
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.inputText, original.inputText)
        XCTAssertEqual(decoded.tokenCount, original.tokenCount)
    }

    func testGeneratedEmbeddingDataCodableWithNilValues() throws {
        // GIVEN
        let original = GeneratedEmbeddingData(
            embedding: [0.1, 0.2],
            dimensions: 2,
            model: "test-model"
        )

        // WHEN
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GeneratedEmbeddingData.self, from: data)

        // THEN
        XCTAssertEqual(decoded.embedding, original.embedding)
        XCTAssertNil(decoded.inputText)
        XCTAssertNil(decoded.tokenCount)
    }

    // MARK: - Data Size Tests

    func testDataSize() {
        // GIVEN
        let vector: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let embedding = GeneratedEmbeddingData(
            embedding: vector,
            dimensions: vector.count,
            model: "test-model"
        )

        // WHEN
        let dataSize = embedding.dataSize

        // THEN
        XCTAssertEqual(dataSize, vector.count * MemoryLayout<Float>.size)
    }

    func testDataSizeWithNilEmbedding() {
        // GIVEN
        let embedding = GeneratedEmbeddingData(
            embedding: nil,
            dimensions: 1536,
            model: "test-model"
        )

        // WHEN
        let dataSize = embedding.dataSize

        // THEN
        XCTAssertEqual(dataSize, 0)
    }

    // MARK: - EmbeddingConfig Tests

    func testEmbeddingConfigInitialization() {
        // WHEN
        let config = EmbeddingConfig(
            model: .textEmbedding3Large,
            dimensions: 3072
        )

        // THEN
        XCTAssertEqual(config.model, .textEmbedding3Large)
        XCTAssertEqual(config.dimensions, 3072)
    }

    func testEmbeddingConfigDefaults() {
        // WHEN
        let config = EmbeddingConfig()

        // THEN
        XCTAssertEqual(config.model, .textEmbedding3Small)
        XCTAssertNil(config.dimensions, "Dimensions should be nil by default (uses model default)")
    }

    func testEmbeddingConfigDefault() {
        // WHEN
        let config = EmbeddingConfig.default

        // THEN
        XCTAssertEqual(config.model, .textEmbedding3Small)
        XCTAssertNil(config.dimensions)
    }

    func testEmbeddingConfigHighQuality() {
        // WHEN
        let config = EmbeddingConfig.highQuality

        // THEN
        XCTAssertEqual(config.model, .textEmbedding3Large)
    }

    func testEmbeddingConfigPerformance() {
        // WHEN
        let config = EmbeddingConfig.performance

        // THEN
        XCTAssertEqual(config.model, .textEmbedding3Small)
        XCTAssertEqual(config.dimensions, 512, "Performance should use reduced dimensions")
    }

    func testEmbeddingConfigLegacy() {
        // WHEN
        let config = EmbeddingConfig.legacy

        // THEN
        XCTAssertEqual(config.model, .textEmbeddingAda002)
    }

    func testEmbeddingConfigCodable() throws {
        // GIVEN
        let original = EmbeddingConfig(
            model: .textEmbedding3Large,
            dimensions: 3072
        )

        // WHEN
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EmbeddingConfig.self, from: data)

        // THEN
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.dimensions, original.dimensions)
    }

    func testEmbeddingConfigModelDisplayNames() {
        // THEN
        XCTAssertEqual(EmbeddingConfig.Model.textEmbedding3Small.displayName, "Text Embedding 3 Small")
        XCTAssertEqual(EmbeddingConfig.Model.textEmbedding3Large.displayName, "Text Embedding 3 Large")
        XCTAssertEqual(EmbeddingConfig.Model.textEmbeddingAda002.displayName, "Ada 002 (Legacy)")
    }

    func testEmbeddingConfigModelDefaultDimensions() {
        // THEN
        XCTAssertEqual(EmbeddingConfig.Model.textEmbedding3Small.defaultDimensions, 1536)
        XCTAssertEqual(EmbeddingConfig.Model.textEmbedding3Large.defaultDimensions, 3072)
        XCTAssertEqual(EmbeddingConfig.Model.textEmbeddingAda002.defaultDimensions, 1536)
    }

    func testEmbeddingConfigModelSupportsCustomDimensions() {
        // THEN
        XCTAssertTrue(EmbeddingConfig.Model.textEmbedding3Small.supportsCustomDimensions)
        XCTAssertTrue(EmbeddingConfig.Model.textEmbedding3Large.supportsCustomDimensions)
        XCTAssertFalse(EmbeddingConfig.Model.textEmbeddingAda002.supportsCustomDimensions)
    }

    // MARK: - Edge Cases

    func testGeneratedEmbeddingDataWithNegativeValues() {
        // GIVEN
        let vector: [Float] = [-1.0, -0.5, 0.0, 0.5, 1.0]
        let embedding = GeneratedEmbeddingData(
            embedding: vector,
            dimensions: vector.count,
            model: "test-model"
        )

        // THEN
        XCTAssertEqual(embedding.embedding, vector)
        XCTAssertTrue(embedding.embedding?.contains { $0 < 0 } ?? false)
    }

    func testGeneratedEmbeddingDataWithExtremeValues() {
        // GIVEN
        let vector: [Float] = [Float.greatestFiniteMagnitude, Float.leastNormalMagnitude, -Float.greatestFiniteMagnitude]
        let embedding = GeneratedEmbeddingData(
            embedding: vector,
            dimensions: vector.count,
            model: "test-model"
        )

        // THEN
        XCTAssertEqual(embedding.embedding?.count, 3)
    }

    func testSerializePreservesFloatPrecision() throws {
        // GIVEN - Test precision preservation
        let originalVector: [Float] = [1.123456, 2.234567, 3.345678, 4.456789, 5.567890]
        let original = GeneratedEmbeddingData(
            embedding: originalVector,
            dimensions: originalVector.count,
            model: "test-model"
        )

        // WHEN
        let binaryData = try original.serialize()
        let reconstructed = try GeneratedEmbeddingData.deserialize(from: binaryData, format: .binary)

        // THEN - Should preserve Float precision (not full decimal precision)
        if let reVector = reconstructed.embedding {
            for (index, value) in reVector.enumerated() {
                XCTAssertEqual(value, originalVector[index], accuracy: 0.000001)
            }
        } else {
            XCTFail("Reconstructed embedding should not be nil")
        }
    }

    func testInputTextTruncation() {
        // GIVEN - Input text longer than 1000 characters
        let longText = String(repeating: "a", count: 1500)
        let embedding = GeneratedEmbeddingData(
            embedding: [0.1, 0.2],
            dimensions: 2,
            model: "test-model",
            inputText: longText
        )

        // THEN - Should be truncated to 1000 characters + "..."
        XCTAssertNotNil(embedding.inputText)
        XCTAssertLessThanOrEqual(embedding.inputText?.count ?? 0, 1003)
        XCTAssertTrue(embedding.inputText?.hasSuffix("...") ?? false)
    }

    func testBatchIndex() {
        // GIVEN
        let embedding = GeneratedEmbeddingData(
            embedding: [0.1, 0.2],
            dimensions: 2,
            model: "test-model",
            inputText: "Test",
            tokenCount: 1,
            index: 5
        )

        // THEN
        XCTAssertEqual(embedding.index, 5)
    }
}
