//
//  TextConfigurationViewTests.swift
//  SwiftHablareTests
//
//  Phase 7A: Tests for text configuration UI
//

import XCTest
import SwiftUI
@testable import SwiftCompartido

@available(macOS 15.0, iOS 17.0, *)
final class TextConfigurationViewTests: XCTestCase {

    // MARK: - Initialization Tests

    func testTextConfigurationView_Initialization() {
        let config = TextGenerationConfig()
        let view = TextConfigurationView(configuration: .constant(config))

        XCTAssertNotNil(view)
    }

    func testTextConfigurationView_DefaultConfiguration() {
        let config = TextGenerationConfig()

        XCTAssertEqual(config.temperature, 0.7)
        XCTAssertEqual(config.maxTokens, 2048)
        XCTAssertEqual(config.topP, 1.0)
        XCTAssertEqual(config.frequencyPenalty, 0.0)
        XCTAssertEqual(config.presencePenalty, 0.0)
        XCTAssertNil(config.systemPrompt)
        XCTAssertNil(config.stopSequences)
    }

    func testTextConfigurationView_CustomConfiguration() {
        let config = TextGenerationConfig(
            temperature: 1.5,
            maxTokens: 1000,
            topP: 0.9,
            frequencyPenalty: 0.5,
            presencePenalty: 0.5,
            systemPrompt: "You are a helpful assistant.",
            stopSequences: ["END", "STOP"]
        )

        XCTAssertEqual(config.temperature, 1.5)
        XCTAssertEqual(config.maxTokens, 1000)
        XCTAssertEqual(config.topP, 0.9)
        XCTAssertEqual(config.frequencyPenalty, 0.5)
        XCTAssertEqual(config.presencePenalty, 0.5)
        XCTAssertEqual(config.systemPrompt, "You are a helpful assistant.")
        XCTAssertEqual(config.stopSequences, ["END", "STOP"])
    }

    // MARK: - Configuration Modification Tests

    func testTextConfigurationView_TemperatureModification() {
        var config = TextGenerationConfig()
        config.temperature = 1.2

        XCTAssertEqual(config.temperature, 1.2)
    }

    func testTextConfigurationView_MaxTokensModification() {
        var config = TextGenerationConfig()
        config.maxTokens = 500

        XCTAssertEqual(config.maxTokens, 500)
    }

    func testTextConfigurationView_TopPModification() {
        var config = TextGenerationConfig()
        config.topP = 0.8

        XCTAssertEqual(config.topP, 0.8)
    }

    func testTextConfigurationView_FrequencyPenaltyModification() {
        var config = TextGenerationConfig()
        config.frequencyPenalty = 1.0

        XCTAssertEqual(config.frequencyPenalty, 1.0)
    }

    func testTextConfigurationView_PresencePenaltyModification() {
        var config = TextGenerationConfig()
        config.presencePenalty = -0.5

        XCTAssertEqual(config.presencePenalty, -0.5)
    }

    func testTextConfigurationView_SystemPromptModification() {
        var config = TextGenerationConfig()
        config.systemPrompt = "Test system prompt"

        XCTAssertEqual(config.systemPrompt, "Test system prompt")
    }

    func testTextConfigurationView_StopSequencesModification() {
        var config = TextGenerationConfig()
        config.stopSequences = ["STOP", "END", "DONE"]

        XCTAssertEqual(config.stopSequences, ["STOP", "END", "DONE"])
    }

    // MARK: - Validation Tests

    func testTextConfigurationView_TemperatureRange() {
        var config = TextGenerationConfig()

        // Valid temperatures
        config.temperature = 0.0
        XCTAssertEqual(config.temperature, 0.0)

        config.temperature = 1.0
        XCTAssertEqual(config.temperature, 1.0)

        config.temperature = 2.0
        XCTAssertEqual(config.temperature, 2.0)
    }

    func testTextConfigurationView_MaxTokensRange() {
        var config = TextGenerationConfig()

        // Valid max tokens
        config.maxTokens = 1
        XCTAssertEqual(config.maxTokens, 1)

        config.maxTokens = 2048
        XCTAssertEqual(config.maxTokens, 2048)

        config.maxTokens = 4096
        XCTAssertEqual(config.maxTokens, 4096)
    }

    func testTextConfigurationView_TopPRange() {
        var config = TextGenerationConfig()

        // Valid top-p values
        config.topP = 0.0
        XCTAssertEqual(config.topP, 0.0)

        config.topP = 0.5
        XCTAssertEqual(config.topP, 0.5)

        config.topP = 1.0
        XCTAssertEqual(config.topP, 1.0)
    }

    func testTextConfigurationView_FrequencyPenaltyRange() {
        var config = TextGenerationConfig()

        // Valid frequency penalties
        config.frequencyPenalty = -2.0
        XCTAssertEqual(config.frequencyPenalty, -2.0)

        config.frequencyPenalty = 0.0
        XCTAssertEqual(config.frequencyPenalty, 0.0)

        config.frequencyPenalty = 2.0
        XCTAssertEqual(config.frequencyPenalty, 2.0)
    }

    func testTextConfigurationView_PresencePenaltyRange() {
        var config = TextGenerationConfig()

        // Valid presence penalties
        config.presencePenalty = -2.0
        XCTAssertEqual(config.presencePenalty, -2.0)

        config.presencePenalty = 0.0
        XCTAssertEqual(config.presencePenalty, 0.0)

        config.presencePenalty = 2.0
        XCTAssertEqual(config.presencePenalty, 2.0)
    }

