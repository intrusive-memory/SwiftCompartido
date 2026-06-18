//
//  SpeakableElementTests.swift
//  SwiftCompartido
//
//  Tests for SpeakableElement protocol conformance on GuionElementModel and ElementReference.
//

import SwiftData
import Testing

@testable import SwiftCompartido

@Suite("SpeakableElement Protocol Tests", .tags(.glosa))
struct SpeakableElementTests {

  // MARK: - GuionElementModel Conformance Tests

  @Test("GuionElementModel spokenText returns glosaSpokenText when available")
  func guionElementModelSpokenTextWithGlosa() throws {
    // Given: An element with glosa fields populated
    let element = GuionElementModel(
      elementText: "Original text with [[<breath/>]] marker",
      elementType: .dialogue,
      chapterIndex: 0,
      orderIndex: 1
    )
    element.glosaSpokenText = "Original text with  marker"
    element.glosaBreathOffsets = [18]

    // When: We access spokenText
    let spokenText = element.spokenText

    // Then: It returns the glosa stripped text
    #expect(spokenText == "Original text with  marker")
  }

  @Test("GuionElementModel spokenText falls back to elementText when glosa is nil")
  func guionElementModelSpokenTextFallback() throws {
    // Given: An element without glosa annotation
    let element = GuionElementModel(
      elementText: "Plain dialogue line",
      elementType: .dialogue,
      chapterIndex: 0,
      orderIndex: 1
    )

    // When: We access spokenText (glosaSpokenText is nil)
    let spokenText = element.spokenText

    // Then: It falls back to elementText
    #expect(spokenText == "Plain dialogue line")
  }

  @Test("GuionElementModel breathOffsets returns glosaBreathOffsets when available")
  func guionElementModelBreathOffsetsWithGlosa() throws {
    // Given: An element with breath offsets
    let element = GuionElementModel(
      elementText: "Dialogue with breath",
      elementType: .dialogue,
      chapterIndex: 0,
      orderIndex: 1
    )
    element.glosaBreathOffsets = [10, 20]

    // When: We access breathOffsets
    let offsets = element.breathOffsets

    // Then: It returns the glosa offsets
    #expect(offsets == [10, 20])
  }

  @Test("GuionElementModel breathOffsets returns empty array when glosa is nil")
  func guionElementModelBreathOffsetsFallback() throws {
    // Given: An element without glosa annotation
    let element = GuionElementModel(
      elementText: "Plain dialogue",
      elementType: .dialogue,
      chapterIndex: 0,
      orderIndex: 1
    )

    // When: We access breathOffsets (glosaBreathOffsets is nil)
    let offsets = element.breathOffsets

    // Then: It returns an empty array
    #expect(offsets.isEmpty)
  }

  @Test("GuionElementModel instruct returns glosaInstruct when available")
  func guionElementModelInstructWithGlosa() throws {
    // Given: An element with performance instruction
    let element = GuionElementModel(
      elementText: "Dialogue line",
      elementType: .dialogue,
      chapterIndex: 0,
      orderIndex: 1
    )
    element.glosaInstruct = "Speak softly and quickly"

    // When: We access instruct
    let instruction = element.instruct

    // Then: It returns the glosa instruction
    #expect(instruction == "Speak softly and quickly")
  }

  @Test("GuionElementModel instruct returns nil when glosa is nil")
  func guionElementModelInstructFallback() throws {
    // Given: An element without performance instruction
    let element = GuionElementModel(
      elementText: "Plain dialogue",
      elementType: .dialogue,
      chapterIndex: 0,
      orderIndex: 1
    )

    // When: We access instruct (glosaInstruct is nil)
    let instruction = element.instruct

    // Then: It returns nil
    #expect(instruction == nil)
  }

  @Test("GuionElementModel displayBreathOffsets matches breathOffsets")
  func guionElementModelDisplayBreathOffsets() throws {
    // Given: An element with breath offsets
    let element = GuionElementModel(
      elementText: "Dialogue with breath",
      elementType: .dialogue,
      chapterIndex: 0,
      orderIndex: 1
    )
    element.glosaBreathOffsets = [5, 15, 25]

    // When: We access both breathOffsets and displayBreathOffsets
    let breathOffsets = element.breathOffsets
    let displayOffsets = element.displayBreathOffsets

    // Then: They are identical
    #expect(breathOffsets == displayOffsets)
    #expect(displayOffsets == [5, 15, 25])
  }

  // MARK: - ElementReference Conformance Tests

