---
feature_name: OPERATION ANNOTATED VAULT
starting_point_commit: c000c24665de13dae5483215a0f6ae273da44333
mission_branch: mission/annotated-vault/1
iteration: 1
---

# EXECUTION_PLAN.md — SwiftCompartido Glosa Integration (Consumer Side)

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

---

## Mission Scope

**Consumer-side integration of GlosaCore into SwiftCompartido** to parse, store, and expose glosa annotations for downstream audio and display features.

**BLOCKING EXTERNAL DEPENDENCY**: This mission requires glosa-av Phase 1 (FR1-FR4) to ship first:
- A SwiftPM-resolvable release tag of `GlosaCore` (≥v0.5.0)
- Public `GlosaInlineNotes` stripper API
- Public `compileAnnotations(fountainNotes:rawDialogueLines:)` DTO entry point
- `GlosaCore` with zero SwiftCompartido dependency (clean leaf)

**No sortie in this plan can begin until the upstream release tag exists.** The plan below assumes the blocking gate has opened.

---

## Work Units

| Work Unit | Directory | Sorties | Layer | Dependencies |
|-----------|-----------|---------|-------|-------------|
| Phase 3 — Consumer Integration | `/Users/stovak/Projects/SwiftCompartido` | 4 | 1 | none |
| Phase 4 — Schema Versioning & Migration | `/Users/stovak/Projects/SwiftCompartido` | 1 | 2 | Phase 3 |

---

## Parallelism Structure

**Critical Path**: Sortie 1 → Sortie 2 → Sortie 3 → Sortie 4 → Sortie 5 (length: 5 sorties)

**Parallel Execution Groups**: None (strict sequential execution required)

**Agent Constraints**:
- **Supervising agent**: Handles all sorties (every sortie has build/test steps)
- **Sub-agents**: None (no parallelism opportunities)

**Rationale**: Each sortie has a strict data dependency on its predecessor's output — no sorties can run concurrently.

---

## Phase 3 — Consumer Integration

### Sortie 1: Add GlosaCore dependency and verify resolution

**Priority**: 16.75 — Foundation dependency blocking all subsequent sorties

**Entry criteria**:
- [ ] First sortie — no prerequisites
- [ ] GlosaCore release tag exists (≥v0.5.0) and is SwiftPM-resolvable

**Tasks**:
1. Add `GlosaCore` to `Package.swift` dependencies using the existing `sibling(...)` helper, pinned to the upstream release tag
2. Add `GlosaCore` product to the `SwiftCompartido` target dependencies
3. Run `xcodebuild clean build -scheme SwiftCompartido -destination 'platform=macOS'` to verify resolution and compilation
4. Verify no SwiftPM cycle errors (GlosaCore must not transitively depend on SwiftCompartido)

**Exit criteria**:
- [ ] `Package.swift` contains `sibling("glosa-av", remote: "https://github.com/intrusive-memory/glosa-av.git", from: Version(0, 5, 0))`
- [ ] `GlosaCore` product is listed in target `SwiftCompartido` dependencies
- [ ] `xcodebuild build` succeeds on macOS destination
- [ ] No SwiftPM cycle errors in build output

---

### Sortie 2: Extend GuionElementModel storage for glosa annotations

**Priority**: 13.84 — Schema foundation blocking annotation pass, protocol, and migration

**Entry criteria**:
- [ ] Sortie 1 exit criteria confirmed (GlosaCore dependency resolved)

**Tasks**:
1. Add optional glosa storage fields to `GuionElementModel` (`Sources/SwiftCompartido/SwiftDataModels/GuionElementModel.swift`) using **flattened fields** (Option A):
   - `glosaSpokenText: String?` — notes-stripped prose
   - `glosaBreathOffsets: [Int]?` — unicode-scalar offsets into `glosaSpokenText`
   - `glosaBreathStrengths: [String]?` — parallel to `glosaBreathOffsets`, raw BreathStrength values
   - `glosaInstruct: String?` — composed performance direction
   - `glosaPausePoints: Data?` — encoded `[PausePointDTO]`
2. Keep `elementText` unchanged (raw, with `[[ ]]` markers) for lossless export
3. Add private local DTO mirrors for `PausePointDTO` if decoupling from GlosaCore's concrete types (or re-export if acceptable)
4. Verify the model compiles with `xcodebuild build -scheme SwiftCompartido -destination 'platform=macOS'`
5. Update any existing tests that construct `GuionElementModel` to pass `nil` for new fields (preserve existing behavior)

