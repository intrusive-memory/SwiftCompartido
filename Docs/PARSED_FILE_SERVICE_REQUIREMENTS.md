# Parsed File Service Requirements (v6.1.0)

## Overview

SwiftCompartido 6.1.0 introduces a **Parsed File Service** powered by App Intents, enabling external clients (including Apple Shortcuts) to import screenplay files and receive structured document references and element collections from the SwiftData database.

**Design Principles**:
1. **Purely additive** - Zero breaking changes to existing APIs
2. **Single code path** - App Intents are thin wrappers around core APIs (no duplicate logic)
3. **Integration testing** - App Intents can be used for testing the standard application path

---

## Goals

1. **Enable Shortcuts Integration**: Allow users to parse screenplay files via Siri Shortcuts
2. **Headless Parsing**: Support parsing without UI/view dependencies
3. **Database Integration**: Return persistent SwiftData document references
4. **Workflow Chaining**: Return element data that can be directly chained to downstream intents (voice generation, export, etc.)
5. **Format Agnostic**: Support all existing screenplay formats (Fountain, FDX, PDF, Markdown, Highland, TextBundle)
6. **Single-Shot Operations**: Parse + filter in one intent to minimize user workflow complexity

---

## User Stories

### Story 1: Import Screenplay via Shortcuts
**As a** Shortcuts user
**I want to** select a screenplay file and import it into SwiftCompartido's database
**So that** I can access structured screenplay data in other apps

**Acceptance Criteria**:
- [ ] Shortcut action appears in Shortcuts app
- [ ] User can select file from Files app, iCloud Drive, or Dropbox
- [ ] Action returns `ScreenplayElementsReference` containing element data
- [ ] Reference can be directly chained to voice generation or export intents
- [ ] Progress/errors are reported to Shortcuts UI

### Story 2: Query Elements via Shortcuts
**As a** Shortcuts user
**I want to** retrieve specific screenplay elements (scenes, dialogue, characters)
**So that** I can filter, count, or process screenplay content

**Acceptance Criteria**:
- [ ] Query by element type (scene heading, dialogue, action, etc.)
- [ ] Query by chapter/act
- [ ] Query by character name
- [ ] Returns element text and metadata

### Story 3: Voice Generation Workflow via Shortcuts
**As a** Produciesta user
**I want to** parse a screenplay and generate voice audio for all dialogue
**So that** I can create audio versions of my scripts

**Acceptance Criteria**:
- [ ] Parse screenplay with dialogue filter in single intent
- [ ] Chain `ScreenplayElementsReference` directly to voice generation intent
- [ ] No intermediate query/fetch steps required
- [ ] Element data includes character names for voice assignment

### Story 4: Batch Import via Shortcuts
**As a** power user
**I want to** import multiple screenplay files in one shortcut
**So that** I can process entire folders of scripts

**Acceptance Criteria**:
- [ ] Accept array of file URLs
- [ ] Return array of `ScreenplayElementsReference` objects
- [ ] Handle partial failures gracefully

### Story 5: Export Document via Shortcuts
**As a** user
**I want to** export a parsed document to Fountain/FDX/PDF
**So that** I can share formatted screenplays

**Acceptance Criteria**:
- [ ] Accept `ScreenplayElementsReference` or document ID
- [ ] Accept target format (fountain, fdx, markdown)
- [ ] Return file URL to exported document

---

## Technical Architecture

### Unified Code Path Architecture

**CRITICAL**: App Intents are **thin wrappers** around existing APIs. They do NOT duplicate parsing or conversion logic.

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────────┐        ┌─────────────────────┐      │
│  │ SwiftUI Views      │        │ App Intents         │      │
│  │ (Standard UI)      │        │ (Shortcuts/Testing) │      │
│  └────────┬───────────┘        └──────────┬──────────┘      │
│           │                               │                  │
│           └───────────┬───────────────────┘                  │
│                       ↓                                      │
├─────────────────────────────────────────────────────────────┤
│                   Core Service Layer                         │
│           (SINGLE SOURCE OF TRUTH)                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         ParsedFileService (Actor)                    │   │
│  │  - parseFile(url) → PersistentIdentifier            │   │
│  │  - elements(documentID, filter) → [GuionElement]    │   │
│  │  - document(id) → GuionDocumentModel                 │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     ↓                                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │    Existing SwiftCompartido Core APIs                │   │
│  │  - GuionParsedElementCollection(file:)              │   │
│  │  - GuionDocumentModel.from(screenplay:)             │   │
│  │  - FDXDocumentWriter, FountainTextWriter, etc.      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

**Key Principles**:

1. **ParsedFileService is the unified API** for both UI and Intents
2. **App Intents call ParsedFileService** (not GuionParsedElementCollection directly)
3. **ParsedFileService calls existing APIs** (GuionParsedElementCollection, GuionDocumentModel, etc.)
4. **Zero duplicate parsing logic** - All parsing uses existing parsers
5. **Export uses existing writers** - FDXDocumentWriter, FountainTextWriter
6. **Integration tests use App Intents** to verify the full stack

