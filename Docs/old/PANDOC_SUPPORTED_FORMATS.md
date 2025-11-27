# Pandoc-Supported Formats in SwiftCompartido

## Overview

Since SwiftCompartido bundles Pandoc for DOCX import, we get **47 additional input formats for free** with zero extra development or file size cost. This document lists formats that can be supported with minimal code changes.

## Format Categories

### 📝 Word Processor Formats (High Value)

| Format | Extension | Source | User Value | Priority |
|--------|-----------|--------|------------|----------|
| **DOCX** | `.docx` | Microsoft Word | ✅ PRIMARY | P0 (In Progress) |
| **ODT** | `.odt` | LibreOffice, Google Docs | High - Free Word alternative | P0 |
| **RTF** | `.rtf` | Universal (Word, TextEdit, etc.) | High - Universal format | P0 |

**Why these matter:**
- **ODT**: Users with LibreOffice (free alternative to Word)
- **RTF**: Universal format, works everywhere (even TextEdit on Mac)
- Users switching from free tools to SwiftCompartido

### 📚 E-book Formats (Medium-High Value)

| Format | Extension | Source | User Value | Priority |
|--------|-----------|--------|------------|----------|
| **EPUB** | `.epub` | E-books (Kindle, Apple Books, etc.) | Medium - Writers may have novels/scripts | P1 |
| **FB2** | `.fb2` | FictionBook (popular in Russia) | Low - Niche audience | P2 |

**Why these matter:**
- Writers may have novels or scripts stored as EPUBs
- Easy to import published works for reference

### 🌐 Web/HTML Formats (Medium Value)

| Format | Extension | Source | User Value | Priority |
|--------|-----------|--------|------------|----------|
| **HTML** | `.html`, `.htm` | Web pages, blogs | Medium - Copy from web sources | P1 |
| **MediaWiki** | `.wiki` | Wikipedia, wikis | Low - Technical users | P2 |

**Why these matter:**
- Users copying content from websites/blogs
- Reference materials from online sources

### 🔬 Technical/Programming Formats (Low-Medium Value)

| Format | Extension | Source | User Value | Priority |
|--------|-----------|--------|------------|----------|
| **IPYNB** | `.ipynb` | Jupyter Notebooks | Medium - Technical writers | P1 |
| **reStructuredText** | `.rst` | Python documentation | Low - Very technical | P2 |
| **Org-mode** | `.org` | Emacs Org-mode | Low - Emacs users only | P3 |
| **LaTeX** | `.tex` | Academic papers | Low - Academic users | P2 |
| **Typst** | `.typ` | Modern LaTeX alternative | Low - Emerging format | P3 |

**Why IPYNB matters:**
- Jupyter notebooks can contain narrative text
- Technical writers may use notebooks for documentation
- Could be screenplay notes with code examples

### 📖 Wiki Markup (Low Value)

| Format | Extension | Notes | Priority |
|--------|-----------|-------|----------|
| MediaWiki | `.wiki` | Wikipedia | P2 |
| DokuWiki | `.txt` | DokuWiki | P3 |
| TikiWiki | `.txt` | TikiWiki | P3 |
| TWiki | `.txt` | TWiki | P3 |
| Vimwiki | `.wiki` | Vim wiki | P3 |
| Jira | `.jira` | Jira wiki | P3 |
| Creole | `.creole` | Generic wiki | P3 |

**Why low priority:**
- Niche technical audiences
- Low-knowledge users unlikely to have these

### 📋 Other Document Formats

| Format | Extension | Source | User Value | Priority |
|--------|-----------|--------|------------|----------|
| **CSV** | `.csv` | Spreadsheets | Very Low - Not narrative | P3 |
| **TSV** | `.tsv` | Tab-separated | Very Low - Not narrative | P3 |
| **OPML** | `.opml` | Outlines | Low - Outliner apps | P2 |
| **Textile** | `.textile` | Textile markup | Very Low - Obsolete | P3 |
| **txt2tags** | `.t2t` | txt2tags | Very Low - Obscure | P3 |

---

## Recommended Implementation Plan

### Phase 1: Core Word Processor Formats (Week 3)

**Add to DOCX implementation (minimal code):**

