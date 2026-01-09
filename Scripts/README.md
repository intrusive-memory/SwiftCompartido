# SwiftCompartido Scripts

This directory contains utility scripts for testing and development.

## Apple Intelligence Testing

### test-ai-features.sh

Tests Apple Intelligence (Foundation Models) features for PDF parsing.

**Requirements:**
- iOS 26.2+ / macOS 26.2+ (currently shipping)
- Apple Intelligence enabled in System Settings
- M1+ Mac or A17 Pro+ device

**Usage:**

```bash
# Run on iOS Simulator (default)
./Scripts/test-ai-features.sh

# Run on macOS
./Scripts/test-ai-features.sh --macos

# Run on connected iOS device
./Scripts/test-ai-features.sh --device

# Show help
./Scripts/test-ai-features.sh --help
```

**What it tests:**
- Foundation Models framework availability
- AI-powered PDF to Fountain conversion
- AI vs. heuristic accuracy comparison
- Non-standard format handling (TV pilots)
- Content preservation (no hallucinations)
- System prompt effectiveness (Fountain format compliance)
- Progress reporting during AI conversion
- Multiple PDF processing

**Expected behavior:**
- **iOS 26.2 Shipping**: API availability needs verification
- **Without Apple Intelligence**: Tests will skip (user hasn't enabled)
- **With Apple Intelligence Enabled**: Tests will validate AI-enhanced parsing if API is functional
- **API Not Ready**: Tests will skip gracefully with informative messages

**Not required for contributions** - CI validates heuristic conversion (production baseline).

## Test Plans

SwiftCompartido uses multiple test plans for different testing scenarios:

| Test Plan | Purpose | When to Run |
|-----------|---------|-------------|
| **UnitTests** | Fast unit tests | Every PR (CI) |
| **LongTests** | Integration tests | Weekends (CI) |
| **UITests** | SwiftUI view tests | Manual or weekends |
| **PerformanceTests** | Benchmarks | After unit tests (CI) |
| **AITests** | Apple Intelligence | Manual with script |

### Running AI Tests

```bash
# Option 1: Use the script (recommended)
./Scripts/test-ai-features.sh

# Option 2: Direct xcodebuild
xcodebuild test \
  -scheme SwiftCompartido \
  -testPlan AITests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## When to Use AI Tests

**Use AI tests when:**
- ✅ Working on Foundation Models integration
- ✅ Validating AI-enhanced accuracy
- ✅ Comparing AI vs. heuristic quality
- ✅ You have Apple Intelligence enabled locally

**Don't use AI tests for:**
- ❌ Regular development (use UnitTests or LongTests)
- ❌ CI/CD pipelines (Apple Intelligence unavailable)
- ❌ Contributing to the project (not required)

## Contributing

All contributors should focus on:
1. **UnitTests** - Fast tests for everyday development
2. **LongTests** - Comprehensive integration tests

AI tests are optional and only useful if you have Apple Intelligence enabled.
