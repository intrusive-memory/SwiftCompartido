# Import PDF Screenplays

This skill helps you import screenplay PDF files into SwiftCompartido using the production-ready PDFScreenplayParser.

## What You'll Add

The PDFScreenplayParser provides complete PDF-to-screenplay conversion with:
- Automatic format detection for screenplay elements
- Three-phase parsing with progress reporting
- Support for movie scripts, TV pilots, and classic screenplays
- Conversion to structured GuionParsedElementCollection

## Prerequisites

Before importing PDFs:
1. PDF file must have embedded text (OCR not supported for scanned documents)
2. PDF must not be password-protected
3. Your target must support iOS 26.0+ or Mac Catalyst 26.0+
4. SwiftData configured in your app (if persisting to database)

## Platform Availability

```swift
@available(iOS 26.0, macCatalyst 26.0, *)
```

PDFScreenplayParser uses PDFKit, which requires these minimum platform versions.

## Basic Import

### Import Without Progress Tracking

```swift
import SwiftCompartido

@available(iOS 26.0, macCatalyst 26.0, *)
func importPDFScreenplay(from url: URL) async throws -> GuionParsedElementCollection {
    // Simple import - no progress tracking
    let screenplay = try await PDFScreenplayParser.parse(from: url)
    return screenplay
}
```

### Import With Progress Tracking

```swift
import SwiftCompartido

@available(iOS 26.0, macCatalyst 26.0, *)
func importPDFWithProgress(from url: URL) async throws -> GuionParsedElementCollection {
    // Create progress tracker
    let progress = OperationProgress(totalUnits: 100) { update in
        print("\(update.description) - \(Int((update.fractionCompleted ?? 0) * 100))%")
    }

    let screenplay = try await PDFScreenplayParser.parse(
        from: url,
        progress: progress
    )

    return screenplay
}
```

## SwiftUI Integration

### Basic PDF Import View

```swift
import SwiftUI
import SwiftCompartido
import SwiftData

@available(iOS 26.0, macCatalyst 26.0, *)
struct PDFImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isImporting = false
    @State private var showFilePicker = false
    @State private var importError: Error?
    @State private var importedDocument: GuionDocumentModel?

    var body: some View {
        VStack {
            Button("Import PDF Screenplay") {
                showFilePicker = true
            }
            .disabled(isImporting)

            if isImporting {
                ProgressView("Importing screenplay...")
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf]
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    await importPDF(from: url)
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

    private func importPDF(from url: URL) async {
        isImporting = true
        defer { isImporting = false }

        do {
            // Start accessing security-scoped resource
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Parse the PDF
            let screenplay = try await PDFScreenplayParser.parse(from: url)

            // Convert to SwiftData
            let document = await GuionDocumentModel.from(screenplay, in: modelContext)

            // Set source file for update tracking
            document.setSourceFile(url)

            try modelContext.save()
            importedDocument = document

        } catch {
            importError = error
        }
    }
}
```

### PDF Import With Progress Bar

```swift
import SwiftUI
import SwiftCompartido

@available(iOS 26.0, macCatalyst 26.0, *)
struct PDFImportProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var progressMessage = ""
    @State private var progressFraction = 0.0
    @State private var isImporting = false
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: 20) {
            Button("Import PDF Screenplay") {
                showFilePicker = true
            }
            .disabled(isImporting)

            if isImporting {
                VStack {
                    ProgressView(value: progressFraction) {
                        Text(progressMessage)
                    }
                    .progressViewStyle(.linear)

                    Text("\(Int(progressFraction * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf]
        ) { result in
            if case .success(let url) = result {
                Task {
                    await importWithProgress(from: url)
                }
            }
        }
    }

    private func importWithProgress(from url: URL) async {
        isImporting = true
        defer { isImporting = false }

        // Create progress tracker
        let progress = OperationProgress(totalUnits: 100) { update in
            Task { @MainActor in
                self.progressMessage = update.description
                self.progressFraction = update.fractionCompleted ?? 0.0
            }
        }

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Parse with progress
            let screenplay = try await PDFScreenplayParser.parse(
                from: url,
                progress: progress
            )

            // Convert to SwiftData
            _ = await GuionDocumentModel.from(screenplay, in: modelContext)
            try modelContext.save()

        } catch {
            print("Import failed: \(error)")
        }
    }
}
```

## Three-Phase Progress Workflow

The PDFScreenplayParser reports progress through three phases:

1. **Text Extraction (20%)**: Extracts text from PDF using PDFKit
2. **Fountain Conversion (60%)**: Converts extracted text to Fountain markup
3. **Screenplay Parsing (20%)**: Parses Fountain into structured elements

Example progress messages:
- "Extracting text from PDF..."
- "Converting to Fountain format..."
- "Parsing screenplay elements..."

## Error Handling

