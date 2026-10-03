---
type: reference
updated: 2026-10-03
---

# Personaje (Character) Requirements

## Purpose

Define character-related functionality in SwiftCompartido, including character extraction from screenplays, voice casting assignments, and integration with external cast management systems.

## Scope

**In Scope:**
- ✅ Character voice mapping data model
- ✅ Character extraction from screenplay elements
- ✅ Voice assignment per character
- ✅ App Intents for character workflows
- ✅ Integration with SwiftProyecto for cast management

**Out of Scope:**
- ❌ AI voice generation (belongs in consumer apps)
- ❌ Character biography or backstory management
- ❌ Character relationship graphs
- ❌ Cloud-synced cast lists (removed in 6.2.1)

## Platform Requirements

- **iOS**: 26.0+
- **macOS**: 26.0+
- **Swift**: 6.2+
- **SwiftData**: System framework
- **SwiftUI**: For configuration UI

## Core Components

### 1. CharacterVoiceMapping Model

**Purpose**: SwiftData model linking screenplay characters to TTS voice configurations

**Schema:**
```swift
@Model
final class CharacterVoiceMapping {
    var characterName: String        // Character name from screenplay (e.g., "JANE")
    var voiceProvider: String        // Provider ID ("macos", "elevenlabs", "openai")
    var voiceIdentifier: String      // Provider-specific voice ID
    var displayName: String?         // Human-readable voice name
    var createdAt: Date
    var lastUsed: Date?
    
    // Relationship
    var document: GuionDocumentModel?  // Parent document
}
```

**Indexes:**
- Primary: `characterName` + `document` (unique constraint)
- Secondary: `voiceProvider`

**Relationships:**
```
GuionDocumentModel (1) ──┬─→ CharacterVoiceMapping (N)
                         │   @Relationship(deleteRule: .cascade)
                         │
                         └─→ GuionElementModel (N)
```

**Delete Rules:**
- When document deleted → cascade delete all CharacterVoiceMapping entries

### 2. Character Extraction

**Purpose**: Extract unique character names and dialogue counts from screenplay elements

**API:**
```swift
actor DocumentModelActor {
    func extractCharacters(
        from documentID: PersistentIdentifier
    ) async throws -> [CharacterInfo]
}

struct CharacterInfo: Sendable, Identifiable {
    let id: UUID
    let name: String              // Character name (normalized, uppercase)
    let dialogueCount: Int        // Number of dialogue blocks
    let firstAppearance: Int      // Element index of first appearance
    let assignedVoice: VoiceInfo? // Current voice assignment (if any)
}

struct VoiceInfo: Sendable {
    let provider: String
    let identifier: String
    let displayName: String?
}
```

**Extraction Logic:**
1. Query all elements where `elementType == .character`
2. Normalize character names (uppercase, trim whitespace)
3. Count dialogue blocks per character
4. Track first appearance index
5. Join with CharacterVoiceMapping for voice assignments
6. Return sorted by `firstAppearance` (script order)

