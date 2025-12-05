//
//  GeneratedTextDataTests.swift
//  SwiftHablareTests
//
//  Phase 5: Tests for GeneratedTextData and TextGenerationConfig
//

import Testing
@testable import SwiftCompartido

struct GeneratedTextDataTests {

    // MARK: - GeneratedTextData Initialization Tests

    @Test func testGeneratedTextDataInitialization() {
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
        #expect(generated.text == text)
        #expect(generated.model == model)
        #expect(generated.completionTokens == completionTokens)
        #expect(generated.promptTokens == promptTokens)
    }

    @Test func testGeneratedTextDataWithOptionalParameters() {
        // WHEN
        let generated = GeneratedTextData(
            text: "Test text",
            model: "gpt-3.5-turbo"
        )

        // THEN
        #expect(generated.text == "Test text")
        #expect(generated.model == "gpt-3.5-turbo")
        #expect(generated.promptTokens == nil)
        #expect(generated.completionTokens == nil)
    }

    // MARK: - Word Count Tests

    @Test func testWordCount() {
        // GIVEN
        let text = "Hello world, this is a test."
        let generated = GeneratedTextData(text: text, model: "test-model")

        // WHEN
        let wordCount = generated.wordCount

        // THEN
        #expect(wordCount == 6, "Should count 6 words")
    }

    @Test func testWordCountWithEmptyText() {
        // GIVEN
        let generated = GeneratedTextData(text: "", model: "test-model")

        // WHEN
        let wordCount = generated.wordCount

        // THEN
        #expect(wordCount == 0, "Empty text should have 0 words")
    }

    @Test func testWordCountWithWhitespaceOnly() {
        // GIVEN
        let generated = GeneratedTextData(text: "   \n\t  ", model: "test-model")

        // WHEN
        let wordCount = generated.wordCount

        // THEN
        #expect(wordCount == 0, "Whitespace-only text should have 0 words")
    }

    @Test func testWordCountWithMultipleSpaces() {
        // GIVEN
        let text = "Hello    world   test"
        let generated = GeneratedTextData(text: text, model: "test-model")

        // WHEN
        let wordCount = generated.wordCount

        // THEN
        #expect(wordCount == 3, "Should handle multiple spaces between words")
    }

    @Test func testWordCountWithNewlines() {
        // GIVEN
        let text = "Hello\nworld\ntest"
        let generated = GeneratedTextData(text: text, model: "test-model")

        // WHEN
        let wordCount = generated.wordCount

        // THEN
        #expect(wordCount == 3, "Should count words across newlines")
    }

    // MARK: - Character Count Tests

    @Test func testCharacterCount() {
        // GIVEN
        let text = "Hello"
        let generated = GeneratedTextData(text: text, model: "test-model")

        // WHEN
        let charCount = generated.characterCount

        // THEN
        #expect(charCount == 5)
    }

    @Test func testCharacterCountWithWhitespace() {
        // GIVEN
        let text = "Hello world"
        let generated = GeneratedTextData(text: text, model: "test-model")

        // WHEN
        let charCount = generated.characterCount

        // THEN
        #expect(charCount == 11, "Should include space in count")
    }

    @Test func testCharacterCountWithEmptyText() {
        // GIVEN
        let generated = GeneratedTextData(text: "", model: "test-model")

        // WHEN
        let charCount = generated.characterCount

        // THEN
        #expect(charCount == 0)
    }

    // MARK: - Token Count Tests

    @Test func testTokenCounts() {
        // WHEN
        let generated = GeneratedTextData(
            text: "Test",
            model: "gpt-4",
            tokenCount: 30,
            completionTokens: 20,
            promptTokens: 10
        )

        // THEN
        #expect(generated.tokenCount == 30)
        #expect(generated.completionTokens == 20)
        #expect(generated.promptTokens == 10)
    }

    @Test func testTokenCountsWithNilValues() {
        // WHEN
        let generated = GeneratedTextData(text: "Test", model: "gpt-4")

        // THEN
        #expect(generated.tokenCount == nil)
        #expect(generated.completionTokens == nil)
        #expect(generated.promptTokens == nil)
    }

    // MARK: - SerializableTypedData Conformance Tests

    @Test func testPreferredFormat() {
        // GIVEN
        let generated = GeneratedTextData(text: "Test", model: "gpt-4")

        // THEN
        #expect(generated.preferredFormat == .json)
    }

