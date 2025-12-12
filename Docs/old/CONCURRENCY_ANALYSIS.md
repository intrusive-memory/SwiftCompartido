# Concurrency Analysis: ParsedFileService

**Date**: 2025-12-05
**Context**: Phase 1 implementation of ParsedFileService

## Current Architecture

### ParsedFileService Definition

```swift
@available(iOS 26.0, macOS 26.0, *)
public actor ParsedFileService {
    private let modelContainer: ModelContainer

    @MainActor
    public func parseFile(at url: URL, progress: OperationProgress? = nil) async throws -> PersistentIdentifier

    @MainActor
    public func document(id: PersistentIdentifier) async throws -> GuionDocumentModel

    @MainActor
    public func elements(documentID: PersistentIdentifier, filter: ElementFilter? = nil) async throws -> [GuionElementModel]
}
```

### Key Observations

1. **ParsedFileService is an `actor`** (line 34)
   - Provides isolated execution context
   - All methods run on the actor's executor by default

2. **All public methods are `@MainActor` isolated** (lines 57, 96, 117)
   - `parseFile()` - Main actor isolated
   - `document()` - Main actor isolated
   - `elements()` - Main actor isolated

3. **Return types are NOT Sendable**:
   - `GuionDocumentModel` - SwiftData `@Model` class (not Sendable)
   - `GuionElementModel` - SwiftData `@Model` class (not Sendable)

## Problem Identified

### Issue 1: Actor + @MainActor Conflict

**Problem**: You cannot have an `actor` with `@MainActor` methods. This is contradictory:
- `actor ParsedFileService` creates its own isolated executor
- `@MainActor func parseFile()` tries to run on the main actor's executor
- These are **two different executors**

**Error manifestation**:
```
error: returning a main actor-isolated 'GuionDocumentModel' value as a 'sending' result
risks causing data races
```

### Issue 2: Non-Sendable Return Types

**Problem**: Returning `GuionDocumentModel` and `[GuionElementModel]` from async methods:
- These are SwiftData `@Model` classes
- `@Model` classes are NOT `Sendable` by design
- They can only be safely accessed on one isolation domain

**Current flow**:
1. Test (nonisolated) → calls → `service.document(id:)`
2. `service.document(id:)` (@MainActor) → returns → `GuionDocumentModel` (not Sendable)
3. Compiler error: Cannot return non-Sendable type across actor boundary

## Root Cause Analysis

The architecture has **three conflicting requirements**:

1. **SwiftData requirement**: `GuionDocumentModel.from()` is `@MainActor` isolated
2. **Actor design**: `ParsedFileService` is an `actor` (custom executor)
3. **Return types**: `GuionDocumentModel` is NOT `Sendable`

**These three cannot coexist in the current design.**

## Solution Options

### Option 1: Remove `actor`, Use `@MainActor` Class ✅ RECOMMENDED

**Change**:
```swift
@MainActor
public final class ParsedFileService {
    private let modelContainer: ModelContainer

    public func parseFile(...) async throws -> PersistentIdentifier { }
    public func document(id:) async throws -> GuionDocumentModel { }
    public func elements(...) async throws -> [GuionElementModel] { }
}
```

**Pros**:
- ✅ All methods run on main actor (matches `GuionDocumentModel.from()`)
- ✅ Can return non-Sendable types (all on same actor)
- ✅ Simple, clear ownership model
- ✅ Matches SwiftUI/SwiftData patterns

