//
//  TypedDataStorage+Convenience.swift
//  SwiftCompartido
//
//  Convenience initializers and file storage methods for TypedDataStorage
//

import Foundation

// MARK: - Convenience Initializers from DTO Types

extension TypedDataStorage {

    // MARK: - From GeneratedTextData

    /// Creates a TypedDataStorage record from GeneratedTextData
    ///
    /// - Parameters:
    ///   - id: Unique identifier (typically the request ID)
    ///   - providerId: Provider identifier
    ///   - requestorID: Requestor identifier
    ///   - data: Generated text data
    ///   - prompt: The generation prompt
    ///   - fileReference: Optional file reference for large text
    ///   - estimatedCost: Optional cost estimate
    ///   - storageMode: Storage mode (defaults to local)
    public convenience init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        data: GeneratedTextData,
        prompt: String,
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil,
        storageMode: StorageMode = .local
    ) {
        // If file reference exists, don't store text in-memory
        let textValue = fileReference == nil ? data.text : nil

        self.init(
            id: id,
            providerId: providerId,
            requestorID: requestorID,
            mimeType: "text/plain",
            textValue: textValue,
            binaryValue: nil,
            prompt: prompt,
            modelIdentifier: data.model,
            estimatedCost: estimatedCost,
            fileReference: fileReference,
            storageMode: storageMode,
            wordCount: data.wordCount,
            characterCount: data.characterCount,
            languageCode: data.languageCode,
            tokenCount: data.tokenCount,
            completionTokens: data.completionTokens,
            promptTokens: data.promptTokens
        )
    }

    // MARK: - From GeneratedAudioData

    /// Creates a TypedDataStorage record from GeneratedAudioData
    ///
    /// - Parameters:
    ///   - id: Unique identifier (typically the request ID)
    ///   - providerId: Provider identifier
    ///   - requestorID: Requestor identifier
    ///   - data: Generated audio data
    ///   - prompt: The generation prompt
    ///   - fileReference: Optional file reference for audio file
    ///   - estimatedCost: Optional cost estimate
    ///   - storageMode: Storage mode (defaults to local)
    public convenience init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        data: GeneratedAudioData,
        prompt: String,
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil,
        storageMode: StorageMode = .local
    ) {
        // If file reference exists, don't store audio data in-memory
        let binaryValue = fileReference == nil ? data.audioData : nil

        self.init(
            id: id,
            providerId: providerId,
            requestorID: requestorID,
            mimeType: data.format.mimeType,
            textValue: nil,
            binaryValue: binaryValue,
            prompt: prompt,
            modelIdentifier: data.model,
            estimatedCost: estimatedCost,
            fileReference: fileReference,
            storageMode: storageMode,
            audioFormat: data.format.rawValue,
            durationSeconds: data.durationSeconds,
            sampleRate: data.sampleRate,
            bitRate: data.bitRate,
            channels: data.channels,
            voiceID: data.voiceID,
            voiceName: data.voiceName
        )
    }

    // MARK: - From GeneratedImageData

    /// Creates a TypedDataStorage record from GeneratedImageData
    ///
    /// - Parameters:
    ///   - id: Unique identifier (typically the request ID)
    ///   - providerId: Provider identifier
    ///   - requestorID: Requestor identifier
    ///   - data: Generated image data
    ///   - prompt: The generation prompt
    ///   - fileReference: Optional file reference for image file
    ///   - estimatedCost: Optional cost estimate
    ///   - storageMode: Storage mode (defaults to local)
    public convenience init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        data: GeneratedImageData,
        prompt: String,
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil,
        storageMode: StorageMode = .local
    ) {
        // If file reference exists, don't store image data in-memory
        let binaryValue = fileReference == nil ? data.imageData : nil

        self.init(
            id: id,
            providerId: providerId,
            requestorID: requestorID,
            mimeType: data.format.mimeType,
            textValue: nil,
            binaryValue: binaryValue,
            prompt: prompt,
            modelIdentifier: data.model,
            estimatedCost: estimatedCost,
            fileReference: fileReference,
            storageMode: storageMode,
            imageFormat: data.format.rawValue,
            width: data.width,
            height: data.height,
            revisedPrompt: data.revisedPrompt
        )
    }

    // MARK: - From GeneratedEmbeddingData

    /// Creates a TypedDataStorage record from GeneratedEmbeddingData
    ///
    /// - Parameters:
    ///   - id: Unique identifier (typically the request ID)
    ///   - providerId: Provider identifier
    ///   - requestorID: Requestor identifier
    ///   - data: Generated embedding data
    ///   - prompt: The generation prompt
    ///   - fileReference: Optional file reference for embedding file
    ///   - estimatedCost: Optional cost estimate
    ///   - storageMode: Storage mode (defaults to local)
    public convenience init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        data: GeneratedEmbeddingData,
        prompt: String,
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil,
        storageMode: StorageMode = .local
    ) {
        // If file reference exists, don't store embedding data in-memory
        let binaryValue: Data?
        if fileReference == nil, let embedding = data.embedding {
            // Store embedding as binary data
            binaryValue = embedding.withUnsafeBufferPointer { buffer in
                Data(buffer: buffer)
            }
        } else {
            binaryValue = nil
        }

        self.init(
            id: id,
            providerId: providerId,
            requestorID: requestorID,
            mimeType: "application/x-embedding",
            textValue: nil,
            binaryValue: binaryValue,
            prompt: prompt,
            modelIdentifier: data.model,
            estimatedCost: estimatedCost,
            fileReference: fileReference,
            storageMode: storageMode,
            tokenCount: data.tokenCount,
            dimensions: data.dimensions,
            inputText: data.inputText,
            batchIndex: data.index
        )
    }
}

