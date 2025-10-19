//
//  GeneratedTextRecord.swift
//  SwiftHablare
//
//  Phase 6B: SwiftData model for generated text
//

import Foundation
import SwiftData
import CloudKit

/// SwiftData model for storing generated text with file reference support.
///
/// This model follows the Phase 6 pattern where small text is stored directly
/// in the model, and large text can be stored in .guion bundle files with
/// a file reference.
///
/// ## Storage Strategy
/// - **Small text** (< 50KB): Stored in `text` property
/// - **Large text** (>= 50KB): Stored in file, referenced by `fileReference`
///
/// ## Example
/// ```swift
/// let record = GeneratedTextRecord(
///     id: requestID,
///     providerId: "openai",
///     requestorID: "openai.text.gpt4",
///     text: generatedText,
///     wordCount: 150,
///     characterCount: 750,
///     languageCode: "en",
///     modelIdentifier: "gpt-4"
/// )
/// modelContext.insert(record)
/// ```
@Model
public final class GeneratedTextRecord {

    // MARK: - Identity

    /// Unique identifier (matches request ID)
    @Attribute(.unique) public var id: UUID

    /// Provider that generated this text
    public var providerId: String

    /// Specific requestor that generated this text
    public var requestorID: String

    // MARK: - Content

    /// The generated text content (if stored in-memory)
    ///
    /// For small text (<50KB), this contains the actual text.
    /// For large text (>=50KB), this is nil and text is in file.
    public var text: String?

    /// Word count
    public var wordCount: Int

    /// Character count
    public var characterCount: Int

    /// Language code (e.g., "en", "es")
    public var languageCode: String?

    // MARK: - Generation Metadata

    /// Model identifier that generated this text
    public var modelIdentifier: String?

    /// Total token count
    public var tokenCount: Int?

    /// Completion tokens used
    public var completionTokens: Int?

    /// Prompt tokens used
    public var promptTokens: Int?

    /// The prompt used to generate this text
    public var prompt: String

    // MARK: - File Reference

    /// Reference to file if text is stored externally
    ///
    /// When text is large, it's written to a .guion bundle file
    /// and this property stores the reference for retrieval.
    /// SwiftData handles Codable types automatically.
    public var fileReference: TypedDataFileReference?

    // MARK: - Timestamps

    /// When this text was generated
    public var generatedAt: Date

    /// When this record was last modified
    public var modifiedAt: Date

    // MARK: - Estimated Cost

    /// Estimated cost in USD (if available)
    public var estimatedCost: Double?

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

    /// CloudKit asset for large text files (when using CloudKit storage)
    @Attribute(.externalStorage)
    public var cloudKitTextAsset: Data?

    // MARK: - Initialization

    /// Creates a generated text record
    ///
    /// - Parameters:
    ///   - id: Unique identifier (typically the request ID)
    ///   - providerId: Provider identifier
    ///   - requestorID: Specific requestor identifier
    ///   - text: Generated text (nil if stored in file)
    ///   - wordCount: Number of words
    ///   - characterCount: Number of characters
    ///   - languageCode: Language code (optional)
    ///   - modelIdentifier: Model identifier (optional)
    ///   - tokenCount: Total token count (optional)
    ///   - completionTokens: Completion tokens (optional)
    ///   - promptTokens: Prompt tokens (optional)
    ///   - prompt: The generation prompt
    ///   - fileReference: File reference (optional)
    ///   - estimatedCost: Estimated cost (optional)
    ///   - storageMode: Storage mode (defaults to local)
    public init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        text: String?,
        wordCount: Int,
        characterCount: Int,
        languageCode: String? = nil,
        modelIdentifier: String? = nil,
        tokenCount: Int? = nil,
        completionTokens: Int? = nil,
        promptTokens: Int? = nil,
        prompt: String = "",
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil,
        storageMode: StorageMode = .local
    ) {
        self.id = id
        self.providerId = providerId
        self.requestorID = requestorID
        self.text = text
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.languageCode = languageCode
        self.modelIdentifier = modelIdentifier
        self.tokenCount = tokenCount
        self.completionTokens = completionTokens
        self.promptTokens = promptTokens
        self.prompt = prompt
        self.fileReference = fileReference
        self.estimatedCost = estimatedCost
        self.generatedAt = Date()
        self.modifiedAt = Date()

        // CloudKit defaults
        self.cloudKitRecordID = nil
        self.cloudKitChangeTag = nil
        self.lastSyncedAt = nil
        self.syncStatus = storageMode == .local ? .localOnly : .pending
        self.ownerUserRecordID = nil
        self.sharedWith = nil
        self.conflictVersion = 1
        self.storageMode = storageMode
        self.cloudKitTextAsset = nil
    }

    // MARK: - Convenience Initializer from TypedData

    /// Creates a record from typed data
    ///
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - providerId: Provider identifier
    ///   - requestorID: Requestor identifier
    ///   - data: Generated text data
    ///   - prompt: The generation prompt
    ///   - fileReference: Optional file reference
    ///   - estimatedCost: Optional cost estimate
    public convenience init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        data: GeneratedTextData,
        prompt: String,
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil
    ) {
        // If file reference exists, don't store text in-memory
        let text = fileReference == nil ? data.text : nil

        self.init(
            id: id,
            providerId: providerId,
            requestorID: requestorID,
            text: text,
            wordCount: data.wordCount,
            characterCount: data.characterCount,
            languageCode: data.languageCode,
            modelIdentifier: data.model,
            tokenCount: data.tokenCount,
            completionTokens: data.completionTokens,
            promptTokens: data.promptTokens,
            prompt: prompt,
            fileReference: fileReference,
            estimatedCost: estimatedCost
        )
    }

    // MARK: - Helper Methods

    /// Updates the modification timestamp
    public func touch() {
        self.modifiedAt = Date()
    }

    /// Returns the text content, loading from file if necessary
    ///
    /// - Parameter storageArea: Storage area for file loading
    /// - Returns: The text content
    /// - Throws: File errors if text is in file and cannot be loaded
    public func getText(from storageArea: StorageAreaReference? = nil) throws -> String {
        // If text is in memory, return it
        if let text = text {
            return text
        }

        // If we have a file reference, load from file
        guard let fileRef = fileReference else {
            throw TypedDataError.fileOperationFailed(
                operation: "load text",
                reason: "No text content and no file reference"
            )
        }

        // Load from file
        guard let storage = storageArea else {
            throw TypedDataError.fileOperationFailed(
                operation: "load text",
                reason: "File reference exists but no storage area provided"
            )
        }

        let data = try fileRef.readData(from: storage)
        guard let textContent = String(data: data, encoding: .utf8) else {
            throw TypedDataError.typeConversionFailed(
                fromType: "Data",
                toType: "String",
                reason: "Invalid UTF-8 encoding"
            )
        }

        return textContent
    }

    /// Whether this record stores text in a file
    public var isFileStored: Bool {
        fileReference != nil
    }

    /// Whether CloudKit features are enabled for this record
    public var isCloudKitEnabled: Bool {
        cloudKitRecordID != nil || storageMode != .local
    }
}

// MARK: - CloudKitSyncable Conformance

extension GeneratedTextRecord: CloudKitSyncable {}

// MARK: - CustomStringConvertible

extension GeneratedTextRecord: CustomStringConvertible {
    public var description: String {
        let storage = isFileStored ? "file" : "memory"
        let sync = isCloudKitEnabled ? "cloudkit" : "local"
        return "GeneratedTextRecord(id: \(id), provider: \(providerId), \(wordCount) words, storage: \(storage), sync: \(sync))"
    }
}
