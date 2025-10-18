//
//  GeneratedTextDataTests.swift
//  SwiftHablareTests
//
//  Phase 5: Tests for GeneratedTextData and TextGenerationConfig
//

import XCTest
@testable import SwiftCompartido

@available(macOS 15.0, iOS 17.0, *)
final class GeneratedTextDataTests: XCTestCase {

    // MARK: - GeneratedTextData Initialization Tests

    func testGeneratedTextDataInitialization() {
        // GIVEN
        let text = "Hello world, this is a test."
        let model = "gpt-4"
        let completionTokens = 6
        let promptTokens = 10

        // WHEN
        let generated = GeneratedTextData(
            text: text,
            model: model,
            completionTokens: completionTokens,
            promptTokens: promptTokens
        )

        // THEN
        XCTAssertEqual(generated.text, text)
        XCTAssertEqual(generated.model, model)
        XCTAssertEqual(generated.completionTokens, completionTokens)
        XCTAssertEqual(generated.promptTokens, promptTokens)
    }

    func testGeneratedTextDataWithOptionalParameters() {
        // WHEN
        let generated = GeneratedTextData(
            text: "Test text",
            model: "gpt-3.5-turbo"
        )

        // THEN
        XCTAssertEqual(generated.text, "Test text")
        XCTAssertEqual(generated.model, "gpt-3.5-turbo")
        XCTAssertNil(generated.promptTokens)
        XCTAssertNil(generated.completionTokens)
    }

    // MARK: - Word Count Tests

    func testWordCount() {
        // GIVEN
        let text = "Hello world, this is a test."
        let generated = GeneratedTextData(text: text, model: "test-model")

        // WHEN
        let wordCount = generated.wordCount

        // THEN
        XCTAssertEqual(wordCount, 6, "Should count 6 words")
    }

    func testWordCountWithEmptyText() {
        // GIVEN
        let generated = GeneratedTextData(text: "", model: "test-model")

        // WHEN
        let wordCount = generated.wordCount

        // THEN
        XCTAssertEqual(wordCount, 0, "Empty text should have 0 words")
    }

    func testWordCountWithWhitespaceOnly() {
        // GIVEN
        let generated = GeneratedTextData(text: "   \n\t  ", model: "test-model")

        // WHEN
        let wordCount = generated.wordCount

        // THEN
        XCTAssertEqual(wordCount, 0, "Whitespace-only text should have 0 words")
    }

    func testWordCountWithMultipleSpaces() {
        // GIVEN
        let text = "Hello    world   test"
        let generated = GeneratedTextData(text: text, model: "test-model")

        // WHEN
        let wordCount = generated.wordCount

        // THEN
        XCTAssertEqual(wordCount, 3, "Should handle multiple spaces between words")
    }

    func testWordCountWithNewlines() {
        // GIVEN
        let text = "Hello\nworld\ntest"
        let generated = GeneratedTextData(text: text, model: "test-model")

        // WHEN
        let wordCount = generated.wordCount

        // THEN
        XCTAssertEqual(wordCount, 3, "Should count words across newlines")
    }

    // MARK: - Character Count Tests

    func testCharacterCount() {
        // GIVEN
        let text = "Hello"
        let generated = GeneratedTextData(text: text, model: "test-model")

        // WHEN
        let charCount = generated.characterCount

        // THEN
        XCTAssertEqual(charCount, 5)
    }

    func testCharacterCountWithWhitespace() {
        // GIVEN
        let text = "Hello world"
        let generated = GeneratedTextData(text: text, model: "test-model")

        // WHEN
        let charCount = generated.characterCount

        // THEN
        XCTAssertEqual(charCount, 11, "Should include space in count")
    }

    func testCharacterCountWithEmptyText() {
        // GIVEN
        let generated = GeneratedTextData(text: "", model: "test-model")

        // WHEN
        let charCount = generated.characterCount

        // THEN
        XCTAssertEqual(charCount, 0)
    }

    // MARK: - Token Count Tests

    func testTokenCounts() {
        // WHEN
        let generated = GeneratedTextData(
            text: "Test",
            model: "gpt-4",
            tokenCount: 30,
            completionTokens: 20,
            promptTokens: 10
        )

        // THEN
        XCTAssertEqual(generated.tokenCount, 30)
        XCTAssertEqual(generated.completionTokens, 20)
        XCTAssertEqual(generated.promptTokens, 10)
    }

    func testTokenCountsWithNilValues() {
        // WHEN
        let generated = GeneratedTextData(text: "Test", model: "gpt-4")

        // THEN
        XCTAssertNil(generated.tokenCount)
        XCTAssertNil(generated.completionTokens)
        XCTAssertNil(generated.promptTokens)
    }

    // MARK: - SerializableTypedData Conformance Tests

    func testPreferredFormat() {
        // GIVEN
        let generated = GeneratedTextData(text: "Test", model: "gpt-4")

        // THEN
        XCTAssertEqual(generated.preferredFormat, .json)
    }

    // MARK: - Codable Tests