**Cons**:
- ❌ Not thread-safe for concurrent calls (but SwiftData ModelContext isn't either)
- ❌ Blocks main thread during parsing (but we do async work anyway)

**Verdict**: **Best option** - aligns with SwiftData's main-actor isolation model.

---

### Option 2: Keep `actor`, Return `PersistentIdentifier` Only

**Change**:
```swift
public actor ParsedFileService {
    private let modelContainer: ModelContainer

    // Returns Sendable ID, not the model
    public func parseFile(...) async throws -> PersistentIdentifier { }

    // NO document() or elements() methods
    // Clients create their own ModelContext on @MainActor
}
```

**Pros**:
- ✅ Actor provides true thread safety
- ✅ Only returns Sendable types (PersistentIdentifier)

**Cons**:
- ❌ Breaks unified code path requirement (UI has to write separate logic)
- ❌ Clients must create ModelContext themselves (defeats purpose of service)
- ❌ Cannot query elements (main feature requirement)

**Verdict**: **Not viable** - violates core requirements.

---

### Option 3: Nonisolated Actor with `assumeIsolated`

**Change**:
```swift
public actor ParsedFileService {
    nonisolated public func document(id: PersistentIdentifier) async throws -> GuionDocumentModel {
        await MainActor.run {
            let modelContext = ModelContext(modelContainer)
            // ...
        }
    }
}
```

**Pros**:
- ✅ Keeps actor for theoretical thread safety

**Cons**:
- ❌ Verbose and error-prone
- ❌ Still cannot return non-Sendable from nonisolated context
- ❌ Requires `MainActor.run { }` everywhere
- ❌ Doesn't solve the fundamental Sendable problem

**Verdict**: **Not viable** - doesn't fix the core issue.

---

### Option 4: Make Models Sendable (Not Possible)

**Change**: Mark `GuionDocumentModel` as `Sendable`

**Why not possible**:
- SwiftData `@Model` classes are intentionally NOT `Sendable`
- They contain mutable state tied to a ModelContext
- Making them Sendable would be a lie and cause data races

**Verdict**: **Impossible** - conflicts with SwiftData design.

---

## Recommended Solution: Option 1

### Implementation

```swift
/// Unified service for parsing screenplay files and querying elements.
///
/// This class provides @MainActor-isolated access to screenplay parsing and database operations.
/// All methods run on the main actor to align with SwiftData's isolation requirements.
@available(iOS 26.0, macOS 26.0, *)
@MainActor
public final class ParsedFileService {

    private let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    public func parseFile(
        at url: URL,
        progress: OperationProgress? = nil
    ) async throws -> PersistentIdentifier {
        let modelContext = ModelContext(modelContainer)

        let screenplay = try await GuionParsedElementCollection(file: url.path, progress: progress)
        let document = await GuionDocumentModel.from(screenplay, in: modelContext, generateSummaries: false, progress: progress)

        modelContext.insert(document)
        try modelContext.save()

        return document.persistentModelID
    }

    public func document(id: PersistentIdentifier) async throws -> GuionDocumentModel {
        let modelContext = ModelContext(modelContainer)

        guard let document = modelContext.model(for: id) as? GuionDocumentModel else {
            throw ParsedFileServiceError.documentNotFound(id: id)
        }

        return document
    }

    public func elements(
        documentID: PersistentIdentifier,
        filter: ElementFilter? = nil
    ) async throws -> [GuionElementModel] {
        let document = try await self.document(id: documentID)

        var elements = document.sortedElements

        if let filter = filter, !filter.isEmpty {
            elements = elements.filter { filter.matches($0) }
        }

        return elements
    }

    public static let shared: ParsedFileService = {
        do {
            let container = try ModelContainer(
                for: GuionDocumentModel.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
            return ParsedFileService(modelContainer: container)
        } catch {
            fatalError("Failed to create shared ParsedFileService: \(error)")
        }
    }()
}
```

### Test Changes

Tests should be `@MainActor` isolated:

```swift
@Suite("ParsedFileService Tests")
@MainActor
struct ParsedFileServiceTests {

    @Test("Parse Fountain file returns valid document ID")
    func testParseFountainFile() async throws {
        let container = try makeTestContainer()
        let service = ParsedFileService(modelContainer: container)

        let fileURL = try fixtureURL(named: "bigfish.fountain")
        let documentID = try await service.parseFile(at: fileURL)

        let document = try await service.document(id: documentID)
        let title = document.title
        let count = document.sortedElements.count
        let filename = document.filename

        #expect(title != nil)
        #expect(count > 0)
        #expect(filename == "bigfish.fountain")
    }
}
```

**Key test patterns**:
- Extract values to local variables BEFORE using in `#expect`
- This avoids capturing non-Sendable types in macro expansion
- All assertions use local Sendable values (String, Int, Bool)

---

## Why This Works

1. **Single isolation domain**: Everything runs on `@MainActor`
   - Service methods: `@MainActor`
   - `GuionDocumentModel.from()`: `@MainActor`
   - Test methods: `@MainActor`

2. **No cross-actor communication**: All non-Sendable types stay on main actor

3. **Aligns with SwiftData**: ModelContext is designed for single-threaded access

4. **Simple mental model**: "All SwiftData operations happen on main actor"

---

## Action Items

1. ✅ Change `public actor ParsedFileService` → `@MainActor public final class ParsedFileService`
2. ✅ Remove `@MainActor` from individual methods (class is already isolated)
3. ✅ Keep tests `@MainActor` isolated
4. ✅ Extract values to local variables before using in `#expect` macros
5. ✅ Update documentation to reflect main-actor isolation

---

## Alternative Considered: Hybrid Approach

**Not recommended**, but documented for completeness:

```swift
public actor ParsedFileService {
    // Parsing returns Sendable ID only
    nonisolated public func parseFile(...) async throws -> PersistentIdentifier {
        await MainActor.run {
            // parsing logic
        }
    }
}

// Separate query service
@MainActor
public final class ScreenplayQueryService {
    public func document(id:) -> GuionDocumentModel { }
    public func elements(...) -> [GuionElementModel] { }
}
```

**Why not**: Splits unified code path requirement, adds complexity.
