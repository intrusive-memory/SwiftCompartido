//
//  TypedDataFileReference.swift
//  SwiftHablare
//
//  Phase 6A: Reference to typed data stored as file
//

import Foundation
import SwiftData
import CryptoKit

/// Reference to typed data stored as a file in a `.guion` bundle.
///
/// Instead of storing large binary data directly in SwiftData models,
/// this struct stores a lightweight reference to a file on disk.
///
/// ## Design Rationale
///
/// **Problem**: Storing large data in SwiftData models:
/// - Blocks main thread during serialization/deserialization
/// - Increases model store size dramatically
/// - Slows down queries and fetches
/// - Poor memory usage (entire blob loaded into memory)
///
/// **Solution**: Store file reference instead of data:
/// - SwiftData model stores only this small struct (~200 bytes)
/// - Large data written to file on background thread
/// - File loading is lazy (only when needed)
/// - Bundle manages file lifecycle
///
/// ## Storage Structure
///
/// ```
/// MyDocument.guion/
/// └── assets/
///     └── {requestID}/       # Request-specific directory
///         ├── data.mp3       # Generated audio (referenced by this struct)
///         └── metadata.json  # Optional metadata
/// ```
///
/// ## Thread Safety
///
/// - `TypedDataFileReference` is `Sendable` and can cross actor boundaries
/// - File paths are immutable and safe to use from any thread
/// - File loading can happen on background threads
/// - Only small struct stored in SwiftData on main thread
///
/// ## Lifecycle
///
/// 1. **Creation** (background thread):
///    ```swift
///    let fileURL = storageArea.defaultDataFileURL(extension: "mp3")
///    try audioData.write(to: fileURL)
///    let fileRef = TypedDataFileReference(
///        requestID: requestID,
///        fileName: "data.mp3",
///        fileSize: Int64(audioData.count),
///        mimeType: "audio/mpeg"
///    )
///    ```
///
/// 2. **Storage** (main thread):
///    ```swift
///    let model = responseModel(from: typedData, fileReference: fileRef, requestID: requestID)
///    modelContext.insert(model)
///    ```
///
/// 3. **Loading** (any thread):
///    ```swift
///    let fileURL = bundle.fileURL(for: fileRef)
///    let data = try Data(contentsOf: fileURL)
///    ```
///
/// 4. **Cleanup**: Document manages bundle lifecycle
///
/// ## Example Usage
///
/// ```swift
/// // Audio requestor creates file reference
/// public struct GeneratedAudio: SerializableTypedData {
///     public let fileReference: TypedDataFileReference
///     public let format: AudioFormat
///     public let duration: TimeInterval
///
///     // Load audio data lazily when needed
///     public func loadAudioData(from bundle: GuionBundle) throws -> Data {
///         let fileURL = bundle.fileURL(for: fileReference)
///         return try Data(contentsOf: fileURL)
///     }
/// }
/// ```
@available(macOS 15.0, iOS 17.0, *)
public struct TypedDataFileReference: Codable, Sendable, Equatable, Hashable {

    // MARK: - Properties

    /// Request ID that owns this file
    ///
    /// Used to locate the file within the bundle:
    /// `{bundle}/assets/{requestID}/{fileName}`
    public let requestID: UUID

    /// Name of the file within the request directory
    ///
    /// Examples:
    /// - "data.mp3"
    /// - "data.json"
    /// - "image.png"
    /// - "audio_0001.wav"
    public let fileName: String

    /// Size of the file in bytes
    ///
    /// Stored for quick size checks without reading the file.
    public let fileSize: Int64

    /// MIME type of the file
    ///
    /// Examples:
    /// - "audio/mpeg"
    /// - "application/json"
    /// - "image/png"
    public let mimeType: String

    /// File extension (derived from fileName)
    ///
    /// Computed property for convenience.
    public var fileExtension: String {
        (fileName as NSString).pathExtension
    }

    /// Timestamp when the file was created
    ///
    /// Stored for reference and debugging.
    public let createdAt: Date

    /// Optional checksum for integrity verification
    ///
    /// SHA-256 hash of file contents (64 hex characters).
    /// Used to verify file hasn't been corrupted or modified.
    public let checksum: String?

    // MARK: - Initialization

