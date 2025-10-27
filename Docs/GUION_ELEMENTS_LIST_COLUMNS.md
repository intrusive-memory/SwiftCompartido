# GuionElementsList Column Feature

## Overview

`GuionElementsList` now supports adding custom trailing columns to each row. Each column has full access to the `GuionElementModel` for that row, enabling interactive features like generating audio, showing metadata, or adding action buttons.

## Basic Usage

### Default List (No Columns)

```swift
// Existing code continues to work
GuionElementsList()
GuionElementsList(document: myDocument)
```

### With Trailing Column

```swift
// Add custom content to the right of each row
GuionElementsList { element in
    // Access element properties
    Text("\(element.chapterIndex)")
        .font(.caption)
}
```

## Access to Element Data

The trailing content closure receives the complete `GuionElementModel`, providing access to:

- `element.persistentModelID` - Unique SwiftData identifier
- `element.elementText` - The element's text content
- `element.elementType` - Type (dialogue, action, sceneHeading, etc.)
- `element.chapterIndex` - Chapter number
- `element.orderIndex` - Position within chapter
- `element.generatedContent` - Associated AI-generated content (audio, images, etc.)
- All other `GuionElementModel` properties

## Common Patterns

### 1. Simple Metadata Display

```swift
GuionElementsList(document: screenplay) { element in
    VStack(alignment: .trailing, spacing: 2) {
        Text("Ch \(element.chapterIndex)")
            .font(.caption2)
        Text("#\(element.orderIndex)")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
    .frame(width: 60)
}
```

### 2. Interactive Button

```swift
GuionElementsList { element in
    Button {
        handleAction(element)
    } label: {
        Image(systemName: "ellipsis.circle")
    }
    .buttonStyle(.plain)
}

func handleAction(_ element: GuionElementModel) {
    print("Action for: \(element.elementText)")
}
```

### 3. Conditional Display

```swift
GuionElementsList(document: screenplay) { element in
    // Only show column for dialogue
    if element.elementType == .dialogue {
        Button("🎵") {
            generateAudio(for: element)
        }
    }
}
```

## Complete Example: Generate Audio Button

See `Sources/SwiftCompartido/UI/Examples/GuionElementsListWithAudioButton.swift` for a full implementation showing:

1. **Accessing element data** - Read `element.elementText` and `element.elementType`
2. **Generating content** - Call TTS service with element content
3. **Creating SwiftData records** - Store audio in `TypedDataStorage`
4. **Associating with element** - Link via `element.generatedContent` relationship
5. **Displaying status** - Show count of existing audio files

### Key Code Pattern

```swift
GuionElementsList(document: document) { element in
    Button {
        Task {
            await generateAudio(for: element)
        }
    } label: {
        Image(systemName: "waveform.circle")
    }
}

func generateAudio(for element: GuionElementModel) async {
    let content = element.elementText

    // Generate audio (replace with your TTS service)
    let audioData = try await generateTTS(text: content)

    // Create SwiftData record
    let audioRecord = TypedDataStorage(
        providerId: "your-tts-provider",
        requestorID: "tts.voice",
        mimeType: "audio/mpeg",
        binaryValue: audioData,
        prompt: "Generate speech",
        audioFormat: "mp3",
        durationSeconds: 5.0,
        voiceID: "default",
        voiceName: "Default Voice"
    )

    // Associate with element
    if element.generatedContent == nil {
        element.generatedContent = []
    }
    element.generatedContent?.append(audioRecord)

    // Save
    modelContext.insert(audioRecord)
    try modelContext.save()
}
```

## Multiple Columns

You can stack multiple views horizontally:

```swift
GuionElementsList { element in
    HStack(spacing: 8) {
        // Column 1: Type badge
        Text(element.elementType.rawValue)
            .font(.caption2)
            .padding(2)
            .background(.blue.opacity(0.2))
            .cornerRadius(4)

        // Column 2: Audio button
        Button("🎵") {
            generateAudio(for: element)
        }

        // Column 3: More actions
        Menu {
            Button("Delete") { /* ... */ }
            Button("Duplicate") { /* ... */ }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
    .frame(width: 150)
}
```

## Phase 6 File Storage Pattern

For larger audio files, use file-based storage:

```swift
func generateAudioWithFileStorage(for element: GuionElementModel) async {
    let requestID = UUID()
    let audioData = try await generateTTS(text: element.elementText)

    // Create storage area
    let storage = StorageAreaReference.temporary(requestID: requestID)

    // Create record
    let audioRecord = TypedDataStorage(
        id: requestID,
        providerId: "tts-provider",
        requestorID: "tts.voice",
        mimeType: "audio/mpeg",
        prompt: "Generate speech",
        audioFormat: "mp3"
    )

    // Save to file (creates file reference automatically)
    try audioRecord.saveBinary(
        audioData,
        to: storage,
        fileName: "element_\(element.persistentModelID.hashValue).mp3",
        mode: .local
    )

    // Associate and save
    element.generatedContent?.append(audioRecord)
    modelContext.insert(audioRecord)
    try modelContext.save()
}
```

## Querying Generated Content

To display or use generated content associated with elements:

```swift
// Get all audio for an element
let audioFiles = element.generatedContent?.filter {
    $0.mimeType.hasPrefix("audio/")
} ?? []

// Get the latest audio
let latestAudio = audioFiles.sorted {
    $0.generatedAt > $1.generatedAt
}.first

// Access file reference
if let fileRef = latestAudio?.fileReference {
    let url = try fileRef.resolveURL()
    // Play audio from URL
}
```

## Design Considerations

### Width Management

Always set an explicit width for your trailing content to maintain consistent layout:

```swift
.frame(width: 50)  // Fixed width
.frame(minWidth: 40, maxWidth: 100)  // Flexible
```

### Performance

- Keep trailing content lightweight - it renders for EVERY element
- Use lazy loading for expensive operations
- Consider caching computed values
- Use `Task` for async operations to avoid blocking the UI

### Accessibility

Don't forget to add accessibility labels:

```swift
Button { /* ... */ } label: {
    Image(systemName: "waveform.circle")
}
.accessibilityLabel("Generate audio for \(element.elementType)")
```

## Technical Details

### Type System

`GuionElementsList` is now generic:

```swift
public struct GuionElementsList<TrailingContent: View>
```

The `TrailingContent` defaults to `EmptyView` when no trailing content is provided, ensuring backward compatibility.

### Initializers

Four initializers are available:

1. `init()` - All elements, no trailing content
2. `init(document:)` - Filtered to document, no trailing content
3. `init(trailingContent:)` - All elements with trailing content
4. `init(document:trailingContent:)` - Filtered with trailing content

### HStack Integration

Trailing content is added to the existing `HStack` for each row:

```swift
HStack(alignment: .top) {
    // Element view (action, dialogue, etc.)

    // Trailing content (if provided)
    if let trailingContent = trailingContent {
        trailingContent(element)
    }
}
```

## See Also

- `GuionElementModel.swift:167-173` - Generated content relationship
- `TypedDataStorage.swift` - AI content storage model
- `GuionElementsListWithAudioButton.swift` - Complete working example
- `CLAUDE.md` - Phase 6 architecture documentation
