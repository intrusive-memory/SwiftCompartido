//
//  TypedDataStorage.swift
//  SwiftCompartido
//
//  Unified storage model for all AI-generated content types
//  Consolidates GeneratedTextRecord, GeneratedAudioRecord, GeneratedImageRecord, and GeneratedEmbeddingRecord
//

import Foundation
import SwiftData
import CloudKit

/// Errors specific to TypedDataStorage operations
public enum TypedDataStorageError: Error, CustomStringConvertible {
    case unsupportedMimeType(String)
    case storageTypeNotAvailable(mimeType: String, reason: String)
    case invalidStorageConfiguration(reason: String)
    case contentTypeMismatch(expected: String, got: String)

    public var description: String {
        switch self {
        case .unsupportedMimeType(let mimeType):
            return "Unsupported MIME type: \(mimeType). Supported types: text/*, image/*, audio/*, video/*, application/x-embedding"
        case .storageTypeNotAvailable(let mimeType, let reason):
            return "Storage type not available for MIME type '\(mimeType)': \(reason)"
        case .invalidStorageConfiguration(let reason):
            return "Invalid storage configuration: \(reason)"
        case .contentTypeMismatch(let expected, let got):
            return "Content type mismatch: expected \(expected), got \(got)"
        }
    }
}

/// Unified SwiftData model for storing all types of AI-generated content.
///
/// This model consolidates the previous separate models (GeneratedTextRecord, GeneratedAudioRecord,
/// GeneratedImageRecord, GeneratedEmbeddingRecord) into a single flexible storage system.
///
/// ## Storage Strategy
/// Content is routed to the appropriate storage field based on MIME type:
/// - `text/*` → Stored in `textValue` field
/// - `image/*` → Stored in `binaryValue` field
/// - `audio/*` → Stored in `binaryValue` field
/// - `video/*` → Stored in `binaryValue` field
/// - `application/x-embedding` → Stored in `binaryValue` field
///
/// ## Phase 6 File Storage
/// Large content can be stored in files with references:
/// - Small content: Stored directly in textValue/binaryValue
/// - Large content: Stored in file, referenced by `fileReference`
///
/// ## Example Usage
/// ```swift
/// // Text content
/// let textRecord = TypedDataStorage(
///     providerId: "openai",
///     requestorID: "gpt-4",
///     mimeType: "text/plain",
///     textValue: "Generated text",
///     wordCount: 2,
///     characterCount: 14
/// )
///
/// // Audio content
/// let audioRecord = TypedDataStorage(
///     providerId: "elevenlabs",
///     requestorID: "tts.rachel",
///     mimeType: "audio/mpeg",
///     binaryValue: audioData,
///     durationSeconds: 5.5,
///     voiceID: "rachel",
///     voiceName: "Rachel"
/// )
/// ```
@Model
public final class TypedDataStorage {

    // MARK: - Identity

    /// Unique identifier (matches request ID)
    @Attribute(.unique) public var id: UUID

    /// Provider that generated this content
    public var providerId: String

    /// Specific requestor that generated this content
    public var requestorID: String

    // MARK: - Content Storage

    /// Text content storage (for text/* MIME types)
    ///
    /// Used when mimeType starts with "text/".
    /// For large text, this may be nil with content in file via fileReference.
    public var textValue: String?

    /// Binary content storage (for image/*, audio/*, video/*, application/* MIME types)
    ///
    /// Used for all non-text content types.
    /// For large binary data, this may be nil with content in file via fileReference.
    public var binaryValue: Data?

    /// MIME type determining storage and interpretation
    ///
    /// Supported types:
    /// - text/* (plain, html, markdown, etc.)
    /// - image/* (png, jpeg, webp, etc.)
    /// - audio/* (mpeg, wav, m4a, etc.)
    /// - video/* (mp4, mov, etc.)
    /// - application/x-embedding (for vector embeddings)
    public var mimeType: String

    // MARK: - Common Metadata

    /// The prompt used to generate this content
    public var prompt: String

    /// Model identifier that generated this content
    public var modelIdentifier: String?

    /// Estimated cost in USD (if available)
    public var estimatedCost: Double?

    /// Reference to file if content is stored externally
    ///
    /// When content is large, it's written to a .guion bundle file
    /// and this property stores the reference for retrieval.
    public var fileReference: TypedDataFileReference?

    // MARK: - Text-specific Metadata (used when mimeType starts with "text/")

    /// Word count (for text content)
    public var wordCount: Int?

    /// Character count (for text content)
    public var characterCount: Int?

