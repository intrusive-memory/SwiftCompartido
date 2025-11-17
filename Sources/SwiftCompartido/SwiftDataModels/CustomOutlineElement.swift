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
    public init(
        id: UUID = UUID(),
        elementType: CustomElementType,
        title: String,
        notes: String? = nil,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.elementType = elementType
        self.title = title
        self.notes = notes
        self.orderIndex = orderIndex
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