    /// Creates a file reference for typed data
    ///
    /// - Parameters:
    ///   - requestID: Request ID that owns this file
    ///   - fileName: Name of the file
    ///   - fileSize: Size of the file in bytes
    ///   - mimeType: MIME type of the file
    ///   - createdAt: Creation timestamp (defaults to now)
    ///   - checksum: Optional checksum for integrity verification
    public init(
        requestID: UUID,
        fileName: String,
        fileSize: Int64,
        mimeType: String,
        createdAt: Date = Date(),
        checksum: String? = nil
    ) {
        self.requestID = requestID
        self.fileName = fileName
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.createdAt = createdAt
        self.checksum = checksum
    }

    // MARK: - File Path Construction

    /// Returns the relative path to the file within a bundle
    ///
    /// Format: `assets/{requestID}/{fileName}`
    ///
    /// - Returns: Relative path from bundle root
    public var relativePath: String {
        "assets/\(requestID.uuidString)/\(fileName)"
    }

    /// Constructs the full file URL within a storage area
    ///
    /// - Parameter storageArea: Storage area reference
    /// - Returns: Full URL to the file
    public func fileURL(in storageArea: StorageAreaReference) -> URL {
        storageArea.fileURL(for: fileName)
    }

    /// Constructs the full file URL within a bundle
    ///
    /// - Parameter bundleURL: URL to the .guion bundle
    /// - Returns: Full URL to the file
    public func fileURL(in bundleURL: URL) -> URL {
        bundleURL
            .appendingPathComponent("assets")
            .appendingPathComponent(requestID.uuidString)
            .appendingPathComponent(fileName)
    }

    // MARK: - File Operations

    /// Reads the file data from a storage area
    ///
    /// Thread-safe: Can be called from any thread.
    ///
    /// - Parameter storageArea: Storage area where the file is located
    /// - Returns: File contents as Data
    /// - Throws: File system errors if file cannot be read
    public func readData(from storageArea: StorageAreaReference) throws -> Data {
        let fileURL = self.fileURL(in: storageArea)
        return try Data(contentsOf: fileURL)
    }

    /// Reads the file data from a bundle
    ///
    /// Thread-safe: Can be called from any thread.
    ///
    /// - Parameter bundleURL: URL to the .guion bundle
    /// - Returns: File contents as Data
    /// - Throws: File system errors if file cannot be read
    public func readData(from bundleURL: URL) throws -> Data {
        let fileURL = self.fileURL(in: bundleURL)
        return try Data(contentsOf: fileURL)
    }