**Example: How parsing works**

```swift
// ❌ WRONG - Duplicate logic in App Intent
public struct ParseScreenplayFileIntent: AppIntent {
    public func perform() async throws -> ... {
        // DON'T: Re-implement parsing logic here
        let parser = FountainParser()
        let elements = parser.parse(text)  // ❌ Duplicate!
    }
}

// ✅ CORRECT - App Intent calls ParsedFileService
public struct ParseScreenplayFileIntent: AppIntent {
    @Dependency
    var service: ParsedFileService

    public func perform() async throws -> ... {
        // DO: Delegate to unified service
        let documentID = try await service.parseFile(at: fileURL)
        let elements = try await service.elements(documentID: documentID)
        // ...
    }
}

// ✅ ParsedFileService calls existing APIs
public actor ParsedFileService {
    public func parseFile(at url: URL) async throws -> PersistentIdentifier {
        // Uses existing GuionParsedElementCollection (automatic format detection)
        let screenplay = try GuionParsedElementCollection(file: url)

        // Uses existing GuionDocumentModel.from() (SwiftData conversion)
        let document = await GuionDocumentModel.from(screenplay: screenplay, in: modelContext)

        return document.persistentModelID
    }
}
```

**Benefits**:
- ✅ Bug fixes in core APIs automatically fix App Intents
- ✅ App Intents can be used for integration testing
- ✅ No behavior divergence between UI and Shortcuts
- ✅ Easier to maintain (one implementation)

### Intent Return Type Strategy

**Key Design Decision**: Intents return `ScreenplayElementsReference` (synthetic reference struct) instead of document IDs, queries, or entities.

#### Why `ScreenplayElementsReference`?

**Problem**: Voice generation workflows in Produciesta need element data (text, character names) to be chainable in Shortcuts.

**Options Evaluated**:

1. ❌ **Return Query** - SwiftData queries don't serialize across process boundaries (Shortcuts runs in separate process)
2. ⚠️ **Return Document ID** - Requires second intent call to fetch elements, creating inefficient multi-step workflows
3. ❌ **Return View** - Views don't conform to `Transferable` for Shortcuts
4. ✅ **Return Synthetic Reference Struct** - Contains both metadata AND element data, directly chainable

**Workflow Comparison**:

```
// Option A: Document ID approach (❌ 3 steps)
Parse File → DocumentID
Query Elements (filter: dialogue) → [ElementEntity]
Generate Voice (for each element)

// Option B: Elements Reference approach (✅ 2 steps)
Parse File (filter: dialogue) → ScreenplayElementsReference
Generate Voice (input: reference) → Done
```

**Benefits**:
- ✅ Single-shot parsing + filtering
- ✅ Contains complete element data (text, type, character, order)
- ✅ Batch-friendly (process multiple elements in one intent)
- ✅ Serializable (Codable) across process boundaries
- ✅ Future-proof (can add metadata fields without breaking changes)

### Phase 1: App Intent Framework (v6.1.0)

#### New Types

**1. `ParsedFileService` (Actor)**
- **Purpose**: Unified API for parsing and querying screenplays (used by both UI and App Intents)
- **Location**: `Sources/SwiftCompartido/Services/ParsedFileService.swift`
- **Architecture Role**: Thin wrapper around existing SwiftCompartido APIs
- **Responsibilities**:
  - Delegate to `GuionParsedElementCollection` for parsing (existing API)
  - Delegate to `GuionDocumentModel.from()` for SwiftData conversion (existing API)
  - Provide query interface over SwiftData documents
  - Manage SwiftData context isolation (actor)

