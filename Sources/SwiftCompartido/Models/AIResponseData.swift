import Foundation

/// Immutable, Sendable container for API responses that safely crosses actor boundaries.
///
/// `AIResponseData` wraps the result of an AI service provider request, including either
/// the successfully generated content or an error describing the failure. This type is
/// designed to be passed between actors without data races.
///
/// ## Example
/// ```swift
/// let responseData = AIResponseData(
///     requestID: request.id,
///     providerID: "openai",
///     result: .success(.text("Generated content")),
///     metadata: ["model": "gpt-4"]
/// )
/// ```
public struct AIResponseData: Sendable, Identifiable {

    /// Unique identifier correlating this response to the original request.
    public let requestID: UUID

    /// ID of the provider that generated this response.
    public let providerID: String

    /// The result of the generation: either content or an error.
    public let result: Result<ResponseContent, AIServiceError>

    /// Additional metadata from the provider (model name, usage stats, etc.).
    public let metadata: [String: String]

    /// Timestamp when the response was received.
    public let receivedAt: Date

    /// Usage statistics if available.
    public let usage: UsageStats?

    /// Convenience identifier matching requestID for Identifiable conformance.
    public var id: UUID { requestID }

    /// Creates a new response data instance.
    ///
    /// - Parameters:
    ///   - requestID: UUID of the original request
    ///   - providerID: ID of the provider that generated the response
    ///   - result: Result containing either content or error
    ///   - metadata: Additional provider metadata (default: empty)
    ///   - receivedAt: Timestamp (default: now)
    ///   - usage: Usage statistics (default: nil)
    public init(
        requestID: UUID,
        providerID: String,
        result: Result<ResponseContent, AIServiceError>,
        metadata: [String: String] = [:],
        receivedAt: Date = Date(),
        usage: UsageStats? = nil
    ) {
        self.requestID = requestID
        self.providerID = providerID
        self.result = result
        self.metadata = metadata
        self.receivedAt = receivedAt
        self.usage = usage
    }

    /// Convenience initializer for successful responses.
    ///
    /// - Parameters:
    ///   - requestID: UUID of the original request
    ///   - providerID: ID of the provider
    ///   - content: The generated content
    ///   - metadata: Additional metadata (default: empty)
    ///   - usage: Usage statistics (default: nil)
    public init(
        requestID: UUID,
        providerID: String,
        content: ResponseContent,
        metadata: [String: String] = [:],
        usage: UsageStats? = nil
    ) {
        self.init(
            requestID: requestID,
            providerID: providerID,
            result: .success(content),
            metadata: metadata,
            receivedAt: Date(),
            usage: usage
        )
    }

    /// Convenience initializer for failed responses.
    ///
    /// - Parameters:
    ///   - requestID: UUID of the original request
    ///   - providerID: ID of the provider
    ///   - error: The error that occurred
    ///   - metadata: Additional metadata (default: empty)
    public init(
        requestID: UUID,
        providerID: String,
        error: AIServiceError,
        metadata: [String: String] = [:]
    ) {
        self.init(
            requestID: requestID,
            providerID: providerID,
            result: .failure(error),
            metadata: metadata,
            receivedAt: Date(),
            usage: nil
        )
    }

    // MARK: - Convenience Properties

    /// Whether the request was successful.
    public var isSuccess: Bool {
        if case .success = result {
            return true
        }
        return false
    }

    /// Whether the request failed.
    public var isFailure: Bool {
        !isSuccess
    }

    /// The content if successful, nil otherwise.
    public var content: ResponseContent? {
        try? result.get()
    }

    /// The error if failed, nil otherwise.
    public var error: AIServiceError? {
        if case .failure(let error) = result {
            return error
        }
        return nil
    }
}

// MARK: - Response Content

/// The content returned by an AI service provider.
///
/// `ResponseContent` represents the different types of data that providers can generate,
/// all in a Sendable, immutable form suitable for crossing actor boundaries.
public enum ResponseContent: Sendable {

    /// Plain text content.
    case text(String)

    /// Binary data (generic format).
    case data(Data)

    /// Audio data with format information.
    case audio(Data, format: AudioFormat)

    /// Image data with format information.
    case image(Data, format: ImageFormat)

    /// Structured data (JSON-compatible dictionary).
    /// Values must be Sendable types: String, Int, Double, Bool, [String: Any], [Any]
    case structured([String: SendableValue])

    /// The type of content this enum case represents.
    public var contentType: ContentType {
        switch self {
        case .text: return .text
        case .data: return .data
        case .audio: return .audio
        case .image: return .image
        case .structured: return .structured
        }
    }

    /// Extracts text content if this is a text response.
    public var text: String? {
        if case .text(let string) = self {
            return string
        }
        return nil
    }

    /// Extracts data content regardless of the specific type.
    public var dataContent: Data? {
        switch self {
        case .text(let string):
            return string.data(using: .utf8)
        case .data(let data):
            return data
        case .audio(let data, _):
            return data
        case .image(let data, _):
            return data
        case .structured(let dict):
            return try? JSONEncoder().encode(SendableValueWrapper(dict))
        }
    }

    /// Extracts audio data and format if this is an audio response.
    public var audioContent: (data: Data, format: AudioFormat)? {
        if case .audio(let data, let format) = self {
            return (data, format)
        }
        return nil
    }

    /// Extracts image data and format if this is an image response.
    public var imageContent: (data: Data, format: ImageFormat)? {
        if case .image(let data, let format) = self {
            return (data, format)
        }
        return nil
    }

