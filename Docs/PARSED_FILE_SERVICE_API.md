# ParsedFileService API Reference

Complete API documentation for ParsedFileService - the unified service layer for screenplay parsing and querying.

## Overview

`ParsedFileService` is a `@MainActor` class that provides a unified API for:
- Parsing screenplay files (Fountain, FDX, PDF, Markdown, Highland, TextBundle)
- Converting parsed data to SwiftData models
- Querying elements with filtering
- Managing documents in SwiftData

**Architecture**: All App Intents and UI components use ParsedFileService as the single source of truth. This ensures consistent behavior across Shortcuts, programmatic usage, and UI.

## Class Definition

```swift
@available(iOS 26.0, macOS 26.0, *)
@MainActor
public final class ParsedFileService {
    /// Shared singleton instance (uses default SwiftData container)
    public static let shared: ParsedFileService

    /// ModelContainer for SwiftData persistence
    public let modelContainer: ModelContainer

    /// Initializer with custom ModelContainer (for testing)
    public init(modelContainer: ModelContainer)
}
```

## Core Methods

### parseFile(at:progress:)

Parse a screenplay file and store in SwiftData.

```swift
public func parseFile(
    at url: URL,
    progress: OperationProgress? = nil
) async throws -> PersistentIdentifier
```

**Parameters**:
- `url`: File URL to parse (supports Fountain, FDX, PDF, Markdown, Highland, TextBundle)
- `progress`: Optional progress callback for UI updates

**Returns**: `PersistentIdentifier` of the created `GuionDocumentModel`

**Throws**:
- `ParsedFileServiceError.fileNotFound` - File doesn't exist at URL
- `ParsedFileServiceError.unsupportedFormat` - File format not recognized
- `ParsedFileServiceError.parseFailed` - Parse operation failed

**Example**:
```swift
@MainActor
func loadScreenplay(from url: URL) async throws {
    let service = ParsedFileService.shared
    let documentID = try await service.parseFile(at: url)
    print("Parsed document ID: \(documentID)")
}
```

**With Progress**:
```swift
@MainActor
func loadScreenplayWithProgress(from url: URL) async throws {
    let progress = OperationProgress()
    progress.onUpdate = { current, total, message in
        print("Progress: \(current)/\(total) - \(message ?? "")")
    }

    let service = ParsedFileService.shared
    let documentID = try await service.parseFile(at: url, progress: progress)
}
```

**Format Detection**:
- `.fountain` → Fountain parser
- `.fdx` → Final Draft XML parser
- `.pdf` → PDF parser (AI-powered, iOS 26+)
- `.md`, `.markdown` → Markdown parser (with YAML front matter)
- `.highland` → Highland bundle handler → Fountain parser
- `.textbundle` → TextBundle handler → Recursive format detection

### document(id:)

Retrieve a document by its persistent identifier.

```swift
public func document(id: PersistentIdentifier) async throws -> GuionDocumentModel
```

**Parameters**:
- `id`: The persistent identifier of the document

**Returns**: `GuionDocumentModel` instance

**Throws**:
- `ParsedFileServiceError.documentNotFound` - Document doesn't exist

**Example**:
```swift
@MainActor
func getDocument(id: PersistentIdentifier) async throws {
    let service = ParsedFileService.shared
    let document = try await service.document(id: id)
    print("Document title: \(document.title ?? "Untitled")")
    print("Element count: \(document.sortedElements.count)")
}
```

### elements(documentID:filter:)

Query elements from a document with optional filtering.

```swift
public func elements(
    documentID: PersistentIdentifier,
    filter: ElementFilter?
) async throws -> [GuionElementModel]
```

**Parameters**:
- `documentID`: The document to query
- `filter`: Optional filter criteria (see `ElementFilter`)

**Returns**: Array of `GuionElementModel` matching filter criteria

**Throws**:
- `ParsedFileServiceError.documentNotFound` - Document doesn't exist

**Example**:
```swift
@MainActor
func getDialogue(documentID: PersistentIdentifier) async throws {
    let service = ParsedFileService.shared

    // Get all dialogue elements
    let filter = ElementFilter(
        elementTypes: [.dialogue],
        chapterIndex: nil,
        characterName: nil,
        searchText: nil
    )

    let elements = try await service.elements(documentID: documentID, filter: filter)
    print("Found \(elements.count) dialogue elements")
}
```

**Filter Examples**:
```swift
// Filter by element type
let dialogueFilter = ElementFilter(elementTypes: [.dialogue])

// Filter by chapter
let chapter0Filter = ElementFilter(chapterIndex: 0)

// Filter by character
let edwardFilter = ElementFilter(
    elementTypes: [.dialogue],
    characterName: "EDWARD"
)

// Filter by search text
let searchFilter = ElementFilter(searchText: "fish")

// Combine filters
let complexFilter = ElementFilter(
    elementTypes: [.dialogue, .action],
    chapterIndex: 0,
    characterName: nil,
    searchText: "Edward"
)
```

