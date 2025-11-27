# Pandoc Document Import

SwiftCompartido supports importing document files (DOCX, ODT, RTF) with automatic conversion to screenplay elements via the bundled Pandoc converter.

## Supported Formats

| Format | Extension | Source Applications | Notes |
|--------|-----------|---------------------|-------|
| **Microsoft Word** | `.docx` | Word 2007+, Google Docs, Pages | Office Open XML format |
| **OpenDocument Text** | `.odt` | LibreOffice, Google Docs | OpenDocument Format (ODF) |
| **Rich Text Format** | `.rtf` | TextEdit, Word, LibreOffice | Universal compatibility |

## Quick Start

### Import a DOCX File

```swift
import SwiftCompartido

// Load document
let screenplay = try await GuionParsedElementCollection(
    file: "/path/to/document.docx"
)

// Access elements
for element in screenplay.elements {
    print(element.text)
}

// Access metadata
print(screenplay.titlePage)
```

### Automatic Format Detection

SwiftCompartido automatically detects the file format based on extension:

```swift
// All of these work automatically
let docx = try await GuionParsedElementCollection(file: "script.docx")
let odt = try await GuionParsedElementCollection(file: "script.odt")
let rtf = try await GuionParsedElementCollection(file: "script.rtf")
```

## How It Works

### 1. Pandoc Conversion

Documents are converted to Markdown via Pandoc:

```
DOCX/ODT/RTF → Pandoc → Markdown → MarkdownParser → GuionElements
```

### 2. Pandoc Detection

The parser looks for Pandoc in this order:

1. **Bundled Pandoc** (production): `Resources/Binaries/pandoc`
2. **System Pandoc** (development): `/opt/homebrew/bin/pandoc`, `/usr/local/bin/pandoc`

### 3. Platform Support

- **macOS**: Full support (Process API available)
- **iOS**: Not supported (Process API unavailable)

## Document Structure Mapping

### Headings

DOCX/ODT/RTF headings map to section headings:

| Document Style | GuionElement | Rendering |
|----------------|--------------|-----------|
| Heading 1 | `.sectionHeading(level: 1)` | Large title |
| Heading 2 | `.sectionHeading(level: 2)` | Act heading |
| Heading 3-6 | `.sectionHeading(level: 3-6)` | Scene groups, beats |

### Paragraphs

Normal paragraphs become action elements:

```swift
// DOCX paragraph
"INT. COFFEE SHOP - DAY"

// Becomes
GuionElement(elementType: .action, text: "INT. COFFEE SHOP - DAY")
```

### Text Formatting

Formatting is preserved in markdown syntax:

| Document Format | Markdown | Rendering |
|-----------------|----------|-----------|
| **Bold** | `**bold**` | **Bold text** |
| *Italic* | `*italic*` | *Italic text* |
| `Code` | `` `code` `` | `Monospace` |

### Lists

Lists are converted to markdown format:

```markdown
# Bulleted lists
- First item
- Second item
  - Nested item

# Numbered lists
1. First step
2. Second step
   1. Substep
```

### Page Breaks

Hard page breaks become:

```swift
GuionElement(elementType: .pageBreak, text: "===")
```

## Metadata Extraction

Document properties are extracted to the title page:

```swift
// DOCX metadata:
// Title: "My Screenplay"
// Author: "Jane Doe"
// Date: "2025-01-15"

// Becomes:
screenplay.titlePage = [
    ["title": ["My Screenplay"]],
    ["author": ["Jane Doe"]],
    ["date": ["2025-01-15"]]
]
```

## SwiftData Integration

Import documents directly into SwiftData:

```swift
import SwiftData

let screenplay = try await GuionParsedElementCollection(file: "script.docx")

let document = await GuionDocumentParserSwiftData.parse(
    script: screenplay,
    in: modelContext
)

// Access in SwiftUI
struct DocumentView: View {
    @Query var documents: [GuionDocumentModel]

    var body: some View {
        List(documents) { doc in
            Text(doc.title ?? "Untitled")
        }
    }
}
```

## Error Handling

### Common Errors

```swift
do {
    let screenplay = try await GuionParsedElementCollection(file: "doc.docx")
} catch PandocParserError.pandocNotAvailable {
    print("Pandoc converter not available")
} catch PandocParserError.unsupportedFormat(let ext) {
    print("Unsupported format: .\(ext)")
} catch PandocParserError.conversionFailed(let message) {
    print("Conversion failed: \(message)")
} catch {
    print("Unknown error: \(error)")
}
```

### Platform Errors

On iOS, document import is not supported:

```swift
#if os(macOS)
let screenplay = try await GuionParsedElementCollection(file: "doc.docx")
#else
// iOS: Process API not available
// Use other formats (.fountain, .md, .pdf)
#endif
```

## Testing

SwiftCompartido includes comprehensive tests for Pandoc integration:

- **Unit tests**: Pandoc detection, format support, error handling
- **Integration tests**: End-to-end document conversion
- **GuionParsedElementCollection tests**: API integration

Run tests:

```bash
./build.sh --action test
```

## Examples

### Import with Metadata

```swift
let screenplay = try await GuionParsedElementCollection(
    file: "screenplay.docx"
)

// Check for title
if let titleEntry = screenplay.titlePage.first(where: { $0.keys.contains("title") }) {
    let title = titleEntry["title"]?.first ?? "Untitled"
    print("Title: \(title)")
}
```

### Import with Progress

```swift
let progress = OperationProgress(totalUnits: nil) { update in
    print("Progress: \(Int((update.fractionCompleted ?? 0) * 100))%")
}

let screenplay = try await GuionParsedElementCollection(
    file: "screenplay.docx",
    progress: progress
)
```

### Batch Import

```swift
let urls = [
    URL(fileURLWithPath: "script1.docx"),
    URL(fileURLWithPath: "script2.odt"),
    URL(fileURLWithPath: "script3.rtf")
]

for url in urls {
    let screenplay = try await GuionParsedElementCollection(file: url.path)
    print("Imported: \(screenplay.filename ?? "unknown")")
}
```

## Limitations

1. **iOS**: Not supported (Process API unavailable)
2. **Password-protected files**: Not supported
3. **Legacy .doc format**: Not supported (use DOCX instead)
4. **Embedded images**: Not preserved (text content only)
5. **Complex tables**: Converted to markdown tables (formatting may be simplified)

## Performance

Expected performance on modern hardware:

| Document Size | Conversion Time | Memory Usage |
|---------------|-----------------|--------------|
| 10 pages | < 500ms | < 10 MB |
| 100 pages | < 2 seconds | < 50 MB |
| 500 pages | < 5 seconds | < 100 MB |

## License

Pandoc is GPL-2 licensed software. The bundled Pandoc binary license is included at `Resources/Licenses/pandoc-LICENSE.txt`.

## See Also

- [Pandoc User's Guide](https://pandoc.org/MANUAL.html)
- [Markdown Parser Documentation](MARKDOWN_PARSER.md)
- [GuionParsedElementCollection API](../Sources/SwiftCompartido/Sendable/GuionParsedScreenplay.swift)
