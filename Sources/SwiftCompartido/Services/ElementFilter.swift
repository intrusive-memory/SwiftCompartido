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
    /// Only applies to dialogue, parenthetical, and lyrics elements.
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
    /// **Note**: This method cannot check `characterName` because it lacks context of preceding
    /// CHARACTER elements. Use `filter(elements:)` instead for character name filtering.
    ///
    /// - Parameter element: The element to test against this filter
    /// - Returns: True if the element matches all specified criteria (except characterName)
    public func matches(_ element: GuionElementModel) -> Bool {
        var matches = true

        if let types = elementTypes {
            matches = matches && types.contains(element.elementType)
        }

        if let chapterIndex = chapterIndex {
            matches = matches && element.chapterIndex == chapterIndex
        }

        // Character name filtering requires context (preceding CHARACTER elements)
        // This is handled by filter(elements:) method instead
        // Ignoring characterName in this method would make it inconsistent

        if let searchText = searchText {
            matches = matches && element.elementText.localizedCaseInsensitiveContains(searchText)
        }

        return matches
    }

    /// Filters an array of elements using this filter's criteria, including character name matching.
    ///
    /// This method tracks preceding CHARACTER elements to properly match character names
    /// for dialogue, parenthetical, and lyrics elements.
    ///
    /// - Parameter elements: The elements to filter (should be sorted)
    /// - Returns: Array of elements matching all filter criteria
    public func filter(elements: [GuionElementModel]) -> [GuionElementModel] {
        // If no character name filter, use simple element-by-element matching
        guard let targetCharacter = characterName else {
            return elements.filter { matches($0) }
        }

        // Track current character for character name filtering
        var results: [GuionElementModel] = []
        var currentCharacter: String? = nil

        for element in elements {
            // Update current character when we encounter a CHARACTER element
            if element.elementType == .character {
                currentCharacter = element.elementText.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Check if element matches all criteria
            var elementMatches = matches(element) // Check type, chapter, search text

            // Additionally check character name for dialogue/parenthetical/lyrics
            if elementMatches {
                switch element.elementType {
                case .dialogue, .parenthetical, .lyrics:
                    // Only include if current character matches target
                    elementMatches = currentCharacter?.localizedCaseInsensitiveCompare(targetCharacter) == .orderedSame
                default:
                    // For non-dialogue elements, character filter doesn't apply
                    // Only include if not filtering to dialogue-only
                    if let types = elementTypes, types.contains(.dialogue) || types.contains(.parenthetical) || types.contains(.lyrics) {
                        // User is filtering to dialogue types, don't include non-dialogue
                        elementMatches = false
                    }
                }
            }

            if elementMatches {
                results.append(element)
            }
        }

        return results
    }
}
