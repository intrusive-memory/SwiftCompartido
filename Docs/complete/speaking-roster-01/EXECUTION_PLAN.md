---
type: execution-plan
state: completed
feature_name: OPERATION SPEAKING ROSTER
starting_point_commit: 30a2c18355af75a3f93794fed623d468fa357c19
mission_branch: mission/speaking-roster/01
iteration: 1
---

# EXECUTION_PLAN.md — SwiftCompartido Cast Discovery

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

## Work Units

| Work Unit | Directory | Sorties | Layer | Dependencies |
|-----------|-----------|---------|-------|-------------|
| SwiftCompartido | Sources/SwiftCompartido | 6 | 0-4 | none |

## Sorties

### Sortie 1: Schema Migration Foundation (V2 → V3)

**Priority**: 19.75 — Foundation (blocks all downstream work, establishes speaker field pattern)

**Entry criteria**:
- [ ] First sortie — no prerequisites
- [ ] RECON_REPORT.md confirms GuionElementModel exists in SwiftCompartidoSchemaV2 at Schemas/SwiftCompartidoSchemaV2.swift (A-07)
- [ ] RECON_REPORT.md confirms GuionElementModel has NO speaker field (A-08)

**Migration Strategy**:
Create **SwiftCompartidoSchemaV3** following the repo's established VersionedSchema pattern. Existing data will have null speaker values — this is acceptable. Character descriptions will be incomplete for old data. New parses will populate the field.

**Tasks**:
1. Create `Schemas/SwiftCompartidoSchemaV3.swift` by copying V2 and adding `speaker: String?` to GuionElementModel
2. Add `speaker: String?` property to production `GuionElementModel` in `SwiftDataModels/GuionElementModel.swift`
3. Update V3 documentation to note that existing records will have null speaker (intentional design choice)
4. Create lightweight migration stage from V2 → V3
5. Update schema version identifier to 3.0.0
6. Verify the model compiles and SwiftData accepts the new property

**Exit criteria**:
- [ ] SwiftCompartidoSchemaV3.swift exists with speaker field in GuionElementModel
- [ ] Production GuionElementModel has `speaker: String?` property with default nil
- [ ] V3 migration stage defined (lightweight from V2)
- [ ] Schema documentation clarifies null speaker values are expected for migrated data
- [ ] Build succeeds with no schema-related errors
- [ ] [judgment] Migration follows the established V1→V2 pattern (complete model mirroring)

### Sortie 2: Parse-Time Speaker Assignment

**Priority**: 17.0 — Foundation (blocks all query/aggregation work, establishes population pattern)

**Entry criteria**:
- [ ] Sortie 1 exit criteria verified (speaker field exists)
- [ ] RECON_REPORT.md confirms cleanCharacterName is private at Sendable/GuionParsedScreenplay+Characters.swift:100 (A-05)
- [ ] RECON_REPORT.md confirms findMostRecentCharacter is private at Sendable/GuionParsedScreenplay+Characters.swift:115 (A-06)

**Tasks**:
1. Locate the parser code that creates GuionElementModel instances (FountainParser or related)
2. For dialogue elements: call `findMostRecentCharacter()` and assign the cleaned result to the speaker field
3. For parenthetical elements: assign the same speaker as their associated dialogue
4. Handle dual dialogue: assign each speaker to their respective elements
5. Ensure speaker is nil/empty for non-dialogue elements (action, scene headings, etc.)
6. Test in-memory parse path to verify speaker population

**Exit criteria**:
- [ ] Parser sets speaker field on dialogue and parenthetical elements at parse time
- [ ] Speaker value is the result of cleanCharacterName applied to the character cue
- [ ] Dual dialogue assigns each speaker correctly
- [ ] Non-dialogue elements have nil/empty speaker
- [ ] Build succeeds with no parse-related errors
- [ ] [judgment] Parser modification preserves the existing in-memory vs file-based parse distinction

### Sortie 3: Store-Wide Character Collection (CP-P2)

**Priority**: 9.25 — Implementation (CP-P2 API, blocks acceptance testing)

**Entry criteria**:
- [ ] Sortie 2 exit criteria verified (speaker field is populated at parse time)
- [ ] RECON_REPORT.md confirms extractCharacters() exists on GuionDocumentModel at GuionDocument.swift:363 (A-02)
- [ ] RECON_REPORT.md confirms CharacterInfo exists at Sendable/CharacterInfo.swift:29 (A-04)