```swift
@available(iOS 26.0, macOS 26.0, *)
public actor ParsedFileService {
    private let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer)

    /// Parse file and insert into database
    /// - Uses: GuionParsedElementCollection (existing API)
    /// - Uses: GuionDocumentModel.from() (existing API)
    public func parseFile(
        at url: URL,
        sourceTracking: SourceFileTrackingMode = .enabled
    ) async throws -> PersistentIdentifier {
        let modelContext = ModelContext(modelContainer)

        // Step 1: Use existing parser (automatic format detection)
        let screenplay = try GuionParsedElementCollection(file: url)

        // Step 2: Use existing SwiftData conversion
        let document = await GuionDocumentModel.from(
            screenplay: screenplay,
            in: modelContext,
            sourceTracking: sourceTracking
        )

        modelContext.insert(document)
        try modelContext.save()

        return document.persistentModelID
    }

    /// Retrieve document by ID
    public func document(
        id: PersistentIdentifier
    ) async throws -> GuionDocumentModel {
        let modelContext = ModelContext(modelContainer)
        guard let document = modelContext.model(for: id) as? GuionDocumentModel else {
            throw ParsedFileServiceError.documentNotFound(id)
        }
        return document
    }

    /// Query elements from document with optional filtering
    public func elements(
        documentID: PersistentIdentifier,
        filter: ElementFilter?
    ) async throws -> [GuionElementModel] {
        let document = try await self.document(id: documentID)

        // Use existing sortedElements property (composite key ordering)
        var elements = document.sortedElements

        // Apply filters if provided
        if let filter = filter {
            elements = elements.filter { element in
                var matches = true

                if let types = filter.elementTypes {
                    matches = matches && types.contains(element.elementType)
                }

                if let chapterIndex = filter.chapterIndex {
                    matches = matches && element.chapterIndex == chapterIndex
                }

                if let characterName = filter.characterName {
                    matches = matches && element.characterName?.uppercased() == characterName.uppercased()
                }

                if let searchText = filter.searchText {
                    matches = matches && element.elementText.localizedCaseInsensitiveContains(searchText)
                }

                return matches
            }
        }

        return elements
    }
}

public enum ParsedFileServiceError: Error, LocalizedError {
    case documentNotFound(PersistentIdentifier)

    public var errorDescription: String? {
        switch self {
        case .documentNotFound(let id):
            return "Document with ID \(id) not found in database"
        }
    }
}
```

**2. `ElementFilter` (Struct, Sendable)**
- **Purpose**: Filter criteria for element queries
- **Location**: `Sources/SwiftCompartido/Services/ElementFilter.swift`

```swift
@available(iOS 26.0, macOS 26.0, *)
public struct ElementFilter: Sendable, Codable {
    public var elementTypes: [ElementType]?
    public var chapterIndex: Int?
    public var characterName: String?
    public var searchText: String?

    public init(
        elementTypes: [ElementType]? = nil,
        chapterIndex: Int? = nil,
        characterName: String? = nil,
        searchText: String? = nil
    )
}
```

**3. `ScreenplayElementsReference` (Primary Return Type)**
- **Purpose**: Synthetic reference struct containing element data for workflow chaining
- **Location**: `Sources/SwiftCompartido/AppIntents/Entities/ScreenplayElementsReference.swift`
- **Key Feature**: Directly chainable to voice generation, export, and analysis intents

```swift
import AppIntents
import Foundation

@available(iOS 26.0, macOS 26.0, *)
public struct ScreenplayElementsReference: Codable, Sendable, Transferable {
    /// Document metadata
    public let documentID: PersistentIdentifier
    public let documentTitle: String

    /// Element references for downstream processing
    public let elements: [ElementReference]

    /// Summary metadata
    public var elementCount: Int { elements.count }

    /// Unique character names (sorted) - useful for voice assignment
    public var characterNames: [String] {
        Set(elements.compactMap { $0.characterName }).sorted()
    }

    /// Count dialogue lines per character
    public func dialogueCount(for character: String) -> Int {
        elements.filter {
            $0.characterName?.uppercased() == character.uppercased() && $0.isDialogue
        }.count
    }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

@available(iOS 26.0, macOS 26.0, *)
public struct ElementReference: Codable, Sendable, Identifiable {
    public let id: PersistentIdentifier
    public let elementType: ElementType
    public let elementText: String
    public let chapterIndex: Int
    public let orderIndex: Int
    public let characterName: String?

    /// For voice generation workflows - identify dialogue elements
    public var isDialogue: Bool {
        elementType == .dialogue ||
        elementType == .dualDialogueLeft ||
        elementType == .dualDialogueRight
    }

    /// For scene-based workflows
    public var isSceneHeading: Bool {
        elementType == .sceneHeading
    }
}
```

**4. `ScreenplayDocumentEntity` (AppEntity) - For Display/Inspection**
- **Purpose**: Lightweight entity for document browsing/selection in Shortcuts
- **Use Case**: Get document metadata, list documents, inspect without loading elements

```swift
import AppIntents

@available(iOS 26.0, macOS 26.0, *)
public struct ScreenplayDocumentEntity: AppEntity, Identifiable {
    public let id: PersistentIdentifier
    public var title: String
    public var elementCount: Int
    public var sourceURL: URL?

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Screenplay Document"
    )

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(elementCount) elements"
        )
    }
}
```

**5. App Intents**

**`ParseScreenplayFileIntent` - Primary Import Intent**
- **Returns**: `ScreenplayElementsReference` (not just document ID)
- **Key Feature**: Optional filtering during parse (e.g., dialogue only)

