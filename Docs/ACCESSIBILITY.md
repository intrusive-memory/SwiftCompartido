# Accessibility Guide

SwiftCompartido has comprehensive accessibility support for VoiceOver and other assistive technologies. This guide documents all accessibility features, keyboard shortcuts, and best practices for using the library.

## Table of Contents

- [Keyboard Shortcuts](#keyboard-shortcuts)
- [VoiceOver Support](#voiceover-support)
- [Accessibility Labels and Hints](#accessibility-labels-and-hints)
- [Custom Accessibility Actions](#custom-accessibility-actions)
- [Testing Accessibility](#testing-accessibility)

## Keyboard Shortcuts

### GuionViewer

The main screenplay viewer supports the following keyboard shortcuts:

| Shortcut | Action | Description |
|----------|--------|-------------|
| `⌘-` | Decrease Font Size | Decreases the screenplay font size by 1 point (minimum: 8pt) |
| `⌘=` | Increase Font Size | Increases the screenplay font size by 1 point (maximum: 24pt) |

### Element Navigation

VoiceOver users can navigate through screenplay elements using standard VoiceOver commands:

| Command | Action |
|---------|--------|
| `⌃⌥→` | Next element |
| `⌃⌥←` | Previous element |
| `⌃⌥Space` | Activate element (show/hide details) |

## VoiceOver Support

### Screenplay Elements

All screenplay elements are fully accessible with VoiceOver. Each element announces:

- **Element Type**: Action, Dialogue, Scene Heading, etc.
- **Content**: The text content of the element
- **Position**: Chapter and order index for navigation

Example VoiceOver announcement:
```
"Scene Heading: INT. COFFEE SHOP - DAY"
"Action: John walks into the coffee shop."
"Dialogue: Hello, how are you?"
```

### Interactive Elements

#### Font Size Controls

- **Decrease Button**: "Decrease font size, Decreases the screenplay font size by 1 point, 12 points"
- **Current Size**: "Current font size: 12 points"
- **Increase Button**: "Increase font size, Increases the screenplay font size by 1 point, 12 points"

#### Element Details Button

- **Label**: "Element details"
- **Hint**: "Shows detailed information about this screenplay element including type, position, and generated content"
- **Action**: Opens popover with element metadata

### Audio Playback

Audio playback controls provide full accessibility support:

#### Playback Controls

- **Play/Pause Button**:
  - When paused: "Play, Starts or resumes audio playback, Paused"
  - When playing: "Pause, Pauses audio playback, Playing"
- **Stop Button**: "Stop, Stops audio playback and resets to the beginning"

#### State Announcements

VoiceOver automatically announces playback state changes:
- "Audio playback started"
- "Audio playback paused"
- "Audio playback stopped"

#### Audio Information

Audio metadata is announced as:
- "Audio information: Voice: Rachel, Format: MP3, Duration: 0:05"

### Progress Indicators

Progress bars announce their current state:

- **Active**: "Operation in progress, 50%"
- **Complete**: "Operation complete, 100%"
- **With Message**: "[Message], 75%"

### Content Filters

Content type filters in GeneratedContentListView:

- **Label**: "Filter content by type"
- **Hint**: "Select a content type to filter the list"
- **Value**: Current selection (e.g., "Audio", "Image", "Text")

### Content Lists

Each content item in the list announces:

- **Type**: "Audio content", "Image content", "Text content", etc.
- **Prompt**: The generation prompt
- **Metadata**: Duration, size, word count, or dimensions depending on type
- **Position**: "Element at chapter [X], position [Y]"
- **Selection State**: "Selected" when the item is active

Example announcement:
```
"Audio content: Generate audio for this dialogue, Duration: 0:05, Element at chapter 1, position 3, Selected"
```

### Image Views

Images announce descriptive information:

- **Loading**: "Loading image, Please wait"
- **Error**: "Image load error, [Error description]"
- **Loaded**: "Generated image: [Prompt], Size: 1024 by 1024 pixels"

### Text Views

Text content announces:

- **Loading**: "Loading text content, Please wait"
- **Error**: "Text load error, [Error description]"
- **Loaded**: "Generated text for: [Prompt], [Word count] words. Content: [Text]"

## Custom Accessibility Actions

### Popover Interactions

Screenplay elements support custom accessibility actions for showing/hiding details:

- **Action**: "Show details" or "Hide details"
- **Trigger**: Activated with `⌃⌥Space`

This provides an alternative to hover gestures for VoiceOver users.

### Audio Playback Actions

Audio views provide custom actions:

- **Action**: "Toggle playback"
- **Action**: "Stop playback"

These allow VoiceOver users to control playback without targeting specific buttons.

## Accessibility Labels and Hints

### Accessibility Label Guidelines

All interactive elements include:

1. **Accessibility Label**: Short description of the element
2. **Accessibility Hint**: Description of what happens when activated
3. **Accessibility Value**: Current state or value (when applicable)
4. **Accessibility Traits**: Appropriate traits (.isButton, .isSelected, .isImage, etc.)

### Element Grouping

Complex views use `.accessibilityElement(children: .contain)` to group related content:

- Audio information (voice, format, duration)
- Playback controls (play/pause, stop)
- Progress indicators (bar and message)
- Content metadata (type, provider, position)

This provides a better navigation experience by treating related elements as a single unit.

## Testing Accessibility

### VoiceOver Testing (macOS)

1. **Enable VoiceOver**: Press `⌘F5` or go to System Settings → Accessibility → VoiceOver
2. **Navigate Elements**: Use `⌃⌥→` and `⌃⌥←`
3. **Interact**: Press `⌃⌥Space` to activate
4. **Verify Announcements**: Listen for clear, descriptive labels

### VoiceOver Testing (iOS)

1. **Enable VoiceOver**: Triple-click Home/Side button or Settings → Accessibility → VoiceOver
2. **Navigate**: Swipe right/left
3. **Activate**: Double-tap
4. **Verify**: Ensure all elements are reachable and clearly described

### Keyboard Navigation Testing

1. **Tab Through Interface**: Verify all interactive elements are reachable
2. **Test Shortcuts**: Verify `⌘-` and `⌘=` work for font sizing
3. **Verify Focus**: Ensure focus indicators are visible

### Accessibility Inspector (Xcode)

Use Xcode's Accessibility Inspector to:

1. **Inspect Elements**: View accessibility properties
2. **Run Audit**: Identify accessibility issues
3. **Test VoiceOver**: Simulate VoiceOver without enabling it system-wide

## Best Practices for Consumers

### Adding Custom Accessibility

When using SwiftCompartido in your app:

```swift
// Good: Add accessibility to custom UI wrapping library components
GuionViewer(document: screenplay)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Screenplay viewer")

// Good: Provide context-specific hints
ElementMetadataButton(element: element)
    .accessibilityHint("Shows character, scene, and timing information")

// Avoid: Don't override built-in accessibility
GuionElementsList(document: screenplay)
    // Don't add .accessibilityLabel here - elements already have proper labels
```

### Custom Trailing Content

When adding custom trailing content to lists, ensure it's accessible:

```swift
GuionElementsList(document: screenplay) { element in
    Button("Generate Audio") {
        generateAudio(for: element)
    }
    .accessibilityLabel("Generate audio for \(element.elementType.description)")
    .accessibilityHint("Creates audio narration for this element")
}
```

### Keyboard Shortcuts

If adding custom keyboard shortcuts, follow macOS conventions:

- Use `⌘` for primary actions
- Use `⌘⇧` for related but opposite actions
- Provide `.help()` modifiers for discoverability

### Dynamic Type Support

SwiftCompartido respects the `screenplayFontSize` environment variable. Consider supporting Dynamic Type in your app:

```swift
@Environment(\.dynamicTypeSize) var dynamicTypeSize

var fontSize: CGFloat {
    switch dynamicTypeSize {
    case .xSmall, .small: return 10
    case .medium: return 12
    case .large: return 14
    case .xLarge, .xxLarge, .xxxLarge: return 16
    default: return 12
    }
}

GuionViewer(document: screenplay)
    .environment(\.screenplayFontSize, fontSize)
```

## Reporting Accessibility Issues

If you encounter accessibility issues with SwiftCompartido:

1. **Verify**: Test with latest version
2. **Document**: Note the specific component and VoiceOver behavior
3. **Report**: File an issue on GitHub with:
   - Component name (e.g., GuionViewer, TypedDataAudioView)
   - Expected behavior
   - Actual behavior
   - Steps to reproduce
   - VoiceOver announcements (if applicable)

## Resources

- [Apple Human Interface Guidelines - Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [VoiceOver User Guide](https://support.apple.com/guide/voiceover/welcome/mac)
- [SwiftUI Accessibility Documentation](https://developer.apple.com/documentation/swiftui/accessibility)
- [Xcode Accessibility Inspector](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/OSXAXTestingApps.html)
