//
//  CustomPageModel.swift
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
#if canImport(SwiftData)
import SwiftData

/// SwiftData model for custom pages (Cast List, Advanced, Empty, etc.)
///
/// This model stores custom pages as raw JSON data to support:
/// - Full round-trip fidelity for all page types
/// - Preservation of unsupported page types
/// - Future extensibility without schema migrations
///
/// ## Usage
///
/// ```swift
/// // Create from a cast list
/// let castList = CastListPage(title: "Cast List", position: 0)
/// let container = try CustomPageContainer(page: castList, type: .castList)
/// let model = CustomPageModel.from(container)
///
/// modelContext.insert(model)
///
/// // Convert back to DTO
/// let restoredContainer = try model.toDTO()
/// let restoredCastList = try restoredContainer.asCastList()
/// ```
@Model
public final class CustomPageModel {
    /// Unique identifier for the custom page
    public var id: String

    /// Title of the custom page (e.g., "Cast List", "Production Notes")
    public var title: String

    /// Position in print order (0-based, gaps allowed)
    public var position: Int

    /// Page type discriminator ("castList", "advanced", "empty", "unknown")
    public var pageType: String

    /// Raw JSON data for the entire page
    /// Stores the complete page object for round-trip fidelity
    public var jsonData: Data

    /// Parent document relationship
    @Relationship(deleteRule: .nullify)
    public var document: GuionDocumentModel?

    public init(
        id: String,
        title: String,
        position: Int,
        pageType: String,
        jsonData: Data
    ) {
        self.id = id
        self.title = title
        self.position = position
        self.pageType = pageType
        self.jsonData = jsonData
    }

    /// Create from a CustomPageContainer
    public static func from(_ container: CustomPageContainer) -> CustomPageModel {
        CustomPageModel(
            id: container.id ?? UUID().uuidString,
            title: container.title ?? "Untitled Page",
            position: container.positionValue ?? 0,
            pageType: container.type.rawValue,
            jsonData: container.rawJSON
        )
    }

    /// Convert to a CustomPageContainer
    public func toDTO() throws -> CustomPageContainer {
        guard let type = CustomPageType(rawValue: pageType) else {
            return CustomPageContainer(type: .unknown, rawJSON: jsonData)
        }
        return CustomPageContainer(type: type, rawJSON: jsonData)
    }

    /// Convenience: Get as CastListPage if type is castList
    public func asCastList() throws -> CastListPage? {
        try toDTO().asCastList()
    }

    /// Convenience: Get raw JSON as dictionary
    public func asRawJSON() throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
    }

    /// Update from a CustomPageContainer
    public func update(from container: CustomPageContainer) throws {
        self.title = container.title ?? self.title
        self.position = container.positionValue ?? self.position
        self.pageType = container.type.rawValue
        self.jsonData = container.rawJSON

        // Update ID if it changed (rare, but possible)
        if let newID = container.id {
            self.id = newID
        }
    }

    /// Validate the stored JSON data
    public func validate() throws {
        let json = try JSONSerialization.jsonObject(with: jsonData)
        guard let dict = json as? [String: Any] else {
            throw CustomPageError.invalidJSON
        }

        // Verify required fields
        guard dict["id"] is String else {
            throw CustomPageError.missingRequiredField("id")
        }
        guard dict["title"] is String else {
            throw CustomPageError.missingRequiredField("title")
        }
        guard dict["position"] is Int else {
            throw CustomPageError.missingRequiredField("position")
        }
        guard dict["type"] is String else {
            throw CustomPageError.missingRequiredField("type")
        }
    }
}

#endif