```swift
import AppIntents

@available(iOS 26.0, macOS 26.0, *)
public struct ParseScreenplayFileIntent: AppIntent {
    public static let title: LocalizedStringResource = "Parse Screenplay File"
    public static let description = IntentDescription(
        "Import a screenplay file and parse it into structured elements"
    )

    @Parameter(title: "File")
    public var file: IntentFile

    @Parameter(
        title: "Filter Element Types",
        description: "Optionally filter to specific element types (e.g., only dialogue)",
        optionsProvider: ElementTypeOptionsProvider()
    )
    public var filterTypes: [ElementTypeOption]?

    @Parameter(
        title: "Track Source File",
        description: "Enable source file tracking for change detection",
        default: true
    )
    public var trackSource: Bool

    public static var parameterSummary: some ParameterSummary {
        Summary("Parse \(\.$file)") {
            \.$filterTypes
            \.$trackSource
        }
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<ScreenplayElementsReference> {
        // 1. Parse file to database
        let fileURL = try file.url
        let documentID = try await service.parseFile(
            at: fileURL,
            sourceTracking: trackSource ? .enabled : .disabled
        )

        // 2. Query elements with optional filter
        let filter = filterTypes.map { types in
            ElementFilter(elementTypes: types.map { $0.elementType })
        }
        let elements = try await service.elements(documentID: documentID, filter: filter)

        // 3. Build reference struct
        let document = try await service.document(id: documentID)
        let elementRefs = elements.map { ElementReference(from: $0) }

        let reference = ScreenplayElementsReference(
            documentID: documentID,
            documentTitle: document.title ?? "Untitled",
            elements: elementRefs
        )

        return .result(value: reference)
    }
}
```

**`QueryScreenplayElementsIntent` - Re-filter Existing Document**
- **Returns**: `ScreenplayElementsReference`
- **Use Case**: Re-query an already-parsed document with different filters

```swift
@available(iOS 26.0, macOS 26.0, *)
public struct QueryScreenplayElementsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Query Screenplay Elements"
    public static let description = IntentDescription(
        "Retrieve screenplay elements from an existing document with optional filters"
    )

    @Parameter(title: "Document")
    public var document: ScreenplayDocumentEntity

    @Parameter(
        title: "Element Types",
        description: "Filter by element type (leave empty for all)",
        optionsProvider: ElementTypeOptionsProvider()
    )
    public var elementTypes: [ElementTypeOption]?

    @Parameter(title: "Character Name")
    public var characterName: String?

    @Parameter(title: "Chapter Index")
    public var chapterIndex: Int?

    public static var parameterSummary: some ParameterSummary {
        Summary("Query elements from \(\.$document)") {
            \.$elementTypes
            \.$characterName
            \.$chapterIndex
        }
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<ScreenplayElementsReference> {
        // Build filter from parameters
        let filter = ElementFilter(
            elementTypes: elementTypes?.map { $0.elementType },
            chapterIndex: chapterIndex,
            characterName: characterName
        )

        // Query elements
        let elements = try await service.elements(
            documentID: document.id,
            filter: filter
        )

        // Build reference struct
        let elementRefs = elements.map { ElementReference(from: $0) }
        let reference = ScreenplayElementsReference(
            documentID: document.id,
            documentTitle: document.title,
            elements: elementRefs
        )

        return .result(value: reference)
    }
}
```

**`ExportScreenplayIntent` - Export to File**
- **Accepts**: `ScreenplayElementsReference` OR `ScreenplayDocumentEntity`
- **Returns**: `IntentFile` for saving to Files app

```swift
@available(iOS 26.0, macOS 26.0, *)
public struct ExportScreenplayIntent: AppIntent {
    public static let title: LocalizedStringResource = "Export Screenplay"
    public static let description = IntentDescription(
        "Export screenplay elements to a file format"
    )

    @Parameter(title: "Elements Reference")
    public var elementsReference: ScreenplayElementsReference?

    @Parameter(title: "Document (if no elements reference)")
    public var document: ScreenplayDocumentEntity?

    @Parameter(
        title: "Format",
        default: ExportFormat.fountain
    )
    public var format: ExportFormat

    public static var parameterSummary: some ParameterSummary {
        Summary("Export screenplay as \(\.$format)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        // Get elements from reference or query document
        let elements: [ElementReference]
        let title: String

        if let reference = elementsReference {
            elements = reference.elements
            title = reference.documentTitle
        } else if let doc = document {
            // Fallback: query all elements from document
            let allElements = try await service.elements(documentID: doc.id, filter: nil)
            elements = allElements.map { ElementReference(from: $0) }
            title = doc.title
        } else {
            throw IntentError.message("No document or elements reference provided")
        }

        // Export to format
        let fileURL = try await exportService.export(
            elements: elements,
            title: title,
            format: format
        )

        let intentFile = IntentFile(fileURL: fileURL, filename: "\(title).\(format.fileExtension)")
        return .result(value: intentFile)
    }
}

public enum ExportFormat: String, AppEnum {
    case fountain
    case fdx
    case markdown

    public var fileExtension: String {
        switch self {
        case .fountain: return "fountain"
        case .fdx: return "fdx"
        case .markdown: return "md"
        }
    }

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Export Format"
    )

    public static let caseDisplayRepresentations: [ExportFormat: DisplayRepresentation] = [
        .fountain: "Fountain",
        .fdx: "Final Draft (FDX)",
        .markdown: "Markdown"
    ]
}
```

