//
//  OutputFileType.swift
//  SwiftHablare
//
//  Phase 6A: Output file type specification
//

import Foundation
import UniformTypeIdentifiers

/// Describes the output file type produced by a requestor.
///
/// Combines file format metadata (MIME type, extension) with storage preferences
/// to help the framework decide how to handle generated data.
///
/// ## Design Rationale
///
/// Each requestor declares what type of file it generates:
/// - **Text requestors**: JSON files with text responses
/// - **Audio requestors**: MP3/WAV files with audio data
/// - **Image requestors**: PNG/JPEG files with image data
///
/// The `OutputFileType` contains:
/// 1. **Format identification**: MIME type, file extension, UTType
/// 2. **Storage preferences**: Size thresholds for file storage
/// 3. **Serialization hints**: Preferred format for typed data
///
/// ## Storage Decision Logic
///
/// The framework uses `shouldStoreAsFile(estimatedSize:)` to decide:
/// - **Small data** (< threshold): Store in SwiftData model directly
/// - **Large data** (≥ threshold): Write to .guion bundle, store file reference
///
/// ## Example Usage
///
/// ```swift
/// // Text requestor outputs JSON
/// public var outputFileType: OutputFileType {
///     .json(category: .text)
/// }
///
/// // Audio requestor outputs MP3 with large file storage
/// public var outputFileType: OutputFileType {
///     .mp3(storeAsFileThreshold: 100_000) // > 100KB goes to file
/// }
///
/// // Custom format
/// public var outputFileType: OutputFileType {
///     OutputFileType(
///         mimeType: "application/x-custom",
///         fileExtension: "custom",
///         utType: UTType(filenameExtension: "custom"),
///         category: .structuredData,
///         serializationFormat: .binary,
///         storeAsFileThreshold: 1_000_000
///     )
/// }
/// ```
@available(macOS 15.0, iOS 17.0, *)
public struct OutputFileType: Codable, Sendable, Equatable, Hashable {

    // MARK: - Properties

    /// MIME type for this file type
    ///
    /// Examples:
    /// - "text/plain"
    /// - "application/json"
    /// - "audio/mpeg"
    /// - "image/png"
    public let mimeType: String

    /// File extension (without leading dot)
    ///
    /// Examples:
    /// - "txt"
    /// - "json"
    /// - "mp3"
    /// - "png"
    public let fileExtension: String

    /// Uniform Type Identifier (UTType)
    ///
    /// Used for system integration and file type identification.
    /// May be `nil` for custom formats not registered with the system.
    public let utType: UTType?

    /// Category of data this file type represents
    ///
    /// Used for UI organization and filtering.
    public let category: ProviderCategory

    /// Preferred serialization format for typed data
    ///
    /// Indicates how the typed data should be serialized when written to file.
    public let serializationFormat: SerializationFormat

    /// Size threshold (in bytes) for file storage
    ///
    /// - If data size ≥ threshold: Write to .guion bundle
    /// - If data size < threshold: Store in SwiftData model
    /// - If `nil`: Always store in SwiftData (no file storage)
    ///
    /// **Default thresholds**:
    /// - Text/JSON: 50KB (most text responses fit in memory)
    /// - Audio: 100KB (most audio is large)
    /// - Images: 100KB (most images are large)
    /// - Binary: 10KB (depends on data type)
    public let storeAsFileThreshold: Int64?

    // MARK: - Initialization

    /// Creates a custom output file type
    ///
    /// - Parameters:
    ///   - mimeType: MIME type for the file
    ///   - fileExtension: File extension without leading dot
    ///   - utType: Optional UTType for system integration
    ///   - category: Category of data this file represents
    ///   - serializationFormat: Preferred serialization format
    ///   - storeAsFileThreshold: Optional size threshold for file storage (bytes)
    public init(
        mimeType: String,
        fileExtension: String,
        utType: UTType?,
        category: ProviderCategory,
        serializationFormat: SerializationFormat,
        storeAsFileThreshold: Int64?
    ) {
        self.mimeType = mimeType
        self.fileExtension = fileExtension
        self.utType = utType
        self.category = category
        self.serializationFormat = serializationFormat
        self.storeAsFileThreshold = storeAsFileThreshold
    }

