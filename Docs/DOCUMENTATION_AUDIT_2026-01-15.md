# Documentation Audit - January 15, 2026

## Executive Summary

This audit identifies outdated, redundant, and incorrectly structured documentation in README.md and CLAUDE.md. Key issues include broken links, duplicate content, and version-specific information that should be consolidated.

## Critical Issues

### 1. Broken Documentation Links ⚠️

Both README.md and CLAUDE.md reference documentation files with **incorrect paths**:

| Referenced Path | Actual Path | Files Affected |
|----------------|-------------|----------------|
| `./USAGE-SUMMARY.md` | `./Docs/old/USAGE-SUMMARY.md` | README.md:341, CLAUDE.md:1198 |
| `./Docs/APP_INTENTS_GUIDE.md` | `./Docs/old/APP_INTENTS_GUIDE.md` | README.md:342, CLAUDE.md:1197, 984 |
| `./Docs/PARSED_FILE_SERVICE_API.md` | `./Docs/old/PARSED_FILE_SERVICE_API.md` | README.md:346, CLAUDE.md:1202, 985 |
| `./SOURCE_FILE_TRACKING.md` | `./Docs/old/SOURCE_FILE_TRACKING.md` | README.md:347, CLAUDE.md:1205 |

**Impact**: Users clicking these links get 404 errors.

**Recommendation**: Either move files out of `Docs/old/` to their referenced locations, or update all references to point to `Docs/old/`.

### 2. Redundant Content Between Files

Multiple sections appear in both README.md and CLAUDE.md with 70-90% overlap:

#### GuionViewer Reference Implementation
- **README.md**: Lines 273-336 (63 lines)
- **CLAUDE.md**: Lines 108-188 (80 lines)
- **Overlap**: ~80% identical content
- **Recommendation**: Keep brief overview in README, detailed architecture in CLAUDE.md, reference CLAUDE.md from README

#### Apple Intelligence PDF Parsing
- **README.md**: Lines 60 (brief mention), embedded in Features
- **CLAUDE.md**: Lines 822-942 (120 lines of detailed implementation)
- **Overlap**: Different levels of detail, but duplicate information
- **Recommendation**: Keep user-facing summary in README, move technical details to `Docs/FOUNDATION_MODELS_STATUS.md` (already exists)

#### Testing Requirements
- **README.md**: Lines 363-381 (18 lines, brief)
- **CLAUDE.md**: Lines 626-820 (194 lines, comprehensive)
- **Overlap**: ~50% - README has summary, CLAUDE has full guide
- **Recommendation**: Keep summary in README, comprehensive guide in CLAUDE.md (correct as-is)

#### App Intents Integration
- **README.md**: Not present in features list
- **CLAUDE.md**: Lines 946-985 (39 lines)
- **Overlap**: CLAUDE.md references docs, but pattern/example is duplicated
- **Recommendation**: Add brief mention to README, keep full examples in CLAUDE.md

### 3. Content That Should Move to Docs/

Several large technical sections in CLAUDE.md should be extracted to dedicated documentation files:

#### Performance Testing & Benchmarking
- **Location**: CLAUDE.md lines 292-381 (89 lines)
- **Target**: `Docs/PERFORMANCE_TESTING.md`
- **Reason**: Highly specialized, changes frequently, clutters main architecture doc

#### SwiftData Relationships and Cascade Delete
- **Location**: CLAUDE.md lines 482-556 (74 lines)
- **Target**: `Docs/ARCHITECTURE_SWIFTDATA.md`
- **Reason**: Deep technical detail, useful for contributors but not core architecture

#### Known Issues and Migration Notes
- **Location**: CLAUDE.md lines 558-615 (57 lines)
- **Target**: `Docs/MIGRATION_GUIDE.md` or `Docs/KNOWN_ISSUES.md`
- **Reason**: Version-specific, should be tracked separately

#### CI/CD Setup (Simulator Creation & Branch Protection)
- **Location**: CLAUDE.md lines 1083-1183 (100 lines)
- **Target**: `Docs/CI_CD_SETUP.md`
- **Reason**: Operational detail, not architecture, useful for CI maintainers

#### File Format Parsing Flow
- **Location**: CLAUDE.md lines 233-290 (57 lines with Mermaid diagram)
- **Target**: `Docs/PARSING_ARCHITECTURE.md`
- **Reason**: Detailed technical diagram, useful but clutters main doc

**Total Lines to Extract**: ~377 lines (31% of CLAUDE.md)

### 4. Outdated Version References

Multiple sections reference old versions or use "NEW in X.X.X" labels:

