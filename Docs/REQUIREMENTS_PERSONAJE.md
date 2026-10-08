---
type: requirements
state: draft
updated: 2026-10-03
origin: intrusive-memory/Personaje @ 74721c3 (docs/REQUIREMENTS-APP-UI.md §11; RECON_REPORT.md; boundary decisions 2026-10-03)
sequence: 1 — no dependencies; SwiftReparto's discovery writer and Personaje's last build step wait on it
---

# SwiftCompartido — what Personaje needs

**Decided 2026-10-03: cast discovery belongs here.** Once a screenplay is
parsed, SwiftCompartido is the one place that says who speaks, how much and
where. SwiftEchada's `generate cast` is being removed. SwiftReparto reads this
library's database and writes what it finds to CAST.md; it does no discovery of
its own. Personaje queries the same database for the script excerpts that go
into its generation prompts.

This fits the library's first mission (parsing and storage). It adds no UI.

This file replaces two earlier drafts: the Personaje-derived requirements
(CP-P1 to CP-P7, kept here in full) and the voice-casting specification
committed in `b0bd600`. What the second one described mostly exists already;
see "Already in the library" and "Not carried over".

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| CP-P1 | **Speaker on every dialogue element.** `GuionElementModel` records the cleaned speaker name on each dialogue (and parenthetical) element at parse time. Today the speaker is found by walking back to the nearest character cue (`findMostRecentCharacter`), so no SwiftData predicate can select a character's lines. | Decision 2026-10-03 |
| CP-P2 | **The character collection.** One call returns every speaking character in the store with metadata: dialogue line count, word count, the scenes they speak in, the episodes they appear in, and their first line. It spans every document in the store, so a ten-episode series gives one collection. A character is a cue that has dialogue. | APP-UI §11.1, UD14 |
| CP-P3 | **A character's lines** as a SwiftData query on the speaker field, in script order. | Decision 2026-10-03 |
| CP-P4 | **Scenes a character speaks in, complete.** Every scene in which the character has dialogue, with all of its elements in order. | APP-UI §11.3 (major tier) |
| CP-P5 | **Lines with neighbours.** Each of a character's lines with the N elements before and after it (N = 3 in Personaje), clipped to the scene, with overlapping windows merged. An element is one dialogue block, narrator block or action paragraph, labelled with its speaker. | APP-UI §11.3 (minor tier), §11.6 |
| CP-P6 | Results are deterministic and in script order (document, then scene, then `orderIndex`), so the same scripts give the same prompt. | APP-UI §11.4 |
| CP-P7 | The names in CP-P2 are the screenplay's cue with extensions removed (`(V.O.)`, `(CONT'D)`), as `cleanCharacterName` does today. Uppercasing and NFC normalization are SwiftReparto's `canonicalName`, not this library's. | REQUIREMENTS §1.1; Reparto RQ-22 |

Dual dialogue counts for each speaker separately. Unnamed cues (`BARTENDER`,
`COP #1`) are characters like any other.

## What this library does not do

- Write CAST.md, or link SwiftReparto.
- Read or write PROJECT.md, or link SwiftProyecto. SwiftProyecto v5 removed
  its cast surface; the cast list is CAST.md, and SwiftReparto owns it.
- Decide that two different names are the same person. Alias merging is a
  review step in Personaje.
- Decide who is major or minor. It returns counts; the thresholds are
  Personaje's (UD19).
- Generate voices, or hold character biography, backstory or relationships.
- Add UI for any of the above.

## Already in the library (do not rebuild)

Checked at `b0bd600`. Paths are under `Sources/SwiftCompartido/`.

- **Per-screenplay extraction.** `extractCharacters() -> CharacterList` on
  `GuionParsedElementCollection` (`Sendable/GuionParsedScreenplay+Characters.swift:32`)
  and on `GuionDocumentModel` (`GuionDocument.swift:363`). `CharacterList` is
  `[String: CharacterInfo]`; `CharacterInfo` has `color`, `counts` (`lineCount`,
  `wordCount`), `gender` and `scenes: [Int]` (`Sendable/CharacterInfo.swift:29`).
  One screenplay per call. CP-P2 is the store-wide version of this.
- **Name cleaning.** `cleanCharacterName` (`…+Characters.swift:100`) and
  `findMostRecentCharacter` (`:115`) are both `private`.
- **`GuionElementModel`** has `orderIndex`, `sceneId`, `chapterIndex`,
  `elementType`, `elementText` and `document`. It has no speaker field.
- **Voice casting, per document.** `CharacterVoiceMapping` is a `@Model` in
  schema V1 and V2 (`SwiftDataModels/CharacterVoiceMapping.swift:56`) with
  `characterName`, `voiceURI` (`<provider>://<voiceId>?lang=<code>`),
  `voiceName`, `providerID` and `document`.
