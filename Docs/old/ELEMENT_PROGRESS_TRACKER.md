# Element Progress Tracker

Cleaner API for tracking progress on GuionElementModel operations.

## Overview

`ElementProgressTracker` provides a scoped, element-aware interface for progress tracking. Instead of manually passing element IDs, you get a tracker bound to a specific element.

## Quick Comparison

### Before (Manual ID Passing)

```swift
let elementID = element.persistentModelID

progressState.setProgress(0.5, for: elementID, message: "Processing...")
progressState.setComplete(for: elementID, message: "Done!")
```

### After (Element Progress Tracker)

```swift
let tracker = element.progressTracker(using: progressState)

tracker.setProgress(0.5, message: "Processing...")
tracker.setComplete(message: "Done!")
```

## Getting a Tracker

```swift
@Environment(ElementProgressState.self) private var progressState

let tracker = element.progressTracker(using: progressState)
```

## Basic API

### Update Progress

```swift
tracker.setProgress(0.0, message: "Starting...")
tracker.setProgress(0.5, message: "Processing...")
tracker.setProgress(1.0, message: "Complete!")
```

### Mark Complete

```swift
tracker.setComplete(message: "Done!")
// Progress bar turns green and auto-hides after 2 seconds
```

### Handle Errors

```swift
do {
    try await riskyOperation()
    tracker.setComplete()
} catch {
    tracker.setError(error)
    // Error message shown in progress bar, then auto-hides
}
```

### Clear Progress

```swift
tracker.clearProgress()
// Immediately removes progress bar
```

## Query Methods

### Check if Progress is Visible

```swift
if tracker.hasVisibleProgress {
    print("Operation in progress")
}

// Or use element directly
if element.hasVisibleProgress(in: progressState) {
    print("Element has active progress")
}
```

### Get Current Progress

```swift
if let progress = tracker.currentProgress {
    print("Progress: \(progress.progress)")
    print("Message: \(progress.message ?? "none")")
    print("Complete: \(progress.isComplete)")
}

// Or use element directly
if let progress = element.currentProgress(in: progressState) {
    // ...
}
```

## Convenience Methods

### withProgress - Automatic Error Handling

Execute an operation with automatic progress tracking and error handling:

```swift
try await tracker.withProgress(
    startMessage: "Generating audio...",
    completeMessage: "Audio generated!"
) { updateProgress in

    updateProgress(0.2, "Analyzing text...")
    let analysis = try await analyze(element.elementText)

    updateProgress(0.5, "Generating...")
    let audio = try await generate(analysis)

    updateProgress(0.9, "Saving...")
    try await save(audio)

    return audio
}
// Automatically calls setComplete() on success
// Automatically calls setError() on failure
```

### withSteps - Step-Based Progress

Execute discrete steps with automatic progress calculation:

```swift
let steps = [
    "Analyzing text...",
    "Generating audio...",
    "Applying effects...",
    "Saving file..."
]

try await tracker.withSteps(steps) { index, step in
    print("Step \(index): \(step)")
    try await performStep(index)
}
// Progress automatically divided evenly across steps
// Automatically calls setComplete() when done
```

## Complete Examples

### Example 1: Basic Manual Tracking

```swift
func generateAudio(_ element: GuionElementModel) async {
    let tracker = element.progressTracker(using: progressState)

    do {
        tracker.setProgress(0.0, message: "Preparing...")
        let text = element.elementText

        tracker.setProgress(0.3, message: "Generating audio...")
        let audio = try await ttsService.generate(text)

        tracker.setProgress(0.9, message: "Saving...")
        try await save(audio)

        tracker.setComplete(message: "Done!")
    } catch {
        tracker.setError(error)
    }
}
```

### Example 2: Using withProgress

```swift
func generateAudio(_ element: GuionElementModel) async {
    let tracker = element.progressTracker(using: progressState)

    do {
        let audio = try await tracker.withProgress(
            startMessage: "Generating audio...",
            completeMessage: "Audio generated!"
        ) { updateProgress in
            updateProgress(0.1, "Preparing...")
            let text = element.elementText

            updateProgress(0.3, "Calling TTS service...")
            let audio = try await ttsService.generate(text)

            updateProgress(0.9, "Saving...")
            try await save(audio)

            return audio
        }

        print("Generated \(audio.count) bytes")
    } catch {
        print("Failed: \(error)")
    }
}
```

### Example 3: Using withSteps

```swift
func processElement(_ element: GuionElementModel) async {
    let tracker = element.progressTracker(using: progressState)

    try? await tracker.withSteps([
        "Analyzing content...",
        "Processing text...",
        "Generating output...",
        "Saving results..."
    ]) { index, step in
        switch index {
        case 0:
            try await analyzeContent(element)
        case 1:
            try await processText(element)
        case 2:
            try await generateOutput(element)
        case 3:
            try await saveResults(element)
        default:
            break
        }
    }
}
```

### Example 4: With Progress Callbacks

