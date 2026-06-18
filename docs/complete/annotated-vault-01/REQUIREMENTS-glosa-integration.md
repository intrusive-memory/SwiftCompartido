---
state: completed
---

# REQUIREMENTS — Glosa Integration (SwiftCompartido)

**Status:** Stub — to be broken down
**Owner repo role:** Consumer. Parses screenplays, stores glosa annotations as
SwiftData, and exposes them via representation "coats."

> This is the **consumer side**. The authoritative architecture, sequencing, and
> the producer-side requirements live in glosa-av:
> - `../glosa-av/REQUIREMENTS-glosa-integration-RECONCILED.md` (cross-repo plan)
> - `../glosa-av/REQUIREMENTS-glosa-integration.md` (producer/`GlosaCore` side)
>
> A prior draft of this consumer doc was folded into the RECONCILED plan and is
> superseded. Re-break-down the work below against that plan.

---

## Sequencing — do glosa-av FIRST

**Yes, this work depends on glosa-av, and glosa-av must ship first.** This repo
consumes a **tagged `GlosaCore` release** (the producer's FR3). Two hard
dependencies on the producer:

1. The `SwiftCompartido → GlosaCore` dependency only resolves once glosa-av's
   library tier is decoupled from SwiftCompartido (producer **FR0**). Until then,
   adding the dependency creates an illegal SwiftPM package cycle.
2. The annotation pass calls `GlosaCore.compileAnnotations(...)` and stores the
   `GlosaLineAnnotation` DTO (producer **FR1/FR2**). That API doesn't exist yet.

So: **glosa-av Phase 1 (decouple + stripper + DTO + release) is a blocking gate.**
You can scaffold/design here in parallel, but nothing in this repo compiles
against glosa-av until the release tag exists. Do **not** pin to a glosa-av branch
in any released/CI build.

---

## Scope (Phases 3–4 of the RECONCILED plan)

### Phase 3 — consumer work in this repo
- **Dependency:** add `GlosaCore` to `Package.swift` via the `sibling(...)`
  helper, pinned to the glosa-av release tag.
- **Storage:** persist the `GlosaLineAnnotation` DTO on the screenplay model —
  either flattened fields on `GuionElementModel` or an encoded blob. Keep
  `elementText` unchanged (raw, with `[[ ]]` markers) for lossless export.
- **Annotation pass:** after `GuionDocumentModel.from(...)`, on `DocumentModelActor`
  (`@ModelActor`), collect dialogue in `sortedElements` order, call
  `compileAnnotations(fountainNotes:rawDialogueLines:)` with **raw** text (never
  strip locally — RISK-1), and write each DTO onto its element at the existing
  `orderIndex`. Gate with `parseGlosa: Bool = true`. Degrade gracefully — a glosa
  throw must not abort import.
- **Audio coat:** `SpeakableElement` protocol (`spokenText`, `breathOffsets`,
  `instruct`); conform `GuionElementModel` + `ElementReference`. No mlx types here.
- **Display coat (light):** expose breath/pause data from the display path.

### Phase 4 — schema versioning & migration (app + this repo)
- **Note:** there is currently **no** `VersionedSchema`/`SchemaMigrationPlan` in
  this repo — that foundation must be established where the `ModelContainer` is
  built (the **app**). Do not rely on implicit/lightweight auto-migration.
- New `VersionedSchema` capturing the post-change `@Model` shape; an explicit
  `MigrationStage` (`.lightweight` acceptable since additions are optional, but
  declared, not inferred); app owns `SchemaMigrationPlan` ordering.
- Migration test: open a prior-version store, confirm clean migration, new fields
  default to `nil`, existing data intact.

---

## Acceptance criteria
See RECONCILED plan §5 (Phase 3 AC1–AC5) and §6 (Phase 4 AC6). Summary:
- AC1: inline `[[<breath/>]]` import yields correct `spokenText` + `breathOffsets`.
- AC2: split `spokenText` at `breathOffsets` round-trips losslessly.
- AC3: no-markup screenplay imports unchanged; glosa fields `nil`/`[]`.
- AC4: offsets land where glosa intended when fed to mlx `splitTextAtBreaths`
  (value test, no mlx dependency).
- AC5: tests cover storage + annotation pass + audio coat + no-markup case.
- AC6: migration test passes; new fields default to `nil`; old data intact.
</content>
