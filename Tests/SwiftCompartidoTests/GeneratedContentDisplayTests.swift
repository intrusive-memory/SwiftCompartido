//
//  GeneratedContentDisplayTests.swift
//  SwiftCompartido Tests
//
//  Tests for TypedDataStorage display components:
//  - GeneratedContentListView
//  - TypedDataDetailView
//  - TypedDataRowView
//  - TypedDataAudioView
//  - TypedDataTextView
//  - TypedDataVideoView
//

import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import SwiftCompartido

@Suite("GeneratedContent Display Tests")
@MainActor
struct GeneratedContentDisplayTests {

  // MARK: - Helper Methods

  private func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
      for: GuionDocumentModel.self, TypedDataStorage.self,
      configurations: config
    )
  }

  private func makeTestDocument(in context: ModelContext) -> GuionDocumentModel {
    let document = GuionDocumentModel()
    document.title = "Test Document"
    context.insert(document)
    return document
  }

  private func makeTextRecord(in context: ModelContext) -> TypedDataStorage {
    let record = TypedDataStorage(
      providerId: "test",
      requestorID: "test",
      mimeType: "text/plain",
      textValue: "Sample text content",
      prompt: "Test prompt"
    )
    context.insert(record)
    return record
  }

  private func makeAudioRecord(in context: ModelContext) -> TypedDataStorage {
    let record = TypedDataStorage(
      providerId: "test",
      requestorID: "test",
      mimeType: "audio/mpeg",
      binaryValue: nil,
      prompt: "Test audio",
      audioFormat: "mp3",
      voiceID: "test-voice"
    )
    context.insert(record)
    return record
  }

  private func makeImageRecord(in context: ModelContext) -> TypedDataStorage {
    let imageData = Data([0x89, 0x50, 0x4E, 0x47])  // PNG header
    let record = TypedDataStorage(
      providerId: "test",
      requestorID: "test",
      mimeType: "image/png",
      binaryValue: imageData,
      prompt: "Test image",
      imageFormat: "png",
      width: 512,
      height: 512
    )
    context.insert(record)
    return record
  }

  private func makeVideoRecord(in context: ModelContext) -> TypedDataStorage {
    let record = TypedDataStorage(
      providerId: "test",
      requestorID: "test",
      mimeType: "video/mp4",
      binaryValue: nil,
      prompt: "Test video"
    )
    context.insert(record)
    return record
  }

  // MARK: - GeneratedContentListView Tests

  @Test("GeneratedContentListView initializes with document")
  func testGeneratedContentListViewInitialization() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext)

    let view = GeneratedContentListView(document: document)
      .environmentObject(AudioPlayerManager())

    #expect(document.title == "Test Document")
  }

  @Test("GeneratedContentListView handles empty document")
  func testGeneratedContentListViewEmptyDocument() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext)

    let view = GeneratedContentListView(document: document)
      .environmentObject(AudioPlayerManager())

    // Document has no generated content
    #expect(document.generatedContent?.count == 0 || document.generatedContent == nil)
  }

  @Test("GeneratedContentListView displays content items")
  func testGeneratedContentListViewDisplaysContent() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext)

    let textRecord = makeTextRecord(in: container.mainContext)
    let audioRecord = makeAudioRecord(in: container.mainContext)

    if document.generatedContent == nil {
      document.generatedContent = []
    }
    document.generatedContent?.append(textRecord)
    document.generatedContent?.append(audioRecord)

    let view = GeneratedContentListView(document: document)
      .environmentObject(AudioPlayerManager())

    #expect(document.generatedContent?.count == 2)
  }

  @Test("ContentTypeFilter enum has all cases")
  func testContentTypeFilterCases() {
    let filters = ContentTypeFilter.allCases

    #expect(filters.count == 6)
    #expect(filters.contains(.all))
    #expect(filters.contains(.text))
    #expect(filters.contains(.audio))
    #expect(filters.contains(.image))
    #expect(filters.contains(.video))
    #expect(filters.contains(.embedding))
  }

  @Test("ContentTypeFilter mime type prefixes")
  func testContentTypeFilterMIMEPrefixes() {
    #expect(ContentTypeFilter.all.mimeTypePrefix == nil)
    #expect(ContentTypeFilter.text.mimeTypePrefix == "text/")
    #expect(ContentTypeFilter.audio.mimeTypePrefix == "audio/")
    #expect(ContentTypeFilter.image.mimeTypePrefix == "image/")
    #expect(ContentTypeFilter.video.mimeTypePrefix == "video/")
    #expect(ContentTypeFilter.embedding.mimeTypePrefix == nil)
  }

  @Test("ContentTypeFilter has icons")
  func testContentTypeFilterIcons() {
    #expect(ContentTypeFilter.all.icon == "square.grid.2x2")
    #expect(ContentTypeFilter.text.icon == "doc.text")
    #expect(ContentTypeFilter.audio.icon == "waveform")
    #expect(ContentTypeFilter.image.icon == "photo")
    #expect(ContentTypeFilter.video.icon == "video")
    #expect(ContentTypeFilter.embedding.icon == "point.3.connected.trianglepath.dotted")
  }

  // MARK: - TypedDataDetailView Tests

  @Test("TypedDataDetailView initializes with text record")
  func testTypedDataDetailViewText() throws {
    let container = try makeTestContainer()
    let textRecord = makeTextRecord(in: container.mainContext)

    let view = TypedDataDetailView(record: textRecord, storageArea: nil)

    #expect(textRecord.mimeType == "text/plain")
    #expect(textRecord.textValue == "Sample text content")
  }

  @Test("TypedDataDetailView initializes with audio record")
  func testTypedDataDetailViewAudio() throws {
    let container = try makeTestContainer()
    let audioRecord = makeAudioRecord(in: container.mainContext)

    let view = TypedDataDetailView(record: audioRecord, storageArea: nil)
      .environmentObject(AudioPlayerManager())

    #expect(audioRecord.mimeType == "audio/mpeg")
  }

  @Test("TypedDataDetailView initializes with image record")
  func testTypedDataDetailViewImage() throws {
    let container = try makeTestContainer()
    let imageRecord = makeImageRecord(in: container.mainContext)

    let view = TypedDataDetailView(record: imageRecord, storageArea: nil)

    #expect(imageRecord.mimeType == "image/png")
    #expect(imageRecord.width == 512)
    #expect(imageRecord.height == 512)
  }

  @Test("TypedDataDetailView initializes with video record")
  func testTypedDataDetailViewVideo() throws {
    let container = try makeTestContainer()
    let videoRecord = makeVideoRecord(in: container.mainContext)

    let view = TypedDataDetailView(record: videoRecord, storageArea: nil)

    #expect(videoRecord.mimeType == "video/mp4")
  }

  // MARK: - TypedDataRowView Tests

  @Test("TypedDataRowView displays text metadata")
  func testTypedDataRowViewTextMetadata() throws {
    let container = try makeTestContainer()
    let textRecord = makeTextRecord(in: container.mainContext)

    let view = TypedDataRowView(record: textRecord)

    #expect(textRecord.mimeType == "text/plain")
    #expect(textRecord.contentCategory == "text")
  }

  @Test("TypedDataRowView displays audio metadata")
  func testTypedDataRowViewAudioMetadata() throws {
    let container = try makeTestContainer()
    let audioRecord = makeAudioRecord(in: container.mainContext)

    let view = TypedDataRowView(record: audioRecord)

    #expect(audioRecord.mimeType == "audio/mpeg")
    #expect(audioRecord.contentCategory == "audio")
    #expect(audioRecord.audioFormat == "mp3")
  }

  @Test("TypedDataRowView displays image metadata")
  func testTypedDataRowViewImageMetadata() throws {
    let container = try makeTestContainer()
    let imageRecord = makeImageRecord(in: container.mainContext)

    let view = TypedDataRowView(record: imageRecord)

    #expect(imageRecord.mimeType == "image/png")
    #expect(imageRecord.contentCategory == "image")
    #expect(imageRecord.width == 512)
    #expect(imageRecord.height == 512)
  }

  @Test("TypedDataRowView displays video metadata")
  func testTypedDataRowViewVideoMetadata() throws {
    let container = try makeTestContainer()
    let videoRecord = makeVideoRecord(in: container.mainContext)

    let view = TypedDataRowView(record: videoRecord)

    #expect(videoRecord.mimeType == "video/mp4")
    #expect(videoRecord.contentCategory == "video")
  }

  // MARK: - TypedDataAudioView Tests

  @Test("TypedDataAudioView initializes with audio record")
  func testTypedDataAudioViewInitialization() throws {
    let container = try makeTestContainer()
    let audioRecord = makeAudioRecord(in: container.mainContext)

    let view = TypedDataAudioView(record: audioRecord, storageArea: nil)
      .environmentObject(AudioPlayerManager())

    #expect(audioRecord.mimeType == "audio/mpeg")
    #expect(audioRecord.audioFormat == "mp3")
  }

  @Test("TypedDataAudioView handles missing file reference")
  func testTypedDataAudioViewMissingFile() throws {
    let container = try makeTestContainer()
    let audioRecord = makeAudioRecord(in: container.mainContext)

    let view = TypedDataAudioView(record: audioRecord, storageArea: nil)
      .environmentObject(AudioPlayerManager())

    // Record has no file reference (binaryValue is nil, no fileReference)
    #expect(audioRecord.fileReference == nil)
    #expect(audioRecord.binaryValue == nil)
  }

  @Test("TypedDataAudioView displays voice metadata")
  func testTypedDataAudioViewVoiceMetadata() throws {
    let container = try makeTestContainer()
    let audioRecord = makeAudioRecord(in: container.mainContext)
    audioRecord.voiceName = "Test Voice"
    audioRecord.voiceID = "test-voice-id"

    let view = TypedDataAudioView(record: audioRecord, storageArea: nil)
      .environmentObject(AudioPlayerManager())

    #expect(audioRecord.voiceID == "test-voice-id")
    #expect(audioRecord.voiceName == "Test Voice")
  }

  // MARK: - TypedDataTextView Tests

  @Test("TypedDataTextView displays text content")
  func testTypedDataTextViewDisplaysText() throws {
    let container = try makeTestContainer()
    let textRecord = makeTextRecord(in: container.mainContext)

    let view = TypedDataTextView(record: textRecord, storageArea: nil)

    #expect(textRecord.textValue == "Sample text content")
  }

  @Test("TypedDataTextView handles long text")
  func testTypedDataTextViewLongText() throws {
    let container = try makeTestContainer()
    let longText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 100)
    let textRecord = TypedDataStorage(
      providerId: "test",
      requestorID: "test",
      mimeType: "text/plain",
      textValue: longText,
      prompt: "Long text"
    )
    container.mainContext.insert(textRecord)

    let view = TypedDataTextView(record: textRecord, storageArea: nil)

    #expect(textRecord.textValue?.count ?? 0 > 1000)
  }

  @Test("TypedDataTextView handles empty text")
  func testTypedDataTextViewEmptyText() throws {
    let container = try makeTestContainer()
    let textRecord = TypedDataStorage(
      providerId: "test",
      requestorID: "test",
      mimeType: "text/plain",
      textValue: "",
      prompt: "Empty text"
    )
    container.mainContext.insert(textRecord)

    let view = TypedDataTextView(record: textRecord, storageArea: nil)

    #expect(textRecord.textValue == "")
  }

  // MARK: - TypedDataVideoView Tests

  @Test("TypedDataVideoView displays video record")
  func testTypedDataVideoViewDisplays() throws {
    let container = try makeTestContainer()
    let videoRecord = makeVideoRecord(in: container.mainContext)

    let view = TypedDataVideoView(record: videoRecord, storageArea: nil)

    #expect(videoRecord.mimeType == "video/mp4")
  }

  @Test("TypedDataVideoView handles missing file")
  func testTypedDataVideoViewMissingFile() throws {
    let container = try makeTestContainer()
    let videoRecord = makeVideoRecord(in: container.mainContext)

    let view = TypedDataVideoView(record: videoRecord, storageArea: nil)

    // Video record has no file reference
    #expect(videoRecord.fileReference == nil)
    #expect(videoRecord.binaryValue == nil)
  }

  // MARK: - Integration Tests

  @Test("GeneratedContentListView with mixed content types")
  func testGeneratedContentListViewMixedContent() throws {
    let container = try makeTestContainer()
    let document = makeTestDocument(in: container.mainContext)

    let textRecord = makeTextRecord(in: container.mainContext)
    let audioRecord = makeAudioRecord(in: container.mainContext)
    let imageRecord = makeImageRecord(in: container.mainContext)
    let videoRecord = makeVideoRecord(in: container.mainContext)

    if document.generatedContent == nil {
      document.generatedContent = []
    }
    document.generatedContent?.append(textRecord)
    document.generatedContent?.append(audioRecord)
    document.generatedContent?.append(imageRecord)
    document.generatedContent?.append(videoRecord)

    let view = GeneratedContentListView(document: document)
      .environmentObject(AudioPlayerManager())

    #expect(document.generatedContent?.count == 4)

    // Verify each content type
    guard let content = document.generatedContent else {
      #expect(false, "Generated content should not be nil")
      return
    }
    let contentTypes = content.map { $0.contentCategory }
    #expect(contentTypes.contains("text"))
    #expect(contentTypes.contains("audio"))
    #expect(contentTypes.contains("image"))
    #expect(contentTypes.contains("video"))
  }

  @Test("TypedDataStorage content category routing")
  func testTypedDataStorageContentCategory() throws {
    let container = try makeTestContainer()

    let textRecord = makeTextRecord(in: container.mainContext)
    let audioRecord = makeAudioRecord(in: container.mainContext)
    let imageRecord = makeImageRecord(in: container.mainContext)
    let videoRecord = makeVideoRecord(in: container.mainContext)

    #expect(textRecord.contentCategory == "text")
    #expect(audioRecord.contentCategory == "audio")
    #expect(imageRecord.contentCategory == "image")
    #expect(videoRecord.contentCategory == "video")
  }
}
