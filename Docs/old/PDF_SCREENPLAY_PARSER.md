# PDF Screenplay Parser Design Document

**Status**: Planned
**Version**: 1.0
**Target Release**: TBD
**Author**: Claude Code
**Date**: 2025-10-25

## Overview

The PDF Screenplay Parser feature enables extraction of screenplay content from PDF files by leveraging PDFKit for text extraction and Foundation Models (Apple's on-device LLM) for intelligent conversion to Fountain format.

### Goals

1. **Extract text** from PDF files using native PDFKit framework
2. **Convert to Fountain format** using Foundation Models with smart prompting
3. **Parse into screenplay** using existing `GuionParsedElementCollection` infrastructure
4. **Report progress** throughout the multi-phase workflow
5. **Handle errors gracefully** with clear, actionable error messages

### Non-Goals

- OCR support for scanned PDFs (Phase 1 - may be added later with Vision framework)
- Support for non-screenplay PDFs (e.g., novels, scripts in non-standard formats)
- Batch processing (Phase 1 - single file at a time)

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────┐
│            PDFScreenplayParser                      │
│                                                     │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────┐  │
│  │  PDFKit     │→ │ Foundation   │→ │  Fountain │  │
│  │  Extract    │  │ Models       │  │  Parser   │  │
│  │  (20%)      │  │ Convert      │  │  (20%)    │  │
│  │             │  │ (60%)        │  │           │  │
│  └─────────────┘  └──────────────┘  └───────────┘  │
│         ↓                 ↓                ↓        │
│    PDF Text      Fountain Format    GuionParsed    │
│                                     ElementCollection│
└─────────────────────────────────────────────────────┘
```

### Class Design

**Location**: `Sources/SwiftCompartido/Serialization/PDFScreenplayParser.swift`

```swift
import Foundation
import PDFKit

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Parses PDF files into screenplay format using PDFKit and Foundation Models
///
/// ## Overview
///
/// PDFScreenplayParser extracts text from PDF files and converts it to
/// Fountain-formatted screenplays using Apple's on-device language model.
///
/// ## Requirements
///
/// - iOS 26+ / macOS 26+ (for Foundation Models)
/// - PDFKit available on both platforms
///
/// ## Usage
///
/// ```swift
/// // Simple usage
/// let screenplay = try await PDFScreenplayParser.parse(from: pdfURL)
///
/// // With progress tracking
/// let progress = OperationProgress(totalUnits: 100) { update in
///     print("\(update.description) - \(Int(update.fractionCompleted ?? 0 * 100))%")
/// }
/// let screenplay = try await PDFScreenplayParser.parse(
///     from: pdfURL,
///     progress: progress
/// )
/// ```
@available(iOS 26.0, macOS 26.0, *)
public final class PDFScreenplayParser {

    // MARK: - Public API

    /// Parse a PDF file into a screenplay
    /// - Parameters:
    ///   - url: URL to the PDF file
    ///   - progress: Optional progress reporting
    /// - Returns: Parsed screenplay collection
    public static func parse(
        from url: URL,
        progress: OperationProgress? = nil
    ) async throws -> GuionParsedElementCollection

    // MARK: - Private Implementation

    /// Extract text from all pages of a PDF
    private static func extractText(from pdfURL: URL) throws -> String

    /// Convert extracted text to Fountain format using Foundation Models
    private static func convertToFountain(
        _ text: String,
        progress: OperationProgress?
    ) async throws -> String

    /// Build the Foundation Models prompt
    private static func buildConversionPrompt(_ text: String) -> String
}
```

## Implementation Details

### Phase 1: PDF Text Extraction (20% of progress)

**Framework**: PDFKit (native iOS/macOS)

```swift
private static func extractText(from pdfURL: URL) throws -> String {
    // Validate file exists
    guard FileManager.default.fileExists(atPath: pdfURL.path) else {
        throw PDFScreenplayParserError.unableToOpenPDF
    }

    // Open PDF document
    guard let pdfDocument = PDFDocument(url: pdfURL) else {
        throw PDFScreenplayParserError.unableToOpenPDF
    }

    // Check for empty PDF
    guard pdfDocument.pageCount > 0 else {
        throw PDFScreenplayParserError.emptyPDF
    }

    // Extract text from all pages
    var fullText = ""
    for pageIndex in 0..<pdfDocument.pageCount {
        guard let page = pdfDocument.page(at: pageIndex) else { continue }

        if let pageText = page.string {
            fullText += pageText + "\n\n"
        }
    }

    // Validate we got text
    guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw PDFScreenplayParserError.textExtractionFailed
    }

    return fullText
}
```

**Progress Updates**:
- "Extracting text from PDF..."
- "Reading page X of Y..."

### Phase 2: Foundation Models Conversion (60% of progress)

**Framework**: FoundationModels (iOS 26+)

#### Conversion Prompt

```swift
private static func buildConversionPrompt(_ text: String) -> String {
    return """
    Convert this screenplay text to Fountain format. Follow these rules:

    SCENE HEADINGS:
    - Format as: INT./EXT. LOCATION - TIME OF DAY
    - Always in ALL CAPS
    - Examples: INT. COFFEE SHOP - DAY, EXT. PARK - NIGHT

    CHARACTER NAMES:
    - Always in ALL CAPS
    - On their own line above dialogue
    - Examples: JOHN, SARAH, VOICE OVER

    DIALOGUE:
    - Plain text below character name
    - No special formatting needed

    PARENTHETICALS:
    - Wrapped in (parentheses)
    - On their own line within dialogue
    - Examples: (laughing), (to Sarah), (into phone)

    ACTION:
    - Plain text paragraphs
    - Between other elements
    - Describe what happens on screen

    TRANSITIONS:
    - End with colon
    - Examples: CUT TO:, FADE OUT., DISSOLVE TO:

    SECTION HEADINGS:
    - Use # for acts (# ACT ONE)
    - Use ## for sequences (## OPENING SEQUENCE)
    - Use ### for scene groups (### THE HEIST)

    IMPORTANT:
    - Preserve all dialogue word-for-word
    - Preserve all story content
    - Only reformat to valid Fountain syntax
    - Ensure proper spacing between elements

    Original text:
    \(text)
    """
}
```

#### Implementation

```swift
#if canImport(FoundationModels)
private static func convertToFountain(
    _ text: String,
    progress: OperationProgress?
) async throws -> String {

    progress?.updateDescription("Converting to screenplay format...")

    // Build the prompt
    let prompt = buildConversionPrompt(text)

    // TODO: Actual Foundation Models API implementation
    // When the API is finalized, this will be something like:
    //
    // let model = try await LanguageModel.shared
    // let response = try await model.generateText(
    //     prompt: prompt,
    //     maxTokens: 8000,
    //     temperature: 0.3  // Lower temperature for more consistent formatting
    // )
    // return response.text

    // For now, return basic cleaned text
    // This allows testing the infrastructure before Foundation Models API is finalized
    let cleaned = text
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)

    return cleaned
}
#else
private static func convertToFountain(
    _ text: String,
    progress: OperationProgress?
) async throws -> String {
    // Fallback for platforms without Foundation Models
    throw PDFScreenplayParserError.foundationModelsUnavailable
}
#endif
```

**Progress Updates**:
- "Converting to screenplay format..."
- "Processing with Foundation Models..."
- "Formatting screenplay elements..."

### Phase 3: Fountain Parsing (20% of progress)

**Uses existing infrastructure**: `GuionParsedElementCollection`

```swift
public static func parse(
    from url: URL,
    progress: OperationProgress? = nil
) async throws -> GuionParsedElementCollection {

    // Phase 1: Extract text from PDF (20%)
    progress?.updateDescription("Extracting text from PDF...")
    let pdfText = try extractText(from: url)
    progress?.addCompleted(20)

    // Phase 2: Convert to Fountain using Foundation Models (60%)
    progress?.updateDescription("Converting to screenplay format...")
    let fountainText = try await convertToFountain(pdfText, progress: progress)
    progress?.addCompleted(60)

    // Phase 3: Parse Fountain into screenplay (20%)
    progress?.updateDescription("Parsing screenplay elements...")
    do {
        let screenplay = try await GuionParsedElementCollection(
            string: fountainText,
            progress: progress
        )
        progress?.addCompleted(20)
        return screenplay
    } catch {
        throw PDFScreenplayParserError.parsingFailed(error)
    }
}
```

## Error Handling

### Error Types

```swift
public enum PDFScreenplayParserError: Error, LocalizedError {
    case unableToOpenPDF
    case emptyPDF
    case textExtractionFailed
    case foundationModelsUnavailable
    case conversionFailed(String)
    case parsingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .unableToOpenPDF:
            return "Unable to open PDF file. The file may be corrupted or password-protected."
        case .emptyPDF:
            return "PDF contains no pages"
        case .textExtractionFailed:
            return "Failed to extract text from PDF. The PDF may contain only images (OCR not yet supported)."
        case .foundationModelsUnavailable:
            return "Foundation Models not available. This feature requires iOS 26+/macOS 26+ with Apple Intelligence enabled."
        case .conversionFailed(let reason):
            return "Failed to convert to screenplay format: \(reason)"
        case .parsingFailed(let error):
            return "Failed to parse screenplay: \(error.localizedDescription)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unableToOpenPDF:
            return "Verify the PDF file is not corrupted and try again."
        case .emptyPDF:
            return "Ensure the PDF contains screenplay content."
        case .textExtractionFailed:
            return "Try exporting the PDF with embedded text, or use a different PDF source."
        case .foundationModelsUnavailable:
            return "Update to iOS 26+/macOS 26+ and enable Apple Intelligence in Settings."
        case .conversionFailed:
            return "The PDF content may not be in a recognizable screenplay format."
        case .parsingFailed:
            return "The conversion to Fountain format may have produced invalid syntax."
        }
    }
}
```

## Testing Strategy

### Test Files

**Location**: `Tests/SwiftCompartidoTests/PDFScreenplayParserTests.swift`

**Test Fixtures**: `Fixtures/PDFScreenplays/`
- `simple-screenplay.pdf` - Single scene, basic dialogue
- `multi-page-screenplay.pdf` - 10+ pages with various elements
- `invalid.pdf` - Corrupted PDF for error handling
- `empty.pdf` - PDF with no text
- `scanned-screenplay.pdf` - Image-based PDF (should fail gracefully)

### Test Cases

```swift
import Testing
@testable import SwiftCompartido