```swift
func generateWithCallbacks(_ element: GuionElementModel) async {
    let tracker = element.progressTracker(using: progressState)

    tracker.setProgress(0.0, message: "Starting...")

    let audio = try await ttsService.generate(
        text: element.elementText,
        onProgress: { progress in
            Task { @MainActor in
                tracker.setProgress(progress, message: "Generating...")
            }
        }
    )

    tracker.setComplete(message: "Done!")
}
```

### Example 5: Querying Progress State

```swift
struct ElementStatusView: View {
    let element: GuionElementModel
    @Environment(ElementProgressState.self) private var progressState

    var body: some View {
        VStack {
            // Using tracker
            let tracker = element.progressTracker(using: progressState)

            if tracker.hasVisibleProgress {
                if let progress = tracker.currentProgress {
                    ProgressView(value: progress.progress)
                    Text(progress.message ?? "In progress...")
                }
            } else {
                Text("No active operations")
            }

            // Or using element directly
            if element.hasVisibleProgress(in: progressState) {
                Text("Element is busy")
            }
        }
    }
}
```

## Integration with Buttons

### Button Template

```swift
struct MyElementButton: View {
    let element: GuionElementModel
    @Environment(ElementProgressState.self) private var progressState

    var body: some View {
        Button("Do Something") {
            Task {
                await performAction()
            }
        }
    }

    private func performAction() async {
        let tracker = element.progressTracker(using: progressState)

        do {
            try await tracker.withProgress(
                startMessage: "Processing...",
                completeMessage: "Complete!"
            ) { updateProgress in
                updateProgress(0.5, "Working...")
                try await doWork()
            }
        } catch {
            print("Failed: \(error)")
        }
    }
}
```

## API Reference

### ElementProgressTracker

```swift
@MainActor
public struct ElementProgressTracker {
    // Progress Operations
    func setProgress(_ progress: Double, message: String? = nil)
    func setComplete(message: String? = nil)
    func setError(_ error: Error)
    func clearProgress()

    // Queries
    var hasVisibleProgress: Bool
    var currentProgress: ElementProgress?

    // Convenience Methods
    func withProgress<T>(
        startMessage: String = "Starting...",
        completeMessage: String = "Complete!",
        _ operation: (_ updateProgress: @Sendable @escaping (Double, String?) -> Void) async throws -> T
    ) async throws -> T

    func withSteps(
        _ steps: [String],
        operation: @escaping (Int, String) async throws -> Void
    ) async throws
}
```

### GuionElementModel Extension

```swift
extension GuionElementModel {
    @MainActor
    func progressTracker(using state: ElementProgressState) -> ElementProgressTracker

    @MainActor
    func hasVisibleProgress(in state: ElementProgressState) -> Bool

    @MainActor
    func currentProgress(in state: ElementProgressState) -> ElementProgress?
}
```

## Thread Safety

All methods are `@MainActor` isolated, ensuring thread-safe UI updates. The tracker automatically handles main actor isolation for progress callbacks in `withProgress`.

## Error Handling

### Automatic (Recommended)

Use `withProgress` for automatic error handling:

```swift
try await tracker.withProgress(...) { updateProgress in
    try await riskyOperation()
}
// Errors automatically reported via setError()
```

### Manual

Handle errors yourself:

```swift
do {
    try await riskyOperation()
    tracker.setComplete()
} catch {
    tracker.setError(error)
}
```

## Best Practices

1. **Always get fresh tracker**: Get the tracker when you need it, don't store it as a property
2. **Use convenience methods**: `withProgress` and `withSteps` handle errors and completion automatically
3. **Provide messages**: Help users understand what's happening
4. **Handle errors**: Always either use `withProgress` or manually catch and report errors
5. **Don't clear manually**: Let auto-hide do its job (unless you have a specific reason)

## Common Patterns

### Pattern: Long-Running Operation

```swift
let tracker = element.progressTracker(using: progressState)
try await tracker.withProgress(
    startMessage: "Processing...",
    completeMessage: "Done!"
) { updateProgress in
    for i in 0..<10 {
        updateProgress(Double(i) / 10.0, "Step \(i+1)/10...")
        try await processChunk(i)
    }
}
```

### Pattern: Multi-Stage Pipeline

```swift
let tracker = element.progressTracker(using: progressState)
try await tracker.withSteps([
    "Stage 1: Analysis",
    "Stage 2: Processing",
    "Stage 3: Generation",
    "Stage 4: Finalization"
]) { stage, description in
    try await performStage(stage)
}
```

### Pattern: Conditional Progress

```swift
let tracker = element.progressTracker(using: progressState)

if element.elementType == .dialogue {
    tracker.setProgress(0.0, message: "Generating audio...")
    try await generateAudio(element)
    tracker.setComplete()
}
```

## See Also

- `UI/ElementProgress/ElementProgressTracker.swift` - Implementation
- `UI/ElementProgress/README.md` - Component overview
- `UI/Examples/ElementProgressTrackerExamples.swift` - Working examples
- `Docs/PROGRESS_BARS.md` - Progress bars documentation
- `.claude/skills/add-guion-element-button.md` - Pattern 6: Progress Tracking
