//
//  ParseScreenplayFileIntent.swift
//  SwiftCompartido
//
//  App Intent for parsing screenplay files via Shortcuts.
//

import AppIntents
import Foundation
@preconcurrency import SwiftData

/// Parse a screenplay file and return structured element references.
///
/// This intent enables Shortcuts workflows to import screenplay files and
/// extract elements for downstream processing (e.g., voice generation).
///
/// **Key Features**:
/// - Automatic format detection (Fountain, FDX, PDF, Markdown, Highland, TextBundle)
/// - Optional filtering during parse (e.g., dialogue only)
/// - Returns complete element data for chaining
///
/// **Example Workflow**:
/// ```
/// Parse Screenplay File (file: script.fountain, filter: dialogue)
/// → ScreenplayElementsReference
/// → Generate Voice (for each element)
/// ```
@available(iOS 26.0, macOS 26.0, *)
public struct ParseScreenplayFileIntent: AppIntent {

  public static let title: LocalizedStringResource = "Parse Screenplay File"

  public static let description = IntentDescription(
    "Import a screenplay file and parse it into structured elements. Supports Fountain, FDX, PDF, and other formats."
  )

  public static let openAppWhenRun: Bool = false

  // MARK: - Parameters

  @Parameter(
    title: "File",
    description: "The screenplay file to parse"
  )
  public var fileURL: URL

  @Parameter(
    title: "Filter Element Types",
    description: "Optional: Filter to specific element types (e.g., dialogue only)"
  )
  public var elementTypes: [ElementTypeEntity]?

  @Parameter(
    title: "Filter by Chapter",
    description: "Optional: Filter to specific chapter index (0-based)"
  )
  public var chapterIndex: Int?

  @Parameter(
    title: "Search Text",
    description: "Optional: Filter to elements containing this text"
  )
  public var searchText: String?

  // MARK: - Initializer

  public init() {
    // Required empty initializer for AppIntent
  }

  public init(
    fileURL: URL,
    elementTypes: [ElementTypeEntity]? = nil,
    chapterIndex: Int? = nil,
    searchText: String? = nil
  ) {
    self.fileURL = fileURL
    self.elementTypes = elementTypes
    self.chapterIndex = chapterIndex
    self.searchText = searchText
  }

  // MARK: - Perform

  @MainActor
  public func perform() async throws -> some IntentResult & ReturnsValue<
    ScreenplayElementsReference
  > {
    // Use unified service (single code path)
    let service = ParsedFileService.shared

    // Step 1: Parse file
    let documentID = try await service.parseFile(at: fileURL)

    // Step 2: Build filter from parameters
    let filter: ElementFilter? = {
      // If no filter parameters provided, return nil
      guard elementTypes != nil || chapterIndex != nil || searchText != nil else {
        return nil
      }

      return ElementFilter(
        elementTypes: elementTypes?.map { $0.elementType },
        chapterIndex: chapterIndex,
        characterName: nil,  // Not supported in this intent
        searchText: searchText
      )
    }()

    // Step 3: Query elements with filter
    let elements = try await service.elements(documentID: documentID, filter: filter)

    // Step 4: Get document for metadata
    let document = try await service.document(id: documentID)

    // Step 5: Create reference
    let reference = ScreenplayElementsReference(
      from: document,
      elements: elements
    )

    // Return result directly
    return .result(value: reference)
  }
}

/// Entity for element type selection in Shortcuts.
@available(iOS 26.0, macOS 26.0, *)
public struct ElementTypeEntity: AppEntity {

  public static let typeDisplayRepresentation = TypeDisplayRepresentation(
    name: "Element Type"
  )

  public let id: String
  public let elementType: ElementType

  public var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(id)")
  }

  public init(id: String, elementType: ElementType) {
    self.id = id
    self.elementType = elementType
  }

  public static var defaultQuery: ElementTypeQuery {
    ElementTypeQuery()
  }
}

/// Query for element type entities.
@available(iOS 26.0, macOS 26.0, *)
public struct ElementTypeQuery: EntityQuery {

  public init() {}

  public func entities(for identifiers: [String]) async throws -> [ElementTypeEntity] {
    identifiers.compactMap { id in
      Self.allTypes.first { $0.id == id }
    }
  }

  public func suggestedEntities() async throws -> [ElementTypeEntity] {
    Self.allTypes
  }

  private static let allTypes: [ElementTypeEntity] = [
    ElementTypeEntity(id: "Scene Heading", elementType: .sceneHeading),
    ElementTypeEntity(id: "Action", elementType: .action),
    ElementTypeEntity(id: "Character", elementType: .character),
    ElementTypeEntity(id: "Dialogue", elementType: .dialogue),
    ElementTypeEntity(id: "Parenthetical", elementType: .parenthetical),
    ElementTypeEntity(id: "Transition", elementType: .transition),
    ElementTypeEntity(id: "Lyrics", elementType: .lyrics),
  ]
}
