# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

For detailed project documentation, architecture, and development guidelines, see **[AGENTS.md](AGENTS.md)**.

## Quick Reference

**Project**: SwiftCompartido - Screenplay parsing, storage, and SwiftUI display library

**Platforms**: iOS 26.0+, macOS 26.0+

**Architecture**: Phase 6 - file-based storage with DTO pattern for actor isolation

## Core Missions

SwiftCompartido has **exactly TWO core missions**:

1. **Mission 1: Parsing & Storage** - Parse and store screenplay documents and AI-generated content
2. **Mission 2: UI Display** - Display screenplay documents and AI-generated content with SwiftUI widgets

**Decision Framework**: If code doesn't support parsing, storage, or display, it doesn't belong here.

## Key Components

**Parsers**: Fountain, FDX, PDF (AI + heuristic), Markdown, Highland, TextBundle, Pandoc
**Models**: GuionDocumentModel, GuionElementModel, TypedDataStorage (SwiftData)
**Views**: GuionTextEditor, GuionViewer, SceneHeadingView, DialogueTextView, 10+ element views
**Reference App**: GuionViewer (minimal macOS demo with best practices)

## Important Notes

- **ONLY supports iOS 26.0+ and macOS 26.0+** (NEVER add code for older platforms)
- **NEVER add `@available` attributes** for versions below iOS 26/macOS 26
- **Use `xcodebuild`** for all builds and tests (SwiftData/SwiftUI require Xcode build system)
- **Actor isolation**: All SwiftData operations through `DocumentModelActor`
- **DTO pattern**: Never pass Model instances across actor boundaries, use Sendable DTOs
- **What doesn't belong**: AI generation (OpenAI/ElevenLabs/DALL-E), cloud sync, external service integration
- **Exception**: Foundation Models PDF parsing OK (on-device Apple Intelligence)

## Quick API Reference

```swift
// Parse screenplay
let screenplay = try await GuionParsedElementCollection(string: fountainText)

// Convert to SwiftData
let document = await GuionDocumentParserSwiftData.parse(script: screenplay, in: modelContext)

// Use DocumentModelActor for safe concurrency
let actor = DocumentModelActor(modelContainer: container)
let documentID = try await actor.parseAndSaveDocument(from: url)
let elements = try await actor.getElements(for: documentID, limit: 100)

// Display with element views
SceneHeadingView(element: element)
DialogueTextView(element: element)
```

See [AGENTS.md](AGENTS.md) for complete documentation, architecture patterns, GuionViewer reference implementation, and Phase 6 storage details.