**6. App Shortcuts Provider**

```swift
import AppIntents

@available(iOS 26.0, macOS 26.0, *)
public struct SwiftCompartidoShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ParseScreenplayFileIntent(),
            phrases: [
                "Import screenplay with \(.applicationName)",
                "Parse screenplay file in \(.applicationName)"
            ],
            shortTitle: "Parse Screenplay",
            systemImageName: "doc.text"
        )

        AppShortcut(
            intent: QueryScreenplayElementsIntent(),
            phrases: [
                "Query screenplay elements in \(.applicationName)",
                "Get screenplay dialogue in \(.applicationName)"
            ],
            shortTitle: "Query Elements",
            systemImageName: "doc.text.magnifyingglass"
        )
    }
}
```

---

## File Structure

```
Sources/SwiftCompartido/
├── Services/
│   ├── ParsedFileService.swift          (NEW)
│   └── ElementFilter.swift              (NEW)
├── AppIntents/
│   ├── Entities/
│   │   ├── ScreenplayElementsReference.swift    (NEW - PRIMARY)
│   │   ├── ElementReference.swift               (NEW)
│   │   └── ScreenplayDocumentEntity.swift       (NEW - METADATA ONLY)
│   ├── Intents/
│   │   ├── ParseScreenplayFileIntent.swift  (NEW)
│   │   ├── QueryScreenplayElementsIntent.swift (NEW)
│   │   └── ExportScreenplayIntent.swift     (NEW)
│   ├── OptionsProviders/
│   │   └── ElementTypeOptionsProvider.swift (NEW)
│   └── SwiftCompartidoShortcuts.swift       (NEW)

Tests/SwiftCompartidoTests/
├── Services/
│   └── ParsedFileServiceTests.swift     (NEW)
└── AppIntents/
    ├── ParseScreenplayFileIntentTests.swift (NEW)
    ├── QueryScreenplayElementsIntentTests.swift (NEW)
    └── ExportScreenplayIntentTests.swift (NEW)
```

---

## SwiftData Integration

### ModelContainer Configuration

Clients using the Parsed File Service must provide a `ModelContainer`:

```swift
// In client app
import SwiftCompartido
import SwiftData

let container = try ModelContainer(
    for: GuionDocumentModel.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: false)
)

let service = ParsedFileService(modelContainer: container)
```

### Thread Safety

- `ParsedFileService` is an `actor` for thread-safe SwiftData access
- All database operations use `@ModelActor` context isolation
- File I/O operations run on background tasks

---

## Backward Compatibility

### Zero Breaking Changes

**Existing APIs remain unchanged:**
- ✅ `GuionParsedElementCollection` - No changes
- ✅ `GuionDocumentModel` - No changes
- ✅ All parsers - No changes
- ✅ UI components - No changes
- ✅ Export functionality - No changes

