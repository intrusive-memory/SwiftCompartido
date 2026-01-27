# SwiftData Architecture

This document describes SwiftCompartido's SwiftData model architecture, relationships, and cascade delete strategy.

## SwiftData Relationships and Cascade Delete Strategy

**IMPORTANT**: All `@Relationship` decorators omit the `inverse:` parameter to avoid macro expansion circular reference errors in Swift 6. SwiftData automatically infers inverse relationships.

## Relationship Graph

```
GuionDocumentModel (parent)
    ├─→ elements: [GuionElementModel] (@Relationship deleteRule: .cascade)
    ├─→ titlePage: [TitlePageEntryModel] (@Relationship deleteRule: .cascade)
    ├─→ customPages: [CustomPageModel] (@Relationship deleteRule: .cascade)
    ├─→ casting: [CharacterVoiceMapping] (@Relationship deleteRule: .cascade)
    └─→ generatedContent: [TypedDataStorage] (@Relationship deleteRule: .cascade)

GuionElementModel
    ├─→ document: GuionDocumentModel? (@Relationship deleteRule: .nullify)
    └─→ generatedContent: [TypedDataStorage] (@Relationship deleteRule: .cascade)

CharacterVoiceMapping (leaf node)
    └─→ document: GuionDocumentModel? (@Relationship deleteRule: .nullify)

TypedDataStorage (leaf node)
    ├─→ owningElement: GuionElementModel? (@Relationship deleteRule: .nullify)
    └─→ owningDocument: GuionDocumentModel? (@Relationship deleteRule: .nullify)

CustomPageModel (leaf node)
    └─→ document: GuionDocumentModel? (no @Relationship decorator)

TitlePageEntryModel (leaf node)
    └─→ document: GuionDocumentModel? (no @Relationship decorator)
```

## Cascade Delete Behavior

### When a Document is Deleted

**All child records are automatically deleted**:
- ✅ All elements (`GuionElementModel`) are deleted (`.cascade`)
- ✅ All title page entries (`TitlePageEntryModel`) are deleted (`.cascade`)
- ✅ All custom pages (`CustomPageModel`) are deleted (`.cascade`)
- ✅ All character voice mappings (`CharacterVoiceMapping`) are deleted (`.cascade`)
- ✅ All document-level generated content (`TypedDataStorage`) is deleted (`.cascade`)
- ✅ Element-level generated content is deleted via element cascade

**Example**:
```swift
// Delete document
modelContext.delete(document)
try modelContext.save()

// Result: Document + 5000 elements + 100 content records = ALL deleted
```

### When an Element is Deleted

**Element-level content is deleted, but document is preserved**:
- ✅ All element-level generated content (`TypedDataStorage`) is deleted (`.cascade`)
- ❌ Parent document is **NOT** deleted (`.nullify`)

**Example**:
```swift
// Delete single element
modelContext.delete(element)
try modelContext.save()

// Result: Element + 3 audio records deleted, document untouched
```

### When Generated Content is Deleted

**Orphaned content, no parent deletion**:
- ❌ Owning element is **NOT** deleted (`.nullify`)
- ❌ Owning document is **NOT** deleted (`.nullify`)

**Example**:
```swift
// Delete audio record
modelContext.delete(audioRecord)
try modelContext.save()

// Result: Audio record deleted, element and document untouched
```

## Why No `inverse:` Parameters?

The `inverse:` parameter in `@Relationship` macros can cause circular reference errors during macro expansion in Swift 6:

```swift
// ❌ PROBLEMATIC - Causes circular reference errors
@Model
class GuionDocumentModel {
    @Relationship(deleteRule: .cascade, inverse: \GuionElementModel.document)
    var elements: [GuionElementModel]
}

@Model
class GuionElementModel {
    @Relationship(deleteRule: .nullify, inverse: \GuionDocumentModel.elements)
    var document: GuionDocumentModel?
}
```

By omitting `inverse:` parameters:
1. ✅ SwiftData still correctly infers bidirectional relationships
2. ✅ All cascade delete rules work as expected
3. ✅ Macro expansion completes without circular reference errors
4. ✅ The relationship graph remains functionally identical

## Proper Relationship Usage Example

```swift
// ✅ CORRECT - Document owns elements
@Model
class GuionDocumentModel {
    @Relationship(deleteRule: .cascade)  // No inverse: parameter
    var elements: [GuionElementModel]
}

// ✅ CORRECT - Element references document
@Model
class GuionElementModel {
    @Relationship(deleteRule: .nullify)  // No inverse: parameter
    var document: GuionDocumentModel?
}

// Result: Deleting document cascades to elements, but deleting element doesn't affect document
```

