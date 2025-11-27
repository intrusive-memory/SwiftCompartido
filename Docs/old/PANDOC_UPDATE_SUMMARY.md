# Pandoc Document Import - ODT & RTF Update Summary

## What Changed

The DOCX import requirements have been expanded to support **ODT and RTF** formats using the same Pandoc infrastructure.

## File Renaming

- **Old**: `Docs/DOCX_IMPORT_REQUIREMENTS.md`
- **New**: `Docs/PANDOC_IMPORT_REQUIREMENTS.md`

## Key Updates

### 1. Parser Renamed

- **Old**: `DocxParser`
- **New**: `PandocDocumentParser`

**Rationale**: Generic name supports multiple formats (DOCX, ODT, RTF)

### 2. Supported Formats (3 formats)

| Format | Extension | Source | User Value | Added |
|--------|-----------|--------|------------|-------|
| **DOCX** | `.docx` | Microsoft Word | ⭐⭐⭐⭐⭐ | Week 2-3 |
| **ODT** | `.odt` | LibreOffice, Google Docs | ⭐⭐⭐⭐⭐ | Week 3 |
| **RTF** | `.rtf` | TextEdit, Universal | ⭐⭐⭐⭐⭐ | Week 3 |

### 3. Test Count Updates

| Category | Old (DOCX only) | New (DOCX + ODT + RTF) |
|----------|-----------------|------------------------|
| Unit tests | 35-40 | 50-55 |
| Integration tests | 10 | 17 |
| UI tests | 10 | 18 |
| Performance tests | 5 | 6 |
| **Total new tests** | **~55** | **~90** |
| **Total project tests** | **492** | **527** |

### 4. Fixture Updates

**Old**: 18 DOCX fixtures

**New**: 30 total fixtures
- DOCX: 18 files (unchanged)
- ODT: 7 files (new)
- RTF: 6 files (new)

### 5. Implementation Changes

**Code impact**: Minimal (2-3 lines per format)

```swift
// Detection
let inputFormat = switch ext {
    case "docx": "docx"
    case "odt": "odt"   // +1 line
    case "rtf": "rtf"   // +1 line
    default: throw error
}

// Conversion (same code path)
pandoc -f \(inputFormat) -t markdown file
```

### 6. Timeline Impact

**Old**: 5 weeks (DOCX only)
**New**: 5 weeks (DOCX + ODT + RTF)

**Week 3 additions**:
- Add ODT support (+1 day)
- Add RTF support (+1 day)
- Total: +2 days to Week 3

No change to total timeline (Week 3 has capacity)

### 7. User Experience Improvements

**Before** (DOCX only):
```
Supported imports:
- Microsoft Word (.docx)
```

**After** (DOCX + ODT + RTF):
```
Supported imports:
- Microsoft Word (.docx)
- LibreOffice, Google Docs (.odt)
- TextEdit, Universal (.rtf)
```

**Marketing message**:
> "Import from anywhere: Word, LibreOffice, Google Docs, TextEdit, and more. SwiftCompartido speaks 50+ document formats."

### 8. File Size Impact

**No change**: 0 MB additional (Pandoc already bundled)

### 9. Documentation Updates

Files updated:
- ✅ `PANDOC_IMPORT_REQUIREMENTS.md` (renamed from DOCX_IMPORT_REQUIREMENTS.md)
- ✅ `PANDOC_SUPPORTED_FORMATS.md` (new, comprehensive format guide)
- 🔄 `README.md` (pending - add ODT and RTF to supported formats)
- 🔄 `CLAUDE.md` (pending - update parser architecture)
- 🔄 `AI-REFERENCE.md` (pending - update API docs)
- 🔄 `CHANGELOG.md` (pending - document v5.0.0 features)

### 10. Error Messages

**Old**:
```
Error: Unsupported file format .odt
Please convert to .docx or .fountain
```

**New**:
```
✅ Successfully imported from LibreOffice ODT
```

## Breaking Changes

**None**. This is purely additive.

- Existing DOCX implementation unchanged
- Existing parsers (Fountain, Markdown, FDX, PDF) unchanged
- SwiftData schema unchanged
- UI rendering unchanged

## Migration Path

No migration needed. Existing code continues to work.

Optional: Rename `DocxParser` → `PandocDocumentParser` for consistency

## Benefits Summary

### For Users

✅ **LibreOffice users**: Can import ODT files directly (no conversion)
✅ **Free software users**: Don't need Microsoft Word
✅ **Universal compatibility**: RTF works everywhere (TextEdit, Word, LibreOffice)
✅ **No conversion step**: Direct import from any source

### For Development

✅ **Zero file size cost**: Pandoc already bundled
✅ **Minimal code changes**: 2 lines per format
✅ **Shared infrastructure**: All formats use same code path
✅ **Easy testing**: Same test patterns for all formats

### For Project

✅ **Competitive advantage**: "Import from 50+ formats"
✅ **Low-knowledge friendly**: Works with free software (LibreOffice)
✅ **Future-proof**: Easy to add EPUB, HTML, IPYNB later

## Next Steps

### Week 3 Implementation

1. **Day 1-2**: DOCX support (as planned)
2. **Day 3**: Add ODT support
   - Add `case "odt": "odt"` to parser
   - Create 7 ODT test fixtures
   - Write ~10 ODT tests
3. **Day 4**: Add RTF support
   - Add `case "rtf": "rtf"` to parser
   - Create 6 RTF test fixtures
   - Write ~10 RTF tests
4. **Day 5**: Integration testing
   - Test all 3 formats together
   - Cross-format compatibility tests
   - UI rendering tests

### Post-Implementation

1. Update README.md with new formats
2. Update CLAUDE.md parser architecture
3. Update AI-REFERENCE.md API documentation
4. Create v5.0.0 changelog entry
5. Create PR with all changes
6. Merge when CI passes (527 tests green)

## Success Metrics

✅ All 527 tests passing
✅ 90%+ code coverage maintained
✅ No regressions in existing parsers
✅ Users can import DOCX, ODT, RTF files
✅ All formats render identically (GitHub-style markdown)
✅ Performance < 2 seconds for 100-page documents (all formats)

## Questions Resolved

1. ✅ Should we support ODT? **YES** - High value, zero cost
2. ✅ Should we support RTF? **YES** - Universal format, zero cost
3. ✅ Timeline impact? **+2 days to Week 3** (within capacity)
4. ✅ Breaking changes? **NONE** - Purely additive
5. ✅ File size impact? **NONE** - Pandoc already bundled
6. ✅ Test burden? **+35 tests** (manageable, same patterns)
7. ✅ Should we add EPUB now? **NO** - Save for v5.1
8. ✅ Should we add HTML now? **NO** - Save for v5.2

---

**Status**: Ready for implementation
**Timeline**: Week 3 (DOCX + ODT + RTF)
**Risk**: LOW (minimal code changes, same infrastructure)
**Value**: HIGH (3 formats for price of 1)
**Recommendation**: **PROCEED** with ODT and RTF in same PR as DOCX