    /// Extracts structured data if this is a structured response.
    public var structuredContent: [String: SendableValue]? {
        if case .structured(let dict) = self {
            return dict
        }
        return nil
    }
}

// MARK: - Content Type

extension ResponseContent {

    /// The type of content that can be generated.
    public enum ContentType: String, Sendable, CaseIterable {
        case text
        case data
        case audio
        case image
        case structured
    }
}

// MARK: - Audio Format

/// Supported audio formats for audio responses.
public enum AudioFormat: String, Sendable {
    case mp3
    case wav
    case aac
    case flac
    case ogg
    case opus
    case pcm
    case unknown
}

// MARK: - Image Format

/// Supported image formats for image responses.
public enum ImageFormat: String, Sendable {
    case jpeg
    case png
    case gif
    case webp
    case heic
    case tiff
    case bmp
    case unknown
}

// MARK: - Sendable Value

/// A type-erased Sendable value for structured data.
///
/// This enables storing heterogeneous Sendable values in dictionaries and arrays
/// while maintaining Sendable safety across actor boundaries.
public enum SendableValue: Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([SendableValue])
    case dictionary([String: SendableValue])

    /// Attempts to extract a String value.
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// Attempts to extract an Int value.
    public var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    /// Attempts to extract a Double value.
    public var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }

    /// Attempts to extract a Bool value.
    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    /// Attempts to extract an Array value.
    public var arrayValue: [SendableValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    /// Attempts to extract a Dictionary value.
    public var dictionaryValue: [String: SendableValue]? {
        if case .dictionary(let value) = self { return value }
        return nil
    }

    /// Whether this value is null.
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}

// MARK: - Usage Stats

/// Usage statistics for a request.
///
/// This type consolidates token counts, costs, and timing information across
/// all AI service requests. It's used by both `AIResponseData` and `AIResponse`.
public struct UsageStats: Sendable, Equatable {

    /// Number of tokens in the prompt (if applicable).
    public let promptTokens: Int?

    /// Number of tokens in the completion (if applicable).
    public let completionTokens: Int?

    /// Total number of tokens used.
    public let totalTokens: Int?

    /// Cost of the request in USD (if available).
    public let costUSD: Decimal?

    /// Duration of the request in seconds.
    public let durationSeconds: TimeInterval?

    /// Creates usage statistics.
    ///
    /// - Parameters:
    ///   - promptTokens: Prompt token count
    ///   - completionTokens: Completion token count
    ///   - totalTokens: Total token count
    ///   - costUSD: Request cost in USD
    ///   - durationSeconds: Request duration
    public init(
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        totalTokens: Int? = nil,
        costUSD: Decimal? = nil,
        durationSeconds: TimeInterval? = nil
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.costUSD = costUSD
        self.durationSeconds = durationSeconds
    }

    // MARK: - Legacy Compatibility

    /// Legacy property name for cost (same as costUSD).
    ///
    /// Provided for backward compatibility.
    public var cost: Decimal? { costUSD }
}

// MARK: - Codable Support

// Helper for encoding SendableValue dictionaries
struct SendableValueWrapper: Codable {
    let value: [String: SendableValue]

    init(_ value: [String: SendableValue]) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let dict = try convertToEncodable(value)
        try container.encode(dict)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnyCodable].self)
        self.value = Self.convertToSendableValue(dict)
    }

    private func convertToEncodable(_ dict: [String: SendableValue]) throws -> [String: AnyCodable] {
        var result: [String: AnyCodable] = [:]
        for (key, value) in dict {
            result[key] = try convertValueToEncodable(value)
        }
        return result
    }

    private func convertValueToEncodable(_ value: SendableValue) throws -> AnyCodable {
        switch value {
        case .string(let s): return AnyCodable(s)
        case .int(let i): return AnyCodable(i)
        case .double(let d): return AnyCodable(d)
        case .bool(let b): return AnyCodable(b)
        case .null: return AnyCodable(NSNull())
        case .array(let arr):
            // Convert array elements to [Any] for proper JSON encoding
            let anyArray: [Any] = try arr.map { value in
                try convertValueToEncodable(value).value
            }
            return AnyCodable(anyArray)
        case .dictionary(let dict):
            // Convert dictionary values to [String: Any] for proper JSON encoding
            let anyDict: [String: Any] = try convertToEncodable(dict).mapValues { $0.value }
            return AnyCodable(anyDict)
        }
    }

    private static func convertToSendableValue(_ dict: [String: AnyCodable]) -> [String: SendableValue] {
        var result: [String: SendableValue] = [:]
        for (key, value) in dict {
            result[key] = convertAnyCodableToSendable(value)
        }
        return result
    }

    private static func convertAnyCodableToSendable(_ value: AnyCodable) -> SendableValue {
        if let string = value.value as? String {
            return .string(string)
        } else if let int = value.value as? Int {
            return .int(int)
        } else if let double = value.value as? Double {
            return .double(double)
        } else if let bool = value.value as? Bool {
            return .bool(bool)
        } else if let array = value.value as? [Any] {
            return .array(array.map { convertAnyCodableToSendable(AnyCodable($0)) })
        } else if let dict = value.value as? [String: Any] {
            return .dictionary(convertToSendableValue(dict.mapValues { AnyCodable($0) }))
        } else {
            return .null
        }
    }
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if value is NSNull {
            try container.encodeNil()
        } else if let array = value as? [Any] {
            // Encode array recursively
            try container.encode(array.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            // Encode dictionary recursively
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else {
            try container.encodeNil()
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            // Decode array recursively
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            // Decode dictionary recursively
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
}