### allDocuments()

Retrieve all documents in the database.

```swift
public func allDocuments() async throws -> [GuionDocumentModel]
```

**Returns**: Array of all `GuionDocumentModel` instances

**Example**:
```swift
@MainActor
func listAllDocuments() async throws {
    let service = ParsedFileService.shared
    let documents = try await service.allDocuments()

    for document in documents {
        print("\(document.title ?? "Untitled"): \(document.sortedElements.count) elements")
    }
}
```

### deleteDocument(id:)

Delete a document and all its elements.

```swift
public func deleteDocument(id: PersistentIdentifier) async throws
```

**Parameters**:
- `id`: The persistent identifier of the document to delete

**Throws**:
- `ParsedFileServiceError.documentNotFound` - Document doesn't exist

**Example**:
```swift
@MainActor
func removeDocument(id: PersistentIdentifier) async throws {
    let service = ParsedFileService.shared
    try await service.deleteDocument(id: id)
    print("Document deleted")
}
```

**Cascade Behavior**:
- Deletes all `GuionElementModel` instances (cascade)
- Deletes all `TitlePageEntryModel` instances (cascade)
- Deletes all `TypedDataStorage` instances (cascade)

## ElementFilter

Filter criteria for element queries.

```swift
@available(iOS 26.0, macOS 26.0, *)
public struct ElementFilter: Sendable {
    /// Filter to specific element types (nil = all types)
    public let elementTypes: [ElementType]?

    /// Filter to specific chapter (nil = all chapters)
    public let chapterIndex: Int?

    /// Filter dialogue to specific character (nil = all characters)
    public let characterName: String?

    /// Filter elements containing text (nil = no text filter)
    public let searchText: String?

    public init(
        elementTypes: [ElementType]? = nil,
        chapterIndex: Int? = nil,
        characterName: String? = nil,
        searchText: String? = nil
    )
}
```

**Usage Examples**:

```swift
// Get all dialogue
let dialogueFilter = ElementFilter(elementTypes: [.dialogue])

// Get all elements in chapter 0
let chapterFilter = ElementFilter(chapterIndex: 0)

// Get Edward's dialogue
let characterFilter = ElementFilter(
    elementTypes: [.dialogue],
    characterName: "EDWARD"
)

// Search for "fish"
let searchFilter = ElementFilter(searchText: "fish")

// Complex: Edward's dialogue in chapter 0 containing "big"
let complexFilter = ElementFilter(
    elementTypes: [.dialogue],
    chapterIndex: 0,
    characterName: "EDWARD",
    searchText: "big"
)
```

## ParsedFileServiceError

Errors thrown by ParsedFileService.

```swift
public enum ParsedFileServiceError: LocalizedError {
    case fileNotFound(URL)
    case unsupportedFormat(String)
    case parseFailed(Error)
    case documentNotFound(PersistentIdentifier)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found at path: \(url.path)"
        case .unsupportedFormat(let format):
            return "Unsupported file format: \(format)"
        case .parseFailed(let error):
            return "Parse failed: \(error.localizedDescription)"
        case .documentNotFound:
            return "Document not found in database"
        }
    }
}
```

**Error Handling**:
```swift
do {
    let documentID = try await service.parseFile(at: url)
} catch ParsedFileServiceError.fileNotFound(let url) {
    print("File not found: \(url.path)")
} catch ParsedFileServiceError.unsupportedFormat(let format) {
    print("Format not supported: \(format)")
} catch ParsedFileServiceError.parseFailed(let error) {
    print("Parse error: \(error)")
} catch {
    print("Unknown error: \(error)")
}
```

## GuionDocumentModel

SwiftData model representing a parsed screenplay document.

```swift
@Model
@available(iOS 26.0, macOS 26.0, *)
public final class GuionDocumentModel {
    // MARK: - Stored Properties

    /// Unique identifier (UUID)
    @Attribute(.unique) public var id: UUID

    /// Document title (from front matter or filename)
    public var title: String?

    /// Filename without extension
    public var filename: String?

    /// Source file path
    public var sourceFilePath: String?

    // MARK: - Relationships

    /// Document elements (use sortedElements for ordered access!)
    @Relationship(deleteRule: .cascade)
    public var elements: [GuionElementModel]

    /// Title page entries
    @Relationship(deleteRule: .cascade)
    public var titlePage: [TitlePageEntryModel]

    /// Generated content attached to document
    @Relationship(deleteRule: .cascade)
    public var generatedContent: [TypedDataStorage]

    // MARK: - Computed Properties

    /// Elements sorted by (chapterIndex, orderIndex)
    public var sortedElements: [GuionElementModel] {
        elements.sorted { lhs, rhs in
            if lhs.chapterIndex != rhs.chapterIndex {
                return lhs.chapterIndex < rhs.chapterIndex
            }
            return lhs.orderIndex < rhs.orderIndex
        }
    }
}
```

