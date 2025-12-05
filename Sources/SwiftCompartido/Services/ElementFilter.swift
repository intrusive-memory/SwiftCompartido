//
//  ElementFilter.swift
//  SwiftCompartido
//
//  Filter criteria for querying screenplay elements.
//

import Foundation

/// Filter criteria for querying screenplay elements from a document.
///
/// Use this struct to filter elements by type, chapter, character name, or text search.
/// All filter criteria are optional and combine with AND logic when multiple are specified.
///
/// Example:
/// ```swift
/// // Filter for Sarah's dialogue in chapter 1
/// let filter = ElementFilter(
///     elementTypes: [.dialogue],
///     chapterIndex: 1,
///     characterName: "SARAH"
/// )
/// ```
@available(iOS 26.0, macOS 26.0, *)
public struct ElementFilter: Sendable, Codable, Equatable {

    /// Filter by specific element types (e.g., dialogue, action, scene headings).
    /// If nil, all element types are included.
    public var elementTypes: [ElementType]?

    /// Filter by chapter index (0-based).
    /// If nil, elements from all chapters are included.
    public var chapterIndex: Int?

    /// Filter by character name (case-insensitive).
    /// If nil, elements with any character name (or no character) are included.
    /// **Note**: Character name filtering requires more complex logic and is not yet implemented.
    /// This field is reserved for future use.
    public var characterName: String?

    /// Filter by text search (case-insensitive substring match).
    /// If nil, no text filtering is applied.
    public var searchText: String?

    /// Creates a new element filter.
    ///
    /// - Parameters:
    ///   - elementTypes: Optional array of element types to filter by
    ///   - chapterIndex: Optional chapter index to filter by
    ///   - characterName: Optional character name to filter by (case-insensitive)
    ///   - searchText: Optional search text to filter by (case-insensitive substring match)
    public init(
        elementTypes: [ElementType]? = nil,
        chapterIndex: Int? = nil,
        characterName: String? = nil,
        searchText: String? = nil
    ) {
        self.elementTypes = elementTypes
        self.chapterIndex = chapterIndex
        self.characterName = characterName
        self.searchText = searchText
    }

    /// Returns true if this filter has no criteria (matches all elements).
    public var isEmpty: Bool {
        elementTypes == nil &&
        chapterIndex == nil &&
        characterName == nil &&
        searchText == nil
    }

    /// Returns true if the given element matches this filter's criteria.
    ///
    /// - Parameter element: The element to test against this filter
    /// - Returns: True if the element matches all specified criteria
    public func matches(_ element: GuionElementModel) -> Bool {
        var matches = true

        if let types = elementTypes {
            matches = matches && types.contains(element.elementType)
        }

        if let chapterIndex = chapterIndex {
            matches = matches && element.chapterIndex == chapterIndex
        }

        // TODO: Implement character name filtering
        // Character name is not a stored property on GuionElementModel
        // Will require scanning for preceding CHARACTER elements
        if let _ = characterName {
            // Character name filtering not yet implemented
            // For now, skip this filter
        }

        if let searchText = searchText {
            matches = matches && element.elementText.localizedCaseInsensitiveContains(searchText)
        }

        return matches
    }
}