@available(iOS 26.0, macOS 26.0, *)
@Suite("PDF Screenplay Parser Tests")
struct PDFScreenplayParserTests {

    // MARK: - Success Cases

    @Test("Parse simple PDF screenplay")
    func testSimplePDFParsing() async throws {
        let url = getFixture("simple-screenplay.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        #expect(screenplay.elements.count > 0)
        #expect(screenplay.elements.contains { $0.elementType == .sceneHeading })
        #expect(screenplay.elements.contains { $0.elementType == .dialogue })
    }

    @Test("Parse multi-page PDF screenplay")
    func testMultiPagePDFParsing() async throws {
        let url = getFixture("multi-page-screenplay.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        #expect(screenplay.elements.count > 20)
        // Verify various element types exist
        #expect(screenplay.elements.contains { $0.elementType == .sceneHeading })
        #expect(screenplay.elements.contains { $0.elementType == .character })
        #expect(screenplay.elements.contains { $0.elementType == .dialogue })
        #expect(screenplay.elements.contains { $0.elementType == .action })
    }

    @Test("Progress reporting works correctly")
    func testProgressReporting() async throws {
        actor ProgressCollector {
            var updates: [ProgressUpdate] = []

            func add(_ update: ProgressUpdate) {
                updates.append(update)
            }

            func getUpdates() -> [ProgressUpdate] {
                return updates
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: 100) { update in
            Task { await collector.add(update) }
        }

        let url = getFixture("simple-screenplay.pdf")
        let screenplay = try await PDFScreenplayParser.parse(from: url, progress: progress)

        let updates = await collector.getUpdates()
        #expect(updates.count > 0)
        #expect(updates.contains { $0.description.contains("Extracting") })
        #expect(updates.contains { $0.description.contains("Converting") })
        #expect(updates.contains { $0.description.contains("Parsing") })
    }

    // MARK: - Error Cases

    @Test("Handle invalid PDF file")
    func testInvalidPDF() async throws {
        let url = getFixture("invalid.pdf")

        await #expect(throws: PDFScreenplayParserError.self) {
            try await PDFScreenplayParser.parse(from: url)
        }
    }

    @Test("Handle empty PDF file")
    func testEmptyPDF() async throws {
        let url = getFixture("empty.pdf")

        await #expect(throws: PDFScreenplayParserError.emptyPDF) {
            try await PDFScreenplayParser.parse(from: url)
        }
    }

    @Test("Handle scanned PDF gracefully")
    func testScannedPDF() async throws {
        let url = getFixture("scanned-screenplay.pdf")

        await #expect(throws: PDFScreenplayParserError.textExtractionFailed) {
            try await PDFScreenplayParser.parse(from: url)
        }
    }