**Edge Cases:**
- Dual dialogue: Count separately for each character
- Character extensions (V.O., O.S., CONT'D): Strip extensions before matching
- Unnamed characters: Include as-is (e.g., "BARTENDER", "COP #1")

### 3. Voice Casting API

**Purpose**: Assign and retrieve TTS voices for characters

**API:**
```swift
actor DocumentModelActor {
    // Assign voice to character
    func setVoice(
        characterName: String,
        voiceProvider: String,
        voiceIdentifier: String,
        displayName: String?,
        for documentID: PersistentIdentifier
    ) async throws
    
    // Remove voice assignment
    func clearVoice(
        characterName: String,
        for documentID: PersistentIdentifier
    ) async throws
    
    // Get all voice assignments
    func getVoiceCasting(
        for documentID: PersistentIdentifier
    ) async throws -> [CharacterVoiceInfo]
    
    // Bulk import voice assignments
    func importVoiceCasting(
        _ mappings: [CharacterVoiceInfo],
        for documentID: PersistentIdentifier
    ) async throws
}

struct CharacterVoiceInfo: Sendable, Codable {
    let characterName: String
    let voiceProvider: String
    let voiceIdentifier: String
    let displayName: String?
}
```

**Validation:**
- `characterName`: Required, non-empty, normalized to uppercase
- `voiceProvider`: Required, one of ("macos", "elevenlabs", "openai", custom)
- `voiceIdentifier`: Required, provider-specific format
- `displayName`: Optional, for UI display

**Upsert Behavior:**
- If mapping exists for (characterName, documentID) → update
- If no mapping exists → create new
- Update `lastUsed` timestamp on every assignment

### 4. App Intents Integration

**Purpose**: Expose character workflows to Shortcuts app

**Intents:**

#### 4.1 ExtractCharactersIntent
```swift
struct ExtractCharactersIntent: AppIntent {
    static var title: LocalizedStringResource = "Extract Characters"
    static var description: IntentDescription = "Extract character list with dialogue counts from screenplay"
    
    @Parameter(title: "Screenplay File")
    var screenplayURL: URL
    
    func perform() async throws -> some IntentResult & ReturnsValue<CharacterListReference>
}
```

**Returns:**
- `CharacterListReference` with:
  - `characters: [CharacterReference]` - Full character data
  - `totalCharacters: Int` - Count of unique characters
  - `totalDialogueBlocks: Int` - Sum of all dialogue

**CharacterReference:**
```swift
struct CharacterReference: AppEntity {
    var id: UUID
    var name: String
    var dialogueCount: Int
    var firstAppearance: Int
    var hasAssignedVoice: Bool
}
```

#### 4.2 GetVoiceCastingIntent
```swift
struct GetVoiceCastingIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Voice Casting"
    static var description: IntentDescription = "Get character-to-voice assignments for screenplay"
    
    @Parameter(title: "Screenplay File")
    var screenplayURL: URL
    
    func perform() async throws -> some IntentResult & ReturnsValue<VoiceCastingReference>
}
```

**Returns:**
- `VoiceCastingReference` with:
  - `assignments: [VoiceAssignmentReference]`
  - `assignedCharacters: [String]` - Characters with voices
  - `unassignedCharacters: [String]` - Characters without voices

#### 4.3 SetVoiceCastingIntent
```swift
struct SetVoiceCastingIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Voice Casting"
    static var description: IntentDescription = "Assign TTS voice to character"
    
    @Parameter(title: "Screenplay File")
    var screenplayURL: URL
    
    @Parameter(title: "Character Name")
    var characterName: String
    
    @Parameter(title: "Voice Provider")
    var voiceProvider: VoiceProviderEnum
    
    @Parameter(title: "Voice Identifier")
    var voiceIdentifier: String
    
    func perform() async throws -> some IntentResult
}
```

**VoiceProviderEnum:**
```swift
enum VoiceProviderEnum: String, AppEnum {
    case macos = "macOS"
    case elevenlabs = "ElevenLabs"
    case openai = "OpenAI"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Voice Provider"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .macos: "macOS System Voices",
        .elevenlabs: "ElevenLabs",
        .openai: "OpenAI TTS"
    ]
}
```

### 5. SwiftProyecto Integration

**Purpose**: External cast management via PROJECT.md frontmatter

**Integration Pattern:**
```swift
import SwiftProyecto

// Consumer app reads cast from PROJECT.md
let discovery = ProjectDiscovery()
if let projectMd = discovery.findProjectMd(from: screenplayURL) {
    let cast = try discovery.readCast(from: projectMd)
    
    // Import cast as voice mappings
    let mappings = cast.map { castMember in
        CharacterVoiceInfo(
            characterName: castMember.characterName,
            voiceProvider: castMember.voiceProvider,
            voiceIdentifier: castMember.voiceIdentifier,
            displayName: castMember.displayName
        )
    }
    
    await actor.importVoiceCasting(mappings, for: documentID)
}
```

**SwiftCompartido Responsibilities:**
- ✅ Store voice mappings in SwiftData
- ✅ Provide import/export API
- ❌ Read/write PROJECT.md (consumer app responsibility)
- ❌ Manage cast biography/metadata (SwiftProyecto responsibility)

**Deprecated:**
- ~~custom-pages.json sidecar files~~ (removed in v7.0.0)
- ~~CastListPage model~~ (kept for Highland .textbundle compatibility only)

### 6. UI Components

**Purpose**: SwiftUI views for character configuration

**Components:**

#### 6.1 CharacterVoiceConfigurationView
```swift
struct CharacterVoiceConfigurationView: View {
    let documentID: PersistentIdentifier
    @State private var characters: [CharacterInfo] = []
    @State private var selectedCharacter: CharacterInfo?
    
    // Layout:
    // ┌─────────────────────────────────────┐
    // │ Characters (List)  │ Voice Config   │
    // │                    │                │
    // │ • JANE (12 lines)  │ Provider: ▼    │
    // │ • EDWARD (8 lines) │ Voice: ▼       │
    // │ • TAXI (1 line)    │ [Test] [Clear] │
    // └─────────────────────────────────────┘
}
```

**Features:**
- Split view: character list (left) + voice config (right)
- Character list sorted by first appearance
- Show dialogue count per character
- Highlight characters with assigned voices (✓ badge)
- Voice provider picker (macOS, ElevenLabs, OpenAI)
- Voice identifier picker (provider-specific)
- Test voice button (plays sample)
- Clear assignment button

#### 6.2 CharacterListRowView
```swift
struct CharacterListRowView: View {
    let character: CharacterInfo
    
    // Layout: JANE (12 lines) ✓
    //         ├─ Name + dialogue count
    //         └─ Voice assignment indicator
}
```

#### 6.3 VoiceProviderPickerView
```swift
struct VoiceProviderPickerView: View {
    @Binding var provider: String
    @Binding var identifier: String
    @Binding var displayName: String?
    
    // Conditional UI based on provider:
    // - macOS: System voice picker
    // - ElevenLabs: API-fetched voice list
    // - OpenAI: Voice model picker (alloy, echo, fable, onyx, nova, shimmer)
}
```

## Performance Requirements

### Character Extraction
- ✅ Extract 100 characters in < 100ms
- ✅ Extract 1000 characters in < 500ms
- ✅ Incremental loading for 5000+ characters

### Voice Assignment
- ✅ Set voice in < 50ms
- ✅ Bulk import 100 mappings in < 500ms
- ✅ Query all assignments in < 100ms

### Memory
- ✅ CharacterVoiceMapping: < 500 bytes per entry
- ✅ Cache character list in memory (invalidate on document change)

## Data Migration

### V1 → V2 (SwiftData Schema)
- ✅ CharacterVoiceMapping added in v6.3.0
- ✅ Lightweight migration (no data transform needed)
- ✅ Existing documents have empty casting by default

### custom-pages.json → CharacterVoiceMapping
**Migration Path (Consumer App):**
1. Read legacy custom-pages.json (if exists)
2. Extract `cast` array
3. Convert to CharacterVoiceInfo DTOs
4. Import via `importVoiceCasting()`
5. Delete custom-pages.json

**SwiftCompartido:**
- ❌ Does NOT perform migration (consumer app responsibility)
- ✅ Provides import API only

## Testing Requirements

### Unit Tests
- ✅ Character extraction accuracy (100%)
- ✅ Normalize character names with extensions (V.O., O.S., CONT'D)
- ✅ Voice assignment CRUD operations
- ✅ Upsert behavior (update existing, create new)
- ✅ Delete cascade (document deletion removes mappings)
- ✅ Empty screenplay (no characters)
- ✅ Duplicate character names (single entry)

### Integration Tests
- ✅ Extract characters → assign voices → query casting
- ✅ Import bulk mappings from SwiftProyecto
- ✅ App Intents end-to-end workflows
- ✅ Concurrent voice assignments (actor safety)

### Performance Tests
- ✅ Extract 1000 characters in < 500ms
- ✅ Bulk import 100 mappings in < 500ms
- ✅ Query 500 assignments in < 100ms

## Error Handling

### Extraction Errors
- Empty document → return empty array (not error)
- Malformed elements → skip, log warning
- Missing character names → skip, continue

### Voice Assignment Errors
- Invalid provider → throw `VoiceAssignmentError.invalidProvider`
- Empty character name → throw `VoiceAssignmentError.invalidCharacterName`
- Document not found → throw `VoiceAssignmentError.documentNotFound`
- Database write failure → propagate SwiftData error

### App Intents Errors
- File not found → IntentError with localized message
- Parsing failure → IntentError with details
- Invalid parameters → IntentError with validation message

## Security & Privacy

- ✅ Voice mappings stored locally in SwiftData (no cloud sync)
- ✅ No PII in character names (screenplay content only)
- ✅ Voice identifiers may contain API keys (consumer app responsibility to secure)
- ✅ App Intents require file access permission (sandbox enforcement)

## Documentation

### Public API Docs
- ✅ DocC documentation for CharacterVoiceMapping
- ✅ DocC documentation for DocumentModelActor character methods
- ✅ Code examples for voice assignment
- ✅ SwiftProyecto integration guide

### Internal Docs
- ✅ This REQUIREMENTS file
- ✅ APP_INTENTS_GUIDE.md (character section)
- ✅ ARCHITECTURE_SWIFTDATA.md (CharacterVoiceMapping schema)

## Future Enhancements (Not in MVP)

- Character name fuzzy matching (handle typos)
- Voice preview in UI (play sample audio)
- Voice recommendation engine (match character traits)
- Export casting to CSV/JSON
- Import casting from external formats
- Character appearance timeline visualization
- Dialogue analysis (sentiment, emotion, pacing)
- Multi-language voice support

## Non-Functional Requirements

### Accessibility
- ✅ VoiceOver support for character lists
- ✅ Keyboard navigation for voice picker
- ✅ High-contrast mode support
- ✅ Dynamic Type support

### Localization
- ✅ English (primary)
- ✅ Spanish (future)
- ✅ Localized error messages
- ✅ Localized App Intent titles/descriptions

### Compatibility
- ✅ SwiftData schema versioning
- ✅ Graceful degradation (missing SwiftProyecto)
- ✅ Backward compatibility (read-only for older schemas)

## References

### Code Locations
- Model: `Sources/SwiftCompartido/Models/CharacterVoiceMapping.swift`
- Actor: `Sources/SwiftCompartido/Actors/DocumentModelActor.swift`
- Intents: `Sources/SwiftCompartido/Intents/CharacterIntents.swift`
- UI: `Sources/SwiftCompartido/Views/Characters/`
- Tests: `Tests/SwiftCompartidoTests/CharacterTests.swift`

### External Dependencies
- SwiftProyecto: https://github.com/intrusive-memory/SwiftProyecto
- SwiftHablare: https://github.com/intrusive-memory/SwiftHablare (TTS integration)

### Related Documents
- [APP_INTENTS_GUIDE.md](APP_INTENTS_GUIDE.md) - Character & voice casting intents
- [ARCHITECTURE_SWIFTDATA.md](ARCHITECTURE_SWIFTDATA.md) - Schema relationships
- [AGENTS.md](../AGENTS.md) - Project overview and missions

## Acceptance Criteria

✅ CharacterVoiceMapping model exists with correct schema
✅ Character extraction returns accurate character list with dialogue counts
✅ Voice assignment API supports create, update, delete operations
✅ ExtractCharactersIntent works in Shortcuts app
✅ GetVoiceCastingIntent returns all assignments
✅ SetVoiceCastingIntent assigns voice successfully
✅ CharacterVoiceConfigurationView displays and edits voices
✅ 100% test coverage for character extraction logic
✅ Performance benchmarks met (< 500ms for 1000 characters)
✅ SwiftProyecto integration documented with code examples
✅ All public APIs documented with DocC

## Version History

- **v6.3.0**: Initial CharacterVoiceMapping model and App Intents
- **v7.0.0**: Deprecated custom-pages.json, recommend SwiftProyecto
- **v7.2.5**: This REQUIREMENTS document created