    /// Language code (e.g., "en", "es") for text content
    public var languageCode: String?

    /// Total token count (for text generation)
    public var tokenCount: Int?

    /// Completion tokens used (for text generation)
    public var completionTokens: Int?

    /// Prompt tokens used (for text generation)
    public var promptTokens: Int?

    // MARK: - Audio-specific Metadata (used when mimeType starts with "audio/")

    /// Audio format (e.g., "mp3", "wav", "m4a")
    public var audioFormat: String?

    /// Duration in seconds (for audio/video)
    public var durationSeconds: Double?

    /// Sample rate in Hz (for audio)
    public var sampleRate: Int?

    /// Bit rate in bps (for audio/video)
    public var bitRate: Int?

    /// Number of channels (1 = mono, 2 = stereo)
    public var channels: Int?

    /// Voice ID used for generation (for TTS audio)
    public var voiceID: String?

    /// Voice name (human-readable, for TTS audio)
    public var voiceName: String?

    // MARK: - Image-specific Metadata (used when mimeType starts with "image/")

    /// Image format (e.g., "png", "jpeg", "webp")
    public var imageFormat: String?

    /// Image width in pixels
    public var width: Int?

    /// Image height in pixels
    public var height: Int?

    /// Revised prompt (if the model modified the original)
    ///
    /// Some models like DALL-E 3 may revise prompts for safety or quality.
    public var revisedPrompt: String?

    // MARK: - Embedding-specific Metadata (used when mimeType = "application/x-embedding")

    /// Number of dimensions in the embedding
    public var dimensions: Int?

    /// The input text that was embedded
    ///
    /// Truncated to 1000 characters for storage efficiency.
    public var inputText: String?

    /// Index in batch (if part of batch request)
    public var batchIndex: Int?

    // MARK: - Owner Reference

    /// Optional reference to the owning GuionElement
    ///
    /// When TypedDataStorage is associated with a screenplay element
    /// (e.g., generated audio for dialogue, images for scene descriptions),
    /// this relationship tracks the owner.
    @Relationship(deleteRule: .nullify, inverse: \GuionElementModel.generatedContent)
    public var owningElement: GuionElementModel?

    /// Optional reference to the owning GuionDocument
    ///
    /// When TypedDataStorage is associated with an entire document
    /// (e.g., document-level summaries or embeddings),
    /// this relationship tracks the owner.
    @Relationship(deleteRule: .nullify, inverse: \GuionDocumentModel.generatedContent)
    public var owningDocument: GuionDocumentModel?

    /// Generic owner identifier for other model types
    ///
    /// Stores a URL representation of a PersistentIdentifier for
    /// model types not explicitly supported by typed relationships.
    /// Format: "x-coredata://[store-id]/[model]/p[entity-id]"
    public var ownerIdentifier: String?

    // MARK: - Timestamps

    /// When this content was generated
    public var generatedAt: Date

    /// When this record was last modified
    public var modifiedAt: Date

    // MARK: - CloudKit Sync Properties

    /// CloudKit record identifier (nil for local-only records)
    public var cloudKitRecordID: String?

    /// CloudKit change tag for conflict detection
    public var cloudKitChangeTag: String?

    /// When this record was last synced to CloudKit
    public var lastSyncedAt: Date?

    /// Current sync status
    public var syncStatus: SyncStatus

    /// Owner's CloudKit user record ID
    public var ownerUserRecordID: String?

    /// User record IDs with shared access
    public var sharedWith: [String]?

    /// Conflict resolution version (increments on each change)
    public var conflictVersion: Int

    /// Storage mode for the content
    public var storageMode: StorageMode

    /// CloudKit asset for large files (when using CloudKit storage)
    @Attribute(.externalStorage)
    public var cloudKitAsset: Data?

    // MARK: - Initialization

