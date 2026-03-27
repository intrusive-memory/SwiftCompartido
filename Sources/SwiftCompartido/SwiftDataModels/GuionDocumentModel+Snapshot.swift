//
//  GuionDocumentModel+Snapshot.swift
//  SwiftCompartido
//
//  Conversion extensions between SwiftData models and Codable snapshots (Phase 1)
//

import Foundation

#if canImport(SwiftData)
  @preconcurrency import SwiftData

  // MARK: - GuionDocumentModel → Snapshot

  extension GuionDocumentModel {
    /// Convert this SwiftData model to a Codable snapshot
    ///
    /// This creates a plain Codable struct suitable for JSON serialization.
    /// Used by NSDocument/UIDocument to save .guion files.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let snapshot = document.toSnapshot()
    /// let data = try JSONEncoder().encode(snapshot)
    /// try data.write(to: url)
    /// ```
    ///
    /// - Returns: Snapshot ready for JSON serialization
    public func toSnapshot() -> GuionDocumentSnapshot {
      GuionDocumentSnapshot(
        id: UUID(),  // Generate new UUID for snapshot (SwiftData ID not serializable)
        filename: filename,
        title: title,
        created: nil,  // Not tracked in current model
        modified: Date(),  // Current timestamp
        suppressSceneNumbers: suppressSceneNumbers,
        elements: sortedElements.map { $0.toSnapshot() },
        titlePage: titlePage.map { $0.toSnapshot() },
        customPages: customPages.isEmpty ? nil : customPages.map { $0.toSnapshot() },
        generatedContent: generatedContentSnapshot(),
        casting: castingSnapshot(),
        sourceFileBookmark: sourceFileBookmark,
        lastImportDate: lastImportDate,
        sourceFileModificationDate: sourceFileModificationDate,
        lastOpenedDate: lastOpenedDate
      )
    }

    /// Convert generated content to snapshot dictionary
    ///
    /// - Returns: Dictionary mapping content UUID to snapshot, or nil if no content
    private func generatedContentSnapshot() -> [UUID: TypedDataStorageSnapshot]? {
      guard let content = generatedContent, !content.isEmpty else {
        return nil
      }

      var result: [UUID: TypedDataStorageSnapshot] = [:]
      for item in content {
        result[item.id] = item.toSnapshot()
      }
      return result
    }

    /// Convert casting to snapshot dictionary
    ///
    /// - Returns: Dictionary mapping character name to voice mapping snapshot, or nil if no casting
    private func castingSnapshot() -> [String: CharacterVoiceMappingSnapshot]? {
      guard let mappings = casting, !mappings.isEmpty else {
        return nil
      }

      var result: [String: CharacterVoiceMappingSnapshot] = [:]
      for mapping in mappings {
        result[mapping.characterName] = mapping.toSnapshot()
      }
      return result
    }

    /// Create SwiftData model from a Codable snapshot
    ///
    /// This converts a snapshot loaded from a .guion JSON file back into
    /// a SwiftData model for persistence.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let data = try Data(contentsOf: url)
    /// let snapshot = try JSONDecoder().decode(GuionDocumentSnapshot.self, from: data)
    /// let document = GuionDocumentModel.from(snapshot, in: modelContext)
    /// modelContext.insert(document)
    /// ```
    ///
    /// - Parameters:
    ///   - snapshot: Snapshot loaded from JSON
    ///   - context: SwiftData model context
    /// - Returns: SwiftData model ready for insertion
    @MainActor
    public static func from(
      _ snapshot: GuionDocumentSnapshot,
      in context: ModelContext
    ) -> GuionDocumentModel {
      let document = GuionDocumentModel(
        filename: snapshot.filename,
        rawContent: nil,  // Raw content not stored in snapshots
        suppressSceneNumbers: snapshot.suppressSceneNumbers
      )

      document.title = snapshot.title
      document.sourceFileBookmark = snapshot.sourceFileBookmark
      document.lastImportDate = snapshot.lastImportDate
      document.sourceFileModificationDate = snapshot.sourceFileModificationDate
      document.lastOpenedDate = snapshot.lastOpenedDate

      // Convert elements
      document.elements = snapshot.elements.map { elementSnapshot in
        GuionElementModel.from(elementSnapshot, in: context, document: document)
      }

      // Convert title page
      document.titlePage = snapshot.titlePage.map { entrySnapshot in
        TitlePageEntryModel.from(entrySnapshot, document: document)
      }

      // Convert custom pages
      if let customPagesSnapshot = snapshot.customPages {
        document.customPages = customPagesSnapshot.map { pageSnapshot in
          CustomPageModel.from(pageSnapshot, document: document)
        }
      }

      // Convert generated content
      if let contentSnapshot = snapshot.generatedContent {
        document.generatedContent = contentSnapshot.values.map { snapshot in
          TypedDataStorage.from(snapshot, in: context, owningDocument: document)
        }
      }

      // Convert casting
      if let castingSnapshot = snapshot.casting {
        document.casting = castingSnapshot.map { (characterName, voiceSnapshot) in
          CharacterVoiceMapping.from(
            characterName: characterName, voiceSnapshot, document: document)
        }
      }

      return document
    }
  }

  // MARK: - GuionElementModel → Snapshot

  extension GuionElementModel {
    /// Convert this SwiftData model to a Codable snapshot
    ///
    /// - Returns: Snapshot ready for JSON serialization
    public func toSnapshot() -> GuionElementSnapshot {
      GuionElementSnapshot(
        id: uuid,
        chapterIndex: chapterIndex,
        orderIndex: orderIndex,
        elementText: elementText,
        elementType: elementType,
        isCentered: isCentered,
        isDualDialogue: isDualDialogue,
        sceneNumber: sceneNumber,
        sectionDepth: elementType.level,
        sceneId: sceneId,
        summary: summary,
        cachedSceneLocation: cachedSceneLocation,
        generatedContent: generatedContentSnapshot()
      )
    }

    /// Convert generated content to snapshot dictionary
    private func generatedContentSnapshot() -> [UUID: TypedDataStorageSnapshot]? {
      guard let content = generatedContent, !content.isEmpty else {
        return nil
      }

      var result: [UUID: TypedDataStorageSnapshot] = [:]
      for item in content {
        result[item.id] = item.toSnapshot()
      }
      return result
    }

    /// Create SwiftData model from a Codable snapshot
    ///
    /// - Parameters:
    ///   - snapshot: Snapshot loaded from JSON
    ///   - context: SwiftData model context
    ///   - document: Parent document (for relationship)
    /// - Returns: SwiftData model ready for insertion
    @MainActor
    public static func from(
      _ snapshot: GuionElementSnapshot,
      in context: ModelContext,
      document: GuionDocumentModel? = nil
    ) -> GuionElementModel {
      let element = GuionElementModel(
        elementText: snapshot.elementText,
        elementType: snapshot.elementType,
        isCentered: snapshot.isCentered,
        isDualDialogue: snapshot.isDualDialogue,
        sceneNumber: snapshot.sceneNumber,
        sectionDepth: snapshot.sectionDepth,
        summary: snapshot.summary,
        sceneId: snapshot.sceneId,
        chapterIndex: snapshot.chapterIndex,
        orderIndex: snapshot.orderIndex,
        uuid: snapshot.id  // Preserve stable UUID from snapshot
      )

      element.document = document

      // Note: cachedSceneLocation is a computed property in GuionElementModel,
      // so it will be automatically re-computed when needed

      // Convert generated content
      if let contentSnapshot = snapshot.generatedContent {
        element.generatedContent = contentSnapshot.values.map { snapshot in
          TypedDataStorage.from(snapshot, in: context, owningElement: element)
        }
      }

      return element
    }
  }

  // MARK: - TitlePageEntryModel → Snapshot

  extension TitlePageEntryModel {
    /// Convert this SwiftData model to a Codable snapshot
    ///
    /// - Returns: Snapshot ready for JSON serialization
    public func toSnapshot() -> TitlePageEntrySnapshot {
      TitlePageEntrySnapshot(
        key: key,
        values: values
      )
    }

    /// Create SwiftData model from a Codable snapshot
    ///
    /// - Parameters:
    ///   - snapshot: Snapshot loaded from JSON
    ///   - document: Parent document (for relationship)
    /// - Returns: SwiftData model ready for insertion
    public static func from(
      _ snapshot: TitlePageEntrySnapshot,
      document: GuionDocumentModel? = nil
    ) -> TitlePageEntryModel {
      let entry = TitlePageEntryModel(
        key: snapshot.key,
        values: snapshot.values
      )
      entry.document = document
      return entry
    }
  }

  // MARK: - CustomPageModel → Snapshot

  extension CustomPageModel {
    /// Convert this SwiftData model to a Codable snapshot
    ///
    /// - Returns: Snapshot (CustomPageContainer)
    public func toSnapshot() -> CustomPageSnapshot {
      toDTO()  // Already returns CustomPageContainer
    }

    /// Create SwiftData model from a Codable snapshot
    ///
    /// - Parameters:
    ///   - snapshot: Snapshot (CustomPageContainer) loaded from JSON
    ///   - document: Parent document (for relationship)
    /// - Returns: SwiftData model ready for insertion
    public static func from(
      _ snapshot: CustomPageSnapshot,
      document: GuionDocumentModel? = nil
    ) -> CustomPageModel {
      let model = CustomPageModel.from(snapshot)
      model.document = document
      return model
    }
  }

  // MARK: - TypedDataStorage → Snapshot

  extension TypedDataStorage {
    /// Convert this SwiftData model to a Codable snapshot
    ///
    /// - Returns: Snapshot ready for JSON serialization
    public func toSnapshot() -> TypedDataStorageSnapshot {
      TypedDataStorageSnapshot(
        id: id,
        providerId: providerId,
        requestorID: requestorID,
        mimeType: mimeType,
        prompt: prompt,
        textValue: textValue,
        binaryValue: binaryValue,
        modelIdentifier: modelIdentifier,
        estimatedCost: estimatedCost,
        wordCount: wordCount,
        characterCount: characterCount,
        languageCode: languageCode,
        tokenCount: tokenCount,
        completionTokens: completionTokens,
        promptTokens: promptTokens,
        audioFormat: audioFormat,
        durationSeconds: durationSeconds,
        sampleRate: sampleRate,
        bitRate: bitRate,
        channels: channels,
        voiceID: voiceID,
        voiceName: voiceName,
        imageFormat: imageFormat,
        width: width,
        height: height,
        revisedPrompt: revisedPrompt,
        dimensions: dimensions,
        inputText: inputText,
        batchIndex: batchIndex,
        generatedAt: generatedAt,
        modifiedAt: modifiedAt
      )
    }

    /// Create SwiftData model from a Codable snapshot
    ///
    /// - Parameters:
    ///   - snapshot: Snapshot loaded from JSON
    ///   - context: SwiftData model context
    ///   - owningElement: Parent element (for relationship)
    ///   - owningDocument: Parent document (for relationship)
    /// - Returns: SwiftData model ready for insertion
    @MainActor
    public static func from(
      _ snapshot: TypedDataStorageSnapshot,
      in context: ModelContext,
      owningElement: GuionElementModel? = nil,
      owningDocument: GuionDocumentModel? = nil
    ) -> TypedDataStorage {
      let storage = TypedDataStorage(
        id: snapshot.id,
        providerId: snapshot.providerId,
        requestorID: snapshot.requestorID,
        mimeType: snapshot.mimeType,
        textValue: snapshot.textValue,
        binaryValue: snapshot.binaryValue,
        prompt: snapshot.prompt
      )

      storage.modelIdentifier = snapshot.modelIdentifier
      storage.estimatedCost = snapshot.estimatedCost

      // Text metadata
      storage.wordCount = snapshot.wordCount
      storage.characterCount = snapshot.characterCount
      storage.languageCode = snapshot.languageCode
      storage.tokenCount = snapshot.tokenCount
      storage.completionTokens = snapshot.completionTokens
      storage.promptTokens = snapshot.promptTokens

      // Audio metadata
      storage.audioFormat = snapshot.audioFormat
      storage.durationSeconds = snapshot.durationSeconds
      storage.sampleRate = snapshot.sampleRate
      storage.bitRate = snapshot.bitRate
      storage.channels = snapshot.channels
      storage.voiceID = snapshot.voiceID
      storage.voiceName = snapshot.voiceName

      // Image metadata
      storage.imageFormat = snapshot.imageFormat
      storage.width = snapshot.width
      storage.height = snapshot.height
      storage.revisedPrompt = snapshot.revisedPrompt

      // Embedding metadata
      storage.dimensions = snapshot.dimensions
      storage.inputText = snapshot.inputText
      storage.batchIndex = snapshot.batchIndex

      // Timestamps
      storage.generatedAt = snapshot.generatedAt
      storage.modifiedAt = snapshot.modifiedAt

      // Relationships
      storage.owningElement = owningElement
      storage.owningDocument = owningDocument

      return storage
    }
  }

#endif
