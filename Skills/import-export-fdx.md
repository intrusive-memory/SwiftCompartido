# Import and Export FDX Files

This skill helps you import and export Final Draft FDX format screenplay files (.fdx) using SwiftCompartido's FDXParser and FDXDocumentWriter.

## What You'll Add

FDX support provides:
- **Import**: Parse Final Draft .fdx XML files into structured screenplay elements
- **Export**: Convert screenplay data back to FDX XML format
- **Progress tracking**: Optional progress reporting for long files
- **Full compatibility**: Works with Final Draft, Movie Magic Screenwriter, and other FDX-compatible apps

## FDX Format Overview

FDX (Final Draft XML) is the native file format for Final Draft screenwriting software. It's an XML-based format that stores:
- Screenplay content with precise formatting
- Scene numbers and properties
- Character names and dialogue
- Title page information
- Document settings and metadata

## Importing FDX Files

### Basic Import

```swift
import SwiftCompartido

func importFDX(from url: URL) async throws -> GuionParsedElementCollection {
    // Read FDX file
    let data = try Data(contentsOf: url)

    // Parse FDX
    let parser = FDXParser()
    let fdxDocument = try parser.parse(data: data, filename: url.lastPathComponent)

    // Convert to GuionParsedElementCollection
    let screenplay = GuionParsedElementCollection(fdxParsedDocument: fdxDocument)
    return screenplay
}
```

### Import With Progress Tracking

```swift
import SwiftCompartido

func importFDXWithProgress(from url: URL) async throws -> GuionParsedElementCollection {
    let data = try Data(contentsOf: url)

    // Create progress tracker
    let progress = OperationProgress(totalUnits: nil) { update in
        print("\(update.description)")
    }

    // Parse with progress
    let parser = FDXParser()
    let fdxDocument = try await parser.parse(
        data: data,
        filename: url.lastPathComponent,
        progress: progress
    )

    let screenplay = GuionParsedElementCollection(fdxParsedDocument: fdxDocument)
    return screenplay
}
```

### SwiftUI Import View

```swift
import SwiftUI
import SwiftCompartido
import SwiftData
import UniformTypeIdentifiers

struct FDXImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var importedDocument: GuionDocumentModel?
    @State private var importError: Error?

    // Define FDX UTType
    static let fdxType = UTType(filenameExtension: "fdx")!

    var body: some View {
        VStack {
            Button("Import Final Draft File") {
                showFilePicker = true
            }
            .disabled(isImporting)

            if isImporting {
                ProgressView("Importing FDX file...")
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [Self.fdxType]
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    await importFDXFile(from: url)
                }
            case .failure(let error):
                importError = error
            }
        }
        .alert("Import Error", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: {
            if let error = importError {
                Text(error.localizedDescription)
            }
        }
        .navigationDestination(item: $importedDocument) { document in
            GuionViewer(document: document)
        }
    }

    private func importFDXFile(from url: URL) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Read and parse FDX
            let data = try Data(contentsOf: url)
            let parser = FDXParser()
            let fdxDocument = try await parser.parse(
                data: data,
                filename: url.lastPathComponent
            )

            // Convert to screenplay
            let screenplay = GuionParsedElementCollection(fdxParsedDocument: fdxDocument)

            // Convert to SwiftData
            let document = await GuionDocumentModel.from(screenplay, in: modelContext)
            document.title = url.deletingPathExtension().lastPathComponent
            document.setSourceFile(url)

            try modelContext.save()
            importedDocument = document

        } catch FDXParserError.unableToParse {
            importError = NSError(domain: "Import", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Unable to parse FDX file. File may be corrupted or in unsupported format."
            ])
        } catch {
            importError = error
        }
    }
}
```

## Exporting FDX Files

### Basic Export

```swift
import SwiftCompartido

func exportToFDX(screenplay: GuionParsedElementCollection, to url: URL) throws {
    // Generate FDX XML
    let fdxData = FDXDocumentWriter.write(screenplay)

    // Write to file
    try fdxData.write(to: url, options: .atomic)
}
```

### Export From SwiftData Document

```swift
import SwiftCompartido
import SwiftData

func exportDocumentToFDX(
    _ document: GuionDocumentModel,
    to url: URL
) throws {
    // Generate FDX directly from SwiftData model
    let fdxData = FDXDocumentWriter.makeFDX(from: document)

    // Write to file
    try fdxData.write(to: url, options: .atomic)
}

// Or convert to GuionParsedElementCollection first
func exportDocumentToFDXViaScreenplay(
    _ document: GuionDocumentModel,
    to url: URL,
    modelContext: ModelContext
) async throws {
    // Convert to screenplay
    let screenplay = await document.toGuionParsedElementCollection(context: modelContext)

    // Generate FDX
    let fdxData = FDXDocumentWriter.write(screenplay)

    // Write to file
    try fdxData.write(to: url, options: .atomic)
}
```

### SwiftUI Export View

