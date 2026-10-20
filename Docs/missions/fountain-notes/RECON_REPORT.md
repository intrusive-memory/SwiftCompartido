---
type: recon-report
state: current
requirements_file: REQUIREMENTS.md
requirements_sha256: 5a92fd5a7c1eabdd10d90812f2ef6347d1e972583be137ca8c66ef019728157f
project_head: af5a734ebd0afd28a193c4edd940cb2d7b1aec38
search_root: ~/Projects
generated: 2026-10-20
verdict: CLEAR
---

# RECON_REPORT.md — SwiftCompartido: Fountain Notes

## Terminology

> **Mission** — A definable, testable scope of work.
> **Sortie** — An atomic, testable unit of work executed by a single agent in one dispatch.
> **Work Unit** — A grouping of sorties.

## Verdict

**CLEAR** — 12 assumptions checked, 12 confirmed, 0 blocking. All assumptions are
`repo` locus except A-12 (a downstream consumer, read for context only). Verified by
the hub directly against the working tree at `af5a734` (clean `development`); no spokes
were needed for grep-level claims.

## Assumption Findings

| ID | Kind | Claim | Locus | Verdict | Evidence |
|----|------|-------|-------|---------|----------|
| A-01 | A-BEHAVIOR | `"section"` pattern forbids `]` and is single-line | repo | CONFIRMED | `Sources/SwiftCompartido/Serialization/FountainParser.swift:55` |
| A-02 | A-BEHAVIOR | Note text strips every `[[`/`]]` on the line, then trims `.whitespaces` | repo | CONFIRMED | `FountainParser.swift:338-345`, `:771-778` |
| A-03 | A-API | Two body parse loops exist: `parseContents(_:)` and `parseContentsAsync(_:progress:)` | repo | CONFIRMED | `FountainParser.swift:135`, `:537`; callers `:91`, `:95`, `:125` |
| A-04 | A-BEHAVIOR | Note branch requires `newlinesBefore > 0` and does not reset it | repo | CONFIRMED | `FountainParser.swift:338-346` (no `newlinesBefore = 0`) |
| A-05 | A-BEHAVIOR | No multi-line note handling exists | repo | CONFIRMED | `grep -n '\[\['` on parser: only `:341`, `:774` |
| A-06 | A-BEHAVIOR | `FountainWriter` writes `.comment` as `\n[[<text>]]` with no blank line after | repo | CONFIRMED | `Sources/SwiftCompartido/Serialization/FountainWriter.swift:64-65`, `:121-125` |
| A-07 | A-API | `ElementType.comment` exists | repo | CONFIRMED | `Sources/SwiftCompartido/Sendable/ElementType.swift:157` |
| A-08 | A-DATA | `bigfish.fountain` fixture exists for perf | repo | CONFIRMED | `Tests/SwiftCompartidoTests/Fixtures/bigfish.fountain`; loader `IntegrationTests.swift:26` |
| A-09 | A-CONFIG | Makefile has `test-ci`, `test-perf`, and a `PERF_TESTS` list excluded from CI | repo | CONFIRMED | `Makefile:32`, `:53`, `:58` |
| A-10 | A-CONFIG | Required check on `development` is `Test on macOS` and CI runs `make test-ci`, skipping drafts | repo/GitHub | CONFIRMED | `gh api …/branches/development/protection` → `contexts: ["Test on macOS"]`; `.github/workflows/tests.yml` |
| A-11 | A-BEHAVIOR | Existing note regression test and inline dialogue note tests exist | repo | CONFIRMED | `Tests/SwiftCompartidoTests/FountainParserTests.swift:164` (`testComment`); `GlosaIntegrationTests.swift:81-90` |
| A-12 | A-BEHAVIOR | SwiftVinetas `extractNotes` reads `.comment` text and trims `.whitespacesAndNewlines` | consumer (context only) | CONFIRMED | `~/Projects/package-collection/pkg/SwiftVinetas/Sources/VinetasCLICore/Storyboard/ScreenplayShots.swift:60-66` |

No blocking findings.

## Local Dependency Map

The parser touches no dependency API. Map recorded for completeness.

| Dependency | Declared | Resolved | Local checkout | Local HEAD | Status |
|------------|----------|----------|----------------|-----------|--------|
| intrusive-memory/glosa-av | `sibling from: 0.8.1` | `0.8.1` (`92e81cb50e`) | `~/Projects/package-collection/pkg/glosa-av` | `7459eb8` (v0.9.0) | SIBLING_ACTIVE (local ahead) |
| intrusive-memory/SwiftFijos | `sibling from: 1.4.1` | `1.4.1` (`1f9c562e5b`) | `~/Projects/package-collection/pkg/SwiftFijos` | `c1c5367` (v1.4.1) | SIBLING_ACTIVE |
| mcritz/TextBundle | `from: 1.0.0` | `1.0.7` | — | — | NO_LOCAL_CHECKOUT |
| weichsel/ZIPFoundation | `from: 0.9.0` | `0.9.20` | — | — | NO_LOCAL_CHECKOUT |
| swiftlang/swift-markdown | `from: 0.7.0` | `0.7.3` | — | — | NO_LOCAL_CHECKOUT |

### Drift and ambiguity notes

- **glosa-av is SIBLING_ACTIVE and ahead of its pin** (local v0.9.0, CI 0.8.1). Local
  builds compile against different glosa-av source than CI. Irrelevant to the parser
  change, but a local-green / CI-red split on Glosa tests should be read in this light.

## Unverifiable

None.

## Handoff to breakdown

- All `CONFIRMED` facts are safe as sortie entry criteria.
- Work lives in `Sources/SwiftCompartido/Serialization/FountainParser.swift` and
  `Tests/SwiftCompartidoTests/`.
