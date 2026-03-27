//
//  VoiceCastingIntents.swift
//  SwiftCompartido
//
//  App Intents for managing character voice assignments.
//

import AppIntents
import Foundation
@preconcurrency import SwiftData

// MARK: - Get Voice Casting Intent

/// Retrieve voice casting assignments for a screenplay document.
///
/// This intent returns all character→voice mappings for a document, which is
/// essential for audio generation workflows.
///
/// **Example Workflow**:
/// ```
/// Parse Screenplay File
/// → Get Voice Casting
/// → For each character without voice: Assign voice
/// → Generate audio for all dialogue
/// ```
@available(iOS 26.0, macOS 26.0, *)
public struct GetVoiceCastingIntent: AppIntent {

  public static let title: LocalizedStringResource = "Get Voice Casting"

  public static let description = IntentDescription(
    "Retrieve character voice assignments from a screenplay document."
  )

  public static let openAppWhenRun: Bool = false

  // MARK: - Parameters

  @Parameter(
    title: "Document ID",
    description: "The persistent identifier of the screenplay document (as JSON-encoded string)"
  )
  public var documentIDString: String

  // MARK: - Initializer

  public init() {
    self.documentIDString = ""
  }

  public init(documentIDString: String) {
    self.documentIDString = documentIDString
  }

  // MARK: - Perform

  @MainActor
  public func perform() async throws -> some IntentResult & ReturnsValue<VoiceCastingReference> {
    // Step 1: Parse documentID from string
    guard let documentID = try? parsePersistentIdentifier(from: documentIDString) else {
      throw VoiceCastingError.invalidDocumentID
    }

    // Step 2: Retrieve document
    let service = ParsedFileService.shared
    let document = try await service.document(id: documentID)

    // Step 3: Extract voice mappings
    var mappings: [VoiceMappingReference] = []

    if let casting = document.casting {
      for mapping in casting {
        mappings.append(
          VoiceMappingReference(
            characterName: mapping.characterName,
            voiceURI: mapping.voiceURI,
            voiceName: mapping.voiceName,
            providerID: mapping.providerID
          ))
      }
    }

    // Step 4: Sort by character name
    mappings.sort { $0.characterName < $1.characterName }

    // Step 5: Create reference
    let reference = VoiceCastingReference(
      documentID: documentID,
      documentTitle: document.title,
      mappings: mappings
    )

    return .result(value: reference)
  }

  // MARK: - Helper

  private func parsePersistentIdentifier(from string: String) throws -> PersistentIdentifier {
    guard let data = string.data(using: .utf8) else {
      throw VoiceCastingError.invalidDocumentID
    }

    let decoder = JSONDecoder()
    do {
      return try decoder.decode(PersistentIdentifier.self, from: data)
    } catch {
      throw VoiceCastingError.invalidDocumentID
    }
  }
}

// MARK: - Set Voice Casting Intent

/// Assign a voice to a character in a screenplay document.
///
/// This intent creates or updates a character→voice mapping for audio generation.
///
/// **Example Workflow**:
/// ```
/// Extract Characters
/// → For each character:
///     - Ask user to select voice
///     - Set Voice Casting (character: name, voice: selected)
/// → Generate audio for all dialogue
/// ```
@available(iOS 26.0, macOS 26.0, *)
public struct SetVoiceCastingIntent: AppIntent {

  public static let title: LocalizedStringResource = "Set Voice Casting"

  public static let description = IntentDescription(
    "Assign a voice to a character in a screenplay document for audio generation."
  )

  public static let openAppWhenRun: Bool = false

  // MARK: - Parameters

  @Parameter(
    title: "Document ID",
    description: "The persistent identifier of the screenplay document (as JSON-encoded string)"
  )
  public var documentIDString: String

  @Parameter(
    title: "Character Name",
    description: "The character to assign a voice to (e.g., 'JANE')"
  )
  public var characterName: String

  @Parameter(
    title: "Voice URI",
    description:
      "Voice identifier (e.g., 'macos://Samantha?lang=en', 'elevenlabs://voice-id?lang=en')"
  )
  public var voiceURI: String

  @Parameter(
    title: "Voice Name",
    description: "Human-readable voice name (e.g., 'Samantha', 'Rachel')"
  )
  public var voiceName: String

  @Parameter(
    title: "Provider ID",
    description: "Provider identifier (e.g., 'macos', 'elevenlabs', 'openai')"
  )
  public var providerID: String

  // MARK: - Initializer

  public init() {
    self.documentIDString = ""
    self.characterName = ""
    self.voiceURI = ""
    self.voiceName = ""
    self.providerID = ""
  }

  public init(
    documentIDString: String,
    characterName: String,
    voiceURI: String,
    voiceName: String,
    providerID: String
  ) {
    self.documentIDString = documentIDString
    self.characterName = characterName
    self.voiceURI = voiceURI
    self.voiceName = voiceName
    self.providerID = providerID
  }

  // MARK: - Perform

