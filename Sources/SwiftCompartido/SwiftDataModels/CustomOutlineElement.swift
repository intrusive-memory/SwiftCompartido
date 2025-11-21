//
//  CustomOutlineElement.swift
//  SwiftCompartido
//
//  Custom outline elements allow users to attach media files to screenplay scenes/sections
//  for reference, production notes, or creative purposes
//  Part of Custom Outline Elements feature
//

import Foundation
import SwiftData

/// A custom outline element that can be attached to screenplay scenes/sections
///
/// Custom outline elements allow users to organize and attach media files (audio, images,
/// video, documents) to specific points in their screenplay. These elements are distinct
/// from AI-generated content and serve purposes like:
/// - Music cues for soundtrack planning
/// - Sound effects for audio design reference
/// - Production notes with attached reference materials
/// - Generic media containers for flexible use
///
/// ## Relationships
/// - **Parent**: Links to a `GuionElementModel` (typically a scene heading)
/// - **Media**: Can have multiple `TypedDataStorage` records attached
///
/// ## Cascade Deletion
/// - Deleting a parent element will cascade delete all custom elements
/// - Deleting a custom element will cascade delete all attached media
@Model
public final class CustomOutlineElement {
    // MARK: - Identity

    /// Unique identifier for this custom element
    public var id: UUID

    // MARK: - Type & Metadata

    /// The type of custom element (music cue, sound effect, etc.)
    public var elementType: CustomElementType

    /// User-provided title/label for this element
    ///
    /// Required field that describes what this element represents
    /// Example: "Opening Credits Music", "Thunder Sound Effect"
    public var title: String

    /// Optional description or notes about this element
    ///
    /// Additional context the user wants to attach to this element
    /// Example: "Use dramatic orchestral piece here"
    public var notes: String?

    /// Position of this element relative to other custom elements on the same parent
    ///
    /// Used to maintain user-defined ordering when multiple custom elements
    /// are attached to the same scene
    public var orderIndex: Int

    // MARK: - Audio Cue Properties

    /// Audio cue category for this element
    ///
    /// Valid values: "MUSIC", "SFX", "BACKGROUND", "CUE"
    /// Only set when this custom element represents an audio cue directive
    /// Nil for non-audio custom elements
    public var audioCueCategory: String?

    /// Reference to the audio file to be used for this cue
    ///
    /// Relative path from Resources/ folder (e.g., "music/intro-theme.mp3")
    /// Nil until user selects a file
    public var audioFileReference: String?

    /// Volume adjustment in decibels
    ///
    /// Always set (never nil) with category-specific defaults:
    /// - MUSIC: -18.0 dB
    /// - SFX: -12.0 dB
    /// - BACKGROUND: -30.0 dB
    /// - CUE: 0.0 dB (not used, but set for consistency)
    public var volume: Float

    /// Fade in duration in seconds
    ///
    /// Always set (never nil) with category-specific defaults:
    /// - MUSIC: 2.0 seconds
    /// - SFX: 0.0 seconds
    /// - BACKGROUND: 8.0 seconds
    /// - CUE: 0.0 seconds (not used)
    public var fadeInDuration: TimeInterval

    /// Fade out duration in seconds
    ///
    /// Always set (never nil) with category-specific defaults:
    /// - MUSIC: 2.0 seconds
    /// - SFX: 0.0 seconds
    /// - BACKGROUND: 8.0 seconds
    /// - CUE: 0.0 seconds (not used)
    public var fadeOutDuration: TimeInterval

    /// Playback speed as percentage (100.0 = normal speed)
    ///
    /// Always set (never nil), defaults to 100.0 for all categories
    /// Values: 50.0 (half speed) to 200.0 (double speed)
    public var playSpeed: Float

    /// Whether the audio should loop continuously
    ///
    /// Always set (never nil) with category-specific defaults:
    /// - MUSIC: false
    /// - SFX: false
    /// - BACKGROUND: true (ambient audio typically loops)
    /// - CUE: false (not used)
    public var loopEnabled: Bool

    /// Duration for production cues (CUE category only)
    ///
    /// Specifies how long a pause, silence, or timing directive should last
    /// Nil for MUSIC, SFX, and BACKGROUND categories
    /// Default: 2.0 seconds for CUE category
    public var cueDuration: TimeInterval?

    /// Optional timing reference for relative positioning
    ///
    /// Example: "after dialogue", "with scene start", "00:15:30"
    /// Used for advanced timeline positioning (Phase 2+)
    public var timingReference: String?

    // MARK: - Timestamps

    /// When this custom element was created
    public var createdAt: Date

    /// When this custom element was last modified
    ///
    /// Should be updated whenever title, notes, or media attachments change
    public var modifiedAt: Date

    // MARK: - Relationships

    /// The screenplay element (scene/section) this custom element is attached to
    ///
    /// Typically a scene heading or section heading element
    /// Inverse relationship: `GuionElementModel.customElements`
    @Relationship(inverse: \GuionElementModel.customElements)
    public var parentElement: GuionElementModel?

