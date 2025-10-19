//
//  StorageAreaReference.swift
//  SwiftHablare
//
//  Phase 6A: Reference to request-specific storage area
//

import Foundation

/// Reference to a request-specific storage area for large files.
///
/// Each AI request gets its own storage area within a `.guion` TextPack bundle.
/// This struct provides a thread-safe reference that can be passed to background
/// threads for file writing operations.
///
/// ## Design Rationale
///
/// **Problem**: Large AI-generated data (audio, images, video) can block the main thread
/// if stored directly in SwiftData models.
///
/// **Solution**: Write large data to files on background thread, store only file
/// references in SwiftData on main thread.
///
/// **Storage Structure**:
/// ```
/// MyDocument.guion/         # TextPack bundle (owned by document)
/// ├── info.json             # TextPack metadata
/// ├── text.txt              # Main text content
/// └── assets/               # AI-generated files
///     ├── {requestID}/      # One directory per request
///     │   ├── data.mp3      # Generated audio
///     │   └── metadata.json # Request metadata
///     └── {requestID}/
///         └── data.json     # Generated text
/// ```
///
/// ## Thread Safety
///
/// - `StorageAreaReference` is `Sendable` and can cross actor boundaries
/// - File paths are immutable and safe to use from any thread
/// - File I/O operations can be performed on background threads
/// - Only file references (small structs) cross back to main thread
///
/// ## Lifecycle
///
/// 1. **Request starts**: Document creates storage area for request ID
/// 2. **Background thread**: Requestor writes large data to file
/// 3. **Main thread**: TypedDataBroker stores file reference in SwiftData
/// 4. **Cleanup**: Document manages bundle lifecycle (not individual files)
///
/// ## Example Usage
///
/// ```swift
/// // On main thread (document)
/// let storageArea = document.createStorageArea(for: requestID)
///
/// // Pass to background thread (requestor)
/// let result = await requestor.request(
///     prompt: prompt,
///     configuration: config,
///     storageArea: storageArea
/// )
///
/// // Inside requestor (background thread)
/// let fileURL = storageArea.fileURL(for: "audio.mp3")
/// try audioData.write(to: fileURL)
/// let fileRef = TypedDataFileReference(
///     requestID: storageArea.requestID,
///     fileName: "audio.mp3",
///     fileSize: Int64(audioData.count),
///     mimeType: "audio/mpeg"
/// )
/// ```
public struct StorageAreaReference: Sendable, Codable, Equatable, Hashable {

    // MARK: - Properties

    /// Unique identifier for this request
    ///
    /// Used as directory name within the bundle's assets folder.
    public let requestID: UUID

    /// Base URL for the storage area
    ///
    /// Points to the request-specific directory:
    /// `{bundle}/assets/{requestID}/`
    ///
    /// **Thread Safety**: File URLs are safe to use from any thread
    public let baseURL: URL

    /// Bundle identifier for tracking
    ///
    /// Optional identifier of the `.guion` bundle that owns this storage area.
    /// Used for logging and debugging.
    public let bundleIdentifier: String?

    // MARK: - Initialization

    /// Creates a storage area reference for a request
    ///
    /// - Parameters:
    ///   - requestID: Unique identifier for the request
    ///   - baseURL: Base URL for the storage area directory
    ///   - bundleIdentifier: Optional bundle identifier for tracking
    public init(
        requestID: UUID,
        baseURL: URL,
        bundleIdentifier: String? = nil
    ) {
        self.requestID = requestID
        self.baseURL = baseURL
        self.bundleIdentifier = bundleIdentifier
    }

    // MARK: - File Operations

    /// Returns the file URL for a named file in this storage area
    ///
    /// Thread-safe: Can be called from any thread.
    ///
    /// - Parameter fileName: Name of the file (e.g., "audio.mp3", "data.json")
    /// - Returns: Full URL to the file within this storage area
    public func fileURL(for fileName: String) -> URL {
        baseURL.appendingPathComponent(fileName)
    }