**CRITICAL**: Always use `sortedElements`, never `elements`:
```swift
// ✅ CORRECT
for element in document.sortedElements {
    print(element.elementText)
}

// ❌ WRONG - Order not guaranteed!
for element in document.elements {
    print(element.elementText)
}
```

## GuionElementModel

SwiftData model representing a single screenplay element.

```swift
@Model
@available(iOS 26.0, macOS 26.0, *)
public final class GuionElementModel {
    // MARK: - Stored Properties

    /// Unique identifier (UUID)
    @Attribute(.unique) public var id: UUID

    /// Element type (dialogue, action, sceneHeading, etc.)
    public var elementType: ElementType

    /// Element text content
    public var elementText: String

    /// Chapter index (0-based)
    public var chapterIndex: Int

    /// Order within chapter (0-based)
    public var orderIndex: Int

    /// Pre-computed formatted text (bold/italic/underline)
    public var formattedText: AttributedString?

    // MARK: - Relationships

    /// Parent document
    @Relationship(deleteRule: .nullify)
    public var document: GuionDocumentModel?

    /// Generated content attached to element
    @Relationship(deleteRule: .cascade)
    public var generatedContent: [TypedDataStorage]

    // MARK: - Computed Properties

    /// True if this is a dialogue element
    public var isDialogue: Bool {
        elementType == .dialogue
    }

    /// True if this is a scene heading
    public var isSceneHeading: Bool {
        elementType == .sceneHeading
    }

    /// True if this is an action element
    public var isAction: Bool {
        elementType == .action
    }
}
```

## ElementType

Enum representing screenplay element types.

```swift
@available(iOS 26.0, macOS 26.0, *)
public enum ElementType: String, Codable, Sendable {
    case sceneHeading
    case action
    case character
    case dialogue
    case parenthetical
    case transition
    case lyrics
    case pageBreak
    case sectionHeading
    case synopsis
    case boneyard
    case comment
    case unorderedListItem
    case orderedListItem
}
```

## Complete Usage Example

### Parse, Query, and Display

```swift
import SwiftUI
import SwiftData
import SwiftCompartido

@MainActor
struct ScreenplayParserView: View {
    @State private var documentID: PersistentIdentifier?
    @State private var elements: [GuionElementModel] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            Button("Parse Screenplay") {
                Task {
                    await parseScreenplay()
                }
            }

            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            }

            List(elements, id: \.id) { element in
                VStack(alignment: .leading) {
                    Text(element.elementType.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(element.elementText)
                }
            }
        }
    }

    func parseScreenplay() async {
        let service = ParsedFileService.shared

        do {
            // Parse file
            let url = URL(fileURLWithPath: "/path/to/screenplay.fountain")
            let docID = try await service.parseFile(at: url)
            documentID = docID

            // Query dialogue elements
            let filter = ElementFilter(elementTypes: [.dialogue])
            let results = try await service.elements(documentID: docID, filter: filter)
            elements = results

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### Progress Tracking

```swift
@MainActor
class ScreenplayLoader: ObservableObject {
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var documentID: PersistentIdentifier?

    func loadScreenplay(from url: URL) async throws {
        let progressTracker = OperationProgress()

        progressTracker.onUpdate = { [weak self] current, total, message in
            Task { @MainActor in
                self?.progress = Double(current) / Double(total)
                self?.statusMessage = message ?? ""
            }
        }

        let service = ParsedFileService.shared
        let docID = try await service.parseFile(at: url, progress: progressTracker)
        documentID = docID
    }
}
```

### Document Management

```swift
@MainActor
class DocumentManager: ObservableObject {
    @Published var documents: [GuionDocumentModel] = []
    private let service = ParsedFileService.shared

    func loadAllDocuments() async throws {
        documents = try await service.allDocuments()
    }

    func deleteDocument(_ document: GuionDocumentModel) async throws {
        try await service.deleteDocument(id: document.persistentModelID)
        documents.removeAll { $0.id == document.id }
    }

    func searchDocuments(query: String) async throws -> [GuionElementModel] {
        var allResults: [GuionElementModel] = []

        for document in documents {
            let filter = ElementFilter(searchText: query)
            let results = try await service.elements(
                documentID: document.persistentModelID,
                filter: filter
            )
            allResults.append(contentsOf: results)
        }

        return allResults
    }
}
```

## Testing

### Unit Testing with Custom Container

```swift
import Testing
import SwiftData
@testable import SwiftCompartido

