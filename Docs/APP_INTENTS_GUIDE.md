# App Intents Guide

Complete guide to using SwiftCompartido's App Intents for Shortcuts integration.

## Overview

SwiftCompartido provides two App Intents for screenplay parsing and querying via Apple Shortcuts:

1. **ParseScreenplayFileIntent** - Parse screenplay files and extract elements
2. **QueryScreenplayElementsIntent** - Query elements from previously parsed documents

Both intents return a `ScreenplayElementsReference` that can be chained to downstream actions like voice generation, analysis, or export.

## Requirements

- iOS 26.0+ or macOS 26.0+
- SwiftCompartido 6.1+
- Shortcuts app (included with iOS/macOS)

## Quick Start

### 1. Parse a Screenplay File

**Intent**: `ParseScreenplayFileIntent`

**What it does**: Parses a screenplay file (Fountain, FDX, PDF, Markdown) and returns structured elements.

**Parameters**:
- `fileURL` (required): The screenplay file to parse
- `elementTypes` (optional): Filter to specific element types (dialogue, action, scene headings, etc.)
- `chapterIndex` (optional): Filter to a specific chapter (0-based)
- `searchText` (optional): Filter to elements containing specific text

**Returns**: `ScreenplayElementsReference` with parsed elements

**Example Shortcut**:
```
1. Get File (select screenplay file)
2. Parse Screenplay File
   - File: [File from step 1]
   - Filter Element Types: Dialogue
3. Show Result
```

### 2. Query Existing Document

**Intent**: `QueryScreenplayElementsIntent`

**What it does**: Queries elements from a document that's already been parsed and stored.

**Parameters**:
- `documentIDString` (required): The document ID from a previous parse
- `elementTypes` (optional): Filter to specific element types
- `chapterIndex` (optional): Filter to specific chapter
- `characterName` (optional): Filter dialogue by character name
- `searchText` (optional): Filter by text content

**Returns**: `ScreenplayElementsReference` with filtered elements

**Example Shortcut**:
```
1. Parse Screenplay File (returns reference)
2. Query Screenplay Elements
   - Document ID: [documentID from step 1]
   - Filter Element Types: Dialogue
   - Character Name: EDWARD
3. Show Result
```

## Voice Commands (Siri)

SwiftCompartido registers the following voice commands:

### Parse Screenplay
- "Import screenplay with SwiftCompartido"
- "Parse screenplay file in SwiftCompartido"
- "Parse a screenplay in SwiftCompartido"
- "Import a script with SwiftCompartido"

### Query Elements
- "Query screenplay elements in SwiftCompartido"
- "Get screenplay dialogue in SwiftCompartido"
- "Search screenplay in SwiftCompartido"
- "Find screenplay elements in SwiftCompartido"

**Usage**:
```
User: "Import screenplay with SwiftCompartido"
Siri: [Opens file picker]
User: [Selects bigfish.fountain]
Siri: "Parsed 1,247 elements from Big Fish"
```

## Element Types

SwiftCompartido supports these element types for filtering:

| Type | ID | Description |
|------|-----|-------------|
| Scene Heading | `sceneHeading` | Scene headers (INT./EXT.) |
| Action | `action` | Action lines |
| Character | `character` | Character name cues |
| Dialogue | `dialogue` | Character dialogue |
| Parenthetical | `parenthetical` | Dialogue parentheticals |
| Transition | `transition` | Scene transitions |
| Lyrics | `lyrics` | Song lyrics |

**Filter Example**:
```
Parse Screenplay File
  - Filter Element Types: [Dialogue, Character]
  → Returns only dialogue and character name elements
```

## ScreenplayElementsReference

The reference object returned by both intents contains:

### Properties

```swift
// Document metadata
documentID: PersistentIdentifier  // Unique document identifier
documentTitle: String?             // Screenplay title
documentFilename: String?          // Source filename
elementCount: Int                  // Total elements in reference

// Computed properties
characterNames: [String]           // All unique character names (sorted)
dialogueCount: Int                 // Count of dialogue elements
sceneCount: Int                    // Count of scene headings
```

### Methods

```swift
// Count dialogue for a specific character
dialogueCount(for character: String) -> Int

// Filter elements by type
elements(ofTypes types: [ElementType]) -> [ElementReference]

// Filter elements by chapter
elements(inChapter chapterIndex: Int) -> [ElementReference]
```

