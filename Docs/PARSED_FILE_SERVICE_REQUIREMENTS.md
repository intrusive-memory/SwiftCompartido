# Parsed File Service Requirements (v6.1.0)

## Overview

SwiftCompartido 6.1.0 introduces a **Parsed File Service** powered by App Intents, enabling external clients (including Apple Shortcuts) to import screenplay files and receive structured document references and element collections from the SwiftData database.

**Design Principle**: This feature is **purely additive** with zero breaking changes to existing APIs.

---

## Goals

1. **Enable Shortcuts Integration**: Allow users to parse screenplay files via Siri Shortcuts
2. **Headless Parsing**: Support parsing without UI/view dependencies
3. **Database Integration**: Return persistent SwiftData document references
4. **Query Support**: Provide element collection queries for downstream processing
5. **Format Agnostic**: Support all existing screenplay formats (Fountain, FDX, PDF, Markdown, Highland, TextBundle)

---

## User Stories

### Story 1: Import Screenplay via Shortcuts
**As a** Shortcuts user
**I want to** select a screenplay file and import it into SwiftCompartido's database
**So that** I can access structured screenplay data in other apps

**Acceptance Criteria**:
- [ ] Shortcut action appears in Shortcuts app
- [ ] User can select file from Files app, iCloud Drive, or Dropbox
- [ ] Action returns document ID for chaining with other shortcuts
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

### Story 3: Batch Import via Shortcuts
**As a** power user
**I want to** import multiple screenplay files in one shortcut
**So that** I can process entire folders of scripts

**Acceptance Criteria**:
- [ ] Accept array of file URLs
- [ ] Return array of document IDs
- [ ] Handle partial failures gracefully

### Story 4: Export Document via Shortcuts
**As a** user
**I want to** export a parsed document to Fountain/FDX/PDF
**So that** I can share formatted screenplays

**Acceptance Criteria**:
- [ ] Accept document ID
- [ ] Accept target format (fountain, fdx, pdf)
- [ ] Return file URL to exported document

---

## Technical Architecture

### Phase 1: App Intent Framework (v6.1.0)

#### New Types

**1. `ParsedFileService` (Actor)**
- **Purpose**: Headless parsing service with SwiftData integration
- **Location**: `Sources/SwiftCompartido/Services/ParsedFileService.swift`
- **Responsibilities**:
  - Parse screenplay files to `GuionParsedElementCollection`
  - Convert to `GuionDocumentModel` and insert into SwiftData
  - Return document ID for query operations
  - Manage temporary storage for file references

```swift
@available(iOS 26.0, macOS 26.0, *)
public actor ParsedFileService {
    private let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer)

    /// Parse file and insert into database
    public func parseFile(
        at url: URL,
        sourceTracking: SourceFileTrackingMode = .enabled
    ) async throws -> PersistentIdentifier

    /// Retrieve document by ID
    public func document(
        id: PersistentIdentifier
    ) async throws -> GuionDocumentModel

    /// Query elements from document
    public func elements(
        documentID: PersistentIdentifier,
        filter: ElementFilter?
    ) async throws -> [GuionElementModel]
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

**3. App Intent Entities**

**`ScreenplayDocumentEntity` (AppEntity)**
- Represents a parsed screenplay document
- Conforms to `AppEntity` for Shortcuts integration

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

**`ScreenplayElementEntity` (Transferable)**
- Represents screenplay element data for Shortcuts output

```swift
@available(iOS 26.0, macOS 26.0, *)
public struct ScreenplayElementEntity: Codable, Sendable {
    public let elementType: ElementType
    public let elementText: String
    public let chapterIndex: Int
    public let orderIndex: Int
    public let characterName: String?
}
```

**4. App Intents**

**`ParseScreenplayFileIntent`**
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
        title: "Track Source File",
        description: "Enable source file tracking for change detection",
        default: true
    )
    public var trackSource: Bool

    public static var parameterSummary: some ParameterSummary {
        Summary("Parse \(\.$file)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<ScreenplayDocumentEntity> {
        // Implementation
    }
}
```

**`QueryScreenplayElementsIntent`**
```swift
@available(iOS 26.0, macOS 26.0, *)
public struct QueryScreenplayElementsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Query Screenplay Elements"
    public static let description = IntentDescription(
        "Retrieve screenplay elements with optional filters"
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
        Summary("Query elements from \(\.$document)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[ScreenplayElementEntity]> {
        // Implementation
    }
}
```

**`ExportScreenplayIntent`**
```swift
@available(iOS 26.0, macOS 26.0, *)
public struct ExportScreenplayIntent: AppIntent {
    public static let title: LocalizedStringResource = "Export Screenplay"
    public static let description = IntentDescription(
        "Export a screenplay document to a file format"
    )

    @Parameter(title: "Document")
    public var document: ScreenplayDocumentEntity

    @Parameter(
        title: "Format",
        default: ExportFormat.fountain
    )
    public var format: ExportFormat

    public static var parameterSummary: some ParameterSummary {
        Summary("Export \(\.$document) as \(\.$format)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        // Implementation
    }
}

public enum ExportFormat: String, AppEnum {
    case fountain
    case fdx
    case markdown

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

**5. App Shortcuts Provider**

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
│   │   ├── ScreenplayDocumentEntity.swift   (NEW)
│   │   └── ScreenplayElementEntity.swift    (NEW)
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

**App Intent Tests (15 tests)**
- ✅ ParseScreenplayFileIntent with valid file → Returns entity
- ✅ ParseScreenplayFileIntent with invalid file → Throws error
- ✅ QueryScreenplayElementsIntent with filters → Returns filtered results
- ✅ QueryScreenplayElementsIntent without filters → Returns all elements
- ✅ ExportScreenplayIntent to Fountain → Returns valid file
- ✅ ExportScreenplayIntent to FDX → Returns valid file
- ✅ Entity display representation → Correct title/subtitle

### Integration Tests

**Shortcut Workflow Tests (10 tests)**
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

**Example 3: Shortcuts Workflow**
```
1. User selects screenplay file in Files app
2. Run "Parse Screenplay File" action
3. Pass document entity to "Query Screenplay Elements" action
4. Filter by element type: "Scene Heading"
5. Count items → Get number of scenes
6. Show result notification
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
- [ ] Implement `ParsedFileService` actor
- [ ] Implement `ElementFilter` struct
- [ ] Write unit tests for service (20 tests)
- [ ] Document service API

### Phase 2: App Intents (Week 2)
- [ ] Implement `ScreenplayDocumentEntity`
- [ ] Implement `ScreenplayElementEntity`
- [ ] Implement `ParseScreenplayFileIntent`
- [ ] Implement `QueryScreenplayElementsIntent`
- [ ] Write App Intent tests (15 tests)

### Phase 3: Export & Shortcuts (Week 3)
- [ ] Implement `ExportScreenplayIntent`
- [ ] Implement `SwiftCompartidoShortcuts` provider
- [ ] Create example Shortcuts
- [ ] Write integration tests (10 tests)

### Phase 4: Documentation & Polish (Week 4)
- [ ] Write `APP_INTENTS_GUIDE.md`
- [ ] Write `PARSED_FILE_SERVICE_API.md`
- [ ] Write `SHORTCUTS_EXAMPLES.md`
- [ ] Update `README.md` and `CLAUDE.md`
- [ ] Record demo video for Shortcuts integration

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