    /// Creates a typed data storage record
    ///
    /// - Parameters:
    ///   - id: Unique identifier (typically the request ID)
    ///   - providerId: Provider identifier
    ///   - requestorID: Specific requestor identifier
    ///   - mimeType: MIME type determining storage type
    ///   - textValue: Text content (for text/* types)
    ///   - binaryValue: Binary content (for non-text types)
    ///   - prompt: The generation prompt
    ///   - modelIdentifier: Model identifier (optional)
    ///   - estimatedCost: Estimated cost (optional)
    ///   - fileReference: File reference (optional)
    ///   - storageMode: Storage mode (defaults to local)
    ///   - Additional metadata parameters are type-specific (see individual parameters)
    public init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        mimeType: String,
        textValue: String? = nil,
        binaryValue: Data? = nil,
        prompt: String = "",
        modelIdentifier: String? = nil,
        estimatedCost: Double? = nil,
        fileReference: TypedDataFileReference? = nil,
        storageMode: StorageMode = .local,
        // Text-specific
        wordCount: Int? = nil,
        characterCount: Int? = nil,
        languageCode: String? = nil,
        tokenCount: Int? = nil,
        completionTokens: Int? = nil,
        promptTokens: Int? = nil,
        // Audio-specific
        audioFormat: String? = nil,
        durationSeconds: Double? = nil,
        sampleRate: Int? = nil,
        bitRate: Int? = nil,
        channels: Int? = nil,
        voiceID: String? = nil,
        voiceName: String? = nil,
        // Image-specific
        imageFormat: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        revisedPrompt: String? = nil,
        // Embedding-specific
        dimensions: Int? = nil,
        inputText: String? = nil,
        batchIndex: Int? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.requestorID = requestorID
        self.mimeType = mimeType
        self.textValue = textValue
        self.binaryValue = binaryValue
        self.prompt = prompt
        self.modelIdentifier = modelIdentifier
        self.estimatedCost = estimatedCost
        self.fileReference = fileReference
        self.generatedAt = Date()
        self.modifiedAt = Date()

        // Text-specific
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.languageCode = languageCode
        self.tokenCount = tokenCount
        self.completionTokens = completionTokens
        self.promptTokens = promptTokens

        // Audio-specific
        self.audioFormat = audioFormat
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.bitRate = bitRate
        self.channels = channels
        self.voiceID = voiceID
        self.voiceName = voiceName

        // Image-specific
        self.imageFormat = imageFormat
        self.width = width
        self.height = height
        self.revisedPrompt = revisedPrompt

        // Embedding-specific
        self.dimensions = dimensions
        self.inputText = inputText
        self.batchIndex = batchIndex

