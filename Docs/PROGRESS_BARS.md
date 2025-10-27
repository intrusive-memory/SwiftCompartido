# GuionElementsList Progress Bars

Auto-showing progress bars for GuionElementsList items.

## Overview

Progress bars automatically appear as a second row below list items during long-running operations. They hide automatically after completion with smooth animations.

## Features

- **Automatic display**: Progress bars appear when operations start
- **Auto-hide**: Bars disappear 2 seconds after completion (configurable)
- **Per-element tracking**: Each element has independent progress
- **Smooth animations**: Fade in/out with slide transition
- **Progress messages**: Optional status messages
- **Error handling**: Shows error messages before auto-hiding
- **Zero configuration**: Built into GuionElementsList by default

## Quick Start

```swift
import SwiftUI
import SwiftData

struct MyView: View {
    @State private var progressState = ElementProgressState()

    var body: some View {
        GuionElementsList(document: screenplay) { element in
            GenerateAudioElementButton(element: element)
        }
        .environment(progressState)  // Enable progress tracking
    }
}
```

## Using Progress in Buttons

```swift
struct MyButton: View {
    let element: GuionElementModel
    @Environment(ElementProgressState.self) private var progressState

    private func performAction() async {
        let id = element.persistentModelID

        // Start - progress bar appears
        progressState.setProgress(0.0, for: id, message: "Starting...")

        // Update progress
        progressState.setProgress(0.5, for: id, message: "Processing...")

        // Complete - bar turns green, auto-hides after 2s
        progressState.setComplete(for: id, message: "Done!")
    }
}
```

## Architecture

### Components

1. **ElementProgressState** (`@MainActor @Observable`)
   - Tracks progress keyed by element `PersistentIdentifier`
   - Auto-hide scheduling
   - Thread-safe with main actor isolation

2. **ElementProgressBar** (SwiftUI View)
   - Checks environment for progress
   - Shows/hides automatically
   - Smooth animations

3. **GuionElementsList Integration**
   - VStack per row: main content + progress bar
   - Progress bar always present but conditionally visible

### Data Flow

```
Button Action
    ↓
Update ElementProgressState
    ↓
@Observable triggers UI update
    ↓
ElementProgressBar checks hasVisibleProgress()
    ↓
Show/hide with animation
    ↓
After completion delay → auto-hide
```

## API Reference

### ElementProgressState

```swift
@MainActor
@Observable
public final class ElementProgressState {
    // Configuration
    public var autoHideDelay: TimeInterval = 2.0

    // Methods
    public func setProgress(_ progress: Double, for elementID: PersistentIdentifier, message: String? = nil)
    public func setComplete(for elementID: PersistentIdentifier, message: String? = nil)
    public func setError(_ error: Error, for elementID: PersistentIdentifier)
    public func clearProgress(for elementID: PersistentIdentifier)
    public func clearAll()

    // Query
    public func hasVisibleProgress(for elementID: PersistentIdentifier) -> Bool
    public func progress(for elementID: PersistentIdentifier) -> ElementProgress?
}
```

### ElementProgress Struct

```swift
public struct ElementProgress: Sendable {
    public var progress: Double         // 0.0 to 1.0
    public var message: String?         // Optional status message
    public var isComplete: Bool         // Completion flag
    public var completedAt: Date?       // Timestamp for auto-hide
}
```

## Examples

### Multi-Step Operation

```swift
func processElement(_ element: GuionElementModel) async {
    let id = element.persistentModelID

    do {
        progressState.setProgress(0.0, for: id, message: "Analyzing...")
        let analysis = try await analyze(element.elementText)

        progressState.setProgress(0.33, for: id, message: "Processing...")
        let processed = try await process(analysis)

        progressState.setProgress(0.66, for: id, message: "Generating...")
        let result = try await generate(processed)

        progressState.setProgress(0.9, for: id, message: "Saving...")
        try await save(result)

        progressState.setComplete(for: id, message: "Success!")
    } catch {
        progressState.setError(error, for: id)
    }
}
```

### With Progress Callbacks

```swift
let audioData = try await ttsService.generate(
    text: element.elementText,
    onProgress: { progress in
        progressState.setProgress(
            progress,
            for: element.persistentModelID,
            message: "Generating audio..."
        )
    }
)
```

### Parallel Operations

```swift
// Progress bars for multiple elements simultaneously
for element in elements {
    Task {
        await processElement(element)  // Each gets its own progress bar
    }
}
```

## Customization

### Change Auto-Hide Delay

```swift
let progressState = ElementProgressState()
progressState.autoHideDelay = 3.0  // Hide after 3 seconds
```

### Manual Control

```swift
// Clear specific element
progressState.clearProgress(for: elementID)

// Clear all progress
progressState.clearAll()
```

## UI Details

### Progress Bar Appearance

- **Active**: Blue progress bar with message
- **Complete**: Green progress bar, shows completion message
- **Error**: Shows error message (red tint in future)

### Animations

- **Appear**: 0.2s ease-in-out fade + slide from top
- **Disappear**: 0.2s ease-in-out fade
- **Auto-hide delay**: 2.0s (configurable)

### Layout

```
┌─────────────────────────────────────┐
│ Element Content         │ Buttons   │  ← Main row
├─────────────────────────────────────┤
│ ████████████░░░░░░░░░░░░ 60%        │  ← Progress bar (when active)
│ Generating audio...                 │  ← Message
└─────────────────────────────────────┘
```

## Integration with Existing Buttons

The `GenerateAudioElementButton` already includes progress tracking. See:
- `UI/ElementButtons/GenerateAudioElementButton.swift:104-141` - Full implementation
- Simulates multi-step progress during audio generation
- Auto-completes with success message

## Testing

See `UI/Examples/GuionElementsListWithProgress.swift` for:
- Interactive demo with "Simulate Progress" button
- Shows all three states (no progress, active, complete)
- Demonstrates auto-hide behavior

## Technical Notes

### Thread Safety

`ElementProgressState` is `@MainActor` isolated, ensuring all updates happen on the main thread. This prevents data races and ensures UI updates are safe.

### Performance

- Progress state uses `@Observable` for efficient SwiftUI updates
- Only elements with active progress re-render on updates
- Auto-hide uses Task-based scheduling (no timers)

### Memory Management

- Progress data is removed on auto-hide
- Weak self capture in async tasks prevents retain cycles
- @Observable ensures proper cleanup

## Migration from Custom Progress

If you have custom progress implementations:

1. Replace custom state with `ElementProgressState`
2. Change `@Environment(\.myProgressKey)` to `@Environment(ElementProgressState.self)`
3. Update progress calls to use `setProgress(_, for:)`
4. Remove manual show/hide logic (automatic now)

## See Also

- `UI/ElementProgress/README.md` - Detailed component documentation
- `UI/ElementProgress/ElementProgressState.swift` - State management implementation
- `UI/ElementProgress/ElementProgressBar.swift` - UI component
- `UI/Examples/GuionElementsListWithProgress.swift` - Working example
- `.claude/skills/add-guion-element-button.md` - Pattern 6: Progress Tracking
