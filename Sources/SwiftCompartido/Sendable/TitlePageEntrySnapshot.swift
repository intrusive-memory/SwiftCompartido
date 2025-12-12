//
//  TitlePageEntrySnapshot.swift
//  SwiftCompartido
//
//  Codable snapshot type for title page entries (Phase 1: .guion JSON format)
//

import Foundation

/// Codable snapshot representing a title page entry.
///
/// Title page entries store screenplay metadata such as title, author, contact
/// information, draft date, and other production details.
///
/// ## Overview
///
/// Each entry consists of a key (e.g., "TITLE", "AUTHOR") and one or more values.
/// Multiple values are supported for keys like "AUTHOR" when there are co-writers.
///
/// ## Example
///
/// ```swift
/// // Single value
/// let titleEntry = TitlePageEntrySnapshot(
///     key: "TITLE",
///     values: ["The Great Screenplay"]
/// )
///
/// // Multiple values
/// let authorsEntry = TitlePageEntrySnapshot(
///     key: "AUTHOR",
///     values: ["Jane Doe", "John Smith"]
/// )
/// ```
///
/// ## Common Keys
///
/// - `TITLE`: The screenplay title
/// - `AUTHOR`: Writer name(s)
/// - `CONTACT`: Contact information
/// - `DRAFT DATE`: Date of this draft
/// - `COPYRIGHT`: Copyright notice
/// - `NOTES`: Production notes
///
/// ## Topics
///
/// ### Creating Entries
/// - ``init(key:values:)``
///
/// ### Properties
/// - ``key``
/// - ``values``
public struct TitlePageEntrySnapshot: Codable, Sendable, Hashable {

    /// The title page key (e.g., "TITLE", "AUTHOR", "CONTACT")
    ///
    /// Keys are normalized to uppercase for consistent lookup.
    public var key: String

    /// The values for this key
    ///
    /// Supports multiple values for co-authors, multiple contact methods, etc.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Single value
    /// TitlePageEntrySnapshot(key: "TITLE", values: ["My Screenplay"])
    ///
    /// // Multiple values
    /// TitlePageEntrySnapshot(key: "AUTHOR", values: ["Jane Doe", "John Smith"])
    /// ```
    public var values: [String]

    /// Initialize a new title page entry
    ///
    /// - Parameters:
    ///   - key: The entry key (will be normalized to uppercase)
    ///   - values: One or more values for this key
    public init(key: String, values: [String]) {
        self.key = key.uppercased()
        self.values = values
    }
}
