# Import and Export Highland Files

This skill helps you import and export Highland format screenplay files (.highland) using SwiftCompartido's GuionParsedElementCollection with Highland extensions.

## What You'll Add

Highland support provides:
- **Import**: Parse .highland files (both ZIP bundles and plain text variants)
- **Export**: Create .highland bundles with TextBundle structure
- **Resources**: Optional character and outline JSON files
- **Format compatibility**: Full Highland 2 compatibility

## Highland Format Overview

Highland files (.highland) can be one of two formats:

1. **Highland ZIP Bundle** (Highland 2): A ZIP archive containing:
   - A TextBundle directory with the screenplay
   - Optional resources (characters.json, outline.json)
   - Metadata files

2. **Plain Text** (Highland 1): A plain Fountain text file with .highland extension

SwiftCompartido automatically detects which format and handles both correctly.

## Importing Highland Files

### Basic Import

```swift
import SwiftCompartido

func importHighland(from url: URL) throws -> GuionParsedElementCollection {
    // Automatically detects ZIP bundle vs plain text
    let screenplay = try GuionParsedElementCollection(highland: url)
    return screenplay
}
```

### Import With Parser Selection

```swift
import SwiftCompartido

func importHighlandWithParser(from url: URL) throws -> GuionParsedElementCollection {
    // Use specific parser
    let screenplay = try GuionParsedElementCollection(
        highland: url,
        parser: .fast  // or .legacy
    )
    return screenplay
}
```

### SwiftUI Import View

```swift
import SwiftUI
import SwiftCompartido
import SwiftData
import UniformTypeIdentifiers

struct HighlandImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var importedDocument: GuionDocumentModel?
    @State private var importError: Error?

    // Define Highland UTType
    static let highlandType = UTType(filenameExtension: "highland")!

    var body: some View {
        VStack {
            Button("Import Highland File") {
                showFilePicker = true
            }
            .disabled(isImporting)

            if isImporting {
                ProgressView("Importing Highland file...")
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [Self.highlandType]
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    await importHighlandFile(from: url)
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

    private func importHighlandFile(from url: URL) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Parse Highland file (auto-detects format)
            let screenplay = try GuionParsedElementCollection(highland: url)

            // Convert to SwiftData
            let document = await GuionDocumentModel.from(screenplay, in: modelContext)
            document.title = url.deletingPathExtension().lastPathComponent
            document.setSourceFile(url)

            try modelContext.save()
            importedDocument = document

        } catch HighlandError.noTextBundleFound {
            importError = NSError(domain: "Import", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "No TextBundle found in Highland file"
            ])
        } catch HighlandError.extractionFailed {
            importError = NSError(domain: "Import", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to extract Highland ZIP archive"
            ])
        } catch {
            importError = error
        }
    }
}
```

## Exporting Highland Files

### Basic Export

```swift
import SwiftCompartido

func exportToHighland(
    screenplay: GuionParsedElementCollection,
    destinationURL: URL,
    name: String
) throws -> URL {
    // Creates a .highland ZIP bundle
    let highlandURL = try screenplay.writeToHighland(
        destinationURL: destinationURL,
        name: name,
        includeResources: true  // Include characters.json and outline.json
    )

    return highlandURL
}
```

### Export Without Resources

```swift
import SwiftCompartido

func exportToHighlandMinimal(
    screenplay: GuionParsedElementCollection,
    destinationURL: URL,
    name: String
) throws -> URL {
    // Creates minimal Highland file without metadata
    let highlandURL = try screenplay.writeToHighland(
        destinationURL: destinationURL,
        name: name,
        includeResources: false  // No characters.json or outline.json
    )

    return highlandURL
}
```

### Export From SwiftData Document

```swift
import SwiftCompartido
import SwiftData

func exportDocumentToHighland(
    _ document: GuionDocumentModel,
    destinationURL: URL,
    name: String,
    modelContext: ModelContext
) async throws -> URL {
    // Convert SwiftData document to GuionParsedElementCollection
    let screenplay = await document.toGuionParsedElementCollection(context: modelContext)

    // Write to Highland format
    let highlandURL = try screenplay.writeToHighland(
        destinationURL: destinationURL,
        name: name,
        includeResources: true
    )

    return highlandURL
}
```

### SwiftUI Export View

```swift
import SwiftUI
import SwiftCompartido
import SwiftData
import UniformTypeIdentifiers

struct HighlandExportView: View {
    let document: GuionDocumentModel
    @Environment(\.modelContext) private var modelContext
    @State private var showExporter = false
    @State private var isExporting = false
    @State private var exportError: Error?

    static let highlandType = UTType(filenameExtension: "highland")!

    var body: some View {
        Button("Export as Highland") {
            showExporter = true
        }
        .disabled(isExporting)
        .fileExporter(
            isPresented: $showExporter,
            document: HighlandExportDocument(
                document: document,
                modelContext: modelContext
            ),
            contentType: Self.highlandType,
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
struct HighlandExportDocument: FileDocument {
    let document: GuionDocumentModel
    let modelContext: ModelContext

    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "highland")!]
    }

    init(document: GuionDocumentModel, modelContext: ModelContext) {
        self.document = document
        self.modelContext = modelContext
    }

    init(configuration: ReadConfiguration) throws {
        fatalError("Reading not supported")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Convert to screenplay
        let screenplay = Task {
            await document.toGuionParsedElementCollection(context: modelContext)
        }

        guard let screenplay = try? screenplay.value else {
            throw NSError(domain: "Export", code: 500)
        }

        // Create temporary directory for Highland export
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Export to Highland
        let highlandURL = try screenplay.writeToHighland(
            destinationURL: tempDir,
            name: document.title ?? "Screenplay",
            includeResources: true
        )

        // Read the created file
        let data = try Data(contentsOf: highlandURL)
        return FileWrapper(regularFileWithContents: data)
    }
}
```