    func testGeneratedTextDataCodable() throws {
        // GIVEN
        let original = GeneratedTextData(
            text: "Hello world",
            model: "gpt-4",
            tokenCount: 7,
            completionTokens: 2,
            promptTokens: 5
        )

        // WHEN - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        // THEN - Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GeneratedTextData.self, from: data)

        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.tokenCount, original.tokenCount)
        XCTAssertEqual(decoded.completionTokens, original.completionTokens)
        XCTAssertEqual(decoded.promptTokens, original.promptTokens)
    }

    func testGeneratedTextDataCodableWithNilValues() throws {
        // GIVEN
        let original = GeneratedTextData(text: "Test", model: "gpt-3.5-turbo")

        // WHEN
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GeneratedTextData.self, from: data)

        // THEN
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertNil(decoded.tokenCount)
        XCTAssertNil(decoded.completionTokens)
        XCTAssertNil(decoded.promptTokens)
    }

    // MARK: - TextGenerationConfig Tests

    func testTextGenerationConfigInitialization() {
        // WHEN
        let config = TextGenerationConfig(
            temperature: 0.8,
            maxTokens: 1000,
            topP: 0.9,
            frequencyPenalty: 0.5,
            presencePenalty: 0.3
        )

        // THEN
        XCTAssertEqual(config.temperature, 0.8)
        XCTAssertEqual(config.maxTokens, 1000)
        XCTAssertEqual(config.topP, 0.9)
        XCTAssertEqual(config.frequencyPenalty, 0.5)
        XCTAssertEqual(config.presencePenalty, 0.3)
    }

    func testTextGenerationConfigDefaults() {
        // WHEN
        let config = TextGenerationConfig()

        // THEN
        XCTAssertEqual(config.temperature, 0.7)
        XCTAssertEqual(config.maxTokens, 2048)
        XCTAssertEqual(config.topP, 1.0)
        XCTAssertEqual(config.frequencyPenalty, 0.0)
        XCTAssertEqual(config.presencePenalty, 0.0)
    }

    func testTextGenerationConfigDefault() {
        // WHEN
        let config = TextGenerationConfig.default

        // THEN
        XCTAssertEqual(config.temperature, 0.7)
        XCTAssertEqual(config.maxTokens, 2048)
    }

    func testTextGenerationConfigConservative() {
        // WHEN
        let config = TextGenerationConfig.conservative

        // THEN
        XCTAssertEqual(config.temperature, 0.3, "Conservative should have low temperature")
        XCTAssertEqual(config.maxTokens, 1024, "Conservative should have lower max tokens")
        XCTAssertEqual(config.topP, 0.9)
    }

    func testTextGenerationConfigCreative() {
        // WHEN
        let config = TextGenerationConfig.creative

        // THEN
        XCTAssertEqual(config.temperature, 1.2, "Creative should have high temperature")
        XCTAssertEqual(config.maxTokens, 4096, "Creative should have higher max tokens")
        XCTAssertEqual(config.topP, 0.95)
        XCTAssertEqual(config.presencePenalty, 0.6, "Creative should encourage diversity")
    }

    func testTextGenerationConfigCodable() throws {
        // GIVEN
        let original = TextGenerationConfig(
            temperature: 0.8,
            maxTokens: 1500,
            topP: 0.95,
            frequencyPenalty: 0.2,
            presencePenalty: 0.1
        )

        // WHEN
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TextGenerationConfig.self, from: data)

        // THEN
        XCTAssertEqual(decoded.temperature, original.temperature)
        XCTAssertEqual(decoded.maxTokens, original.maxTokens)
        XCTAssertEqual(decoded.topP, original.topP)
        XCTAssertEqual(decoded.frequencyPenalty, original.frequencyPenalty)
        XCTAssertEqual(decoded.presencePenalty, original.presencePenalty)
    }

    // MARK: - Edge Cases

    func testGeneratedTextDataWithLongText() {
        // GIVEN
        let longText = String(repeating: "Hello world. ", count: 1000)
        let generated = GeneratedTextData(text: longText, model: "gpt-4")

        // THEN
        XCTAssertEqual(generated.text, longText)
        XCTAssertGreaterThan(generated.wordCount, 1000)
        XCTAssertGreaterThan(generated.characterCount, 10000)
    }

    func testGeneratedTextDataWithUnicodeCharacters() {
        // GIVEN
        let text = "Hello 世界 🌍 Привет"
        let generated = GeneratedTextData(text: text, model: "gpt-4")

        // WHEN
        let charCount = generated.characterCount
        let wordCount = generated.wordCount

        // THEN
        XCTAssertEqual(charCount, text.count)
        XCTAssertEqual(wordCount, 4, "Should count Unicode words correctly")
    }

    func testTextGenerationConfigBoundaryValues() {
        // Test boundary values for temperature and penalties
        let configMin = TextGenerationConfig(
            temperature: 0.0,
            maxTokens: 1,
            topP: 0.0,
            frequencyPenalty: 0.0,
            presencePenalty: 0.0
        )

        let configMax = TextGenerationConfig(
            temperature: 2.0,
            maxTokens: 8000,
            topP: 1.0,
            frequencyPenalty: 2.0,
            presencePenalty: 2.0
        )

        XCTAssertEqual(configMin.temperature, 0.0)
        XCTAssertEqual(configMin.maxTokens, 1)
        XCTAssertEqual(configMax.temperature, 2.0)
        XCTAssertEqual(configMax.maxTokens, 8000)
    }
}
