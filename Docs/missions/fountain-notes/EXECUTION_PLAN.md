---
type: execution-plan
feature_name: OPERATION BRACKET SMUGGLER
starting_point_commit: af5a734ebd0afd28a193c4edd940cb2d7b1aec38
mission_branch: mission/bracket-smuggler/01
iteration: 1
---

# EXECUTION_PLAN.md — SwiftCompartido: Fountain Notes

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

Source: `REQUIREMENTS.md` (this directory). Ground truth: `RECON_REPORT.md` (CLEAR).

## Work Units

| Work Unit | Directory | Sorties | Layer | Dependencies |
|-----------|-----------|---------|-------|-------------|
| fountain-notes | `/Users/stovak/Projects/package-collection/pkg/SwiftCompartido` | 4 | 1 | none |

Build/test rules for every sortie: `make` / `xcodebuild` only, never `swift build` /
`swift test`. Targeted runs:
`xcodebuild test -scheme SwiftCompartido -destination 'platform=macOS,arch=arm64' -only-testing:SwiftCompartidoTests/<Suite>`.
Public repo: synthetic fixtures, no private product names.

### Sortie 1: Shared note-block recognizer

**Priority**: 13.0 — blocks 3 sorties (9), foundation for both parse loops (2), algorithmic risk (2)

**Entry criteria**:
- [ ] First sortie — no prerequisites. Recon A-01..A-05 confirmed (`FountainParser.swift:55`, `:338-345`, `:771-778`).

**Tasks**:
1. Add an internal, pure helper `FountainNoteBlock` in `Sources/SwiftCompartido/Serialization/FountainNoteBlock.swift` with `static func match(lines: [String], at index: Int) -> (text: String, lastLineIndex: Int)?` implementing REQUIREMENTS R1–R4 (one-line rule, multi-line scan bounded by the first `""` line or end, well-formed depth ≥ −1, multi-line closer needs final depth ≤ 0). The `newlinesBefore > 0` precondition stays in the caller.
2. Text extraction per R2/R3: drop only the first `[[` and the final `]]`, trim `.whitespaces`, keep every interior byte.
3. Add `Tests/SwiftCompartidoTests/FountainNoteBlockTests.swift` (Swift Testing) covering REQUIREMENTS §4 cases 1–6 at the helper level, including `lastLineIndex` for multi-line blocks and `nil` for every negative case.

**Exit criteria**:
- [ ] `FountainNoteBlock.swift` and `FountainNoteBlockTests.swift` exist.
- [ ] `xcodebuild test … -only-testing:SwiftCompartidoTests/FountainNoteBlockTests` passes with ≥ 12 tests.
- [ ] `FountainParser.swift` is unchanged (`git diff --quiet -- Sources/SwiftCompartido/Serialization/FountainParser.swift`).

### Sortie 2: Wire both parse loops to the shared recognizer

**Priority**: 9.5 — blocks 2 sorties (6), regression risk across all Fountain parsing (2), touches hot loop

**Entry criteria**:
- [ ] Sortie 1 exit criteria met.

**Tasks**:
1. In `FountainParser.swift`, replace the note branch in `parseContents` and `parseContentsAsync` with a call to `FountainNoteBlock.match(lines:at:)`; on a multi-line match, skip the consumed lines (convert the `for line in lines` loops to index-based iteration or a skip counter) while keeping progress reporting in the async loop.
2. Remove the `"section"` pattern from the regex cache if nothing else uses it.
3. Add `Tests/SwiftCompartidoTests/FountainParserNoteTests.swift`: every REQUIREMENTS §4 fixture parsed through `FountainParser(string:)` **and** the async progress path, asserting element types and exact `.comment` text, plus the R7 regressions (existing single-line note text identical; inline dialogue note stays in dialogue text; negative cases produce the same element types/texts as on `development` — capture expected values by running the fixtures against the unmodified parser first).

