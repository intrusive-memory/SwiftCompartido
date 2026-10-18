---
type: recon-report
state: completed
requirements_file: Docs/REQUIREMENTS_PERSONAJE.md
requirements_sha256: 5826b8ad7b6ec86578691694589cb2d80c49626daa30763094804dcaccf085c5
project_head: 30a2c18355af75a3f93794fed623d468fa357c19
search_root: ~/Projects
generated: 2026-10-03
verdict: BLOCKED
---

# RECON_REPORT.md — SwiftCompartido

## Terminology

> **Mission** — A definable, testable scope of work.
> **Sortie** — An atomic, testable unit of work executed by a single agent in one dispatch.
> **Work Unit** — A grouping of sorties.

## Verdict

**BLOCKED** — 21 assumptions checked, 19 confirmed, 2 stale (minor line-number discrepancies).

## Assumption Findings

| ID | Kind | Claim | Locus | Verdict | Evidence |
|----|------|-------|-------|---------|----------|
| A-01 | A-API | `extractCharacters() -> CharacterList` on `GuionParsedElementCollection` | repo | CONFIRMED | `Sendable/GuionParsedScreenplay+Characters.swift:32` |
| A-02 | A-API | `extractCharacters() -> CharacterList` on `GuionDocumentModel` | repo | CONFIRMED | `GuionDocument.swift:363` |
| A-03 | A-API | `CharacterList` is `[String: CharacterInfo]` | repo | CONFIRMED | `Sendable/CharacterInfo.swift:77` |
| A-04 | A-API | `CharacterInfo` with properties `color`, `counts`, `gender`, `scenes` | repo | CONFIRMED | `Sendable/CharacterInfo.swift:29` |
| A-05 | A-API | `cleanCharacterName` is `private` | repo | CONFIRMED | `Sendable/GuionParsedScreenplay+Characters.swift:100` |
| A-06 | A-API | `findMostRecentCharacter` is `private` | repo | CONFIRMED | `Sendable/GuionParsedScreenplay+Characters.swift:115` |
| A-07 | A-API | `GuionElementModel` has required properties | repo | CONFIRMED | `SwiftDataModels/GuionElementModel.swift` (multiple lines) |
| A-08 | A-API | `GuionElementModel` has NO `speaker` field | repo | CONFIRMED | Full file inspection |
| A-09 | A-API | `CharacterVoiceMapping` is `@Model` at line 56 | repo | STALE | `@Model` at line 55, class at 56 |
| A-10 | A-API | `CharacterVoiceMapping` properties | repo | CONFIRMED | `SwiftDataModels/CharacterVoiceMapping.swift` (lines 62,73,81,90,96) |
| A-11 | A-API | `ExtractCharactersIntent` exists | repo | CONFIRMED | `AppIntents/ExtractCharactersIntent.swift:30` |
| A-12 | A-API | `GetVoiceCastingIntent` exists | repo | CONFIRMED | `AppIntents/VoiceCastingIntents.swift:27` |
| A-13 | A-API | `SetVoiceCastingIntent` exists | repo | CONFIRMED | `AppIntents/VoiceCastingIntents.swift:127` |
| A-14 | A-API | Intents have `documentIDString` parameter | repo | CONFIRMED | Multiple intent files |
| A-15 | A-API | `DocumentModelActor` exists | repo | CONFIRMED | `Actors/DocumentModelActor.swift:53` |
| A-16 | A-API | `DocumentModelActor` has parse/info/delete/element/existence methods | repo | CONFIRMED | `Actors/DocumentModelActor.swift` (multiple lines) |
| A-17 | A-API | `DocumentModelActor` has NO character/voice methods | repo | CONFIRMED | Full file inspection |
| A-18 | A-API | In-memory parse at `FountainParser.swift:89-121` | repo | STALE | Range includes both in-memory and file-based parsing |
| A-19 | A-BEHAVIOR | SwiftData is optional for parse | repo | CONFIRMED | No SwiftData import in FountainParser |
| A-20 | A-BEHAVIOR | No public neighbour/window/adjacency queries | repo | CONFIRMED | Grep found none |
| A-21 | A-FILE | `CastListPage.swift:59` references `SwiftProyecto.CastMember` | repo | CONFIRMED | Deprecation message found |