```swift
import SwiftUI
import SwiftCompartido
import SwiftData
import UniformTypeIdentifiers

struct FDXExportView: View {
    let document: GuionDocumentModel
    @Environment(\.modelContext) private var modelContext
    @State private var showExporter = false
    @State private var isExporting = false
    @State private var exportError: Error?

    static let fdxType = UTType(filenameExtension: "fdx")!

    var body: some View {
        Button("Export as Final Draft") {
            showExporter = true
        }
        .disabled(isExporting)
        .fileExporter(
            isPresented: $showExporter,
            document: FDXExportDocument(
                document: document,
                modelContext: modelContext
            ),
            contentType: Self.fdxType,
            defaultFilename: document.title ?? "Screenplay"
        ) { result in
            if case .failure(let error) = result {
                exportError = error
            }
        }
        .alert("Export Error", isPresented: .constant(exportError != nil)) {
            Button("OK") { exportError = nil }
        } message: {
            if let error = exportError {
                Text(error.localizedDescription)
            }
        }
    }
}

// Helper document type for file exporter
struct FDXExportDocument: FileDocument {
    let document: GuionDocumentModel
    let modelContext: ModelContext

    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "fdx")!]
    }

    init(document: GuionDocumentModel, modelContext: ModelContext) {
        self.document = document
        self.modelContext = modelContext
    }

    init(configuration: ReadConfiguration) throws {
        fatalError("Reading not supported")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Generate FDX directly from SwiftData model
        let fdxData = FDXDocumentWriter.makeFDX(from: document)
        return FileWrapper(regularFileWithContents: fdxData)
    }
}
```

## Complete Import/Export Example

```swift
import SwiftUI
import SwiftCompartido
import SwiftData
import UniformTypeIdentifiers

struct FDXDocumentManager: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var documents: [GuionDocumentModel]
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var selectedDocument: GuionDocumentModel?
    @State private var isProcessing = false
    @State private var progressMessage = ""

    static let fdxType = UTType(filenameExtension: "fdx")!

    var body: some View {
        NavigationStack {
            List {
                ForEach(documents) { document in
                    HStack {
                        NavigationLink {
                            GuionViewer(document: document)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(document.title ?? "Untitled")
                                    .font(.headline)
                                if let count = document.elements?.count {
                                    Text("\(count) elements")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Spacer()

                        Button {
                            selectedDocument = document
                            showExporter = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderless)
                        .disabled(isProcessing)
                    }
                }
                .onDelete(perform: deleteDocuments)
            }
            .navigationTitle("Final Draft Documents")
            .toolbar {
                Button {
                    showImporter = true
                } label: {
                    Label("Import", systemImage: "doc.badge.plus")
                }
                .disabled(isProcessing)
            }
            .overlay {
                if isProcessing {
                    VStack {
                        ProgressView()
                        Text(progressMessage)
                            .font(.caption)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(12)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [Self.fdxType]
            ) { result in
                if case .success(let url) = result {
                    Task {
                        await importFDX(from: url)
                    }
                }
            }
            .fileExporter(
                isPresented: $showExporter,
                document: selectedDocument.map { doc in
                    FDXExportDocument(document: doc, modelContext: modelContext)
                },
                contentType: Self.fdxType,
                defaultFilename: selectedDocument?.title ?? "Screenplay"
            ) { _ in }
        }
    }

    private func importFDX(from url: URL) async {
        isProcessing = true
        progressMessage = "Importing FDX file..."
        defer { isProcessing = false }

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let progress = OperationProgress(totalUnits: nil) { update in
                Task { @MainActor in
                    self.progressMessage = update.description
                }
            }

            let data = try Data(contentsOf: url)
            let parser = FDXParser()
            let fdxDocument = try await parser.parse(
                data: data,
                filename: url.lastPathComponent,
                progress: progress
            )

            let screenplay = GuionParsedElementCollection(fdxParsedDocument: fdxDocument)
            let document = await GuionDocumentModel.from(screenplay, in: modelContext)
            document.title = url.deletingPathExtension().lastPathComponent
            document.setSourceFile(url)

            try modelContext.save()
        } catch {
            print("Import failed: \(error)")
        }
    }

    private func deleteDocuments(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(documents[index])
        }
    }
}
```

## FDX XML Structure

An FDX file has this basic structure:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<FinalDraft DocumentType="Script" Template="No" Version="4">
  <Content>
    <Paragraph Type="Scene Heading">
      <SceneProperties Number="1"/>
      <Text>INT. COFFEE SHOP - DAY</Text>
    </Paragraph>
    <Paragraph Type="Action">
      <Text>SARAH enters and looks around.</Text>
    </Paragraph>
    <Paragraph Type="Character">
      <Text>SARAH</Text>
    </Paragraph>
    <Paragraph Type="Dialogue">
      <Text>Where is everyone?</Text>
    </Paragraph>
  </Content>
  <TitlePage>
    <Content>
      <Paragraph>
        <Text>My Screenplay</Text>
      </Paragraph>
    </Content>
  </TitlePage>