    @Test("Handle missing file")
    func testMissingFile() async throws {
        let url = URL(fileURLWithPath: "/nonexistent/file.pdf")

        await #expect(throws: PDFScreenplayParserError.unableToOpenPDF) {
            try await PDFScreenplayParser.parse(from: url)
        }
    }

    // MARK: - Integration Tests

    @Test("Full workflow: PDF to SwiftData")
    func testFullWorkflow() async throws {
        let url = getFixture("simple-screenplay.pdf")

        // Parse PDF
        let screenplay = try await PDFScreenplayParser.parse(from: url)

        // Convert to SwiftData
        let modelContext = createTestModelContext()
        let document = await GuionDocumentParserSwiftData.parse(
            script: screenplay,
            in: modelContext,
            generateSummaries: false
        )

        #expect(document.elements.count > 0)
        #expect(document.sortedElements.count == screenplay.elements.count)
    }

    // MARK: - Helper Methods

    private func getFixture(_ filename: String) -> URL {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: type(of: self))
        #endif

        let fixturesPath = bundle.resourcePath!
        return URL(fileURLWithPath: fixturesPath)
            .appendingPathComponent("Fixtures/PDFScreenplays")
            .appendingPathComponent(filename)
    }

    private func createTestModelContext() -> ModelContext {
        // Create in-memory model context for testing
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return container.mainContext
    }
}
```

## Usage Examples

### Basic Usage

```swift
import SwiftCompartido

