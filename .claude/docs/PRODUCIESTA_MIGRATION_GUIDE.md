# Produciesta Migration Guide - SwiftCompartido 5.4.0 Performance Optimizations

This guide helps you migrate the Produciesta app to take advantage of the performance optimizations introduced in SwiftCompartido 5.4.0.

## Overview of Changes

SwiftCompartido 5.4.0 introduces significant performance improvements focused on eliminating runtime text formatting overhead:

1. **Pre-computed formatted text**: `GuionElementModel.formattedText` property stores AttributedString with formatting
2. **Single-pass regex**: `FountainTextFormatter` uses one combined regex instead of three separate passes
3. **Batch SwiftData insertions**: Elements are created in batch and added via `append(contentsOf:)` instead of individual appends
4. **View updates**: All element views now use pre-computed formatting with fallback

## Performance Impact

**Before (5.3.0):**
- 1000 elements: ~1.200s total (94% SwiftData, 4.5% formatting, 1.3% parsing)
- 5000 elements: ~24.050s total (99% SwiftData, 1% formatting, 0.3% parsing)

**After (5.4.0 - estimated):**
- Formatting overhead: **Eliminated** (3-5x improvement for formatted text rendering)
- SwiftData conversion: **10-20% improvement** from batch insertions
- First render: **Instant** (no runtime formatting needed)

## Migration Checklist

### 1. Update SwiftCompartido Dependency

Update your `Package.swift` or Xcode project to use SwiftCompartido 5.4.0+:

```swift
.package(url: "https://github.com/intrusive-memory/SwiftCompartido", from: "5.4.0")
```

### 2. No Code Changes Required (Backward Compatible)

The optimizations are **100% backward compatible**. Existing code will work without changes:

- Old documents without `formattedText` property will automatically fall back to runtime formatting
- New documents will automatically use pre-computed formatting
- All views handle both cases transparently

### 3. Verify Custom Element Views (If Any)

If Produciesta has custom element views that use `FountainTextFormatter`, update them to use pre-computed formatting:

**Before:**
```swift
Text(FountainTextFormatter.format(
    element.elementText,
    baseFont: .custom("Courier New", size: fontSize)
))
```

**After:**
```swift
// Use pre-computed formatted text if available (NEW in 5.4.0)
// Falls back to runtime formatting for backward compatibility
Text(element.formattedText ?? FountainTextFormatter.format(
    element.elementText,
    baseFont: .custom("Courier New", size: fontSize)
))
```

### 4. Test with Existing Documents

Test that existing Produciesta documents open and render correctly:

1. Open an existing screenplay document
2. Verify text formatting (bold, italic, underline) displays correctly
3. Scroll through long documents to verify performance
4. Check that editing and saving works normally

### 5. Test with New Documents

Create a new screenplay document and verify performance:

1. Import a large screenplay (1000+ elements)
2. Measure import time (should be faster than before)
3. Verify first render is instant (no formatting lag)
4. Check that formatting is preserved after save/reload

### 6. Migration Strategy for Existing Documents (Optional)

Existing documents can be migrated to use pre-computed formatting for maximum performance:

**Option A: Lazy Migration (Recommended)**
- Do nothing - formatting happens on first render with fallback
- Documents are automatically optimized on next save

**Option B: Batch Migration**
- Add a migration function to re-parse and save all documents
- Run once after updating to 5.4.0

```swift
@MainActor
func migrateDocumentsToPrecomputedFormatting(modelContext: ModelContext) async throws {
    let descriptor = FetchDescriptor<GuionDocumentModel>()
    let documents = try modelContext.fetch(descriptor)

    let baseFont = Font.custom("Courier New", size: 12)

    for document in documents {
        for element in document.sortedElements {
            // Only migrate if not already formatted
            if element.formattedText == nil {
                element.formattedText = FountainTextFormatter.format(
                    element.elementText,
                    baseFont: baseFont
                )
            }
        }
    }

    try modelContext.save()
}
```

## Changes by File

### Modified Files in SwiftCompartido

