//
//  SerializableTypedData.swift
//  SwiftHablare
//
//  Phase 6A: Protocol for type-specific serialization
//

import Foundation

/// Protocol for typed data that can be serialized to various formats.
///
/// Each typed data type declares its own serialization strategy based on
/// the most appropriate format for the data (JSON, binary, plist, etc.).
///
/// ## Design Rationale
///
/// Different data types have different optimal serialization strategies:
/// - **Text**: JSON (human-readable, debuggable)
/// - **Audio**: Binary (efficient, no conversion overhead)
/// - **Embeddings**: Binary (large float arrays)
/// - **Images**: Binary (PNG/JPEG format)
/// - **Metadata**: Plist (structured, Apple-native)
///
/// Rather than a universal schema system, each type chooses its own format.
///
/// ## Example
///
/// ```swift
/// public struct GeneratedText: SerializableTypedData {
///     public let text: String
///     public let model: String?
///     public let tokenUsage: TokenUsage?
///
///     public var preferredFormat: SerializationFormat { .json }
///
///     public func serialize() throws -> Data {
///         return try JSONEncoder().encode(self)
///     }
///
///     public static func deserialize(from data: Data, format: SerializationFormat) throws -> Self {
///         return try JSONDecoder().decode(Self.self, from: data)
///     }
/// }
/// ```
@available(macOS 15.0, iOS 17.0, *)
public protocol SerializableTypedData: Codable, Sendable {

    /// The preferred serialization format for this data type.
    ///
    /// This is a **recommendation**, not a requirement. The storage layer
    /// may choose a different format based on performance or compatibility needs.
    ///
    /// Examples:
    /// - Text: `.json` (human-readable)
    /// - Audio: `.binary` (efficient)
    /// - Metadata: `.plist` (structured)
    var preferredFormat: SerializationFormat { get }

    /// Serializes this data to the preferred format.
    ///
    /// - Returns: Serialized data ready for storage
    /// - Throws: Serialization errors
    func serialize() throws -> Data

    /// Deserializes data from the specified format.
    ///
    /// - Parameters:
    ///   - data: The serialized data
    ///   - format: The format used for serialization
    /// - Returns: Deserialized typed data
    /// - Throws: Deserialization errors
    static func deserialize(from data: Data, format: SerializationFormat) throws -> Self
}

// MARK: - Default Implementation for Codable

@available(macOS 15.0, iOS 17.0, *)
extension SerializableTypedData {

    /// Default serialization using the preferred format.
    ///
    /// Types can override this for custom serialization logic.
    public func serialize() throws -> Data {
        switch preferredFormat {
        case .json:
            return try JSONEncoder().encode(self)
        case .plist:
            return try PropertyListEncoder().encode(self)
        case .binary:
            // Binary format requires custom implementation
            fatalError("Binary serialization must be implemented by the conforming type")
        case .protobuf:
            // Protobuf requires custom implementation
            fatalError("Protobuf serialization must be implemented by the conforming type")
        case .messagepack:
            // MessagePack requires custom implementation
            fatalError("MessagePack serialization must be implemented by the conforming type")
        }
    }

    /// Default deserialization using the specified format.
    ///
    /// Types can override this for custom deserialization logic.
    public static func deserialize(from data: Data, format: SerializationFormat) throws -> Self {
        switch format {
        case .json:
            return try JSONDecoder().decode(Self.self, from: data)
        case .plist:
            return try PropertyListDecoder().decode(Self.self, from: data)
        case .binary:
            // Binary format requires custom implementation
            fatalError("Binary deserialization must be implemented by the conforming type")
        case .protobuf:
            // Protobuf requires custom implementation
            fatalError("Protobuf deserialization must be implemented by the conforming type")
        case .messagepack:
            // MessagePack requires custom implementation
            fatalError("MessagePack deserialization must be implemented by the conforming type")
        }
    }
}
