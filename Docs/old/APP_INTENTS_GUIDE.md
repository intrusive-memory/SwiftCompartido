# App Intents Guide

Complete guide to using SwiftCompartido's App Intents for Shortcuts integration.

## Overview

SwiftCompartido provides six App Intents for screenplay parsing, querying, export, and voice casting via Apple Shortcuts:

### Import & Query
1. **ParseScreenplayFileIntent** - Parse screenplay files and extract elements
2. **QueryScreenplayElementsIntent** - Query elements from previously parsed documents

### Export
3. **ExportScreenplayIntent** - Export screenplays to Fountain, FDX, or .guion JSON

### Character & Voice Casting
4. **ExtractCharactersIntent** - Extract character list with dialogue counts
5. **GetVoiceCastingIntent** - Retrieve character voice assignments
6. **SetVoiceCastingIntent** - Assign voices to characters

These intents enable complete screenplay workflows including parsing, querying, format conversion, and audio generation setup.

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

## New Intents (6.2.0+)

### 3. Export Screenplay

**Intent**: `ExportScreenplayIntent`

**What it does**: Exports a parsed screenplay to Fountain, FDX, or .guion JSON format.

**Parameters**:
- `documentIDString` (required): The document ID from a previous parse
- `exportFormat` (required): Target format (Fountain, FDX, or .guion JSON)
- `outputFilename` (optional): Custom filename (without extension)

**Returns**: `IntentFile` with the exported screenplay

**Example Shortcut**:
```
1. Parse Screenplay File (returns reference)
2. Export Screenplay
   - Document ID: [documentID from step 1]
   - Export Format: Final Draft (FDX)
   - Output Filename: "my_script"
3. Save File
```

**Supported Export Formats**:
| Format | Description | Extension |
|--------|-------------|-----------|
| Fountain | Plain text screenplay format | .fountain |
| Final Draft (FDX) | Final Draft XML format | .fdx |
| .guion JSON | SwiftCompartido JSON format with metadata | .guion |

**Use Cases**:
- Convert Fountain to FDX for Final Draft import
- Export to .guion for archiving with AI-generated content
- Share screenplays in industry-standard formats

### 4. Extract Characters

**Intent**: `ExtractCharactersIntent`

**What it does**: Extracts the complete list of characters from a screenplay, with optional dialogue counts.

**Parameters**:
- `documentIDString` (required): The document ID from a previous parse
- `includeDialogueCount` (optional): Include dialogue line counts (default: true)

**Returns**: `CharacterListReference` with character data

**Example Shortcut**:
```
1. Parse Screenplay File (script.fountain)
2. Extract Characters
   - Document ID: [documentID from step 1]
   - Include Dialogue Count: Yes
3. Show Result → Character list with counts
```

**CharacterListReference Properties**:
```swift
characterCount: Int          // Total number of characters
characterNames: [String]     // Sorted character names
characters: [CharacterReference]  // Full character data
```

**CharacterReference Properties**:
```swift
name: String                 // Character name (e.g., "JANE")
aliases: [String]            // Alternative names
dialogueCount: Int?          // Number of dialogue lines (optional)
```

**Use Cases**:
- Prepare voice assignment list before audio generation
- Analyze character presence in screenplay
- Generate casting sheets

### 5. Get Voice Casting

**Intent**: `GetVoiceCastingIntent`

**What it does**: Retrieves all character→voice assignments from a screenplay document.

**Parameters**:
- `documentIDString` (required): The document ID

**Returns**: `VoiceCastingReference` with all voice mappings

**Example Shortcut**:
```
1. Get Voice Casting
   - Document ID: [documentID]
2. Show Result → List of character voice assignments
```

**VoiceCastingReference Properties**:
```swift
mappingCount: Int                    // Total number of assignments
assignedCharacters: [String]         // Characters with voices (sorted)
mappings: [VoiceMappingReference]    // Full mapping data
```

**VoiceMappingReference Properties**:
```swift
characterName: String    // Character name (e.g., "JANE")
voiceURI: String        // Voice identifier (e.g., "macos://Samantha")
voiceName: String       // Human-readable name (e.g., "Samantha")
providerID: String      // Provider (e.g., "macos", "elevenlabs")
```

**Voice URI Formats**:
- **macOS System**: `macos://VoiceName` (e.g., `macos://Samantha`)
- **ElevenLabs**: `elevenlabs://voice-id` (e.g., `elevenlabs://21m00Tcm4TlvDq8ikWAM`)
- **OpenAI**: `openai://voice-name` (e.g., `openai://alloy`)

**Use Cases**:
- Review current voice assignments before audio generation
- Export voice casting for documentation
- Verify all characters have assigned voices

### 6. Set Voice Casting

**Intent**: `SetVoiceCastingIntent`

**What it does**: Assigns a voice to a character in the screenplay document.