### Blocking findings

#### A-09 — STALE (minor)
**Claim**: `CharacterVoiceMapping` is a `@Model` in schema V1 and V2 at `SwiftDataModels/CharacterVoiceMapping.swift:56`
**Source**: REQUIREMENTS_PERSONAJE.md § "Already in the library", lines 66-69
**Found**: `@Model` macro at line 55, class declaration at line 56
**Impact**: Minimal — the class declaration IS at line 56 as claimed; the `@Model` macro being on the preceding line is standard Swift practice
**Options**:
1. Accept minor line-number discrepancy — the claim is essentially correct *(recommended)*
2. Update requirements to specify line 55 for the `@Model` macro

#### A-18 — STALE (minor)
**Claim**: Parse works in memory at `FountainParser.swift:89-121`
**Source**: REQUIREMENTS_PERSONAJE.md § "Already in the library", line 77
**Found**: Lines 89-121 include both `init(file:)` (file-based, lines 89-92) and `init(string:)` (in-memory, lines 94-96, 121)
**Impact**: Minimal — in-memory parsing DOES exist in the specified range; the presence of file-based parsing there doesn't invalidate the claim
**Options**:
1. Accept that the claim is accurate (in-memory parse exists in that range) *(recommended)*
2. Update requirements to specify lines 94-96, 121 for in-memory parsing specifically

## Local Dependency Map

| Dependency | Declared | Resolved | Local checkout | Local HEAD | Status |
|------------|----------|----------|----------------|-----------|--------|
| intrusive-memory/SwiftFijos | `from: 1.4.1` | **sibling path** | `~/Projects/package-collection/pkg/SwiftFijos` | `c1c5367` (development) | SIBLING_ACTIVE, LOCAL_AHEAD |
| intrusive-memory/glosa-av | `from: 0.8.1` | **sibling path** | `~/Projects/package-collection/pkg/glosa-av` | `efb640f` (development) | SIBLING_ACTIVE, LOCAL_AHEAD |
| mcritz/TextBundle | `from: 1.0.0` | `1.0.7` (`6fd4f91…`) | — | — | NO_LOCAL_CHECKOUT |
| weichsel/ZIPFoundation | `from: 0.9.0` | `0.9.20` (`22787ff…`) | — | — | NO_LOCAL_CHECKOUT |
| swiftlang/swift-markdown | `from: 0.7.0` | `0.7.3` (`7d9a5ce…`) | — | — | NO_LOCAL_CHECKOUT |
| swiftlang/swift-cmark | *(transitive)* | `0.7.1` (`5d9bdaa…`) | — | — | NO_LOCAL_CHECKOUT |

### Drift and ambiguity notes

- **SwiftFijos is SIBLING_ACTIVE and 19 commits ahead of v1.4.1.** Local builds resolve to `../SwiftFijos`; CI builds resolve to the v1.4.1 remote pin. This machine and CI build different source.
- **glosa-av is SIBLING_ACTIVE and 1 commit ahead of v0.8.1.** Local builds resolve to `../glosa-av`; CI builds resolve to the v0.8.1 remote pin. This machine and CI build different source.
- **No assumptions in REQUIREMENTS_PERSONAJE.md reference sibling dependencies.** All verified assumptions are about code in this repository, so dependency drift does not affect this recon.

## Unverifiable

*No unverifiable assumptions identified.*

## Handoff to breakdown

**Verdict is BLOCKED due to 2 STALE findings, but both are minor line-number discrepancies that do not represent false premises:**

- **A-09**: The class IS at line 56 as claimed; the `@Model` macro on line 55 is standard Swift practice
- **A-18**: In-memory parsing DOES exist at the specified line range; the file-based variant being there too doesn't invalidate the claim

**Recommended action**: Re-run with `--accept-risk` to convert these into Open Questions, or accept them as written and proceed. Neither finding represents a premise that would cause sortie failure.

**If accepted**:
- `CONFIRMED` facts (19) are safe as sortie entry criteria without re-checking
- The dependency map's local paths carry into EXECUTION_PLAN.md so sortie agents don't rediscover them
- Note that SwiftFijos and glosa-av are in sibling mode — local builds and CI builds resolve different source, but this mission has no dependencies on them