**Exit criteria**:
- [ ] `GuionElementModel.swift` contains five new optional glosa fields (flattened)
- [ ] `elementText` field is unchanged
- [ ] Local `PausePointDTO` mirror exists (or GlosaCore type is re-exported)
- [ ] `xcodebuild build` succeeds
- [ ] Existing `SwiftCompartidoTests` pass without modification (new fields default to `nil`)

---

### Sortie 3: Implement annotation pass in DocumentModelActor

**Priority**: 12.17 — High-risk external API integration blocking protocol and migration

**Entry criteria**:
- [ ] Sortie 2 exit criteria confirmed (storage fields exist)
- [ ] GlosaCore public API available (`compileAnnotations(fountainNotes:rawDialogueLines:)`)

**Tasks**:
1. Add `parseGlosa: Bool = true` parameter to `DocumentModelActor.parseAndSaveDocument(from:progress:)` and the string-based variant
2. After `GuionDocumentModel.from(...)` returns, on the `@ModelActor` context:
   - Collect dialogue elements from `document.sortedElements` in `(chapterIndex, orderIndex)` order
   - Build `fountainNotes: [String]` from `.comment` elements and inline notes, document order
   - Build `rawDialogueLines: [(character: String, rawText: String)]` from dialogue elements with **raw** `elementText` (inline `[[ ]]` intact)
   - Call `GlosaCore.compileAnnotations(fountainNotes:rawDialogueLines:)` — never strip locally (RISK-1)
   - For each dialogue-line index `i`, write the DTO onto `GuionElementModel` at its existing `orderIndex`:
     - `glosaSpokenText = dto.spokenText`
     - `glosaBreathOffsets = dto.breathOffsets`
     - `glosaBreathStrengths = dto.breathStrengths`
     - `glosaInstruct = dto.instruct`
     - `glosaPausePoints = try? JSONEncoder().encode(dto.pausePoints)`
   - Surface `diagnostics` via log (use `print` or `os.log`; do not persist on model)
3. Wrap the glosa call in a do-catch; on throw, log the error and leave glosa fields `nil` (graceful degradation — glosa failure must not abort import)
4. Create test fixture files in `Tests/SwiftCompartidoTests/Fixtures/`:
   - `glosa_with_breath.fountain` — minimal Fountain file with dialogue containing `[[<breath/>]]` inline markup
   - `glosa_no_markup.fountain` — minimal Fountain file with plain dialogue (no glosa markup)
5. Write three basic tests in `SwiftCompartidoTests/GlosaIntegrationTests.swift`:
   - **AC1 test**: parse `glosa_with_breath.fountain` fixture and verify `glosaSpokenText` is notes-stripped and `glosaBreathOffsets` contains expected integer offsets
   - **AC2 test**: verify `String(spokenText.unicodeScalars)` split at `glosaBreathOffsets` reconstructs `spokenText` losslessly
   - **AC3 test**: parse `glosa_no_markup.fountain` fixture and verify glosa fields are `nil`/`[]`, no regression

**Exit criteria**:
- [ ] `DocumentModelActor` has `parseGlosa` parameter
- [ ] Annotation pass calls `GlosaCore.compileAnnotations` with raw text (no local stripping)
- [ ] DTO is written onto `GuionElementModel` at correct `orderIndex`
- [ ] Glosa throw/diagnostic does not abort import (fields remain `nil`)
- [ ] Test fixtures exist: `Tests/SwiftCompartidoTests/Fixtures/glosa_with_breath.fountain` and `glosa_no_markup.fountain`
- [ ] `GlosaIntegrationTests.swift` exists with AC1, AC2, AC3 tests
- [ ] All three tests pass (`xcodebuild test -scheme SwiftCompartido`)

---

### Sortie 4: Add SpeakableElement protocol and conform GuionElementModel + ElementReference

**Priority**: 7.0 — Protocol definition blocking migration task

**Entry criteria**:
- [ ] Sortie 3 exit criteria confirmed (annotation pass implemented and tested)

**Tasks**:
1. Define `public protocol SpeakableElement` in a new file `Sources/SwiftCompartido/Protocols/SpeakableElement.swift`:
   ```swift
   public protocol SpeakableElement {
       var spokenText: String { get }     // glosaSpokenText ?? elementText
       var breathOffsets: [Int] { get }   // glosaBreathOffsets ?? []
       var instruct: String? { get }
   }
   ```
2. Conform `GuionElementModel` to `SpeakableElement`:
   - `spokenText`: return `glosaSpokenText ?? elementText`
   - `breathOffsets`: return `glosaBreathOffsets ?? []`
   - `instruct`: return `glosaInstruct`
