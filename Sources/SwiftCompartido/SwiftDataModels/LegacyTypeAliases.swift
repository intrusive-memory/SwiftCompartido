//
//  LegacyTypeAliases.swift
//  SwiftCompartido
//
//  Deprecated type aliases for legacy Generated*Record models
//  Use TypedDataStorage directly for new code
//

import Foundation
import SwiftData

/// Legacy type alias for GeneratedTextRecord
///
/// - Important: This type alias is deprecated. Use `TypedDataStorage` instead.
/// - Note: Create text records with `mimeType: "text/plain"`
///
/// ## Migration Example
/// ```swift
/// // Old code:
/// let record = GeneratedTextRecord(
///     providerId: "openai",
///     requestorID: "gpt-4",
///     text: "Hello",
///     wordCount: 1,
///     characterCount: 5
/// )
///
/// // New code:
/// let record = TypedDataStorage(
///     providerId: "openai",
///     requestorID: "gpt-4",
///     mimeType: "text/plain",
///     textValue: "Hello",
///     wordCount: 1,
///     characterCount: 5
/// )
/// ```
@available(*, deprecated, renamed: "TypedDataStorage", message: "Use TypedDataStorage with mimeType 'text/plain' instead")
public typealias GeneratedTextRecord = TypedDataStorage

/// Legacy type alias for GeneratedAudioRecord
///
/// - Important: This type alias is deprecated. Use `TypedDataStorage` instead.
/// - Note: Create audio records with appropriate `mimeType` (e.g., "audio/mpeg", "audio/wav")
///
/// ## Migration Example
/// ```swift
/// // Old code:
/// let record = GeneratedAudioRecord(
///     providerId: "elevenlabs",
///     requestorID: "tts",
///     audioData: data,
///     format: "mp3",
///     voiceID: "rachel",
///     voiceName: "Rachel"
/// )
///
/// // New code:
/// let record = TypedDataStorage(
///     providerId: "elevenlabs",
///     requestorID: "tts",
///     mimeType: "audio/mpeg",
///     binaryValue: data,
///     audioFormat: "mp3",
///     voiceID: "rachel",
///     voiceName: "Rachel"
/// )
/// ```
@available(*, deprecated, renamed: "TypedDataStorage", message: "Use TypedDataStorage with audio/* mimeType instead")
public typealias GeneratedAudioRecord = TypedDataStorage

/// Legacy type alias for GeneratedImageRecord
///
/// - Important: This type alias is deprecated. Use `TypedDataStorage` instead.
/// - Note: Create image records with appropriate `mimeType` (e.g., "image/png", "image/jpeg")
///
/// ## Migration Example
/// ```swift
/// // Old code:
/// let record = GeneratedImageRecord(
///     providerId: "openai",
///     requestorID: "dalle-3",
///     imageData: data,
///     format: "png",
///     width: 1024,
///     height: 1024
/// )
///
/// // New code:
/// let record = TypedDataStorage(
///     providerId: "openai",
///     requestorID: "dalle-3",
///     mimeType: "image/png",
///     binaryValue: data,
///     imageFormat: "png",
///     width: 1024,
///     height: 1024
/// )
/// ```
@available(*, deprecated, renamed: "TypedDataStorage", message: "Use TypedDataStorage with image/* mimeType instead")
public typealias GeneratedImageRecord = TypedDataStorage

/// Legacy type alias for GeneratedEmbeddingRecord
///
/// - Important: This type alias is deprecated. Use `TypedDataStorage` instead.
/// - Note: Create embedding records with `mimeType: "application/x-embedding"`
///
/// ## Migration Example
/// ```swift
/// // Old code:
/// let record = GeneratedEmbeddingRecord(
///     providerId: "openai",
///     requestorID: "embedding",
///     embeddingData: data,
///     dimensions: 1536,
///     inputText: "Test"
/// )
///
/// // New code:
/// let record = TypedDataStorage(
///     providerId: "openai",
///     requestorID: "embedding",
///     mimeType: "application/x-embedding",
///     binaryValue: data,
///     dimensions: 1536,
///     inputText: "Test"
/// )
/// ```
@available(*, deprecated, renamed: "TypedDataStorage", message: "Use TypedDataStorage with mimeType 'application/x-embedding' instead")
public typealias GeneratedEmbeddingRecord = TypedDataStorage