| Location | Current Text | Issue |
|----------|--------------|-------|
| README.md:32 | "⚡ What's New in 6.3.1" | Should be "What's New in 6.6.0" or link to CHANGELOG |
| README.md:86 | "(NEW in 6.2.0)" | Version-specific tags unnecessary (over 4 versions old) |
| README.md:649 | "(NEW in 6.3.1)" | Version-specific tags unnecessary |
| CLAUDE.md:287 | "iOS 26.2 shipping, API verification needed" | Contradicts later sections showing it's implemented in 6.6.0 |
| CLAUDE.md:493 | "[NEW in 6.2.0]" | Unnecessary version tag |

**Recommendation**: Remove "NEW in X.X.X" tags older than current major version. Use CHANGELOG.md for version history.

### 5. Confusing PDF Parsing Status

PDF parsing information appears in **three different states** across documentation:

| Location | Status Claim | Accuracy |
|----------|--------------|----------|
| CLAUDE.md:287 | "architecturally prepared (iOS 26.2 shipping, API verification needed)" | ❌ Outdated - implies not implemented |
| CLAUDE.md:826 | "✅ FULLY IMPLEMENTED" | ✅ Accurate |
| README.md:60 | "AI-powered conversion with Apple Intelligence (98%+ accuracy)" | ✅ Accurate but brief |

**Issue**: Users reading CLAUDE.md line 287 think the feature isn't ready, but it's been production-ready since 6.5.0.

**Recommendation**: Remove outdated status from line 287, consolidate all PDF parsing status info in `Docs/FOUNDATION_MODELS_STATUS.md`, reference that doc from both README and CLAUDE.md.

## Recommendations Summary

### High Priority (Broken Functionality)
1. ✅ Fix broken documentation links (update paths to `Docs/old/` or move files)
2. ✅ Remove contradictory PDF parsing status in CLAUDE.md line 287
3. ✅ Update "What's New" section in README to reflect current version (6.6.0)

### Medium Priority (Maintainability)
4. ✅ Extract performance testing to `Docs/PERFORMANCE_TESTING.md`
5. ✅ Extract CI/CD setup to `Docs/CI_CD_SETUP.md`
6. ✅ Extract SwiftData relationships to `Docs/ARCHITECTURE_SWIFTDATA.md`
7. ✅ Extract known issues to `Docs/KNOWN_ISSUES.md`
8. ✅ Extract parsing flow to `Docs/PARSING_ARCHITECTURE.md`

### Low Priority (Polish)
9. ✅ Remove "NEW in X.X.X" tags older than 2 versions
10. ✅ Consolidate GuionViewer documentation (keep brief in README, detailed in CLAUDE.md)
11. ✅ Add brief App Intents mention to README features list

## File Organization Proposal

```
Docs/
├── ACCESSIBILITY.md (existing)
├── AI_IMPLEMENTATION_COMPLETE.md (existing)
├── FOUNDATION_MODELS_STATUS.md (existing, expand)
├── FOUNDATION_MODELS_VERIFICATION.md (existing)
├── STORYBOARD_CLI_PSEUDOCODE.md (existing)
├── ARCHITECTURE_SWIFTDATA.md (NEW - extract from CLAUDE.md)
├── CI_CD_SETUP.md (NEW - extract from CLAUDE.md)
├── KNOWN_ISSUES.md (NEW - extract from CLAUDE.md)
├── MIGRATION_GUIDE.md (NEW - expand with 6.2.0+ migration notes)
├── PARSING_ARCHITECTURE.md (NEW - extract from CLAUDE.md)
├── PERFORMANCE_TESTING.md (NEW - extract from CLAUDE.md)
└── old/
    ├── APP_INTENTS_GUIDE.md (move to Docs/)
    ├── PARSED_FILE_SERVICE_API.md (move to Docs/)
    ├── SOURCE_FILE_TRACKING.md (move to Docs/)
    └── USAGE-SUMMARY.md (move to Docs/)
```

## Impact Assessment

### Lines Affected
- **README.md**: ~50 lines (link updates, version updates, minor edits)
- **CLAUDE.md**: ~400 lines (extracted to new docs, link updates)
- **New Documentation**: ~500 lines (extracted + expanded)

### Time Estimate
- High Priority: 1-2 hours
- Medium Priority: 2-3 hours
- Low Priority: 1 hour
- **Total**: 4-6 hours

## Implementation Order

1. Create new documentation files (ARCHITECTURE_SWIFTDATA.md, CI_CD_SETUP.md, etc.)
2. Move files from `Docs/old/` to `Docs/` (if they're still relevant)
3. Update all broken links in README.md and CLAUDE.md
4. Extract large sections from CLAUDE.md to new docs
5. Remove contradictory/outdated status information
6. Remove old "NEW in X.X.X" tags
7. Update "What's New" section in README

---

**Audit Date**: January 15, 2026
**Audited Files**: README.md (407 lines), CLAUDE.md (1228 lines)
**Issues Found**: 5 categories, 27 specific issues
**Files to Create**: 6 new documentation files
**Files to Move**: 4 files from Docs/old/ to Docs/
