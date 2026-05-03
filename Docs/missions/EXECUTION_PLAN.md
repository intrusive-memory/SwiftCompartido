# SwiftCompartido Execution Plan - Custom-Pages Removal (Phase 2)

**Repository**: SwiftCompartido
**Source**: package-collection/CUSTOM_PAGES_REMOVAL_REQUIREMENTS.md (Phase 2)
**Status**: INDEPENDENT -- Can run in parallel with SwiftProyecto Phase 0
**Timeline**: Week 1-3

---

## Independence Declaration

This execution plan has:
- **NO external dependencies** -- pure internal cleanup
- **NO blocking relationships** -- can run in parallel with SwiftProyecto Phase 0, Phase 1, or any other phase
- **NO cross-repository coordination required** -- all work is contained within SwiftCompartido
- **NO shared state** with other execution plans

This is a standalone cleanup operation. Start it whenever ready.

---

## Executive Summary

Remove all custom-pages.json import/export code from SwiftCompartido. This package should focus on screenplay parsing, not cast management. Cast metadata is now handled by SwiftProyecto via PROJECT.md frontmatter.

**Work to Remove**:
1. Sidecar JSON loading/writing (`custom-pages.json`, `{basename}-custom-pages.json`)
2. Highland .textbundle custom-pages loading
3. TextBundle custom-pages export
4. Disabled test files

**Work to Keep**:
- `CastListPage` model (for Highland compatibility, mark as deprecated)

---

## Work Units

| Work Unit | Directory | Sprints | Layer | Dependencies |
|-----------|-----------|---------|-------|-------------|
| SwiftCompartido Cleanup | `/Users/stovak/Projects/SwiftCompartido` | 4 | 0 | none |

---

## Agent Guidelines

### Build Error Escalation Strategy

**CRITICAL**: If you encounter build errors during any sprint:

1. **First attempt**: Try to resolve simple, obvious build errors (missing imports, typos, syntax errors)
2. **If build errors persist**: Dispatch a higher-order reasoning agent (opus model) to solve the build problem
3. **Wait for resolution**: Continue your sprint work once the build problem is resolved
4. **Do NOT**: Get stuck repeatedly trying the same failed build approach

**Escalation pattern**:
```
If build fails after fixing obvious issues:
  → Use Task tool with subagent_type="general-purpose", model="opus"
  → Prompt: "Build is failing with errors: <paste errors>. Fix the build issues in <files>."
  → Wait for completion, then resume your sprint work
```

This ensures build problems don't block sprint progress and get appropriate expert attention.

---

### Sprint 1: Remove Custom-Pages Methods from Source

**Priority**: 12 -- Foundation sprint; all subsequent sprints depend on clean compilation after removal. Dependency depth: 3, Foundation: yes, Risk: low (deletion-only).

**Type**: code

**Entry criteria**:
- [ ] First sprint -- no prerequisites

**Tasks**:
1. **GuionParsedScreenplay.swift** -- Delete the entire `// MARK: - Custom Pages Helpers` extension block (lines 681-769):
   - Delete `loadCustomPagesForFile(url:)` (lines 696-725)
   - Delete `tryLoadCustomPagesJSON(from:)` (lines 728-745)
   - Delete `writeCustomPagesSidecar(for:)` (lines 753-769)
   - Delete the extension declaration itself (`extension GuionParsedElementCollection {` at line 683) and its closing brace
   - Delete the MARK comment at line 681

2. **GuionParsedScreenplay.swift** -- Remove stale "REMOVED" comments:
   - Line 216: Delete `// REMOVED: Automatic sidecar loading - customPages must be loaded manually if needed`
   - Line 484: Delete `// REMOVED: Automatic sidecar writing - write customPages manually if needed`
   - Line 491: Delete `// REMOVED: Automatic sidecar writing - write customPages manually if needed`

