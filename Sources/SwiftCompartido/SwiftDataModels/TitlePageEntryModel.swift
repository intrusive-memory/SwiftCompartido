//
//  TitlePageEntryModel.swift
//  SwiftCompartido
//
//  SwiftData model for screenplay title page entries
//

import Foundation
import SwiftData

/// SwiftData model representing a title page entry.
///
/// Title page entries store screenplay metadata such as title, author, contact
/// information, draft date, and other production details.
///
/// ## Overview
///
/// Each entry consists of a key (e.g., "Title", "Author") and one or more values.
/// Multiple values are supported for keys like "Author" when there are co-writers.
///
/// ## Example
///
/// ```swift
/// // Single value
/// let titleEntry = TitlePageEntryModel(
///     key: "Title",
///     values: ["The Great Screenplay"]
/// )
///
/// // Multiple values
/// let authorsEntry = TitlePageEntryModel(
///     key: "Author",
///     values: ["Jane Doe", "John Smith"]
/// )
/// ```
///
/// ## Common Keys
///
/// - `Title`: The screenplay title
/// - `Author`: Writer name(s)
/// - `Contact`: Contact information
/// - `Draft date`: Date of this draft
/// - `Copyright`: Copyright notice
/// - `Notes`: Production notes
///
@Model
public final class TitlePageEntryModel {
    /// The title page key (e.g., "Title", "Author", "Contact")
    public var key: String

    /// The values for this key (supports multiple values for co-authors, etc.)
    public var values: [String]

    /// Reference to the parent document
    public var document: GuionDocumentModel?

    /// Initialize a new title page entry
    /// - Parameters:
    ///   - key: The entry key
    ///   - values: One or more values for this key
    public init(key: String, values: [String]) {
        self.key = key
        self.values = values
    }
}
