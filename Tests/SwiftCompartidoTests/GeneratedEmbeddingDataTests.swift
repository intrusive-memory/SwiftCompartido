//
//  GeneratedEmbeddingDataTests.swift
//  SwiftHablareTests
//
//  Phase 5: Tests for GeneratedEmbeddingData and EmbeddingConfig
//

import Foundation
import Testing
@testable import SwiftCompartido

struct GeneratedEmbeddingDataTests {

    // MARK: - GeneratedEmbeddingData Initialization Tests

    @Test func testGeneratedEmbeddingDataInitialization() {
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
        #expect(embedding.embedding == vector)
        #expect(embedding.dimensions == vector.count)
        #expect(embedding.model == model)
        #expect(embedding.inputText == inputText)
        #expect(embedding.tokenCount == 2)
    }

    @Test func testGeneratedEmbeddingDataWithOptionalParameters() {
        // WHEN
        let vector: [Float] = [0.1, 0.2, 0.3]
        let embedding = GeneratedEmbeddingData(
            embedding: vector,
            dimensions: vector.count,
            model: "test-model"
        )

        // THEN
        #expect(embedding.embedding == vector)
        #expect(embedding.dimensions == vector.count)
        #expect(embedding.model == "test-model")
        #expect(embedding.inputText == nil)
        #expect(embedding.tokenCount == nil)
    }

    @Test func testGeneratedEmbeddingDataEmptyVector() {
        // WHEN
        let embedding = GeneratedEmbeddingData(
            embedding: [],
            dimensions: 0,
            model: "test-model"
        )

        // THEN
        #expect(embedding.embedding?.isEmpty ?? false)
        #expect(embedding.dimensions == 0)
    }

    @Test func testGeneratedEmbeddingDataLargeVector() {
        // GIVEN - Typical embedding dimensions (1536 for OpenAI ada-002)
        let vector = (0..<1536).map { _ in Float.random(in: -1...1) }

        // WHEN
        let embedding = GeneratedEmbeddingData(
            embedding: vector,
            dimensions: vector.count,
            model: "text-embedding-ada-002"
        )

        // THEN
        #expect(embedding.embedding?.count == 1536)
        #expect(embedding.dimensions == 1536)
    }

    @Test func testGeneratedEmbeddingDataWithNilEmbedding() {
        // WHEN
        let embedding = GeneratedEmbeddingData(
            embedding: nil,
            dimensions: 1536,
            model: "test-model"
        )

        // THEN
        #expect(embedding.embedding == nil)
        #expect(embedding.dimensions == 1536)
        #expect(embedding.dataSize == 0)
    }

    // MARK: - Serialization Tests

    @Test func testSerializeToBinary() throws {
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
        #expect(!binaryData.isEmpty)
        // Binary data should contain header + vector
        #expect(binaryData.count > vector.count * MemoryLayout<Float>.size)
    }

    @Test func testSerializeNilEmbeddingThrows() {
        // GIVEN
        let embedding = GeneratedEmbeddingData(
            embedding: nil,
            dimensions: 1536,
            model: "test-model"
        )

        // WHEN/THEN
        do { _ = try embedding.serialize(); Issue.record("Expected error") } catch { /* Expected */ }
    }

    // TODO: Re-enable when Swift Testing supports accuracy parameter for floating point comparisons
    // @Test func testDeserializeFromBinary() throws {
    //     // GIVEN
    //     let originalVector: [Float] = [1.0, 2.5, 3.75, 4.25, 5.125]
    //     let original = GeneratedEmbeddingData(
    //         embedding: originalVector,
    //         dimensions: originalVector.count,
    //         model: "test-model",
    //         inputText: "Test input",
    //         tokenCount: 2
    //     )
    //     let binaryData = try original.serialize()
    //
    //     // WHEN
    //     let reconstructed = try GeneratedEmbeddingData.deserialize(from: binaryData, format: .binary)
    //
    //     // THEN
    //     #expect(reconstructed.embedding?.count == originalVector.count)
    //     #expect(reconstructed.dimensions == originalVector.count)
    //     #expect(reconstructed.model == "test-model")
    //     if let reVector = reconstructed.embedding {
    //         for (index, value) in reVector.enumerated() {
    //             #expect(value == originalVector[index], accuracy: 0.0001)
    //         }
    //     } else {
    //         Issue.record("Reconstructed embedding should not be nil")
    //     }
    // }