## Element Ordering

**CRITICAL: Always use `document.sortedElements`** - SwiftData `@Relationship` arrays do **NOT** guarantee order!

```swift
// ❌ WRONG - Order not guaranteed
for element in document.elements {
    print(element.text)
}

// ✅ CORRECT - Always sorted
for element in document.sortedElements {
    print(element.text)
}
```

### Why Order Isn't Guaranteed

SwiftData `@Relationship` arrays are unordered sets internally. Elements may be returned in:
- Database insertion order
- Random order after fetch
- Different order after model context changes

### Composite Key Ordering

Elements use a composite key for ordering:
```swift
public var sortedElements: [GuionElementModel] {
    elements.sorted { lhs, rhs in
        if lhs.chapterIndex != rhs.chapterIndex {
            return lhs.chapterIndex < rhs.chapterIndex
        }
        return lhs.orderIndex < rhs.orderIndex
    }
}
```

**Chapter Index Values**:
- `0`: Before any chapters (title page, cold opens)
- `1`: Chapter 1
- `2`: Chapter 2
- `n`: Chapter n

**Order Index**: Sequential position within chapter (0, 1, 2, ...)

## DocumentModelActor Pattern

For safe SwiftData operations in async contexts, use `DocumentModelActor`:

```swift
import SwiftData

@ModelActor
actor DocumentModelActor {
    // All SwiftData operations happen here
    func getElements(for documentID: PersistentIdentifier, limit: Int) throws -> [ElementInfo] {
        guard let document = self[documentID, as: GuionDocumentModel.self] else {
            throw ActorError.documentNotFound
        }

        // ✅ ALWAYS use sortedElements
        return document.sortedElements.prefix(limit).map { element in
            ElementInfo(from: element)  // Return Sendable DTO
        }
    }
}
```

**Key Principles**:
1. All database operations happen inside the actor
2. Actor returns **Sendable DTOs** (never Model instances)
3. MainActor UI displays DTOs (no actor boundary crossing)
4. Elements **always** retrieved via `sortedElements`

See `Sources/SwiftCompartido/Actors/DocumentModelActor.swift` for full implementation.

## Model Pairs Pattern

Each data type has **TWO** models:

### DTO Models (In-Memory, Sendable)
- `GeneratedTextData`
- `GeneratedAudioData`
- `GeneratedImageData`
- `GeneratedEmbeddingData`

**Purpose**:
- Transfer data between actors/threads
- Short-lived, never persisted
- Sendable (can cross actor boundaries)

### SwiftData Models (Persistent)
- **Primary**: `TypedDataStorage` - Unified model for all AI-generated content
- **Legacy**: `GeneratedTextRecord`, `GeneratedAudioRecord` (deprecated type aliases)

**Purpose**:
- Long-term storage in SwiftData
- Relationship management
- Cascade delete behavior

**DO NOT consolidate DTO models** - they serve different purposes than persistent models.

## Phase 6 Storage Architecture

Large content (audio, images) follows this pattern to prevent main thread blocking:

1. **Background thread**: Generate content → Write to file in `StorageAreaReference`
2. **Create reference**: Lightweight `TypedDataFileReference` (metadata only)
3. **Main thread**: Store file reference in SwiftData (NOT the data)
4. **Playback/display**: Load from file URL directly

**Storage Decision Tree**:
- Text < 10KB → Store in `TypedDataStorage.textValue`
- Text ≥ 10KB → Write to file, store `TypedDataFileReference`
- Audio/Images → **ALWAYS** use file storage
- Embeddings → In-memory or file-based

**Example**:
```swift
let requestID = UUID()
let storage = StorageAreaReference.temporary(requestID: requestID)

// Write to file (background thread)
let audioData = try await generateAudio()
let fileRef = try await TypedDataFileReference(
    fileURL: storage.audioURL(named: "speech.mp3"),
    mimeType: "audio/mpeg"
)

// Store metadata only (main thread)
let record = TypedDataStorage(
    id: requestID,
    providerId: "elevenlabs",
    fileReference: fileRef
)
modelContext.insert(record)
try modelContext.save()
```

## References

- Model Definitions: `Sources/SwiftCompartido/SwiftDataModels/`
- DocumentModelActor: `Sources/SwiftCompartido/Actors/DocumentModelActor.swift`
- Phase 6 Architecture: `Sources/SwiftCompartido/Models/Phase6/`
- DTO Models: `Sources/SwiftCompartido/Models/DTOs/`