    /// Returns the file URL for a file with specific extension
    ///
    /// Thread-safe: Can be called from any thread.
    ///
    /// - Parameters:
    ///   - baseName: Base name of the file (e.g., "data")
    ///   - fileExtension: File extension (e.g., "mp3", "json")
    /// - Returns: Full URL to the file within this storage area
    public func fileURL(baseName: String, fileExtension: String) -> URL {
        baseURL
            .appendingPathComponent(baseName)
            .appendingPathExtension(fileExtension)
    }

    /// Returns the default data file URL for this storage area
    ///
    /// Uses format: `data.{extension}`
    ///
    /// - Parameter fileExtension: File extension (e.g., "mp3", "json")
    /// - Returns: URL to the default data file
    public func defaultDataFileURL(extension fileExtension: String) -> URL {
        fileURL(baseName: "data", fileExtension: fileExtension)
    }

    // MARK: - Directory Operations

    /// Creates the storage directory if it doesn't exist
    ///
    /// Thread-safe: Can be called from any thread.
    /// **Important**: Must be called before writing files.
    ///
    /// - Throws: File system errors if directory cannot be created
    public func createDirectoryIfNeeded() throws {
        try FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    /// Checks if the storage directory exists
    ///
    /// Thread-safe: Can be called from any thread.
    ///
    /// - Returns: `true` if the directory exists, `false` otherwise
    public func directoryExists() -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: baseURL.path,
            isDirectory: &isDirectory
        )
        return exists && isDirectory.boolValue
    }

    /// Lists all files in this storage area
    ///
    /// Thread-safe: Can be called from any thread.
    ///
    /// - Returns: Array of file URLs in this storage area
    /// - Throws: File system errors if directory cannot be read
    public func listFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentTypeKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case requestID
        case baseURL
        case bundleIdentifier
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.requestID = try container.decode(UUID.self, forKey: .requestID)

        // Decode URL from path string
        let urlString = try container.decode(String.self, forKey: .baseURL)
        guard let url = URL(string: urlString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .baseURL,
                in: container,
                debugDescription: "Invalid URL string: \(urlString)"
            )
        }
        self.baseURL = url

        self.bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requestID, forKey: .requestID)
        try container.encode(baseURL.absoluteString, forKey: .baseURL)
        try container.encodeIfPresent(bundleIdentifier, forKey: .bundleIdentifier)
    }
}

// MARK: - Convenience Constructors

extension StorageAreaReference {

    /// Creates a temporary storage area for testing
    ///
    /// Uses a temporary directory that will be cleaned up by the system.
    ///
    /// - Parameter requestID: Optional request ID (generates new UUID if not provided)
    /// - Returns: Storage area reference in a temporary directory
    public static func temporary(requestID: UUID = UUID()) -> StorageAreaReference {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftHablare-\(UUID().uuidString)")
            .appendingPathComponent("assets")
            .appendingPathComponent(requestID.uuidString)

        return StorageAreaReference(
            requestID: requestID,
            baseURL: tempDir,
            bundleIdentifier: nil
        )
    }

    /// Creates a storage area within a bundle's assets directory
    ///
    /// - Parameters:
    ///   - requestID: Request identifier
    ///   - bundleURL: URL to the .guion bundle
    ///   - bundleIdentifier: Optional bundle identifier
    /// - Returns: Storage area reference within the bundle
    public static func inBundle(
        requestID: UUID,
        bundleURL: URL,
        bundleIdentifier: String? = nil
    ) -> StorageAreaReference {
        let assetsDir = bundleURL
            .appendingPathComponent("assets")
            .appendingPathComponent(requestID.uuidString)

        return StorageAreaReference(
            requestID: requestID,
            baseURL: assetsDir,
            bundleIdentifier: bundleIdentifier
        )
    }
}

// MARK: - CustomStringConvertible

extension StorageAreaReference: CustomStringConvertible {
    public var description: String {
        if let bundleID = bundleIdentifier {
            return "StorageAreaReference(requestID: \(requestID), bundle: \(bundleID))"
        } else {
            return "StorageAreaReference(requestID: \(requestID), url: \(baseURL.path))"
        }
    }
}