        // CloudKit defaults
        self.cloudKitRecordID = nil
        self.cloudKitChangeTag = nil
        self.lastSyncedAt = nil
        self.syncStatus = storageMode == .local ? .localOnly : .pending
        self.ownerUserRecordID = nil
        self.sharedWith = nil
        self.conflictVersion = 1
        self.storageMode = storageMode
        self.cloudKitAsset = nil
    }

    // MARK: - MIME Type Validation

    /// Validates that the MIME type is supported for storage
    ///
    /// - Throws: TypedDataStorageError.unsupportedMimeType if not supported
    public func validateMimeType() throws {
        guard Self.isMimeTypeSupported(mimeType) else {
            throw TypedDataStorageError.unsupportedMimeType(mimeType)
        }
    }

    /// Checks if a MIME type is supported for storage
    ///
    /// - Parameter mimeType: The MIME type to check
    /// - Returns: true if supported, false otherwise
    public static func isMimeTypeSupported(_ mimeType: String) -> Bool {
        let lowercased = mimeType.lowercased()
        return lowercased.hasPrefix("text/") ||
               lowercased.hasPrefix("image/") ||
               lowercased.hasPrefix("audio/") ||
               lowercased.hasPrefix("video/") ||
               lowercased == "application/x-embedding"
    }

    /// Returns the storage field type for a given MIME type
    ///
    /// - Parameter mimeType: The MIME type
    /// - Returns: "text" for text/* types, "binary" for all others
    /// - Throws: TypedDataStorageError if MIME type is not supported
    public static func storageFieldType(for mimeType: String) throws -> String {
        guard isMimeTypeSupported(mimeType) else {
            throw TypedDataStorageError.unsupportedMimeType(mimeType)
        }

        return mimeType.lowercased().hasPrefix("text/") ? "text" : "binary"
    }

    // MARK: - Content Retrieval

    /// Retrieves the content, loading from file if necessary
    ///
    /// Intelligently loads content from the best available source with fallback chain:
    /// 1. **CloudKit asset**: Checked first for .cloudKit/.hybrid storage modes
    /// 2. **In-memory content**: textValue or binaryValue for small content
    /// 3. **File-based storage**: Via fileReference for large content (>1MB chunked reading)
    ///
    /// Supports progress reporting with automatic source detection messaging.
    ///
    /// - Parameters:
    ///   - storageArea: Storage area for file loading (required if content is file-based)
    ///   - progress: Optional progress tracking for file I/O operations
    /// - Returns: Content as Data (binary data or UTF-8 encoded text)
    /// - Throws: TypedDataError or TypedDataStorageError if content cannot be retrieved
    public func getContent(from storageArea: StorageAreaReference? = nil, progress: OperationProgress? = nil) throws -> Data {
        // Check if content is in CloudKit asset
        if let cloudKitAsset = cloudKitAsset {
            progress?.setTotalUnitCount(Int64(cloudKitAsset.count))
            progress?.update(completedUnits: 0, description: "Loading from CloudKit asset...")
            progress?.update(completedUnits: Int64(cloudKitAsset.count), description: "Loaded from CloudKit asset", force: true)
            return cloudKitAsset
        }

        // Check if content is in memory
        if mimeType.lowercased().hasPrefix("text/") {
            // Text content
            if let textValue = textValue {
                guard let data = textValue.data(using: .utf8) else {
                    throw TypedDataError.typeConversionFailed(
                        fromType: "String",
                        toType: "Data",
                        reason: "Failed to encode text as UTF-8"
                    )
                }
                progress?.setTotalUnitCount(Int64(data.count))
                progress?.update(completedUnits: Int64(data.count), description: "Loaded text from memory", force: true)
                return data
            }
        } else {
            // Binary content
            if let binaryValue = binaryValue {
                progress?.setTotalUnitCount(Int64(binaryValue.count))
                progress?.update(completedUnits: Int64(binaryValue.count), description: "Loaded binary from memory", force: true)
                return binaryValue
            }
        }

        // If we have a file reference, load from file
        guard let fileRef = fileReference else {
            throw TypedDataError.fileOperationFailed(
                operation: "load content",
                reason: "No content in memory and no file reference"
            )
        }

        // Load from file
        guard let storage = storageArea else {
            throw TypedDataError.fileOperationFailed(
                operation: "load content",
                reason: "File reference exists but no storage area provided"
            )
        }

        // Load file with progress reporting
        return try loadFileWithProgress(fileRef: fileRef, storage: storage, progress: progress)
    }

    /// Loads file data with progress reporting using chunked reading
    ///
    /// For large files (>1MB), reads data in 1MB chunks with progress updates.
    /// For small files, reads all data at once for efficiency.
    ///
    /// - Parameters:
    ///   - fileRef: File reference containing filename and metadata
    ///   - storage: Storage area where file is located
    ///   - progress: Optional progress tracking for file read operations
    /// - Returns: Complete file data
    /// - Throws: TypedDataError if file read fails
    private func loadFileWithProgress(
        fileRef: TypedDataFileReference,
        storage: StorageAreaReference,
        progress: OperationProgress?
    ) throws -> Data {
        let fileURL = fileRef.fileURL(in: storage)

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let fileSize = attributes[.size] as? Int64 else {
            throw TypedDataError.fileOperationFailed(
                operation: "load file",
                reason: "Could not determine file size"
            )
        }

        // Set total units
        progress?.setTotalUnitCount(fileSize)
        progress?.update(completedUnits: 0, description: "Loading \(fileRef.fileName)...")

        // Read file in chunks for large files
        let chunkSize = 1_048_576 // 1MB chunks
        if fileSize > chunkSize, let progress = progress {
            var data = Data()
            data.reserveCapacity(Int(fileSize))

            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            defer {
                try? fileHandle.close()
            }

            var bytesRead: Int64 = 0
            while bytesRead < fileSize {
                let remainingBytes = fileSize - bytesRead
                let bytesToRead = min(Int(chunkSize), Int(remainingBytes))

                if let chunk = try fileHandle.read(upToCount: bytesToRead) {
                    data.append(chunk)
                    bytesRead += Int64(chunk.count)

                    // Report progress
                    progress.update(
                        completedUnits: bytesRead,
                        description: "Loading \(fileRef.fileName)... (\(bytesRead)/\(fileSize) bytes)"
                    )

                    if chunk.count == 0 {
                        break
                    }
                } else {
                    break
                }
            }

            // Report completion
            progress.update(completedUnits: fileSize, description: "Loaded \(fileRef.fileName)", force: true)
            return data
        } else {
            // Small file: read all at once
            let data = try Data(contentsOf: fileURL)
            progress?.update(completedUnits: fileSize, description: "Loaded \(fileRef.fileName)", force: true)
            return data
        }
    }

    /// Retrieves text content (for text/* MIME types)
    ///
    /// - Parameter storageArea: Storage area for file loading
    /// - Returns: The text content
    /// - Throws: TypedDataStorageError or TypedDataError
    public func getText(from storageArea: StorageAreaReference? = nil) throws -> String {
        guard mimeType.lowercased().hasPrefix("text/") else {
            throw TypedDataStorageError.contentTypeMismatch(
                expected: "text/*",
                got: mimeType
            )
        }

        let data = try getContent(from: storageArea)
        guard let text = String(data: data, encoding: .utf8) else {
            throw TypedDataError.typeConversionFailed(
                fromType: "Data",
                toType: "String",
                reason: "Invalid UTF-8 encoding"
            )
        }

        return text
    }

    /// Retrieves binary content (for non-text MIME types)
    ///
    /// Intelligently loads content from the best available source:
    /// 1. CloudKit asset (if available) - for .cloudKit/.hybrid storage modes
    /// 2. In-memory binaryValue - for small content
    /// 3. File-based storage - via fileReference for large content
    ///
    /// Supports progress reporting for large file operations (>1MB).
    ///
    /// - Parameters:
    ///   - storageArea: Storage area for file loading (required if content is file-based)
    ///   - progress: Optional progress tracking for file I/O operations
    /// - Returns: The binary content
    /// - Throws: TypedDataStorageError or TypedDataError
    public func getBinary(from storageArea: StorageAreaReference? = nil, progress: OperationProgress? = nil) throws -> Data {
        guard !mimeType.lowercased().hasPrefix("text/") else {
            throw TypedDataStorageError.contentTypeMismatch(
                expected: "binary (image/*, audio/*, video/*, application/*)",
                got: mimeType
            )
        }

        return try getContent(from: storageArea, progress: progress)
    }

    /// Retrieves embedding vector (for application/x-embedding MIME type)
    ///
    /// - Parameter storageArea: Storage area for file loading
    /// - Returns: The embedding vector as array of Floats
    /// - Throws: TypedDataStorageError or TypedDataError
    public func getEmbedding(from storageArea: StorageAreaReference? = nil) throws -> [Float] {
        guard mimeType.lowercased() == "application/x-embedding" else {
            throw TypedDataStorageError.contentTypeMismatch(
                expected: "application/x-embedding",
                got: mimeType
            )
        }

        let data = try getBinary(from: storageArea)
        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }

    // MARK: - Helper Methods

    /// Updates the modification timestamp
    public func touch() {
        self.modifiedAt = Date()
        self.conflictVersion += 1
    }

    /// Whether this record stores content in a file
    public var isFileStored: Bool {
        fileReference != nil
    }

    /// Whether CloudKit features are enabled for this record
    public var isCloudKitEnabled: Bool {
        cloudKitRecordID != nil || storageMode != .local
    }

    /// Returns the primary content category based on MIME type
    public var contentCategory: String {
        let lowercased = mimeType.lowercased()
        if lowercased.hasPrefix("text/") {
            return "text"
        } else if lowercased.hasPrefix("image/") {
            return "image"
        } else if lowercased.hasPrefix("audio/") {
            return "audio"
        } else if lowercased.hasPrefix("video/") {
            return "video"
        } else if lowercased == "application/x-embedding" {
            return "embedding"
        }
        return "unknown"
    }

    /// File size in bytes (if content is in memory)
    public var contentSize: Int {
        if let textValue = textValue {
            return textValue.utf8.count
        } else if let binaryValue = binaryValue {
            return binaryValue.count
        } else if let fileRef = fileReference {
            return Int(fileRef.fileSize)
        }
        return 0
    }
}

// MARK: - CloudKitSyncable Conformance

extension TypedDataStorage: CloudKitSyncable {}

// MARK: - CustomStringConvertible

extension TypedDataStorage: CustomStringConvertible {
    public var description: String {
        let storage = isFileStored ? "file" : "memory"
        let sync = isCloudKitEnabled ? "cloudkit" : "local"
        let size = ByteCountFormatter.string(fromByteCount: Int64(contentSize), countStyle: .file)

        var details = ""
        switch contentCategory {
        case "text":
            if let wordCount = wordCount {
                details = ", \(wordCount) words"
            }
        case "audio":
            if let duration = durationSeconds {
                details = String(format: ", %.1fs", duration)
            }
        case "image":
            if let w = width, let h = height {
                details = ", \(w)x\(h)"
            }
        case "embedding":
            if let dim = dimensions {
                details = ", \(dim)D"
            }
        default:
            break
        }

        return "TypedDataStorage(id: \(id), type: \(contentCategory), mime: \(mimeType)\(details), size: \(size), storage: \(storage), sync: \(sync))"
    }
}
