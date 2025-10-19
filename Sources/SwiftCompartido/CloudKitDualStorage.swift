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

    /// Saves audio with dual storage strategy and progress reporting
    ///
    /// Writes audio in 1MB chunks with progress updates for each chunk.
    /// Supports cancellation with automatic cleanup of partial files.
    ///
    /// - Parameters:
    ///   - audioData: The audio data to store
    ///   - storageArea: Local storage area for Phase 6 file storage
    ///   - mode: Storage mode (.local, .cloudKit, or .hybrid)
    ///   - progress: Optional progress tracker for byte-level progress
    ///
    /// - Throws: File system errors or CancellationError if cancelled
    ///
    /// ## Usage
    /// ```swift
    /// let progress = OperationProgress(totalUnits: Int64(audioData.count)) { update in
    ///     print("Saving: \\(update.description) - \\(Int((update.fractionCompleted ?? 0) * 100))%")
    /// }
    ///
    /// try await record.saveAudio(audioData, to: storage, mode: .local, progress: progress)
    /// ```
    public func saveAudio(
        _ audioData: Data,
        to storageArea: StorageAreaReference,
        mode: StorageMode = .local,
        progress: OperationProgress?
    ) async throws {
        let chunkSize = 1024 * 1024 // 1MB chunks
        let totalBytes = Int64(audioData.count)

        // Set total units to byte count
        progress?.setTotalUnitCount(totalBytes)
        progress?.update(completedUnits: 0, description: "Preparing to save audio...")

        // Check cancellation before starting
        try Task.checkCancellation()

        // Create directory
        try storageArea.createDirectoryIfNeeded()
        let fileURL = storageArea.defaultDataFileURL(extension: format)

        // Write in chunks with progress
        do {
            // Create output stream for chunked writing
            guard let outputStream = OutputStream(url: fileURL, append: false) else {
                throw TypedDataError.fileOperationFailed(
                    operation: "save audio",
                    reason: "Could not create output stream"
                )
            }

            outputStream.open()
            defer {
                outputStream.close()
            }

            var bytesWritten: Int64 = 0
            var offset = 0

            // Capture progress to ensure it's used correctly in loop
            let progressTracker = progress

            while offset < audioData.count {
                // Check cancellation before each chunk
                try Task.checkCancellation()

                let remainingBytes = audioData.count - offset
                let currentChunkSize = min(chunkSize, remainingBytes)
                let chunk = audioData.subdata(in: offset..<(offset + currentChunkSize))

                chunk.withUnsafeBytes { buffer in
                    guard let baseAddress = buffer.baseAddress else { return }
                    outputStream.write(baseAddress.assumingMemoryBound(to: UInt8.self), maxLength: currentChunkSize)
                }

                offset += currentChunkSize
                bytesWritten += Int64(currentChunkSize)

                // Update progress after each chunk
                let description = "Writing audio data (\(bytesWritten) / \(totalBytes) bytes)..."
                progressTracker?.update(completedUnits: bytesWritten, description: description)

                // Small delay to allow progress updates to propagate
                try? await Task.sleep(for: .milliseconds(1))
            }

            // Create file reference
            self.fileReference = TypedDataFileReference.from(
                requestID: storageArea.requestID,
                fileName: "data.\(format)",
                data: audioData,
                mimeType: "audio/\(format)"
            )

            // CloudKit storage if requested
            if mode == .cloudKit || mode == .hybrid {
                self.cloudKitAudioAsset = audioData
                self.storageMode = mode
                self.syncStatus = .pending
                progress?.update(completedUnits: totalBytes, description: "Preparing CloudKit upload...")
                try? await Task.sleep(for: .milliseconds(1))
            }

            progress?.complete(description: "Audio saved successfully")

        } catch is CancellationError {
            // Clean up partial file on cancellation
            try? FileManager.default.removeItem(at: fileURL)
            throw CancellationError()
        } catch {
            // Clean up partial file on error
            try? FileManager.default.removeItem(at: fileURL)
            throw error
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

    /// Loads audio with automatic fallback and progress reporting
    ///
    /// Priority: CloudKit asset → Local file → In-memory data
    /// Reads file in 1MB chunks with progress updates.
    ///
    /// - Parameters:
    ///   - storageArea: Local storage area
    ///   - progress: Optional progress tracker for byte-level progress
    ///
    /// - Returns: The audio data
    /// - Throws: Errors if audio cannot be loaded or CancellationError if cancelled
    public func loadAudio(
        from storageArea: StorageAreaReference?,
        progress: OperationProgress?
    ) async throws -> Data {
        // Try CloudKit first if enabled
        if isCloudKitEnabled, let asset = cloudKitAudioAsset {
            progress?.setTotalUnitCount(Int64(asset.count))
            progress?.complete(description: "Loaded audio from CloudKit")
            return asset
        }

        // Check if audio is in memory
        if let audioData = audioData {
            progress?.setTotalUnitCount(Int64(audioData.count))
            progress?.complete(description: "Loaded audio from memory")
            return audioData
        }

        // Load from file with progress
        guard let fileRef = fileReference, let storage = storageArea else {
            throw TypedDataError.fileOperationFailed(
                operation: "load audio",
                reason: "No audio data and no file reference"
            )
        }

        let fileURL = storage.fileURL(for: fileRef.fileName)
        let chunkSize = 1024 * 1024 // 1MB chunks

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let fileSize = attributes[.size] as? Int64 else {
            throw TypedDataError.fileOperationFailed(
                operation: "load audio",
                reason: "Could not determine file size"
            )
        }

        progress?.setTotalUnitCount(fileSize)
        progress?.update(completedUnits: 0, description: "Reading audio file...")

        // Read in chunks
        guard let inputStream = InputStream(url: fileURL) else {
            throw TypedDataError.fileOperationFailed(
                operation: "load audio",
                reason: "Could not create input stream"
            )
        }

        inputStream.open()
        defer {
            inputStream.close()
        }

        var result = Data()
        var bytesRead: Int64 = 0
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer {
            buffer.deallocate()
        }

        while inputStream.hasBytesAvailable {
            // Check cancellation
            try Task.checkCancellation()

            let read = inputStream.read(buffer, maxLength: chunkSize)
            if read > 0 {
                result.append(buffer, count: read)
                bytesRead += Int64(read)

                let description = "Reading audio data (\(bytesRead) / \(fileSize) bytes)..."
                progress?.update(completedUnits: bytesRead, description: description)
            } else if read < 0 {
                throw TypedDataError.fileOperationFailed(
                    operation: "load audio",
                    reason: "Stream read error"
                )
            }
        }

        progress?.complete(description: "Audio loaded successfully")
        return result
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

    /// Saves image with dual storage strategy and progress reporting
    ///
    /// Writes image in 1MB chunks with progress updates for each chunk.
    /// Supports cancellation with automatic cleanup of partial files.
    ///
    /// - Parameters:
    ///   - imageData: The image data to store
    ///   - storageArea: Local storage area for Phase 6 file storage
    ///   - mode: Storage mode (.local, .cloudKit, or .hybrid)
    ///   - progress: Optional progress tracker for byte-level progress
    ///
    /// - Throws: File system errors or CancellationError if cancelled
    ///
    /// ## Usage
    /// ```swift
    /// let progress = OperationProgress(totalUnits: Int64(imageData.count)) { update in
    ///     print("Saving: \\(update.description) - \\(Int((update.fractionCompleted ?? 0) * 100))%")
    /// }
    ///
    /// try await record.saveImage(imageData, to: storage, mode: .local, progress: progress)
    /// ```
    public func saveImage(
        _ imageData: Data,
        to storageArea: StorageAreaReference,
        mode: StorageMode = .local,
        progress: OperationProgress?
    ) async throws {
        let chunkSize = 1024 * 1024 // 1MB chunks
        let totalBytes = Int64(imageData.count)

        // Set total units to byte count
        progress?.setTotalUnitCount(totalBytes)
        progress?.update(completedUnits: 0, description: "Preparing to save image...")

        // Check cancellation before starting
        try Task.checkCancellation()

        // Create directory
        try storageArea.createDirectoryIfNeeded()
        let fileURL = storageArea.defaultDataFileURL(extension: format)

        // Write in chunks with progress
        do {
            // Create output stream for chunked writing
            guard let outputStream = OutputStream(url: fileURL, append: false) else {
                throw TypedDataError.fileOperationFailed(
                    operation: "save image",
                    reason: "Could not create output stream"
                )
            }

            outputStream.open()
            defer {
                outputStream.close()
            }

            var bytesWritten: Int64 = 0
            var offset = 0

            while offset < imageData.count {
                // Check cancellation before each chunk
                try Task.checkCancellation()

                let remainingBytes = imageData.count - offset
                let currentChunkSize = min(chunkSize, remainingBytes)
                let chunk = imageData.subdata(in: offset..<(offset + currentChunkSize))

                chunk.withUnsafeBytes { buffer in
                    guard let baseAddress = buffer.baseAddress else { return }
                    outputStream.write(baseAddress.assumingMemoryBound(to: UInt8.self), maxLength: currentChunkSize)
                }

                offset += currentChunkSize
                bytesWritten += Int64(currentChunkSize)

                // Update progress after each chunk
                let description = "Writing image data (\(bytesWritten) / \(totalBytes) bytes)..."
                progress?.update(completedUnits: bytesWritten, description: description)

                // Small delay to allow progress updates to propagate
                try? await Task.sleep(for: .milliseconds(1))
            }

            // Create file reference
            self.fileReference = TypedDataFileReference.from(
                requestID: storageArea.requestID,
                fileName: "data.\(format)",
                data: imageData,
                mimeType: "image/\(format)"
            )

            // CloudKit storage if requested
            if mode == .cloudKit || mode == .hybrid {
                self.cloudKitImageAsset = imageData
                self.storageMode = mode
                self.syncStatus = .pending
                progress?.update(completedUnits: totalBytes, description: "Preparing CloudKit upload...")
                try? await Task.sleep(for: .milliseconds(1))
            }

            progress?.complete(description: "Image saved successfully")

        } catch is CancellationError {
            // Clean up partial file on cancellation
            try? FileManager.default.removeItem(at: fileURL)
            throw CancellationError()
        } catch {
            // Clean up partial file on error
            try? FileManager.default.removeItem(at: fileURL)
            throw error
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

    /// Loads image with automatic fallback and progress reporting
    ///
    /// Priority: CloudKit asset → Local file → In-memory data
    /// Reads file in 1MB chunks with progress updates.
    ///
    /// - Parameters:
    ///   - storageArea: Local storage area
    ///   - progress: Optional progress tracker for byte-level progress
    ///
    /// - Returns: The image data
    /// - Throws: Errors if image cannot be loaded or CancellationError if cancelled
    public func loadImage(
        from storageArea: StorageAreaReference?,
        progress: OperationProgress?
    ) async throws -> Data {
        // Try CloudKit first if enabled
        if isCloudKitEnabled, let asset = cloudKitImageAsset {
            progress?.setTotalUnitCount(Int64(asset.count))
            progress?.complete(description: "Loaded image from CloudKit")
            return asset
        }

        // Check if image is in memory
        if let imageData = imageData {
            progress?.setTotalUnitCount(Int64(imageData.count))
            progress?.complete(description: "Loaded image from memory")
            return imageData
        }

        // Load from file with progress
        guard let fileRef = fileReference, let storage = storageArea else {
            throw TypedDataError.fileOperationFailed(
                operation: "load image",
                reason: "No image data and no file reference"
            )
        }

        let fileURL = storage.fileURL(for: fileRef.fileName)
        let chunkSize = 1024 * 1024 // 1MB chunks

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let fileSize = attributes[.size] as? Int64 else {
            throw TypedDataError.fileOperationFailed(
                operation: "load image",
                reason: "Could not determine file size"
            )
        }

        progress?.setTotalUnitCount(fileSize)
        progress?.update(completedUnits: 0, description: "Reading image file...")

        // Read in chunks
        guard let inputStream = InputStream(url: fileURL) else {
            throw TypedDataError.fileOperationFailed(
                operation: "load image",
                reason: "Could not create input stream"
            )
        }

        inputStream.open()
        defer {
            inputStream.close()
        }

        var result = Data()
        var bytesRead: Int64 = 0
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer {
            buffer.deallocate()
        }

        while inputStream.hasBytesAvailable {
            // Check cancellation
            try Task.checkCancellation()

            let read = inputStream.read(buffer, maxLength: chunkSize)
            if read > 0 {
                result.append(buffer, count: read)
                bytesRead += Int64(read)

                let description = "Reading image data (\(bytesRead) / \(fileSize) bytes)..."
                progress?.update(completedUnits: bytesRead, description: description)
            } else if read < 0 {
                throw TypedDataError.fileOperationFailed(
                    operation: "load image",
                    reason: "Stream read error"
                )
            }
        }

        progress?.complete(description: "Image loaded successfully")
        return result
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

    /// Resolves a sync conflict using version numbers and modification timestamps
    ///
    /// Strategy:
    /// 1. If conflict versions differ, use the higher version (explicit versioning wins)
    /// 2. If versions are equal, use the most recently modified record
    /// 3. If timestamps are equal (rare), prefer local to avoid unnecessary sync
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

        // Versions are equal - compare modification timestamps
        // This handles the critical case where both records start at version 1
        if remote.modifiedAt > self.modifiedAt {
            return .useRemote
        } else if self.modifiedAt > remote.modifiedAt {
            return .useLocal
        }

        // Timestamps exactly equal (extremely rare) - prefer local to avoid sync churn
        return .useLocal
    }
}

/// Conflict resolution result
public enum ConflictResolution {
    case useLocal
    case useRemote
    case merge // For future advanced merging
}