**Parameters**:
- `documentIDString` (required): The document ID
- `characterName` (required): Character to assign voice to (e.g., "JANE")
- `voiceURI` (required): Voice identifier (e.g., "macos://Samantha")
- `voiceName` (required): Human-readable name (e.g., "Samantha")
- `providerID` (required): Provider ID (e.g., "macos", "elevenlabs", "openai")

**Returns**: Confirmation message

**Example Shortcut**:
```
1. Extract Characters
2. For each character:
   - Ask user: "Select voice for [character]"
   - Set Voice Casting
     - Character Name: [character name]
     - Voice URI: [selected voice URI]
     - Voice Name: [selected voice name]
     - Provider ID: [provider]
3. Show Result → "Voice casting complete"
```

**Behavior**:
- Creates new mapping if character doesn't have one
- Updates existing mapping if character already has a voice
- Persists to SwiftData immediately

**Use Cases**:
- Assign voices before audio generation workflow
- Update voice assignments for re-recording
- Batch-assign voices to multiple characters

## Advanced Workflows

### Complete Audio Generation Pipeline

**Goal**: Parse screenplay, assign voices, generate audio for all dialogue

```
1. Get File (screenplay.fountain)
2. Parse Screenplay File
   - File: [File from step 1]
   → documentID

3. Extract Characters
   - Document ID: [documentID]
   → characterList

4. For each character in characterList:
   - Ask user: "Select voice for [character.name]"
   - Set Voice Casting
     - Document ID: [documentID]
     - Character Name: [character.name]
     - Voice URI: [selected voice URI]
     - Voice Name: [selected voice name]
     - Provider ID: [provider]

5. Query Screenplay Elements
   - Document ID: [documentID]
   - Filter Element Types: Dialogue
   → dialogueElements

6. Get Voice Casting
   - Document ID: [documentID]
   → voiceCasting

7. For each dialogue in dialogueElements:
   - Get voice for dialogue.characterName from voiceCasting
   - Generate Voice Audio
     - Text: dialogue.elementText
     - Voice: [voiceURI from casting]
   - Save File
```

### Format Conversion Workflow

**Goal**: Convert Fountain screenplay to Final Draft format

```
1. Get File (screenplay.fountain)
2. Parse Screenplay File
   - File: [File from step 1]
   → documentID

3. Export Screenplay
   - Document ID: [documentID]
   - Export Format: Final Draft (FDX)
   - Output Filename: "screenplay_fdx"
   → exported file

4. Save File (screenplay.fdx)
```

### Character Analysis Workflow

**Goal**: Generate character dialogue statistics

```
1. Parse Screenplay File
   → documentID

2. Extract Characters
   - Document ID: [documentID]
   - Include Dialogue Count: Yes
   → characterList

3. For each character in characterList:
   - Query Screenplay Elements
     - Document ID: [documentID]
     - Filter Element Types: Dialogue
     - Character Name: [character.name]
     → characterDialogue

   - Count Words in characterDialogue
   - Calculate average words per line
   - Log results
```

## Voice Commands (Siri) - Updated

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

### Export Screenplay (NEW)
- "Export screenplay with SwiftCompartido"
- "Convert screenplay in SwiftCompartido"
- "Save screenplay as in SwiftCompartido"

### Extract Characters (NEW)
- "Extract characters in SwiftCompartido"
- "Get character list from SwiftCompartido"
- "List characters in SwiftCompartido"

### Get Voice Casting (NEW)
- "Get voice casting in SwiftCompartido"
- "Show voice assignments in SwiftCompartido"
- "List voice casting in SwiftCompartido"

### Set Voice Casting (NEW)
- "Set voice casting in SwiftCompartido"
- "Assign voice in SwiftCompartido"
- "Map character voice in SwiftCompartido"

## API Reference

See `PARSED_FILE_SERVICE_API.md` for complete API documentation.

## Examples

See `Tests/SwiftCompartidoTests/AppIntents/` for example usage in tests.

## Support

For issues or questions:
- GitHub Issues: https://github.com/intrusive-memory/SwiftCompartido/issues
- Documentation: https://github.com/intrusive-memory/SwiftCompartido/tree/main/Docs

## Version History

- **6.2.0**: Export and Voice Casting Intents (NEW)
  - ExportScreenplayIntent - Export to Fountain/FDX/.guion
  - ExtractCharactersIntent - Character list extraction
  - GetVoiceCastingIntent - Retrieve voice assignments
  - SetVoiceCastingIntent - Assign voices to characters
  - Updated SwiftCompartidoShortcuts with new voice commands

- **6.1.0**: Initial App Intents implementation
  - ParseScreenplayFileIntent
  - QueryScreenplayElementsIntent
  - ScreenplayElementsReference
  - SwiftCompartidoShortcuts (Siri integration)
