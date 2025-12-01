# Custom Pages Support - Requirements Document

## Overview

Add support for Highland's Custom Pages feature to SwiftCompartido, starting with Cast List pages. Custom pages are additional non-screenplay pages (cast lists, production notes, concept images, etc.) that can be included when printing or exporting a screenplay.

## Analysis of custom-pages.json Structure

### File Location: `Fixtures/custom-pages.json`

The JSON contains an array of custom page objects with three identified types:

1. **Cast List** (`type: "castList"`)
   - Properties:
     - `id`: UUID string
     - `title`: String (e.g., "Cast List")
     - `type`: "castList"
     - `position`: Int (print order position)
     - `printDots`: Bool (whether to print dots between role and actor name)
     - `items`: Array of cast members
       - `id`: UUID string
       - `role`: String (character name)
       - `name`: String (actor name, can be empty)
       - `position`: Int (always 0 in sample)

2. **Advanced Page** (`type: "advanced"`)
   - Properties:
     - `id`: UUID string
     - `title`: String
     - `type`: "advanced"
     - `position`: Int
     - `tc`, `tl`, `tr`, `cl`, `cc`, `cr`, `bl`, `bc`, `br`: Grid cells (top/center/bottom × left/center/right)
       - Each cell can have:
         - `text`: String
         - `assetFilename`: String (reference to asset in resources folder)

3. **Empty Page** (`type: "empty"`)
   - Properties:
     - `id`: UUID string
     - `title`: String
     - `type`: "empty"
     - `position`: Int

---

## Phase 1 Requirements: Cast List Support

### Data Models

#### 1.1 Create Sendable DTO Models (`Sources/SwiftCompartido/Sendable/`)

**CustomPage.swift** - Base protocol and enum:
```swift
public protocol CustomPage: Codable, Sendable {
    var id: String { get }
    var title: String { get }
    var position: Int { get }
}

public enum CustomPageType: String, Codable, Sendable {
    case castList
    case advanced
    case empty
    case unknown // For unsupported types
}

public struct CustomPageContainer: Codable, Sendable {
    public let type: CustomPageType
    public let data: Data // JSON-encoded page data

    // Convenience accessors
    public func asCastList() throws -> CastListPage?
    public func asRawJSON() throws -> [String: Any]
}
```

**CastListPage.swift**:
```swift
public struct CastListPage: CustomPage {
    public let id: String
    public var title: String
    public var position: Int
    public var printDots: Bool
    public var items: [CastMember]

    public struct CastMember: Codable, Sendable, Identifiable {
        public let id: String
        public var role: String
        public var name: String
        public var position: Int
    }
}
```

#### 1.2 Create SwiftData Models (`Sources/SwiftCompartido/SwiftDataModels/`)

**CustomPageModel.swift**:
```swift
@Model
public final class CustomPageModel {
    public var id: String
    public var title: String
    public var position: Int
    public var pageType: String // "castList", "advanced", "empty", etc.
    public var jsonData: Data // Raw JSON for the entire page

    @Relationship(deleteRule: .nullify)
    public var document: GuionDocumentModel?

    // Convenience
    public func toDTO() throws -> CustomPageContainer
    public static func from(_ page: CustomPageContainer) -> CustomPageModel
}
```

**Update GuionDocumentModel.swift**:
```swift
@Relationship(deleteRule: .cascade)
public var customPages: [CustomPageModel]

public var sortedCustomPages: [CustomPageModel] {
    customPages.sorted { $0.position < $1.position }
}
```

---

### Parsing & Serialization

#### 2.1 GuionParsedElementCollection Updates

**Update `GuionParsedElementCollection` (Sources/SwiftCompartido/Sendable/GuionParsedScreenplay.swift)**:
```swift
public final class GuionParsedElementCollection {
    // Existing properties...
    public let filename: String?
    public let elements: [GuionElement]
    public let titlePage: [[String: [String]]]
    public let suppressSceneNumbers: Bool

    // NEW:
    public var customPages: [CustomPageContainer]

    public init(
        filename: String? = nil,
        elements: [GuionElement] = [],
        titlePage: [[String: [String]]] = [],
        suppressSceneNumbers: Bool = false,
        customPages: [CustomPageContainer] = [] // NEW
    )
}
```

#### 2.2 Highland Format Support

**Update `GuionParsedScreenplay+Highland.swift`**:

**Reading:**
- After extracting TextBundle, look for `resources/custom-pages.json`
- Parse JSON into `[CustomPageContainer]`
- Pass to `GuionParsedElementCollection` initializer