    /// Checks if the file exists in a storage area
    ///
    /// Thread-safe: Can be called from any thread.
    ///
    /// - Parameter storageArea: Storage area where the file should be located
    /// - Returns: `true` if the file exists, `false` otherwise
    public func fileExists(in storageArea: StorageAreaReference) -> Bool {
        let fileURL = self.fileURL(in: storageArea)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Checks if the file exists in a bundle
    ///
    /// Thread-safe: Can be called from any thread.
    ///
    /// - Parameter bundleURL: URL to the .guion bundle
    /// - Returns: `true` if the file exists, `false` otherwise
    public func fileExists(in bundleURL: URL) -> Bool {
        let fileURL = self.fileURL(in: bundleURL)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    // MARK: - File Attributes

    /// Returns file attributes from disk
    ///
    /// Thread-safe: Can be called from any thread.
    ///
    /// - Parameter storageArea: Storage area where the file is located
    /// - Returns: File attributes dictionary
    /// - Throws: File system errors if attributes cannot be read
    public func fileAttributes(in storageArea: StorageAreaReference) throws -> [FileAttributeKey: Any] {
        let fileURL = self.fileURL(in: storageArea)
        return try FileManager.default.attributesOfItem(atPath: fileURL.path)
    }

    /// Verifies that the actual file size matches the stored size
    ///
    /// Thread-safe: Can be called from any thread.
    ///
    /// - Parameter storageArea: Storage area where the file is located
    /// - Returns: `true` if sizes match, `false` otherwise
    /// - Throws: File system errors if file cannot be accessed
    public func verifySizeMatches(in storageArea: StorageAreaReference) throws -> Bool {
        let attributes = try fileAttributes(in: storageArea)
        guard let actualSize = attributes[.size] as? Int64 else {
            return false
        }
        return actualSize == fileSize
    }

    // MARK: - Integrity Verification

    /// Generates SHA-256 checksum of file contents
    ///
    /// Thread-safe: Can be called from any thread.
    ///
    /// - Parameter storageArea: Storage area where the file is located
    /// - Returns: SHA-256 checksum as hex string (64 characters)
    /// - Throws: File system or hashing errors
    public func generateChecksum(in storageArea: StorageAreaReference) throws -> String {
        let data = try readData(from: storageArea)
        return data.sha256Hash
    }

    /// Verifies that the file checksum matches the stored checksum
    ///
    /// Thread-safe: Can be called from any thread.
    ///
    /// - Parameter storageArea: Storage area where the file is located
    /// - Returns: `true` if checksums match or no checksum is stored, `false` if mismatch
    /// - Throws: File system or hashing errors
    public func verifyChecksum(in storageArea: StorageAreaReference) throws -> Bool {
        guard let expectedChecksum = checksum else {
            // No checksum stored, assume valid
            return true
        }

        let actualChecksum = try generateChecksum(in: storageArea)
        return actualChecksum == expectedChecksum
    }
}

// MARK: - Convenience Constructors

@available(macOS 15.0, iOS 17.0, *)
extension TypedDataFileReference {

    /// Creates a file reference from written data
    ///
    /// Convenience initializer that automatically calculates file size.
    ///
    /// - Parameters:
    ///   - requestID: Request ID that owns this file
    ///   - fileName: Name of the file
    ///   - data: File data (used to calculate size)
    ///   - mimeType: MIME type of the file
    ///   - includeChecksum: Whether to calculate SHA-256 checksum
    /// - Returns: File reference with calculated metadata
    public static func from(
        requestID: UUID,
        fileName: String,
        data: Data,
        mimeType: String,
        includeChecksum: Bool = false
    ) -> TypedDataFileReference {
        TypedDataFileReference(
            requestID: requestID,
            fileName: fileName,
            fileSize: Int64(data.count),
            mimeType: mimeType,
            createdAt: Date(),
            checksum: includeChecksum ? data.sha256Hash : nil
        )
    }

    /// Creates a file reference from an existing file URL
    ///
    /// Reads file attributes to populate metadata.
    ///
    /// - Parameters:
    ///   - requestID: Request ID that owns this file
    ///   - fileURL: URL to the existing file
    ///   - mimeType: MIME type of the file
    ///   - includeChecksum: Whether to calculate SHA-256 checksum
    /// - Returns: File reference with metadata from disk
    /// - Throws: File system errors if file cannot be read
    public static func from(
        requestID: UUID,
        fileURL: URL,
        mimeType: String,
        includeChecksum: Bool = false
    ) throws -> TypedDataFileReference {
        let fileName = fileURL.lastPathComponent
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)

        guard let fileSize = attributes[.size] as? Int64 else {
            throw TypedDataError.fileOperationFailed(
                operation: "read file size",
                reason: "File size attribute not found"
            )
        }

        let checksum: String?
        if includeChecksum {
            let data = try Data(contentsOf: fileURL)
            checksum = data.sha256Hash
        } else {
            checksum = nil
        }

        return TypedDataFileReference(
            requestID: requestID,
            fileName: fileName,
            fileSize: fileSize,
            mimeType: mimeType,
            createdAt: Date(),
            checksum: checksum
        )
    }
}

// MARK: - CustomStringConvertible

@available(macOS 15.0, iOS 17.0, *)
extension TypedDataFileReference: CustomStringConvertible {
    public var description: String {
        "TypedDataFileReference(requestID: \(requestID), fileName: \(fileName), size: \(fileSize) bytes)"
    }
}

// MARK: - Data Extensions

@available(macOS 15.0, iOS 17.0, *)
extension Data {
    /// Calculates SHA-256 hash of data
    ///
    /// Uses CryptoKit for secure, deterministic hashing suitable for
    /// file integrity verification.
    ///
    /// - Returns: SHA-256 hash as hex string (64 characters)
    fileprivate var sha256Hash: String {
        let digest = SHA256.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