```swift
public enum DocxParser {
    /// Parse document using bundled Pandoc converter
    /// Supports: DOCX, ODT, RTF
    public static func parse(url: URL) throws -> (
        elements: [GuionElement],
        titlePage: [[String: [String]]]
    ) {
        let ext = url.pathExtension.lowercased()

        let inputFormat: String
        switch ext {
        case "docx":
            inputFormat = "docx"
        case "odt":
            inputFormat = "odt"
        case "rtf":
            inputFormat = "rtf"
        default:
            throw DocxParserError.unsupportedFormat(ext)
        }

        // Convert to markdown using Pandoc
        let markdown = try convertToMarkdown(
            documentUrl: url,
            inputFormat: inputFormat,
            pandocPath: getPandocPath()
        )

        // Parse markdown using existing MarkdownParser
        return try MarkdownParser.parse(markdown)
    }
}
```

**Files to update:**
- Rename `DocxParser` → `PandocDocumentParser` (more generic)
- Add `.odt` and `.rtf` to format detection
- Update GuionParsedElementCollection to handle new extensions

**Testing:**
- Create ODT fixtures (LibreOffice)
- Create RTF fixtures (TextEdit, Word)
- Verify metadata extraction works
- ~15 new tests (5 per format)

**Effort**: 1-2 days

### Phase 2: EPUB Support (Week 4)

**Why EPUB is valuable:**
- Writers may have novels/scripts in EPUB format
- EPUB is essentially HTML + metadata (Pandoc handles well)
- Popular for self-published authors

**Implementation:**
```swift
case "epub":
    inputFormat = "epub"
```

**Special considerations:**
- EPUB may contain images (extract to temp directory)
- EPUB has chapters (map to section headings)
- EPUB metadata (Dublin Core) → Fountain title page

**Testing:**
- Create EPUB fixtures (Calibre, Apple Books)
- Test chapter structure preservation
- Test image handling (skip or store)
- ~10 new tests

**Effort**: 2-3 days

### Phase 3: HTML Support (Optional)

**Use case:**
- Copy screenplay from website/blog
- Import reference materials
- Convert web research to documents

**Implementation:**
```swift
case "html", "htm":
    inputFormat = "html"
```

**Special considerations:**
- HTML may have navigation, ads, etc. (Pandoc strips this)
- May need `--strip-comments` flag
- Images in HTML (skip or download)

**Testing:**
- Create HTML fixtures (simple web pages)
- Test stripping of navigation/ads
- ~5 new tests

**Effort**: 1 day

### Phase 4: Jupyter Notebooks (Optional, Technical)

**Use case:**
- Technical writers using notebooks for documentation
- Computational narratives (data + story)

**Implementation:**
```swift
case "ipynb":
    inputFormat = "ipynb"
```

**Special considerations:**
- Notebooks have code cells (could render as code blocks)
- May have output cells (skip or include?)
- Metadata extraction

**Testing:**
- Create notebook fixtures
- Test code cell rendering
- ~5 new tests

**Effort**: 1-2 days

---

## Implementation Strategy

### Rename DocxParser → PandocDocumentParser

To support multiple formats, rename the parser:

**Before:**
```swift
public enum DocxParser {
    public static func parse(url: URL) throws -> (...)
}
```

**After:**
```swift
/// Universal document parser using bundled Pandoc
///
/// Supports: DOCX, ODT, RTF, EPUB, HTML, IPYNB
public enum PandocDocumentParser {
    public static func parse(url: URL) throws -> (...)

    /// Supported input formats
    public static let supportedExtensions = [
        "docx", "odt", "rtf", "epub", "html", "htm", "ipynb"
    ]
}
```

### Update GuionParsedElementCollection

**Auto-detection for all Pandoc formats:**

```swift
public init(file: String) async throws {
    let url = URL(fileURLWithPath: file)
    let ext = url.pathExtension.lowercased()

    switch ext {
    case "md", "markdown":
        // Use MarkdownParser
        let (elements, titlePage) = try MarkdownParser.parse(markdown)

    case "docx", "odt", "rtf", "epub", "html", "htm", "ipynb":
        // Use PandocDocumentParser
        let (elements, titlePage) = try PandocDocumentParser.parse(url: url)

    case "fountain":
        // Use FountainParser

    case "fdx":
        // Use FDXParser

    case "pdf":
        // Use PDFScreenplayParser

    default:
        throw ParserError.unsupportedFormat(ext)
    }
}
```

