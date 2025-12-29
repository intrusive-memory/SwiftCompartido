# Storyboard Extraction CLI - Pseudocode

## Overview

A command-line utility executable that processes screenplays imported via SwiftCompartido, extracting storyboard prompts from SYNOPSIS elements and associating them with SLUGLINE locations.

## Swift Package Executable Configuration

```swift
// Package.swift additions
products: [
    .library(name: "SwiftCompartido", targets: ["SwiftCompartido"]),
    .executable(name: "storyboard-extractor", targets: ["StoryboardExtractor"]) // NEW
],
targets: [
    .target(name: "SwiftCompartido", ...),
    .executableTarget(                                                           // NEW
        name: "StoryboardExtractor",
        dependencies: ["SwiftCompartido"],
        path: "Sources/StoryboardExtractor"
    ),
    .testTarget(name: "SwiftCompartidoTests", ...)
]
```

## Directory Structure

```
SwiftCompartido/
├── Package.swift
├── Sources/
│   ├── SwiftCompartido/           # Library code
│   └── StoryboardExtractor/       # NEW: CLI executable
│       ├── main.swift             # Entry point
│       ├── StoryboardExtractor.swift
│       ├── LocationTracker.swift
│       └── StoryboardPrompt.swift
└── Docs/
    └── STORYBOARD_CLI_PSEUDOCODE.md
```

## Data Structures

```swift
// StoryboardPrompt.swift
struct StoryboardPrompt: Codable, Identifiable {
    let id: UUID
    let location: String           // From SLUGLINE (e.g., "INT. COFFEE SHOP - DAY")
    let promptText: String         // SYNOPSIS text after "= STORYBOARD:"
    let elementOrderIndex: Int     // Original position in screenplay
    let chapterIndex: Int          // Chapter grouping

    var fileName: String {
        // Sanitize location for filename
        // "INT. COFFEE SHOP - DAY" -> "int_coffee_shop_day_001.txt"
    }
}

// LocationTracker.swift
@MainActor
class LocationTracker {
    private var currentLocation: String?

    func update(from slugline: GuionElementModel) {
        // Extract location from slugline.location or slugline.textValue
        currentLocation = extractLocation(from: slugline)
    }

    func getCurrentLocation() -> String? {
        return currentLocation
    }

    private func extractLocation(from element: GuionElementModel) -> String {
        // Priority: element.location ?? element.textValue
        // Clean formatting (remove markers like "INT.", "EXT.", time of day)
    }
}
```

## Core Algorithm (Pseudocode)

