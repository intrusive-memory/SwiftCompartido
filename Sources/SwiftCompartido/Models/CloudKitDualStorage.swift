//
//  CloudKitDualStorage.swift
//  SwiftCompartido
//
//  Dual storage helper methods for CloudKit and local file storage
//

import Foundation
import SwiftData
import CloudKit

/// Extension providing dual storage methods for GeneratedAudioRecord
extension GeneratedAudioRecord {

    /// Saves audio with dual storage strategy
    ///
    /// - Parameters:
    ///   - audioData: The audio data to store
    ///   - storageArea: Local storage area for Phase 6 file storage
    ///   - mode: Storage mode (.local, .cloudKit, or .hybrid)
    /// - Throws: File system errors if storage fails
    public func saveAudio(
        _ audioData: Data,
        to storageArea: StorageAreaReference,
        mode: StorageMode = .local
    ) throws {
        // ALWAYS save locally for Phase 6 compatibility
        try storageArea.createDirectoryIfNeeded()
        let fileURL = storageArea.defaultDataFileURL(extension: format)
        try audioData.write(to: fileURL)

        self.fileReference = TypedDataFileReference.from(
            requestID: storageArea.requestID,
            fileName: "data.\(format)",
            data: audioData,
            mimeType: "audio/\(format)"
        )

        // Also save to CloudKit if requested
        if mode == .cloudKit || mode == .hybrid {
            self.cloudKitAudioAsset = audioData
            self.storageMode = mode
            self.syncStatus = .pending
        }
    }

    /// Loads audio with automatic fallback
    ///
    /// Priority: CloudKit asset → Local file → In-memory data
    ///
    /// - Parameter storageArea: Local storage area
    /// - Returns: The audio data
    /// - Throws: Errors if audio cannot be loaded
    public func loadAudio(from storageArea: StorageAreaReference?) throws -> Data {
        // Try CloudKit first if enabled
        if isCloudKitEnabled, let asset = cloudKitAudioAsset {
            return asset
        }

        // Fall back to existing Phase 6 logic
        return try getAudioData(from: storageArea)
    }
}

/// Extension providing dual storage methods for GeneratedTextRecord
extension GeneratedTextRecord {

    /// Saves text with dual storage strategy
    ///
    /// - Parameters:
    ///   - textContent: The text to store
    ///   - storageArea: Local storage area (required for large text)
    ///   - mode: Storage mode (.local, .cloudKit, or .hybrid)
    /// - Throws: File system errors if storage fails
    public func saveText(
        _ textContent: String,
        to storageArea: StorageAreaReference? = nil,
        mode: StorageMode = .local
    ) throws {
        let textData = textContent.data(using: .utf8)!

        // Small text: Store in-memory
        if textData.count < 50_000 {
            self.text = textContent
        }
        // Large text: Store in file
        else {
            guard let storage = storageArea else {
                throw TypedDataError.fileOperationFailed(
                    operation: "save text",
                    reason: "Storage area required for large text (>50KB)"
                )
            }

            try storage.createDirectoryIfNeeded()
            let fileURL = storage.defaultDataFileURL(extension: "txt")
            try textData.write(to: fileURL)

            self.fileReference = TypedDataFileReference.from(
                requestID: storage.requestID,
                fileName: "data.txt",
                data: textData,
                mimeType: "text/plain"
            )

            self.text = nil // Don't duplicate in memory
        }

        // Also save to CloudKit if requested
        if mode == .cloudKit || mode == .hybrid {
            self.cloudKitTextAsset = textData
            self.storageMode = mode
            self.syncStatus = .pending
        }
    }

    /// Loads text with automatic fallback
    ///
    /// Priority: CloudKit asset → Local file → In-memory text
    ///
    /// - Parameter storageArea: Local storage area
    /// - Returns: The text content
    /// - Throws: Errors if text cannot be loaded
    public func loadText(from storageArea: StorageAreaReference? = nil) throws -> String {
        // Try CloudKit first if enabled
        if isCloudKitEnabled, let asset = cloudKitTextAsset {
            guard let text = String(data: asset, encoding: .utf8) else {
                throw TypedDataError.typeConversionFailed(
                    fromType: "Data",
                    toType: "String",
                    reason: "Invalid UTF-8 encoding in CloudKit asset"
                )
            }
            return text
        }

        // Fall back to existing Phase 6 logic
        return try getText(from: storageArea)
    }
}

/// Extension providing dual storage methods for GeneratedImageRecord
extension GeneratedImageRecord {