### Update Format Detection in UI

**GuionElementRow.swift:**

```swift
private var isPandocDocument: Bool {
    guard let filename = element.document?.filename else { return false }
    let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
    return PandocDocumentParser.supportedExtensions.contains(ext)
}

@ViewBuilder
private var elementView: some View {
    // Use GitHub-style markdown views for Pandoc-converted formats
    if isMarkdownDocument || isPandocDocument {
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

---

## Cost-Benefit Analysis

### Immediate Value (Add Now)

**ODT + RTF support:**
- ✅ **Development**: 1-2 days
- ✅ **File size**: 0 MB (Pandoc already bundled)
- ✅ **User value**: HIGH (LibreOffice users, universal compatibility)
- ✅ **Testing**: ~15 tests (manageable)
- ✅ **Maintenance**: Minimal (same code path as DOCX)

**Recommendation**: **Add ODT and RTF in same PR as DOCX** (Week 3)

### Near-Term Value (Add Soon)

**EPUB support:**
- ✅ **Development**: 2-3 days
- ✅ **File size**: 0 MB
- ✅ **User value**: MEDIUM (writers with ebook libraries)
- ✅ **Testing**: ~10 tests
- ⚠️ **Maintenance**: Moderate (image handling, chapter structure)

**Recommendation**: **Add in v5.1** (1 month after DOCX release)

### Optional Value (Add Later)

**HTML, IPYNB:**
- ✅ **Development**: 1 day each
- ✅ **File size**: 0 MB
- ⚠️ **User value**: LOW-MEDIUM (niche users)
- ✅ **Testing**: ~5 tests each
- ⚠️ **Maintenance**: Moderate

**Recommendation**: **Add in v5.2+** (if users request it)

---

## Documentation Updates

### README.md

**Before:**
```markdown
## Supported Formats

- Fountain (.fountain)
- Final Draft (.fdx)
- PDF (.pdf) - iOS 26.0+
- Markdown (.md, .markdown)
- Highland (.highland)
- TextBundle (.textbundle)
```

**After:**
```markdown
## Supported Formats

### Screenplay Formats
- Fountain (.fountain) - Industry standard
- Final Draft (.fdx) - Professional software
- Highland (.highland) - Highland 2 bundles
- TextBundle (.textbundle) - Markdown bundles

### Document Formats (via Pandoc)
- Microsoft Word (.docx)
- OpenDocument Text (.odt) - LibreOffice, Google Docs
- Rich Text Format (.rtf) - Universal compatibility
- EPUB (.epub) - E-books
- Markdown (.md, .markdown) - Plain text with formatting

### Advanced Formats
- PDF (.pdf) - AI-powered extraction (iOS 26.0+)
- HTML (.html, .htm) - Web pages
- Jupyter Notebooks (.ipynb) - Technical documentation
```

### User-Facing Benefits

**Marketing message:**
> "Import from anywhere: Word, Google Docs, LibreOffice, Apple Pages (via RTF/DOCX export), e-books, and more. SwiftCompartido speaks 50+ document formats."

---

## Testing Strategy

### Shared Test Infrastructure

All Pandoc formats share the same testing approach:

```swift
@Suite("PandocDocumentParser - Format Support")
struct PandocFormatTests {

    @Test("Parse ODT with headings and paragraphs")
    func testOdtImport() throws {
        let url = try Fijos.getFixture("simple", extension: "odt")
        let (elements, titlePage) = try PandocDocumentParser.parse(url: url)

        #expect(elements.count == 2)
        #expect(elements[0].elementType == .sectionHeading(level: 1))
    }

    @Test("Parse RTF with formatting")
    func testRtfImport() throws {
        let url = try Fijos.getFixture("formatted", extension: "rtf")
        let (elements, _) = try PandocDocumentParser.parse(url: url)

        // Verify bold/italic preserved
        #expect(elements[0].elementText.contains("**bold**"))
    }