// MARK: - File Storage Methods

extension TypedDataStorage {

    // MARK: - Save Content to File

    /// Saves text content to a file in the storage area or in-memory for small text
    ///
    /// **Smart Storage Routing:**
    /// - Text < 10KB: Stored in textValue (in-memory), no storage area needed
    /// - Text ≥ 10KB: Saved to file with chunked writing for large text
    ///
    /// **CloudKit Integration:**
    /// - For .cloudKit/.hybrid modes: Small text stored in cloudKitAsset as UTF-8 data
    /// - For .cloudKit/.hybrid modes: Large text stored in cloudKitAsset from file
    /// - syncStatus automatically set to .pending for CloudKit-enabled modes
    ///
    /// - Parameters:
    ///   - text: The text to save
    ///   - to storageArea: Storage area for the file (required for text ≥ 10KB, optional for small text)
    ///   - fileName: Optional custom filename (defaults to "text.txt")
    ///   - mode: Storage mode (.local, .cloudKit, .hybrid - defaults to current storageMode)
    ///   - progress: Optional progress tracking for file write operations
    /// - Throws: TypedDataError if save fails or storage area missing for large text
    public func saveText(
        _ text: String,
        to storageArea: StorageAreaReference? = nil,
        fileName: String? = nil,
        mode: StorageMode? = nil,
        progress: OperationProgress? = nil
    ) throws {
        guard mimeType.lowercased().hasPrefix("text/") else {
            throw TypedDataStorageError.contentTypeMismatch(
                expected: "text/*",
                got: mimeType
            )
        }

        // Small text threshold: 10KB
        let smallTextThreshold = 10_000

        if text.count < smallTextThreshold {
            // Store small text in-memory
            self.textValue = text
            self.fileReference = nil

            // Update storage mode if specified
            if let mode = mode {
                self.storageMode = mode
            }

            // Handle CloudKit for in-memory text
            let effectiveMode = mode ?? self.storageMode
            if effectiveMode == .cloudKit || effectiveMode == .hybrid {
                // For CloudKit text, we can store it in cloudKitAsset as well
                if let data = text.data(using: .utf8) {
                    self.cloudKitAsset = data
                }

                // Mark as pending sync
                if self.syncStatus == .localOnly {
                    self.syncStatus = .pending
                }
            }

            touch()
            return
        }

        // Large text: save to file
        guard let storageArea = storageArea else {
            throw TypedDataError.fileOperationFailed(
                operation: "save text",
                reason: "Storage area required for text larger than \(smallTextThreshold) characters"
            )
        }

        guard let data = text.data(using: .utf8) else {
            throw TypedDataError.typeConversionFailed(
                fromType: "String",
                toType: "Data",
                reason: "Failed to encode text as UTF-8"
            )
        }

        let finalFileName = fileName ?? "text.txt"
        try saveContent(data, to: storageArea, fileName: finalFileName, mode: mode, progress: progress)
    }