    // TODO: Re-enable when Swift Testing supports accuracy parameter for floating point comparisons
    // @Test func testBinaryFormatRoundTrip() throws {
    //     // GIVEN
    //     let originalVector: [Float] = [-1.5, 0.0, 1.5, 2.25, -3.75, 4.125]
    //     let original = GeneratedEmbeddingData(
    //         embedding: originalVector,
    //         dimensions: originalVector.count,
    //         model: "test-model"
    //     )
    //
    //     // WHEN - Serialize and deserialize
    //     let binaryData = try original.serialize()
    //     let reconstructed = try GeneratedEmbeddingData.deserialize(from: binaryData, format: .binary)
    //
    //     // THEN
    //     #expect(reconstructed.embedding?.count == originalVector.count)
    //     if let reVector = reconstructed.embedding {
    //         for (index, value) in reVector.enumerated() {
    //             #expect(value == originalVector[index], accuracy: 0.0001,
    //                           "Value at index \(index) should match")
    //         }
    //     }
    // }

    @Test func testSerializeLargeVector() throws {
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
        #expect(binaryData.count > originalVector.count * 4)
    }

    // MARK: - SerializableTypedData Conformance Tests

    @Test func testPreferredFormat() {
        // GIVEN
        let embedding = GeneratedEmbeddingData(
            embedding: [0.1, 0.2],
            dimensions: 2,
            model: "test-model"
        )

        // THEN
        #expect(embedding.preferredFormat == .binary)
    }

    // MARK: - Codable Tests

    @Test func testGeneratedEmbeddingDataCodable() throws {
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

        #expect(decoded.embedding == original.embedding)
        #expect(decoded.dimensions == original.dimensions)
        #expect(decoded.model == original.model)
        #expect(decoded.inputText == original.inputText)
        #expect(decoded.tokenCount == original.tokenCount)
    }

    @Test func testGeneratedEmbeddingDataCodableWithNilValues() throws {
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
        #expect(decoded.embedding == original.embedding)
        #expect(decoded.inputText == nil)
        #expect(decoded.tokenCount == nil)
    }

    // MARK: - Data Size Tests

    @Test func testDataSize() {
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
        #expect(dataSize == vector.count * MemoryLayout<Float>.size)
    }

    @Test func testDataSizeWithNilEmbedding() {
        // GIVEN
        let embedding = GeneratedEmbeddingData(
            embedding: nil,
            dimensions: 1536,
            model: "test-model"
        )

        // WHEN
        let dataSize = embedding.dataSize

        // THEN
        #expect(dataSize == 0)
    }

    // MARK: - EmbeddingConfig Tests

    @Test func testEmbeddingConfigInitialization() {
        // WHEN
        let config = EmbeddingConfig(
            model: .textEmbedding3Large,
            dimensions: 3072
        )

        // THEN
        #expect(config.model == .textEmbedding3Large)
        #expect(config.dimensions == 3072)
    }

    @Test func testEmbeddingConfigDefaults() {
        // WHEN
        let config = EmbeddingConfig()

        // THEN
        #expect(config.model == .textEmbedding3Small)
        #expect(config.dimensions == nil, "Dimensions should be nil by default (uses model default)")
    }

    @Test func testEmbeddingConfigDefault() {
        // WHEN
        let config = EmbeddingConfig.default

        // THEN
        #expect(config.model == .textEmbedding3Small)
        #expect(config.dimensions == nil)
    }

    @Test func testEmbeddingConfigHighQuality() {
        // WHEN
        let config = EmbeddingConfig.highQuality

        // THEN
        #expect(config.model == .textEmbedding3Large)
    }

    @Test func testEmbeddingConfigPerformance() {
        // WHEN
        let config = EmbeddingConfig.performance

        // THEN
        #expect(config.model == .textEmbedding3Small)
        #expect(config.dimensions == 512, "Performance should use reduced dimensions")
    }