// Simple parse
let pdfURL = URL(fileURLWithPath: "/path/to/screenplay.pdf")
let screenplay = try await PDFScreenplayParser.parse(from: pdfURL)

// Access elements
for element in screenplay.elements {
    print("\(element.elementType): \(element.elementText)")
}
```

### With Progress Tracking

```swift
let progress = OperationProgress(totalUnits: 100) { update in
    print("\(update.description) - \(Int((update.fractionCompleted ?? 0) * 100))%")
}

let screenplay = try await PDFScreenplayParser.parse(
    from: pdfURL,
    progress: progress
)
```

### SwiftUI Integration

```swift
@MainActor
class DocumentImporter: ObservableObject {
    @Published var isProcessing = false
    @Published var progressMessage = ""
    @Published var progressValue = 0.0
    @Published var error: Error?

    func importPDF(_ url: URL, modelContext: ModelContext) async {
        isProcessing = true
        error = nil

        let progress = OperationProgress(totalUnits: 100) { [weak self] update in
            Task { @MainActor in
                self?.progressMessage = update.description
                self?.progressValue = update.fractionCompleted ?? 0.0
            }
        }

        do {
            // Parse PDF
            let screenplay = try await PDFScreenplayParser.parse(
                from: url,
                progress: progress
            )

            // Convert to SwiftData
            let document = await GuionDocumentParserSwiftData.parse(
                script: screenplay,
                in: modelContext,
                generateSummaries: true
            )

            // Success!
            print("Imported screenplay with \(document.elements.count) elements")

        } catch {
            self.error = error
        }

        isProcessing = false
    }
}