    // MARK: - Storage Decision

    /// Determines if data should be stored as a file
    ///
    /// - Parameter estimatedSize: Estimated size of the data in bytes
    /// - Returns: `true` if data should be written to file, `false` if it should be stored in model
    public func shouldStoreAsFile(estimatedSize: Int64?) -> Bool {
        guard let threshold = storeAsFileThreshold else {
            // No threshold means never store as file
            return false
        }

        guard let size = estimatedSize else {
            // Unknown size: use category default
            return category.typicallyNeedsFileStorage
        }

        return size >= threshold
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case mimeType
        case fileExtension
        case utTypeIdentifier
        case category
        case serializationFormat
        case storeAsFileThreshold
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mimeType = try container.decode(String.self, forKey: .mimeType)
        self.fileExtension = try container.decode(String.self, forKey: .fileExtension)

        // Decode UTType from identifier string
        if let identifier = try container.decodeIfPresent(String.self, forKey: .utTypeIdentifier) {
            self.utType = UTType(identifier)
        } else {
            self.utType = nil
        }

        self.category = try container.decode(ProviderCategory.self, forKey: .category)
        self.serializationFormat = try container.decode(SerializationFormat.self, forKey: .serializationFormat)
        self.storeAsFileThreshold = try container.decodeIfPresent(Int64.self, forKey: .storeAsFileThreshold)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encode(fileExtension, forKey: .fileExtension)

        // Encode UTType as identifier string
        if let utType = utType {
            try container.encode(utType.identifier, forKey: .utTypeIdentifier)
        }

        try container.encode(category, forKey: .category)
        try container.encode(serializationFormat, forKey: .serializationFormat)
        try container.encodeIfPresent(storeAsFileThreshold, forKey: .storeAsFileThreshold)
    }
}

// MARK: - Common File Types

@available(macOS 15.0, iOS 17.0, *)
extension OutputFileType {

    // MARK: - Text Formats

    /// Plain text file
    ///
    /// - MIME: text/plain
    /// - Extension: .txt
    /// - Threshold: 50KB
    public static func plainText(storeAsFileThreshold: Int64? = 50_000) -> OutputFileType {
        OutputFileType(
            mimeType: "text/plain",
            fileExtension: "txt",
            utType: .plainText,
            category: .text,
            serializationFormat: .json,
            storeAsFileThreshold: storeAsFileThreshold
        )
    }

    /// JSON file
    ///
    /// - MIME: application/json
    /// - Extension: .json
    /// - Threshold: 50KB
    public static func json(
        category: ProviderCategory = .text,
        storeAsFileThreshold: Int64? = 50_000
    ) -> OutputFileType {
        OutputFileType(
            mimeType: "application/json",
            fileExtension: "json",
            utType: .json,
            category: category,
            serializationFormat: .json,
            storeAsFileThreshold: storeAsFileThreshold
        )
    }

    // MARK: - Audio Formats

    /// MP3 audio file
    ///
    /// - MIME: audio/mpeg
    /// - Extension: .mp3
    /// - Threshold: 100KB
    public static func mp3(storeAsFileThreshold: Int64? = 100_000) -> OutputFileType {
        OutputFileType(
            mimeType: "audio/mpeg",
            fileExtension: "mp3",
            utType: .mp3,
            category: .audio,
            serializationFormat: .binary,
            storeAsFileThreshold: storeAsFileThreshold
        )
    }

