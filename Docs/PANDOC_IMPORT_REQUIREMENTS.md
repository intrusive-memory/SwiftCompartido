# Pandoc Document Import Requirements

## Overview

SwiftCompartido should support importing document files (DOCX, ODT, RTF) with **GitHub-style markdown rendering**, matching the existing markdown styling system. Documents will be converted to Markdown via bundled Pandoc, then parsed to extract structure and content, then rendered using the same visual components as Markdown files.


**Supported formats:**
- **DOCX** (.docx) - Microsoft Word 2007+
- **ODT** (.odt) - OpenDocument Text (LibreOffice, Google Docs)
- **RTF** (.rtf) - Rich Text Format (Universal compatibility)

## Design Goals

1. **Consistent Styling**: DOCX files should render identically to Markdown files
2. **Structure Preservation**: Maintain document hierarchy (headings, paragraphs, lists, etc.)
3. **Metadata Extraction**: Support document properties (title, author, creation date)
4. **Phase 6 Architecture**: Follow the existing DTO + SwiftData model pattern
5. **Automatic Detection**: Use file extension (`.docx`) for format detection

---

## Functional Requirements

### 1. File Format Support

**Priority**: P0 (Required)

- **Extension**: `.docx` (Office Open XML format)
- **Auto-detection**: Files with `.docx` extension automatically use DOCX parser
- **Compatibility**: Support DOCX files created by:
  - Microsoft Word (2007+)
  - Google Docs (exported as DOCX)
  - LibreOffice Writer
  - Apple Pages (exported as DOCX)

**Out of scope**:
- Legacy `.doc` format (binary, pre-2007)
- `.rtf` files (use separate RTF parser if needed)
- Password-protected DOCX files

---

### 2. Document Structure Parsing

**Priority**: P0 (Required)

#### 2.1 Headings

Map DOCX heading styles to section headings:

| DOCX Style | ElementType | Rendering |
|------------|-------------|-----------|
| Heading 1 | `.sectionHeading(level: 1)` | MarkdownSectionHeadingView (H1) |
| Heading 2 | `.sectionHeading(level: 2)` | MarkdownSectionHeadingView (H2) |
| Heading 3 | `.sectionHeading(level: 3)` | MarkdownSectionHeadingView (H3) |
| Heading 4 | `.sectionHeading(level: 4)` | MarkdownSectionHeadingView (H4) |
| Heading 5 | `.sectionHeading(level: 5)` | MarkdownSectionHeadingView (H5) |
| Heading 6 | `.sectionHeading(level: 6)` | MarkdownSectionHeadingView (H6) |

**Implementation notes**:
- Detect headings by style name (`Heading 1`, `Heading 2`, etc.)
- Fallback: If styled headings unavailable, detect by font size/weight
- Preserve heading hierarchy for outline generation

#### 2.2 Paragraphs

Map DOCX paragraphs to action elements:

| DOCX Element | ElementType | Rendering |
|--------------|-------------|-----------|
| Normal paragraph | `.action` | MarkdownActionView |
| Block quote | `.action` | MarkdownActionView (prefix with `>`) |
| Pre-formatted text | `.action` | MarkdownActionView (preserve formatting) |