@Suite("ParsedFileService Tests")
@MainActor
struct ParsedFileServiceTests {

    private func makeTestContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: GuionDocumentModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return container
    }

    @Test("Parse Fountain file")
    func testParseFountainFile() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let url = URL(fileURLWithPath: "/path/to/test.fountain")
        let documentID = try await service.parseFile(at: url)

        let document = try await service.document(id: documentID)
        #expect(document.sortedElements.count > 0)
    }

    @Test("Query with filter")
    func testQueryWithFilter() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let url = URL(fileURLWithPath: "/path/to/test.fountain")
        let documentID = try await service.parseFile(at: url)

        let filter = ElementFilter(elementTypes: [.dialogue])
        let elements = try await service.elements(documentID: documentID, filter: filter)

        #expect(elements.allSatisfy { $0.elementType == .dialogue })
    }
}
```

## Performance Characteristics

### Parse Performance

| Elements | Parse Time | SwiftData Conversion | Total |
|----------|------------|----------------------|-------|
| 1,000 | 0.016s | 1.1s | 1.2s |
| 5,000 | 0.072s | 23.7s | 24.0s |

**Bottleneck**: SwiftData conversion (94-99% of total time)

### Query Performance

| Operation | Time (1000 elements) | Time (5000 elements) |
|-----------|----------------------|----------------------|
| No filter | 0.001s | 0.005s |
| Type filter | 0.002s | 0.010s |
| Text search | 0.050s | 0.250s |

**Recommendation**: Use filters during parsing for best performance.

## Thread Safety

**IMPORTANT**: ParsedFileService is `@MainActor` isolated. All methods must be called from the main actor:

```swift
// ✅ CORRECT - Called from MainActor context
@MainActor
func loadScreenplay() async throws {
    let service = ParsedFileService.shared
    let documentID = try await service.parseFile(at: url)
}

// ❌ WRONG - Called from background actor
Task.detached {
    let service = ParsedFileService.shared  // ⚠️ Compiler error
}

// ✅ CORRECT - Explicitly switch to MainActor
Task.detached {
    await MainActor.run {
        let service = ParsedFileService.shared
        // ...
    }
}
```

## Best Practices

### 1. Use Shared Instance for App Code

```swift
// ✅ Good - Use shared instance
let service = ParsedFileService.shared

// ❌ Bad - Creating new instances
let service = ParsedFileService(modelContainer: myContainer)
```

**Exception**: Only create custom instances for testing.

### 2. Filter During Parse

```swift
// ✅ Good - Filter during parse
let documentID = try await service.parseFile(at: url)
let elements = try await service.elements(
    documentID: documentID,
    filter: ElementFilter(elementTypes: [.dialogue])
)

// ❌ Bad - Parse all then filter in memory
let documentID = try await service.parseFile(at: url)
let document = try await service.document(id: documentID)
let filtered = document.sortedElements.filter { $0.elementType == .dialogue }
```

### 3. Cache Document IDs

```swift
// ✅ Good - Parse once, query many times
let documentID = try await service.parseFile(at: url)
UserDefaults.standard.set(documentID.description, forKey: "lastDocID")

// Later...
if let idString = UserDefaults.standard.string(forKey: "lastDocID") {
    let elements = try await service.elements(documentID: parsedID, filter: filter)
}

// ❌ Bad - Re-parse for each query
let documentID1 = try await service.parseFile(at: url)
let elements1 = try await service.elements(documentID: documentID1, filter: filter1)

let documentID2 = try await service.parseFile(at: url)  // Wasteful!
let elements2 = try await service.elements(documentID: documentID2, filter: filter2)
```

### 4. Use sortedElements

```swift
// ✅ Good - Guaranteed order
let document = try await service.document(id: documentID)
for element in document.sortedElements {
    print(element.elementText)
}

// ❌ Bad - Undefined order
for element in document.elements {
    print(element.elementText)
}
```

### 5. Handle Errors

```swift
// ✅ Good - Specific error handling
do {
    let documentID = try await service.parseFile(at: url)
} catch ParsedFileServiceError.fileNotFound {
    showAlert("File not found")
} catch ParsedFileServiceError.parseFailed(let error) {
    showAlert("Parse failed: \(error)")
} catch {
    showAlert("Unknown error: \(error)")
}

// ❌ Bad - Generic catch
do {
    let documentID = try await service.parseFile(at: url)
} catch {
    print("Error: \(error)")  // Loses error detail
}
```

## See Also

- `APP_INTENTS_GUIDE.md` - User guide for Shortcuts integration
- `AI-REFERENCE.md` - Complete API reference
- `README.md` - Project overview
- `CLAUDE.md` - Development guide
