---
type: project
---

# Fountain Notes — Requirements

Fix how `FountainParser` recognises and extracts Fountain **notes** (`[[ … ]]`) so that
multi-line notes and notes containing brackets survive parsing as `.comment` elements.

The motivating payload is GLOSA notation 2.0's canonical shot directive, a JSON object
written inside a note, often spread over several lines and containing JSON arrays
(e.g. a `ref` array). Today both shapes are silently dropped as notes and fall through
to action text. Downstream consumers read `.comment` elements (for example SwiftVinetas'
`VinetasCLICore/Storyboard/ScreenplayShots.swift` `extractNotes`).

## 1. Current behaviour (verified)

`Sources/SwiftCompartido/Serialization/FountainParser.swift`:

1. The `"section"` pattern `^\s*\[{2}\s*([^\]\n])+\s*\]{2}\s*$` forbids **any `]`**
   inside a note and only matches a **single line**. There is no multi-line note
   handling anywhere in the parser.
2. Note text is built with `replacingOccurrences(of: "[[", with: "")` and
   `replacingOccurrences(of: "]]", with: "")` on the whole line, then
   `.trimmingCharacters(in: .whitespaces)`. This strips brackets **inside** the content
   as well as the outer delimiters.
3. The logic is duplicated in the two body parse loops — `parseContents(_:)`
   (~line 337) and `parseContentsAsync(_:progress:)` (~line 770).
4. A line is only considered for a note when `newlinesBefore > 0` (it follows a blank
   line). The comment branch does not reset `newlinesBefore`.

## 2. The Fountain rule we follow

From the Fountain syntax reference (fountain.io, *Notes*): a note is created by enclosing
text in double brackets. *"Notes can contain carriage returns, but if you wish a note to
contain an empty line, you must place two spaces there to 'connect' the element into
one."* Notes may also appear inline in the middle of a line.

We follow that rule exactly:

- A note **may span multiple lines** (line breaks are allowed).
- A note **may not contain a truly empty line**. A line consisting of whitespace only
  (for example two spaces) is allowed and connects the note. If an empty line occurs
  before the closing `]]`, the candidate is **not** a note and its lines parse exactly as
  they do today.

## 3. Functional requirements

### R1 — Note block recognition

Definitions:

- A line *opens* a candidate when it follows a blank line (`newlinesBefore > 0`, the
  unchanged precondition) and, trimmed of spaces/tabs, starts with `[[`.
- A line is a *closer candidate* when, trimmed of trailing spaces/tabs, it ends with `]]`.
- The *content* of a candidate block is everything between the first `[[` and the final
  `]]` of the block.
- The *bracket depth* of content is a running count, from 0, of `+1` per `[` and `-1`
  per `]`. Content is *well-formed* when its running depth never drops below `-1`
  (one stray `]` in prose is allowed; two closers in a row at the outer level — i.e. a
  note that ended early, as in `[[a]] [[b]]` — are not).

Rules:

1. **One-line note.** An opening line that is also a closer candidate is a note block if
   its content is well-formed. (Every note today's pattern accepts has no `]` in its
   content, so it is always well-formed and stays a note.)
2. **Multi-line note.** Otherwise, scan the following lines up to, not including, the
   first empty line (`""`) or end of document. Whitespace-only lines (e.g. two spaces)
   are part of the scan. The block closes at the **first** closer candidate where the
   content so far is well-formed **and** its final depth is `<= 0` (balanced). This lets a
   line inside a JSON object end in `]]` (e.g. `[1, [2]]`) without closing the note.
3. If no line closes the block — an empty line or end of document comes first, or the
   content stops being well-formed — the candidate is **not** a note and every line
   parses exactly as it does today.

Known, accepted limitation: a multi-line prose note with an unbalanced `[` never
balances and so is not recognised (it parses as today). A JSON string value containing
`]]` makes content ill-formed and likewise parses as today.

### R2 — Delimiters

Only the **first** `[[` and the **last** `]]` of a note block are delimiters. Any `[`, `]`,
`[[` or `]]` between them is content.

### R3 — Content fidelity

