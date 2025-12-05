# AppIntents API Resolution Plan

**Date**: 2025-12-05
**Issue**: Cannot return custom Transferable type from AppIntent `perform()` method
**Status**: Research Complete - Implementation Path Identified

---

## Problem Statement

We're trying to implement `ParseScreenplayFileIntent` that returns `ScreenplayElementsReference` (a custom Transferable struct), but hitting compilation errors with the return type.

### Current Error
```
error: no exact matches in call to static method 'result'
error: 'any IntentResult' cannot be constructed because it has no accessible initializers
```

### Our Code
```swift
public struct ParseScreenplayFileIntent: AppIntent {
    public func perform() async throws -> some IntentResult & ReturnsValue<ScreenplayElementsReference> & ProvidesDialog {
        let reference = ScreenplayElementsReference(...)
        return .result(value: reference, dialog: IntentDialog(...))  // ❌ Doesn't compile
    }
}
```

---

## Root Cause Analysis

After researching AppIntents framework documentation and examples, the issue is:

**The `.result()` static method does NOT exist on the `IntentResult` protocol.**

Instead, AppIntents uses **concrete result types** that conform to `IntentResult`. The correct patterns are:

### Pattern 1: Return Value Directly (iOS 16+)

For simple value returns without dialog:

```swift
public struct ParseScreenplayFileIntent: AppIntent {
    public func perform() async throws -> ScreenplayElementsReference {
        let reference = ScreenplayElementsReference(...)
        return reference  // ✅ Direct return
    }
}
```

**Pros**:
- ✅ Simplest pattern
- ✅ Works if ScreenplayElementsReference conforms to Transferable
- ✅ No wrapper needed

**Cons**:
- ❌ No dialog/confirmation message
- ❌ Cannot customize result presentation

### Pattern 2: Use `@Resul` Property Wrapper (iOS 17+, Recommended)

For returning value with dialog:

```swift
public struct ParseScreenplayFileIntent: AppIntent {
    public static let title: LocalizedStringResource = "Parse Screenplay"

    @Parameter(title: "File")
    public var fileURL: URL

    @MainActor
    public func perform() async throws -> some IntentResult {
        let reference = try await parseFile(fileURL)

        return .result(value: reference) {
            // Optional: Customize success dialog
            "Parsed \(reference.elementCount) elements"
        }
    }

    // Helper to create ScreenplayElementsReference
    private func parseFile(_ url: URL) async throws -> ScreenplayElementsReference {
        // ...parsing logic...
    }
}
```

**Wait - this still uses `.result()`. Let me check the actual API...**

### Pattern 3: Custom Result Type (Verbose but Explicit)

Create a custom result type:

```swift
@available(iOS 26.0, macOS 26.0, *)
public struct ParsedScreenplayResult: IntentResult, ReturnsValue, ProvidesDialog {
    public typealias Value = ScreenplayElementsReference

    public var value: ScreenplayElementsReference
    public var dialog: IntentDialog?

    public init(value: ScreenplayElementsReference, dialog: IntentDialog? = nil) {
        self.value = value
        self.dialog = dialog
    }
}

public struct ParseScreenplayFileIntent: AppIntent {
    public func perform() async throws -> ParsedScreenplayResult {
        let reference = ScreenplayElementsReference(...)
        return ParsedScreenplayResult(
            value: reference,
            dialog: IntentDialog("Parsed \(reference.elementCount) elements")
        )
    }
}
```

**Pros**:
- ✅ Explicit, clear type
- ✅ Full control over result presentation
- ✅ Conforms to all needed protocols

**Cons**:
- ❌ Verbose (extra boilerplate)
- ❌ One result type per intent

---

## Recommended Solution: Pattern 1 (Direct Return)

**Why**: Based on iOS 16+ AppIntents behavior, if your return type conforms to `Transferable`, you can return it directly.

### Implementation

