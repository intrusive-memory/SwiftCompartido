# Source File Tracking

GuionDocumentModel now tracks the original source file and can detect when it has been modified, allowing you to prompt users to re-import the latest version.

## Features

- ✅ **Security-scoped bookmarks** - Maintains access to files across app launches
- ✅ **Modification detection** - Detects when source file changes
- ✅ **Automatic bookmark refresh** - Updates stale bookmarks automatically
- ✅ **Status reporting** - Clear status enum for UI display

## New Properties

### GuionDocumentModel

```swift
/// Security-scoped bookmark to the original source file
public var sourceFileBookmark: Data?

/// Date when this document was last imported from source
public var lastImportDate: Date?

/// Modification date of source file at time of import
public var sourceFileModificationDate: Date?
```

## API

### Setting the Source File

When importing a screenplay, set the source file to create a bookmark:

```swift
let document = await GuionDocumentModel.from(screenplay, in: modelContext)

// Set the source file (creates security-scoped bookmark)
document.setSourceFile(sourceURL)

try modelContext.save()
```

### Checking for Updates

```swift
// Check if source file has been modified
if document.isSourceFileModified() {
    // Prompt user to re-import
    showUpdatePrompt()
}

// Or use the status enum for more detailed information
let status = document.sourceFileStatus()

switch status {
case .modified:
    // Source file has changed - prompt user to update
    showUpdateAlert()

case .upToDate:
    // All good, no action needed
    break

case .noSourceFile:
    // Document wasn't imported from a file
    break

case .fileNotAccessible:
    // Permissions issue
    showPermissionsError()

case .fileNotFound:
    // File was moved or deleted
    showFileNotFoundError()
}
```

### Resolving the Source File URL

```swift
// Get URL to the original source file
if let sourceURL = document.resolveSourceFileURL() {
    // Can now access the file
    let updatedData = try Data(contentsOf: sourceURL)
    // Re-import...
}
```

## Usage Patterns

### On App Launch

Check all documents for updates on app launch:

```swift
@MainActor
func checkForUpdates() async {
    let documents = try? modelContext.fetch(FetchDescriptor<GuionDocumentModel>())

    for document in documents ?? [] {
        if document.isSourceFileModified() {
            await showUpdateNotification(for: document)
        }
    }
}
```

### Periodic Checking

Use a timer to periodically check for updates:

```swift
Timer.publish(every: 300, on: .main, in: .common) // Check every 5 minutes
    .autoconnect()
    .sink { _ in
        Task {
            await checkForUpdates()
        }
    }
```

### User-Initiated Update

Let users manually check for updates:

```swift
Button("Check for Updates") {
    Task {
        let status = document.sourceFileStatus()

        if status == .modified {
            await reimportFromSource()
        } else {
            showAlert("Document is up to date")
        }
    }
}
```

### Re-importing from Source

```swift
@MainActor
func reimportFromSource(document: GuionDocumentModel) async throws {
    guard let sourceURL = document.resolveSourceFileURL() else {
        throw ImportError.sourceFileNotFound
    }

    // Start security-scoped access
    let accessing = sourceURL.startAccessingSecurityScopedResource()
    defer {
        if accessing {
            sourceURL.stopAccessingSecurityScopedResource()
        }
    }

    // Parse the updated file
    let screenplay = try await FountainParser.loadAndParse(
        fileURL: sourceURL,
        progress: nil
    )

    // Clear existing elements
    for element in document.elements {
        modelContext.delete(element)
    }
    document.elements.removeAll()

    // Import new elements
    for element in screenplay.elements {
        let newElement = GuionElementModel(from: element)
        newElement.document = document
        document.elements.append(newElement)
    }

    // Update source file metadata
    document.setSourceFile(sourceURL)

    try modelContext.save()
}
```

## SwiftUI Integration

### Update Alert

```swift
struct DocumentUpdateAlert: View {
    let document: GuionDocumentModel
    @State private var showingAlert = false

    var body: some View {
        VStack {
            GuionViewer(document: document)
        }
        .onAppear {
            checkForUpdates()
        }
        .alert("Update Available", isPresented: $showingAlert) {
            Button("Update Now") {
                Task {
                    await reimportFromSource()
                }
            }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text("The source file has been modified since this document was imported. Would you like to update to the latest version?")
        }
    }

    func checkForUpdates() {
        showingAlert = document.isSourceFileModified()
    }
}
```

### Status Badge

```swift
struct DocumentStatusBadge: View {
    let document: GuionDocumentModel

    var body: some View {
        let status = document.sourceFileStatus()

        if status.shouldPromptForUpdate {
            Label("Update Available", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(4)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}
```