    // MARK: - Reset Tests

    func testTextConfigurationView_ResetToDefaults() {
        var config = TextGenerationConfig(
            temperature: 1.5,
            maxTokens: 1000,
            topP: 0.9,
            frequencyPenalty: 0.5,
            presencePenalty: 0.5,
            systemPrompt: "Test",
            stopSequences: ["END"]
        )

        // Reset to defaults
        config = TextGenerationConfig()

        XCTAssertEqual(config.temperature, 0.7)
        XCTAssertEqual(config.maxTokens, 2048)
        XCTAssertEqual(config.topP, 1.0)
        XCTAssertEqual(config.frequencyPenalty, 0.0)
        XCTAssertEqual(config.presencePenalty, 0.0)
        XCTAssertNil(config.systemPrompt)
        XCTAssertNil(config.stopSequences)
    }

    // MARK: - Edge Cases

    func testTextConfigurationView_EmptySystemPrompt() {
        var config = TextGenerationConfig()
        config.systemPrompt = ""

        // Empty string should be treated as nil
        XCTAssertEqual(config.systemPrompt, "")
    }

    func testTextConfigurationView_EmptyStopSequences() {
        var config = TextGenerationConfig()
        config.stopSequences = []

        // Empty array should remain empty
        XCTAssertEqual(config.stopSequences, [])
    }

    func testTextConfigurationView_SingleStopSequence() {
        var config = TextGenerationConfig()
        config.stopSequences = ["END"]

        XCTAssertEqual(config.stopSequences, ["END"])
    }

    func testTextConfigurationView_MultipleStopSequences() {
        var config = TextGenerationConfig()
        config.stopSequences = ["END", "STOP", "DONE", "FINISH"]

        XCTAssertEqual(config.stopSequences, ["END", "STOP", "DONE", "FINISH"])
    }

    // MARK: - Codable Tests

    func testTextConfigurationView_Codable() throws {
        let original = TextGenerationConfig(
            temperature: 1.2,
            maxTokens: 1500,
            topP: 0.95,
            frequencyPenalty: 0.3,
            presencePenalty: 0.3,
            systemPrompt: "Test system",
            stopSequences: ["END"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TextGenerationConfig.self, from: data)

        XCTAssertEqual(decoded.temperature, original.temperature)
        XCTAssertEqual(decoded.maxTokens, original.maxTokens)
        XCTAssertEqual(decoded.topP, original.topP)
        XCTAssertEqual(decoded.frequencyPenalty, original.frequencyPenalty)
        XCTAssertEqual(decoded.presencePenalty, original.presencePenalty)
        XCTAssertEqual(decoded.systemPrompt, original.systemPrompt)
        XCTAssertEqual(decoded.stopSequences, original.stopSequences)
    }

    func testTextConfigurationView_CodableWithNils() throws {
        let original = TextGenerationConfig(
            temperature: 0.8,
            maxTokens: 2000,
            topP: 1.0,
            frequencyPenalty: 0.0,
            presencePenalty: 0.0,
            systemPrompt: nil,
            stopSequences: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TextGenerationConfig.self, from: data)

        XCTAssertEqual(decoded.temperature, original.temperature)
        XCTAssertEqual(decoded.maxTokens, original.maxTokens)
        XCTAssertNil(decoded.systemPrompt)
        XCTAssertNil(decoded.stopSequences)
    }

    // MARK: - Integration Tests

    // TODO: Re-enable when OpenAIProvider and AnthropicProvider are implemented
    /*
    func testTextConfigurationView_IntegrationWithOpenAIRequestor() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAITextRequestor(provider: provider, model: .gpt4)
        var config = requestor.defaultConfiguration()

        XCTAssertEqual(config.temperature, 0.7)
        XCTAssertEqual(config.maxTokens, 2048)
    }

    func testTextConfigurationView_IntegrationWithAnthropicRequestor() {
        let provider = AnthropicProvider.shared()
        let requestor = AnthropicTextRequestor(provider: provider, model: .claude3Sonnet)
        var config = requestor.defaultConfiguration()

        XCTAssertEqual(config.temperature, 0.7)
        XCTAssertEqual(config.maxTokens, 2048)
    }
    */

    // MARK: - View Rendering Tests

    func testTextConfigurationView_CreatesView() {
        let config = TextGenerationConfig()
        let view = TextConfigurationView(configuration: .constant(config))

        // Test that view can be created without crashing
        XCTAssertNotNil(view)
        XCTAssertNotNil(view.body)
    }

    func testTextConfigurationView_PreviewConfiguration() {
        // Test preview configurations don't crash
        let defaultConfig = TextGenerationConfig()
        let defaultView = TextConfigurationView(configuration: .constant(defaultConfig))
        XCTAssertNotNil(defaultView)

        let customConfig = TextGenerationConfig(
            temperature: 1.5,
            maxTokens: 1000,
            topP: 0.9,
            frequencyPenalty: 0.5,
            presencePenalty: 0.5,
            systemPrompt: "You are a helpful assistant.",
            stopSequences: ["END", "STOP"]
        )
        let customView = TextConfigurationView(configuration: .constant(customConfig))
        XCTAssertNotNil(customView)
    }
}