    /// Saves binary content to a file in the storage area
    ///
    /// Handles complete save workflow with automatic CloudKit asset management:
    /// - Creates storage directory if needed
    /// - Writes file in chunks (1MB) for large files (>1MB) with progress
    /// - Creates TypedDataFileReference automatically
    /// - For .cloudKit/.hybrid modes: Populates cloudKitAsset and sets syncStatus = .pending
    /// - Clears in-memory binaryValue to save space (data now in file/CloudKit)
    ///
    /// - Parameters:
    ///   - data: The binary data to save
    ///   - storageArea: Storage area for the file
    ///   - fileName: Optional custom filename (auto-generated if nil based on MIME type)
    ///   - mode: Storage mode (.local, .cloudKit, .hybrid - defaults to current storageMode)
    ///   - progress: Optional progress tracking for file write and CloudKit preparation
    /// - Throws: TypedDataError if save fails
    public func saveBinary(
        _ data: Data,
        to storageArea: StorageAreaReference,
        fileName: String? = nil,
        mode: StorageMode? = nil,
        progress: OperationProgress? = nil
    ) throws {
        guard !mimeType.lowercased().hasPrefix("text/") else {
            throw TypedDataStorageError.contentTypeMismatch(
                expected: "binary (image/*, audio/*, video/*, application/*)",
                got: mimeType
            )
        }

        // Auto-generate filename based on content type if not provided
        let finalFileName = fileName ?? generateFileName()
        try saveContent(data, to: storageArea, fileName: finalFileName, mode: mode, progress: progress)
    }

    /// Saves embedding vector to a file in the storage area
    ///
    /// - Parameters:
    ///   - embedding: The embedding vector to save
    ///   - storageArea: Storage area for the file
    ///   - fileName: Optional custom filename (defaults to "embedding.bin")
    ///   - mode: Storage mode (defaults to current storageMode)
    ///   - progress: Optional progress tracking
    /// - Throws: TypedDataError if save fails
    public func saveEmbedding(
        _ embedding: [Float],
        to storageArea: StorageAreaReference,
        fileName: String? = nil,
        mode: StorageMode? = nil,
        progress: OperationProgress? = nil
    ) throws {
        guard mimeType.lowercased() == "application/x-embedding" else {
            throw TypedDataStorageError.contentTypeMismatch(
                expected: "application/x-embedding",
                got: mimeType
            )
        }

        let data = embedding.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }

        let finalFileName = fileName ?? "embedding.bin"
        try saveContent(data, to: storageArea, fileName: finalFileName, mode: mode, progress: progress)
    }

    // MARK: - Private Helper

    /// Internal method to save content and create file reference
    ///
    /// Core save implementation handling:
    /// - Directory creation
    /// - Chunked file writing (1MB chunks for >1MB files)
    /// - TypedDataFileReference creation
    /// - CloudKit asset management (.cloudKit/.hybrid modes)
    /// - In-memory content cleanup
    /// - Progress reporting
    ///
    /// - Parameters:
    ///   - data: The data to save
    ///   - storageArea: Storage area for the file
    ///   - fileName: Filename to use
    ///   - mode: Storage mode (.local, .cloudKit, .hybrid)
    ///   - progress: Optional progress tracking for file write and CloudKit preparation
    /// - Throws: TypedDataError if save fails
    private func saveContent(
        _ data: Data,
        to storageArea: StorageAreaReference,
        fileName: String,
        mode: StorageMode?,
        progress: OperationProgress?
    ) throws {
        // Determine effective storage mode
        let effectiveMode = mode ?? self.storageMode

        // Set total units for progress tracking if progress is provided
        progress?.setTotalUnitCount(Int64(data.count))

        // Create directory if needed
        try storageArea.createDirectoryIfNeeded()

        // Write file to local storage (always done for .local, .cloudKit, and .hybrid)
        let fileURL = storageArea.fileURL(for: fileName)

        // Report progress for file write
        progress?.update(completedUnits: 0, description: "Writing \(fileName)...")

        // Write file in chunks for progress reporting
        let chunkSize = 1_048_576 // 1MB chunks
        if data.count > chunkSize, let progress = progress {
            // Large file: write in chunks with progress
            try FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            let fileHandle = try FileHandle(forWritingTo: fileURL)
            defer {
                try? fileHandle.close()
            }

            var offset = 0
            while offset < data.count {
                let remainingBytes = data.count - offset
                let bytesToWrite = min(chunkSize, remainingBytes)
                let chunk = data.subdata(in: offset..<(offset + bytesToWrite))

                fileHandle.write(chunk)
                offset += bytesToWrite

                // Report progress
                progress.update(
                    completedUnits: Int64(offset),
                    description: "Writing \(fileName)... (\(offset)/\(data.count) bytes)"
                )
            }
        } else {
            // Small file: write all at once
            try data.write(to: fileURL)
        }

        // Report file write completion (force to ensure delivery)
        progress?.update(completedUnits: Int64(data.count), description: "Completed writing \(fileName)", force: true)

        // Create file reference
        let fileRef = TypedDataFileReference(
            requestID: id,
            fileName: fileName,
            fileSize: Int64(data.count),
            mimeType: mimeType
        )

        // Update record with file reference
        self.fileReference = fileRef

        // Handle CloudKit asset management based on storage mode
        if effectiveMode == .cloudKit || effectiveMode == .hybrid {
            // Store data in CloudKit asset field for sync
            self.cloudKitAsset = data

            // Mark as pending sync
            if self.syncStatus == .localOnly {
                self.syncStatus = .pending
            }

            // Report CloudKit preparation progress
            progress?.update(
                completedUnits: Int64(data.count),
                description: "Prepared CloudKit asset for sync"
            )
        }

        // Update storage mode if specified
        if let mode = mode {
            self.storageMode = mode
        }

        // Clear in-memory content to save space (now stored in file)
        // Exception: Keep cloudKitAsset for pending sync
        if mimeType.lowercased().hasPrefix("text/") {
            self.textValue = nil
        } else {
            // Only clear binaryValue if we're using CloudKit (data is in cloudKitAsset)
            // or if it's local-only (data is in file)
            if effectiveMode == .local || effectiveMode == .cloudKit || effectiveMode == .hybrid {
                self.binaryValue = nil
            }
        }

        touch()
    }

    /// Generates a filename based on content type
    private func generateFileName() -> String {
        let lowercased = mimeType.lowercased()

        if lowercased.hasPrefix("image/") {
            if let format = imageFormat {
                return "image.\(format)"
            }
            // Extract extension from MIME type
            let ext = lowercased.components(separatedBy: "/").last ?? "bin"
            return "image.\(ext)"

        } else if lowercased.hasPrefix("audio/") {
            if let format = audioFormat {
                return "audio.\(format)"
            }
            let ext = lowercased.components(separatedBy: "/").last ?? "bin"
            return "audio.\(ext)"

        } else if lowercased.hasPrefix("video/") {
            let ext = lowercased.components(separatedBy: "/").last ?? "bin"
            return "video.\(ext)"

        } else if lowercased == "application/x-embedding" {
            return "embedding.bin"
        }

        return "data.bin"
    }
}

// MARK: - Migration Note

// Migration helpers have been removed because GeneratedTextRecord, GeneratedAudioRecord,
// GeneratedImageRecord, and GeneratedEmbeddingRecord are now type aliases to TypedDataStorage.
// No migration is needed - the types are identical.