// In SwiftUI View
struct PDFImportView: View {
    @StateObject private var importer = DocumentImporter()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack {
            Button("Import PDF Screenplay") {
                // Show file picker
                showFilePicker()
            }
            .disabled(importer.isProcessing)

            if importer.isProcessing {
                ProgressView(value: importer.progressValue) {
                    Text(importer.progressMessage)
                }
                .padding()
            }

            if let error = importer.error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }

    private func showFilePicker() {
        // File picker implementation
        // On selection, call:
        // Task {
        //     await importer.importPDF(selectedURL, modelContext: modelContext)
        // }
    }
}
```

### Error Handling

```swift
do {
    let screenplay = try await PDFScreenplayParser.parse(from: pdfURL)
    // Process screenplay...

} catch PDFScreenplayParserError.unableToOpenPDF {
    print("Could not open PDF file")

} catch PDFScreenplayParserError.emptyPDF {
    print("PDF is empty")

} catch PDFScreenplayParserError.textExtractionFailed {
    print("PDF may be scanned (OCR not supported)")

} catch PDFScreenplayParserError.foundationModelsUnavailable {
    print("Requires iOS 26+ with Apple Intelligence")

} catch PDFScreenplayParserError.conversionFailed(let reason) {
    print("Conversion failed: \(reason)")

} catch PDFScreenplayParserError.parsingFailed(let error) {
    print("Parsing failed: \(error)")

} catch {
    print("Unexpected error: \(error)")
}
```

## Platform Requirements

### Minimum Requirements

- **iOS**: 26.0+
- **macOS**: 26.0+
- **Mac Catalyst**: 26.0+
- **Frameworks**: PDFKit (native), FoundationModels (iOS 26+)

### Device Requirements

For Foundation Models to work:
- Apple Intelligence-compatible device
- Apple Intelligence enabled in Settings
- iPhone 15 Pro or later (for phones)
- iPad with M1 or later
- Mac with Apple Silicon

### Fallback Strategy

**Pre-iOS 26** or **Foundation Models unavailable**:
```swift
// Throw clear error
throw PDFScreenplayParserError.foundationModelsUnavailable
```

**Future Enhancement** (Phase 2):
- Add heuristic-based conversion for older platforms
- Basic pattern matching for scene headings, character names
- Best-effort Fountain formatting
- Display warning that results may need manual cleanup

## Implementation Roadmap

### Phase 1: Foundation (Week 1)

1. **Create class skeleton**
   - `PDFScreenplayParser.swift`
   - Public API definition
   - Error types

2. **Implement PDF extraction**
   - PDFKit integration
   - Text extraction from pages
   - Empty/invalid PDF handling

3. **Add progress infrastructure**
   - Integrate with `OperationProgress`
   - Phase-based progress reporting
   - Description updates

### Phase 2: Foundation Models Integration (Week 2)

1. **Implement conversion**
   - Build prompt template
   - Foundation Models API integration (TODO marker for now)
   - Fallback handling

2. **Add Fountain parsing**
   - Integration with `GuionParsedElementCollection`
   - Error handling for invalid Fountain

3. **SwiftData workflow**
   - Test full PDF → SwiftData pipeline
   - Verify element ordering

### Phase 3: Testing (Week 3)

1. **Create test fixtures**
   - Generate sample PDFs
   - Various scenarios (simple, complex, edge cases)

2. **Write unit tests**
   - PDF extraction tests
   - Error handling tests
   - Progress reporting tests

3. **Integration tests**
   - Full workflow tests
   - SwiftData conversion tests

### Phase 4: Documentation & Polish (Week 4)

1. **API documentation**
   - DocC comments
   - Usage examples
   - Error recovery guidance

2. **User documentation**
   - README updates
   - Migration guide
   - Troubleshooting section

3. **CI/CD integration**
   - Add test fixtures to bundle
   - Update Package.swift resources
   - Verify tests pass on CI

## Future Enhancements (Phase 2+)

### OCR Support (Phase 2)

Use Vision framework for scanned PDFs:

```swift
import Vision