## Complete Import/Export Example

```swift
import SwiftUI
import SwiftCompartido
import SwiftData
import UniformTypeIdentifiers

struct HighlandDocumentManager: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var documents: [GuionDocumentModel]
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var selectedDocument: GuionDocumentModel?
    @State private var isProcessing = false

    static let highlandType = UTType(filenameExtension: "highland")!

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
            .navigationTitle("Highland Documents")
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
                    ProgressView("Processing...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [Self.highlandType]
            ) { result in
                if case .success(let url) = result {
                    Task {
                        await importHighland(from: url)
                    }
                }
            }
            .fileExporter(
                isPresented: $showExporter,
                document: selectedDocument.map { doc in
                    HighlandExportDocument(document: doc, modelContext: modelContext)
                },
                contentType: Self.highlandType,
                defaultFilename: selectedDocument?.title ?? "Screenplay"
            ) { _ in }
        }
    }

    private func importHighland(from url: URL) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let screenplay = try GuionParsedElementCollection(highland: url)
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

## Highland Bundle Structure

When you export a Highland file, SwiftCompartido creates this structure:

```
MyScreenplay.highland (ZIP archive)
└── MyScreenplay.textbundle/
    ├── info.json                 # TextBundle metadata
    ├── text.fountain            # Screenplay content
    └── resources/               # Optional resources
        ├── characters.json      # Character list
        └── outline.json         # Outline structure
```

## Resource Files

### characters.json

Contains a list of all characters in the screenplay:

```json
{
  "characters": [
    {
      "name": "SARAH",
      "appearances": 12
    },
    {
      "name": "JOHN",
      "appearances": 8
    }
  ]
}
```

### outline.json

Contains the screenplay outline structure:

```json
{
  "outline": [
    {
      "title": "ACT ONE",
      "scenes": [
        {
          "heading": "INT. COFFEE SHOP - DAY",
          "page": 1
        }
      ]
    }
  ]
}
```

## Format Detection

SwiftCompartido automatically detects Highland file format:

```swift
// This works for both formats:

// Format 1: Highland 2 ZIP bundle
let screenplay1 = try GuionParsedElementCollection(highland: zipBundleURL)

// Format 2: Highland 1 plain text with .highland extension
let screenplay2 = try GuionParsedElementCollection(highland: plainTextURL)

// No manual format detection needed!
```

## Error Handling

```swift
func safeImportHighland(from url: URL) -> Result<GuionParsedElementCollection, Error> {
    do {
        let screenplay = try GuionParsedElementCollection(highland: url)
        return .success(screenplay)
    } catch HighlandError.noTextBundleFound {
        return .failure(NSError(domain: "Import", code: 404, userInfo: [
            NSLocalizedDescriptionKey: "Highland ZIP file is missing TextBundle"
        ]))
    } catch HighlandError.extractionFailed {
        return .failure(NSError(domain: "Import", code: 500, userInfo: [
            NSLocalizedDescriptionKey: "Failed to extract Highland ZIP archive"
        ]))
    } catch {
        return .failure(NSError(domain: "Import", code: 500, userInfo: [
            NSLocalizedDescriptionKey: "Failed to parse Highland file: \(error.localizedDescription)"
        ]))
    }
}
```

## Performance

- **Import** (ZIP bundles): 1-5 seconds depending on size
- **Import** (plain text): <1 second (same as Fountain)
- **Export**: 2-5 seconds (includes ZIP compression)

## Compatibility

✅ **Compatible with:**
- Highland 2 (macOS app)
- Highland for iOS
- Any app that supports TextBundle format
- Fountain-compatible editors (for plain text variant)

✅ **Preserves:**
- All Fountain formatting
- Scene numbers
- Notes and comments
- Section structure
- Character metadata (in resources)
- Outline structure (in resources)

## Troubleshooting

### "No TextBundle found" Error
- **Cause**: Highland ZIP is corrupted or has wrong structure
- **Solution**: Re-export from Highland app, or use plain Fountain instead

### "Extraction failed" Error
- **Cause**: Invalid ZIP archive
- **Solution**: Verify file is not corrupted, try re-downloading

### Import Works But Shows Wrong Content
- **Cause**: Multiple .fountain or .md files in TextBundle
- **Solution**: Highland should have only one content file

### Export Creates Large Files
- **Cause**: ZIP compression with resources
- **Solution**: Set `includeResources: false` to reduce file size

### Can't Open in Highland App
- **Cause**: Missing required TextBundle structure
- **Solution**: Ensure export completes successfully, check file permissions

## Related Documentation

- `GuionParsedScreenplay+Highland.swift` - Highland import/export implementation
- `GuionParsedElementCollection.swift` - Main screenplay container
- `GuionDocumentModel.swift` - SwiftData document model
- `SOURCE_FILE_TRACKING.md` - Source file update detection
- TextBundle specification: http://textbundle.org
- Highland app: https://highland2.app