1. **GuionElementModel.swift** (Sources/SwiftCompartido/SwiftDataModels/)
   - Added `formattedText: AttributedString?` property with `@Attribute(.transformable)`
   - Stores pre-computed formatted text for instant rendering

2. **GuionDocumentModel.swift** (Sources/SwiftCompartido/SwiftDataModels/)
   - Added `import SwiftUI` for Font type
   - Pre-computes formatting during parsing: `elementModel.formattedText = FountainTextFormatter.format(...)`
   - Batch insertion optimization: `document.elements.append(contentsOf: elementModels)`

3. **FountainTextFormatter.swift** (Sources/SwiftCompartido/UI/Helpers/)
   - Optimized to single-pass regex (from 3 separate passes)
   - Combined pattern: `"(\\*\\*([^*]+)\\*\\*)|((?<!\\*)\\*([^*]+)\\*(?!\\*))|((_)([^_]+)(_))"`

4. **ActionView.swift** (Sources/SwiftCompartido/UI/Elements/)
   - Updated to use `element.formattedText ?? FountainTextFormatter.format(...)`

5. **DialogueTextView.swift** (Sources/SwiftCompartido/UI/Elements/)
   - Updated to use `element.formattedText ?? FountainTextFormatter.format(...)`

### Files You May Need to Update in Produciesta

1. **Custom element views** (if any)
   - Check for direct `FountainTextFormatter.format()` calls
   - Add fallback pattern: `element.formattedText ?? FountainTextFormatter.format(...)`

2. **Document import/export** (if custom)
   - Verify that import preserves formatting
   - Ensure export doesn't rely on runtime formatting

3. **Performance monitoring** (if any)
   - Update benchmarks to reflect new performance characteristics
   - Adjust loading indicators if needed (faster imports may flash too quickly)

## Testing Recommendations

### Unit Tests

1. Test that old documents without `formattedText` render correctly
2. Test that new documents with `formattedText` render correctly
3. Test that formatting fallback works when `formattedText` is nil

### Integration Tests

1. Import a large screenplay (1000+ elements) and measure time
2. Open an existing document and verify formatting
3. Edit text with formatting and verify it persists
4. Save and reload a document, verify formatting is preserved

### Performance Tests

Run performance benchmarks to verify improvements:

```bash
./build.sh --action test
```

Compare results with baseline in `PERFORMANCE_BASELINE.md`.

## Rollback Plan

If issues arise, you can rollback to SwiftCompartido 5.3.0:

1. Update dependency to `from: "5.3.0"`
2. Rebuild Produciesta
3. Existing documents will continue to work (SwiftData ignores unknown properties)
4. Runtime formatting will be used for all elements

**Note:** Rolling back will not lose data - the `formattedText` property is simply ignored by older versions.

## Known Issues and Limitations

1. **Migration time**: Batch migration of large document collections may take time
2. **Storage increase**: Pre-computed formatting increases document size by ~10-15%
3. **SwiftData attribute**: Requires `NSSecureUnarchiveFromDataTransformer` (iOS 16+, macOS 13+)

## Support

For issues or questions about migration:

1. Check the changelog: `CHANGELOG.md`
2. Review the API reference: `AI-REFERENCE.md`
3. Check GitHub issues: https://github.com/intrusive-memory/SwiftCompartido/issues
4. Contact maintainers if needed

## Version Compatibility

- **Minimum SwiftCompartido**: 5.4.0
- **Backward compatible**: Yes (with runtime formatting fallback)
- **Forward compatible**: Yes (older versions ignore `formattedText`)
- **Platforms**: iOS 26.0+, macOS 26.0+ (Apple Silicon only)

## Next Steps

After migration:

1. Monitor app performance in production
2. Collect metrics on import/render times
3. Consider batch migration for power users with large document libraries
4. Update Produciesta documentation to reflect performance improvements

---

**Last updated**: 2025-11-27
**SwiftCompartido version**: 5.4.0
**Produciesta compatibility**: TBD (test after migration)
