# Import and Export Fountain Files

This skill helps you import and export Fountain format screenplay files (.fountain) using SwiftCompartido's GuionParsedElementCollection and FountainWriter.

## What You'll Add

Fountain support provides:
- **Import**: Parse .fountain files into structured screenplay elements
- **Export**: Convert screenplay data back to Fountain format
- **Progress tracking**: Optional progress reporting for long files
- **Format preservation**: Maintains scene numbers, notes, and formatting

## Fountain Format Overview

Fountain is a plain text markup language for writing screenplays. It's human-readable and supported by most screenwriting software.

Example Fountain syntax:
```
INT. COFFEE SHOP - DAY

SARAH walks in and spots JOHN at a table.

SARAH
Hey! Long time no see.

JOHN
(surprised)
Sarah? Is that really you?
```

## Importing Fountain Files

### Basic Import

```swift
import SwiftCompartido

func importFountain(from url: URL) async throws -> GuionParsedElementCollection {
    // Simple import - synchronous
    let screenplay = try GuionParsedElementCollection(file: url.path)
    return screenplay
}

// Or from string
func importFountainString(_ text: String) async throws -> GuionParsedElementCollection {
    let screenplay = try await GuionParsedElementCollection(string: text)
    return screenplay
}
```

### Import With Progress Tracking

```swift
import SwiftCompartido

func importFountainWithProgress(from url: URL) async throws -> GuionParsedElementCollection {
    let progress = OperationProgress(totalUnits: nil) { update in
        print("\(update.description)")
    }

    let screenplay = try await GuionParsedElementCollection(
        file: url.path,
        progress: progress
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

struct FountainImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var importedDocument: GuionDocumentModel?
    @State private var importError: Error?

    // Define Fountain UTType
    static let fountainType = UTType(filenameExtension: "fountain")!

    var body: some View {
        VStack {
            Button("Import Fountain File") {
                showFilePicker = true
            }
            .disabled(isImporting)

            if isImporting {
                ProgressView("Importing...")
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [Self.fountainType]
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    await importFountainFile(from: url)
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

    private func importFountainFile(from url: URL) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Parse Fountain file
            let screenplay = try await GuionParsedElementCollection(
                file: url.path
            )

            // Convert to SwiftData
            let document = await GuionDocumentModel.from(screenplay, in: modelContext)
            document.title = url.deletingPathExtension().lastPathComponent
            document.setSourceFile(url)

            try modelContext.save()
            importedDocument = document

        } catch {
            importError = error
        }
    }
}
```

## Exporting Fountain Files

### Basic Export

```swift
import SwiftCompartido

func exportToFountain(screenplay: GuionParsedElementCollection, to url: URL) throws {
    let fountainWriter = FountainWriter(guionParsedElementCollection: screenplay)
    let fountainText = fountainWriter.write()

    try fountainText.write(to: url, atomically: true, encoding: .utf8)
}
```

### Export From SwiftData Document

```swift
import SwiftCompartido
import SwiftData

func exportDocument(
    _ document: GuionDocumentModel,
    to url: URL,
    modelContext: ModelContext
) async throws {
    // Convert SwiftData document to GuionParsedElementCollection
    let screenplay = await document.toGuionParsedElementCollection(context: modelContext)

    // Write to Fountain format
    let writer = FountainWriter(guionParsedElementCollection: screenplay)
    let fountainText = writer.write()

    try fountainText.write(to: url, atomically: true, encoding: .utf8)
}
```

### SwiftUI Export View