```swift
@available(iOS 26.0, macCatalyst 26.0, *)
func safeImportPDF(from url: URL) async -> Result<GuionParsedElementCollection, Error> {
    do {
        let screenplay = try await PDFScreenplayParser.parse(from: url)
        return .success(screenplay)
    } catch PDFScreenplayParserError.fileNotFound {
        return .failure(NSError(domain: "Import", code: 404, userInfo: [
            NSLocalizedDescriptionKey: "PDF file not found at path"
        ]))
    } catch PDFScreenplayParserError.unableToOpenPDF {
        return .failure(NSError(domain: "Import", code: 400, userInfo: [
            NSLocalizedDescriptionKey: "Unable to open PDF. File may be corrupted or password-protected."
        ]))
    } catch PDFScreenplayParserError.textExtractionFailed {
        return .failure(NSError(domain: "Import", code: 500, userInfo: [
            NSLocalizedDescriptionKey: "Failed to extract text from PDF. File may be scanned/OCR required."
        ]))
    } catch {
        return .failure(error)
    }
}
```

## Supported PDF Types

✅ **Supported:**
- Movie scripts (traditional feature film format)
- TV pilots (television screenplay format)
- Classic screenplays (1930s+ formatting)
- Modern PDF exports from Final Draft, Highland, Fade In, etc.

❌ **Not Supported:**
- Scanned PDFs without embedded text (OCR required)
- Password-protected PDFs
- Image-only PDFs

## Performance Characteristics

- **Small PDFs** (20-40 pages): <5 seconds
- **Medium PDFs** (80-120 pages): 10-20 seconds
- **Large PDFs** (150+ pages): 20-30 seconds

Tested with real-world screenplays including:
- Casablanca (1942) - 124 pages
- The Godfather (1972) - 163 pages
- Modern TV pilots - 60 pages

## Complete Example: Document-Based App

```swift
import SwiftUI
import SwiftCompartido
import SwiftData
import UniformTypeIdentifiers

@available(iOS 26.0, macCatalyst 26.0, *)
struct ScreenplayImporterApp: App {
    var body: some Scene {
        WindowGroup {
            DocumentListView()
        }
        .modelContainer(for: [GuionDocumentModel.self])
    }
}

@available(iOS 26.0, macCatalyst 26.0, *)
struct DocumentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var documents: [GuionDocumentModel]
    @State private var showImporter = false
    @State private var isImporting = false
    @State private var progressMessage = ""
    @State private var progressFraction = 0.0

    var body: some View {
        NavigationStack {
            List {
                ForEach(documents) { document in
                    NavigationLink {
                        GuionViewer(document: document)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(document.title ?? "Untitled")
                                .font(.headline)
                            if let elementCount = document.elements?.count {
                                Text("\(elementCount) elements")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteDocuments)
            }
            .navigationTitle("Screenplays")
            .toolbar {
                Button {
                    showImporter = true
                } label: {
                    Label("Import PDF", systemImage: "doc.badge.plus")
                }
            }
            .overlay {
                if isImporting {
                    VStack {
                        ProgressView(value: progressFraction) {
                            Text(progressMessage)
                        }
                        .frame(maxWidth: 300)
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.pdf]
            ) { result in
                if case .success(let url) = result {
                    Task {
                        await importPDF(from: url)
                    }
                }
            }
        }
    }

    private func importPDF(from url: URL) async {
        isImporting = true
        progressMessage = "Starting import..."
        progressFraction = 0.0

        defer { isImporting = false }

        let progress = OperationProgress(totalUnits: 100) { update in
            Task { @MainActor in
                self.progressMessage = update.description
                self.progressFraction = update.fractionCompleted ?? 0.0
            }
        }

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let screenplay = try await PDFScreenplayParser.parse(
                from: url,
                progress: progress
            )

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

## Troubleshooting

### "Unable to open PDF" Error
- **Cause**: PDF is password-protected or corrupted
- **Solution**: Remove password protection or use a different PDF

### "Text extraction failed" Error
- **Cause**: PDF is scanned (no embedded text)
- **Solution**: Use OCR software to convert to searchable PDF first

### "File not found" Error
- **Cause**: Invalid URL or file was moved/deleted
- **Solution**: Verify file exists and URL is correct

### Missing Platform Availability
- **Cause**: Using on unsupported platform
- **Solution**: Ensure iOS 26.0+ or Mac Catalyst 26.0+ target

### Slow Import Performance
- **Cause**: Very large PDF or complex formatting
- **Solution**: Normal for 150+ page scripts (20-30 seconds)

## Related Documentation

- `PDFScreenplayParser.swift` - PDF parsing implementation
- `GuionParsedElementCollection.swift` - Screenplay data structure
- `GuionDocumentModel.swift` - SwiftData document model
- `SOURCE_FILE_TRACKING.md` - Source file update detection
- `Docs/PDF_CAPABILITIES.md` - Complete PDF parsing assessment
