# Integrate Generated Content UI

This skill helps you integrate the GeneratedContentListView component into a SwiftUI application.

## What You'll Add

The GeneratedContentListView provides a master-detail interface for browsing AI-generated content (text, audio, images, videos, embeddings) with:
- MIME type filtering (All, Text, Audio, Image, Video, Embedding)
- Preview pane showing selected item with appropriate viewer
- Automatic audio playback when selecting audio items
- Content sorted by screenplay order (chapterIndex, orderIndex)

## Prerequisites

Before integrating, ensure:
1. You have a SwiftUI app with SwiftData configured
2. You have a `GuionDocumentModel` instance available
3. You have access to a `StorageAreaReference` (optional, for file-based content)

## Integration Steps

### Step 1: Add AudioPlayerManager to Your View Hierarchy

Add the AudioPlayerManager as a StateObject at the root of your view hierarchy:

```swift
import SwiftUI
import SwiftCompartido

@main
struct MyApp: App {
    @StateObject private var audioPlayer = AudioPlayerManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioPlayer)
        }
    }
}
```

### Step 2: Create a View with GeneratedContentListView

In the view where you want to display generated content:

```swift
import SwiftUI
import SwiftCompartido

struct GeneratedContentBrowserView: View {
    let document: GuionDocumentModel
    let storageArea: StorageAreaReference?

    // AudioPlayerManager comes from environment
    @EnvironmentObject private var audioPlayer: AudioPlayerManager

    var body: some View {
        GeneratedContentListView(
            document: document,
            storageArea: storageArea
        )
        .navigationTitle("Generated Content")
    }
}
```

### Step 3: Pass the Document and Storage Area

When navigating to your generated content view:

```swift
NavigationLink("View Generated Content") {
    GeneratedContentBrowserView(
        document: selectedDocument,
        storageArea: storageAreaForDocument(selectedDocument)
    )
}
```

## Common Patterns

### Pattern 1: Document-Based App

For a document-based app where each document has its own storage:

```swift
struct DocumentView: View {
    let document: GuionDocumentModel
    @StateObject private var audioPlayer = AudioPlayerManager()

    var storageArea: StorageAreaReference? {
        guard let bundleURL = document.bundleURL else { return nil }
        return .inBundle(requestID: document.id, bundleURL: bundleURL)
    }

    var body: some View {
        TabView {
            // Screenplay tab
            GuionViewer(document: document)
                .tabItem { Label("Screenplay", systemImage: "doc.text") }

            // Generated content tab
            GeneratedContentListView(
                document: document,
                storageArea: storageArea
            )
            .environmentObject(audioPlayer)
            .tabItem { Label("Generated", systemImage: "sparkles") }
        }
    }
}
```

### Pattern 2: Temporary Storage

For temporary content during processing:

```swift
struct ContentGenerationView: View {
    let document: GuionDocumentModel
    @State private var processingID = UUID()
    @EnvironmentObject private var audioPlayer: AudioPlayerManager

    var storageArea: StorageAreaReference {
        .temporary(requestID: processingID)
    }

    var body: some View {
        VStack {
            // Generation controls
            Button("Generate Content") {
                Task {
                    await generateContent()
                }
            }

            // View generated content
            GeneratedContentListView(
                document: document,
                storageArea: storageArea
            )
        }
    }

    func generateContent() async {
        // Your content generation logic
        try? storageArea.createDirectoryIfNeeded()
        // ... generate and save content
    }
}
```

### Pattern 3: No Storage Area (In-Memory Only)

For content stored entirely in-memory (small text, embeddings):

```swift
GeneratedContentListView(
    document: document,
    storageArea: nil  // Only in-memory content will be accessible
)
```

## Accessing Generated Content Programmatically

You can also access the underlying data without the UI:

```swift
// Get all generated content in screenplay order
let allContent = document.sortedElementGeneratedContent

// Filter by MIME type
let audioContent = document.sortedElementGeneratedContent(mimeTypePrefix: "audio/")
let imageContent = document.sortedElementGeneratedContent(mimeTypePrefix: "image/")

// Filter by element type
let dialogueAudio = document.sortedElementGeneratedContent(for: .dialogue)
    .filter { $0.mimeType.hasPrefix("audio/") }
```

## Troubleshooting

### Audio Doesn't Play
- Ensure `AudioPlayerManager` is provided as an environment object
- Check that `storageArea` is not nil for file-based audio
- Verify audio files exist at the expected URLs

### Content Not Showing
- Verify that `TypedDataStorage` records are attached to elements via `element.generatedContent`
- Check that elements have `owningElement` relationship set
- Ensure content has proper MIME types set

### Missing Files
- For file-based content, ensure `StorageAreaReference` points to correct directory
- Check that `fileReference.fileURL(in:)` returns valid paths
- Verify files weren't deleted or moved

### Performance Issues
- For large documents (100+ elements), content access is still <100ms
- Consider pagination if displaying thousands of items
- Use MIME type filtering to reduce displayed items

## Example: Complete Integration

Here's a complete example showing document browsing with generated content:

```swift
import SwiftUI
import SwiftCompartido
import SwiftData

struct DocumentBrowserView: View {
    @Query private var documents: [GuionDocumentModel]
    @State private var selectedDocument: GuionDocumentModel?
    @StateObject private var audioPlayer = AudioPlayerManager()

    var body: some View {
        NavigationSplitView {
            // Document list
            List(documents, selection: $selectedDocument) { document in
                Text(document.title ?? "Untitled")
            }
            .navigationTitle("Documents")
        } detail: {
            if let document = selectedDocument {
                DocumentDetailView(document: document)
                    .environmentObject(audioPlayer)
            } else {
                Text("Select a document")
            }
        }
    }
}

struct DocumentDetailView: View {
    let document: GuionDocumentModel
    @EnvironmentObject private var audioPlayer: AudioPlayerManager

    var storageArea: StorageAreaReference? {
        guard let bundleURL = document.bundleURL else { return nil }
        return .inBundle(requestID: document.id, bundleURL: bundleURL)
    }

    var body: some View {
        TabView {
            GuionViewer(document: document)
                .tabItem { Label("Script", systemImage: "doc.text") }

            GeneratedContentListView(
                document: document,
                storageArea: storageArea
            )
            .tabItem { Label("Generated", systemImage: "sparkles") }
        }
    }
}
```

## Next Steps

After integration, you can:
1. Customize the view with additional toolbar items
2. Add export functionality for generated content
3. Implement batch operations (delete, export multiple items)
4. Add search/filtering beyond MIME types
5. Create custom detail views for specific content types

## Related Documentation

- `GeneratedContentListView.swift` - Main UI component
- `TypedDataDetailView.swift` - Content detail viewer
- `TypedDataRowView.swift` - List row component
- `GuionDocumentModel.swift` - Document model with sortedElementGeneratedContent
- `AudioPlayerManager.swift` - Audio playback manager
- `StorageAreaReference.swift` - File storage management