**Writing:**
- Include `writeCustomPagesJSON(to:)` method
- Export `customPages` to `resources/custom-pages.json`
- Preserve unsupported page types by re-encoding their raw JSON

#### 2.3 Fountain Format Support

**Update `GuionParsedScreenplay.swift`** (file-based init):

**Reading:**
- When loading `.fountain` file at `/path/to/script.fountain`
- Check for `/path/to/custom-pages.json` in same directory
- If found, parse and attach to `GuionParsedElementCollection`

**Writing:**
- When writing `.fountain` file, write `custom-pages.json` to same directory
- If multiple `.fountain` files exist in directory, they share the same `custom-pages.json`

**Edge case:** How to handle multiple `.fountain` files?
- **Option A:** Merge all custom pages from all documents (union by ID)
- **Option B:** Last-write-wins (overwrite file)
- **Option C:** Only write if no existing `custom-pages.json`

#### 2.4 Markdown Format Support

**Update Markdown Parser (ProjectMarkdownParser.swift)**:

**Reading:**
- Extract YAML front matter
- Look for `customPages` key with array of page objects
- Parse into `[CustomPageContainer]`

**Writing:**
- Serialize `customPages` to YAML
- Include in front matter as:
```yaml
---
title: My Screenplay
author: Jane Doe
customPages:
  - type: castList
    id: "10D477F4-15F6-4521-A80C-E95EEEF0EC90"
    title: "Cast List"
    position: 2
    printDots: true
    items:
      - id: "B468DD9C-FC98-41AF-9F48-22F716253DF2"
        role: "BERNARD"
        name: "Jason Manino"
        position: 0
---
```

**Question:** Should we encode all custom pages in YAML, or only supported types?
- **Recommendation:** Encode all types to preserve round-trip fidelity

---

### SwiftData Conversion

#### 3.1 Update GuionDocumentParserSwiftData

**File:** `Sources/SwiftCompartido/Serialization/GuionDocumentParserSwiftData.swift`

**In `parse(script:in:)` method:**
```swift
// After creating GuionDocumentModel
for pageContainer in screenplay.customPages {
    let pageModel = CustomPageModel.from(pageContainer)
    document.customPages.append(pageModel)
}
```

**Create reverse method:**
```swift
public static func toGuionParsedElementCollection(
    from document: GuionDocumentModel
) throws -> GuionParsedElementCollection {
    // Existing element/title page conversion...

    let customPages = try document.sortedCustomPages.map { try $0.toDTO() }

    return GuionParsedElementCollection(
        filename: document.filename,
        elements: elements,
        titlePage: titlePage,
        suppressSceneNumbers: document.suppressSceneNumbers,
        customPages: customPages
    )
}
```

---

### UI Components (Optional for Phase 1)

#### 4.1 Cast List View

**File:** `Sources/SwiftCompartido/UI/CustomPages/CastListView.swift`

```swift
public struct CastListView: View {
    let castList: CastListPage
    @Binding var castList: CastListPage // For editing

    var body: some View {
        List {
            ForEach(castList.items) { member in
                HStack {
                    Text(member.role)
                        .bold()
                    if castList.printDots {
                        Text("..................")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(member.name)
                }
            }
        }
        .navigationTitle(castList.title)
    }
}
```

#### 4.2 Custom Pages List

**File:** `Sources/SwiftCompartido/UI/CustomPages/CustomPagesListView.swift`

```swift
public struct CustomPagesListView: View {
    @Bindable var document: GuionDocumentModel

    var body: some View {
        List {
            ForEach(document.sortedCustomPages) { page in
                NavigationLink {
                    customPageView(for: page)
                } label: {
                    Label(page.title, systemImage: iconForPageType(page.pageType))
                }
            }
        }
    }

    @ViewBuilder
    private func customPageView(for page: CustomPageModel) -> some View {
        switch page.pageType {
        case "castList":
            if let castList = try? page.toDTO().asCastList() {
                CastListView(castList: .constant(castList))
            }
        default:
            Text("Unsupported page type: \(page.pageType)")
        }
    }
}
```

---

### Testing Requirements

#### 5.1 Model Tests
- `CustomPageContainerTests.swift`: Encoding/decoding, type detection
- `CastListPageTests.swift`: Cast member management, sorting
- `CustomPageModelTests.swift`: SwiftData persistence, relationships

#### 5.2 Parser Tests
- `HighlandCustomPagesTests.swift`: Read/write Highland with custom pages
- `FountainCustomPagesTests.swift`: Read/write Fountain with sidecar JSON
- `MarkdownCustomPagesTests.swift`: YAML front matter encoding

