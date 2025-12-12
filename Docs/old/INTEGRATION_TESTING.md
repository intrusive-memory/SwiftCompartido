# Integration Testing Guide

Comprehensive guide for running scriptable integration tests before each SwiftCompartido release.

## Overview

SwiftCompartido provides App Intents integration that enables scriptable testing of major library functions. This allows you to validate core functionality end-to-end before releasing new versions.

## Quick Start

```bash
# Run all integration tests
./Scripts/integration-test.sh

# Expected output:
# ✓ All tests passed!
# SwiftCompartido is ready for release.
```

## What Gets Tested

The integration test suite validates these critical workflows:

### 1. Parse Screenplay (All Elements)
- **Function**: `ParseScreenplayFileIntent`
- **Test**: Parse `bigfish.fountain` without filters
- **Validates**:
  - File format detection (Fountain, FDX, PDF, etc.)
  - Element extraction
  - SwiftData persistence
  - Minimum element count (>100 elements expected)

### 2. Parse with Filtering
- **Function**: `ParseScreenplayFileIntent` with element type filter
- **Test**: Parse `bigfish.fountain` filtering only dialogue
- **Validates**:
  - Element type filtering during parse
  - Correct dialogue detection
  - Minimum dialogue count (>50 dialogue elements expected)

### 3. Query Existing Document
- **Function**: `QueryScreenplayElementsIntent`
- **Test**: Query elements with character filter
- **Validates**:
  - Document querying by PersistentIdentifier
  - Character name filtering
  - Element text search

### 4. Element Type Detection
- **Function**: `ElementTypeQuery` (App Intents support)
- **Test**: Query all available element types
- **Validates**:
  - All 7 screenplay element types available
  - Correct element type enumeration
  - App Intents entity queries

### 5. Roundtrip (Parse → Export)
- **Function**: End-to-end parse and export
- **Test**: Parse file and verify document creation
- **Validates**:
  - Parse completes successfully
  - Document persisted to SwiftData
  - No data loss during roundtrip

## Test Architecture

### App Intents as Test Interface

The integration tests use App Intents as the scriptable interface:

```
┌─────────────────────────────────────────┐
│     Integration Test Script             │
│     (Scripts/integration-test.sh)       │
└─────────────────┬───────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│          App Intents Layer              │
│  - ParseScreenplayFileIntent            │
│  - QueryScreenplayElementsIntent        │
└─────────────────┬───────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│         ParsedFileService               │
│  (Unified service layer)                │
└─────────────────┬───────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│       Core SwiftCompartido APIs         │
│  - GuionParsedElementCollection         │
│  - GuionDocumentModel                   │
│  - FDXDocumentWriter, etc.              │
└─────────────────────────────────────────┘
```

**Key Benefit**: Testing via App Intents validates the same code paths that Shortcuts users will execute.

## Pre-Release Checklist

Before releasing a new version:

1. **Run integration tests**:
   ```bash
   ./Scripts/integration-test.sh
   ```

2. **Verify all tests pass** (exit code 0)

3. **Check for warnings**:
   ```bash
   # Review build logs
   cat /tmp/integration-test-build.log | grep -i warning
   ```

4. **Test on both platforms** (if possible):
   ```bash
   # iOS Simulator (default)
   ./Scripts/integration-test.sh

   # macOS (modify script destination)
   # Edit Scripts/integration-test.sh to use:
   # -destination 'platform=macOS'
   ```

5. **Update CHANGELOG.md** with test results

6. **Tag and release** only if all tests pass

## Test Fixtures

### Required Files

- **`Fixtures/bigfish.fountain`** (primary test file)
  - Full-length screenplay (~120 pages)
  - Comprehensive element types
  - Used for all integration tests

### Adding New Test Files

To add new test fixtures:

1. Place file in `Fixtures/` directory
2. Update `Scripts/integration-test.sh` with new tests
3. Document expected element counts
4. Update `.gitignore` if file is large

## Interpreting Results

### Success Output

```
=========================================
SwiftCompartido Integration Tests
=========================================
Testing library via App Intents for pre-release validation
Test file: Fixtures/bigfish.fountain

✓ PASS: Test fixture found
✓ PASS: Build succeeded
✓ PASS: Parse all elements test passed
✓ PASS: Dialogue filter test passed
✓ PASS: Query elements test passed
✓ PASS: Element type detection test passed
✓ PASS: Roundtrip test passed

=========================================
Test Summary
=========================================
Tests passed: 5
Tests failed: 0

✓ All tests passed!
SwiftCompartido is ready for release.
```

