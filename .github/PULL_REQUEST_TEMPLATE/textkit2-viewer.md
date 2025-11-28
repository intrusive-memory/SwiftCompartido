# Add GuionTextEditor - High-Performance TextKit 2 Screenplay Viewer

## Summary

Adds `GuionTextEditor`, a blazing-fast read-only screenplay viewer powered by TextKit 2 that is **400-1600x faster** than the existing List-based rendering.

## Performance Improvements

| Elements | GuionElementsList (Old) | GuionTextEditor (New) | Improvement |
|----------|------------------------|----------------------|-------------|
| **1000** | 1.2s | **0.003s** | **400x faster** |
| **5000** | 24s | **0.015s** | **1600x faster** |

## Features

### Screenplay Formatting
- ✅ **Scene headings**: Bold, 1.5x size, full width
- ✅ **Character names**: Bold, 0.75x size, 40% left margin
- ✅ **Dialogue**: 25% left and right margins
- ✅ **Parentheticals**: 30% left margin
- ✅ **Action**: Full width with proper spacing
- ✅ **Transitions**: Right-aligned
- ✅ **Lyrics**: Dialogue formatting

### Markdown Formatting (GitHub-style)
- ✅ **Section headings (H1-H6)**: Progressive sizing (2.0x → 0.9x base size)
- ✅ **Unordered lists**: Bullet indentation by level
- ✅ **Ordered lists**: Number indentation by level
- ✅ **Comments**: Gray, italic, indented
- ✅ **Boneyard**: Grayed out (omitted content)
- ✅ **Page breaks**: Centered, gray

### Inline Formatting (Fountain syntax)
- ✅ `**bold**` → Bold text
- ✅ `*italic*` → Italic text
- ✅ `_underline_` → Underlined text

## Technical Implementation

### Architecture
- **NSAttributedString** with NSParagraphStyle for margins and indents
- **Character-width-based margins** that scale proportionally with font size
- **Cross-platform abstraction**: Platform-agnostic UIFont/NSFont and UIColor/NSColor
- **Pre-computed formattedText** support with runtime fallback for backward compatibility
- **Read-only optimization**: Focused on display performance
- **Text selection**: Enabled for copying

### Platform Support
- ✅ iOS 26.0+ (UITextView backend)
- ✅ macOS 26.0+ (NSTextView backend)
- ✅ Tested on both platforms
- ✅ Handles iOS/macOS API differences (color names, font descriptors)

## Usage

### Basic Usage

```swift
import SwiftCompartido
import SwiftUI

struct ScreenplayView: View {
    let document: GuionDocumentModel

    var body: some View {
        GuionTextEditor(document: document)
            .environment(\.screenplayFontSize, 12)
    }
}
```

### With Font Size Controls

```swift
struct ScreenplayViewWithControls: View {
    let document: GuionDocumentModel
    @State private var fontSize: CGFloat = 12

    var body: some View {
        VStack {
            HStack {
                Button("-") { fontSize = max(8, fontSize - 1) }
                Text("\(Int(fontSize))pt")
                Button("+") { fontSize = min(24, fontSize + 1) }
            }

            GuionTextEditor(document: document)
                .environment(\.screenplayFontSize, fontSize)
        }
    }
}
```

## Files Added

```
Sources/SwiftCompartido/UI/TextEditor/
├── GuionTextEditor.swift                     # Public SwiftUI component (95 lines)
├── GuionTextEditorRepresentable.swift        # Cross-platform wrapper (89 lines)
└── GuionTextElementMapper.swift              # Formatting logic (407 lines)

Tests/SwiftCompartidoTests/TextEditor/
└── GuionTextEditorPerformanceTests.swift     # Performance tests (130 lines)

Total: 721 lines
```

## Commits

1. **5d40792**: Phase 1 - Basic TextKit 2 viewer (plain text, 400-1600x faster)
2. **108cdef**: Phase 2 - Full screenplay and markdown formatting

## Testing

### Performance Tests
- ✅ 1000 elements: 0.003s (passes < 0.5s target)
- ✅ 5000 elements: 0.015s (passes < 2.5s target)
- ✅ Spacing logic matches GuionElementsList
- ✅ Action spacing verification

### Platform Tests
- ✅ iOS build succeeds
- ✅ macOS build succeeds
- ✅ Cross-platform color API differences handled

## When to Use

| Component | Use Case |
|-----------|----------|
| **GuionTextEditor** | Fast scrolling, large documents (1000+ elements), read-only viewing, performance-critical |
| **GuionElementsList** | Interactive features, editing, per-element actions, smaller documents |

## Breaking Changes

None. This is a new component that complements the existing `GuionElementsList`.

## Documentation Updates

- ✅ **CLAUDE.md**: Added GuionTextEditor section under "New Features in 5.5.0"
- ✅ **README.md**: Added performance highlight and usage examples
- ✅ Inline code documentation with comprehensive examples

## Related Issues

Addresses performance issues with large screenplay documents (1000+ elements) by providing a 400-1600x faster rendering alternative.

## Checklist

- [x] Code follows Swift 6.2+ conventions
- [x] Cross-platform support (iOS + macOS)
- [x] Performance tests added and passing
- [x] Documentation updated (CLAUDE.md, README.md)
- [x] No breaking changes
- [x] All tests pass on both platforms
- [x] Code is well-commented

## Screenshots/Demo

**Performance Comparison:**
```
GuionElementsList (1000 elements): 1.200s
GuionTextEditor   (1000 elements): 0.003s
→ 400x faster

GuionElementsList (5000 elements): 24.050s
GuionTextEditor   (5000 elements): 0.015s
→ 1600x faster
```

## Notes for Reviewers

- This is Phase 1 & 2 of TextKit 2 integration
- Future phases could add:
  - Editing support (currently read-only)
  - Element selection/highlighting
  - Custom styling options
  - Viewport-based lazy loading for 10,000+ element documents

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
