# Element Buttons

Custom button components for GuionElementsList rows. Each button has access to its row's `GuionElementModel`.

## Available Buttons

### GenerateAudioElementButton
Generates text-to-speech audio for dialogue, character, and action elements.

**Features:**
- Shows count of existing audio files
- Loading state indicator
- Error handling with alerts
- Stores audio in SwiftData via TypedDataStorage
- Associates audio with element via generatedContent relationship

**Usage:**
```swift
GuionElementsList(document: screenplay) { element in
    GenerateAudioElementButton(element: element)
}
```

### ElementMetadataButton
Displays element metadata in a popover.

**Shows:**
- Element type and position
- Text content (truncated)
- Scene information (for scene headings)
- Generated content counts (audio, images)

**Usage:**
```swift
GuionElementsList(document: screenplay) { element in
    ElementMetadataButton(element: element)
}
```

## Creating New Buttons

See the skill documentation:
```
.claude/skills/add-guion-element-button.md
```

This skill provides:
- Step-by-step implementation guide
- Common patterns (AI content generation, file storage, etc.)
- Complete code templates
- Testing guidelines

## Combining Multiple Buttons

```swift
// Horizontal layout with multiple buttons
GuionElementsList(document: screenplay) { element in
    HStack(spacing: 8) {
        GenerateAudioElementButton(element: element)
        ElementMetadataButton(element: element)
        // Add more buttons here
    }
    .frame(width: 150)
}
```

## Element Data Access

All buttons receive the full `GuionElementModel` with access to:

- `element.persistentModelID` - Unique identifier
- `element.elementText` - Text content
- `element.elementType` - Type (.dialogue, .action, etc.)
- `element.chapterIndex` - Chapter number
- `element.orderIndex` - Position within chapter
- `element.generatedContent` - Associated AI content (audio, images, etc.)
- `element.document` - Parent document
- `element.cachedSceneLocation` - Scene info (for scene headings)

## Design Guidelines

1. **Width**: Always set explicit frame width for consistent layout
2. **Loading states**: Show ProgressView for async operations
3. **Error handling**: Use alerts or inline error messages
4. **Accessibility**: Add `.help()` tooltips
5. **Conditional display**: Only show buttons when applicable
6. **SwiftData**: Use `@Environment(\.modelContext)` for database operations

## See Also

- [Skill Documentation](.claude/skills/add-guion-element-button.md) - Comprehensive guide
- [Column Documentation](../../../Docs/GUION_ELEMENTS_LIST_COLUMNS.md) - GuionElementsList column feature
- [Examples](../Examples/GuionElementsListWithAudioButton.swift) - Complete working examples