## Common Workflows

### 1. Voice Generation Workflow

**Goal**: Parse screenplay, extract dialogue, generate audio for each line.

```
1. Get File (screenplay.fountain)
2. Parse Screenplay File
   - File: [File from step 1]
   - Filter Element Types: Dialogue
3. Repeat with Each (element in reference.elements)
   - Generate Voice Audio
     - Text: element.elementText
     - Voice: [Map element.characterName to voice]
   - Save File
```

**Voice Assignment**:
```swift
// Use reference.characterNames to assign voices before generation
let characters = reference.characterNames  // ["EDWARD", "WILL", "SANDRA"]

// Map each character to a voice ID
let voiceMap = [
  "EDWARD": "voice-1234",
  "WILL": "voice-5678",
  "SANDRA": "voice-9012"
]

// Generate audio for each dialogue element
for element in reference.elements where element.isDialogue {
  let voiceID = voiceMap[element.characterName ?? ""]
  generateAudio(text: element.elementText, voice: voiceID)
}
```

### 2. Scene Analysis Workflow

**Goal**: Extract all scene headings and count elements per scene.

```
1. Get File (screenplay.fountain)
2. Parse Screenplay File
   - File: [File from step 1]
3. Show Result
   - Scene Count: reference.sceneCount
   - Total Elements: reference.elementCount
```

### 3. Character Dialogue Export

**Goal**: Extract all dialogue for a specific character.

```
1. Get File (screenplay.fountain)
2. Parse Screenplay File
   - File: [File from step 1]
3. Query Screenplay Elements
   - Document ID: [documentID from step 2]
   - Filter Element Types: Dialogue
   - Character Name: EDWARD
4. Combine Text (join all element.elementText with newlines)
5. Save to File
```

### 4. Chapter-by-Chapter Processing

**Goal**: Process screenplay one chapter at a time.

```
1. Get File (screenplay.fountain)
2. Parse Screenplay File
   - File: [File from step 1]
3. Repeat with Each (chapter index 0...N)
   - Query Screenplay Elements
     - Document ID: [documentID from step 2]
     - Chapter Index: [current index]
   - Process Chapter Elements
   - Save Results
```

## Supported File Formats

SwiftCompartido automatically detects and parses these formats:

| Format | Extension | Notes |
|--------|-----------|-------|
| Fountain | `.fountain` | Industry-standard plain text format |
| Final Draft | `.fdx` | XML-based Final Draft format |
| PDF | `.pdf` | AI-powered extraction (iOS 26+) |
| Markdown | `.md`, `.markdown` | With YAML front matter support |
| Highland | `.highland` | ZIP archive containing Fountain |
| TextBundle | `.textbundle` | Bundle format with metadata |

**No parser parameter required** - format detection is automatic based on file extension.

## Error Handling

### Common Errors

**1. File Not Found**
```
Error: File does not exist at path
Solution: Verify file path is correct and file exists
```

**2. Unsupported Format**
```
Error: Unsupported file format
Solution: Check file extension matches supported formats
```

**3. Parse Error**
```
Error: Failed to parse screenplay
Solution: Verify file is valid screenplay format
```

**4. Invalid Document ID**
```
Error: Document ID is invalid or cannot be parsed
Solution: Ensure documentID comes from a previous parse operation
```

### Error Handling in Shortcuts

```
1. Parse Screenplay File
   - File: [input file]
   - If Error: Show Alert "Failed to parse: [error message]"
2. Continue with elements...
```

## Performance Considerations

### Parsing Performance

| Element Count | Parse Time | Convert to SwiftData |
|---------------|------------|----------------------|
| 1,000 | ~0.016s | ~1.1s |
| 5,000 | ~0.072s | ~23.7s |

**Recommendation**: For large screenplays (5000+ elements), consider:
1. Parsing once and storing the documentID
2. Using QueryScreenplayElementsIntent for subsequent queries
3. Filtering during parse to reduce element count

### Memory Usage

- **Small screenplays** (< 1000 elements): ~5-10 MB
- **Large screenplays** (5000+ elements): ~50-100 MB

**Recommendation**: Process in chunks using chapter filtering for very large documents.

## Programmatic Usage

While intents are designed for Shortcuts, you can also execute them programmatically:

```swift
import SwiftCompartido
import AppIntents

@MainActor
func parseScreenplay(at url: URL) async throws -> ScreenplayElementsReference {
    var intent = ParseScreenplayFileIntent()
    intent.fileURL = url
    intent.elementTypes = [ElementTypeEntity(id: "Dialogue", elementType: .dialogue)]

    let result = try await intent.perform()
    return result.value
}

@MainActor
func queryElements(documentID: PersistentIdentifier, character: String) async throws -> ScreenplayElementsReference {
    // Note: PersistentIdentifier must be encoded to string
    let encoder = JSONEncoder()
    let data = try encoder.encode(documentID)
    let idString = String(data: data, encoding: .utf8)!

    let intent = QueryScreenplayElementsIntent(
        documentIDString: idString,
        elementTypes: [ElementTypeEntity(id: "Dialogue", elementType: .dialogue)],
        chapterIndex: nil,
        characterName: character,
        searchText: nil
    )

    let result = try await intent.perform()
    return result.value
}
```

## Advanced Usage

### Custom Element Processing

Process elements with custom logic:

```swift
let reference = try await parseScreenplay(at: fileURL)

// Group dialogue by character
var dialogueByCharacter: [String: [String]] = [:]
for element in reference.elements where element.isDialogue {
    let character = element.characterName ?? "UNKNOWN"
    dialogueByCharacter[character, default: []].append(element.elementText)
}

// Analyze dialogue patterns
for (character, lines) in dialogueByCharacter {
    let totalWords = lines.joined(separator: " ").split(separator: " ").count
    print("\(character): \(lines.count) lines, \(totalWords) words")
}
```

### Caching Strategies

For repeated queries, cache the documentID:

```swift
// First parse - cache the ID
let reference = try await parseScreenplay(at: fileURL)
UserDefaults.standard.set(reference.documentID.description, forKey: "lastDocumentID")

// Subsequent queries - reuse cached ID
if let idString = UserDefaults.standard.string(forKey: "lastDocumentID") {
    let dialogueReference = try await queryElements(
        documentIDString: idString,
        elementTypes: [.dialogue]
    )
}
```

## Troubleshooting

### Issue: "Intent not found in Shortcuts"

**Solution**: Ensure SwiftCompartido is linked to your app target and `SwiftCompartidoShortcuts` is registered.

```swift
// In your app's main entry point
import SwiftCompartido

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Issue: "No elements returned from query"

**Checklist**:
1. Verify document was successfully parsed (check elementCount > 0)
2. Check filter parameters aren't too restrictive
3. Verify character names match exactly (case-sensitive)
4. Check searchText is spelled correctly

### Issue: "Slow performance on large screenplays"

**Solutions**:
1. Filter during parse (use elementTypes parameter)
2. Process by chapter (use chapterIndex parameter)
3. Cache parsed documentID and use QueryScreenplayElementsIntent
4. Consider splitting very large screenplays into multiple files

## Best Practices

### 1. Filter Early
Apply filters during parsing, not after:
```
✅ Good: Parse with elementTypes filter
❌ Bad: Parse all, then filter in Shortcuts
```

### 2. Reuse Document IDs
Parse once, query many times:
```
✅ Good: Parse → Save documentID → Query multiple times
❌ Bad: Re-parse file for each query
```

### 3. Handle Errors Gracefully
Always include error handling:
```
1. Parse Screenplay File
2. If Error: Show Alert + Exit
3. Continue processing...
```

### 4. Use Computed Properties
Leverage reference properties instead of manual iteration:
```
✅ Good: reference.characterNames
❌ Bad: Loop through elements to extract character names
```

### 5. Validate Input Files
Check file format before parsing:
```
1. Get File
2. If Extension is not [.fountain, .fdx, .pdf]: Show Alert
3. Parse Screenplay File
```

## API Reference

See `PARSED_FILE_SERVICE_API.md` for complete API documentation.

## Examples

See `Tests/SwiftCompartidoTests/AppIntents/` for example usage in tests.

## Support

For issues or questions:
- GitHub Issues: https://github.com/intrusive-memory/SwiftCompartido/issues
- Documentation: https://github.com/intrusive-memory/SwiftCompartido/tree/main/Docs

## Version History

- **6.1.0**: Initial App Intents implementation
  - ParseScreenplayFileIntent
  - QueryScreenplayElementsIntent
  - ScreenplayElementsReference
  - SwiftCompartidoShortcuts (Siri integration)
