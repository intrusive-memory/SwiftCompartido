# Add Button to GuionElementsList Row

## Skill Overview

This skill guides you through adding a custom button to GuionElementsList rows where each button has access to its row's GuionElementModel. This pattern enables interactive features like generating audio, adding notes, or performing actions on screenplay elements.

## When to Use This Skill

- Adding interactive buttons to screenplay element rows (generate audio, add notes, etc.)
- Creating actions that need access to element data (text, type, ID)
- Associating generated content (audio, images) with specific elements
- Building custom UI controls for screenplay elements

## Pattern Overview

```swift
// 1. Create a button view that takes a GuionElementModel
struct MyElementButton: View {
    let element: GuionElementModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Button {
            Task {
                await performAction(on: element)
            }
        } label: {
            Image(systemName: "star.circle")
        }
    }

    private func performAction(on element: GuionElementModel) async {
        // Access element properties: element.elementText, element.elementType, etc.
        // Perform your action here
    }
}

// 2. Use it with GuionElementsList
GuionElementsList(document: screenplay) { element in
    MyElementButton(element: element)
}
```

## Step-by-Step Implementation

### Step 1: Create the Button View File

Create a new file in `Sources/SwiftCompartido/UI/ElementButtons/`

```swift
//
//  [YourButton]ElementButton.swift
//  SwiftCompartido
//
//  [Description of what this button does]
//

import SwiftUI
import SwiftData

/// Button for [action description]
///
/// This button [explain what it does and when to use it]
public struct [YourButton]ElementButton: View {
    let element: GuionElementModel
    @Environment(\.modelContext) private var modelContext

    // Add state for UI feedback if needed
    @State private var isProcessing = false
    @State private var errorMessage: String?

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        Button {
            Task {
                await performAction()
            }
        } label: {
            // Your button UI
            if isProcessing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "your.icon")
            }
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .help("Tooltip text")
    }

    private func performAction() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            // Access element data
            let text = element.elementText
            let type = element.elementType

            // Perform your action
            // ...

            // Save if needed
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    // Create mock element for preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: GuionElementModel.self,
        configurations: config
    )

    let element = GuionElementModel(
        elementText: "Sample dialogue text",
        elementType: .dialogue,
        orderIndex: 1
    )
    container.mainContext.insert(element)

    return [YourButton]ElementButton(element: element)
        .modelContainer(container)
        .padding()
}
```

### Step 2: Use with GuionElementsList

```swift
// In your view where you use GuionElementsList
GuionElementsList(document: screenplay) { element in
    [YourButton]ElementButton(element: element)
        .frame(width: 50)
}

// Or combine multiple buttons
GuionElementsList(document: screenplay) { element in
    HStack(spacing: 8) {
        GenerateAudioButton(element: element)
        AddNoteButton(element: element)
        MoreActionsButton(element: element)
    }
    .frame(width: 150)
}
```

## Common Patterns

### Pattern 1: Generate and Store AI Content

```swift
private func generateContent() async {
    let requestID = UUID()

    // 1. Access element data
    let text = element.elementText
    let type = element.elementType

    // 2. Generate content (replace with your service)
    let generatedData = try await yourService.generate(text)

    // 3. Create SwiftData record
    let record = TypedDataStorage(
        id: requestID,
        providerId: "your-provider",
        requestorID: "service.id",
        mimeType: "audio/mpeg",  // or "image/png", "text/plain", etc.
        binaryValue: generatedData,
        prompt: "Generate for: \(text.prefix(50))",
        // Add type-specific metadata
        audioFormat: "mp3",
        voiceID: "default",
        voiceName: "Default Voice"
    )

    // 4. Associate with element
    if element.generatedContent == nil {
        element.generatedContent = []
    }
    element.generatedContent?.append(record)

    // 5. Save to SwiftData
    modelContext.insert(record)
    try modelContext.save()
}
```

### Pattern 2: Generate and Store in File (Phase 6 - Large Files)

```swift
private func generateContentWithFileStorage() async {
    let requestID = UUID()
    let text = element.elementText

    // 1. Generate content
    let data = try await yourService.generate(text)

    // 2. Create storage area reference
    let storage = StorageAreaReference.temporary(requestID: requestID)

    // 3. Create TypedDataStorage record
    let record = TypedDataStorage(
        id: requestID,
        providerId: "your-provider",
        requestorID: "service.id",
        mimeType: "audio/mpeg",
        prompt: "Generate audio",
        audioFormat: "mp3"
    )

    // 4. Save to file (creates file reference automatically)
    try record.saveBinary(
        data,
        to: storage,
        fileName: "element_\(element.persistentModelID.hashValue).mp3",
        mode: .local
    )

    // 5. Associate and save
    if element.generatedContent == nil {
        element.generatedContent = []
    }
    element.generatedContent?.append(record)
    modelContext.insert(record)
    try modelContext.save()
}
```