  @MainActor
  public func perform() async throws -> some IntentResult {
    // Step 1: Parse documentID from string
    guard let documentID = try? parsePersistentIdentifier(from: documentIDString) else {
      throw VoiceCastingError.invalidDocumentID
    }

    // Step 2: Retrieve document
    let service = ParsedFileService.shared
    let document = try await service.document(id: documentID)

    // Step 3: Get ModelContext from document
    guard let modelContext = document.modelContext else {
      throw VoiceCastingError.saveFailed(
        NSError(
          domain: "VoiceCastingIntents", code: -1,
          userInfo: [
            NSLocalizedDescriptionKey: "Document has no model context"
          ]))
    }

    // Step 4: Find or create voice mapping
    if let existingMapping = document.casting?.first(where: { $0.characterName == characterName }) {
      // Update existing mapping
      existingMapping.voiceURI = voiceURI
      existingMapping.voiceName = voiceName
      existingMapping.providerID = providerID
    } else {
      // Create new mapping
      let newMapping = CharacterVoiceMapping(
        characterName: characterName,
        voiceURI: voiceURI,
        voiceName: voiceName,
        providerID: providerID
      )
      newMapping.document = document

      // Initialize casting array if needed
      if document.casting == nil {
        document.casting = []
      }
      document.casting?.append(newMapping)
      modelContext.insert(newMapping)
    }

    // Step 5: Save changes
    do {
      try modelContext.save()
    } catch {
      throw VoiceCastingError.saveFailed(error)
    }

    return .result(
      dialog: "Assigned \(voiceName) to \(characterName)"
    )
  }

  // MARK: - Helper

  private func parsePersistentIdentifier(from string: String) throws -> PersistentIdentifier {
    guard let data = string.data(using: .utf8) else {
      throw VoiceCastingError.invalidDocumentID
    }

    let decoder = JSONDecoder()
    do {
      return try decoder.decode(PersistentIdentifier.self, from: data)
    } catch {
      throw VoiceCastingError.invalidDocumentID
    }
  }
}

// MARK: - Voice Casting Reference

/// A transferable reference to voice casting assignments
@available(iOS 26.0, macOS 26.0, *)
public struct VoiceCastingReference: Codable, Sendable, Hashable, Identifiable {

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

  // MARK: - Voice Mapping Data

  /// Array of voice mappings
  public let mappings: [VoiceMappingReference]

  // MARK: - Computed Properties

  /// Total number of voice mappings
  public var mappingCount: Int {
    mappings.count
  }

  /// Character names with assigned voices (sorted)
  public var assignedCharacters: [String] {
    mappings.map { $0.characterName }.sorted()
  }

  // MARK: - Initializer

  public init(
    documentID: PersistentIdentifier,
    documentTitle: String?,
    mappings: [VoiceMappingReference]
  ) {
    self.documentID = documentID
    self.documentTitle = documentTitle
    self.mappings = mappings
  }

  // MARK: - Query Methods

  /// Get voice mapping for a specific character
  public func voiceMapping(for character: String) -> VoiceMappingReference? {
    mappings.first { $0.characterName.uppercased() == character.uppercased() }
  }
}

// MARK: - Voice Mapping Reference

/// A reference to a single character→voice mapping
@available(iOS 26.0, macOS 26.0, *)
public struct VoiceMappingReference: Codable, Sendable, Hashable, Identifiable {

  public var id: String { characterName }

  /// Character name (e.g., "JANE")
  public let characterName: String

  /// Voice URI (e.g., "macos://Samantha")
  public let voiceURI: String

  /// Human-readable voice name (e.g., "Samantha")
  public let voiceName: String

  /// Provider ID (e.g., "macos", "elevenlabs")
  public let providerID: String

  public init(
    characterName: String,
    voiceURI: String,
    voiceName: String,
    providerID: String
  ) {
    self.characterName = characterName
    self.voiceURI = voiceURI
    self.voiceName = voiceName
    self.providerID = providerID
  }
}

// MARK: - AppEntity Conformance

@available(iOS 26.0, macOS 26.0, *)
extension VoiceCastingReference: AppEntity {
  public static var typeDisplayRepresentation: TypeDisplayRepresentation {
    TypeDisplayRepresentation(name: "Voice Casting")
  }

  public var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: "\(documentTitle ?? "Untitled Screenplay")",
      subtitle: "\(mappingCount) voice assignments"
    )
  }

  public static var defaultQuery: VoiceCastingReferenceQuery {
    VoiceCastingReferenceQuery()
  }
}

/// Query for VoiceCastingReference entities
@available(iOS 26.0, macOS 26.0, *)
public struct VoiceCastingReferenceQuery: EntityQuery {
  public init() {}

  public func entities(for identifiers: [String]) async throws -> [VoiceCastingReference] {
    // Not supported - these are transient intent results
    return []
  }

  public func suggestedEntities() async throws -> [VoiceCastingReference] {
    // Not supported - these are transient intent results
    return []
  }
}

// MARK: - Errors

@available(iOS 26.0, macOS 26.0, *)
enum VoiceCastingError: LocalizedError {
  case invalidDocumentID
  case saveFailed(Error)

  var errorDescription: String? {
    switch self {
    case .invalidDocumentID:
      return "The provided document ID is invalid or cannot be parsed."
    case .saveFailed(let error):
      return "Failed to save voice casting: \(error.localizedDescription)"
    }
  }
}