**Exit criteria**:
- [ ] `grep -c 'replacingOccurrences(of: "\[\["' Sources/SwiftCompartido/Serialization/FountainParser.swift` prints `0`.
- [ ] `grep -c 'FountainNoteBlock.match' Sources/SwiftCompartido/Serialization/FountainParser.swift` prints `2`.
- [ ] `FountainParserNoteTests` passes and asserts both sync and async paths for each §4 case.
- [ ] `make test-ci` passes (whole CI selection, no regressions).

### Sortie 3: Writer round-trip and performance

**Priority**: 5.0 — blocks Sortie 4 (3), perf measurement risk (1)

**Entry criteria**:
- [ ] Sortie 2 exit criteria met.

**Tasks**:
1. Add round-trip tests (parse → `FountainWriter.document(from:)` → parse) for every §4 positive fixture asserting identical `.comment` text sequences (R6). Change `FountainWriter` only if a test fails.
2. Add a performance test that parses `bigfish.fountain` (repeat ×N to make it large) and add its identifier to the Makefile `PERF_TESTS` list.
3. Measure parse time of the large input with the old parser (checked out from `development` into a scratch worktree) and the new parser locally via `make test-perf`-style `-only-testing` runs; record both numbers. New must be within 10% of old (R9).

**Exit criteria**:
- [ ] Round-trip tests pass under `make test-ci`.
- [ ] The perf test identifier appears in `Makefile` `PERF_TESTS` and is skipped by `make test-ci`.
- [ ] New/old parse-time ratio ≤ 1.10, with both timings written to the Decisions Log in `SUPERVISOR_STATE.md`.

### Sortie 4: Pull request and CI

**Priority**: 1.5 — leaf; release mechanics only

**Entry criteria**:
- [ ] Sortie 3 exit criteria met; working tree clean.

**Tasks**:
1. Add a `CHANGELOG.md` "Unreleased" entry describing the note parsing fix and the R8 behaviour changes.
2. Push the mission branch and open a PR into `development` (body ends with the Claude Code attribution line); mark it ready for review so CI runs.
3. Wait for the `Test on macOS` check.

**Exit criteria**:
- [ ] PR exists with base `development`, not draft.
- [ ] `gh pr checks <n>` shows `Test on macOS` = pass.
- [ ] PR is not merged; no tag created.

## Parallelism Structure

**Critical Path**: Sortie 1 → Sortie 2 → Sortie 3 → Sortie 4 (length: 4 sorties)

**Parallel Execution Groups**: none — every sortie edits or tests the same parser and
needs a build. All four are **SUPERVISING AGENT ONLY** (build steps), run sequentially.

**Agent Constraints**:
- **Supervising agent**: runs all sorties (each has `xcodebuild` steps).
- **Sub-agents**: 0. Missed opportunities: none worth the merge risk.

## Local Dependency Map

<!-- Carried from RECON_REPORT.md. Sortie agents may read these paths; they may not edit them. -->

| Dependency | Resolved version | Local checkout | Status |
|------------|------------------|----------------|--------|
| intrusive-memory/glosa-av | 0.8.1 (`92e81cb50e`) | `~/Projects/package-collection/pkg/glosa-av` (v0.9.0) | SIBLING_ACTIVE |
| intrusive-memory/SwiftFijos | 1.4.1 (`1f9c562e5b`) | `~/Projects/package-collection/pkg/SwiftFijos` | SIBLING_ACTIVE |
| mcritz/TextBundle | 1.0.7 | — | NO_LOCAL_CHECKOUT |
| weichsel/ZIPFoundation | 0.9.20 | — | NO_LOCAL_CHECKOUT |
| swiftlang/swift-markdown | 0.7.3 | — | NO_LOCAL_CHECKOUT |

## Open Questions

_No blocking open questions identified during breakdown._

## Summary

| Metric | Value |
|--------|-------|
| Work units | 1 |
| Total sorties | 4 |
| Open questions | 0 |
| Dependencies mapped | 5 |
| Dependency structure | sequential |
| Refinement | Passes 1–5 complete (0 blockers, 0 splits/merges, 2 criteria sharpened) |