### Pattern 3: Check for Existing Content

```swift
private var hasExistingAudio: Bool {
    guard let content = element.generatedContent else { return false }
    return content.contains { $0.mimeType.hasPrefix("audio/") }
}

private var audioCount: Int {
    element.generatedContent?.filter { $0.mimeType.hasPrefix("audio/") }.count ?? 0
}

// Use in body
var body: some View {
    Button {
        // ...
    } label: {
        if hasExistingAudio {
            Label("\(audioCount)", systemImage: "waveform.circle.fill")
        } else {
            Image(systemName: "waveform.circle")
        }
    }
}
```

### Pattern 4: Conditional Display Based on Element Type

```swift
var body: some View {
    // Only show button for dialogue and action
    if element.elementType == .dialogue || element.elementType == .action {
        Button {
            // ...
        } label: {
            Image(systemName: "speaker.wave.2")
        }
    } else {
        // Return EmptyView or placeholder
        Color.clear.frame(width: 0, height: 0)
    }
}
```

### Pattern 5: Loading States and Error Handling

```swift
@State private var isProcessing = false
@State private var errorMessage: String?
@State private var showError = false

var body: some View {
    Button {
        Task {
            await performAction()
        }
    } label: {
        if isProcessing {
            ProgressView()
                .controlSize(.small)
        } else {
            Image(systemName: "star.circle")
        }
    }
    .disabled(isProcessing)
    .alert("Error", isPresented: $showError) {
        Button("OK") { errorMessage = nil }
    } message: {
        Text(errorMessage ?? "Unknown error")
    }
}

private func performAction() async {
    isProcessing = true
    errorMessage = nil
    defer { isProcessing = false }

    do {
        try await yourAsyncOperation()
    } catch {
        errorMessage = error.localizedDescription
        showError = true
    }
}
```

### Pattern 6: Progress Tracking (Auto-Showing Progress Bars)

**Recommended: Using Element Progress Tracker**

```swift
@Environment(ElementProgressState.self) private var progressState

private func performActionWithProgress() async {
    // Get scoped progress tracker for this element
    let tracker = element.progressTracker(using: progressState)

    do {
        // Start progress - progress bar appears automatically
        tracker.setProgress(0.0, message: "Starting...")

        // Update progress as work proceeds
        tracker.setProgress(0.3, message: "Processing...")
        try await step1()

        tracker.setProgress(0.6, message: "Generating...")
        try await step2()

        tracker.setProgress(0.9, message: "Saving...")
        try await step3()

        // Complete - progress bar turns green and auto-hides after 2 seconds
        tracker.setComplete(message: "Done!")
    } catch {
        // Error - shows error message and auto-hides
        tracker.setError(error)
    }
}
```

**Alternative: Using Convenience Method**

```swift
private func performActionWithProgress() async {
    let tracker = element.progressTracker(using: progressState)

    do {
        try await tracker.withProgress(
            startMessage: "Processing...",
            completeMessage: "Complete!"
        ) { updateProgress in
            updateProgress(0.3, "Step 1...")
            try await step1()

            updateProgress(0.6, "Step 2...")
            try await step2()

            updateProgress(0.9, "Step 3...")
            try await step3()
        }
    } catch {
        // Errors handled automatically
    }
}
```

**Alternative: Step-Based Progress**

```swift
private func performActionWithSteps() async {
    let tracker = element.progressTracker(using: progressState)

    let steps = ["Analyzing...", "Processing...", "Generating...", "Saving..."]

    try? await tracker.withSteps(steps) { index, step in
        print("Executing: \(step)")
        try await performStep(index)
    }
}
```

**Note:** Progress bars appear as a second row below each element and automatically hide after completion. No additional UI setup needed!

## Element Data Available

The `GuionElementModel` provides access to:

```swift
// Identity
element.persistentModelID          // SwiftData unique identifier

// Content
element.elementText                // The text content
element.elementType                // .dialogue, .action, .sceneHeading, etc.

// Position
element.chapterIndex               // Chapter number (0-based)
element.orderIndex                 // Position within chapter

// Relationships
element.document                   // Parent GuionDocumentModel
element.generatedContent           // Associated AI content (audio, images, etc.)

// Scene-specific (for scene headings)
element.cachedSceneLocation        // Parsed location info
element.sceneNumber                // Scene number if present

// Type-specific flags
element.isCentered                 // For centered text
element.isDualDialogue             // For dual dialogue
```

