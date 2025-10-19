//
//  GeneratedEmbeddingData.swift
//  SwiftHablare
//
//  Phase 6E: Typed embedding data structures
//

import Foundation

/// Typed data structure for generated embeddings.
///
/// This is the in-memory representation of vector embeddings that can be used
/// for semantic search, similarity comparison, and clustering tasks.
///
/// ## Storage Strategy
/// - **Small embeddings** (<100KB, ~12,500 dimensions): Stored in-memory in SwiftData
/// - **Large embeddings** (≥100KB): Metadata in SwiftData, vectors in file
///
/// ## Example
/// ```swift
/// let embeddingData = GeneratedEmbeddingData(
///     embedding: vectorArray,
///     model: "text-embedding-3-small",
///     dimensions: 1536,
///     inputText: "The quick brown fox"
/// )
/// ```
public struct GeneratedEmbeddingData: Codable, Sendable, SerializableTypedData {

    // MARK: - Properties

    /// The embedding vector (may be nil if stored in file)
    ///
    /// For file-based storage, this will be nil and vector loaded from file reference.
    public let embedding: [Float]?

    /// Number of dimensions in the embedding vector
    public let dimensions: Int

    /// Model identifier that generated this embedding
    public let model: String

    /// The input text that was embedded (optional, for reference)
    ///
    /// Useful for debugging and understanding what the embedding represents.
    /// Limited to first 1000 characters for storage efficiency.
    public let inputText: String?

    /// Token count of the input (if provided by API)
    public let tokenCount: Int?

    /// Embedding index in batch (if part of batch request)
    ///
    /// When generating embeddings for multiple inputs, this indicates
    /// the position in the original batch.
    public let index: Int?

    /// File size in bytes (if embedding data present)
    public var dataSize: Int {
        guard let embedding = embedding else { return 0 }
        return embedding.count * MemoryLayout<Float>.size
    }

    // MARK: - Initialization

    /// Creates generated embedding data
    ///
    /// - Parameters:
    ///   - embedding: The embedding vector (nil if stored in file)
    ///   - dimensions: Number of dimensions
    ///   - model: Model identifier
    ///   - inputText: The input text (optional, truncated to 1000 chars)
    ///   - tokenCount: Token count (optional)
    ///   - index: Index in batch (optional)
    public init(
        embedding: [Float]?,
        dimensions: Int,
        model: String,
        inputText: String? = nil,
        tokenCount: Int? = nil,
        index: Int? = nil
    ) {
        self.embedding = embedding
        self.dimensions = dimensions
        self.model = model

        // Truncate input text for storage efficiency
        if let inputText = inputText, inputText.count > 1000 {
            self.inputText = String(inputText.prefix(1000)) + "..."
        } else {
            self.inputText = inputText
        }

        self.tokenCount = tokenCount
        self.index = index
    }

    // MARK: - SerializableTypedData Conformance

    /// Prefers binary format for efficient vector storage
    public var preferredFormat: SerializationFormat {
        .binary
    }

    /// Serialize embedding to binary format
    ///
    /// Binary format is more efficient for large float arrays:
    /// - 4 bytes per float (native representation)
    /// - No parsing overhead
    /// - Direct memory mapping possible
    public func serialize() throws -> Data {
        guard let embedding = embedding else {
            throw TypedDataError.fileOperationFailed(
                operation: "serialize",
                reason: "Embedding data is nil (likely stored in file)"
            )
        }

        var data = Data()

        // Write header: dimensions (4 bytes) + model length (4 bytes) + model string
        var dims = Int32(dimensions)
        data.append(Data(bytes: &dims, count: 4))

        let modelData = model.data(using: .utf8)!
        var modelLength = Int32(modelData.count)
        data.append(Data(bytes: &modelLength, count: 4))
        data.append(modelData)

        // Write embedding vector
        let vectorData = embedding.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        data.append(vectorData)

        // Write optional metadata
        if let inputText = inputText {
            let textData = inputText.data(using: .utf8)!
            var textLength = Int32(textData.count)
            data.append(Data(bytes: &textLength, count: 4))
            data.append(textData)
        } else {
            var zero = Int32(0)
            data.append(Data(bytes: &zero, count: 4))
        }

        if let tokenCount = tokenCount {
            var tokens = Int32(tokenCount)
            data.append(Data(bytes: &tokens, count: 4))
        } else {
            var negativeOne = Int32(-1)
            data.append(Data(bytes: &negativeOne, count: 4))
        }

        return data
    }