The `.comment` element text is the block with only the outer `[[` and `]]` removed, then
trimmed of leading/trailing spaces and tabs (`.whitespaces`, exactly the trimming the
current code applies). Every byte in between — including interior newlines, indentation,
quotes, brackets and whitespace-only lines — is preserved unchanged.

### R4 — Multi-line consumption

When a multi-line note block is recognised, all of its lines are consumed into a single
`.comment` element; none of them produce other elements. Look-ahead is bounded by the
first empty line or end of document, so a `[[` with no matching `]]` costs at most a scan
to the next blank line.

### R5 — One implementation

Both body parse loops (`parseContents` and `parseContentsAsync`) use one shared
implementation of note recognition and extraction. No duplicated note logic remains.

### R6 — Writer round-trip

`FountainWriter` writes `.comment` elements as `[[<text>]]`. For every fixture in this
mission, parse → write → parse produces the same sequence of `.comment` texts, and a
multi-line note written by `FountainWriter` re-parses as one `.comment` with identical
text. Writer changes are allowed only if this fails.

### R7 — Regression: existing notes

- Every existing single-line note whose content contains no `[[`, `]]` or `]` (the only
  notes today's pattern accepts) produces exactly the same element type and text as
  today.
- Notes inline in dialogue or action lines (e.g. `Hello [[<breath/>]] world`) remain part
  of that dialogue/action text, unchanged. The parser does not extract inline notes.
- A `[[` line followed by an empty line before any `]]` parses exactly as today.
- `[[a]] [[b]]` on its own line parses exactly as today.
- All existing tests in `SwiftCompartidoTests` continue to pass.

### R8 — Intended behaviour changes (complete list)

These inputs change, and only these:

| Input (after a blank line) | Today | After |
|---|---|---|
| Single-line note containing `]` or `[ ]` pairs, e.g. `[[ see [1] ]]` | action | `.comment` `see [1]` |
| Single-line note containing an interior `[[` or `]]`, well-formed, e.g. `[[ {"ref": [["a"]]} ]]` | action (if it contains `]`), or `.comment` with interior `[[` stripped (e.g. `[[ a [[b ]]` → `a b`) | `.comment` with interior brackets preserved (`a [[b`) |
| Multi-line note with no empty line inside, balanced brackets | other elements (usually merged action; all-caps lines can become character/dialogue) | one `.comment` |

### R9 — Performance

Parsing a large screenplay (the `bigfish` fixture or larger) is not materially slower:
the new implementation's parse time is within 10% of the old implementation's, measured
locally by a performance test that is listed in the Makefile's `PERF_TESTS` (excluded
from CI, per repo convention).

## 4. Test fixtures (synthetic only)

All fixtures are synthetic and generic. Required cases:

1. A notation 2.0-style shot on one line with a `ref` JSON array, e.g.
   `[[ {"shot": {"size": "MS", "ref": ["a.png", "b.png"]}} ]]`.
2. A multi-line shot, one key per line:
   ```
   [[ {"shot": {
     "size": "WS",
     "angle": "low",
     "ref": ["hall.png"]
   }} ]]
   ```
3. A note with a single `]` inside prose, e.g. `[[ the sign reads ] EXIT ]]`.
4. Nested arrays, e.g. `[[ {"grid": [[1, 2], [3, 4]]} ]]`, single- and multi-line.
5. A multi-line note containing a whitespace-only (two-space) line.
6. Negative cases (parse exactly as today): `[[` … empty line … `]]`; unterminated `[[`;
   `[[a]] [[b]]`; `[[x]] some action` followed by `more [[y]]` on the next line.
7. Regression: today's single-line note (`[[ This is a note about the scene ]]`), inline
   dialogue note (`Hello [[<breath/>]] world`).

Each case is asserted through **both** the sync (`FountainParser(string:)`) and async
(progress-reporting) parse paths.

## 5. Non-goals

- Parsing GLOSA or JSON inside notes (glosa-av does that).
- Extracting inline notes out of dialogue/action text.
- Changing `FountainWriter` output format beyond what R6 requires.
- Boneyard (`/* */`) handling.

## 6. Constraints

- Public repo: synthetic, generic fixtures and wording only.
- Build/test via `make` / `xcodebuild` only; never `swift build` / `swift test`.
- PR targets `development`; required check `Test on macOS` must be green.