    /// Media files attached to this custom element
    ///
    /// Can include audio, images, video, documents stored via `TypedDataStorage`
    /// Cascade delete: When this element is deleted, all attached media is also deleted
    @Relationship(deleteRule: .cascade)
    public var attachedMedia: [TypedDataStorage]?

    // MARK: - Initialization

    /// Create a new custom outline element
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - elementType: Type of custom element
    ///   - title: User-provided title/label
    ///   - notes: Optional description or notes
    ///   - orderIndex: Position relative to other custom elements (defaults to 0)
    ///   - audioCueCategory: Audio cue category ("MUSIC", "SFX", "BACKGROUND", "CUE") or nil
    ///   - audioFileReference: Relative path to audio file or nil
    ///   - volume: Volume in dB (defaults to 0.0, use factory method for category defaults)
    ///   - fadeInDuration: Fade in duration in seconds (defaults to 0.0)
    ///   - fadeOutDuration: Fade out duration in seconds (defaults to 0.0)
    ///   - playSpeed: Playback speed percentage (defaults to 100.0)
    ///   - loopEnabled: Whether to loop audio (defaults to false)
    ///   - cueDuration: Duration for CUE category (defaults to nil)
    ///   - timingReference: Optional timing reference string
    public init(
        id: UUID = UUID(),
        elementType: CustomElementType,
        title: String,
        notes: String? = nil,
        orderIndex: Int = 0,
        audioCueCategory: String? = nil,
        audioFileReference: String? = nil,
        volume: Float = 0.0,
        fadeInDuration: TimeInterval = 0.0,
        fadeOutDuration: TimeInterval = 0.0,
        playSpeed: Float = 100.0,
        loopEnabled: Bool = false,
        cueDuration: TimeInterval? = nil,
        timingReference: String? = nil
    ) {
        self.id = id
        self.elementType = elementType
        self.title = title
        self.notes = notes
        self.orderIndex = orderIndex
        self.audioCueCategory = audioCueCategory
        self.audioFileReference = audioFileReference
        self.volume = volume
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
        self.playSpeed = playSpeed
        self.loopEnabled = loopEnabled
        self.cueDuration = cueDuration
        self.timingReference = timingReference
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

// MARK: - Convenience Methods

extension CustomOutlineElement {
    /// Check if this element has any attached media
    public var hasAttachedMedia: Bool {
        guard let media = attachedMedia else { return false }
        return !media.isEmpty
    }

    /// Count of attached media files
    public var attachedMediaCount: Int {
        attachedMedia?.count ?? 0
    }

    /// Get attached media of a specific MIME type prefix
    ///
    /// - Parameter mimeTypePrefix: The MIME type prefix to filter by (e.g., "audio/", "image/")
    /// - Returns: Array of matching TypedDataStorage records
    public func attachedMedia(withMimeTypePrefix mimeTypePrefix: String) -> [TypedDataStorage] {
        guard let media = attachedMedia else { return [] }
        return media.filter { $0.mimeType.hasPrefix(mimeTypePrefix) }
    }

    /// Get all attached audio files
    public var attachedAudio: [TypedDataStorage] {
        attachedMedia(withMimeTypePrefix: "audio/")
    }

    /// Get all attached images
    public var attachedImages: [TypedDataStorage] {
        attachedMedia(withMimeTypePrefix: "image/")
    }

    /// Get all attached videos
    public var attachedVideos: [TypedDataStorage] {
        attachedMedia(withMimeTypePrefix: "video/")
    }

    /// Get all attached documents
    public var attachedDocuments: [TypedDataStorage] {
        attachedMedia(withMimeTypePrefix: "application/")
    }
}

// MARK: - Audio Cue Factory Methods

extension CustomOutlineElement {
    /// Create a MUSIC audio cue with category-specific defaults
    ///
    /// - Parameters:
    ///   - title: User-provided title (e.g., "Opening Theme")
    ///   - notes: Optional description or notes
    ///   - orderIndex: Position relative to other custom elements (defaults to 0)
    /// - Returns: CustomOutlineElement configured as MUSIC cue with defaults
    ///
    /// Default values for MUSIC:
    /// - Volume: -18.0 dB
    /// - Fade in: 2.0 seconds
    /// - Fade out: 2.0 seconds
    /// - Speed: 100.0%
    /// - Loop: false
    public static func musicCue(
        title: String,
        notes: String? = nil,
        orderIndex: Int = 0
    ) -> CustomOutlineElement {
        CustomOutlineElement(
            elementType: .musicCue,
            title: title,
            notes: notes,
            orderIndex: orderIndex,
            audioCueCategory: "MUSIC",
            volume: -18.0,
            fadeInDuration: 2.0,
            fadeOutDuration: 2.0,
            playSpeed: 100.0,
            loopEnabled: false
        )
    }

    /// Create an SFX (sound effects) audio cue with category-specific defaults
    ///
    /// - Parameters:
    ///   - title: User-provided title (e.g., "Door Slam")
    ///   - notes: Optional description or notes
    ///   - orderIndex: Position relative to other custom elements (defaults to 0)
    /// - Returns: CustomOutlineElement configured as SFX cue with defaults
    ///
    /// Default values for SFX:
    /// - Volume: -12.0 dB
    /// - Fade in: 0.0 seconds (instant)
    /// - Fade out: 0.0 seconds (instant)
    /// - Speed: 100.0%
    /// - Loop: false
    public static func sfxCue(
        title: String,
        notes: String? = nil,
        orderIndex: Int = 0
    ) -> CustomOutlineElement {
        CustomOutlineElement(
            elementType: .soundEffect,
            title: title,
            notes: notes,
            orderIndex: orderIndex,
            audioCueCategory: "SFX",
            volume: -12.0,
            fadeInDuration: 0.0,
            fadeOutDuration: 0.0,
            playSpeed: 100.0,
            loopEnabled: false
        )
    }

    /// Create a BACKGROUND audio cue with category-specific defaults
    ///
    /// - Parameters:
    ///   - title: User-provided title (e.g., "Coffee Shop Ambience")
    ///   - notes: Optional description or notes
    ///   - orderIndex: Position relative to other custom elements (defaults to 0)
    /// - Returns: CustomOutlineElement configured as BACKGROUND cue with defaults
    ///
    /// Default values for BACKGROUND:
    /// - Volume: -30.0 dB (very quiet)
    /// - Fade in: 8.0 seconds (smooth entry)
    /// - Fade out: 8.0 seconds (smooth exit)
    /// - Speed: 100.0%
    /// - Loop: true (ambient audio typically loops)
    public static func backgroundCue(
        title: String,
        notes: String? = nil,
        orderIndex: Int = 0
    ) -> CustomOutlineElement {
        CustomOutlineElement(
            elementType: .genericMedia,
            title: title,
            notes: notes,
            orderIndex: orderIndex,
            audioCueCategory: "BACKGROUND",
            volume: -30.0,
            fadeInDuration: 8.0,
            fadeOutDuration: 8.0,
            playSpeed: 100.0,
            loopEnabled: true
        )
    }

    /// Create a CUE (production cue) with category-specific defaults
    ///
    /// - Parameters:
    ///   - title: User-provided title (e.g., "Pause for emphasis")
    ///   - notes: Optional description or notes
    ///   - duration: Duration of the cue in seconds (defaults to 2.0)
    ///   - orderIndex: Position relative to other custom elements (defaults to 0)
    /// - Returns: CustomOutlineElement configured as CUE with defaults
    ///
    /// Default values for CUE:
    /// - Volume: 0.0 dB (not used for timing cues)
    /// - Fade in: 0.0 seconds (not used)
    /// - Fade out: 0.0 seconds (not used)
    /// - Speed: 100.0%
    /// - Loop: false
    /// - Duration: 2.0 seconds (customizable via parameter)
    public static func productionCue(
        title: String,
        notes: String? = nil,
        duration: TimeInterval = 2.0,
        orderIndex: Int = 0
    ) -> CustomOutlineElement {
        CustomOutlineElement(
            elementType: .productionNote,
            title: title,
            notes: notes,
            orderIndex: orderIndex,
            audioCueCategory: "CUE",
            volume: 0.0,
            fadeInDuration: 0.0,
            fadeOutDuration: 0.0,
            playSpeed: 100.0,
            loopEnabled: false,
            cueDuration: duration
        )
    }
}

// MARK: - Audio Cue Validation

extension CustomOutlineElement {
    /// Check if this element is an audio cue
    public var isAudioCue: Bool {
        audioCueCategory != nil
    }

    /// Validate that audio cue properties are consistent with category
    ///
    /// - Returns: True if properties are valid for the category, false otherwise
    public var isValidAudioCue: Bool {
        guard let category = audioCueCategory else {
            // Not an audio cue, so validation passes
            return true
        }

        // Validate category is one of the four supported types
        let validCategories = ["MUSIC", "SFX", "BACKGROUND", "CUE"]
        guard validCategories.contains(category) else {
            return false
        }

        // CUE category must have cueDuration set
        if category == "CUE" && cueDuration == nil {
            return false
        }

        // Non-CUE categories should not have cueDuration
        if category != "CUE" && cueDuration != nil {
            return false
        }

        // Volume should be reasonable (between -60 and +12 dB)
        guard volume >= -60.0 && volume <= 12.0 else {
            return false
        }

        // Fade durations should be non-negative
        guard fadeInDuration >= 0.0 && fadeOutDuration >= 0.0 else {
            return false
        }

        // Play speed should be positive (typically 50% to 200%)
        guard playSpeed > 0.0 && playSpeed <= 500.0 else {
            return false
        }

        return true
    }

    /// Get a user-friendly description of the audio cue category
    public var audioCueCategoryDescription: String? {
        guard let category = audioCueCategory else { return nil }

        switch category {
        case "MUSIC":
            return "Music Cue"
        case "SFX":
            return "Sound Effect"
        case "BACKGROUND":
            return "Background Audio"
        case "CUE":
            return "Production Cue"
        default:
            return category
        }
    }
}
