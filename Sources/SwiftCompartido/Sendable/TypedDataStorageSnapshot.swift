//
//  TypedDataStorageSnapshot.swift
//  SwiftCompartido
//
//  Codable snapshot type for AI-generated content (Phase 1: .guion JSON format)
//

import Foundation

/// Codable snapshot representing AI-generated content.
///
/// This snapshot consolidates all types of AI-generated content (text, audio,
/// images, embeddings, video) into a single flexible Codable structure suitable
/// for JSON serialization in .guion files.
///
/// ## Overview
///
/// Content is routed to the appropriate storage field based on MIME type:
/// - `text/*` → Stored in `textValue` field
/// - `image/*` → Stored in `binaryValue` field (base64 encoded in JSON)
/// - `audio/*` → Stored in `binaryValue` field (base64 encoded in JSON)
/// - `video/*` → Stored in `binaryValue` field (base64 encoded in JSON)
/// - `application/x-embedding` → Stored in `binaryValue` field (base64 encoded in JSON)
///
/// ## Example - Text Content
///
/// ```swift
/// let textSnapshot = TypedDataStorageSnapshot(
///     id: UUID(),
///     providerId: "openai",
///     requestorID: "gpt-4",
///     mimeType: "text/plain",
///     prompt: "Generate a summary",
///     textValue: "Generated text",
///     wordCount: 2,
///     characterCount: 14
/// )
/// ```
///
/// ## Example - Audio Content
///
/// ```swift
/// let audioSnapshot = TypedDataStorageSnapshot(
///     id: UUID(),
///     providerId: "elevenlabs",
///     requestorID: "tts.rachel",
///     mimeType: "audio/mpeg",
///     prompt: "Generate speech",
///     binaryValue: audioData,
///     durationSeconds: 5.5,
///     voiceID: "rachel",
///     voiceName: "Rachel"
/// )
/// ```
///
/// ## Topics
///
/// ### Creating Storage
/// - ``init(id:providerId:requestorID:mimeType:prompt:textValue:binaryValue:modelIdentifier:estimatedCost:wordCount:characterCount:languageCode:tokenCount:completionTokens:promptTokens:audioFormat:durationSeconds:sampleRate:bitRate:channels:voiceID:voiceName:imageFormat:width:height:revisedPrompt:dimensions:inputText:batchIndex:generatedAt:modifiedAt:)``
///
/// ### Identity
/// - ``id``
/// - ``providerId``
/// - ``requestorID``
///
/// ### Content Storage
/// - ``textValue``
/// - ``binaryValue``
/// - ``mimeType``
/// - ``prompt``
/// - ``modelIdentifier``
/// - ``estimatedCost``
///
/// ### Text Metadata
/// - ``wordCount``
/// - ``characterCount``
/// - ``languageCode``
/// - ``tokenCount``
/// - ``completionTokens``
/// - ``promptTokens``
///
/// ### Audio Metadata
/// - ``audioFormat``
/// - ``durationSeconds``
/// - ``sampleRate``
/// - ``bitRate``
/// - ``channels``
/// - ``voiceID``
/// - ``voiceName``
///
/// ### Image Metadata
/// - ``imageFormat``
/// - ``width``
/// - ``height``
/// - ``revisedPrompt``
///
/// ### Embedding Metadata
/// - ``dimensions``
/// - ``inputText``
/// - ``batchIndex``
///
/// ### Timestamps
/// - ``generatedAt``
/// - ``modifiedAt``
public struct TypedDataStorageSnapshot: Codable, Identifiable, Sendable, Hashable {

  // MARK: - Identity

  /// Unique identifier (matches request ID)
  public var id: UUID

  /// Provider that generated this content
  public var providerId: String

  /// Specific requestor that generated this content
  public var requestorID: String

  // MARK: - Content Storage

  /// Text content storage (for text/* MIME types)
  ///
  /// Used when mimeType starts with "text/".
  /// For large text, consider file-based storage in future phases.
  public var textValue: String?

  /// Binary content storage (for image/*, audio/*, video/*, application/* MIME types)
  ///
  /// Used for all non-text content types.
  /// **Note**: Binary data is base64-encoded when serialized to JSON.
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

