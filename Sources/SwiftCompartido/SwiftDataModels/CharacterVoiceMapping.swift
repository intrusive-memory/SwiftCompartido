//
//  CharacterVoiceMapping.swift
//  SwiftCompartido
//
//  SwiftData model for character voice assignments (Phase 1.5: Casting Support)
//

import Foundation
#if canImport(SwiftData)
@preconcurrency import SwiftData

/// SwiftData model representing a character's voice assignment.
///
/// This model maps a screenplay character to a specific voice for audio generation.
/// Used by SwiftHablare to generate dialogue audio with the correct voice for each character.
///
/// ## Overview
///
/// Voice mappings are stored in the document's `casting` relationship. Each mapping
/// specifies which voice to use when generating audio for a character's dialogue.
///
/// ## Voice URI Format
///
/// Voice URIs use a provider-specific scheme:
/// - **macOS System Voices**: `macos://VoiceName` (e.g., `macos://Samantha`)
/// - **ElevenLabs**: `elevenlabs://voice-id` (e.g., `elevenlabs://21m00Tcm4TlvDq8ikWAM`)
/// - **OpenAI**: `openai://voice-name` (e.g., `openai://alloy`)
///
/// ## Example
///
/// ```swift
/// let mapping = CharacterVoiceMapping(
///     characterName: "JANE",
///     voiceURI: "macos://Samantha",
///     voiceName: "Samantha",
///     providerID: "macos"
/// )
/// document.casting.append(mapping)
/// ```
///
/// ## Topics
///
/// ### Creating Mappings
/// - ``init(characterName:voiceURI:voiceName:providerID:)``
///
/// ### Properties
/// - ``characterName``
/// - ``voiceURI``
/// - ``voiceName``
/// - ``providerID``
///
/// ### Relationships
/// - ``document``
@Model
public final class CharacterVoiceMapping {

    /// Character name (e.g., "JANE", "JOHN")
    ///
    /// This is the character name as it appears in the screenplay.
    /// Must match exactly for voice mapping to work.
    public var characterName: String

    /// Voice URI identifying the specific voice
    ///
    /// Format: `provider://identifier`
    ///
    /// ## Examples
    ///
    /// - `macos://Samantha` - macOS system voice
    /// - `elevenlabs://21m00Tcm4TlvDq8ikWAM` - ElevenLabs voice ID
    /// - `openai://alloy` - OpenAI voice name
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

    /// Parent document (inverse relationship)
    ///
    /// **Delete Rule**: `.nullify` - Deleting a mapping doesn't affect the document
    @Relationship(deleteRule: .nullify)
    public var document: GuionDocumentModel?

    /// Initialize a new character voice mapping
    ///
    /// - Parameters:
    ///   - characterName: Character name (e.g., "JANE")
    ///   - voiceURI: Voice URI (e.g., "macos://Samantha")
    ///   - voiceName: Human-readable name (e.g., "Samantha")
    ///   - providerID: Provider ID (e.g., "macos")
    public init(characterName: String, voiceURI: String, voiceName: String, providerID: String) {
        self.characterName = characterName
        self.voiceURI = voiceURI
        self.voiceName = voiceName
        self.providerID = providerID
    }
}

// MARK: - Snapshot Conversion

extension CharacterVoiceMapping {
    /// Convert this SwiftData model to a Codable snapshot
    ///
    /// - Returns: Snapshot ready for JSON serialization
    public func toSnapshot() -> CharacterVoiceMappingSnapshot {
        CharacterVoiceMappingSnapshot(
            voiceURI: voiceURI,
            voiceName: voiceName,
            providerID: providerID
        )
    }

    /// Create SwiftData model from a Codable snapshot
    ///
    /// - Parameters:
    ///   - characterName: Character name this mapping is for
    ///   - snapshot: Snapshot loaded from JSON
    ///   - document: Parent document (for relationship)
    /// - Returns: SwiftData model ready for insertion
    public static func from(
        characterName: String,
        _ snapshot: CharacterVoiceMappingSnapshot,
        document: GuionDocumentModel? = nil
    ) -> CharacterVoiceMapping {
        let mapping = CharacterVoiceMapping(
            characterName: characterName,
            voiceURI: snapshot.voiceURI,
            voiceName: snapshot.voiceName,
            providerID: snapshot.providerID
        )
        mapping.document = document
        return mapping
    }
}

#endif