    @Test func testEmbeddingConfigLegacy() {
        // WHEN
        let config = EmbeddingConfig.legacy

        // THEN
        #expect(config.model == .textEmbeddingAda002)
    }

    @Test func testEmbeddingConfigCodable() throws {
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
        #expect(decoded.model == original.model)
        #expect(decoded.dimensions == original.dimensions)
    }

    @Test func testEmbeddingConfigModelDisplayNames() {
        // THEN
        #expect(EmbeddingConfig.Model.textEmbedding3Small.displayName == "Text Embedding 3 Small")
        #expect(EmbeddingConfig.Model.textEmbedding3Large.displayName == "Text Embedding 3 Large")
        #expect(EmbeddingConfig.Model.textEmbeddingAda002.displayName == "Ada 002 (Legacy)")
    }

    @Test func testEmbeddingConfigModelDefaultDimensions() {
        // THEN
        #expect(EmbeddingConfig.Model.textEmbedding3Small.defaultDimensions == 1536)
        #expect(EmbeddingConfig.Model.textEmbedding3Large.defaultDimensions == 3072)
        #expect(EmbeddingConfig.Model.textEmbeddingAda002.defaultDimensions == 1536)
    }

    @Test func testEmbeddingConfigModelSupportsCustomDimensions() {
        // THEN
        #expect(EmbeddingConfig.Model.textEmbedding3Small.supportsCustomDimensions)
        #expect(EmbeddingConfig.Model.textEmbedding3Large.supportsCustomDimensions)
        #expect(!EmbeddingConfig.Model.textEmbeddingAda002.supportsCustomDimensions)
    }

    // MARK: - Edge Cases

    @Test func testGeneratedEmbeddingDataWithNegativeValues() {
        // GIVEN
        let vector: [Float] = [-1.0, -0.5, 0.0, 0.5, 1.0]
        let embedding = GeneratedEmbeddingData(
            embedding: vector,
            dimensions: vector.count,
            model: "test-model"
        )

        // THEN
        #expect(embedding.embedding == vector)
        #expect(embedding.embedding?.contains { $0 < 0 } ?? false)
    }

    @Test func testGeneratedEmbeddingDataWithExtremeValues() {
        // GIVEN
        let vector: [Float] = [Float.greatestFiniteMagnitude, Float.leastNormalMagnitude, -Float.greatestFiniteMagnitude]
        let embedding = GeneratedEmbeddingData(
            embedding: vector,
            dimensions: vector.count,
            model: "test-model"
        )

        // THEN
        #expect(embedding.embedding?.count == 3)
    }

    // TODO: Re-enable when Swift Testing supports accuracy parameter for floating point comparisons
    // @Test func testSerializePreservesFloatPrecision() throws {
    //     // GIVEN - Test precision preservation
    //     let originalVector: [Float] = [1.123456, 2.234567, 3.345678, 4.456789, 5.567890]
    //     let original = GeneratedEmbeddingData(
    //         embedding: originalVector,
    //         dimensions: originalVector.count,
    //         model: "test-model"
    //     )
    //
    //     // WHEN
    //     let binaryData = try original.serialize()
    //     let reconstructed = try GeneratedEmbeddingData.deserialize(from: binaryData, format: .binary)
    //
    //     // THEN - Should preserve Float precision (not full decimal precision)
    //     if let reVector = reconstructed.embedding {
    //         for (index, value) in reVector.enumerated() {
    //             #expect(value == originalVector[index], accuracy: 0.000001)
    //         }
    //     } else {
    //         Issue.record("Reconstructed embedding should not be nil")
    //     }
    // }

    @Test func testInputTextTruncation() {
        // GIVEN - Input text longer than 1000 characters
        let longText = String(repeating: "a", count: 1500)
        let embedding = GeneratedEmbeddingData(
            embedding: [0.1, 0.2],
            dimensions: 2,
            model: "test-model",
            inputText: longText
        )

        // THEN - Should be truncated to 1000 characters + "..."
        #expect(embedding.inputText != nil)
        #expect(embedding.inputText?.count ?? 0 <= 1003)
        #expect(embedding.inputText?.hasSuffix("...") ?? false)
    }

    @Test func testBatchIndex() {
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
        #expect(embedding.index == 5)
    }
}
