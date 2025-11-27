# Markdown Rendering

SwiftCompartido provides **dual rendering modes**: GitHub-style markdown rendering for `.md`/`.markdown` files, and traditional screenplay formatting for Fountain files.

## Overview

The library automatically detects the source file format and applies appropriate styling:

- **Markdown files** (`.md`, `.markdown`): GitHub-style rendering
- **Fountain files** (`.fountain`): Screenplay formatting
- **Other formats** (`.highland`, `.fdx`, `.pdf`): Screenplay formatting

## GitHub-Style Markdown Rendering

### Features

- **Headings (H1-H6)**: Sized typography with bottom borders on H1/H2
- **Bold text**: `**bold**` → **bold**
- **Italic text**: `*italic*` → *italic*
- **Inline code**: `` `code` `` → `code` (monospaced, smaller, secondary color)
- **Responsive sizing**: All elements scale with the user's font size setting

### Heading Styles

Markdown headings follow GitHub's visual hierarchy:

| Level | Font Size | Weight | Border |
|-------|-----------|--------|--------|
| H1 | 2.0em | Semibold | Bottom border |
| H2 | 1.5em | Semibold | Bottom border |
| H3 | 1.25em | Semibold | None |
| H4 | 1.0em | Semibold | None |
| H5 | 0.875em | Semibold | None |
| H6 | 0.85em | Semibold | None |

### Paragraph Styles

Markdown paragraphs (action elements) support:
- **Bold**: `**text**`
- **Italic**: `*text*`
- **Inline code**: `` `code` ``
- Vertical padding for readability

## Implementation Details

### Automatic Format Detection

The rendering mode is determined by the document's filename:

```swift
private var isMarkdownDocument: Bool {
    guard let filename = element.document?.filename else { return false }
    let lowercased = filename.lowercased()
    return lowercased.hasSuffix(".md") || lowercased.hasSuffix(".markdown")
}
```

### View Components

**Markdown Views:**
- `MarkdownSectionHeadingView`: GitHub-style headings (H1-H6)
- `MarkdownActionView`: GitHub-style paragraphs with formatting

**Fountain/Screenplay Views:**
- `SectionHeadingView`: Screenplay outline headings
- `ActionView`: Screenplay action lines
- `SceneHeadingView`: Scene sluglines
- `DialogueCharacterView`, `DialogueTextView`, etc.

### Rendering Logic

```swift
@ViewBuilder
private var elementView: some View {
    if isMarkdownDocument {
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

## Example Usage

### Markdown Document

```markdown
---
title: My Document
author: Jane Doe
---

# Introduction

This is a **bold** statement with some *italic* text and `inline code`.

## Features

Markdown documents are rendered with GitHub styling for better readability.
```

**Renders as:**
- Large H1 "Introduction" with bottom border
- Paragraph with bold, italic, and code formatting
- Medium H2 "Features" with bottom border
- Standard paragraph text

### Fountain Document

```fountain
INT. COFFEE SHOP - DAY

SARAH enters, looking nervous.

SARAH
(whispering)
This is it.
```

**Renders as:**
- Scene heading in Courier Bold, uppercase
- Action line in Courier
- Character name centered, uppercase
- Parenthetical in Courier
- Dialogue in Courier

## Font Size Control

Both rendering modes support dynamic font sizing via the `+` and `-` buttons in GuionViewer:

```swift
// User clicks +
fontSize = min(24, fontSize + 1)

// All markdown elements scale proportionally
H1: fontSize * 2.0
H2: fontSize * 1.5
Paragraph: fontSize * 1.0
```

## Customization

### Modifying Markdown Styles

To adjust GitHub-style rendering, edit:

**MarkdownSectionHeadingView.swift:**
```swift
private var fontForLevel: Font {
    switch level {
    case 1:
        return .system(size: fontSize * 2.0) // Adjust multiplier
    // ...
    }
}
```

**MarkdownActionView.swift:**
```swift
private func parseMarkdownText(_ text: String) -> Text {
    // Add support for new markdown syntax
    // Example: ~~strikethrough~~, __underline__, etc.
}
```

### Adding New Markdown Features

Planned enhancements:
- [ ] Lists (ordered and unordered)
- [ ] Block quotes
- [ ] Code blocks with syntax highlighting
- [ ] Tables
- [ ] Links (with hover preview)
- [ ] Images (inline display)
- [ ] Task lists `- [ ]` and `- [x]`
- [ ] Strikethrough `~~text~~`

## Best Practices

1. **Use appropriate formats**:
   - Markdown (`.md`) for documentation, notes, outlines
   - Fountain (`.fountain`) for screenplays

2. **Consistent naming**:
   - Always use `.md` or `.markdown` extension for markdown files
   - Use `.fountain` for screenplay files

3. **Test both modes**:
   - Verify rendering in both markdown and screenplay modes
   - Check font scaling with `+` and `-` controls

4. **Accessibility**:
   - Markdown headings create proper document structure
   - Font sizing respects user preferences

## See Also

- [GuionViewer](../Sources/SwiftCompartido/UI/GuionViewer.swift) - Main viewer with font controls
- [MarkdownParser](../Sources/SwiftCompartido/Serialization/MarkdownParser.swift) - YAML front matter parsing
- [Fountain Specification](https://fountain.io/) - Screenplay format