**New code is isolated:**
- All App Intents code is in new `AppIntents/` directory
- `ParsedFileService` is standalone (doesn't modify existing services)
- New dependencies (AppIntents framework) are additive

### Feature Flags

No feature flags needed - App Intents are opt-in by design. Apps that don't use the service simply don't import the intents.

---

## Testing Strategy

### Unit Tests

**ParsedFileService Tests (20 tests)**
- ✅ Parse Fountain file → Returns valid document ID
- ✅ Parse FDX file → Returns valid document ID
- ✅ Parse PDF file → Returns valid document ID
- ✅ Parse invalid file → Throws appropriate error
- ✅ Query elements with no filter → Returns all elements
- ✅ Query elements by type → Returns filtered elements
- ✅ Query elements by character → Returns character's dialogue
- ✅ Query elements by chapter → Returns chapter elements
- ✅ Query non-existent document → Throws error
- ✅ Parse file with source tracking → Creates file reference
- ✅ Parse file without source tracking → No file reference

**App Intent Tests (20 tests)**
- ✅ ParseScreenplayFileIntent with valid file → Returns ScreenplayElementsReference
- ✅ ParseScreenplayFileIntent with dialogue filter → Returns only dialogue
- ✅ ParseScreenplayFileIntent with invalid file → Throws error
- ✅ ScreenplayElementsReference serialization → Codable round-trip succeeds
- ✅ ElementReference.isDialogue → Correctly identifies dialogue types
- ✅ ElementReference.isSceneHeading → Correctly identifies scenes
- ✅ ScreenplayElementsReference.characterNames → Returns unique sorted names
- ✅ ScreenplayElementsReference.dialogueCount(for:) → Correct count per character
- ✅ QueryScreenplayElementsIntent with filters → Returns filtered reference
- ✅ QueryScreenplayElementsIntent without filters → Returns all elements in reference
- ✅ ExportScreenplayIntent with reference → Returns valid file
- ✅ ExportScreenplayIntent with document entity → Returns valid file
- ✅ ExportScreenplayIntent to Fountain → Correct format
- ✅ ExportScreenplayIntent to FDX → Correct format
- ✅ ExportScreenplayIntent to Markdown → Correct format
- ✅ Entity display representation → Correct title/subtitle
- ✅ Transferable conformance → ScreenplayElementsReference transfers correctly
- ✅ Large reference (1000+ elements) → Serializes without errors
- ✅ Empty reference (0 elements) → Handles gracefully
- ✅ Chain Parse → Export → Verify output matches input

### Integration Tests via App Intents

**CRITICAL**: App Intents can be invoked programmatically for integration testing, validating the full stack from file → parse → database → query.

**Integration Test Pattern**:
```swift
import XCTest
import AppIntents
@testable import SwiftCompartido

final class ScreenplayWorkflowIntegrationTests: XCTestCase {
    func testFullParseAndQueryWorkflow() async throws {
        // Setup
        let testFile = IntentFile(/* test screenplay */)
        let container = try ModelContainer(
            for: GuionDocumentModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        // Execute App Intent (tests ENTIRE stack)
        let parseIntent = ParseScreenplayFileIntent()
        parseIntent.file = testFile
        parseIntent.filterTypes = [.dialogue]

        let result = try await parseIntent.perform()
        let reference = result.value

        // Verify parse result
        XCTAssertEqual(reference.documentTitle, "Test Screenplay")
        XCTAssertGreaterThan(reference.elementCount, 0)

        // Verify elements are in database
        let queryIntent = QueryScreenplayElementsIntent()
        queryIntent.document = ScreenplayDocumentEntity(
            id: reference.documentID,
            title: reference.documentTitle,
            elementCount: reference.elementCount
        )
        queryIntent.characterName = "SARAH"

        let queryResult = try await queryIntent.perform()
        XCTAssertTrue(queryResult.value.elements.allSatisfy { $0.characterName == "SARAH" })
    }

    func testExportRoundTrip() async throws {
        // Parse → Export → Parse → Verify identical
        let originalIntent = ParseScreenplayFileIntent()
        originalIntent.file = testFile

        let reference1 = try await originalIntent.perform().value

        let exportIntent = ExportScreenplayIntent()
        exportIntent.elementsReference = reference1
        exportIntent.format = .fountain

        let exportedFile = try await exportIntent.perform().value

        // Re-parse exported file
        let reimportIntent = ParseScreenplayFileIntent()
        reimportIntent.file = exportedFile

        let reference2 = try await reimportIntent.perform().value

        // Verify element count and content match
        XCTAssertEqual(reference1.elementCount, reference2.elementCount)
    }
}
```

**Benefits of Intent-based Integration Testing**:
- ✅ Tests the EXACT code path users will execute in Shortcuts
- ✅ Validates entire stack (parse → SwiftData → query → export)
- ✅ No test-specific code paths (same API as production)
- ✅ Catches integration bugs between layers

**Shortcut Workflow Tests (10 tests via App Intents)**
- ✅ Import screenplay → Query dialogue → Count words
- ✅ Import screenplay → Filter by character → Export to PDF
- ✅ Batch import 5 files → Verify all documents created
- ✅ Query elements → Pass to next shortcut action

### Performance Tests

**Benchmarks:**
- Parse 1000-element screenplay: < 2s
- Query 1000 elements with filter: < 0.5s
- Export 1000-element screenplay to Fountain: < 1s

---

## Documentation

### New Documentation Files

1. **`Docs/APP_INTENTS_GUIDE.md`** - User guide for Shortcuts integration
2. **`Docs/PARSED_FILE_SERVICE_API.md`** - API reference for service
3. **`Docs/SHORTCUTS_EXAMPLES.md`** - Example Shortcut workflows

### Updated Documentation

1. **`README.md`** - Add App Intents section
2. **`CLAUDE.md`** - Add Parsed File Service architecture section
3. **`AI-REFERENCE.md`** - Add service API documentation

### Code Examples

**Example 1: Simple Import**
```swift
import SwiftCompartido
import SwiftData

let container = try ModelContainer(for: GuionDocumentModel.self)
let service = ParsedFileService(modelContainer: container)

let fileURL = URL(fileURLWithPath: "/path/to/screenplay.fountain")
let documentID = try await service.parseFile(at: fileURL)

let document = try await service.document(id: documentID)
print("Parsed: \(document.title ?? "Untitled") with \(document.sortedElements.count) elements")
```

**Example 2: Query Dialogue**
```swift
let filter = ElementFilter(
    elementTypes: [.dialogue],
    characterName: "SARAH"
)

let elements = try await service.elements(
    documentID: documentID,
    filter: filter
)

print("Sarah has \(elements.count) dialogue lines")
```

**Example 3: Produciesta Voice Generation Intent**

This example shows how Produciesta can consume `ScreenplayElementsReference` for voice generation:

```swift
// In Produciesta app
import AppIntents
import SwiftCompartido

@available(iOS 26.0, macOS 26.0, *)
public struct GenerateVoiceForElementsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Generate Voice for Screenplay"
    public static let description = IntentDescription(
        "Generate voice audio for screenplay dialogue elements"
    )

    @Parameter(title: "Elements")
    public var elementsReference: ScreenplayElementsReference

    @Parameter(title: "Voice Provider")
    public var voiceProvider: VoiceProviderOption  // ElevenLabs, Apple TTS, etc.

    @Parameter(title: "Voice ID")
    public var voiceID: String

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Filter to dialogue elements (already in reference or filter here)
        let dialogueElements = elementsReference.elements.filter { $0.isDialogue }

        // Generate audio for each dialogue element
        for element in dialogueElements {
            try await voiceService.generate(
                text: element.elementText,
                voiceID: voiceID,
                provider: voiceProvider,
                elementID: element.id,
                characterName: element.characterName
            )

            // Store audio in SwiftData TypedDataStorage linked to element
        }

        let message = """
        Generated \(dialogueElements.count) voice lines for "\(elementsReference.documentTitle)"
        Characters: \(elementsReference.characterNames.joined(separator: ", "))
        """

        return .result(dialog: IntentDialog(message))
    }
}
```

**Example 4: Shortcuts Workflow - Voice Generation**
```
┌─────────────────────────────────────────┐
│ 1. Get File                             │
│    Input: screenplay.fountain           │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│ 2. Parse Screenplay File                │
│    File: screenplay.fountain            │
│    Filter: Dialogue only ✓              │
│    Output: ScreenplayElementsReference  │
│      - documentID                       │
│      - documentTitle: "My Script"       │
│      - elements: [150 dialogue items]   │
│      - characterNames: [SARAH, JOHN]    │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│ 3. Generate Voice for Screenplay        │
│    Elements: (from step 2)              │
│    Voice Provider: ElevenLabs           │
│    Voice ID: rachel                     │
│    Output: "Generated 150 voice lines"  │
└─────────────────────────────────────────┘
```

**Key Benefits:**
- ✅ Only 2 steps (parse + generate) instead of 3+ steps
- ✅ No manual element iteration in Shortcuts
- ✅ Character names available for voice assignment
- ✅ Element IDs preserved for linking audio to database

**Example 5: Shortcuts Workflow - Scene Count**
```
1. User selects screenplay file in Files app
2. Run "Parse Screenplay File" action
   - Filter: Scene Heading only
3. Get count of elements from reference
4. Show result notification: "Your screenplay has 47 scenes"
```

---

## Success Metrics

### Adoption Metrics
- [ ] 10+ example Shortcuts published in documentation
- [ ] Integration guide viewed by 50+ developers
- [ ] 5+ community-created Shortcuts shared

### Technical Metrics
- [ ] 100% test coverage for App Intents code
- [ ] Zero regression bugs in existing APIs
- [ ] < 2s parse time for 1000-element screenplays
- [ ] All CI tests pass (iOS + macOS)

### Quality Metrics
- [ ] Zero breaking changes in 6.1.0 release
- [ ] All App Intents pass App Store review
- [ ] Documentation covers all use cases

---

## Implementation Phases

### Phase 1: Core Service (Week 1)
**Goal**: Create unified API layer that both UI and Intents will use

- [ ] Implement `ParsedFileService` actor
  - ✅ **MUST** delegate to `GuionParsedElementCollection` (no duplicate parsing)
  - ✅ **MUST** delegate to `GuionDocumentModel.from()` (no duplicate conversion)
  - ✅ **MUST** use `document.sortedElements` (no manual sorting)
- [ ] Implement `ElementFilter` struct
- [ ] Write unit tests for service (20 tests)
  - ✅ Verify service uses existing APIs (integration tests)
  - ✅ Test all parsers through service (Fountain, FDX, PDF, etc.)
- [ ] Document service API with emphasis on unified code path

**Acceptance Criteria**:
- [ ] Zero duplicate parsing logic
- [ ] All existing parsers work through service
- [ ] Service can be used by UI code (not just Intents)

### Phase 2: App Intents (Week 2)
**Goal**: Create thin wrappers around ParsedFileService

- [ ] Implement `ScreenplayElementsReference` (primary return type)
- [ ] Implement `ElementReference` (element data struct)
- [ ] Implement `ScreenplayDocumentEntity` (metadata only)
- [ ] Implement `ParseScreenplayFileIntent`
  - ✅ **MUST** call `ParsedFileService.parseFile()` (no direct parser calls)
  - ✅ **MUST** call `ParsedFileService.elements()` for filtering
- [ ] Implement `QueryScreenplayElementsIntent`
  - ✅ **MUST** call `ParsedFileService.elements()` with filter
- [ ] Write App Intent tests (20 tests)
  - ✅ Verify intents delegate to service (no duplicate logic)

**Acceptance Criteria**:
- [ ] App Intents contain ZERO parsing logic
- [ ] All intents delegate to ParsedFileService
- [ ] Intents are < 50 lines each (thin wrappers)

### Phase 3: Export & Shortcuts (Week 3)
**Goal**: Complete workflow support with unified export path

- [ ] Implement `ExportScreenplayIntent`
  - ✅ **MUST** use existing writers (FDXDocumentWriter, FountainTextWriter)
  - ✅ **NO** duplicate export logic
- [ ] Implement `SwiftCompartidoShortcuts` provider
- [ ] Create example Shortcuts
- [ ] Write integration tests via App Intents (10 tests)
  - ✅ Test full stack (parse → query → export → re-parse)
  - ✅ Verify round-trip fidelity

**Acceptance Criteria**:
- [ ] Export intent uses existing writers
- [ ] Integration tests use App Intents (not separate test code)
- [ ] Round-trip tests pass (parse → export → parse → identical)

### Phase 4: Documentation & Polish (Week 4)
**Goal**: Document unified architecture and best practices

- [ ] Write `APP_INTENTS_GUIDE.md`
  - ✅ Emphasize unified code path architecture
  - ✅ Show integration testing examples
- [ ] Write `PARSED_FILE_SERVICE_API.md`
  - ✅ Document service as single source of truth
- [ ] Write `SHORTCUTS_EXAMPLES.md`
- [ ] Update `README.md` and `CLAUDE.md`
  - ✅ Add unified code path architecture diagram
- [ ] Record demo video for Shortcuts integration

**Acceptance Criteria**:
- [ ] Documentation clearly states "no duplicate logic" principle
- [ ] Architecture diagrams show single code path
- [ ] Examples use ParsedFileService (not direct APIs)

---

## Dependencies

### Framework Dependencies

**New:**
- `AppIntents` (iOS 26.0+, macOS 26.0+)

**Existing (no changes):**
- SwiftData
- SwiftUI
- Foundation
- TextBundle
- ZIPFoundation
- swift-markdown
- SwiftGitX

### Package.swift Changes

No changes needed - `AppIntents` is a first-party framework included with iOS/macOS SDKs.

---

## Risk Assessment

### Low Risk
- ✅ Purely additive feature (no breaking changes)
- ✅ All new code is isolated in separate directory
- ✅ Existing tests continue to pass
- ✅ App Intents framework is stable (iOS 16+, mature in iOS 26)

### Medium Risk
- ⚠️ SwiftData thread safety in actor context (mitigated by `@ModelActor`)
- ⚠️ File access permissions in Shortcuts (mitigated by security-scoped URLs)
- ⚠️ Large file parsing performance (mitigated by background tasks)

### Mitigations
- Comprehensive unit and integration tests
- Performance benchmarks for large files
- Error handling with clear user messages
- Documentation with best practices

---

## Open Questions

1. **Q: Should we support iCloud sync for parsed documents?**
   - **A**: Defer to 6.2.0 - focus on local parsing first

2. **Q: Should we cache parsed documents to avoid re-parsing?**
   - **A**: Yes - SwiftData handles caching automatically

3. **Q: Should we support watch complications or widgets?**
   - **A**: Defer to 6.3.0 - focus on Shortcuts first

4. **Q: Should we support live activities for long-running parsing?**
   - **A**: Defer to 6.2.0 - not critical for v1

---

## Changelog Entry (v6.1.0)

```markdown
### Added
- **Parsed File Service**: New `ParsedFileService` actor for headless screenplay parsing
- **App Intents Integration**: Import and query screenplays via Apple Shortcuts
  - `ParseScreenplayFileIntent`: Import screenplay files
  - `QueryScreenplayElementsIntent`: Query elements with filters
  - `ExportScreenplayIntent`: Export to Fountain/FDX/Markdown
- **Element Filtering**: New `ElementFilter` for querying elements by type, character, or chapter
- **Shortcuts Support**: Pre-configured App Shortcuts for common workflows

### Documentation
- Added `APP_INTENTS_GUIDE.md` for Shortcuts integration
- Added `PARSED_FILE_SERVICE_API.md` for service API reference
- Added `SHORTCUTS_EXAMPLES.md` with example workflows
```

---

## References

- [App Intents Documentation](https://developer.apple.com/documentation/appintents)
- [SwiftData Actor Isolation](https://developer.apple.com/documentation/swiftdata/modelactor)
- [Shortcuts Best Practices](https://developer.apple.com/design/human-interface-guidelines/app-shortcuts)
- SwiftCompartido Phase 6 Architecture (CLAUDE.md)