    // MARK: - Codable Tests

    @Test func testGeneratedTextDataCodable() throws {
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

        #expect(decoded.text == original.text)
        #expect(decoded.model == original.model)
        #expect(decoded.tokenCount == original.tokenCount)
        #expect(decoded.completionTokens == original.completionTokens)
        #expect(decoded.promptTokens == original.promptTokens)
    }

    @Test func testGeneratedTextDataCodableWithNilValues() throws {
        // GIVEN
        let original = GeneratedTextData(text: "Test", model: "gpt-3.5-turbo")

        // WHEN
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GeneratedTextData.self, from: data)

        // THEN
        #expect(decoded.text == original.text)
        #expect(decoded.model == original.model)
        #expect(decoded.tokenCount == nil)
        #expect(decoded.completionTokens == nil)
        #expect(decoded.promptTokens == nil)
    }

    // MARK: - TextGenerationConfig Tests

    @Test func testTextGenerationConfigInitialization() {
        // WHEN
        let config = TextGenerationConfig(
            temperature: 0.8,
            maxTokens: 1000,
            topP: 0.9,
            frequencyPenalty: 0.5,
            presencePenalty: 0.3
        )

        // THEN
        #expect(config.temperature == 0.8)
        #expect(config.maxTokens == 1000)
        #expect(config.topP == 0.9)
        #expect(config.frequencyPenalty == 0.5)
        #expect(config.presencePenalty == 0.3)
    }

    @Test func testTextGenerationConfigDefaults() {
        // WHEN
        let config = TextGenerationConfig()

        // THEN
        #expect(config.temperature == 0.7)
        #expect(config.maxTokens == 2048)
        #expect(config.topP == 1.0)
        #expect(config.frequencyPenalty == 0.0)
        #expect(config.presencePenalty == 0.0)
    }

    @Test func testTextGenerationConfigDefault() {
        // WHEN
        let config = TextGenerationConfig.default

        // THEN
        #expect(config.temperature == 0.7)
        #expect(config.maxTokens == 2048)
    }

    @Test func testTextGenerationConfigConservative() {
        // WHEN
        let config = TextGenerationConfig.conservative

        // THEN
        #expect(config.temperature == 0.3, "Conservative should have low temperature")
        #expect(config.maxTokens == 1024, "Conservative should have lower max tokens")
        #expect(config.topP == 0.9)
    }

    @Test func testTextGenerationConfigCreative() {
        // WHEN
        let config = TextGenerationConfig.creative

        // THEN
        #expect(config.temperature == 1.2, "Creative should have high temperature")
        #expect(config.maxTokens == 4096, "Creative should have higher max tokens")
        #expect(config.topP == 0.95)
        #expect(config.presencePenalty == 0.6, "Creative should encourage diversity")
    }

    @Test func testTextGenerationConfigCodable() throws {
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
        #expect(decoded.temperature == original.temperature)
        #expect(decoded.maxTokens == original.maxTokens)
        #expect(decoded.topP == original.topP)
        #expect(decoded.frequencyPenalty == original.frequencyPenalty)
        #expect(decoded.presencePenalty == original.presencePenalty)
    }

    // MARK: - Edge Cases

    @Test func testGeneratedTextDataWithLongText() {
        // GIVEN
        let longText = String(repeating: "Hello world. ", count: 1000)
        let generated = GeneratedTextData(text: longText, model: "gpt-4")

        // THEN
        #expect(generated.text == longText)
        #expect(generated.wordCount > 1000)
        #expect(generated.characterCount > 10000)
    }

    @Test func testGeneratedTextDataWithUnicodeCharacters() {
        // GIVEN
        let text = "Hello 世界 🌍 Привет"
        let generated = GeneratedTextData(text: text, model: "gpt-4")

        // WHEN
        let charCount = generated.characterCount
        let wordCount = generated.wordCount

        // THEN
        #expect(charCount == text.count)
        #expect(wordCount == 4, "Should count Unicode words correctly")
    }

    @Test func testTextGenerationConfigBoundaryValues() {
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

        #expect(configMin.temperature == 0.0)
        #expect(configMin.maxTokens == 1)
        #expect(configMax.temperature == 2.0)
        #expect(configMax.maxTokens == 8000)
    }
}