private static func performOCR(on pdfURL: URL) async throws -> String {
    // Use VNRecognizeTextRequest
    // Extract text from image-based PDFs
}
```

### Custom Prompts (Phase 2)

Allow users to customize conversion prompts:

```swift
public static func parse(
    from url: URL,
    customPrompt: String? = nil,
    progress: OperationProgress? = nil
) async throws -> GuionParsedElementCollection
```

### Batch Processing (Phase 3)

Process multiple PDFs:

```swift
public static func parseBatch(
    _ urls: [URL],
    progress: OperationProgress? = nil
) async throws -> [GuionParsedElementCollection]
```

### Format Detection (Phase 3)

Auto-detect if PDF already contains Fountain metadata:

```swift
private static func detectFormat(_ pdfURL: URL) -> ScreenplayFormat {
    // Check PDF metadata
    // Look for Fountain/FDX markers
}
```

## Dependencies

### Required

- **PDFKit** - Native iOS/macOS framework for PDF handling
- **FoundationModels** - iOS 26+ for on-device LLM (optional at runtime)

### Existing

- **GuionParsedElementCollection** - Fountain parsing infrastructure
- **OperationProgress** - Progress reporting system
- **GuionDocumentParserSwiftData** - SwiftData conversion

### New

None - uses only Apple frameworks and existing infrastructure

## Performance Considerations

### Benchmarks (Estimated)

For a typical 120-page screenplay (~30,000 words):

- **PDF Text Extraction**: ~1-2 seconds
- **Foundation Models Conversion**: ~30-60 seconds (on-device LLM)
- **Fountain Parsing**: ~1-2 seconds
- **Total**: ~35-65 seconds

### Optimizations

1. **Chunking** (Phase 2)
   - Process PDF in chunks if > 100 pages
   - Prevents memory issues
   - Better progress reporting

2. **Caching** (Phase 2)
   - Cache extracted text for retry scenarios
   - Cache conversion results

3. **Streaming** (Phase 3)
   - Stream Foundation Models output
   - Parse incrementally

## Security Considerations

### Sandboxing

- PDFs may come from untrusted sources
- Validate file permissions
- Use security-scoped bookmarks

### Privacy

- Processing happens on-device (Foundation Models)
- No network requests
- User data stays local

### Error Cases

- Handle corrupted PDFs gracefully
- Don't crash on malformed input
- Clear error messages

## Open Questions

1. **Foundation Models API** - Exact API is TBD (marked as TODO in implementation)
2. **Token Limits** - What's the max input size for Foundation Models?
3. **Quality Validation** - How do we validate conversion quality?
4. **User Feedback** - Should we show confidence scores?

## Success Criteria

### Functional Requirements

- ✅ Extract text from valid PDF files
- ✅ Convert to valid Fountain format (when Foundation Models available)
- ✅ Parse into `GuionParsedElementCollection`
- ✅ Report progress throughout workflow
- ✅ Handle errors gracefully

### Quality Requirements

- ✅ Preserve all dialogue word-for-word
- ✅ Preserve all story content
- ✅ Proper Fountain formatting
- ✅ Element order maintained
- ✅ Character names correctly identified

### Performance Requirements

- ✅ Process 120-page screenplay in < 2 minutes
- ✅ Progress updates every 5% (at minimum)
- ✅ Memory usage < 200MB for typical screenplay

## Appendix

### Related Documentation

- [Foundation Models Documentation](https://developer.apple.com/documentation/foundationmodels) (when available)
- [PDFKit Documentation](https://developer.apple.com/documentation/pdfkit)
- [Fountain Specification](https://fountain.io/syntax)

### References

- `SceneSummarizer.swift` - Foundation Models integration pattern
- `FDXParser.swift` - XML parsing pattern
- `GuionParsedElementCollection.swift` - Screenplay parsing infrastructure
- `OperationProgress.swift` - Progress reporting system

---

**Document Version**: 1.0
**Last Updated**: 2025-10-25
**Status**: Ready for Implementation