3. Conform `ElementReference` (the DTO) to `SpeakableElement` (mirror the dual-conformance pattern from `DisplayableElement`)
4. Write a test: create a `GuionElementModel` with glosa fields populated, verify `spokenText` returns the glosa value; create one with glosa fields `nil`, verify `spokenText` falls back to `elementText`
5. Expose breath/pause data from the display path (light coat): add computed property `var displayBreathOffsets: [Int] { breathOffsets }` or equivalent on `GuionElementModel` for future overlay rendering (no full breath-visualizing views in scope)

**Exit criteria**:
- [ ] `SpeakableElement.swift` protocol exists
- [ ] `GuionElementModel` conforms to `SpeakableElement`
- [ ] `ElementReference` conforms to `SpeakableElement`
- [ ] Test confirms fallback behavior (`glosaSpokenText ?? elementText`)
- [ ] Display path exposes breath/pause data (light coat)
- [ ] No mlx-audio-swift types referenced in protocol or conformances

---

## Phase 4 — Schema Versioning & Migration

### Sortie 5: Implement VersionedSchema, MigrationStage, and migration test

**Priority**: 4.17 — Terminal migration task with no downstream dependencies

**Entry criteria**:
- [ ] All Phase 3 sorties complete (Sortie 1–4 exit criteria confirmed)
- [ ] Coordination with the app on version number (the app owns `SchemaMigrationPlan`)

**Tasks**:
1. Introduce a `VersionedSchema` (e.g. `SwiftCompartidoSchemaV2`) in a new file `Sources/SwiftCompartido/Schemas/SwiftCompartidoSchemaV2.swift` capturing the post-change shape of `GuionElementModel` (with glosa fields)
2. Define the prior schema version (e.g. `SwiftCompartidoSchemaV1`) with the old `GuionElementModel` shape (no glosa fields) — this is the baseline for migration
3. Register a `.lightweight` `MigrationStage` from V1 → V2 in a public static var (e.g. `SwiftCompartidoSchemaV2.migrationStage`)
4. Add a migration test in `Tests/SwiftCompartidoTests/MigrationTests.swift`:
   - Create a V1 store (old schema) with sample `GuionElementModel` instances
   - Instantiate a `ModelContainer` with the migration plan (`schemas: [V1.self, V2.self], migrationPlan: ...`)
   - Verify migration completes without error
   - Fetch the migrated elements and confirm: (a) new glosa fields default to `nil`, (b) pre-existing `elementText`/`elementType`/etc. are intact
5. Document in `AGENTS.md` § Schema Versioning that the app must include `SwiftCompartidoSchemaV2` in its `SchemaMigrationPlan.schemas` and reference the migration stage

**Exit criteria**:
- [ ] `SwiftCompartidoSchemaV1` and `SwiftCompartidoSchemaV2` exist
- [ ] `.lightweight` migration stage is registered and public
- [ ] Migration test passes: old store migrates cleanly, new fields default to `nil`, old data intact
- [ ] `AGENTS.md` documents the app-side integration requirement

---

## Open Questions

_No blocking open questions remaining. All decisions resolved._

**Resolved decisions**:
- **OQ-1** (Sortie 1): GlosaCore dependency — `https://github.com/intrusive-memory/glosa-av.git` at v0.5.0 ✓
- **OQ-2** (Sortie 5): VersionedSchema naming — `SwiftCompartidoSchemaV1`/`SwiftCompartidoSchemaV2` ✓

---

## Summary

| Metric | Value |
|--------|-------|
| Work units | 2 |
| Total sorties | 5 |
| Open questions | 0 (all resolved) |
| Dependency structure | sequential (Phase 4 depends on Phase 3) |

**External blocking gate**: glosa-av Phase 1 release (≥v0.5.0) must exist before Sortie 1 can begin.

**Acceptance criteria** (from RECONCILED plan):
- AC1: inline `[[<breath/>]]` import yields correct `spokenText` + `breathOffsets` → covered by Sortie 3 test
- AC2: split `spokenText` at `breathOffsets` round-trips losslessly → covered by Sortie 3 test
- AC3: no-markup screenplay imports unchanged; glosa fields `nil`/`[]` → covered by Sortie 3 test
- AC4: offsets land where glosa intended when fed to mlx `splitTextAtBreaths` → covered by Sortie 3 test (value test, no mlx dependency)
- AC5: tests cover storage + annotation pass + audio coat + no-markup case → covered by Sortie 3 + Sortie 4 tests
- AC6: migration test passes; new fields default to `nil`; old data intact → covered by Sortie 5 test