```swift
import SwiftUI
import SwiftCompartido
import SwiftData
import UniformTypeIdentifiers

struct FountainExportView: View {
    let document: GuionDocumentModel
    @Environment(\.modelContext) private var modelContext
    @State private var showExporter = false
    @State private var isExporting = false
    @State private var exportError: Error?

    static let fountainType = UTType(filenameExtension: "fountain")!

    var body: some View {
        Button("Export as Fountain") {
            showExporter = true
        }
        .disabled(isExporting)
        .fileExporter(
            isPresented: $showExporter,
            document: FountainExportDocument(
                document: document,
                modelContext: modelContext
            ),
            contentType: Self.fountainType,
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
struct FountainExportDocument: FileDocument {
    let document: GuionDocumentModel
    let modelContext: ModelContext

    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "fountain")!]
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

        // Generate Fountain text
        let writer = FountainWriter(guionParsedElementCollection: screenplay)
        let fountainText = writer.write()

        guard let data = fountainText.data(using: .utf8) else {
            throw NSError(domain: "Export", code: 500)
        }

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

struct FountainDocumentManager: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var documents: [GuionDocumentModel]
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var selectedDocument: GuionDocumentModel?

    static let fountainType = UTType(filenameExtension: "fountain")!

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
                    }
                }
                .onDelete(perform: deleteDocuments)
            }
            .navigationTitle("Fountain Documents")
            .toolbar {
                Button {
                    showImporter = true
                } label: {
                    Label("Import", systemImage: "doc.badge.plus")
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [Self.fountainType]
            ) { result in
                if case .success(let url) = result {
                    Task {
                        await importFountain(from: url)
                    }
                }
            }
            .fileExporter(
                isPresented: $showExporter,
                document: selectedDocument.map { doc in
                    FountainExportDocument(document: doc, modelContext: modelContext)
                },
                contentType: Self.fountainType,
                defaultFilename: selectedDocument?.title ?? "Screenplay"
            ) { _ in }
        }
    }

    private func importFountain(from url: URL) async {
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let screenplay = try await GuionParsedElementCollection(file: url.path)
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

## Parser Options

GuionParsedElementCollection supports two parser types:

### Fast Parser (Default)

```swift
// Fast parser - recommended for most use cases
let screenplay = try GuionParsedElementCollection(
    file: path,
    parser: .fast  // Default if omitted
)
```

### Legacy Parser

```swift
// Legacy parser - for backward compatibility
let screenplay = try GuionParsedElementCollection(
    file: path,
    parser: .legacy
)
```

The fast parser is recommended for all new code - it provides better performance and more accurate element detection.

## Fountain Format Features

SwiftCompartido supports the full Fountain specification:

✅ **Supported Elements:**
- Scene headings (INT./EXT.)
- Action lines
- Character names
- Dialogue
- Parentheticals
- Transitions
- Section headings (# Act One)
- Synopsis lines (= Story beats)
- Notes (/* ... */)
- Boneyard (/* ... */)
- Page breaks (===)
- Dual dialogue
- Centered text (> centered <)
- Lyrics (~)

✅ **Formatting:**
- Bold (**text**)
- Italic (*text*)
- Underline (_text_)
- Title page metadata
- Scene numbers (#1#)

## Error Handling

```swift
func safeImportFountain(from url: URL) async -> Result<GuionParsedElementCollection, Error> {
    do {
        let screenplay = try await GuionParsedElementCollection(file: url.path)
        return .success(screenplay)
    } catch {
        return .failure(NSError(domain: "Import", code: 500, userInfo: [
            NSLocalizedDescriptionKey: "Failed to parse Fountain file: \(error.localizedDescription)"
        ]))
    }
}
```

## Performance

- **Small scripts** (20-40 pages): <1 second
- **Medium scripts** (80-120 pages): 1-3 seconds
- **Large scripts** (150+ pages): 3-5 seconds

Export is nearly instantaneous (<1 second for any size).

## Round-Trip Fidelity

Importing and then exporting a Fountain file preserves:
- ✅ All element types and formatting
- ✅ Scene numbers
- ✅ Section structure
- ✅ Notes and comments
- ⚠️ Exact whitespace/line breaks may differ (semantically equivalent)

## Troubleshooting

### Import Fails With Parse Error
- **Cause**: Invalid Fountain syntax
- **Solution**: Validate Fountain file with another app (Highland, Final Draft)

### Missing Elements After Import
- **Cause**: Non-standard formatting or syntax
- **Solution**: Review Fountain specification at fountain.io

### Export Loses Formatting
- **Cause**: SwiftData model missing element data
- **Solution**: Ensure `document.sortedElements` contains all elements

### Characters in Wrong Case
- **Cause**: Fountain requires uppercase character names
- **Solution**: FountainWriter automatically uppercases character names

## Related Documentation

- `GuionParsedElementCollection.swift` - Main screenplay container
- `FountainParser.swift` - Fountain parsing logic
- `FountainWriter.swift` - Fountain export logic
- `GuionDocumentModel.swift` - SwiftData document model
- `SOURCE_FILE_TRACKING.md` - Source file update detection
- Fountain specification: https://fountain.io/syntax