3. **GuionParsedScreenplay+Highland.swift** -- Remove custom-pages loading:
   - Delete `loadCustomPages(from:)` method (lines 90-112, including doc comment at lines 90-92)
   - Delete commented-out call at line 79: `// let customPages = Self.loadCustomPages(from: textBundleURL)`
   - Delete the `// DISABLED: Custom pages loading is temporarily disabled` comment at line 78
   - Clean up line 86: Change `customPages: [] // DISABLED` to `customPages: []`

4. **GuionParsedScreenplay+TextBundle.swift** -- Remove custom-pages export:
   - Delete `writeCustomPagesJSON(to:)` method (lines 172-178, including doc comment)
   - Delete the comment at line 148: `// REMOVED: Automatic custom-pages.json writing`
   - Delete the comment at line 149: `// Custom pages must be written manually if needed`

**Files Modified**:
- `Sources/SwiftCompartido/Sendable/GuionParsedScreenplay.swift`
- `Sources/SwiftCompartido/Sendable/GuionParsedScreenplay+Highland.swift`
- `Sources/SwiftCompartido/Sendable/GuionParsedScreenplay+TextBundle.swift`

**Exit criteria**:
- [ ] No methods named `loadCustomPagesForFile`, `tryLoadCustomPagesJSON`, `writeCustomPagesSidecar`, `loadCustomPages`, or `writeCustomPagesJSON` exist in source: `grep -r 'func loadCustomPagesForFile\|func tryLoadCustomPagesJSON\|func writeCustomPagesSidecar\|func loadCustomPages\|func writeCustomPagesJSON' Sources/` returns no matches
- [ ] No "REMOVED:" or "DISABLED:" comments referencing custom-pages remain: `grep -rn 'REMOVED:.*sidecar\|REMOVED:.*custom-pages\|DISABLED.*custom.*pages\|DISABLED.*Custom.*pages' Sources/` returns no matches
- [ ] Build succeeds: `xcodebuild build -scheme SwiftCompartido -destination 'platform=macOS'`
- [ ] Git commit created with message: "refactor: Remove custom-pages.json sidecar support"

**Context fitness**: R=3 files + M*2=6 + B=1 + V=3 + 5 = 18 turns (36% of 50-turn budget) -- right-sized

---

### Sprint 2: Delete Disabled Tests & Deprecate CastListPage

**Priority**: 8 -- Depends on Sprint 1 for clean build. Moderate foundation (deprecation annotations inform downstream consumers). Risk: low.

**Type**: code

**Entry criteria**:
- [ ] Sprint 1 COMPLETED -- build succeeds after custom-pages method removal

**Tasks**:
1. **Delete disabled test files**:
   - Delete `Tests/SwiftCompartidoTests/FountainCustomPagesSidecarTests.swift.disabled`
   - Delete `Tests/SwiftCompartidoTests/HighlandCustomPagesTests.swift.disabled`

2. **CastListPage.swift** -- Add deprecation annotation and documentation:
   - Add `@available(*, deprecated, message: "Use SwiftProyecto.CastMember for PROJECT.md-based cast management")` to `CastListPage` struct
   - Update file-level doc comment with deprecation notice, migration path, and future plans
   - Add migration guide referencing SwiftProyecto `CastMember` and `ProjectDiscovery`

**CastListPage Deprecation Template**:

