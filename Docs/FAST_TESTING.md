# Fast Parallel Testing Guide

## Quick Commands

### Fastest (Recommended)
```bash
# Build in parallel (12 cores) + Run tests in parallel
swift test --parallel --num-workers 12 -j 12
```

### Medium Speed
```bash
# Parallel build only
swift test -j 12
```

### Default (Slowest)
```bash
# Serial execution
swift test
```

---

## Parallel Testing Options

### 1. Build Parallelization (`-j` or `--jobs`)
Controls how many build jobs run simultaneously:

```bash
# Use all 12 cores for building
swift test -j 12

# Use 8 cores (leave some for system)
swift test -j 8

# Auto-detect cores
swift test -j $(sysctl -n hw.ncpu)
```

**Impact**: Speeds up compilation phase

---

### 2. Test Parallelization (`--parallel`)
Runs multiple test suites simultaneously:

```bash
# Enable parallel test execution
swift test --parallel

# Disable (default)
swift test --no-parallel
```

**Impact**: Speeds up test execution phase

---

### 3. Worker Count (`--num-workers`)
Controls how many test workers run in parallel:

```bash
# Run 12 tests simultaneously
swift test --parallel --num-workers 12

# Run 8 tests simultaneously (safer)
swift test --parallel --num-workers 8

# Auto-detect
swift test --parallel --num-workers $(sysctl -n hw.ncpu)
```

**Impact**: More workers = faster tests, but may cause race conditions if tests aren't thread-safe

---

## Recommended Configurations

### Development (Fast Iteration)
```bash
# Quick feedback, use most cores
swift test --parallel --num-workers 10 -j 12
```

### CI/CD (Maximum Speed)
```bash
# Use all available cores
swift test --parallel --num-workers $(sysctl -n hw.ncpu) -j $(sysctl -n hw.ncpu)
```

### Debugging (When Tests Fail)
```bash
# Serial execution for clear error messages
swift test --no-parallel
```

### Single Test Suite
```bash
# Run specific test faster
swift test --parallel -j 12 --filter FountainParserTests
```

---

## Performance Comparison

Based on 314 tests in 22 suites:

| Configuration | Expected Time | Notes |
|---------------|---------------|-------|
| Default (serial) | ~75 seconds | Current baseline |
| `-j 12` only | ~50 seconds | Faster build, serial tests |
| `--parallel` only | ~60 seconds | Serial build, parallel tests |
| `-j 12 --parallel --num-workers 12` | **~20-30 seconds** | ✨ Fastest |
| `-j 12 --parallel --num-workers 8` | ~25-35 seconds | Safer (fewer race conditions) |

---

## Test Safety Considerations

SwiftCompartido tests are **mostly thread-safe** because:
- ✅ Most tests use `@MainActor` (thread-safe by design)
- ✅ File-based tests use unique temp directories per test
- ✅ SwiftData tests use in-memory contexts
- ⚠️ Some tests may share resources (check if parallel causes failures)

### If Parallel Tests Fail

1. **Identify problematic test**:
   ```bash
   swift test --parallel --num-workers 2
   # Gradually increase workers to find breaking point
   ```

2. **Run that test in isolation**:
   ```bash
   swift test --filter ProblematicTestName --no-parallel
   ```

3. **Mark test as serial** (if needed):
   ```swift
   @Test(.serialized) // Forces this test to run alone
   func testSharedResource() {
       // ...
   }
   ```

---

## GitHub Actions CI Optimization

Update `.github/workflows/tests.yml` to use parallel testing:

```yaml
- name: Run Tests
  run: |
    # Use all available cores in CI
    swift test --parallel --num-workers $(sysctl -n hw.ncpu) -j $(sysctl -n hw.ncpu)
```

Current CI runners typically have 3-4 cores, so this would speed up CI significantly.

---

## Xcode Alternative

If using Xcode instead of command line:

1. **Product → Test** (⌘U)
2. **Edit Scheme → Test → Options**:
   - ✅ Enable "Execute in parallel on Simulator"
   - ✅ Set "Maximum concurrent test runners" to 8-12

---

## Aliases for Your Shell

Add to `~/.zshrc` or `~/.bashrc`:

```bash
# Fast tests
alias swifttest-fast='swift test --parallel --num-workers 12 -j 12'

# Safe parallel
alias swifttest-parallel='swift test --parallel --num-workers 8 -j 12'

# Debug mode
alias swifttest-debug='swift test --no-parallel'

# Single suite fast
swifttest-filter() {
    swift test --parallel -j 12 --filter "$1"
}
```

Then use:
```bash
swifttest-fast
swifttest-filter FountainParserTests
```

---

## Memory Considerations

With 12 parallel workers, you might need ~4-8GB RAM:
- Each test worker: ~300-500MB
- Build process: ~2-3GB
- Total: ~6-9GB

Your Mac likely has 16GB+ so this should be fine.

---

## Watch Mode for Development

Combine with `fswatch` for auto-testing:

```bash
# Install fswatch
brew install fswatch

# Auto-run tests on file changes
fswatch -o Sources/ Tests/ | xargs -n1 -I{} swift test --parallel -j 12
```

---

## Summary

**Best command for daily development:**
```bash
swift test --parallel --num-workers 10 -j 12
```

**Expected speedup:** 2-3x faster (75s → 25-30s)

**Trade-off:** Slightly harder to read errors, but much faster iteration
