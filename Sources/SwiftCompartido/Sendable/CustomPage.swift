//
//  CustomPage.swift
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

/// Protocol for all custom page types (Cast List, Advanced, Empty, etc.)
///
/// Custom pages are additional non-screenplay pages that can be included
/// when printing or exporting a screenplay (e.g., cast lists, production notes).
public protocol CustomPage: Codable, Sendable {
    var id: String { get }
    var title: String { get set }
    var position: Int { get set }
}

/// Types of custom pages supported by Highland
public enum CustomPageType: String, Codable, Sendable {
    case castList
    case advanced
    case empty
    case unknown
}

/// Container for custom pages that preserves type information and raw JSON
///
/// This container allows us to:
/// - Store typed pages (like CastListPage) with full model support
/// - Preserve unsupported page types as raw JSON for round-trip fidelity
/// - Detect page type without deserializing the entire object
public struct CustomPageContainer: Codable, Sendable {
    public let type: CustomPageType
    public let rawJSON: Data

    private enum CodingKeys: String, CodingKey {
        case type
    }

    /// Initialize from a typed custom page
    public init<T: CustomPage>(page: T, type: CustomPageType) throws {
        self.type = type
        self.rawJSON = try JSONEncoder().encode(page)
    }

    /// Initialize from raw JSON data (for unsupported types)
    public init(type: CustomPageType, rawJSON: Data) {
        self.type = type
        self.rawJSON = rawJSON
    }

    /// Initialize from a dictionary (parsed from JSON file)
    public init(from dictionary: [String: Any]) throws {
        let typeString = dictionary["type"] as? String ?? "unknown"
        self.type = CustomPageType(rawValue: typeString) ?? .unknown
        self.rawJSON = try JSONSerialization.data(withJSONObject: dictionary)
    }

    public init(from decoder: Decoder) throws {
        // For JSON decoding, we just read the type field and store raw JSON
        // This is primarily used when loading from files via JSONDecoder
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decodeIfPresent(String.self, forKey: .type) ?? "unknown"
        self.type = CustomPageType(rawValue: typeString) ?? .unknown

        // Store raw data - we'll encode the entire dictionary when needed
        // For now, just encode a minimal stub
        let stub = ["type": typeString]
        self.rawJSON = try JSONEncoder().encode(stub)
    }

    public func encode(to encoder: Encoder) throws {
        // When encoding, we can't use singleValueContainer with [String: Any]
        // Instead, clients should use toDictionary() for JSON serialization
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
    }

    /// Convert to dictionary for JSON serialization
    public func toDictionary() throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: rawJSON) as? [String: Any] ?? [:]
    }

    /// Decode as a Cast List page
    public func asCastList() throws -> CastListPage? {
        guard type == .castList else { return nil }
        return try JSONDecoder().decode(CastListPage.self, from: rawJSON)
    }

    /// Get the raw JSON as a dictionary
    public func asRawJSON() throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: rawJSON) as? [String: Any] ?? [:]
    }

    /// Get the page ID without fully deserializing
    public var id: String? {
        try? asRawJSON()["id"] as? String
    }

    /// Get the page title without fully deserializing
    public var title: String? {
        try? asRawJSON()["title"] as? String
    }

    /// Get the page position without fully deserializing
    public var positionValue: Int? {
        try? asRawJSON()["position"] as? Int
    }
}

/// Error types for custom page operations
public enum CustomPageError: Error {
    case invalidJSON
    case unsupportedPageType
    case missingRequiredField(String)
    case decodingFailed(String)
}