  // MARK: - Text-specific Metadata

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

  // MARK: - Audio-specific Metadata

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

  // MARK: - Image-specific Metadata

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

  // MARK: - Embedding-specific Metadata

  /// Number of dimensions in the embedding
  public var dimensions: Int?

  /// The input text that was embedded
  ///
  /// Truncated to 1000 characters for storage efficiency.
  public var inputText: String?

  /// Index in batch (if part of batch request)
  public var batchIndex: Int?

  // MARK: - Timestamps

  /// When this content was generated
  public var generatedAt: Date

  /// When this record was last modified
  public var modifiedAt: Date

  // MARK: - Initialization

  /// Initialize a new typed data storage snapshot
  public init(
    id: UUID = UUID(),
    providerId: String,
    requestorID: String,
    mimeType: String,
    prompt: String,
    textValue: String? = nil,
    binaryValue: Data? = nil,
    modelIdentifier: String? = nil,
    estimatedCost: Double? = nil,
    wordCount: Int? = nil,
    characterCount: Int? = nil,
    languageCode: String? = nil,
    tokenCount: Int? = nil,
    completionTokens: Int? = nil,
    promptTokens: Int? = nil,
    audioFormat: String? = nil,
    durationSeconds: Double? = nil,
    sampleRate: Int? = nil,
    bitRate: Int? = nil,
    channels: Int? = nil,
    voiceID: String? = nil,
    voiceName: String? = nil,
    imageFormat: String? = nil,
    width: Int? = nil,
    height: Int? = nil,
    revisedPrompt: String? = nil,
    dimensions: Int? = nil,
    inputText: String? = nil,
    batchIndex: Int? = nil,
    generatedAt: Date = Date(),
    modifiedAt: Date = Date()
  ) {
    self.id = id
    self.providerId = providerId
    self.requestorID = requestorID
    self.mimeType = mimeType
    self.prompt = prompt
    self.textValue = textValue
    self.binaryValue = binaryValue
    self.modelIdentifier = modelIdentifier
    self.estimatedCost = estimatedCost
    self.wordCount = wordCount
    self.characterCount = characterCount
    self.languageCode = languageCode
    self.tokenCount = tokenCount
    self.completionTokens = completionTokens
    self.promptTokens = promptTokens
    self.audioFormat = audioFormat
    self.durationSeconds = durationSeconds
    self.sampleRate = sampleRate
    self.bitRate = bitRate
    self.channels = channels
    self.voiceID = voiceID
    self.voiceName = voiceName
    self.imageFormat = imageFormat
    self.width = width
    self.height = height
    self.revisedPrompt = revisedPrompt
    self.dimensions = dimensions
    self.inputText = inputText
    self.batchIndex = batchIndex
    self.generatedAt = generatedAt
    self.modifiedAt = modifiedAt
  }
}

// MARK: - Convenience Initializers

extension TypedDataStorageSnapshot {
  /// Create a snapshot from audio data
  ///
  /// Convenience initializer for audio content with common metadata.
  ///
  /// - Parameters:
  ///   - audioData: Audio file data
  ///   - mimeType: Audio MIME type (e.g., "audio/mpeg")
  ///   - duration: Duration in seconds
  ///   - voiceID: Voice identifier
  ///   - voiceName: Human-readable voice name
  ///   - providerId: Provider ID (e.g., "elevenlabs", "macos")
  ///   - requestorID: Requestor ID
  ///   - prompt: Original prompt
  /// - Returns: Configured snapshot
  public init(
    audioData: Data,
    mimeType: String = "audio/mpeg",
    duration: Double,
    voiceID: String? = nil,
    voiceName: String? = nil,
    providerId: String,
    requestorID: String,
    prompt: String
  ) {
    self.init(
      providerId: providerId,
      requestorID: requestorID,
      mimeType: mimeType,
      prompt: prompt,
      binaryValue: audioData,
      durationSeconds: duration,
      voiceID: voiceID,
      voiceName: voiceName
    )
  }
}