## File Naming Convention

- **File location**: `Sources/SwiftCompartido/UI/ElementButtons/`
- **Naming pattern**: `[Action][Content]ElementButton.swift`
  - Examples: `GenerateAudioElementButton.swift`, `AddNoteElementButton.swift`
- **Struct name**: `[Action][Content]ElementButton`
  - Examples: `GenerateAudioElementButton`, `AddNoteElementButton`

## Complete Example: Generate Audio Button

```swift
//
//  GenerateAudioElementButton.swift
//  SwiftCompartido
//
//  Button to generate text-to-speech audio for screenplay elements
//

import SwiftUI
import SwiftData

/// Button to generate TTS audio for dialogue, character, and action elements
public struct GenerateAudioElementButton: View {
    let element: GuionElementModel
    @Environment(\.modelContext) private var modelContext

    @State private var isGenerating = false
    @State private var errorMessage: String?

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        Button {
            Task {
                await generateAudio()
            }
        } label: {
            if isGenerating {
                ProgressView()
                    .controlSize(.small)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: audioCount > 0 ? "waveform.circle.fill" : "waveform.circle")
                        .foregroundStyle(audioCount > 0 ? .blue : .primary)
                    if audioCount > 0 {
                        Text("\(audioCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isGenerating || !canGenerateAudio)
        .help(canGenerateAudio ? "Generate audio" : "Audio generation not available for \(element.elementType)")
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var canGenerateAudio: Bool {
        element.elementType == .dialogue ||
        element.elementType == .character ||
        element.elementType == .action
    }

    private var audioCount: Int {
        element.generatedContent?.filter { $0.mimeType.hasPrefix("audio/") }.count ?? 0
    }

    private func generateAudio() async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            let text = element.elementText

            // TODO: Replace with your actual TTS service
            let audioData = try await mockGenerateTTS(text: text)

            let audioRecord = TypedDataStorage(
                id: UUID(),
                providerId: "tts-provider",
                requestorID: "tts.default-voice",
                mimeType: "audio/mpeg",
                binaryValue: audioData,
                prompt: "Generate speech for: \(text.prefix(50))...",
                modelIdentifier: "tts-1",
                audioFormat: "mp3",
                durationSeconds: Double(audioData.count) / 16000,
                voiceID: "default",
                voiceName: "Default Voice"
            )

            if element.generatedContent == nil {
                element.generatedContent = []
            }
            element.generatedContent?.append(audioRecord)

            modelContext.insert(audioRecord)
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mockGenerateTTS(text: String) async throws -> Data {
        try await Task.sleep(for: .milliseconds(500))
        return Data(count: 1024)
    }
}
```

## Usage Examples

### Single Button
```swift
GuionElementsList(document: screenplay) { element in
    GenerateAudioElementButton(element: element)
        .frame(width: 50)
}
```

### Multiple Buttons
```swift
GuionElementsList(document: screenplay) { element in
    HStack(spacing: 8) {
        GenerateAudioElementButton(element: element)
        GenerateImageElementButton(element: element)
        AddNoteElementButton(element: element)
    }
    .frame(width: 180)
}
```

### Conditional Button
```swift
GuionElementsList(document: screenplay) { element in
    HStack(spacing: 8) {
        // Always show metadata
        Text("\(element.chapterIndex)")
            .font(.caption)

        // Only show audio button for dialogue
        if element.elementType == .dialogue {
            GenerateAudioElementButton(element: element)
        }
    }
}
```

## Testing Your Button

1. **Create a preview** with mock data (see Step 1 template)
2. **Test with GuionElementsList** in a preview
3. **Test interactions** (button press, loading states)
4. **Test error states** (network failure, invalid data)
5. **Test with different element types** (dialogue, action, etc.)

## Important Notes

- **Always use `@Environment(\.modelContext)`** for SwiftData operations
- **Use `Task { }`** for async operations from button handlers
- **Provide loading states** (`isProcessing`) for better UX
- **Handle errors gracefully** with alerts or inline messages
- **Set explicit frame widths** to maintain consistent layout
- **Add accessibility** via `.help()` and `.accessibilityLabel()`
- **Follow Phase 6 architecture** - use file storage for large content

## See Also

- `GuionElementsList.swift` - The list view component
- `GuionElementModel.swift` - Element model properties
- `TypedDataStorage.swift` - AI content storage model
- `Docs/GUION_ELEMENTS_LIST_COLUMNS.md` - Detailed column documentation
- `UI/Examples/GuionElementsListWithAudioButton.swift` - Complete working example