```swift
/// Highland 2 compatible cast list page model
///
/// ## Deprecation Notice
///
/// **This model is deprecated and kept only for Highland file format compatibility.**
///
/// For new projects, use `SwiftProyecto.CastMember` as the canonical cast model.
/// `CastListPage` is only used when importing/exporting Highland .textbundle files.
///
/// ### Migration Path
///
/// If you're using `CastListPage` for cast management, migrate to SwiftProyecto:
///
/// ```swift
/// import SwiftProyecto
///
/// // Old approach (deprecated):
/// let castPage = CastListPage(items: [...])
///
/// // New approach (recommended):
/// let discovery = ProjectDiscovery()
/// if let projectMd = discovery.findProjectMd(from: screenplayURL) {
///     let cast = try discovery.readCast(from: projectMd)
/// }
/// ```
///
/// ### Future Plans
///
/// This model will be removed in a future release if Highland support is dropped.
/// Consider migrating to PROJECT.md-based cast management now.
@available(*, deprecated, message: "Use SwiftProyecto.CastMember for PROJECT.md-based cast management")
public struct CastListPage: Codable, Sendable, Equatable {
    // ... existing implementation unchanged
}
```

**Exit criteria**:
- [ ] Disabled test files no longer exist: `test ! -f Tests/SwiftCompartidoTests/FountainCustomPagesSidecarTests.swift.disabled && test ! -f Tests/SwiftCompartidoTests/HighlandCustomPagesTests.swift.disabled`
- [ ] CastListPage.swift contains `@available(*, deprecated`: `grep -c '@available.*deprecated' Sources/SwiftCompartido/Sendable/CastListPage.swift` returns 1 or more
- [ ] CastListPage.swift contains migration guide: `grep -c 'SwiftProyecto.CastMember' Sources/SwiftCompartido/Sendable/CastListPage.swift` returns 1 or more
- [ ] Build succeeds: `xcodebuild build -scheme SwiftCompartido -destination 'platform=macOS'`
- [ ] All tests pass: `xcodebuild test -scheme SwiftCompartido -destination 'platform=macOS'`
- [ ] Git commit created with message: "docs: Deprecate CastListPage in favor of SwiftProyecto.CastMember"

**Context fitness**: R=3 files + M*2=2 + B=1 + V=4 + 5 = 15 turns (30% of 50-turn budget) -- right-sized

---

### Sprint 3: Documentation Updates

**Priority**: 4 -- Low dependency depth (only Sprint 4 depends on this). No foundation. Risk: minimal (documentation-only).

**Type**: code

**Entry criteria**:
- [ ] Sprint 2 COMPLETED -- tests pass, CastListPage deprecated

**Tasks**:
1. **Archive old documentation**:
   - Create `.archive/` directory if it does not exist
   - Move `.claude/docs/CUSTOM_PAGES_REQUIREMENTS.md` to `.archive/2025-02_CUSTOM_PAGES_REQUIREMENTS.md`
   - Add a one-line header note: `<!-- Archived 2026-02-15: Custom-pages.json support removed in favor of SwiftProyecto PROJECT.md -->`

2. **Update AGENTS.md** (if it references custom-pages.json -- check first):
   - Remove any references to custom-pages.json functionality
   - Add Cast Management section with deprecation notice and SwiftProyecto reference

3. **Update CHANGELOG.md**:
   - Add `## [2.5.0] - 2026-02-XX` entry with Breaking Changes, Deprecated, and Migration Guide sections
   - Use the template content provided below

4. **Update README.md** -- line 108-110 contains custom-pages code example:
   - Replace the `CustomPageContainer`/`customPages` code block with SwiftProyecto-based example
   - Or remove the custom-pages example if the surrounding section no longer applies

**AGENTS.md Cast Management Section** (add or replace):

```markdown
## Cast Management

**Deprecated**: SwiftCompartido no longer handles cast management via custom-pages.json files.

### Current Approach (Deprecated)

`CastListPage` is kept for Highland .textbundle compatibility only. This model is deprecated.

### Recommended Approach

Use **SwiftProyecto** for all cast management:

```swift
import SwiftProyecto

let discovery = ProjectDiscovery()
if let projectMd = discovery.findProjectMd(from: screenplayURL) {
    let cast = try discovery.readCast(from: projectMd)
}
```

See [SwiftProyecto documentation](https://github.com/intrusive-memory/SwiftProyecto) for details.

### Migration from custom-pages.json

If you have existing custom-pages.json files:
1. Convert cast data to PROJECT.md frontmatter (YAML format)
2. Use SwiftProyecto's `ProjectMarkdownParser` to read/write cast
3. Remove custom-pages.json files

**Breaking Changes**:
- Sidecar JSON loading removed (`loadCustomPagesForFile`, `tryLoadCustomPagesJSON`)
- Sidecar JSON writing removed (`writeCustomPagesSidecar`)
- Highland custom-pages loading removed (`loadCustomPages`)
- TextBundle custom-pages export removed (`writeCustomPagesJSON`)
```

**CHANGELOG.md Entry**:

```markdown
## [2.5.0] - 2026-02-XX

### Breaking Changes

- **REMOVED**: Custom-pages.json sidecar support
  - `loadCustomPagesForFile()` method removed
  - `tryLoadCustomPagesJSON()` method removed
  - `writeCustomPagesSidecar()` method removed
  - Highland `loadCustomPages()` method removed
  - TextBundle `writeCustomPagesJSON()` method removed

### Deprecated

- `CastListPage` model now deprecated
  - Kept only for Highland .textbundle compatibility
  - Use `SwiftProyecto.CastMember` for new projects
  - Will be removed in future release if Highland support is dropped

### Migration Guide

**From custom-pages.json to PROJECT.md**:

1. Install SwiftProyecto package
2. Convert cast data to PROJECT.md YAML frontmatter:
   ```yaml
   cast:
     - character: NARRATOR
       voices:
         apple: com.apple.voice.compact.en-US.Aaron
   ```
3. Use SwiftProyecto's API for cast management
4. Remove custom-pages.json files

See [SwiftProyecto documentation](https://github.com/intrusive-memory/SwiftProyecto) for details.
```

**Exit criteria**:
- [ ] Archive file exists: `test -f .archive/2025-02_CUSTOM_PAGES_REQUIREMENTS.md`
- [ ] Original docs file removed: `test ! -f .claude/docs/CUSTOM_PAGES_REQUIREMENTS.md`
- [ ] CHANGELOG.md contains v2.5.0 entry: `grep -c '## \[2.5.0\]' CHANGELOG.md` returns 1
- [ ] README.md no longer references `CustomPageContainer`: `grep -c 'CustomPageContainer' README.md` returns 0
- [ ] No references to `custom-pages.json` remain in non-archived markdown (excluding EXECUTION_PLAN.md and .archive/): `grep -rl 'custom-pages.json' --include='*.md' . | grep -v '.archive/' | grep -v 'EXECUTION_PLAN.md' | grep -v '.build/' | grep -v 'Docs/old/'` returns empty or only expected files
- [ ] Git commit created with message: "docs: Update documentation for custom-pages removal"

**Context fitness**: R=5 files + C*2=2 + M*2=6 + V=4 + 5 = 22 turns (44% of 50-turn budget) -- right-sized

---

### Sprint 4: Version Bump & Release

**Priority**: 2 -- Terminal sprint. No dependents. Risk: low (tagging and release creation).

**Type**: command

**Entry criteria**:
- [ ] Sprint 3 COMPLETED -- documentation updated, CHANGELOG.md has v2.5.0 entry

**Tasks**:
1. **Verify CI/CD testing infrastructure**:
   - Check for `.github/workflows/tests.yml` or `.github/workflows/unit-tests.yml`
   - Verify unit tests trigger on `pull_request` from development → main
   - Check for `.github/workflows/performance-tests.yml` with `workflow_dispatch` (manual trigger)
   - If missing, create workflows following the standard pattern
2. **Bump version tag**:
   - Create git tag `v2.5.0` on the current HEAD
3. **Push tag** (if remote is configured):
   - `git push origin v2.5.0`
4. **Create GitHub release**:
   - Use `gh release create v2.5.0` with the CHANGELOG migration guide as release notes
   - Title: "v2.5.0 - Remove custom-pages.json support"
   - Mark as latest release

**Exit criteria**:
- [ ] **CI/CD testing infrastructure verified**:
  - [ ] Unit tests workflow exists: `test -f .github/workflows/tests.yml` OR `test -f .github/workflows/unit-tests.yml`
  - [ ] Unit tests trigger on pull_request: `grep -q 'pull_request' .github/workflows/tests.yml` OR `grep -q 'pull_request' .github/workflows/unit-tests.yml`
  - [ ] Performance tests workflow exists: `test -f .github/workflows/performance-tests.yml`
  - [ ] Performance tests use manual trigger: `grep -q 'workflow_dispatch' .github/workflows/performance-tests.yml`
  - [ ] Workflows target correct branches: unit tests run on development → main PRs
- [ ] Git tag exists: `git tag -l 'v2.5.0'` returns `v2.5.0`
- [ ] GitHub release exists: `gh release view v2.5.0` succeeds (exit code 0)
- [ ] Release title contains "custom-pages": `gh release view v2.5.0 --json name -q '.name'` contains relevant text

**Context fitness**: R=1 + B=0 + V=3 + 5 = 9 turns (18% of 50-turn budget) -- right-sized

---

## Parallelism Structure

**Critical Path**: Sprint 1 -> Sprint 2 -> Sprint 3 -> Sprint 4 (length: 4 sprints, sequential)

**Parallel Execution Groups**:
- **Group 1**: Sprint 1 (Agent 1 -- supervising agent, has build step)
- **Group 2**: Sprint 2 (Agent 1 -- supervising agent, has build+test step)
- **Group 3**: Sprint 3 (Agent 1 or sub-agent -- no build, documentation only)
- **Group 4**: Sprint 4 (Agent 1 or sub-agent -- no build, release commands only)

**Agent Constraints**:
- **Supervising agent**: Handles Sprints 1 and 2 (build/compile steps required)
- **Sub-agents (up to 1)**: Can handle Sprints 3 and 4 (no build operations -- documentation and release only)

**Parallelism Analysis**:
- This is a single work unit with sequential sprints -- no intra-plan parallelism available
- Maximum parallelism: 1 agent at a time (strict sequential dependency chain)
- **Cross-plan parallelism**: This entire plan runs in parallel with SwiftProyecto Phase 0 (separate repository, no shared state)

**Missed Opportunities**: None. All sprints have genuine sequential dependencies (each builds on prior sprint's output).

---

## Open Questions & Missing Documentation

### Resolved Items (auto-fixed during refinement)

| Sprint | Issue Type | Original Issue | Resolution |
|--------|-----------|----------------|------------|
| Sprint 3 (was 3) | Vague criterion | "README.md updated if it references custom-pages.json" | Replaced with specific grep check: `grep -c 'CustomPageContainer' README.md` returns 0. Confirmed README.md line 110 does reference `customPages`. |
| Sprint 3/4 (was 3) | Multiple concerns | Sprint mixed documentation + release tagging | Split into Sprint 3 (documentation) and Sprint 4 (release). |
| Sprint 3 | Missing doc | "Update AGENTS.md" but no verification AGENTS.md references custom-pages | Added conditional check instruction. Verified AGENTS.md does not currently reference custom-pages.json. |
| All | Vague criterion | "All custom-pages methods deleted" and "All references to sidecar JSON removed" | Replaced with specific grep commands that return no matches. |

### Unresolved Items

None. All issues were auto-fixed.

---

## Summary

| Metric | Value |
|--------|-------|
| Work units | 1 |
| Total sprints | 4 |
| Dependency structure | Sequential (within single work unit) |
| Cross-plan dependencies | None (independent of SwiftProyecto Phase 0) |
| Estimated timeline | 1-2 days |
| Average sprint size | 16 turns (budget: 50) |
| Critical path length | 4 sprints |
| Parallelism | 1 supervising agent (sequential); cross-plan parallel with Phase 0 |

**Critical Success Criteria**:
- All custom-pages.json code removed (verified by grep)
- CastListPage deprecated with `@available` annotation (verified by grep)
- Tests pass after removal (verified by xcodebuild test)
- Documentation updated with migration guide (verified by file checks)
- Release tagged with breaking changes (verified by git tag and gh release)

**External Dependencies**:
- NONE -- this is independent cleanup work
- Can start immediately
- No coordination with other repositories required
- No blocking relationships with any other phase

---

**Document Version**: 2.0 (refined)
**Created**: 2026-02-15
**Refined**: 2026-02-15
**Status**: Ready for execution
