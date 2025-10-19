//
//  GeneratedTextData.swift
//  SwiftHablare
//
//  Phase 6B: Typed text data structures
//

import Foundation

/// Typed data structure for generated text content.
///
/// This is the in-memory representation of generated text that includes
/// metadata about the generation. It can be serialized to JSON for storage
/// or passed directly to SwiftData models.
///
/// ## Example
/// ```swift
/// let textData = GeneratedTextData(
///     text: "Hello, world!",
///     model: "gpt-4",
///     languageCode: "en"
/// )
/// print("Word count: \(textData.wordCount)")
/// ```
public struct GeneratedTextData: Codable, Sendable, SerializableTypedData {

    // MARK: - Properties

    /// The generated text content
    public let text: String

    /// Number of words in the text
    public let wordCount: Int

    /// Number of characters in the text
    public let characterCount: Int

    /// Language code (e.g., "en", "es", "fr")
    public let languageCode: String?

    /// Model identifier that generated this text
    public let model: String

    /// Token count (if provided by the API)
    public let tokenCount: Int?

    /// Completion tokens used
    public let completionTokens: Int?

    /// Prompt tokens used
    public let promptTokens: Int?

    // MARK: - Initialization

    /// Creates generated text data with automatic word/character counting
    ///
    /// - Parameters:
    ///   - text: The generated text
    ///   - model: Model identifier
    ///   - languageCode: Language code (optional)
    ///   - tokenCount: Total token count (optional)
    ///   - completionTokens: Completion token count (optional)
    ///   - promptTokens: Prompt token count (optional)
    public init(
        text: String,
        model: String,
        languageCode: String? = nil,
        tokenCount: Int? = nil,
        completionTokens: Int? = nil,
        promptTokens: Int? = nil
    ) {
        self.text = text
        self.model = model
        self.languageCode = languageCode
        self.tokenCount = tokenCount
        self.completionTokens = completionTokens
        self.promptTokens = promptTokens

        // Calculate counts
        self.wordCount = text.split(whereSeparator: \.isWhitespace).count
        self.characterCount = text.count
    }

    // MARK: - SerializableTypedData Conformance

    /// Prefers JSON format for human-readable storage
    public var preferredFormat: SerializationFormat {
        .json
    }
}

/// Configuration for text generation requests.
///
/// Contains parameters that control how text is generated,
/// such as temperature, token limits, and sampling parameters.
public struct TextGenerationConfig: Codable, Sendable {

    /// Sampling temperature (0.0 = deterministic, 2.0 = very random)
    public var temperature: Double

    /// Maximum number of tokens to generate
    public var maxTokens: Int

    /// Nucleus sampling parameter (top-p)
    public var topP: Double

    /// Frequency penalty (-2.0 to 2.0)
    public var frequencyPenalty: Double

    /// Presence penalty (-2.0 to 2.0)
    public var presencePenalty: Double

    /// System prompt (optional)
    public var systemPrompt: String?

    /// Stop sequences (optional)
    public var stopSequences: [String]?

    /// Creates a text generation configuration
    ///
    /// - Parameters:
    ///   - temperature: Sampling temperature (default: 0.7)
    ///   - maxTokens: Maximum tokens (default: 2048)
    ///   - topP: Top-p sampling (default: 1.0)
    ///   - frequencyPenalty: Frequency penalty (default: 0.0)
    ///   - presencePenalty: Presence penalty (default: 0.0)
    ///   - systemPrompt: Optional system prompt
    ///   - stopSequences: Optional stop sequences
    public init(
        temperature: Double = 0.7,
        maxTokens: Int = 2048,
        topP: Double = 1.0,
        frequencyPenalty: Double = 0.0,
        presencePenalty: Double = 0.0,
        systemPrompt: String? = nil,
        stopSequences: [String]? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.systemPrompt = systemPrompt
        self.stopSequences = stopSequences
    }

    /// Default configuration for general text generation
    public static let `default` = TextGenerationConfig()

    /// Conservative configuration (lower temperature, deterministic)
    public static let conservative = TextGenerationConfig(
        temperature: 0.3,
        maxTokens: 1024,
        topP: 0.9
    )

    /// Creative configuration (higher temperature, more random)
    public static let creative = TextGenerationConfig(
        temperature: 1.2,
        maxTokens: 4096,
        topP: 0.95,
        presencePenalty: 0.6
    )
}
