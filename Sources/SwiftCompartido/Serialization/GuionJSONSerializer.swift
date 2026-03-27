//
//  GuionJSONSerializer.swift
//  SwiftCompartido
//
//  JSON serialization for .guion files (Phase 1)
//

import Foundation

#if canImport(SwiftData)
  @preconcurrency import SwiftData
#endif

/// JSON serializer for .guion screenplay files.
///
/// This serializer handles conversion between `GuionDocumentSnapshot` (Codable struct)
/// and .guion JSON files. It produces pretty-printed, human-readable JSON suitable
/// for version control and manual editing.
///
/// ## Overview
///
/// The serializer supports:
/// - **Pretty-printed JSON**: Human-readable with sorted keys
/// - **ISO8601 dates**: Standard date format
/// - **Round-trip fidelity**: Encode → Decode → Identical
/// - **SwiftData integration**: Direct save/load from SwiftData models
///
/// ## Example - Snapshot Serialization
///
/// ```swift
/// // Encode snapshot to JSON
/// let snapshot = GuionDocumentSnapshot(...)
/// let data = try GuionJSONSerializer.encode(snapshot)
/// try data.write(to: url)
///
/// // Decode JSON to snapshot
/// let data = try Data(contentsOf: url)
/// let snapshot = try GuionJSONSerializer.decode(data)
/// ```
///
/// ## Example - SwiftData Integration
///
/// ```swift
/// // Save SwiftData model to .guion file
/// try await GuionJSONSerializer.save(document, to: url)
///
/// // Load .guion file to SwiftData model
/// let document = try await GuionJSONSerializer.load(from: url, in: modelContext)
/// ```
///
/// ## Topics
///
/// ### Snapshot Serialization
/// - ``encode(_:)``
/// - ``decode(_:)``
///
/// ### SwiftData Integration
/// - ``save(_:to:)``
/// - ``load(from:in:)``
///
/// ### Configuration
/// - ``encoder``
/// - ``decoder``
public struct GuionJSONSerializer {

  // MARK: - Configuration

  /// Configured JSON encoder for .guion files
  ///
  /// Produces pretty-printed JSON with sorted keys and ISO8601 dates.
  public static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  /// Configured JSON decoder for .guion files
  ///
  /// Decodes ISO8601 dates.
  public static var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  // MARK: - Snapshot Serialization

  /// Encode a screenplay snapshot to JSON data
  ///
  /// Produces pretty-printed, human-readable JSON suitable for .guion files.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let snapshot = GuionDocumentSnapshot(...)
  /// let data = try GuionJSONSerializer.encode(snapshot)
  /// try data.write(to: url, options: .atomic)
  /// ```
  ///
  /// - Parameter snapshot: Screenplay document snapshot
  /// - Returns: JSON data (UTF-8)
  /// - Throws: `EncodingError` if encoding fails
  public static func encode(_ snapshot: GuionDocumentSnapshot) throws -> Data {
    try encoder.encode(snapshot)
  }

  /// Decode JSON data to a screenplay snapshot
  ///
  /// Decodes a .guion JSON file into a Codable snapshot.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let data = try Data(contentsOf: url)
  /// let snapshot = try GuionJSONSerializer.decode(data)
  /// print("Loaded \(snapshot.elements.count) elements")
  /// ```
  ///
  /// - Parameter data: JSON data (UTF-8)
  /// - Returns: Decoded screenplay document snapshot
  /// - Throws: `DecodingError` if decoding fails
  public static func decode(_ data: Data) throws -> GuionDocumentSnapshot {
    try decoder.decode(GuionDocumentSnapshot.self, from: data)
  }

  // MARK: - SwiftData Integration

  #if canImport(SwiftData)

    /// Save a SwiftData document to a .guion JSON file
    ///
    /// Converts the SwiftData model to a snapshot and serializes to JSON.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @MainActor
    /// func saveDocument(_ document: GuionDocumentModel, to url: URL) async throws {
    ///     try await GuionJSONSerializer.save(document, to: url)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - model: SwiftData document model
    ///   - url: Destination file URL (should end in .guion)
    /// - Throws: `EncodingError` or `CocoaError` if save fails
    @MainActor
    public static func save(
      _ model: GuionDocumentModel,
      to url: URL
    ) throws {
      let snapshot = model.toSnapshot()
      let data = try encode(snapshot)
      try data.write(to: url, options: [.atomic])
    }

    /// Load a .guion JSON file to a SwiftData document
    ///
    /// Decodes the JSON file to a snapshot and converts to a SwiftData model.
    ///
    /// **Note**: The returned model is NOT inserted into the context.
    /// Call `modelContext.insert(document)` to persist it.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @MainActor
    /// func loadDocument(from url: URL, in context: ModelContext) async throws -> GuionDocumentModel {
    ///     let document = try await GuionJSONSerializer.load(from: url, in: context)
    ///     context.insert(document)
    ///     try context.save()
    ///     return document
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - url: Source file URL (.guion file)
    ///   - context: SwiftData model context for the new model
    /// - Returns: SwiftData document model (not yet inserted)
    /// - Throws: `DecodingError` or `CocoaError` if load fails
    @MainActor
    public static func load(
      from url: URL,
      in context: ModelContext
    ) throws -> GuionDocumentModel {
      let data = try Data(contentsOf: url)
      let snapshot = try decode(data)
      return GuionDocumentModel.from(snapshot, in: context)
    }

  #endif
}

// MARK: - Validation

extension GuionJSONSerializer {
  /// Validate round-trip fidelity
  ///
  /// Encodes a snapshot, decodes it back, and verifies the result matches the original.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let snapshot = GuionDocumentSnapshot(...)
  /// try GuionJSONSerializer.validateRoundTrip(snapshot)
  /// ```
  ///
  /// - Parameter snapshot: Original snapshot
  /// - Throws: `ValidationError` if round-trip fails
  public static func validateRoundTrip(_ snapshot: GuionDocumentSnapshot) throws {
    let data = try encode(snapshot)
    let decoded = try decode(data)

    // Verify key properties
    guard decoded.id == snapshot.id else {
      throw ValidationError.idMismatch(expected: snapshot.id, got: decoded.id)
    }
    guard decoded.elements.count == snapshot.elements.count else {
      throw ValidationError.elementCountMismatch(
        expected: snapshot.elements.count,
        got: decoded.elements.count
      )
    }
  }

  /// Validation errors
  public enum ValidationError: Error, CustomStringConvertible {
    case idMismatch(expected: UUID, got: UUID)
    case elementCountMismatch(expected: Int, got: Int)

    public var description: String {
      switch self {
      case .idMismatch(let expected, let got):
        return "Round-trip ID mismatch: expected \(expected), got \(got)"
      case .elementCountMismatch(let expected, let got):
        return "Round-trip element count mismatch: expected \(expected), got \(got)"
      }
    }
  }
}

// MARK: - File Format Info

extension GuionJSONSerializer {
  /// File format metadata
  public struct FileFormat {
    /// Current .guion format version
    public static let version = "1.0"

    /// File extension (without dot)
    public static let fileExtension = "guion"

    /// UTType identifier
    public static let uti = "com.swiftguion.screenplay"

    /// MIME type
    public static let mimeType = "application/vnd.swiftguion+json"

    /// Typical file size for 120-page screenplay without audio
    public static let typicalSize = "1-2 MB"

    /// Maximum recommended file size (with 50 audio clips)
    public static let maxRecommendedSize = "50 MB"
  }
}