  @Test("ElementReference spokenText returns glosaSpokenText when available")
  @MainActor
  func elementReferenceSpokenTextWithGlosa() throws {
    // Given: An ElementReference with glosa fields populated
    let modelConfig = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: GuionElementModel.self,
      configurations: modelConfig
    )

    let element = GuionElementModel(
      elementText: "Text with [[<breath/>]] marker",
      elementType: .dialogue,
      chapterIndex: 0,
      orderIndex: 1
    )
    container.mainContext.insert(element)

    let ref = ElementReference(
      id: element.persistentModelID,
      elementType: .dialogue,
      elementText: "Text with [[<breath/>]] marker",
      chapterIndex: 0,
      orderIndex: 1,
      characterName: "JOHN",
      glosaSpokenText: "Text with  marker",
      glosaBreathOffsets: [10],
      glosaInstruct: nil
    )

    // When: We access spokenText
    let spokenText = ref.spokenText

    // Then: It returns the glosa stripped text
    #expect(spokenText == "Text with  marker")
  }

  @Test("ElementReference spokenText falls back to elementText when glosa is nil")
  @MainActor
  func elementReferenceSpokenTextFallback() throws {
    // Given: An ElementReference without glosa annotation
    let modelConfig = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: GuionElementModel.self,
      configurations: modelConfig
    )

    let element = GuionElementModel(
      elementText: "Plain dialogue",
      elementType: .dialogue,
      chapterIndex: 0,
      orderIndex: 1
    )
    container.mainContext.insert(element)

    let ref = ElementReference(
      id: element.persistentModelID,
      elementType: .dialogue,
      elementText: "Plain dialogue",
      chapterIndex: 0,
      orderIndex: 1,
      characterName: "JANE",
      glosaSpokenText: nil,
      glosaBreathOffsets: nil,
      glosaInstruct: nil
    )

    // When: We access spokenText
    let spokenText = ref.spokenText

    // Then: It falls back to elementText
    #expect(spokenText == "Plain dialogue")
  }

  @Test("ElementReference breathOffsets returns glosaBreathOffsets when available")
  @MainActor
  func elementReferenceBreathOffsetsWithGlosa() throws {
    // Given: An ElementReference with breath offsets
    let modelConfig = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: GuionElementModel.self,
      configurations: modelConfig
    )

    let element = GuionElementModel(
      elementText: "Dialogue",
      elementType: .dialogue,
      chapterIndex: 0,
      orderIndex: 1
    )
    container.mainContext.insert(element)

    let ref = ElementReference(
      id: element.persistentModelID,
      elementType: .dialogue,
      elementText: "Dialogue",
      chapterIndex: 0,
      orderIndex: 1,
      characterName: "BOB",
      glosaSpokenText: "Dialogue",
      glosaBreathOffsets: [8],
      glosaInstruct: nil
    )

    // When: We access breathOffsets
    let offsets = ref.breathOffsets

    // Then: It returns the glosa offsets
    #expect(offsets == [8])
  }

  @Test("ElementReference breathOffsets returns empty array when glosa is nil")
  @MainActor
  func elementReferenceBreathOffsetsFallback() throws {
    // Given: An ElementReference without glosa annotation
    let modelConfig = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: GuionElementModel.self,
      configurations: modelConfig
    )

    let element = GuionElementModel(
      elementText: "Dialogue",
      elementType: .dialogue,
      chapterIndex: 0,
      orderIndex: 1
    )
    container.mainContext.insert(element)

    let ref = ElementReference(
      id: element.persistentModelID,
      elementType: .dialogue,
      elementText: "Dialogue",
      chapterIndex: 0,
      orderIndex: 1,
      characterName: "ALICE"
    )

    // When: We access breathOffsets
    let offsets = ref.breathOffsets

    // Then: It returns an empty array
    #expect(offsets.isEmpty)
  }

  @Test("ElementReference created from GuionElementModel preserves glosa data")
  func elementReferenceFromGuionElementModel() throws {
    // Given: A GuionElementModel with glosa fields populated
    let element = GuionElementModel(
      elementText: "Original with [[<breath/>]]",
      elementType: .dialogue,
      chapterIndex: 0,
      orderIndex: 1
    )
    element.glosaSpokenText = "Original with "
    element.glosaBreathOffsets = [14]
    element.glosaInstruct = "Speak clearly"

    // When: We create an ElementReference from it
    let ref = ElementReference(from: element)

    // Then: The glosa data is preserved
    #expect(ref.spokenText == "Original with ")
    #expect(ref.breathOffsets == [14])
    #expect(ref.instruct == "Speak clearly")
  }
}
