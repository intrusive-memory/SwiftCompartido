//
//  SerializationFormat.swift
//  SwiftHablare
//
//  Phase 6A: Serialization format enumeration
//

import Foundation

/// Serialization formats for typed data.
///
/// Each format has different characteristics suitable for different data types:
///
/// - **JSON**: Human-readable, debuggable, good for text
/// - **Plist**: Structured, Apple-native, good for metadata
/// - **Binary**: Efficient, good for audio/images/large data
/// - **Protobuf**: Compact, versioned, good for structured data
/// - **MessagePack**: Compact binary JSON-like, good for mixed data
///
/// ## Design Rationale
///
/// Different data types have different optimal serialization strategies:
/// - **Text responses**: JSON (human-readable, debuggable)
/// - **Audio data**: Binary (efficient, no conversion overhead)
/// - **Vector embeddings**: Binary (large float arrays)
/// - **Images**: Binary (PNG/JPEG format)
/// - **Configuration metadata**: Plist (structured, Apple-native)
///
/// Rather than imposing a universal schema system, each typed data type
/// declares its own `preferredFormat` via `SerializableTypedData` protocol.
///
/// ## Example Usage
///
/// ```swift
/// public struct GeneratedText: SerializableTypedData {
///     public let text: String
///     public let model: String?
///
///     // Text is human-readable, use JSON
///     public var preferredFormat: SerializationFormat { .json }
/// }
///
/// public struct GeneratedAudio: SerializableTypedData {
///     public let audioData: Data
///     public let format: AudioFormat
///
///     // Binary data, use binary format
///     public var preferredFormat: SerializationFormat { .binary }
/// }
/// ```
public enum SerializationFormat: String, Codable, Sendable, CaseIterable, Identifiable {

    /// JSON format (application/json)
    ///
    /// **Characteristics**:
    /// - Human-readable text format
    /// - Good for debugging and inspection
    /// - Widely supported
    /// - Larger file size than binary formats
    ///
    /// **Best for**:
    /// - Text responses
    /// - Configuration data
    /// - Metadata
    /// - Structured data that needs inspection
    ///
    /// **Implementation**:
    /// - Uses `JSONEncoder` / `JSONDecoder`
    /// - Default implementation provided in `SerializableTypedData`
    case json

    /// Property List format (application/x-plist)
    ///
    /// **Characteristics**:
    /// - Apple-native format
    /// - Good for hierarchical data
    /// - XML or binary representation
    /// - Strong type preservation
    ///
    /// **Best for**:
    /// - Configuration metadata
    /// - Preferences and settings
    /// - Hierarchical structures
    /// - Apple ecosystem integration
    ///
    /// **Implementation**:
    /// - Uses `PropertyListEncoder` / `PropertyListDecoder`
    /// - Default implementation provided in `SerializableTypedData`
    case plist

    /// Binary format (application/octet-stream)
    ///
    /// **Characteristics**:
    /// - Most efficient storage
    /// - No conversion overhead
    /// - Not human-readable
    /// - Requires custom serialization logic
    ///
    /// **Best for**:
    /// - Audio data (WAV, MP3, PCM)
    /// - Image data (PNG, JPEG)
    /// - Vector embeddings (float arrays)
    /// - Large data blobs
    ///
    /// **Implementation**:
    /// - Requires custom `serialize()` / `deserialize()` implementation
    /// - No default implementation (will fatalError)
    case binary

    /// Protocol Buffers format (application/x-protobuf)
    ///
    /// **Characteristics**:
    /// - Compact binary format
    /// - Schema-based
    /// - Versioning support
    /// - Fast serialization
    ///
    /// **Best for**:
    /// - Structured data with versioning needs
    /// - API communication
    /// - Cross-language compatibility
    /// - Performance-critical serialization
    ///
    /// **Implementation**:
    /// - Requires custom implementation with protobuf library
    /// - No default implementation (will fatalError)
    ///
    /// **Phase 6A**: Not implemented yet, reserved for future use
    case protobuf

    /// MessagePack format (application/x-msgpack)
    ///
    /// **Characteristics**:
    /// - Compact binary JSON-like format
    /// - Faster than JSON
    /// - More compact than JSON
    /// - Good for mixed data types
    ///
    /// **Best for**:
    /// - Mixed structured and binary data
    /// - Network transmission
    /// - Compact storage needs
    /// - JSON-like flexibility with binary efficiency
    ///
    /// **Implementation**:
    /// - Requires custom implementation with MessagePack library
    /// - No default implementation (will fatalError)
    ///
    /// **Phase 6A**: Not implemented yet, reserved for future use
    case messagepack

    // MARK: - Identifiable

    public var id: String { rawValue }

    // MARK: - Display Properties

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .json: return "JSON"
        case .plist: return "Property List"
        case .binary: return "Binary"
        case .protobuf: return "Protocol Buffers"
        case .messagepack: return "MessagePack"
        }
    }

    /// Brief description of format characteristics
    public var description: String {
        switch self {
        case .json:
            return "Human-readable JSON format, good for text and debugging"
        case .plist:
            return "Apple-native property list format, good for configuration"
        case .binary:
            return "Efficient binary format, good for audio/images/large data"
        case .protobuf:
            return "Compact protocol buffers format, good for structured data"
        case .messagepack:
            return "Compact binary JSON-like format, good for mixed data"
        }
    }

    // MARK: - File Properties

    /// File extension for this format
    public var fileExtension: String {
        switch self {
        case .json: return "json"
        case .plist: return "plist"
        case .binary: return "bin"
        case .protobuf: return "pb"
        case .messagepack: return "msgpack"
        }
    }

    /// MIME type for this format
    public var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .plist: return "application/x-plist"
        case .binary: return "application/octet-stream"
        case .protobuf: return "application/x-protobuf"
        case .messagepack: return "application/x-msgpack"
        }
    }

    // MARK: - Format Characteristics

    /// Whether this format is human-readable
    public var isHumanReadable: Bool {
        switch self {
        case .json: return true
        case .plist: return true // XML plist is readable
        case .binary: return false
        case .protobuf: return false
        case .messagepack: return false
        }
    }

    /// Whether this format has a default implementation
    ///
    /// Formats without default implementations require custom
    /// `serialize()` / `deserialize()` methods in the conforming type.
    public var hasDefaultImplementation: Bool {
        switch self {
        case .json, .plist: return true
        case .binary, .protobuf, .messagepack: return false
        }
    }

    /// Whether this format is implemented in Phase 6A
    public var isImplemented: Bool {
        switch self {
        case .json, .plist, .binary: return true
        case .protobuf, .messagepack: return false
        }
    }

    // MARK: - Format Selection

    /// Recommends a serialization format for given data characteristics
    ///
    /// - Parameters:
    ///   - isTextual: Whether the data is primarily textual
    ///   - needsInspection: Whether human readability is important
    ///   - estimatedSize: Estimated data size in bytes
    /// - Returns: Recommended serialization format
    public static func recommend(
        isTextual: Bool,
        needsInspection: Bool,
        estimatedSize: Int64?
    ) -> SerializationFormat {
        // Prefer human-readable formats for textual data or when inspection is needed
        if isTextual || needsInspection {
            return .json
        }

        // For large data, prefer binary
        if let size = estimatedSize, size > 1_000_000 { // > 1MB
            return .binary
        }

        // Default to JSON for small/medium structured data
        return .json
    }
}