    /// WAV audio file
    ///
    /// - MIME: audio/wav
    /// - Extension: .wav
    /// - Threshold: 100KB
    public static func wav(storeAsFileThreshold: Int64? = 100_000) -> OutputFileType {
        OutputFileType(
            mimeType: "audio/wav",
            fileExtension: "wav",
            utType: .wav,
            category: .audio,
            serializationFormat: .binary,
            storeAsFileThreshold: storeAsFileThreshold
        )
    }

    /// MPEG-4 audio file
    ///
    /// - MIME: audio/mp4
    /// - Extension: .m4a
    /// - Threshold: 100KB
    public static func m4a(storeAsFileThreshold: Int64? = 100_000) -> OutputFileType {
        OutputFileType(
            mimeType: "audio/mp4",
            fileExtension: "m4a",
            utType: .mpeg4Audio,
            category: .audio,
            serializationFormat: .binary,
            storeAsFileThreshold: storeAsFileThreshold
        )
    }

    // MARK: - Image Formats

    /// PNG image file
    ///
    /// - MIME: image/png
    /// - Extension: .png
    /// - Threshold: 100KB
    public static func png(storeAsFileThreshold: Int64? = 100_000) -> OutputFileType {
        OutputFileType(
            mimeType: "image/png",
            fileExtension: "png",
            utType: .png,
            category: .image,
            serializationFormat: .binary,
            storeAsFileThreshold: storeAsFileThreshold
        )
    }

    /// JPEG image file
    ///
    /// - MIME: image/jpeg
    /// - Extension: .jpg
    /// - Threshold: 100KB
    public static func jpeg(storeAsFileThreshold: Int64? = 100_000) -> OutputFileType {
        OutputFileType(
            mimeType: "image/jpeg",
            fileExtension: "jpg",
            utType: .jpeg,
            category: .image,
            serializationFormat: .binary,
            storeAsFileThreshold: storeAsFileThreshold
        )
    }

    // MARK: - Video Formats

    /// MPEG-4 video file
    ///
    /// - MIME: video/mp4
    /// - Extension: .mp4
    /// - Threshold: 1MB
    public static func mp4(storeAsFileThreshold: Int64? = 1_000_000) -> OutputFileType {
        OutputFileType(
            mimeType: "video/mp4",
            fileExtension: "mp4",
            utType: .mpeg4Movie,
            category: .video,
            serializationFormat: .binary,
            storeAsFileThreshold: storeAsFileThreshold
        )
    }

    /// QuickTime video file
    ///
    /// - MIME: video/quicktime
    /// - Extension: .mov
    /// - Threshold: 1MB
    public static func mov(storeAsFileThreshold: Int64? = 1_000_000) -> OutputFileType {
        OutputFileType(
            mimeType: "video/quicktime",
            fileExtension: "mov",
            utType: .quickTimeMovie,
            category: .video,
            serializationFormat: .binary,
            storeAsFileThreshold: storeAsFileThreshold
        )
    }

    // MARK: - Structured Data Formats

    /// Property list file
    ///
    /// - MIME: application/x-plist
    /// - Extension: .plist
    /// - Threshold: 50KB
    public static func plist(
        category: ProviderCategory = .structuredData,
        storeAsFileThreshold: Int64? = 50_000
    ) -> OutputFileType {
        OutputFileType(
            mimeType: "application/x-plist",
            fileExtension: "plist",
            utType: .propertyList,
            category: category,
            serializationFormat: .plist,
            storeAsFileThreshold: storeAsFileThreshold
        )
    }

    /// Binary data file
    ///
    /// - MIME: application/octet-stream
    /// - Extension: .bin
    /// - Threshold: 10KB
    public static func binary(
        category: ProviderCategory,
        fileExtension: String = "bin",
        storeAsFileThreshold: Int64? = 10_000
    ) -> OutputFileType {
        OutputFileType(
            mimeType: "application/octet-stream",
            fileExtension: fileExtension,
            utType: UTType(filenameExtension: fileExtension),
            category: category,
            serializationFormat: .binary,
            storeAsFileThreshold: storeAsFileThreshold
        )
    }
}