#### 5.3 Integration Tests
- Round-trip fidelity (parse → export → parse should be identical)
- Multiple format conversions (Highland → Fountain → Markdown)
- Unsupported page type preservation

---

## Open Questions

### Critical Design Decisions ✅ RESOLVED

1. **Multiple Fountain files in same directory:** ✅ **DECISION: Option C - Document-specific files**
   - Documents can read shared `custom-pages.json` if present
   - Writes go to document-specific files: `script-custom-pages.json`
   - Format: `{basename}-custom-pages.json` (e.g., `episode1-custom-pages.json`)
   - Avoids conflicts, maintains per-document control

2. **Markdown YAML size limits:** ✅ **DECISION: Option B - Sidecar fallback**
   - Keep small custom pages in YAML front matter (threshold: 50 lines)
   - Fall back to sidecar `{basename}-custom-pages.json` for large lists
   - Document which strategy is used in metadata

3. **Unsupported page type handling:** ✅ **DECISION: Store raw JSON, preserve on export**
   - Store raw JSON in `CustomPageModel.jsonData`
   - UI shows: "Unsupported page type: advanced" (no JSON viewer in Phase 1)
   - Full round-trip preservation guaranteed

4. **Asset references in advanced pages:** ✅ **DECISION: Phase 1 simple storage**
   - Store filename as string in raw JSON
   - Preserve on Highland export (assets stay in `resources/` folder)
   - Phase 2: Copy assets to SwiftData storage area

5. **Position renumbering:** ✅ **DECISION: Option A - Preserve gaps**
   - Maintain original position values (matches Highland behavior)
   - Gaps are allowed (e.g., 0, 1, 4, 5)

6. **SwiftData migration:** ✅ **DECISION: Additive change, test backward compatibility**
   - New `customPages` relationship defaults to empty array
   - Add migration test to verify existing databases work

### Implementation Priorities ✅ RESOLVED

7. **Phase 1 scope:** ✅ **DECISION: Option A - Cast List only, no UI**
   - Implement `CastListPage` model with full read/write support
   - Other types (`advanced`, `empty`) preserved as opaque JSON
   - UI components deferred to Phase 2

8. **Backward compatibility:** ✅ **DECISION: Manual management only**
   - Old documents default to empty custom pages array
   - No auto-generation from characters (Phase 2 feature)

9. **Export formats:** ✅ **Deferred to Phase 2**
   - PDF export: Phase 2
   - Final Draft FDX: Phase 2

10. **Character sync:** ✅ **DECISION: Option A - Manual only**
    - Cast list is user-managed, independent of screenplay
    - No auto-sync in Phase 1
    - Phase 2: Consider auto-suggest feature

---

## Implementation Order (Recommended)

### Week 1: Data Models
1. Create Sendable DTOs (`CustomPage`, `CastListPage`, `CustomPageContainer`)
2. Create SwiftData model (`CustomPageModel`)
3. Update `GuionDocumentModel` with `customPages` relationship
4. Write comprehensive model tests

### Week 2: Highland Support
5. Update `GuionParsedScreenplay+Highland.swift` for reading
6. Update for writing with resource export
7. Add Highland integration tests

### Week 3: Fountain Support
8. Update Fountain file reader to check for sidecar JSON
9. Update Fountain writer to export sidecar JSON
10. Handle multiple-file edge cases
11. Add Fountain integration tests

### Week 4: Markdown Support
12. Update YAML front matter parser
13. Update markdown writer with custom pages serialization
14. Add Markdown integration tests

### Week 5: SwiftData Integration
15. Update `GuionDocumentParserSwiftData` for conversion
16. Add reverse conversion method
17. Test round-trip fidelity

### Week 6: UI (Optional)
18. Create `CastListView`
19. Create `CustomPagesListView`
20. Integrate into main document view

---

## Success Criteria

- ✅ Cast lists can be read from Highland files
- ✅ Cast lists can be written to Highland files
- ✅ Fountain files can have sidecar `custom-pages.json`
- ✅ Markdown files encode custom pages in YAML front matter
- ✅ Unsupported page types are preserved on export
- ✅ SwiftData persistence works correctly
- ✅ Round-trip conversion is lossless
- ✅ All tests pass with 90%+ coverage
- ✅ No breaking changes to existing API

---

## Future Enhancements (Out of Scope for Phase 1)

- Advanced page support with asset management
- Empty page support
- Custom page templates
- PDF rendering of custom pages
- Cast list auto-generation from screenplay characters
- Cast list editing UI with drag-and-drop reordering
