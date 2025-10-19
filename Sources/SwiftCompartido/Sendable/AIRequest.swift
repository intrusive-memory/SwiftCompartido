import Foundation

/// Configuration for an AI service request.
///
/// `AIRequest` encapsulates all the information needed to make a request to an AI service provider,
/// including the prompt, parameters, and request-specific configuration.
///
/// ## Example
/// ```swift
/// let request = AIRequest(
///     prompt: "Generate a product description",
///     parameters: [
///         "temperature": "0.7",
///         "max_tokens": "150"
///     ]
/// )
/// ```
public struct AIRequest: Sendable, Hashable {

    /// The prompt text to send to the AI service.
    public let prompt: String

    /// Provider-specific parameters for the request.
    ///
    /// Common parameters include:
    /// - `temperature`: Controls randomness (0.0-1.0)
    /// - `max_tokens`: Maximum response length
    /// - `model`: Specific model to use
    /// - `voice`: Voice selection for TTS
    public let parameters: [String: String]

    /// Unique identifier for this request.
    public let id: UUID

    /// Timestamp when the request was created.
    public let createdAt: Date

    /// Optional timeout for this request in seconds.
    ///
    /// If not specified, the provider's default timeout will be used.
    public let timeout: TimeInterval?

    /// Whether to use cached responses for this request.
    ///
    /// Defaults to `true`. Set to `false` to bypass cache.
    public let useCache: Bool

    /// Optional metadata associated with this request.
    ///
    /// This can be used to track request context or associate
    /// requests with application-specific data.
    public let metadata: [String: String]

    /// Creates a new AI request.
    ///
    /// - Parameters:
    ///   - prompt: The prompt text to send to the AI service
    ///   - parameters: Provider-specific parameters (default: empty)
    ///   - timeout: Optional timeout in seconds
    ///   - useCache: Whether to use cached responses (default: true)
    ///   - metadata: Optional metadata for tracking (default: empty)
    public init(
        prompt: String,
        parameters: [String: String] = [:],
        timeout: TimeInterval? = nil,
        useCache: Bool = true,
        metadata: [String: String] = [:]
    ) {
        self.prompt = prompt
        self.parameters = parameters
        self.id = UUID()
        self.createdAt = Date()
        self.timeout = timeout
        self.useCache = useCache
        self.metadata = metadata
    }

    /// Creates a copy of this request with updated parameters.
    ///
    /// - Parameter parameters: New parameters to merge with existing ones
    /// - Returns: A new request with merged parameters
    public func withParameters(_ parameters: [String: String]) -> AIRequest {
        var merged = self.parameters
        merged.merge(parameters) { _, new in new }

        return AIRequest(
            prompt: self.prompt,
            parameters: merged,
            timeout: self.timeout,
            useCache: self.useCache,
            metadata: self.metadata
        )
    }

    /// Creates a copy of this request with updated timeout.
    ///
    /// - Parameter timeout: New timeout value in seconds
    /// - Returns: A new request with the updated timeout
    public func withTimeout(_ timeout: TimeInterval) -> AIRequest {
        return AIRequest(
            prompt: self.prompt,
            parameters: self.parameters,
            timeout: timeout,
            useCache: self.useCache,
            metadata: self.metadata
        )
    }

    /// Creates a copy of this request with updated cache setting.
    ///
    /// - Parameter useCache: Whether to use cache
    /// - Returns: A new request with the updated cache setting
    public func withCache(_ useCache: Bool) -> AIRequest {
        return AIRequest(
            prompt: self.prompt,
            parameters: self.parameters,
            timeout: self.timeout,
            useCache: useCache,
            metadata: self.metadata
        )
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: AIRequest, rhs: AIRequest) -> Bool {
        return lhs.id == rhs.id
    }
}