**Tasks**:
1. Create a store-wide character aggregation method that queries across all GuionDocumentModel instances
2. Define a Codable and Sendable result type for the character collection (e.g., CharacterCollectionResult)
3. Return a collection of characters with metadata: dialogue line count, word count, scenes, episodes, first line
4. A character is a cue that has dialogue (distinct speaker values excluding nil/empty)
5. Aggregate line counts and word counts across all documents
6. Collect scene IDs and episode identifiers where each character appears
7. Find the first dialogue line for each character (earliest by document → scene → orderIndex)
8. Handle unnamed cues (BARTENDER, COP #1) as distinct characters

**Exit criteria**:
- [ ] Method exists that aggregates characters across the entire store
- [ ] Result type conforms to Codable and Sendable protocols
- [ ] Result includes: character name, line count, word count, scenes, episodes, first line
- [ ] Query works on both in-memory and persistent store containers
- [ ] SwiftReparto can deserialize the result from JSON without linking SwiftCompartido
- [ ] Build succeeds with no query-related errors
- [ ] [judgment] Aggregation logic correctly handles multi-document stores and counts match per-document extractCharacters() sums

### Sortie 4: Character Query Methods (CP-P3, CP-P4, CP-P5)

**Priority**: 9.25 — Implementation (CP-P3/P4/P5 APIs, blocks acceptance testing, window merging complexity)

**Entry criteria**:
- [ ] Sortie 2 exit criteria verified (speaker field exists and is populated)
- [ ] RECON_REPORT.md confirms no existing public neighbour/window/adjacency queries (A-20)
- [ ] CP-P6 requirement: results must be deterministic and in script order

**Tasks**:
1. **CP-P3**: Create SwiftData predicate query to fetch all elements where speaker matches a given character name, ordered by (document, sceneId, orderIndex)
2. **CP-P4**: Create method to fetch complete scenes where a character speaks (all elements in those scenes, in order)
3. **CP-P5**: Create method to fetch a character's lines with ±N neighbours (default N=3), clipped to scene boundaries, with overlapping windows merged
4. For CP-P5: label each element with its speaker in the result
5. Ensure all three queries return results in deterministic script order (document → scene → orderIndex)
6. Handle edge cases: first/last elements in a scene, character appears multiple times in a scene

**Exit criteria**:
- [ ] CP-P3 query method exists and returns character's lines in script order
- [ ] CP-P4 query method exists and returns complete scenes where character speaks
- [ ] CP-P5 query method exists with ±N window and merges overlapping ranges
- [ ] All queries sort by (document, sceneId, orderIndex) for deterministic ordering
- [ ] CP-P5 results include speaker labels for each element
- [ ] Build succeeds with no query-related errors
- [ ] [judgment] Window merging logic correctly handles edge cases (scene boundaries, overlapping windows, first/last elements)

### Sortie 5: Integration Tests and Acceptance Verification

**Priority**: 5.5 — Verification (5 acceptance criteria + unit tests, low risk)

**Entry criteria**:
- [ ] Sortie 3 exit criteria verified (store-wide collection works)
- [ ] Sortie 4 exit criteria verified (character queries work)
- [ ] Acceptance criteria from REQUIREMENTS_PERSONAJE.md § Acceptance

**Tasks**:
1. **Acceptance 1**: Test against Granville 10-episode corpus — verify CP-P2 returns 23 characters + narrator, line counts match per-episode sums
2. **Acceptance 2**: Test full-scene query for HUNTER — verify only scenes where HUNTER speaks are returned, each complete
3. **Acceptance 3**: Test ±3 window for a character with two lines four elements apart — verify one merged window, no cross-scene windows
4. **Acceptance 4**: Test migration/re-parse for stores parsed before CP-P1 — verify no silent empty results
5. **Acceptance 5**: Verify CharacterVoiceMapping and three existing intents (ExtractCharactersIntent, GetVoiceCastingIntent, SetVoiceCastingIntent) behave as they did at b0bd600
6. Write unit tests for edge cases: unnamed cues, dual dialogue, empty stores, single-element scenes

**Exit criteria**:
- [ ] All 5 acceptance criteria pass with Granville corpus or equivalent test data
- [ ] Unit tests added for CP-P2, CP-P3, CP-P4, CP-P5 covering edge cases
- [ ] Tests verify deterministic ordering (same input → same output)
- [ ] Migration test confirms old stores either migrate cleanly or trigger re-parse with clear error
- [ ] Existing voice intents unchanged (regression test)
- [ ] All tests pass in CI
- [ ] [judgment] Test coverage is sufficient to catch regressions in parse-time speaker assignment and query logic

### Sortie 6: Documentation and Deprecation Updates

**Priority**: 2.0 — Documentation (no downstream dependencies, lowest risk)

**Entry criteria**:
- [ ] Sortie 5 exit criteria verified (all acceptance tests pass)
- [ ] RECON_REPORT.md confirms CastListPage.swift:59 references SwiftProyecto.CastMember (A-21)

**Tasks**:
1. Update CastListPage deprecation message to point at SwiftReparto's CAST.md instead of SwiftProyecto.CastMember
2. Add release notes documenting the schema change for Produciesta and Escribir
3. Document the new CP-P2 through CP-P5 APIs with usage examples
4. Note the Codable/Sendable CP-P2 result for SwiftReparto integration
5. Add inline documentation for the three new query methods
6. Update package README if needed to mention cast discovery capabilities

**Exit criteria**:
- [ ] CastListPage deprecation message updated to reference SwiftReparto CAST.md
- [ ] Release notes exist documenting schema change as a minor release (not patch)
- [ ] New APIs have inline documentation with usage examples
- [ ] README mentions cast discovery if appropriate
- [ ] Build succeeds with no documentation-related warnings
- [ ] [judgment] Documentation is clear enough for SwiftReparto and Personaje developers to integrate without asking questions

## Local Dependency Map

<!-- Carried from RECON_REPORT.md. Sortie agents may read these paths; they may not edit them. -->

| Dependency | Resolved version | Local checkout | Status |
|------------|------------------|----------------|--------|
| intrusive-memory/SwiftFijos | sibling path | ~/Projects/package-collection/pkg/SwiftFijos | SIBLING_ACTIVE, LOCAL_AHEAD (c1c5367 on development) |
| intrusive-memory/glosa-av | sibling path | ~/Projects/package-collection/pkg/glosa-av | SIBLING_ACTIVE, LOCAL_AHEAD (efb640f on development) |
| mcritz/TextBundle | 1.0.7 (6fd4f91) | — | NO_LOCAL_CHECKOUT |
| weichsel/ZIPFoundation | 0.9.20 (22787ff) | — | NO_LOCAL_CHECKOUT |
| swiftlang/swift-markdown | 0.7.3 (7d9a5ce) | — | NO_LOCAL_CHECKOUT |
| swiftlang/swift-cmark | 0.7.1 (5d9bdaa, transitive) | — | NO_LOCAL_CHECKOUT |

**Note**: SwiftFijos and glosa-av are in sibling mode — local builds and CI resolve different source. No sorties in this mission depend on their internals.

## Open Questions

<!-- Consumed by Pass 1 of refine (`refine-blockers`). Each entry MUST be resolved before refinement can proceed past Pass 1. -->

### ✅ OQ-1: Schema migration strategy for GuionElementModel — RESOLVED

**Decision**: Lightweight migration with default nil

**Rationale**: SwiftData supports lightweight migrations for additive optional properties. Produciesta and Escribir pick up the change transparently on next build. No schema version bump or explicit migration code required.

**Incorporated into**: Sortie 1 tasks and exit criteria

### ✅ OQ-2: Make CP-P2 result Codable for SwiftReparto — RESOLVED

**Decision**: Yes, make it Codable and Sendable

**Rationale**: Respects SwiftReparto's RQ-INV-1 (no intrusive-memory dependencies). Provides clean file-based integration point. Sendable supports actor isolation.

**Incorporated into**: Sortie 3 tasks and exit criteria

## Parallelism Structure

**Critical Path**: Sortie 1 → Sortie 2 → Sortie 3 → Sortie 5 → Sortie 6 (5 sorties)

**Parallel Execution Groups**:
- **Layer 0**: Sortie 1 (supervising agent — has build)
- **Layer 1**: Sortie 2 (supervising agent — has build)
- **Layer 2**: Sorties 3, 4 (supervising agent sequential — both have builds)
  - *Note*: Sorties 3 and 4 are conceptually parallelizable (no mutual dependency), but both require builds, forcing sequential execution on supervising agent
- **Layer 3**: Sortie 5 (supervising agent — has build + test)
- **Layer 4**: Sortie 6 (supervising agent — has build)

**Agent Constraints**:
- **Supervising agent**: Handles all sorties (all include build verification steps)
- **Sub-agents**: None usable (no non-build sorties in this mission)

**Parallelism Efficiency**: Sequential execution required (0% parallelism due to build constraints)

## Summary

| Metric | Value |
|--------|-------|
| Work units | 1 |
| Total sorties | 6 |
| Open questions | 0 (2 resolved) |
| Dependencies mapped | 6 |
| Dependency structure | layers (0-4) |
| Critical path | 5 sorties |
| Parallelism | Sequential (all sorties have builds) |