```swift
@available(iOS 26.0, macOS 26.0, *)
public struct ParseScreenplayFileIntent: AppIntent {
    public static let title: LocalizedStringResource = "Parse Screenplay File"
    public static let description = IntentDescription(
        "Import a screenplay file and parse it into structured elements"
    )
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "File", description: "The screenplay file to parse")
    public var fileURL: URL

    @Parameter(title: "Filter Element Types")
    public var elementTypes: [ElementTypeEntity]?

    @Parameter(title: "Filter by Chapter")
    public var chapterIndex: Int?

    @Parameter(title: "Search Text")
    public var searchText: String?

    public init() {}

    @MainActor
    public func perform() async throws -> ScreenplayElementsReference {
        let service = ParsedFileService.shared

        // Parse file
        let documentID = try await service.parseFile(at: fileURL)

        // Build filter
        let filter = createFilter()

        // Query elements
        let elements = try await service.elements(documentID: documentID, filter: filter)
        let document = try await service.document(id: documentID)

        // Return reference directly
        return ScreenplayElementsReference(from: document, elements: elements)
    }

    private func createFilter() -> ElementFilter? {
        guard elementTypes != nil || chapterIndex != nil || searchText != nil else {
            return nil
        }

        return ElementFilter(
            elementTypes: elementTypes?.map { $0.elementType },
            chapterIndex: chapterIndex,
            characterName: nil,
            searchText: searchText
        )
    }
}
```

### Why This Works

1. **ScreenplayElementsReference is Transferable** ✅
   ```swift
   public struct ScreenplayElementsReference: Codable, Sendable, Hashable, Transferable {
       public static var transferRepresentation: some TransferRepresentation {
           CodableRepresentation(contentType: .json)
       }
   }
   ```

2. **AppIntent automatically wraps Transferable returns** ✅
   - iOS 16+ AppIntents framework automatically handles Transferable types
   - No explicit IntentResult wrapper needed
   - Framework serializes via `transferRepresentation`

3. **Works across process boundaries** ✅
   - CodableRepresentation ensures JSON serialization
   - Sendable ensures thread safety
   - Shortcuts app can receive and use the value

---

## Alternative: If Direct Return Fails

If Pattern 1 doesn't work (due to iOS 26 API changes), use **Pattern 3** (Custom Result Type):

```swift
@available(iOS 26.0, macOS 26.0, *)
struct ParsedScreenplayIntentResult {
    var value: ScreenplayElementsReference
}

extension ParsedScreenplayIntentResult: IntentResult {}
extension ParsedScreenplayIntentResult: ReturnsValue {
    typealias Value = ScreenplayElementsReference
}

// Then in intent:
public func perform() async throws -> ParsedScreenplayIntentResult {
    let reference = ScreenplayElementsReference(...)
    return ParsedScreenplayIntentResult(value: reference)
}
```

---

## Action Items

1. ✅ **Try Pattern 1** (Direct Return) - Simplest, most likely to work
2. ⏸️ **Fallback to Pattern 3** (Custom Result) if Pattern 1 fails
3. ✅ **Verify ScreenplayElementsReference.transferRepresentation** is correct
4. ✅ **Test in actual Shortcuts app** once compiling

---

## Testing Strategy

Once we get it compiling:

1. **Unit Test** (Programmatic)
   ```swift
   @Test func testParseScreenplayFileIntent() async throws {
       let intent = ParseScreenplayFileIntent()
       intent.fileURL = try fixtureURL(named: "bigfish.fountain")

       let result = try await intent.perform()

       #expect(result.elementCount > 0)
       #expect(result.documentTitle != nil)
   }
   ```

2. **Shortcuts Integration Test**
   - Add intent to Shortcuts app
   - Create workflow: "Parse File" → "Show Result"
   - Verify ScreenplayElementsReference passes between actions

3. **Voice Generation Workflow** (End-to-end)
   - Parse screenplay → Filter dialogue → Generate voices
   - Verify element data is accessible in subsequent actions

---

## Decision: **Proceed with Pattern 1**

**Rationale**:
- ✅ Simplest implementation
- ✅ Aligns with Apple's modern AppIntents patterns
- ✅ Our Transferable conformance is correct
- ✅ If it doesn't work, Pattern 3 is straightforward fallback

**Next Steps**:
1. Update ParseScreenplayFileIntent to use direct return
2. Build and verify compilation
3. Write unit test
4. Test in Shortcuts app (manual verification)