### Document List with Status

```swift
struct DocumentListView: View {
    @Query private var documents: [GuionDocumentModel]

    var body: some View {
        List(documents) { document in
            NavigationLink {
                GuionViewer(document: document)
            } label: {
                HStack {
                    Text(document.filename ?? "Untitled")

                    Spacer()

                    DocumentStatusBadge(document: document)
                }
            }
        }
    }
}
```

## Source File Status Enum

```swift
public enum SourceFileStatus: Sendable {
    case noSourceFile          // No source file set
    case fileNotAccessible     // Cannot resolve bookmark
    case fileNotFound          // File moved/deleted
    case modified              // File has been updated
    case upToDate              // File is current

    var description: String { ... }
    var shouldPromptForUpdate: Bool { ... }
}
```

## Security Considerations

### Sandboxed Apps

For sandboxed macOS apps, you need:
1. **User-selected file access** - User must select the file via open panel
2. **Security-scoped bookmarks** - Required to maintain access

```swift
func importFile() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.fountainDocument]

    panel.begin { response in
        guard response == .OK, let url = panel.url else { return }

        Task { @MainActor in
            // Import the file
            let screenplay = try await FountainParser.loadAndParse(fileURL: url)
            let document = await GuionDocumentModel.from(screenplay, in: modelContext)

            // Create security-scoped bookmark
            document.setSourceFile(url)

            try modelContext.save()
        }
    }
}
```

### Accessing Bookmarked Files

Always use security-scoped resource access:

```swift
if let url = document.resolveSourceFileURL() {
    let accessing = url.startAccessingSecurityScopedResource()
    defer {
        if accessing {
            url.stopAccessingSecurityScopedResource()
        }
    }

    // Work with the file
    let data = try Data(contentsOf: url)
}
```

## Migration

### Existing Documents

Existing GuionDocumentModel instances will have:
- `sourceFileBookmark = nil`
- `lastImportDate = nil`
- `sourceFileModificationDate = nil`

To add source tracking to existing documents:

```swift
func addSourceTracking(to document: GuionDocumentModel, sourceURL: URL) {
    document.setSourceFile(sourceURL)
    try? modelContext.save()
}
```

## Performance

- ✅ **Lightweight** - Bookmarks are small (~200 bytes)
- ✅ **Fast** - Status checks are O(1) file system operations
- ✅ **Efficient** - Only checks when needed, not on every access

## Best Practices

1. **Set source on import** - Always call `setSourceFile()` when importing
2. **Check periodically** - Not on every view, but on launch and periodically
3. **User control** - Let users decide when to update, don't auto-update
4. **Handle errors** - File may be moved, deleted, or inaccessible
5. **Security-scoped access** - Always use proper resource access patterns

## Example: Complete Import Flow

```swift
@MainActor
func importScreenplay(from url: URL) async throws {
    // 1. Parse the screenplay
    let screenplay = try await FountainParser.loadAndParse(fileURL: url)

    // 2. Convert to SwiftData model
    let document = await GuionDocumentModel.from(screenplay, in: modelContext)

    // 3. Set source file (creates bookmark and records dates)
    document.setSourceFile(url)

    // 4. Save
    try modelContext.save()

    // Now document tracks the source file and can detect updates
}

@MainActor
func checkAndUpdate(document: GuionDocumentModel) async throws {
    let status = document.sourceFileStatus()

    switch status {
    case .modified:
        // Prompt user
        let shouldUpdate = await showUpdateDialog()

        if shouldUpdate {
            try await reimportFromSource(document: document)
        }

    case .upToDate:
        showMessage("Document is up to date")

    case .noSourceFile:
        showMessage("No source file tracking available")

    case .fileNotFound:
        showError("Source file not found")

    case .fileNotAccessible:
        showError("Cannot access source file")
    }
}
```

## Testing

```swift
func testSourceFileTracking() async throws {
    // Create a test file
    let testURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test.fountain")
    try "INT. TEST - DAY".write(to: testURL, atomically: true, encoding: .utf8)

    // Import
    let screenplay = try await FountainParser.loadAndParse(fileURL: testURL)
    let document = await GuionDocumentModel.from(screenplay, in: modelContext)
    document.setSourceFile(testURL)

    // Should be up to date
    XCTAssertEqual(document.sourceFileStatus(), .upToDate)
    XCTAssertFalse(document.isSourceFileModified())

    // Modify the file
    try "INT. TEST - NIGHT".write(to: testURL, atomically: true, encoding: .utf8)

    // Should now detect modification
    XCTAssertEqual(document.sourceFileStatus(), .modified)
    XCTAssertTrue(document.isSourceFileModified())
}
```