```python
# main.swift
func main() async throws:
    # 1. Parse command-line arguments
    args = CommandLine.arguments
    if args.count < 2:
        print("Usage: storyboard-extractor <screenplay-file>")
        exit(1)

    screenplayPath = args[1]

    # 2. Setup SwiftData container (in-memory or temporary)
    container = createTemporaryModelContainer()
    modelContext = container.mainContext

    # 3. Import screenplay using SwiftCompartido
    print("Importing screenplay: \(screenplayPath)")
    screenplay = try await GuionParsedElementCollection(url: URL(fileURLWithPath: screenplayPath))

    document = await GuionDocumentParserSwiftData.parse(
        script: screenplay,
        in: modelContext
    )

    print("Imported \(document.sortedElements.count) elements")

    # 4. Query all elements (CRITICAL: use sortedElements for order!)
    elements = document.sortedElements

    # 5. Initialize location tracker
    locationTracker = LocationTracker()
    storyboardPrompts = []

    # 6. Iterate through elements sequentially
    for element in elements:
        # 6a. Track SLUGLINE as current location
        if element.elementType == .slugline:
            locationTracker.update(from: element)
            print("Location changed: \(locationTracker.getCurrentLocation())")

        # 6b. Check for SYNOPSIS elements with STORYBOARD marker
        if element.elementType == .synopsis:
            synopsisText = element.textValue.trimmingCharacters(in: .whitespacesAndNewlines)

            # Check if this is a storyboard prompt
            if synopsisText.hasPrefix("= STORYBOARD:"):
                # Extract prompt text (everything after "= STORYBOARD:")
                promptText = synopsisText
                    .replacingOccurrences(of: "= STORYBOARD:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                # Get current location
                currentLocation = locationTracker.getCurrentLocation()

                if currentLocation == nil:
                    print("Warning: Storyboard prompt found without location context")
                    print("  Prompt: \(promptText)")
                    currentLocation = "UNKNOWN_LOCATION"

                # Create storyboard prompt record
                prompt = StoryboardPrompt(
                    id: UUID(),
                    location: currentLocation!,
                    promptText: promptText,
                    elementOrderIndex: element.orderIndex,
                    chapterIndex: element.chapterIndex
                )

                storyboardPrompts.append(prompt)

                print("Found storyboard: \(currentLocation!) - \(promptText.prefix(50))...")

    # 7. Export results
    print("\nFound \(storyboardPrompts.count) storyboard prompts")

    # 7a. Export as JSON
    exportToJSON(storyboardPrompts, to: "storyboards.json")

    # 7b. Export as individual text files
    exportToTextFiles(storyboardPrompts, to: "storyboards/")

    # 7c. Export as CSV
    exportToCSV(storyboardPrompts, to: "storyboards.csv")

    print("Export complete!")


# Helper functions

func createTemporaryModelContainer() -> ModelContainer:
    schema = Schema([
        GuionDocumentModel.self,
        GuionElementModel.self,
        TypedDataStorage.self,
        # ... other models
    ])

    configuration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true  # Use in-memory for CLI (no persistent DB)
    )

    return try ModelContainer(
        for: schema,
        configurations: [configuration]
    )


func exportToJSON(prompts: [StoryboardPrompt], to path: String):
    encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    data = try encoder.encode(prompts)
    try data.write(to: URL(fileURLWithPath: path))

    print("Exported JSON: \(path)")


func exportToTextFiles(prompts: [StoryboardPrompt], to directory: String):
    # Create output directory
    fileManager = FileManager.default
    try fileManager.createDirectory(
        atPath: directory,
        withIntermediateDirectories: true
    )

    # Group prompts by location (multiple prompts for same location)
    groupedByLocation = Dictionary(grouping: prompts, by: { $0.location })

    for (location, locationPrompts) in groupedByLocation:
        for (index, prompt) in locationPrompts.enumerated():
            # Create filename: "int_coffee_shop_day_001.txt"
            fileName = sanitizeFileName(location) + "_\(String(format: "%03d", index + 1)).txt"
            filePath = directory + "/" + fileName

            # Write prompt text
            content = """
            LOCATION: \(prompt.location)
            CHAPTER: \(prompt.chapterIndex)
            ELEMENT INDEX: \(prompt.elementOrderIndex)

            PROMPT:
            \(prompt.promptText)
            """

            try content.write(
                toFile: filePath,
                atomically: true,
                encoding: .utf8
            )

        print("Exported \(locationPrompts.count) prompts for location: \(location)")


func exportToCSV(prompts: [StoryboardPrompt], to path: String):
    # CSV Header
    csv = "id,location,chapter_index,element_order,prompt\n"

    # CSV Rows
    for prompt in prompts:
        # Escape commas and quotes in prompt text
        escapedPrompt = prompt.promptText
            .replacingOccurrences(of: "\"", with: "\"\"")

        csv += "\(prompt.id),\"\(prompt.location)\",\(prompt.chapterIndex),\(prompt.elementOrderIndex),\"\(escapedPrompt)\"\n"

    try csv.write(
        toFile: path,
        atomically: true,
        encoding: .utf8
    )

    print("Exported CSV: \(path)")


func sanitizeFileName(_ location: String) -> String:
    # Convert "INT. COFFEE SHOP - DAY" to "int_coffee_shop_day"
    return location
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
```

## Example Usage