**Text formatting support**:
- **Bold**: `<w:b/>` → `**text**` (rendered bold)
- **Italic**: `<w:i/>` → `*text*` (rendered italic)
- **Monospace/Code**: `Courier` or `Consolas` font → `` `code` `` (rendered as inline code)
- **Underline**: `<w:u/>` → Preserve as plain text (markdown doesn't support underline)
- **Strikethrough**: `<w:strike/>` → Ignore for now (future: `~~text~~`)

#### 2.3 Lists

**Priority**: P1 (High priority)

| DOCX Element | Conversion | Rendering |
|--------------|------------|-----------|
| Bulleted list | Convert to markdown `- item` | MarkdownActionView |
| Numbered list | Convert to markdown `1. item` | MarkdownActionView |
| Nested lists | Preserve indentation with spaces | MarkdownActionView |

**Example transformation**:
```
DOCX:
  • Introduction
  • Features
    1. Import DOCX
    2. Export Fountain

Converted to:
- Introduction
- Features
  1. Import DOCX
  2. Export Fountain
```

#### 2.4 Page Breaks

| DOCX Element | ElementType | Rendering |
|--------------|-------------|-----------|
| Hard page break (`<w:br w:type="page"/>`) | `.pageBreak` | PageBreakView |
| Section break | `.pageBreak` | PageBreakView |

#### 2.5 Comments and Revisions

**Priority**: P2 (Nice to have)

| DOCX Element | ElementType | Rendering |
|--------------|-------------|-----------|
| Word comment (`<w:comment>`) | `.comment` | CommentView |
| Track changes (deleted text) | `.boneyard` | BoneyardView |
| Track changes (inserted text) | Include in `.action` | MarkdownActionView |

---

### 3. Metadata Extraction

**Priority**: P0 (Required)

Extract DOCX core properties and map to Fountain title page format:

| DOCX Property | Title Page Key | Example |
|---------------|----------------|---------|
| `dc:title` | `title` | "My Screenplay" |
| `dc:creator` | `author` | "Jane Doe" |
| `cp:lastModifiedBy` | `edited by` | "John Smith" |
| `dcterms:created` | `date` | "2025-01-15" |
| `cp:revision` | `draft` | "First Draft" or "Revision 3" |
| `dc:subject` | `subject` | "Sci-Fi Thriller" |
| `dc:description` | `notes` | "A story about..." |

**Implementation**:
1. Parse `docProps/core.xml` from DOCX archive
2. Convert to Fountain title page format:
   ```swift
   [
       ["title": ["My Screenplay"]],
       ["author": ["Jane Doe"]],
       ["draft": ["First Draft"]],
       ["date": ["2025-01-15"]]
   ]
   ```
3. Store in `GuionParsedElementCollection.titlePage`
4. Automatically set `GuionDocumentModel.title` from metadata

---

### 4. Rendering System

**Priority**: P0 (Required)

#### 4.1 Format Detection

```swift
// In GuionElementRow.swift
private var isDocxDocument: Bool {
    guard let filename = element.document?.filename else { return false }
    return filename.lowercased().hasSuffix(".docx")
}
```

#### 4.2 View Routing

Use the same rendering logic as Markdown:

```swift
@ViewBuilder
private var elementView: some View {
    // Use GitHub-style markdown views for .docx files
    if isMarkdownDocument || isDocxDocument {
        switch element.elementType {
        case .action:
            MarkdownActionView(element: element)
        case .sectionHeading:
            MarkdownSectionHeadingView(element: element)
        default:
            standardElementView
        }
    } else {
        standardElementView
    }
}
```

#### 4.3 Spacing Rules

Apply the same spacing as Markdown:
- **After headings**: Controlled by `MarkdownSectionHeadingView` bottom padding (0.42em)
- **After paragraphs**: Full line spacing (`fontSize * 1.5`)
- **After page breaks**: Built-in dividers in PageBreakView

---

### 5. Parser Implementation

**Priority**: P0 (Required)

#### 5.1 Parser Class

```swift
/// Parser that converts Microsoft Word DOCX documents into GuionElement screenplay elements.
///
/// This parser extracts content from Office Open XML (.docx) format, converting
/// document structure into screenplay elements with GitHub-style markdown rendering.
///
public enum PandocDocumentParser {
    /// Parse a DOCX file into screenplay elements and metadata.
    ///
    /// - Parameter url: URL to the .docx file
    /// - Returns: Tuple containing:
    ///   - elements: Array of GuionElement objects
    ///   - titlePage: Array of dictionaries with document metadata
    /// - Throws: Error if the file cannot be read or parsed
    public static func parse(url: URL) throws -> (
        elements: [GuionElement],
        titlePage: [[String: [String]]]
    )

    /// Parse DOCX data into screenplay elements and metadata.
    ///
    /// - Parameter data: Raw DOCX file data
    /// - Returns: Tuple containing elements and title page metadata
    /// - Throws: Error if the data cannot be parsed
    public static func parse(data: Data) throws -> (
        elements: [GuionElement],
        titlePage: [[String: [String]]]
    )
}
```

#### 5.2 Parsing Strategy

1. **Unzip DOCX archive**: Extract `word/document.xml` and `docProps/core.xml`
2. **Parse core properties**: Extract metadata from `core.xml`
3. **Parse document structure**: Walk XML tree in `document.xml`
4. **Convert to GuionElements**: Map paragraphs, headings, lists to elements
5. **Preserve formatting**: Convert bold/italic/code runs to inline markdown
6. **Return results**: Elements array + title page metadata

**Dependencies**:
- **Pandoc** (optional, recommended): External converter for high-quality DOCX → Markdown
- **XMLParser** (Foundation): For manual parsing when Pandoc unavailable
- **ZipFoundation** or `NSFileWrapper` (Foundation): For DOCX extraction (ZIP format)

---

### 6. Integration with GuionParsedElementCollection

**Priority**: P0 (Required)

Add DOCX support to the auto-detection system:

```swift
// In GuionParsedElementCollection initializer
public init(file: String) async throws {
    let url = URL(fileURLWithPath: file)
    let filename = url.lastPathComponent
    let ext = url.pathExtension.lowercased()

    switch ext {
    case "md", "markdown":
        // Use MarkdownParser
        let (elements, titlePage) = try MarkdownParser.parse(markdown)
        self.elements = elements
        self.titlePage = titlePage

    case "docx", "odt", "rtf":
        // Use PandocDocumentParser
        let (elements, titlePage) = try PandocDocumentParser.parse(url: url)
        self.elements = elements
        self.titlePage = titlePage

    case "fountain":
        // Use FountainParser
        let parser = FountainParser(string: text)
        self.elements = parser.elements
        self.titlePage = parser.titlePage

    // ... other formats
    }
}
```

---

### 7. Development Methodology

**Priority**: P0 (Required)

#### 7.1 Test-Driven Development (TDD)

Follow SwiftCompartido's established TDD approach:

**Red-Green-Refactor Cycle:**
1. 🔴 **Write failing test** - Define expected behavior first
2. 🟢 **Make it pass** - Implement minimal code to pass test
3. 🔵 **Refactor** - Clean up code while keeping tests green

**Example TDD workflow:**
```swift
// Step 1: Write failing test
@Test("Parse simple DOCX with heading")
func testParseSimpleHeading() throws {
    let docxUrl = try Fijos.getFixture("simple", extension: "docx")
    let (elements, _) = try PandocDocumentParser.parse(url: docxUrl)

    #expect(elements.count == 2)
    #expect(elements[0].elementType == .sectionHeading(level: 1))
    #expect(elements[0].elementText == "Introduction")
}
// ❌ Test fails - PandocDocumentParser doesn't exist yet

// Step 2: Implement minimal code
public enum PandocDocumentParser {
    public static func parse(url: URL) throws -> (
        elements: [GuionElement],
        titlePage: [[String: [String]]]
    ) {
        // Minimal implementation to pass test
    }
}
// ✅ Test passes

// Step 3: Refactor and add edge cases
@Test("Parse DOCX with multiple heading levels")
func testParseMultipleHeadings() throws {
    // Add more test coverage
}
```

#### 7.2 Incremental Development Strategy

Build DOCX support in small, testable increments:

**Week 1: Foundation (Pandoc Integration)**
- Day 1: Bundle Pandoc binary, implement path detection
  - Test: Verify bundled Pandoc is found
  - Test: Verify system Pandoc fallback works
- Day 2: Implement DOCX → Markdown conversion
  - Test: Convert simple DOCX to markdown string
  - Test: Handle conversion errors gracefully
- Day 3: Integrate with MarkdownParser
  - Test: Parse converted markdown into GuionElements
  - Test: Verify element types match expected
- Day 4: Metadata extraction
  - Test: Extract title, author, date from DOCX
  - Test: Map to Fountain title page format
- Day 5: Error handling and edge cases
  - Test: Handle missing Pandoc
  - Test: Handle corrupted DOCX files
  - Test: Handle empty documents

**Week 2: Rendering Integration**
- Day 1: Format detection for .docx files
  - Test: Verify `.docx` extension triggers correct parser
  - Test: Verify rendering uses MarkdownActionView
- Day 2: GuionParsedElementCollection integration
  - Test: Import DOCX into GuionParsedElementCollection
  - Test: Verify automatic parser selection
- Day 3: SwiftData persistence
  - Test: Import DOCX into GuionDocumentModel
  - Test: Verify title from metadata
  - Test: Verify all elements persisted correctly
- Day 4-5: UI testing and polish
  - Test: Verify GitHub-style rendering
  - Test: Verify font scaling
  - Test: Verify spacing rules

**Daily Workflow:**
1. Start day with test suite passing (all 437+ tests green)
2. Write new tests for feature (TDD red phase)
3. Implement feature to pass tests (TDD green phase)
4. Run full test suite before committing
5. Commit only when all tests pass
6. Push to PR branch for CI/CD validation

#### 7.3 Testing Strategy

**Test Organization:**

```
Tests/SwiftCompartidoTests/
├── PandocDocumentParserTests.swift           # Unit tests for PandocDocumentParser
├── DocxPandocIntegrationTests.swift # Pandoc binary integration
├── PandocImportTests.swift           # SwiftData integration
├── PandocRenderingTests.swift        # UI rendering tests
└── DocxEdgeCasesTests.swift        # Error handling, edge cases
```

**Test Naming Convention:**

Use Swift Testing `@Test` macro with descriptive names:

```swift
// ✅ Good - Describes behavior and expected outcome
@Test("Parse DOCX with H1 heading creates sectionHeading element")
func testParseH1Heading() throws { }

@Test("Extract title from DOCX metadata maps to title page")
func testMetadataTitleExtraction() throws { }

// ❌ Bad - Vague, doesn't describe behavior
@Test("Test parsing")
func testParse() throws { }
```

**Test Categories:**

Tag tests for selective execution:

```swift
@Test("Parse DOCX with Pandoc", .tags(.pandoc, .integration))
func testPandocConversion() throws { }

@Test("Handle missing Pandoc gracefully", .tags(.errorHandling))
func testMissingPandoc() throws { }
```

#### 7.4 Unit Tests

**Suite**: `PandocDocumentParserTests.swift`
**Coverage Target**: 95%+ for PandocDocumentParser module
**Framework**: Swift Testing (`@Test` macro)

**Test Cases:**

```swift
// Pandoc Integration
@Test("Locate bundled Pandoc binary in app bundle")
func testBundledPandocDetection() throws

@Test("Fallback to system Pandoc when bundled unavailable")
func testSystemPandocFallback() throws

@Test("Throw error when no Pandoc available")
func testNoPandocError() throws

// DOCX → Markdown Conversion
@Test("Convert simple DOCX to markdown")
func testSimpleConversion() throws

@Test("Convert DOCX with headings preserves hierarchy")
func testHeadingConversion() throws

@Test("Convert DOCX with bold/italic/code preserves formatting")
func testFormattingConversion() throws

@Test("Convert DOCX with lists preserves structure")
func testListConversion() throws

@Test("Convert DOCX with tables to markdown tables")
func testTableConversion() throws

@Test("Convert DOCX with page breaks to === markers")
func testPageBreakConversion() throws

// Metadata Extraction
@Test("Extract title from DOCX core properties")
func testTitleExtraction() throws

@Test("Extract author from DOCX core properties")
func testAuthorExtraction() throws

@Test("Extract multiple authors as array")
func testMultipleAuthors() throws

@Test("Extract date from DOCX core properties")
func testDateExtraction() throws

@Test("Map DOCX metadata to Fountain title page format")
func testMetadataMapping() throws

@Test("Handle missing metadata gracefully")
func testMissingMetadata() throws

// Element Parsing
@Test("Parse H1 heading creates sectionHeading(level: 1)")
func testH1Parsing() throws

@Test("Parse H2-H6 headings create correct levels")
func testAllHeadingLevels() throws

@Test("Parse paragraph creates action element")
func testParagraphParsing() throws

@Test("Parse bold text preserves **markers**")
func testBoldParsing() throws

@Test("Parse italic text preserves *markers*")
func testItalicParsing() throws

@Test("Parse inline code preserves `backticks`")
func testCodeParsing() throws

@Test("Parse bulleted list converts to markdown")
func testBulletedList() throws

@Test("Parse numbered list converts to markdown")
func testNumberedList() throws

@Test("Parse nested lists preserves indentation")
func testNestedLists() throws

// Error Handling
@Test("Handle corrupted DOCX file throws appropriate error")
func testCorruptedFile() throws

@Test("Handle password-protected DOCX throws appropriate error")
func testPasswordProtectedFile() throws

@Test("Handle empty DOCX returns empty elements")
func testEmptyDocument() throws

@Test("Handle DOCX without metadata uses defaults")
func testNoMetadata() throws

// Edge Cases
@Test("Handle special characters in text")
func testSpecialCharacters() throws

@Test("Handle Unicode emoji and international characters")
func testUnicodeSupport() throws

@Test("Handle very long paragraphs (>10,000 characters)")
func testLongParagraphs() throws

@Test("Handle DOCX exported from Google Docs")
func testGoogleDocsExport() throws

@Test("Handle DOCX exported from Apple Pages")
func testPagesExport() throws

@Test("Handle DOCX exported from LibreOffice")
func testLibreOfficeExport() throws
```

**Total Unit Tests**: ~35-40 tests

#### 7.5 Integration Tests

**Suite**: `PandocImportTests.swift`
**Coverage Target**: All integration points tested
**Framework**: Swift Testing with SwiftData ModelContainer

**Test Cases:**

```swift
@Test("Import DOCX into GuionParsedElementCollection")
func testGuionParsedElementCollectionImport() async throws

@Test("Import DOCX into SwiftData via GuionDocumentParserSwiftData")
func testSwiftDataImport() async throws

@Test("Verify GuionDocumentModel.title from DOCX metadata")
func testDocumentTitleFromMetadata() async throws

@Test("Verify all elements persisted with correct ordering")
func testElementOrdering() async throws

@Test("Verify element relationships (document ↔ elements)")
func testElementRelationships() async throws

@Test("Import DOCX with mixed content (headings, paragraphs, lists)")
func testMixedContentImport() async throws

@Test("Import multiple DOCX files into same ModelContext")
func testMultipleDocuments() async throws

@Test("Re-import same DOCX creates new document (no duplicates)")
func testReImport() async throws

@Test("Import DOCX while other formats in database")
func testMultipleFormats() async throws
```

**Total Integration Tests**: ~10 tests

#### 7.6 UI Rendering Tests

**Suite**: `PandocRenderingTests.swift`
**Coverage Target**: All rendering paths validated
**Framework**: Swift Testing with SwiftUI ViewInspector

**Test Cases:**

```swift
@Test("DOCX headings render with MarkdownSectionHeadingView")
func testHeadingRendering() throws

@Test("DOCX paragraphs render with MarkdownActionView")
func testParagraphRendering() throws

@Test("DOCX bold text renders bold in MarkdownActionView")
func testBoldRendering() throws

@Test("DOCX italic text renders italic in MarkdownActionView")
func testItalicRendering() throws

@Test("DOCX inline code renders with monospace font")
func testCodeRendering() throws

@Test("DOCX page breaks render with PageBreakView")
func testPageBreakRendering() throws

@Test("Font scaling applies to DOCX documents")
func testFontScaling() throws

@Test("Full line spacing after DOCX headings")
func testHeadingSpacing() throws

@Test("Full line spacing after DOCX paragraphs")
func testParagraphSpacing() throws

@Test("DOCX documents detected by .docx, .odt, .rtf extensions")
func testFormatDetection() throws
```

**Total UI Tests**: ~10 tests

#### 7.7 Test Fixtures

**Location**: `Fixtures/` directory
**Format**: Real DOCX files from various sources

**Required Fixtures:**

```
Fixtures/
├── docx/
│   ├── simple.docx                 # Basic headings and paragraphs
│   ├── formatted.docx              # Bold, italic, code formatting
│   ├── lists.docx                  # Bulleted and numbered lists
│   ├── nested-lists.docx           # Complex nested list structures
│   ├── tables.docx                 # Simple tables (converted to markdown)
│   ├── metadata-full.docx          # All metadata fields populated
│   ├── metadata-minimal.docx       # Only title, no other metadata
│   ├── metadata-none.docx          # No metadata at all
│   ├── page-breaks.docx            # Multiple page breaks
│   ├── complex.docx                # Mix of all features
│   ├── google-docs-export.docx     # Exported from Google Docs
│   ├── pages-export.docx           # Exported from Apple Pages
│   ├── libreoffice-export.docx     # Exported from LibreOffice
│   ├── unicode.docx                # Emoji, Chinese, Arabic, etc.
│   ├── special-chars.docx          # Symbols, math, accents
│   ├── empty.docx                  # Empty document
│   ├── large.docx                  # 100+ pages for performance testing
│   └── corrupted.docx.invalid      # Corrupted file for error testing
```

**Fixture Creation:**
- Create fixtures manually in Word/Google Docs/Pages
- Document expected output in adjacent `.md` files
- Include expected element counts and types

**Example:**
```
Fixtures/docx/simple.docx           # The DOCX file
Fixtures/docx/simple.expected.md    # Expected markdown output
Fixtures/docx/simple.meta.json      # Expected metadata
```

#### 7.8 Mocking and Stubbing

**Challenge**: Tests should not require Pandoc installed
**Solution**: Mock Pandoc output for fast, reliable tests

**Approach 1: Pre-converted Markdown (Preferred)**

Store expected markdown output alongside fixtures:

```swift
@Test("Parse simple DOCX")
func testSimpleDocx() throws {
    let docxUrl = try Fijos.getFixture("simple", extension: "docx", subdirectory: "docx")

    // Instead of running Pandoc, use pre-converted markdown
    let expectedMarkdown = try Fijos.getFixture("simple.expected", extension: "md", subdirectory: "docx")
    let markdown = try String(contentsOf: expectedMarkdown)

    // Test MarkdownParser directly
    let (elements, titlePage) = try MarkdownParser.parse(markdown)

    // Verify expected structure
    #expect(elements.count == 2)
    #expect(elements[0].elementType == .sectionHeading(level: 1))
}
```

**Approach 2: Conditional Pandoc Tests**

Tag tests that require Pandoc, skip if unavailable:

```swift
@Test("Full DOCX conversion with Pandoc", .tags(.requiresPandoc))
func testFullConversion() throws {
    guard PandocDocumentParser.isPandocAvailable() else {
        throw XCTSkip("Pandoc not available")
    }

    // Run actual Pandoc conversion
    let (elements, _) = try PandocDocumentParser.parse(url: docxUrl)
    // ...
}
```

**CI/CD Strategy:**
- Short tests: Use pre-converted markdown (fast, no Pandoc)
- Long tests: Install Pandoc, run full conversion tests

#### 7.9 Performance Testing

**Suite**: `DocxPerformanceTests.swift`
**Coverage Target**: Meet performance requirements
**Framework**: Swift Testing with `.timeLimit`

**Test Cases:**

```swift
@Test("Import 10-page DOCX completes in < 500ms", .timeLimit(.milliseconds(500)))
func testSmallDocumentPerformance() async throws {
    let start = Date()
    let docxUrl = try Fijos.getFixture("10-pages", extension: "docx")
    _ = try await PandocDocumentParser.parse(url: docxUrl)
    let duration = Date().timeIntervalSince(start)
    #expect(duration < 0.5)
}

@Test("Import 100-page DOCX completes in < 2s", .timeLimit(.seconds(2)))
func testLargeDocumentPerformance() async throws {
    let docxUrl = try Fijos.getFixture("100-pages", extension: "docx")
    _ = try await PandocDocumentParser.parse(url: docxUrl)
}

@Test("Memory usage for 100-page DOCX under 50MB")
func testMemoryUsage() throws {
    // Measure memory before and after
    let before = getMemoryUsage()
    _ = try PandocDocumentParser.parse(url: largeDocxUrl)
    let after = getMemoryUsage()

    let memoryUsed = after - before
    #expect(memoryUsed < 50_000_000) // 50 MB
}
```

#### 7.10 Regression Testing

**Strategy**: Ensure DOCX import doesn't break existing functionality

**Pre-merge Checklist:**
1. ✅ All 437 existing tests pass
2. ✅ All new DOCX tests pass (~55 new tests)
3. ✅ No changes to existing parsers (Fountain, Markdown, FDX, PDF)
4. ✅ No changes to SwiftData schema
5. ✅ No changes to UI rendering for existing formats
6. ✅ Code coverage ≥ 90%

**Automated Regression Suite:**
```bash
# Run all tests including new DOCX tests
./build.sh --action test

# Expected: 527 tests passing (437 existing + 90 new)
```

#### 7.11 Continuous Integration

**GitHub Actions Integration:**

Update `.github/workflows/tests.yml`:

```yaml
- name: Install Pandoc for DOCX tests
  run: |
    brew install pandoc
    pandoc --version

- name: Run Short Tests (including DOCX)
  run: |
    ./build.sh --action test
  timeout-minutes: 10

- name: Verify DOCX fixtures
  run: |
    ls -la Fixtures/docx/
    echo "DOCX fixture count: $(ls Fixtures/docx/*.docx | wc -l)"
```

**Test Execution Strategy:**

- **Short tests** (PR validation): Include fast DOCX tests with pre-converted markdown
- **Long tests** (weekend schedule): Include full Pandoc conversion tests
- **Performance tests**: Run separately on dedicated hardware

#### 7.12 Quality Gates

**Pre-commit:**
- ✅ All tests pass locally
- ✅ No compiler warnings
- ✅ Code formatted (SwiftFormat)

**Pre-PR:**
- ✅ Feature complete per requirements
- ✅ All tests pass (492+ total)
- ✅ Test coverage ≥ 90%
- ✅ Documentation updated

**Pre-merge:**
- ✅ CI/CD tests pass on GitHub
- ✅ Code review approved
- ✅ No regressions in existing functionality
- ✅ CHANGELOG updated

#### 7.13 Test Coverage Metrics

**Minimum Requirements:**

| Module | Coverage Target |
|--------|----------------|
| PandocDocumentParser | 95%+ |
| Integration (GuionParsedElementCollection) | 90%+ |
| UI Rendering (format detection) | 90%+ |
| Error handling | 100% |
| Overall project | 90%+ |

**Measure Coverage:**

```bash
# Run tests with coverage
xcodebuild test \
  -scheme SwiftCompartido \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -enableCodeCoverage YES \
  CODE_SIGNING_ALLOWED=NO

# View coverage report
open DerivedData/.../CodeCoverage/SwiftCompartido/index.html
```

**Coverage Uploaded to Codecov:**
- Separate flags for `docx-parser`, `docx-integration`, `docx-ui`
- Track coverage trends over time
- Fail PR if coverage drops below 90%

#### 7.14 Test Maintenance

**Regular Reviews:**
- Weekly: Review failing/flaky tests
- Monthly: Update fixtures with new edge cases
- Quarterly: Review test coverage gaps

**Test Documentation:**
- Each test suite has header comment explaining purpose
- Complex tests include inline comments
- Edge cases documented in test names

**Example:**
```swift
/// Tests for PandocDocumentParser Pandoc integration
///
/// These tests verify that the bundled Pandoc binary is correctly
/// detected and used to convert DOCX files to Markdown.
///
/// Test fixtures: Fixtures/docx/
/// Pre-converted markdown: Fixtures/docx/*.expected.md
@Suite("PandocDocumentParser - Pandoc Integration")
struct DocxPandocIntegrationTests {

    @Test("Bundled Pandoc binary is found in app bundle")
    func testBundledPandocDetection() throws {
        // Test implementation
    }
}
```

---

### 8. Testing Requirements Summary

**Total New Tests**: ~90 tests
- Unit tests: 35-40
- Integration tests: 10
- UI tests: 10
- Performance tests: 5

**Test Execution Time**:
- Short tests: ~2-3 minutes (with pre-converted markdown)
- Long tests: ~5-7 minutes (with Pandoc conversion)

**Coverage Target**: 90%+ overall, 95%+ for PandocDocumentParser module

**Quality Assurance**:
- TDD approach (write tests first)
- Daily test runs during development
- CI/CD validation on every PR
- Code review required before merge
- Regression testing with all 437 existing tests

---

### 8. Error Handling

**Priority**: P0 (Required)

#### 8.1 Error Types

```swift
public enum PandocDocumentParserError: LocalizedError {
    case invalidZipArchive
    case missingDocumentXml
    case invalidXmlStructure
    case unsupportedDocxVersion
    case corruptedFile
    case passwordProtected

    public var errorDescription: String? {
        switch self {
        case .invalidZipArchive:
            return "Not a valid DOCX file (invalid ZIP archive)"
        case .missingDocumentXml:
            return "Missing required document.xml in DOCX archive"
        case .invalidXmlStructure:
            return "Invalid XML structure in DOCX document"
        case .unsupportedDocxVersion:
            return "Unsupported DOCX version (requires Office 2007 or later)"
        case .corruptedFile:
            return "File appears to be corrupted"
        case .passwordProtected:
            return "Password-protected DOCX files are not supported"
        }
    }
}
```

#### 8.2 Graceful Degradation

- **Missing metadata**: Default to filename for title, empty arrays for other fields
- **Unrecognized styles**: Treat as normal paragraphs (`.action`)
- **Malformed formatting**: Include text without formatting
- **Missing runs**: Skip empty paragraphs

---

### 9. Performance Requirements

**Priority**: P1 (High priority)

- **Import time**: < 2 seconds for documents up to 100 pages
- **Memory usage**: < 50MB for typical documents
- **Background processing**: Parse on background thread (not main)
- **Progress reporting**: Support `FountainParserProgress` callbacks
- **Streaming**: For large files (>1000 paragraphs), parse incrementally

---

### 10. Accessibility Requirements

**Priority**: P1 (High priority)

- **VoiceOver**: Headings properly announced with level
- **Dynamic Type**: All text scales with system font size
- **Text selection**: All content selectable (`.textSelection(.enabled)`)
- **Keyboard navigation**: Full keyboard support in rendered view

---

### 11. Documentation Requirements

**Priority**: P0 (Required)

#### 11.1 User Documentation

Create `Docs/PANDOC_IMPORT.md`:
- Overview of DOCX support
- Supported features and limitations
- Metadata mapping reference
- Troubleshooting guide
- Examples

#### 11.2 API Documentation

Add DocStrings to all public APIs:
- `PandocDocumentParser.parse(url:)`
- `PandocDocumentParser.parse(data:)`
- Error types
- Example usage

#### 11.3 Update Existing Docs

- **README.md**: Add DOCX to supported formats list
- **CLAUDE.md**: Add DOCX parsing flow to architecture guide
- **AI-REFERENCE.md**: Add PandocDocumentParser API reference
- **CHANGELOG.md**: Document DOCX import feature

---

### 12. Migration and Backward Compatibility

**Priority**: P0 (Required)

- **No breaking changes**: Existing Markdown/Fountain parsing unaffected
- **SwiftData schema**: No changes required (same GuionElementModel)
- **File extension check**: Add `.docx` to `isMarkdownDocument` OR create separate `isDocxDocument`
- **Version bump**: Increment to 5.0.0 (new major feature)

---

## Implementation Phases

### Phase 1: Core Parser (Week 1)
- [ ] PandocDocumentParser class with basic XML parsing
- [ ] Heading extraction (H1-H6)
- [ ] Paragraph extraction (plain text only)
- [ ] Metadata extraction
- [ ] Unit tests for parser

### Phase 2: Text Formatting (Week 2)
- [ ] Bold/italic/code detection
- [ ] Inline markdown conversion
- [ ] Text run aggregation
- [ ] Tests for formatting

### Phase 3: Lists and Structure (Week 3)
- [ ] Bulleted list parsing
- [ ] Numbered list parsing
- [ ] Nested list support
- [ ] Page break detection
- [ ] Tests for lists

### Phase 4: Rendering Integration (Week 4)
- [ ] Add DOCX to format detection
- [ ] Route to MarkdownActionView/MarkdownSectionHeadingView
- [ ] Update GuionParsedElementCollection
- [ ] UI rendering tests

### Phase 5: Documentation and Polish (Week 5)
- [ ] Write PANDOC_IMPORT.md
- [ ] Update all related docs
- [ ] Create test fixtures
- [ ] Performance optimization
- [ ] Code review and cleanup

---

## Success Criteria

✅ **Functional**:
- [ ] DOCX files import successfully
- [ ] Document structure preserved (headings, paragraphs, lists)
- [ ] Metadata extracted and stored in title page
- [ ] Bold, italic, code formatting rendered correctly
- [ ] Page breaks display correctly

✅ **Quality**:
- [ ] 90%+ test coverage
- [ ] All 437+ tests passing (existing + new DOCX tests)
- [ ] No regressions in Markdown/Fountain parsing
- [ ] Documentation complete and accurate

✅ **Performance**:
- [ ] Import completes in < 2 seconds for 100-page documents
- [ ] Memory usage < 50MB for typical documents
- [ ] Background thread processing (no main thread blocking)

✅ **User Experience**:
- [ ] DOCX files render identically to Markdown files
- [ ] Font scaling works (+ and - buttons)
- [ ] VoiceOver support functional
- [ ] Text selection enabled

---

## Out of Scope (Future Enhancements)

The following features are **not** required for initial DOCX import:

- ❌ Tables (map to code blocks or ignore)
- ❌ Images (skip, or store as file references)
- ❌ Hyperlinks (display as plain text)
- ❌ Footnotes and endnotes (skip or append to document)
- ❌ Headers and footers (skip)
- ❌ Equations (MathML) (skip)
- ❌ Charts and diagrams (skip)
- ❌ Embedded objects (skip)
- ❌ Text boxes (flatten to paragraphs)
- ❌ Columns (flatten to single column)
- ❌ Bidirectional text (RTL languages)
- ❌ Custom XML parts
- ❌ Macros and VBA code
- ❌ Digital signatures
- ❌ Export to DOCX (import only)

These can be added in future versions based on user feedback.

---

## References

- **Office Open XML Standard**: [ISO/IEC 29500](http://www.ecma-international.org/publications/standards/Ecma-376.htm)
- **DOCX Structure Guide**: [Microsoft Docs](https://docs.microsoft.com/en-us/office/open-xml/working-with-wordprocessingml-documents)
- **swift-markdown**: Apple's markdown parsing library (for reference)
- **Existing Implementation**: `MarkdownParser.swift`, `MarkdownActionView.swift`, `MarkdownSectionHeadingView.swift`

---

## Parser Strategy: Hybrid Approach

### Research Findings

After researching available Swift libraries for DOCX parsing (January 2025):
- ❌ **No mature Swift-native DOCX parsers** exist
- ❌ **DocX library** (shinjukunian/DocX): Only writes DOCX, doesn't parse
- ❌ **Cloud APIs** (Aspose): Require internet, API keys, privacy concerns
- ✅ **Pandoc**: Industry-standard converter, extremely reliable

### Recommended Approach: Bundled Pandoc Binary

**For Low-Knowledge Users: Bundle Pandoc for Turnkey Experience**

Since SwiftCompartido targets low-knowledge users who need a "just works" experience, the library should **bundle the Pandoc binary** directly in the app. This eliminates installation requirements and provides consistent behavior for all users.

**Primary: Bundled Pandoc Converter**

Include Pandoc binary in app bundle for professional-grade conversion:

```swift
public enum PandocDocumentParser {
    /// Parse DOCX using available parser (Pandoc preferred, fallback to manual)
    public static func parse(url: URL) throws -> (
        elements: [GuionElement],
        titlePage: [[String: [String]]]
    ) {
        // 1. Check if Pandoc is available
        if isPandocAvailable() {
            return try parseWithPandoc(url: url)
        }

        // 2. Fallback to manual parser
        return try parseManually(url: url)
    }

    private static func parseWithPandoc(url: URL) throws -> (...) {
        // Convert DOCX → Markdown using Pandoc
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/pandoc")
        process.arguments = [
            "-f", "docx",
            "-t", "markdown",
            "--extract-media=.",  // Extract images
            "--standalone",        // Include metadata
            url.path
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let markdown = String(data: data, encoding: .utf8)!

        // Parse the resulting markdown using MarkdownParser
        return try MarkdownParser.parse(markdown)
    }
}
```

**Benefits of Bundling**:
- ✅ **Turnkey experience** - No user installation required
- ✅ **Consistent behavior** - All users get same features
- ✅ **Professional-grade conversion** - Handles complex DOCX automatically
- ✅ **No support burden** - Eliminates "how do I install Pandoc?" questions
- ✅ **Preserves formatting** - Tables, lists, metadata, structure
- ✅ **No API keys or internet required** - Fully offline
- ✅ **Guaranteed version** - You control which Pandoc version ships

**Trade-offs**:
- ⚠️ **App size**: +60 MB (acceptable for turnkey experience)
- ⚠️ **GPL-2 license**: Must include Pandoc's license (simple attribution)

### How to Bundle Pandoc

**1. Download Pandoc Binary**

Get the universal binary from [Pandoc Releases](https://github.com/jgm/pandoc/releases):
- Download `pandoc-3.x-macOS.zip` (includes ARM64 + Intel)
- Extract `pandoc` binary
- Optionally compile with `-fembed_data_files` for fully self-contained binary

**2. Add to Xcode Project**

```
SwiftCompartido/
├── Resources/
│   ├── Binaries/
│   │   └── pandoc              # Universal binary
│   └── Licenses/
│       └── pandoc-LICENSE.txt  # GPL-2 license
```

Add to target's "Copy Bundle Resources" build phase.

**3. Update Bundle Lookup**

```swift
private static func getPandocPath() -> URL? {
    // Always use bundled version first
    if let bundled = Bundle.main.url(forResource: "pandoc", withExtension: nil, subdirectory: "Binaries") {
        return bundled
    }

    // Fallback to system installation (for development)
    let systemPaths = [
        "/usr/local/bin/pandoc",
        "/opt/homebrew/bin/pandoc"
    ]

    for path in systemPaths {
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
    }

    return nil
}
```

**4. License Attribution**

Add to app's About screen or Acknowledgments:

```
This application includes Pandoc, a universal document converter.
Pandoc is licensed under GPL-2.
Source code: https://github.com/jgm/pandoc
```

### Implementation Strategy

**Phase 1: Bundle Pandoc Binary**
- Download Pandoc universal binary
- Add to Xcode project resources
- Implement bundle lookup
- Add GPL-2 license attribution

**Phase 2: Implement Converter**
- Shell out to bundled Pandoc
- Convert DOCX → Markdown
- Parse with existing MarkdownParser
- Handle errors gracefully

**Phase 3: Testing & Polish**
- Test with various DOCX files (Word, Google Docs, Pages)
- Verify universal binary works on Intel + ARM64
- Add integration tests
- Document DOCX import feature

### Complete Implementation Example

```swift
public enum PandocDocumentParser {
    /// Parse DOCX using bundled Pandoc converter
    public static func parse(url: URL) throws -> (
        elements: [GuionElement],
        titlePage: [[String: [String]]]
    ) {
        guard let pandocPath = getPandocPath() else {
            throw PandocDocumentParserError.pandocNotAvailable
        }

        // Convert DOCX → Markdown using bundled Pandoc
        let markdown = try convertToMarkdown(docxUrl: url, pandocPath: pandocPath)

        // Parse markdown using existing MarkdownParser
        return try MarkdownParser.parse(markdown)
    }

    private static func convertToMarkdown(docxUrl: URL, pandocPath: URL) throws -> String {
        let process = Process()
        process.executableURL = pandocPath
        process.arguments = [
            "-f", "docx",
            "-t", "markdown",
            "--standalone",        // Include metadata
            "--wrap=preserve",     // Don't wrap long lines
            docxUrl.path
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PandocDocumentParserError.conversionFailed(errorMessage)
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw PandocDocumentParserError.invalidEncoding
        }

        return markdown
    }

    private static func getPandocPath() -> URL? {
        // 1. Check for bundled Pandoc (production)
        if let bundled = Bundle.main.url(
            forResource: "pandoc",
            withExtension: nil,
            subdirectory: "Binaries"
        ) {
            return bundled
        }

        // 2. Fallback to system Pandoc (development)
        let systemPaths = [
            "/usr/local/bin/pandoc",
            "/opt/homebrew/bin/pandoc"
        ]

        for path in systemPaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        return nil
    }
}

public enum PandocDocumentParserError: LocalizedError {
    case pandocNotAvailable
    case conversionFailed(String)
    case invalidEncoding

    public var errorDescription: String? {
        switch self {
        case .pandocNotAvailable:
            return "DOCX converter not available. Please reinstall the application."
        case .conversionFailed(let message):
            return "Failed to convert DOCX: \(message)"
        case .invalidEncoding:
            return "Invalid text encoding in converted document"
        }
    }
}
```

### Why This Matches SwiftCompartido Philosophy

This hybrid approach aligns with the project's existing patterns:

1. **Custom Parsers**: You built FountainParser, MarkdownParser, FDXParser, PDFParser
2. **No Cloud Dependencies**: All parsing happens locally
3. **Pragmatic**: Use best tool (Pandoc) when available, fallback otherwise
4. **User Control**: No API keys, no internet, no privacy concerns
5. **Graceful Degradation**: Works with limited features if Pandoc unavailable

### Alternative Considered: System Pandoc with Manual Fallback

**Why not rely on system-installed Pandoc?**

This was the initial approach, but it's **unsuitable for low-knowledge users**:

**Problems**:
- ❌ Most users won't have Pandoc installed
- ❌ Users won't know how to install via Homebrew
- ❌ Creates confusing two-tier experience (some users get full features, others don't)
- ❌ Support nightmare: "Why doesn't my DOCX import work?"
- ❌ Manual fallback parser provides degraded experience

**Bundled binary solves all these issues** with minimal trade-offs (60 MB).

### Alternative Considered: Pure Swift Manual Parser

**Why not build 100% custom like other parsers?**

DOCX is significantly more complex than Fountain/Markdown:
- 300+ page specification (Office Open XML)
- Nested XML with complex relationships
- Styles, themes, numbering definitions
- Tables, images, equations, charts
- Would require 2-3 months of development

**Bundled Pandoc solution**: 1 week of development for professional-grade quality

---

## Updated Questions for Discussion

1. ✅ **Dependency**: Bundle Pandoc binary in app (turnkey experience for low-knowledge users)
2. ✅ **Tables**: Converted to markdown tables automatically (Pandoc handles this)
3. **Images**: Extract to temp directory, store paths (Phase 6 TypedDataStorage)
4. ✅ **Performance**: 2-second limit for 100 pages (Pandoc easily meets this)
5. ✅ **Export**: Import-only for v1, defer export to v2
6. ✅ **Pandoc Installation**: Bundle universal binary (~60 MB), include GPL-2 attribution
7. **App Store**: Verify bundled GPL-2 binary is acceptable for macOS App Store distribution

---

**Last Updated**: 2025-01-15
**Version**: 1.0 (Draft)
**Author**: Requirements Document for SwiftCompartido DOCX Import