</FinalDraft>
```

## Supported Element Types

SwiftCompartido fully supports all FDX paragraph types:

✅ **Screenplay Elements:**
- Scene Heading (INT./EXT.)
- Action
- Character
- Dialogue
- Parenthetical
- Transition
- Shot
- General (general text)

✅ **Additional Elements:**
- Section Heading (Act/Sequence breaks)
- Synopsis
- Comment/Note
- Centered text

✅ **Properties:**
- Scene numbers
- Scene properties
- Title page metadata
- Document settings

## Two Export Methods

### Method 1: Direct from SwiftData (Faster)

```swift
// Export directly from GuionDocumentModel
let fdxData = FDXDocumentWriter.makeFDX(from: document)
try fdxData.write(to: url)
```

**Benefits:**
- Faster (no intermediate conversion)
- Preserves exact SwiftData ordering
- Less memory usage

### Method 2: Via GuionParsedElementCollection (More Flexible)

```swift
// Convert to screenplay first
let screenplay = await document.toGuionParsedElementCollection(context: modelContext)
let fdxData = FDXDocumentWriter.write(screenplay)
try fdxData.write(to: url)
```

**Benefits:**
- Can apply transformations to screenplay
- Easier to filter/modify elements
- Consistent with other export formats

## Error Handling

```swift
func safeImportFDX(from url: URL) async -> Result<GuionParsedElementCollection, Error> {
    do {
        let data = try Data(contentsOf: url)
        let parser = FDXParser()
        let fdxDocument = try await parser.parse(data: data, filename: url.lastPathComponent)
        let screenplay = GuionParsedElementCollection(fdxParsedDocument: fdxDocument)
        return .success(screenplay)
    } catch FDXParserError.unableToParse {
        return .failure(NSError(domain: "Import", code: 500, userInfo: [
            NSLocalizedDescriptionKey: "Unable to parse FDX file. XML may be malformed or corrupted."
        ]))
    } catch {
        return .failure(NSError(domain: "Import", code: 500, userInfo: [
            NSLocalizedDescriptionKey: "Failed to import FDX file: \(error.localizedDescription)"
        ]))
    }
}
```

## Performance

- **Import** (Small scripts, 20-40 pages): <1 second
- **Import** (Medium scripts, 80-120 pages): 1-3 seconds
- **Import** (Large scripts, 150+ pages): 3-5 seconds
- **Export**: Nearly instantaneous (<1 second for any size)

XML parsing is CPU-bound, so larger files take proportionally longer.

## Compatibility

✅ **Compatible with:**
- Final Draft 8, 9, 10, 11, 12, 13
- Movie Magic Screenwriter (FDX export)
- Fade In (FDX export)
- Any app that reads/writes FDX XML

✅ **Preserves:**
- All element types and text
- Scene numbers and properties
- Title page information
- Section structure
- Character names (automatically uppercased)

⚠️ **Limitations:**
- Inline formatting (bold/italic) not yet supported
- Dual dialogue requires special handling
- Some advanced Final Draft features (colors, bookmarks) not preserved

## Round-Trip Fidelity

Importing an FDX file and exporting it back preserves:
- ✅ All screenplay content and structure
- ✅ Scene numbers
- ✅ Element types and formatting
- ✅ Title page metadata
- ⚠️ XML structure may differ (semantically equivalent)
- ❌ Final Draft-specific features (colors, revisions, etc.)

## Troubleshooting

### "Unable to parse" Error
- **Cause**: Malformed XML or unsupported FDX version
- **Solution**: Open file in Final Draft, save again, try re-importing

### Missing Elements After Import
- **Cause**: Non-standard FDX paragraph types
- **Solution**: Check FDX XML structure, verify element types

### Export Opens Incorrectly in Final Draft
- **Cause**: Missing required XML attributes or structure
- **Solution**: Ensure all elements have proper types, report issue if persistent

### Scene Numbers Not Preserved
- **Cause**: Scene numbers stored in element metadata
- **Solution**: Ensure `sceneNumber` property is set on scene heading elements

### Characters Not Uppercase in Export
- **Cause**: Character names must be uppercase in FDX
- **Solution**: FDXDocumentWriter automatically uppercases, but verify input data

## Advanced: Custom FDX Transformations

You can modify the screenplay before export:

```swift
func exportWithCustomTransformations(
    document: GuionDocumentModel,
    to url: URL,
    modelContext: ModelContext
) async throws {
    // Convert to screenplay
    var screenplay = await document.toGuionParsedElementCollection(context: modelContext)

    // Apply transformations
    screenplay = screenplay.renumberScenes()  // Re-number all scenes
    screenplay = screenplay.filterNotes()     // Remove note elements

    // Export modified screenplay
    let fdxData = FDXDocumentWriter.write(screenplay)
    try fdxData.write(to: url)
}
```

## Related Documentation

- `FDXParser.swift` - FDX parsing implementation
- `FDXDocumentWriter.swift` - FDX export implementation
- `GuionParsedElementCollection.swift` - Main screenplay container
- `GuionDocumentModel.swift` - SwiftData document model
- `SOURCE_FILE_TRACKING.md` - Source file update detection
- Final Draft FDX specification: https://www.finaldraft.com/