```bash
# Build the executable
swift build -c release

# Run the extractor
.build/release/storyboard-extractor screenplay.fountain

# Output:
# Importing screenplay: screenplay.fountain
# Imported 1247 elements
# Location changed: INT. COFFEE SHOP - DAY
# Found storyboard: INT. COFFEE SHOP - DAY - Wide shot of bustling coffee shop...
# Location changed: EXT. CITY STREET - NIGHT
# Found storyboard: EXT. CITY STREET - NIGHT - Dark alley with flickering streetlight...
#
# Found 47 storyboard prompts
# Exported JSON: storyboards.json
# Exported 47 prompts for 12 locations
# Exported CSV: storyboards.csv
# Export complete!
```

## Output Examples

### JSON Output (storyboards.json)
```json
[
  {
    "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
    "location": "INT. COFFEE SHOP - DAY",
    "promptText": "Wide shot of bustling coffee shop, warm lighting, customers at tables, barista behind counter",
    "elementOrderIndex": 45,
    "chapterIndex": 2
  },
  {
    "id": "B2C3D4E5-F6G7-8901-BCDE-F01234567891",
    "location": "EXT. CITY STREET - NIGHT",
    "promptText": "Dark alley with flickering streetlight, rain-slicked pavement, figure in shadows",
    "elementOrderIndex": 127,
    "chapterIndex": 5
  }
]
```

### Text File Output (storyboards/int_coffee_shop_day_001.txt)
```
LOCATION: INT. COFFEE SHOP - DAY
CHAPTER: 2
ELEMENT INDEX: 45

PROMPT:
Wide shot of bustling coffee shop, warm lighting, customers at tables, barista behind counter
```

### CSV Output (storyboards.csv)
```csv
id,location,chapter_index,element_order,prompt
A1B2C3D4-E5F6-7890-ABCD-EF1234567890,"INT. COFFEE SHOP - DAY",2,45,"Wide shot of bustling coffee shop, warm lighting, customers at tables, barista behind counter"
B2C3D4E5-F6G7-8901-BCDE-F01234567891,"EXT. CITY STREET - NIGHT",5,127,"Dark alley with flickering streetlight, rain-slicked pavement, figure in shadows"
```

## Edge Cases to Handle

1. **STORYBOARD without preceding SLUGLINE**
   - Assign location: "UNKNOWN_LOCATION"
   - Print warning with element index

2. **Multiple STORYBOARD prompts for same location**
   - Use counter suffix in filename: `_001.txt`, `_002.txt`
   - Group by location in CSV/JSON

3. **Empty STORYBOARD prompt** (just "= STORYBOARD:" with no text)
   - Skip or include with empty prompt text
   - Log warning

4. **Malformed STORYBOARD marker** (e.g., "=STORYBOARD:" without space)
   - Use flexible matching: `hasPrefix("= STORYBOARD:") || hasPrefix("=STORYBOARD:")`

5. **Location extraction from SLUGLINE**
   - Priority: `element.location` property first
   - Fallback: `element.textValue` if location is nil
   - Clean common markers: "INT.", "EXT.", "INT/EXT.", time of day suffixes

6. **SwiftData query ordering**
   - CRITICAL: Always use `document.sortedElements`
   - NEVER iterate `document.elements` directly (unordered!)

## Google Gemini Integration for Image Generation

### Overview

Google Gemini provides multiple APIs for generating storyboard images from the extracted prompts. This CLI can be extended to automatically generate visual storyboards using either:

1. **Imagen 3 API** - Dedicated high-quality text-to-image generation
2. **Gemini 2.5 Flash Image** - Fast image generation with built-in editing capabilities
3. **Gemini "Nano Banana"** - Native image generation with thinking, search grounding, and 4K output

### Reference Repositories

