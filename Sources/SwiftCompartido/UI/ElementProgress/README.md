# Element Progress

Progress tracking system for GuionElementsList operations.

## Overview

The element progress system provides automatic progress bars that appear below list items during long-running operations (like audio generation). Progress bars automatically hide after completion.

## Components

### ElementProgressTracker

Scoped progress tracker for a specific element. Provides a cleaner API that doesn't require manually passing element IDs.

**Obtained via:**
```swift
let tracker = element.progressTracker(using: progressState)
```

**Methods:**
- `setProgress(_ progress: Double, message: String?)` - Update progress (0.0 to 1.0)
- `setComplete(message: String?)` - Mark as complete
- `setError(_ error: Error)` - Set error state
- `clearProgress()` - Clear progress for this element
- `hasVisibleProgress` - Check if progress is visible
- `currentProgress` - Get current progress info

**Convenience Methods:**
- `withProgress(startMessage:completeMessage:_:)` - Execute operation with automatic error handling
- `withSteps(_:operation:)` - Execute multi-step operation with automatic progress

### ElementProgressState

Observable state manager that tracks progress for each element.

**Features:**
- Per-element progress tracking
- Auto-hide after completion (configurable delay, default 2 seconds)
- Progress values from 0.0 to 1.0
- Optional progress messages
- Error handling

**Usage:**
```swift
@State private var progressState = ElementProgressState()

// Update progress
progressState.setProgress(0.5, for: elementID, message: "Processing...")

// Mark complete (auto-hides after delay)
progressState.setComplete(for: elementID, message: "Done!")

// Handle errors
progressState.setError(error, for: elementID)
```

### ElementProgressBar

SwiftUI view that displays progress for an element.

**Features:**
- Appears automatically when progress starts
- Smooth animations
- Shows progress value and optional message
- Changes color when complete (blue → green)
- Auto-hides after completion

**Automatic Integration:**
The progress bar is automatically included in every `GuionElementsList` row. No manual integration needed.

## How It Works

1. **State Management**: `ElementProgressState` tracks progress keyed by element `PersistentIdentifier`
2. **Environment**: Progress state is passed via SwiftUI environment
3. **Auto-Display**: `ElementProgressBar` checks environment for progress and shows/hides automatically
4. **Auto-Hide**: After completion, progress bar remains visible for `autoHideDelay` seconds (default 2s)

## Usage Example

### Basic Progress Tracking

```swift
struct MyView: View {
    @State private var progressState = ElementProgressState()

    var body: some View {
        GuionElementsList(document: screenplay) { element in
            Button("Process") {
                Task {
                    await processElement(element)
                }
            }
        }
        .environment(progressState)
    }

    func processElement(_ element: GuionElementModel) async {
        let id = element.persistentModelID

        // Start
        progressState.setProgress(0.0, for: id, message: "Starting...")

        // Update progress
        progressState.setProgress(0.5, for: id, message: "Processing...")

        // Complete
        progressState.setComplete(for: id, message: "Done!")
        // Bar auto-hides after 2 seconds
    }
}
```

### Integration with Button Actions

**Recommended: Using Element Progress Tracker**

```swift
struct GenerateAudioButton: View {
    let element: GuionElementModel
    @Environment(ElementProgressState.self) private var progressState

    var body: some View {
        Button("Generate") {
            Task {
                await generateAudio()
            }
        }
    }

    func generateAudio() async {
        // Get scoped progress tracker
        let tracker = element.progressTracker(using: progressState)

        do {
            // Report progress throughout operation
            tracker.setProgress(0.1, message: "Preparing...")

            let data = try await ttsService.generate(
                text: element.elementText,
                onProgress: { progress in
                    tracker.setProgress(progress, message: "Generating...")
                }
            )

            tracker.setProgress(0.9, message: "Saving...")
            try await save(data)

            tracker.setComplete(message: "Audio generated!")
        } catch {
            tracker.setError(error)
        }
    }
}
```

**Alternative: Using Convenience Methods**

```swift
func generateAudioWithConvenience() async {
    let tracker = element.progressTracker(using: progressState)

    do {
        try await tracker.withProgress(
            startMessage: "Generating audio...",
            completeMessage: "Audio generated!"
        ) { updateProgress in
            let data = try await ttsService.generate(
                text: element.elementText,
                onProgress: { progress in
                    updateProgress(progress, "Generating...")
                }
            )

            updateProgress(0.9, "Saving...")
            try await save(data)
        }
    } catch {
        // Error automatically reported
    }
}
```

### Multi-Step Operations

```swift
func multiStepOperation(element: GuionElementModel) async {
    let id = element.persistentModelID

    // Step 1: Analyze
    progressState.setProgress(0.0, for: id, message: "Analyzing...")
    try? await Task.sleep(for: .seconds(1))

    // Step 2: Process
    progressState.setProgress(0.33, for: id, message: "Processing...")
    try? await Task.sleep(for: .seconds(1))

    // Step 3: Generate
    progressState.setProgress(0.66, for: id, message: "Generating...")
    try? await Task.sleep(for: .seconds(1))

    // Complete
    progressState.setComplete(for: id, message: "All done!")
}
```

### Error Handling

```swift
func processWithErrorHandling(element: GuionElementModel) async {
    let id = element.persistentModelID

    progressState.setProgress(0.0, for: id, message: "Starting...")

    do {
        try await riskyOperation()
        progressState.setComplete(for: id)
    } catch {
        // Shows error message in progress bar, then auto-hides
        progressState.setError(error, for: id)
    }
}
```

## Customization

### Auto-Hide Delay

```swift
let progressState = ElementProgressState()
progressState.autoHideDelay = 3.0  // Hide 3 seconds after completion
```

### Manual Clear

```swift
// Clear progress for specific element
progressState.clearProgress(for: elementID)

// Clear all progress
progressState.clearAll()
```

## Design Notes

### Why Per-Element Progress?

Each element can have independent long-running operations (e.g., generating audio for multiple dialogue lines simultaneously). Per-element tracking ensures:
- Operations don't interfere with each other
- User can see progress for specific items
- Multiple operations can run in parallel

### Why Auto-Hide?

Auto-hiding provides better UX:
- User gets confirmation of completion
- UI doesn't stay cluttered with old progress bars
- No manual cleanup needed

### Performance

Progress state uses `@Observable` for efficient SwiftUI updates. Only elements with active progress re-render when progress changes.

## Integration with GuionElementsList

Progress bars are automatically integrated into `GuionElementsList`. Each list item has:

1. **Main row**: Element content + trailing column (buttons, etc.)
2. **Progress row**: Auto-showing progress bar

No additional setup required - just provide progress state via environment.

## See Also

- `GenerateAudioElementButton.swift` - Example button with progress tracking
- `GuionElementsListWithProgress.swift` - Complete working example
- `.claude/skills/add-guion-element-button.md` - Guide for creating buttons with progress
