//
//  ExtractCharactersIntent.swift
//  SwiftCompartido
//
//  App Intent for extracting character list from a screenplay.
//

import AppIntents
import Foundation
@preconcurrency import SwiftData

/// Extract the list of characters from a screenplay document.
///
/// This intent enables Shortcuts workflows to retrieve all unique character names
/// from a screenplay, which is essential for voice assignment workflows.
///
/// **Key Features**:
/// - Extracts character names from dialogue and character elements
/// - Returns sorted alphabetical list
/// - Includes character info (name + dialogue count)
///
/// **Example Workflow**:
/// ```
/// Parse Screenplay File (script.fountain)
/// → Extract Characters
/// → For each character: Assign voice
/// → Generate audio for all dialogue
/// ```
@available(iOS 26.0, macOS 26.0, *)
public struct ExtractCharactersIntent: AppIntent {

  public static let title: LocalizedStringResource = "Extract Characters"

  public static let description = IntentDescription(
    "Extract the list of characters from a screenplay document for voice assignment workflows."
  )

  public static let openAppWhenRun: Bool = false

  // MARK: - Parameters

  @Parameter(
    title: "Document ID",
    description: "The persistent identifier of the screenplay document (as JSON-encoded string)"
  )
  public var documentIDString: String

  @Parameter(
    title: "Include Dialogue Count",
    description: "Include the number of dialogue lines for each character",
    default: true
  )
  public var includeDialogueCount: Bool

  // MARK: - Initializer

  public init() {
    self.documentIDString = ""
    self.includeDialogueCount = true
  }

  public init(
    documentIDString: String,
    includeDialogueCount: Bool = true
  ) {
    self.documentIDString = documentIDString
    self.includeDialogueCount = includeDialogueCount
  }

  // MARK: - Perform

  @MainActor
  public func perform() async throws -> some IntentResult & ReturnsValue<CharacterListReference> {
    // Step 1: Parse documentID from string
    guard let documentID = try? parsePersistentIdentifier(from: documentIDString) else {
      throw ExtractError.invalidDocumentID
    }

    // Step 2: Retrieve document
    let service = ParsedFileService.shared
    let document = try await service.document(id: documentID)

    // Step 3: Extract characters using existing API
    let characterList = document.extractCharacters()

    // Step 4: Create character references
    var characterRefs: [CharacterReference] = []

    for (name, info) in characterList {
      let dialogueCount: Int?
      if includeDialogueCount {
        // Count dialogue lines for this character
        dialogueCount =
          document.sortedElements.filter {
            $0.elementType == .dialogue && extractCharacterName(from: $0) == name
          }.count
      } else {
        dialogueCount = nil
      }

      characterRefs.append(
        CharacterReference(
          name: name,
          aliases: [],  // CharacterInfo doesn't track aliases
          dialogueCount: dialogueCount
        ))
    }

    // Step 5: Sort alphabetically
    characterRefs.sort { $0.name < $1.name }

    // Step 6: Create reference
    let reference = CharacterListReference(
      documentID: documentID,
      documentTitle: document.title,
      characters: characterRefs
    )

    return .result(value: reference)
  }

  // MARK: - Helper

  /// Extract character name from dialogue by looking at preceding CHARACTER element
  private func extractCharacterName(from element: GuionElementModel) -> String? {
    guard element.elementType == .dialogue,
      let document = element.document
    else {
      return nil
    }

    // Find preceding CHARACTER element
    let sortedElements = document.sortedElements
    guard let elementIndex = sortedElements.firstIndex(where: { $0.uuid == element.uuid }),
      elementIndex > 0
    else {
      return nil
    }

    // Look backwards for CHARACTER element
    for i in stride(from: elementIndex - 1, through: 0, by: -1) {
      let precedingElement = sortedElements[i]
      if precedingElement.elementType == .character {
        return precedingElement.elementText.trimmingCharacters(in: .whitespacesAndNewlines)
      } else if precedingElement.elementType == .sceneHeading {
        // Stop searching at scene boundaries
        break
      }
    }

    return nil
  }

  /// Parse a PersistentIdentifier from its JSON-encoded string representation
  private func parsePersistentIdentifier(from string: String) throws -> PersistentIdentifier {
    guard let data = string.data(using: .utf8) else {
      throw ExtractError.invalidDocumentID
    }

    let decoder = JSONDecoder()
    do {
      return try decoder.decode(PersistentIdentifier.self, from: data)
    } catch {
      throw ExtractError.invalidDocumentID
    }
  }
}

// MARK: - Character List Reference

/// A transferable reference to a list of characters from a screenplay
@available(iOS 26.0, macOS 26.0, *)
public struct CharacterListReference: Codable, Sendable, Hashable, Identifiable {

  // MARK: - Document Metadata

  public var id: String {
    guard let data = try? JSONEncoder().encode(documentID),
      let idString = String(data: data, encoding: .utf8)
    else {
      return String(describing: documentID)
    }
    return idString
  }

  /// The persistent identifier of the source document
  public let documentID: PersistentIdentifier

  /// The title of the screenplay document
  public let documentTitle: String?

  // MARK: - Character Data

  /// Array of character references
  public let characters: [CharacterReference]

  // MARK: - Computed Properties

  /// Total number of characters
  public var characterCount: Int {
    characters.count
  }

  /// Character names only (sorted)
  public var characterNames: [String] {
    characters.map { $0.name }
  }

  // MARK: - Initializer

  public init(
    documentID: PersistentIdentifier,
    documentTitle: String?,
    characters: [CharacterReference]
  ) {
    self.documentID = documentID
    self.documentTitle = documentTitle
    self.characters = characters
  }
}

// MARK: - Character Reference

/// A reference to a single character in a screenplay
@available(iOS 26.0, macOS 26.0, *)
public struct CharacterReference: Codable, Sendable, Hashable, Identifiable {

  public var id: String { name }

  /// The character name
  public let name: String

  /// Alternative names/aliases for this character
  public let aliases: [String]

  /// Number of dialogue lines (optional)
  public let dialogueCount: Int?

  public init(
    name: String,
    aliases: [String] = [],
    dialogueCount: Int? = nil
  ) {
    self.name = name
    self.aliases = aliases
    self.dialogueCount = dialogueCount
  }
}

// MARK: - AppEntity Conformance

@available(iOS 26.0, macOS 26.0, *)
extension CharacterListReference: AppEntity {
  public static var typeDisplayRepresentation: TypeDisplayRepresentation {
    TypeDisplayRepresentation(name: "Character List")
  }

  public var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: "\(documentTitle ?? "Untitled Screenplay")",
      subtitle: "\(characterCount) characters"
    )
  }

  public static var defaultQuery: CharacterListReferenceQuery {
    CharacterListReferenceQuery()
  }
}

/// Query for CharacterListReference entities
@available(iOS 26.0, macOS 26.0, *)
public struct CharacterListReferenceQuery: EntityQuery {
  public init() {}

  public func entities(for identifiers: [String]) async throws -> [CharacterListReference] {
    // Not supported - these are transient intent results
    return []
  }

  public func suggestedEntities() async throws -> [CharacterListReference] {
    // Not supported - these are transient intent results
    return []
  }
}

// MARK: - Errors

@available(iOS 26.0, macOS 26.0, *)
extension ExtractCharactersIntent {
  enum ExtractError: LocalizedError {
    case invalidDocumentID

    var errorDescription: String? {
      switch self {
      case .invalidDocumentID:
        return "The provided document ID is invalid or cannot be parsed."
      }
    }
  }
}