### Failure Output

```
✗ FAIL: Parse all elements test failed
error: testParseFile_fountain() - Expected element count > 100, got 42

=========================================
Test Summary
=========================================
Tests passed: 4
Tests failed: 1

✗ Some tests failed!
Please fix failures before releasing.
```

## Advanced Usage

### Running Individual Tests

Instead of the full suite, run specific tests:

```bash
# Test 1: Parse all elements
xcodebuild test \
  -scheme SwiftCompartido \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:SwiftCompartidoTests/AppIntentsIntegrationTests/testParseScreenplayFileIntent_Init \
  CODE_SIGNING_ALLOWED=NO

# Test 2: Dialogue filtering
xcodebuild test \
  -scheme SwiftCompartido \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:SwiftCompartidoTests/ParsedFileServiceTests/testElementsWithFilter_dialogue \
  CODE_SIGNING_ALLOWED=NO
```

### Custom Test Scenarios

Create custom test scenarios by:

1. Adding new test files to `Fixtures/`
2. Creating new test methods in `AppIntentsIntegrationTests.swift`
3. Adding test calls to `Scripts/integration-test.sh`

Example custom test:

```swift
@Test("ParseScreenplayFileIntent: Custom FDX file")
func testParseScreenplayFileIntent_CustomFDX() async throws {
    let fileURL = try fixtureURL(named: "my-script.fdx")

    var intent = ParseScreenplayFileIntent()
    intent.fileURL = fileURL

    let result = try await intent.perform()

    #expect(result.value.elements.count > 0)
    #expect(result.value.title == "My Script")
}
```

## Shortcuts Integration

You can also create Shortcuts that run these tests:

### Create a "Test SwiftCompartido" Shortcut

1. Open Shortcuts app
2. Create new Shortcut
3. Add actions:
   - **Get File** → `Fixtures/bigfish.fountain`
   - **Parse Screenplay File** (SwiftCompartido)
   - **Get Variable** → Count of elements
   - **If** count > 100:
     - **Show Notification** "✓ Test passed"
   - **Otherwise**:
     - **Show Notification** "✗ Test failed"

4. Run shortcut before each release

### Voice Command Testing

Test Siri integration:

1. Say: **"Import screenplay with SwiftCompartido"**
2. Select test file
3. Verify elements are extracted
4. Say: **"Query screenplay elements in SwiftCompartido"**
5. Filter by dialogue
6. Verify dialogue elements returned

## CI/CD Integration

### GitHub Actions Workflow

Add integration tests to CI:

```yaml
name: Integration Tests

on:
  pull_request:
    branches: [main]

jobs:
  integration-tests:
    name: Integration Tests
    runs-on: macos-26

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run integration tests
        run: ./Scripts/integration-test.sh

      - name: Upload test logs
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: integration-test-logs
          path: /tmp/integration-test-*.log
```

## Troubleshooting

### Build Failures

**Error**: `Build failed (see /tmp/integration-test-build.log)`

**Solution**:
```bash
cat /tmp/integration-test-build.log
# Fix compilation errors
./build.sh  # Verify build works
```

### Test Fixture Not Found

**Error**: `Test fixture not found: Fixtures/bigfish.fountain`

**Solution**:
```bash
ls Fixtures/  # Verify file exists
git lfs pull  # If using Git LFS for large files
```

### Simulator Not Available

**Error**: `xcodebuild: iPhone 17 Pro not found`

**Solution**:
```bash
xcrun simctl list devices
# Use available simulator name
# Or create iPhone 17 Pro simulator in Xcode
```

### App Intent Not Registered

**Error**: `Intent 'ParseScreenplayFileIntent' not found`

**Solution**:
```bash
# Rebuild and reinstall on simulator
./build.sh
# App Intents register on first build
```

## Version History

- **6.1.0**: Initial integration test suite
- **Future**: Add export format validation, performance benchmarks

## See Also

- [App Intents Guide](./APP_INTENTS_GUIDE.md) - Complete Shortcuts integration guide
- [ParsedFileService API](./PARSED_FILE_SERVICE_API.md) - Service layer API reference
- [.claude/WORKFLOW.md](../.claude/WORKFLOW.md) - Release workflow documentation
