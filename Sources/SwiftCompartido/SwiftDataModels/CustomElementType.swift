//
//  CustomElementType.swift
//  SwiftCompartido
//
//  Enum defining types of custom outline elements that can be attached to screenplay scenes
//  Part of Custom Outline Elements feature
//

import Foundation

/// Types of custom outline elements that can be attached to screenplay scenes/sections
///
/// Custom outline elements allow users to attach media (audio, images, video, documents)
/// to specific points in their screenplay for reference, production notes, or creative purposes.
public enum CustomElementType: String, Codable, CaseIterable, Sendable {
    /// Musical elements - songs, score cues, background music
    case musicCue = "Music Cue"

    /// Sound design - ambient sounds, specific SFX cues
    case soundEffect = "Sound Effect"

    /// Director/producer notes with reference media
    case productionNote = "Production Note"

    /// Flexible container for any media type
    case genericMedia = "Generic Media"

    /// SF Symbol icon name for this element type
    ///
    /// These icons are used in UI to visually distinguish element types
    public var icon: String {
        switch self {
        case .musicCue:
            return "music.note"
        case .soundEffect:
            return "waveform"
        case .productionNote:
            return "note.text"
        case .genericMedia:
            return "doc.on.doc"
        }
    }

    /// Human-readable description of this element type
    ///
    /// Provides context about the purpose and typical use of each type
    public var description: String {
        switch self {
        case .musicCue:
            return "Musical elements - songs, score cues, background music"
        case .soundEffect:
            return "Sound design - ambient sounds, specific SFX cues"
        case .productionNote:
            return "Director/producer notes with reference media"
        case .genericMedia:
            return "Flexible container for any media type"
        }
    }
}