    @Test("Parse EPUB with chapters")
    func testEpubImport() throws {
        let url = try Fijos.getFixture("novel", extension: "epub")
        let (elements, titlePage) = try PandocDocumentParser.parse(url: url)

        // Verify chapter structure
        let headings = elements.filter { $0.elementType.isSectionHeading }
        #expect(headings.count > 0)
    }
}
```

### Fixture Creation

Create test files for each format:

```
Fixtures/
├── pandoc-formats/
│   ├── odt/
│   │   ├── simple.odt              # LibreOffice basic doc
│   │   ├── formatted.odt           # Bold, italic, lists
│   │   └── metadata.odt            # Full metadata
│   ├── rtf/
│   │   ├── simple.rtf              # TextEdit basic doc
│   │   ├── formatted.rtf           # Word RTF with formatting
│   │   └── universal.rtf           # Cross-platform RTF
│   ├── epub/
│   │   ├── novel.epub              # Multi-chapter ebook
│   │   ├── single-chapter.epub     # Simple ebook
│   │   └── with-images.epub        # EPUB with images
│   ├── html/
│   │   ├── blog-post.html          # Web article
│   │   └── simple.html             # Basic HTML
│   └── ipynb/
│       ├── simple.ipynb            # Basic notebook
│       └── with-code.ipynb         # Code + markdown cells
```

---

## User Experience

### File Import Flow

**User perspective:**

1. **Before** (DOCX only):
   - User has screenplay in Google Docs
   - Must export as DOCX
   - Import to SwiftCompartido

2. **After** (ODT + RTF + EPUB):
   - User has screenplay in Google Docs → Export as **ODT** ✅
   - User has screenplay in LibreOffice → **ODT** ✅
   - User has screenplay in TextEdit → **RTF** ✅
   - User has novel in Apple Books → **EPUB** ✅
   - User copies from website → **HTML** ✅

**Benefit**: "Import from anywhere, no conversion needed"

### Error Messages

**Before:**
```
Error: Unsupported file format .odt
Please convert to .fountain or .docx
```

**After:**
```
✅ File imported successfully from LibreOffice ODT
```

---

## Recommendations

### ✅ Add Immediately (Week 3, same as DOCX)

1. **ODT** - LibreOffice users (high value, zero cost)
2. **RTF** - Universal format (high value, zero cost)

**Rationale:**
- Same code path as DOCX (literally 2 lines per format)
- Huge user value for low-knowledge users with free software
- No additional file size or dependencies
- Minimal testing burden (~15 tests total)

### 🔄 Add Soon (v5.1, 1 month later)

3. **EPUB** - E-book readers (medium value, low cost)

**Rationale:**
- Writers may have novels/scripts in EPUB
- Requires chapter handling (slightly more complex)
- Good "premium" feature for v5.1

### ⏳ Add Later (v5.2+, if requested)

4. **HTML** - Web content (medium value)
5. **IPYNB** - Jupyter notebooks (low value, niche)

**Rationale:**
- Wait for user requests
- Niche use cases
- Can add anytime with zero breaking changes

---

## Implementation Checklist

### Week 3: Add ODT + RTF

- [ ] Rename `DocxParser` → `PandocDocumentParser`
- [ ] Add ODT format detection
- [ ] Add RTF format detection
- [ ] Update `GuionParsedElementCollection` auto-detection
- [ ] Update `GuionElementRow` format detection
- [ ] Create ODT test fixtures (3 files)
- [ ] Create RTF test fixtures (3 files)
- [ ] Write 15 new tests (5 DOCX, 5 ODT, 5 RTF)
- [ ] Update README.md supported formats
- [ ] Update CHANGELOG.md
- [ ] Update DOCX_IMPORT_REQUIREMENTS.md → PANDOC_IMPORT.md

### Future: Add EPUB (v5.1)

- [ ] Add EPUB format detection
- [ ] Handle chapter structure (EPUB → section headings)
- [ ] Handle images (extract or skip)
- [ ] Create EPUB test fixtures
- [ ] Write 10 new tests
- [ ] Update docs

---

**Last Updated**: 2025-01-15
**Pandoc Version**: 3.x
**Total Formats Supported**: 50+ (via Pandoc)
**User-Facing Formats**: DOCX, ODT, RTF, EPUB, HTML, IPYNB
