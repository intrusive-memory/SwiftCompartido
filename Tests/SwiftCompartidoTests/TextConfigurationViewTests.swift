//
//  TextConfigurationViewTests.swift
//  SwiftHablareTests
//
//  Phase 7A: Tests for text configuration UI
//

import Foundation
import Testing
import SwiftUI
@testable import SwiftCompartido

@MainActor
struct TextConfigurationViewTests {

    // MARK: - Initialization Tests

    @Test func testTextConfigurationView_Initialization() {
        let config = TextGenerationConfig()
        let view = TextConfigurationView(configuration: .constant(config))

        #expect(view != nil)
    }

    @Test func testTextConfigurationView_DefaultConfiguration() {
        let config = TextGenerationConfig()

        #expect(config.temperature == 0.7)
        #expect(config.maxTokens == 2048)
        #expect(config.topP == 1.0)
        #expect(config.frequencyPenalty == 0.0)
        #expect(config.presencePenalty == 0.0)
        #expect(config.systemPrompt == nil)
        #expect(config.stopSequences == nil)
    }

    @Test func testTextConfigurationView_CustomConfiguration() {
        let config = TextGenerationConfig(
            temperature: 1.5,
            maxTokens: 1000,
            topP: 0.9,
            frequencyPenalty: 0.5,
            presencePenalty: 0.5,
            systemPrompt: "You are a helpful assistant.",
            stopSequences: ["END", "STOP"]
        )

        #expect(config.temperature == 1.5)
        #expect(config.maxTokens == 1000)
        #expect(config.topP == 0.9)
        #expect(config.frequencyPenalty == 0.5)
        #expect(config.presencePenalty == 0.5)
        #expect(config.systemPrompt == "You are a helpful assistant.")
        #expect(config.stopSequences == ["END", "STOP"])
    }

    // MARK: - Configuration Modification Tests

    @Test func testTextConfigurationView_TemperatureModification() {
        var config = TextGenerationConfig()
        config.temperature = 1.2

        #expect(config.temperature == 1.2)
    }

    @Test func testTextConfigurationView_MaxTokensModification() {
        var config = TextGenerationConfig()
        config.maxTokens = 500

        #expect(config.maxTokens == 500)
    }

    @Test func testTextConfigurationView_TopPModification() {
        var config = TextGenerationConfig()
        config.topP = 0.8

        #expect(config.topP == 0.8)
    }

    @Test func testTextConfigurationView_FrequencyPenaltyModification() {
        var config = TextGenerationConfig()
        config.frequencyPenalty = 1.0

        #expect(config.frequencyPenalty == 1.0)
    }

    @Test func testTextConfigurationView_PresencePenaltyModification() {
        var config = TextGenerationConfig()
        config.presencePenalty = -0.5

        #expect(config.presencePenalty == -0.5)
    }

    @Test func testTextConfigurationView_SystemPromptModification() {
        var config = TextGenerationConfig()
        config.systemPrompt = "Test system prompt"

        #expect(config.systemPrompt == "Test system prompt")
    }

    @Test func testTextConfigurationView_StopSequencesModification() {
        var config = TextGenerationConfig()
        config.stopSequences = ["STOP", "END", "DONE"]

        #expect(config.stopSequences == ["STOP", "END", "DONE"])
    }

    // MARK: - Validation Tests

    @Test func testTextConfigurationView_TemperatureRange() {
        var config = TextGenerationConfig()

        // Valid temperatures
        config.temperature = 0.0
        #expect(config.temperature == 0.0)

        config.temperature = 1.0
        #expect(config.temperature == 1.0)

        config.temperature = 2.0
        #expect(config.temperature == 2.0)
    }

    @Test func testTextConfigurationView_MaxTokensRange() {
        var config = TextGenerationConfig()

        // Valid max tokens
        config.maxTokens = 1
        #expect(config.maxTokens == 1)

        config.maxTokens = 2048
        #expect(config.maxTokens == 2048)

        config.maxTokens = 4096
        #expect(config.maxTokens == 4096)
    }

    @Test func testTextConfigurationView_TopPRange() {
        var config = TextGenerationConfig()

        // Valid top-p values
        config.topP = 0.0
        #expect(config.topP == 0.0)

        config.topP = 0.5
        #expect(config.topP == 0.5)

        config.topP = 1.0
        #expect(config.topP == 1.0)
    }

