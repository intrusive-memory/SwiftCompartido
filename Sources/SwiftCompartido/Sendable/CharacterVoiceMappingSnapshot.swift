//
//  CharacterVoiceMappingSnapshot.swift
//  SwiftCompartido
//
//  Codable snapshot type for character voice mappings (Phase 1: SwiftHablare integration)
//

import Foundation

/// Codable snapshot representing a character's voice assignment.
///
/// This snapshot maps a screenplay character to a specific voice for audio generation.
/// Used by SwiftHablare to generate dialogue audio with the correct voice for each character.
///
/// ## Overview
///
/// Voice mappings are stored in the document's `casting` dictionary, keyed by character name.
/// Each mapping specifies which voice to use when generating audio for that character's dialogue.
///
/// ## Voice URI Format
///
/// Voice URIs follow the SwiftHablare standard: `<provider>://<voiceId>?lang=<languageCode>`
/// - **macOS System Voices**: `macos://Samantha?lang=en`
/// - **ElevenLabs**: `elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en`
/// - **OpenAI**: `openai://alloy?lang=en`
/// - **Custom Providers**: `provider://identifier?lang=<languageCode>`
///
/// ## Example
///
/// ```swift
/// let mapping = CharacterVoiceMappingSnapshot(
///     voiceURI: "macos://Samantha?lang=en",
///     voiceName: "Samantha",
///     providerID: "macos"
/// )
///
/// // Or ElevenLabs:
/// let elevenlabsMapping = CharacterVoiceMappingSnapshot(
///     voiceURI: "elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en",
///     voiceName: "Rachel",
///     providerID: "elevenlabs"
/// )
/// ```
///
/// ## Topics
///
/// ### Creating Mappings
/// - ``init(voiceURI:voiceName:providerID:)``
///
/// ### Properties
/// - ``voiceURI``
/// - ``voiceName``
/// - ``providerID``
public struct CharacterVoiceMappingSnapshot: Codable, Sendable, Hashable {

    /// Voice URI identifying the specific voice
    ///
    /// Format: `<provider>://<voiceId>?lang=<languageCode>`
    ///
    /// ## Examples
    ///
    /// - `macos://Samantha?lang=en` - macOS system voice
    /// - `elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en` - ElevenLabs voice ID
    /// - `openai://alloy?lang=en` - OpenAI voice name
    public var voiceURI: String

    /// Human-readable voice name
    ///
    /// Displayed in UI for voice selection. Examples:
    /// - "Samantha" (macOS)
    /// - "Rachel" (ElevenLabs)
    /// - "Alloy" (OpenAI)
    public var voiceName: String

    /// Provider identifier
    ///
    /// Identifies which audio generation provider owns this voice:
    /// - `macos` - macOS system TTS
    /// - `elevenlabs` - ElevenLabs
    /// - `openai` - OpenAI TTS
    /// - Custom provider IDs
    public var providerID: String

    /// Initialize a new character voice mapping
    ///
    /// - Parameters:
    ///   - voiceURI: Voice URI (e.g., "macos://Samantha?lang=en")
    ///   - voiceName: Human-readable name (e.g., "Samantha")
    ///   - providerID: Provider ID (e.g., "macos")
    public init(voiceURI: String, voiceName: String, providerID: String) {
        self.voiceURI = voiceURI
        self.voiceName = voiceName
        self.providerID = providerID
    }
}
