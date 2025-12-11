//
//  CustomPageSnapshot.swift
//  SwiftCompartido
//
//  Codable snapshot type for custom pages (Phase 1: .guion JSON format)
//

import Foundation

/// Codable snapshot representing a custom page.
///
/// This is a type alias to ``CustomPageContainer``, which already provides
/// the Codable, Sendable snapshot functionality needed for custom pages.
///
/// Custom pages include:
/// - Cast lists
/// - Production notes
/// - Concept images
/// - Empty pages (for formatting)
///
/// ## Overview
///
/// The snapshot preserves custom pages as raw JSON data to support:
/// - Full round-trip fidelity for all page types
/// - Preservation of unsupported page types
/// - Future extensibility without schema migrations
///
/// ## Example
///
/// ```swift
/// // Create from a cast list
/// let castList = CastListPage(title: "Cast List", position: 0)
/// let snapshot = try CustomPageSnapshot(page: castList, type: .castList)
///
/// // Serialize to JSON
/// let dict = try snapshot.toDictionary()
/// let data = try JSONSerialization.data(withJSONObject: dict)
/// ```
///
/// ## Topics
///
/// ### Type Alias
/// - ``CustomPageContainer``
///
/// - SeeAlso: ``CustomPageContainer`` for full API documentation
public typealias CustomPageSnapshot = CustomPageContainer