#### Official Swift SDK (Deprecated - Use Firebase Instead)
- **Repository**: [google/generative-ai-swift](https://github.com/google/generative-ai-swift)
- **Status**: Deprecated (no longer maintained as of August 2024)
- **Migration**: Use Firebase AI Logic SDK instead
- **Note**: 1.1k stars, Apache-2.0 licensed

#### Firebase AI Logic SDK (Recommended for Swift)
- **Documentation**: [Firebase AI Logic](https://firebase.google.com/docs/ai-logic)
- **Image Generation Guide**: [Generate & edit images using Gemini](https://firebase.google.com/docs/ai-logic/generate-images-gemini)
- **Imagen Support**: [Generate images using Imagen](https://firebase.google.com/docs/vertex-ai/generate-images-imagen)
- **Swift Support**: Full client SDK available for iOS/macOS
- **Updated**: December 12, 2025

#### Google Gemini GitHub Organization
- **Organization**: [github.com/google-gemini](https://github.com/google-gemini)
- **Key Repositories**:
  - [gemini-image-editing-nextjs-quickstart](https://github.com/google-gemini/gemini-image-editing-nextjs-quickstart) - Native image generation/editing with Gemini 2.0 (511 stars)
  - [veo-3-nano-banana-gemini-api-quickstart](https://github.com/google-gemini/veo-3-nano-banana-gemini-api-quickstart) - Hackathon starter for Veo 3, Imagen 4, Gemini 2.5 (270 stars)
  - [cookbook](https://github.com/google-gemini/cookbook) - Examples and guides for Gemini API (15.9k stars)
  - [api-examples](https://github.com/google-gemini/api-examples) - Example code for Gemini API (107 stars)

### API Options Comparison

| API | Best For | Quality | Speed | Swift SDK |
|-----|----------|---------|-------|-----------|
| **Imagen 3** | High-quality production storyboards | Highest | Medium | Firebase ✅ |
| **Gemini 2.5 Flash Image** | Fast iteration and editing | High | Fastest | Firebase ✅ |
| **Gemini Nano Banana** | 4K output with reasoning | Very High | Medium | Firebase ✅ |

### Implementation Approaches

#### Option 1: Firebase AI Logic SDK (Recommended for Swift)

**Advantages:**
- Native Swift support for iOS/macOS
- Unified SDK for all Google AI models
- Automatic authentication and API key management
- Built-in retry logic and error handling

**Package Dependencies:**
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0")
],
targets: [
    .executableTarget(
        name: "StoryboardExtractor",
        dependencies: [
            "SwiftCompartido",
            .product(name: "FirebaseVertexAI", package: "firebase-ios-sdk")
        ]
    )
]
```

**Usage Pattern:**
```swift
import FirebaseCore
import FirebaseVertexAI

// Initialize Firebase
FirebaseApp.configure()

// Generate image using Imagen 3
let vertex = VertexAI.vertexAI()
let model = vertex.imagenModel(modelName: "imagen-3.0-generate-001")

let prompt = "INT. COFFEE SHOP - DAY: Wide shot of bustling coffee shop, warm lighting"

let images = try await model.generateImages(prompt: prompt)
for (index, image) in images.enumerated() {
    try image.pngData()?.write(to: URL(fileURLWithPath: "storyboard_\(index).png"))
}
```

#### Option 2: Direct REST API (Cross-Platform)

**Advantages:**
- No SDK dependencies (pure URLSession)
- Works on any platform with HTTP support
- Full control over request/response handling

**Reference Documentation:**
- [Gemini REST API Quickstarts](https://github.com/google-gemini/cookbook/tree/main/quickstarts/rest/)
- [Authentication Setup](https://aistudio.google.com/app/apikey)

**Usage Pattern:**
```swift
import Foundation

struct GeminiImageGenerator {
    let apiKey: String
    let endpoint = "https://generativelanguage.googleapis.com/v1/models/imagen-3.0-generate-001:generateImages"

    func generateImage(prompt: String) async throws -> Data {
        var request = URLRequest(url: URL(string: "\(endpoint)?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "prompt": prompt,
            "numberOfImages": 1,
            "aspectRatio": "16:9",
            "negativePrompt": "blurry, low quality, distorted"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.requestFailed
        }

        return data
    }
}
```

### Extended CLI with Image Generation

**Command-line Interface:**
```bash
# Generate images using Imagen 3
storyboard-extractor screenplay.fountain \
  --generate-images \
  --api imagen3 \
  --api-key $GEMINI_API_KEY \
  --aspect-ratio 16:9 \
  --output-dir ./storyboards/

# Use Gemini Flash for fast iteration
storyboard-extractor screenplay.fountain \
  --generate-images \
  --api gemini-flash \
  --style "cinematic, 35mm film" \
  --negative-prompt "blurry, low quality"

# Batch process with rate limiting
storyboard-extractor screenplay.fountain \
  --generate-images \
  --batch-size 10 \
  --rate-limit 5  # 5 requests per second
```

**Implementation Pseudocode:**
```python
func generateImages(for prompts: [StoryboardPrompt], using api: ImageAPI) async throws:
    generator = ImageGenerator(api: api, apiKey: getAPIKey())

    for prompt in prompts:
        print("Generating image for: \(prompt.location)")

        # Enhance prompt with location context
        enhancedPrompt = """
        Location: \(prompt.location)
        Scene: \(prompt.promptText)
        Style: Cinematic storyboard, high contrast lighting, professional composition
        Format: Wide shot, 16:9 aspect ratio
        """

        # Generate image
        imageData = try await generator.generate(prompt: enhancedPrompt)

        # Save to file
        fileName = prompt.fileName.replacingOccurrences(of: ".txt", with: ".png")
        outputPath = "storyboards/images/\(fileName)"

        try imageData.write(to: URL(fileURLWithPath: outputPath))

        print("  Saved: \(outputPath)")

        # Rate limiting
        try await Task.sleep(nanoseconds: 200_000_000)  # 200ms delay
```

### Prompt Enhancement Strategies

**1. Location-Aware Prompts**
```swift
func enhancePrompt(_ prompt: StoryboardPrompt) -> String {
    let timeOfDay = extractTimeOfDay(from: prompt.location)  // "DAY", "NIGHT", "DAWN"
    let setting = extractSetting(from: prompt.location)      // "INT.", "EXT."

    return """
    \(setting) scene at \(timeOfDay.lowercased()).
    Location: \(prompt.location)
    Visual description: \(prompt.promptText)
    Style: Cinematic storyboard, professional lighting, 16:9 composition.
    Quality: High detail, film grain, depth of field.
    """
}
```

**2. Style Templates**
```swift
enum StoryboardStyle: String {
    case cinematic = "Cinematic film aesthetic, 35mm, high contrast lighting"
    case noir = "Film noir, dramatic shadows, black and white"
    case animated = "Hand-drawn animation style, vibrant colors, expressive"
    case realistic = "Photorealistic, documentary style, natural lighting"
}

func applyStyle(_ prompt: String, style: StoryboardStyle) -> String {
    return "\(prompt)\nStyle: \(style.rawValue)"
}
```

**3. Negative Prompts**
```swift
let defaultNegativePrompt = """
blurry, low quality, distorted, deformed, watermark, text overlay,
poor composition, amateur, out of focus
"""
```

### Error Handling & Retry Logic

```swift
func generateImageWithRetry(
    prompt: String,
    maxRetries: Int = 3
) async throws -> Data {
    var lastError: Error?

    for attempt in 1...maxRetries {
        do {
            return try await generateImage(prompt: prompt)
        } catch let error as GeminiError where error.isRetryable {
            print("Attempt \(attempt) failed: \(error). Retrying...")
            lastError = error

            // Exponential backoff: 2^attempt seconds
            let delay = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)
            try await Task.sleep(nanoseconds: delay)
        } catch {
            throw error  // Non-retryable error
        }
    }

    throw lastError ?? GeminiError.unknown
}
```

### Cost Optimization Strategies

1. **Batch Processing**: Group prompts by location to reduce redundant generation
2. **Caching**: Store generated images with prompt hash to avoid regeneration
3. **Preview Mode**: Generate low-resolution previews first (faster/cheaper)
4. **Selective Generation**: Only generate images for key scenes (filtered by importance)

### Testing Image Generation

```swift
// Tests/StoryboardExtractorTests/ImageGenerationTests.swift
import XCTest
@testable import StoryboardExtractor

final class ImageGenerationTests: XCTestCase {
    func testPromptEnhancement() {
        let prompt = StoryboardPrompt(
            id: UUID(),
            location: "INT. COFFEE SHOP - DAY",
            promptText: "Wide shot of bustling cafe",
            elementOrderIndex: 1,
            chapterIndex: 1
        )

        let enhanced = enhancePrompt(prompt)

        XCTAssertTrue(enhanced.contains("INT. scene"))
        XCTAssertTrue(enhanced.contains("at day"))
        XCTAssertTrue(enhanced.contains("Wide shot of bustling cafe"))
    }

    func testImageGeneration() async throws {
        // Use test API key or mock
        let generator = ImageGenerator(api: .geminiFlash, apiKey: "test-key")

        let prompt = "Test storyboard scene"
        let data = try await generator.generate(prompt: prompt)

        XCTAssertGreaterThan(data.count, 0)
    }
}
```

### References & Documentation

**Official Google Gemini Resources:**
- [Firebase AI Logic Documentation](https://firebase.google.com/docs/ai-logic)
- [Imagen 3 Integration Guide](https://firebase.blog/posts/2025/03/imagen3-support-on-vertex-ai-sdks/)
- [Gemini API Cookbook](https://github.com/google-gemini/cookbook)
- [REST API Quickstarts](https://github.com/google-gemini/cookbook/tree/main/quickstarts/rest/)

**Example Projects:**
- [Veo 3 & Nano Banana Quickstart](https://github.com/google-gemini/veo-3-nano-banana-gemini-api-quickstart) - Full-stack image/video generation demo
- [Gemini Image Editing Quickstart](https://github.com/google-gemini/gemini-image-editing-nextjs-quickstart) - Native image generation with Gemini 2.0

**API Authentication:**
- [Get API Key from Google AI Studio](https://aistudio.google.com/app/apikey)
- [Postman Workspace for Gemini APIs](https://www.postman.com/ai-on-postman/google-gemini-apis/overview)

## Advanced Features (Future Iterations)

1. **Filter by chapter range**
   ```bash
   storyboard-extractor screenplay.fountain --chapters 5-10
   ```

2. **Filter by location pattern**
   ```bash
   storyboard-extractor screenplay.fountain --location "INT.*COFFEE"
   ```

3. **Template-based prompt enhancement**
   ```bash
   storyboard-extractor screenplay.fountain --template cinematic.txt
   ```

   Template example:
   ```
   LOCATION: {location}
   STYLE: Cinematic, high contrast lighting, 35mm film aesthetic
   PROMPT: {original_prompt}
   ADDITIONAL: Detailed foreground, bokeh background, rule of thirds composition
   ```

4. **Batch processing**
   ```bash
   storyboard-extractor *.fountain --output-dir ./all-storyboards/
   ```

5. **Interactive mode**
   ```bash
   storyboard-extractor screenplay.fountain --interactive
   # Allows reviewing/editing prompts before generation
   ```

## Testing Strategy

1. **Unit tests** for LocationTracker
   - Test location extraction from various SLUGLINE formats
   - Test location state persistence across elements

2. **Integration tests** for full pipeline
   - Use test screenplay fixtures with known STORYBOARD elements
   - Verify correct prompt count and location associations

3. **Edge case tests**
   - Screenplay with no STORYBOARD elements
   - STORYBOARD before first SLUGLINE
   - Multiple consecutive STORYBOARD elements

4. **Export tests**
   - Verify JSON structure
   - Verify CSV escaping
   - Verify text file naming and content

## Performance Considerations

- **In-memory SwiftData**: No persistent storage needed for CLI
- **Streaming output**: For large screenplays (>1000 elements), stream results to disk
- **Progress reporting**: For long-running operations, show progress indicator
- **Memory management**: Release document after processing to avoid holding large screenplays in memory

## Documentation Updates Needed

1. Update `README.md` with CLI usage section
2. Add example screenplay with STORYBOARD markers to Fixtures/
3. Create `Docs/STORYBOARD_CLI_GUIDE.md` with user-facing documentation
4. Update `CHANGELOG.md` when releasing CLI feature

## Next Steps

After reviewing this pseudocode:
1. Implement `StoryboardPrompt.swift` data structure
2. Implement `LocationTracker.swift` helper class
3. Implement `main.swift` with core algorithm
4. Add executable target to `Package.swift`
5. Write unit tests for location tracking logic
6. Write integration test with sample screenplay
7. Document CLI usage patterns
