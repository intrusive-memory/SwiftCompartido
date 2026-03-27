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

/// Highland 2 compatible cast list page model
///
/// ## Deprecation Notice
///
/// **This model is deprecated and kept only for Highland file format compatibility.**
///
/// For new projects, use `SwiftProyecto.CastMember` as the canonical cast model.
/// `CastListPage` is only used when importing/exporting Highland .textbundle files.
///
/// ### Migration Path
///
/// If you're using `CastListPage` for cast management, migrate to SwiftProyecto:
///
/// ```swift
/// import SwiftProyecto
///
/// // Old approach (deprecated):
/// let castPage = CastListPage(items: [...])
///
/// // New approach (recommended):
/// let discovery = ProjectDiscovery()
/// if let projectMd = discovery.findProjectMd(from: screenplayURL) {
///     let cast = try discovery.readCast(from: projectMd)
/// }
/// ```
///
/// ### Future Plans
///
/// This model will be removed in a future release if Highland support is dropped.
/// Consider migrating to PROJECT.md-based cast management now.
@available(
  *, deprecated, message: "Use SwiftProyecto.CastMember for PROJECT.md-based cast management"
)
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

    // MARK: - Equatable & Hashable (ID-based)

    /// Two cast members are equal if they have the same ID
    public static func == (lhs: CastMember, rhs: CastMember) -> Bool {
      lhs.id == rhs.id
    }

    /// Hash based on ID only
    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
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

  // MARK: - Private Helpers

  /// Extract all character names from a screenplay (normalized to uppercase)
  private func screenplayCharacters(from screenplay: GuionParsedElementCollection) -> Set<String> {
    Set(
      screenplay.elements.compactMap { element -> String? in
        if case .character = element.elementType {
          return element.elementText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }
        return nil
      }
    )
  }

  // MARK: - Public Methods

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
    let charactersInScreenplay = screenplayCharacters(from: screenplay)

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
    let charactersInScreenplay = screenplayCharacters(from: screenplay)

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
    let charactersInScreenplay = screenplayCharacters(from: screenplay)
    let rolesInCast = Set(
      items.map { $0.role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() })

    return charactersInScreenplay.filter { character in
      !rolesInCast.contains(character)
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