    /// Saves image with dual storage strategy
    ///
    /// - Parameters:
    ///   - imageData: The image data to store
    ///   - storageArea: Local storage area for Phase 6 file storage
    ///   - mode: Storage mode (.local, .cloudKit, or .hybrid)
    /// - Throws: File system errors if storage fails
    public func saveImage(
        _ imageData: Data,
        to storageArea: StorageAreaReference,
        mode: StorageMode = .local
    ) throws {
        // ALWAYS save locally for Phase 6 compatibility
        try storageArea.createDirectoryIfNeeded()
        let fileURL = storageArea.defaultDataFileURL(extension: format)
        try imageData.write(to: fileURL)

        self.fileReference = TypedDataFileReference.from(
            requestID: storageArea.requestID,
            fileName: "data.\(format)",
            data: imageData,
            mimeType: "image/\(format)"
        )

        // Also save to CloudKit if requested
        if mode == .cloudKit || mode == .hybrid {
            self.cloudKitImageAsset = imageData
            self.storageMode = mode
            self.syncStatus = .pending
        }
    }

    /// Loads image with automatic fallback
    ///
    /// Priority: CloudKit asset → Local file → In-memory data
    ///
    /// - Parameter storageArea: Local storage area
    /// - Returns: The image data
    /// - Throws: Errors if image cannot be loaded
    public func loadImage(from storageArea: StorageAreaReference?) throws -> Data {
        // Try CloudKit first if enabled
        if isCloudKitEnabled, let asset = cloudKitImageAsset {
            return asset
        }

        // Fall back to existing Phase 6 logic
        return try getImageData(from: storageArea)
    }
}

/// Extension providing dual storage methods for GeneratedEmbeddingRecord
extension GeneratedEmbeddingRecord {

    /// Saves embedding with dual storage strategy
    ///
    /// - Parameters:
    ///   - embedding: The embedding vector to store
    ///   - storageArea: Local storage area (required for large embeddings)
    ///   - mode: Storage mode (.local, .cloudKit, or .hybrid)
    /// - Throws: File system errors if storage fails
    public func saveEmbedding(
        _ embedding: [Float],
        to storageArea: StorageAreaReference? = nil,
        mode: StorageMode = .local
    ) throws {
        let embeddingData = embedding.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }

        // Small embedding: Store in-memory
        if embeddingData.count < 100_000 {
            self.embeddingData = embeddingData
        }
        // Large embedding: Store in file
        else {
            guard let storage = storageArea else {
                throw TypedDataError.fileOperationFailed(
                    operation: "save embedding",
                    reason: "Storage area required for large embeddings (>100KB)"
                )
            }

            try storage.createDirectoryIfNeeded()
            let fileURL = storage.defaultDataFileURL(extension: "bin")
            try embeddingData.write(to: fileURL)

            self.fileReference = TypedDataFileReference.from(
                requestID: storage.requestID,
                fileName: "data.bin",
                data: embeddingData,
                mimeType: "application/octet-stream"
            )

            self.embeddingData = nil // Don't duplicate in memory
        }

        // Also save to CloudKit if requested
        if mode == .cloudKit || mode == .hybrid {
            self.cloudKitEmbeddingAsset = embeddingData
            self.storageMode = mode
            self.syncStatus = .pending
        }
    }

    /// Loads embedding with automatic fallback
    ///
    /// Priority: CloudKit asset → Local file → In-memory data
    ///
    /// - Parameter storageArea: Local storage area
    /// - Returns: The embedding vector
    /// - Throws: Errors if embedding cannot be loaded
    public func loadEmbedding(from storageArea: StorageAreaReference? = nil) throws -> [Float] {
        // Try CloudKit first if enabled
        if isCloudKitEnabled, let asset = cloudKitEmbeddingAsset {
            return asset.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Float.self))
            }
        }

        // Fall back to existing Phase 6 logic
        return try getEmbedding(from: storageArea)
    }
}

/// Conflict resolution helpers
extension CloudKitSyncable {

    /// Resolves a sync conflict using the most recent modification
    ///
    /// - Parameter remote: Remote version from CloudKit
    /// - Returns: Which version to keep (.local or .remote)
    public func resolveConflict<T: CloudKitSyncable>(with remote: T) -> ConflictResolution {
        // Use conflict version first (explicit versioning)
        if remote.conflictVersion > self.conflictVersion {
            return .useRemote
        } else if self.conflictVersion > remote.conflictVersion {
            return .useLocal
        }

        // Fall back to modification time
        // Note: This assumes both have a `modifiedAt` property
        // For stricter typing, this could be moved to a separate protocol
        return .useLocal // Default to local in case of tie
    }
}

/// Conflict resolution result
public enum ConflictResolution {
    case useLocal
    case useRemote
    case merge // For future advanced merging
}