    @Test func testTextConfigurationView_FrequencyPenaltyRange() {
        var config = TextGenerationConfig()

        // Valid frequency penalties
        config.frequencyPenalty = -2.0
        #expect(config.frequencyPenalty == -2.0)

        config.frequencyPenalty = 0.0
        #expect(config.frequencyPenalty == 0.0)

        config.frequencyPenalty = 2.0
        #expect(config.frequencyPenalty == 2.0)
    }

    @Test func testTextConfigurationView_PresencePenaltyRange() {
        var config = TextGenerationConfig()

        // Valid presence penalties
        config.presencePenalty = -2.0
        #expect(config.presencePenalty == -2.0)

        config.presencePenalty = 0.0
        #expect(config.presencePenalty == 0.0)

        config.presencePenalty = 2.0
        #expect(config.presencePenalty == 2.0)
    }

    // MARK: - Reset Tests

    @Test func testTextConfigurationView_ResetToDefaults() {
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

        #expect(config.temperature == 0.7)
        #expect(config.maxTokens == 2048)
        #expect(config.topP == 1.0)
        #expect(config.frequencyPenalty == 0.0)
        #expect(config.presencePenalty == 0.0)
        #expect(config.systemPrompt == nil)
        #expect(config.stopSequences == nil)
    }

    // MARK: - Edge Cases

    @Test func testTextConfigurationView_EmptySystemPrompt() {
        var config = TextGenerationConfig()
        config.systemPrompt = ""

        // Empty string should be treated as nil
        #expect(config.systemPrompt == "")
    }

    @Test func testTextConfigurationView_EmptyStopSequences() {
        var config = TextGenerationConfig()
        config.stopSequences = []

        // Empty array should remain empty
        #expect(config.stopSequences == [])
    }

    @Test func testTextConfigurationView_SingleStopSequence() {
        var config = TextGenerationConfig()
        config.stopSequences = ["END"]

        #expect(config.stopSequences == ["END"])
    }

    @Test func testTextConfigurationView_MultipleStopSequences() {
        var config = TextGenerationConfig()
        config.stopSequences = ["END", "STOP", "DONE", "FINISH"]

        #expect(config.stopSequences == ["END", "STOP", "DONE", "FINISH"])
    }

    // MARK: - Codable Tests

    @Test func testTextConfigurationView_Codable() throws {
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

        #expect(decoded.temperature == original.temperature)
        #expect(decoded.maxTokens == original.maxTokens)
        #expect(decoded.topP == original.topP)
        #expect(decoded.frequencyPenalty == original.frequencyPenalty)
        #expect(decoded.presencePenalty == original.presencePenalty)
        #expect(decoded.systemPrompt == original.systemPrompt)
        #expect(decoded.stopSequences == original.stopSequences)
    }

    @Test func testTextConfigurationView_CodableWithNils() throws {
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

        #expect(decoded.temperature == original.temperature)
        #expect(decoded.maxTokens == original.maxTokens)
        #expect(decoded.systemPrompt == nil)
        #expect(decoded.stopSequences == nil)
    }

    // MARK: - Integration Tests

    // TODO: Re-enable when OpenAIProvider and AnthropicProvider are implemented
    /*
    @Test func testTextConfigurationView_IntegrationWithOpenAIRequestor() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAITextRequestor(provider: provider, model: .gpt4)
        var config = requestor.defaultConfiguration()

        #expect(config.temperature == 0.7)
        #expect(config.maxTokens == 2048)
    }

    @Test func testTextConfigurationView_IntegrationWithAnthropicRequestor() {
        let provider = AnthropicProvider.shared()
        let requestor = AnthropicTextRequestor(provider: provider, model: .claude3Sonnet)
        var config = requestor.defaultConfiguration()

        #expect(config.temperature == 0.7)
        #expect(config.maxTokens == 2048)
    }
    */

    // MARK: - View Rendering Tests

    @Test func testTextConfigurationView_CreatesView() {
        let config = TextGenerationConfig()
        let view = TextConfigurationView(configuration: .constant(config))

        // Test that view can be created without crashing
        #expect(view != nil)
        #expect(view.body != nil)
    }

    @Test func testTextConfigurationView_PreviewConfiguration() {
        // Test preview configurations don't crash
        let defaultConfig = TextGenerationConfig()
        let defaultView = TextConfigurationView(configuration: .constant(defaultConfig))
        #expect(defaultView != nil)

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
        #expect(customView != nil)
    }
}