    /// Deserialize from binary format
    public static func deserialize(from data: Data, format: SerializationFormat) throws -> Self {
        guard format == .binary else {
            // Fallback to JSON for non-binary formats
            let decoder = JSONDecoder()
            return try decoder.decode(Self.self, from: data)
        }

        var offset = 0

        // Read dimensions
        guard data.count >= offset + 4 else {
            throw TypedDataError.deserializationFailed(
                format: .binary,
                reason: "Insufficient data for dimensions"
            )
        }
        let dims = data.subdata(in: offset..<offset+4).withUnsafeBytes {
            $0.loadUnaligned(as: Int32.self)
        }
        offset += 4

        // Read model
        guard data.count >= offset + 4 else {
            throw TypedDataError.deserializationFailed(
                format: .binary,
                reason: "Insufficient data for model length"
            )
        }
        let modelLength = Int(data.subdata(in: offset..<offset+4).withUnsafeBytes {
            $0.loadUnaligned(as: Int32.self)
        })
        offset += 4

        guard data.count >= offset + modelLength else {
            throw TypedDataError.deserializationFailed(
                format: .binary,
                reason: "Insufficient data for model string"
            )
        }
        guard let model = String(data: data[offset..<offset+modelLength], encoding: .utf8) else {
            throw TypedDataError.deserializationFailed(
                format: .binary,
                reason: "Invalid model string encoding"
            )
        }
        offset += modelLength

        // Read embedding vector
        let vectorSize = Int(dims) * MemoryLayout<Float>.size
        guard data.count >= offset + vectorSize else {
            throw TypedDataError.deserializationFailed(
                format: .binary,
                reason: "Insufficient data for embedding vector"
            )
        }

        let embedding: [Float] = data[offset..<offset+vectorSize].withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
        offset += vectorSize

        // Read optional input text
        var inputText: String? = nil
        if data.count >= offset + 4 {
            let textLength = Int(data.subdata(in: offset..<offset+4).withUnsafeBytes {
                $0.loadUnaligned(as: Int32.self)
            })
            offset += 4

            if textLength > 0 && data.count >= offset + textLength {
                inputText = String(data: data[offset..<offset+textLength], encoding: .utf8)
                offset += textLength
            }
        }

        // Read optional token count
        var tokenCount: Int? = nil
        if data.count >= offset + 4 {
            let tokens = data.subdata(in: offset..<offset+4).withUnsafeBytes {
                $0.loadUnaligned(as: Int32.self)
            }
            if tokens >= 0 {
                tokenCount = Int(tokens)
            }
        }

        return GeneratedEmbeddingData(
            embedding: embedding,
            dimensions: Int(dims),
            model: model,
            inputText: inputText,
            tokenCount: tokenCount,
            index: nil
        )
    }
}

/// Configuration for embedding generation requests.
///
/// Contains parameters that control how embeddings are generated,
/// such as model selection and dimension count.
public struct EmbeddingConfig: Codable, Sendable {

    /// Embedding model options
    public enum Model: String, Codable, Sendable {
        /// Latest small embedding model (1536 dimensions, best performance/cost)
        case textEmbedding3Small = "text-embedding-3-small"

        /// Latest large embedding model (3072 dimensions, highest quality)
        case textEmbedding3Large = "text-embedding-3-large"

        /// Legacy Ada model (1536 dimensions)
        case textEmbeddingAda002 = "text-embedding-ada-002"

        public var displayName: String {
            switch self {
            case .textEmbedding3Small: return "Text Embedding 3 Small"
            case .textEmbedding3Large: return "Text Embedding 3 Large"
            case .textEmbeddingAda002: return "Ada 002 (Legacy)"
            }
        }

        public var defaultDimensions: Int {
            switch self {
            case .textEmbedding3Small: return 1536
            case .textEmbedding3Large: return 3072
            case .textEmbeddingAda002: return 1536
            }
        }

        /// Minimum allowed dimensions for custom dimension support
        ///
        /// - text-embedding-3-small: 512
        /// - text-embedding-3-large: 256
        /// - text-embedding-ada-002: N/A (does not support custom dimensions)
        public var minimumDimensions: Int? {
            switch self {
            case .textEmbedding3Small: return 512
            case .textEmbedding3Large: return 256
            case .textEmbeddingAda002: return nil
            }
        }

        /// Whether this model supports custom dimensions
        public var supportsCustomDimensions: Bool {
            switch self {
            case .textEmbedding3Small, .textEmbedding3Large: return true
            case .textEmbeddingAda002: return false
            }
        }

        /// Approximate cost per 1M tokens (USD)
        public var costPer1MTokens: Double {
            switch self {
            case .textEmbedding3Small: return 0.02
            case .textEmbedding3Large: return 0.13
            case .textEmbeddingAda002: return 0.10
            }
        }
    }

    /// Encoding format for the embedding
    public enum EncodingFormat: String, Codable, Sendable {
        case float = "float"
        case base64 = "base64"
    }

    /// The model to use for generating embeddings
    public var model: Model

    /// Number of dimensions for the output embedding
    ///
    /// Can be used to reduce dimensions for specific models:
    /// - text-embedding-3-small: 512 to 1536 (default 1536)
    /// - text-embedding-3-large: 256 to 3072 (default 3072)
    /// - text-embedding-ada-002: Always 1536 (not customizable)
    public var dimensions: Int?

    /// Encoding format for the response
    public var encodingFormat: EncodingFormat

    /// Optional user identifier for tracking
    public var user: String?

    /// Creates an embedding configuration
    ///
    /// - Parameters:
    ///   - model: The embedding model (default: textEmbedding3Small)
    ///   - dimensions: Custom dimensions (default: model's default)
    ///   - encodingFormat: Response format (default: float)
    ///   - user: User identifier (default: nil)
    public init(
        model: Model = .textEmbedding3Small,
        dimensions: Int? = nil,
        encodingFormat: EncodingFormat = .float,
        user: String? = nil
    ) {
        self.model = model
        self.dimensions = dimensions
        self.encodingFormat = encodingFormat
        self.user = user
    }

    // MARK: - Presets

    /// Default configuration (text-embedding-3-small, 1536 dimensions)
    public static let `default` = EmbeddingConfig()

    /// High quality configuration (text-embedding-3-large, 3072 dimensions)
    public static let highQuality = EmbeddingConfig(
        model: .textEmbedding3Large
    )

    /// Performance-optimized configuration (text-embedding-3-small, 512 dimensions)
    public static let performance = EmbeddingConfig(
        model: .textEmbedding3Small,
        dimensions: 512
    )

    /// Legacy Ada 002 configuration
    public static let legacy = EmbeddingConfig(
        model: .textEmbeddingAda002
    )
}