- **App Intents.** `ExtractCharactersIntent`, `GetVoiceCastingIntent` and
  `SetVoiceCastingIntent` exist (`AppIntents/ExtractCharactersIntent.swift:30`,
  `AppIntents/VoiceCastingIntents.swift:27`, `:127`). Each takes one
  `documentIDString`.
- **`DocumentModelActor`** (`Actors/DocumentModelActor.swift:53`) has parse,
  info, delete, element and existence methods. It has no character or voice
  methods.
- The parse works in memory; SwiftData is optional (`FountainParser.swift:89-121`).
- No public neighbour, window or adjacency query exists.

## Not carried over from the `b0bd600` draft

| Item in that draft | Why it is not here |
|--------------------|--------------------|
| `CharacterVoiceMapping` with `voiceProvider`, `voiceIdentifier`, `displayName`, `createdAt`, `lastUsed` | The model exists with a different shape (`voiceURI`, `voiceName`, `providerID`). The draft described it as new work; changing it is a schema migration nobody asked for. |
| `DocumentModelActor.extractCharacters`, `setVoice`, `clearVoice`, `getVoiceCasting`, `importVoiceCasting` | Per-document extraction exists elsewhere. The voice methods are a second door onto what the two voice intents already do, and Personaje's voice assignments live in CAST.md (`voices`), not here. |
| A new `CharacterInfo` (`dialogueCount`, `firstAppearance`, `assignedVoice`) | A public `CharacterInfo` already exists with a different shape. CP-P2's metadata is specified above. |
| Names "normalized, uppercase" | Contradicts CP-P7: uppercasing is SwiftReparto's. |
| App Intents taking a screenplay file URL; `VoiceProviderEnum` | The intents exist and take a document ID. |
| `CharacterVoiceConfigurationView`, `CharacterListRowView`, `VoiceProviderPickerView` | This work adds no UI. Voice selection is Personaje's Voice tab. |
| SwiftProyecto integration (`ProjectDiscovery().readCast`) | That API was removed in SwiftProyecto v5. `CastListPage.swift:59` still tells callers to use `SwiftProyecto.CastMember`; see Open. |
| Performance, accessibility, localization and security sections | They belonged to the UI and voice API above. CP-P6 is the only ordering or determinism requirement here. |

The full text of that draft is in git at `b0bd600`.

## Acceptance

1. On Granville (10 episodes), CP-P2 returns the 23 speaking characters besides
   the narrator, and each line count equals the sum of the per-episode
   `extractCharacters()` counts.
2. The full-scene query for HUNTER returns only scenes in which HUNTER speaks,
   each complete.
3. The ±3 query for a character with two lines four elements apart returns one
   merged window, not two. No window crosses a scene boundary.
4. A store parsed before CP-P1 either migrates or re-parses; it never returns
   an empty result silently.
5. `CharacterVoiceMapping` and the three existing intents behave as they do at
   `b0bd600`.

## Depends on

Nothing.

## Blocks

- **SwiftReparto** discovery writer (hard): it reads CP-P2.
- **Personaje** building CAST.md from scripts and Auto-generate (hard):
  CP-P2 to CP-P5.

## Schema Migration Policy

**Null properties are assumed defaults.** When adding new stored properties to SwiftData models, existing records will have null values after migration. This is acceptable — we do not backfill or require complete data across all schema versions. Character descriptions and other derived data may be incomplete for records created before a schema version added a field.

CP-P1 adds `speaker: String?` to `GuionElementModel` via SwiftCompartidoSchemaV3. Existing records migrated from V2 will have null speaker values. Only newly parsed content will populate the field.

## Open

- **In-memory or persistent store?** Recommended: Personaje parses on open into
  an in-memory container. A persistent store goes stale whenever an episode is
  edited in Escribir and would need change detection. This is the caller's
  choice; the queries work on either.
- **How SwiftReparto reads CP-P2 without linking this library.** Reparto may
  not depend on any `intrusive-memory` package (its RQ-INV-1), so the
  discovery writer cannot live in the SwiftReparto package. Either it lives in
  a package that links both, or CP-P2's result is also available as a plain
  `Codable` value that can cross as a file. Recommended: make the CP-P2 result
  `Codable` and `Sendable` either way.
- **Stale pointer.** `CastListPage.CastMember`'s deprecation message names
  `SwiftProyecto.CastMember`, which no longer exists. Recommended: point it at
  SwiftReparto's CAST.md in the same release. Text only; no dependency.
- **Does any voice-casting work belong in this mission?** This file says no.
  If the voice API or views in the `b0bd600` draft are wanted, they are a
  separate requirements file.

## Note on release ripple

SwiftProyecto and SwiftVinetas both link SwiftCompartido. The API is additive,
but CP-P1 changes a model, so treat it as a minor release with a migration note,
not a patch.
