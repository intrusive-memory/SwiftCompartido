//
//  DocumentModelActor.swift
//  SwiftCompartido
//
//  SwiftData actor for safe concurrent database operations
//
//  This actor provides isolated access to SwiftData for operations that don't need MainActor,
//  preventing data races and concurrency conflicts during parsing and batch operations.
//

import Foundation
import GlosaCore
@preconcurrency import SwiftData
import os

/// Logger for glosa annotation diagnostics. Glosa data is never persisted as
/// diagnostics on the model — it is surfaced here per the consumer-integration
/// plan (RISK-1: glosa owns stripping/diagnostics, the consumer only logs).
private let glosaLog = Logger(subsystem: "SwiftCompartido", category: "glosa")

/// Actor for safe SwiftData operations off the main thread
///
/// ## Purpose
/// Isolates database writes/reads to prevent concurrent access conflicts.
/// Particularly important for:
/// - Document parsing and import (avoiding forced-sync warnings)
/// - Heavy queries that would block UI
/// - Background operations
///
/// ## Usage Pattern
/// ```swift
/// let actor = DocumentModelActor(modelContainer: sharedModelContainer)
///
/// // Parse and save document in background
/// let documentID = try await actor.parseAndSaveDocument(
///     from: url,
///     progress: progress
/// )
///
/// // Fetch on MainActor for display
/// await MainActor.run {
///     let document = modelContext.model(for: documentID)
///     // Update UI with document
/// }
/// ```
///
/// ## Key Principles
/// - Never pass Model instances between actors (use PersistentIdentifier)
/// - Each actor has its own ModelContext from shared ModelContainer
/// - Return plain data types (Bool, String, PersistentIdentifier, etc.) not model objects
/// - UI updates happen on MainActor after actor operations complete
@ModelActor
public actor DocumentModelActor {

  // MARK: - Document Operations

  /// Parse and save a screenplay document from a file
  /// - Parameters:
  ///   - url: URL of the screenplay file to parse
  ///   - progress: Optional progress tracker
  ///   - parseGlosa: When `true` (default), runs the GlosaCore annotation pass
  ///     over the imported dialogue and stores the compiled glosa fields on each
  ///     ``GuionElementModel``. Glosa failure never aborts the import.
  /// - Returns: Persistent identifier of the created document
  public func parseAndSaveDocument(
    from url: URL,
    progress: OperationProgress? = nil,
    parseGlosa: Bool = true
  ) async throws -> PersistentIdentifier {
    // Parse the screenplay
    let screenplay = try await GuionParsedElementCollection(file: url.path, progress: progress)

    // Convert to SwiftData model (use GuionDocumentModel.from directly to avoid actor isolation issues)
    let document = await GuionDocumentModel.from(
      screenplay,
      in: modelContext,
      generateSummaries: false,
      progress: progress
    )

    // Annotate dialogue with glosa data (graceful — never aborts import)
    if parseGlosa {
      annotateGlosa(document: document)
    }

    // Insert and save
    modelContext.insert(document)
    try modelContext.save()

    return document.persistentModelID
  }

  /// Parse and save a screenplay document from a string
  /// - Parameters:
  ///   - string: Fountain screenplay text
  ///   - title: Optional title for the document
  ///   - progress: Optional progress tracker
  /// - Returns: Persistent identifier of the created document
  public func parseAndSaveDocument(
    from string: String,
    title: String? = nil,
    progress: OperationProgress? = nil,
    parseGlosa: Bool = true
  ) async throws -> PersistentIdentifier {
    // Parse the screenplay
    let screenplay = try await GuionParsedElementCollection(string: string, progress: progress)

    // Convert to SwiftData model (use GuionDocumentModel.from directly to avoid actor isolation issues)
    let document = await GuionDocumentModel.from(
      screenplay,
      in: modelContext,
      generateSummaries: false,
      progress: progress
    )

    // Set title if provided
    if let title = title {
      document.title = title
    }

    // Annotate dialogue with glosa data (graceful — never aborts import)
    if parseGlosa {
      annotateGlosa(document: document)
    }

    // Insert and save
    modelContext.insert(document)
    try modelContext.save()

    return document.persistentModelID
  }

  // MARK: - Glosa Annotation Pass

  /// Runs the GlosaCore annotation pass over the document's dialogue elements
  /// and writes the compiled DTO fields back onto each ``GuionElementModel``.
  ///
  /// Executes on the `@ModelActor` context (no model instances cross actor
  /// boundaries). Raw `elementText` (with inline `[[ … ]]` markers intact) is
  /// forwarded to ``GlosaCore`` — stripping is *never* performed locally
  /// (RISK-1); GlosaCore owns that logic.
  ///
  /// Graceful degradation: any throw or unexpected condition is logged and the
  /// glosa fields are left `nil`. A glosa failure must never abort the import.
  private func annotateGlosa(document: GuionDocumentModel) {
    // Elements in document order: (chapterIndex, orderIndex)
    let ordered = document.sortedElements

    // Dialogue elements in document order — these receive glosa annotations.
    let dialogueElements = ordered.filter { $0.elementType == .dialogue }
    guard !dialogueElements.isEmpty else { return }

    // Build fountainNotes in document order. GlosaCore parses this stream to
    // recover the GLOSA score, then maps breath/pause seams back onto the
    // dialogue lines that appear *inside* each `<Intent>` block.
    //
    //  - standalone `[[ ]]` GLOSA directive notes surface as `.comment`
    //    elements (the SwiftCompartido parser strips the outer `[[ ]]`); they
    //    carry the `<SceneContext>` / `<Intent>` structural tags.
    //  - dialogue lines must appear in the stream with their inline
    //    `[[<breath …/>]]` / `[[<pause …/>]]` markers *intact* so the compiler
    //    can place seams. We forward the dialogue element's RAW `elementText`
    //    (markers preserved) — never strip locally (RISK-1); GlosaCore owns
    //    stripping. `elementText` is left untouched on the model for lossless
    //    export.
    var fountainNotes: [String] = []
    for element in ordered {
      switch element.elementType {
      case .comment:
        fountainNotes.append(element.elementText)
      case .dialogue:
        fountainNotes.append(element.elementText)
      default:
        break
      }
    }

    // Build rawDialogueLines with the *raw* elementText (markers intact). The
    // preceding `.character` element (if any) supplies the speaker name.
    var rawDialogueLines: [(character: String, rawText: String)] = []
    var lastCharacter = ""
    for element in ordered {
      switch element.elementType {
      case .character:
        lastCharacter = element.elementText
      case .dialogue:
        rawDialogueLines.append((character: lastCharacter, rawText: element.elementText))
      default:
        break
      }
    }

    do {
      let annotations = try compileAnnotations(
        fountainNotes: fountainNotes,
        rawDialogueLines: rawDialogueLines
      )

      // Write each DTO onto the matching dialogue element at its orderIndex.
      for (i, element) in dialogueElements.enumerated() {
        guard let dto = annotations[i] else { continue }
        element.glosaSpokenText = dto.spokenText
        element.glosaBreathOffsets = dto.breathOffsets
        element.glosaBreathStrengths = dto.breathStrengths
        element.glosaInstruct = dto.instruct
        element.glosaPausePoints = try? JSONEncoder().encode(dto.pausePoints)
      }

      glosaLog.info(
        "Glosa annotation pass complete: \(dialogueElements.count, privacy: .public) dialogue line(s) annotated."
      )
    } catch {
      // Graceful degradation: log and leave glosa fields nil. Import continues.
      glosaLog.error(
        "Glosa annotation pass failed; leaving glosa fields nil: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  /// Get document basic info (Sendable DTO)
  /// - Parameter documentID: Persistent identifier of the document
  /// - Returns: DocumentInfo struct or nil if not found
  public func getDocumentInfo(documentID: PersistentIdentifier) -> DocumentInfo? {
    guard let document = modelContext.model(for: documentID) as? GuionDocumentModel else {
      return nil
    }

    return DocumentInfo(
      id: document.persistentModelID,
      title: document.title,
      elementCount: document.elements.count
    )
  }

  /// Delete a document
  /// - Parameter documentID: Persistent identifier of the document
  public func deleteDocument(documentID: PersistentIdentifier) throws {
    guard let document = modelContext.model(for: documentID) as? GuionDocumentModel else {
      throw DocumentModelActorError.documentNotFound
    }

    modelContext.delete(document)
    try modelContext.save()
  }

  // MARK: - Element Operations

  /// Get elements for a document (as Sendable DTOs)
  /// - Parameters:
  ///   - documentID: Persistent identifier of the document
  ///   - limit: Optional limit on number of elements to return
  /// - Returns: Array of ElementInfo structs
  public func getElements(
    for documentID: PersistentIdentifier,
    limit: Int? = nil
  ) throws -> [ElementInfo] {
    guard let document = modelContext.model(for: documentID) as? GuionDocumentModel else {
      throw DocumentModelActorError.documentNotFound
    }

    // Get elements in sorted order (by chapterIndex, then orderIndex)
    let elements = document.sortedElements
    let limitedElements = limit.map { Array(elements.prefix($0)) } ?? elements

    // Convert to DTOs, preserving sort order
    let elementInfos = limitedElements.map { element in
      ElementInfo(
        id: element.persistentModelID,
        elementType: element.elementType,
        elementText: element.elementText,
        chapterIndex: element.chapterIndex,
        orderIndex: element.orderIndex
      )
    }

    // Ensure elements are sorted by composite key (chapterIndex, orderIndex)
    // This guarantees document order even if SwiftData relationship order changes
    return elementInfos.sorted { lhs, rhs in
      if lhs.chapterIndex != rhs.chapterIndex {
        return lhs.chapterIndex < rhs.chapterIndex
      }
      return lhs.orderIndex < rhs.orderIndex
    }
  }

  /// Check if a document exists
  /// - Parameter documentID: Persistent identifier of the document
  /// - Returns: True if document exists, false otherwise
  public func documentExists(documentID: PersistentIdentifier) -> Bool {
    return (modelContext.model(for: documentID) as? GuionDocumentModel) != nil
  }

  // MARK: - Character Operations (CP-P2)

  /// Extract all speaking characters across all documents in the store.
  ///
  /// Aggregates character information across every screenplay document, providing
  /// complete metadata for multi-episode series or document collections.
  ///
  /// A character is defined as any distinct speaker value (dialogue or parenthetical
  /// elements with a non-nil, non-empty speaker field). Unnamed cues like "BARTENDER"
  /// or "COP #1" are treated as distinct characters.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// let actor = DocumentModelActor(modelContainer: container)
  /// let result = try await actor.extractAllCharacters()
  ///
  /// for (name, info) in result.characters {
  ///     print("\(name): \(info.lineCount) lines across \(info.documents.count) episodes")
  /// }
  /// ```
  ///
  /// - Returns: CharacterCollectionResult with aggregated character metadata
  /// - Throws: SwiftData errors if the query fails
  public func extractAllCharacters() throws -> CharacterCollectionResult {
    // Fetch all documents, sorted by title for deterministic ordering
    let descriptor = FetchDescriptor<GuionDocumentModel>(
      sortBy: [SortDescriptor(\.title)]
    )
    let documents = try modelContext.fetch(descriptor)

    // Character accumulator: [speakerName: CharacterData]
    var characterData: [String: CharacterData] = [:]

    // Process each document
    for document in documents {
      let documentID = String(describing: document.persistentModelID)
      let documentTitle = document.title ?? document.filename ?? "Untitled"

      // Get all elements with speaker assigned (dialogue and parenthetical)
      // Sorted by (chapterIndex, orderIndex) for deterministic ordering
      let speakingElements = document.sortedElements.filter { element in
        guard let speaker = element.speaker, !speaker.isEmpty else {
          return false
        }
        return element.elementType == .dialogue || element.elementType == .parenthetical
      }

      // Process each speaking element
      for element in speakingElements {
        guard let speaker = element.speaker else { continue }

        // Initialize character data if needed
        if characterData[speaker] == nil {
          characterData[speaker] = CharacterData(name: speaker)
        }

        // Update counts based on element type
        if element.elementType == .dialogue {
          characterData[speaker]!.lineCount += 1
          characterData[speaker]!.wordCount += countWords(in: element.elementText)
        } else if element.elementType == .parenthetical {
          // Parentheticals contribute to word count but not line count
          characterData[speaker]!.wordCount += countWords(in: element.elementText)
        }

        // Track scene ID if present
        if let sceneId = element.sceneId, !sceneId.isEmpty {
          characterData[speaker]!.sceneIds.insert(sceneId)
        }

        // Track document
        let docInfo = StoreCharacterInfo.DocumentInfo(id: documentID, title: documentTitle)
        if !characterData[speaker]!.documents.contains(where: { $0.id == documentID }) {
          characterData[speaker]!.documents.append(docInfo)
        }

        // Track first line (only for dialogue, earliest by document order → scene → orderIndex)
        if element.elementType == .dialogue {
          if characterData[speaker]!.firstLine == nil {
            characterData[speaker]!.firstLine = StoreCharacterInfo.FirstLineInfo(
              text: element.elementText,
              documentTitle: documentTitle,
              sceneId: element.sceneId
            )
          }
        }
      }
    }

    // Convert accumulated data to result format
    let characters = characterData.mapValues { data in
      StoreCharacterInfo(
        name: data.name,
        lineCount: data.lineCount,
        wordCount: data.wordCount,
        sceneIds: Array(data.sceneIds).sorted(),
        documents: data.documents,
        firstLine: data.firstLine
      )
    }

    return CharacterCollectionResult(characters: characters)
  }

  // MARK: - Private Helpers

  /// Count words in a string (same logic as GuionParsedElementCollection)
  private func countWords(in text: String) -> Int {
    let words = text.components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
    return words.count
  }

  /// Accumulator for character data during aggregation
  private struct CharacterData {
    let name: String
    var lineCount: Int = 0
    var wordCount: Int = 0
    var sceneIds: Set<String> = []
    var documents: [StoreCharacterInfo.DocumentInfo] = []
    var firstLine: StoreCharacterInfo.FirstLineInfo?
  }

  // MARK: - Helper Types

  /// Sendable DTO for document information
  public struct DocumentInfo: Sendable, Identifiable {
    public let id: PersistentIdentifier
    public let title: String?
    public let elementCount: Int
  }

  /// Sendable DTO for element information
  public struct ElementInfo: Sendable, Identifiable {
    public let id: PersistentIdentifier
    public let elementType: ElementType
    public let elementText: String
    public let chapterIndex: Int
    public let orderIndex: Int
  }
}

// MARK: - DisplayableElement Conformance

@available(iOS 26.0, macOS 26.0, *)
extension DocumentModelActor.ElementInfo: DisplayableElement {
  /// DTOs don't pre-compute formatted text
  /// Views will format at runtime using FountainTextFormatter
  public var formattedText: AttributedString? {
    return nil
  }
}

// MARK: - Errors

public enum DocumentModelActorError: LocalizedError {
  case documentNotFound
  case elementNotFound
  case invalidData
  case parseError(String)

  public var errorDescription: String? {
    switch self {
    case .documentNotFound:
      return "Document not found in database"
    case .elementNotFound:
      return "Element not found in database"
    case .invalidData:
      return "Invalid data provided for operation"
    case .parseError(let message):
      return "Parse error: \(message)"
    }
  }
}
