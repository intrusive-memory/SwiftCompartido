//
//  CastListPage.swift
//  SwiftCompartido
//
//  Copyright (c) 2025
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

/// A cast list custom page that maps screenplay characters to actor names
///
/// Cast lists are commonly used in screenplays to document which actors
/// are playing which roles. This page type is fully supported for reading,
/// writing, and editing.
///
/// ## Example
///
/// ```swift
/// let castList = CastListPage(
///     id: UUID().uuidString,
///     title: "Cast List",
///     position: 0,
///     printDots: true,
///     items: [
///         CastListPage.CastMember(
///             id: UUID().uuidString,
///             role: "BERNARD",
///             name: "Jason Manino",
///             position: 0
///         )
///     ]
/// )
/// ```
public struct CastListPage: CustomPage, Identifiable {
    public let id: String
    public var title: String
    public var position: Int
    public var printDots: Bool
    public var items: [CastMember]

    /// A single cast member entry mapping a role to an actor
    public struct CastMember: Codable, Sendable, Identifiable, Hashable {
        public let id: String
        public var role: String
        public var name: String
        public var position: Int

        public init(id: String, role: String, name: String, position: Int) {
            self.id = id
            self.role = role
            self.name = name
            self.position = position
        }

        /// Create a new cast member with auto-generated ID
        public init(role: String, name: String, position: Int = 0) {
            self.id = UUID().uuidString
            self.role = role
            self.name = name
            self.position = position
        }
    }

    public init(
        id: String,
        title: String,
        position: Int,
        printDots: Bool,
        items: [CastMember]
    ) {
        self.id = id
        self.title = title
        self.position = position
        self.printDots = printDots
        self.items = items
    }

    /// Create a new cast list with auto-generated ID
    public init(
        title: String,
        position: Int,
        printDots: Bool = true,
        items: [CastMember] = []
    ) {
        self.id = UUID().uuidString
        self.title = title
        self.position = position
        self.printDots = printDots
        self.items = items
    }

    /// Items sorted by position
    public var sortedItems: [CastMember] {
        items.sorted { $0.position < $1.position }
    }

    /// Add a new cast member
    public mutating func addMember(role: String, name: String) {
        let newPosition = (items.map { $0.position }.max() ?? -1) + 1
        items.append(CastMember(role: role, name: name, position: newPosition))
    }

    /// Remove a cast member by ID
    public mutating func removeMember(id: String) {
        items.removeAll { $0.id == id }
    }

    /// Update a cast member
    public mutating func updateMember(id: String, role: String? = nil, name: String? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let role = role {
            items[index].role = role
        }
        if let name = name {
            items[index].name = name
        }
    }

    /// Trim cast list to only include characters that appear in the given screenplay
    ///
    /// This method removes cast members whose roles don't appear in the screenplay.
    /// Useful when working with shared `custom-pages.json` files where multiple
    /// .fountain files share the same cast list.
    ///
    /// ## Important
    ///
    /// - This is a **destructive operation** - removed cast members cannot be recovered
    /// - Only removes members; never adds them automatically
    /// - Character matching is case-insensitive
    /// - Preserves position values (may create gaps)
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Shared cast list has: BERNARD, SYLVIA, MASON
    /// // Current screenplay only has: BERNARD, SYLVIA
    /// var castList = loadedFromSharedFile()
    /// castList.trim(toCharactersIn: currentScreenplay)
    /// // Cast list now has: BERNARD, SYLVIA (MASON removed)
    /// ```
    ///
    /// - Parameter screenplay: The screenplay to match characters against
    public mutating func trim(toCharactersIn screenplay: GuionParsedElementCollection) {
        // Extract all character names from dialogue elements
        let charactersInScreenplay = Set(
            screenplay.elements
                .compactMap { element -> String? in
                    switch element.elementType {
                    case .character:
                        return element.elementText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    default:
                        return nil
                    }
                }
                .map { $0.uppercased() } // Normalize to uppercase for comparison
        )

        // Remove cast members whose roles don't appear in the screenplay
        items.removeAll { member in
            let normalizedRole = member.role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return !charactersInScreenplay.contains(normalizedRole)
        }
    }

    /// Get characters in the cast list that don't appear in the screenplay
    ///
    /// Useful for displaying warnings before trimming, or for showing which
    /// characters are in the shared cast list but not in the current screenplay.
    ///
    /// - Parameter screenplay: The screenplay to check against
    /// - Returns: Array of cast members not found in the screenplay
    public func membersNotIn(_ screenplay: GuionParsedElementCollection) -> [CastMember] {
        let charactersInScreenplay = Set(
            screenplay.elements
                .compactMap { element -> String? in
                    switch element.elementType {
                    case .character:
                        return element.elementText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    default:
                        return nil
                    }
                }
        )

        return items.filter { member in
            let normalizedRole = member.role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return !charactersInScreenplay.contains(normalizedRole)
        }
    }

    /// Get characters in the screenplay that aren't in the cast list
    ///
    /// Useful for suggesting new cast members to add to the list.
    ///
    /// - Parameter screenplay: The screenplay to check against
    /// - Returns: Array of character names found in screenplay but missing from cast list
    public func charactersNotInCast(from screenplay: GuionParsedElementCollection) -> [String] {
        let charactersInScreenplay = Set(
            screenplay.elements
                .compactMap { element -> String? in
                    switch element.elementType {
                    case .character:
                        return element.elementText.trimmingCharacters(in: .whitespacesAndNewlines)
                    default:
                        return nil
                    }
                }
        )

        let rolesInCast = Set(items.map { $0.role.uppercased() })

        return charactersInScreenplay.filter { character in
            !rolesInCast.contains(character.uppercased())
        }.sorted()
    }

    /// Required by Highland format - the type discriminator
    private enum CodingKeys: String, CodingKey {
        case id, title, position, printDots, items, type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        position = try container.decode(Int.self, forKey: .position)
        printDots = try container.decode(Bool.self, forKey: .printDots)
        items = try container.decode([CastMember].self, forKey: .items)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(position, forKey: .position)
        try container.encode(printDots, forKey: .printDots)
        try container.encode(items, forKey: .items)
        try container.encode("castList", forKey: .type)
    }
}
