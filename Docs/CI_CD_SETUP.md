# CI/CD Setup Guide

This document describes SwiftCompartido's continuous integration and deployment configuration, including GitHub Actions workflows, branch protection rules, and simulator management.

## GitHub Actions Workflows

SwiftCompartido uses GitHub Actions for automated testing and quality checks on every pull request.

### Main Workflows

#### 1. **tests.yml** - Unit Tests (Runs on every PR)

**Triggers**:
- Pull requests to `main` or `development`
- Push to `development` branch

**Jobs**:
- **iOS Tests (Short)**: Fast unit tests on iPhone 17 Pro simulator (~300 tests, 2-5 min)
- **macOS Tests (Short)**: Fast unit tests on macOS platform (~300 tests, 2-5 min)
- **Code Quality**: Checks for TODOs, large files, print statements

**Test Plan**: `UnitTests.xctestplan`

**Required for merge**: ✅ Yes - All jobs must pass

#### 2. **long-tests.yml** - Integration Tests (Runs on weekends)

**Triggers**:
- Scheduled: Saturdays and Sundays at 2 AM UTC
- Manual trigger via GitHub Actions UI

**Jobs**:
- **iOS Long Tests**: Integration tests with file I/O (~100 tests, 10-15 min)
- **macOS Long Tests**: Integration tests on macOS platform (~100 tests, 10-15 min)
- **Coverage Report**: Uploads to Codecov with separate flags for iOS and macOS

**Test Plan**: `LongTests.xctestplan`

**Required for merge**: ❌ No - Informational only

#### 3. **ui-tests.yml** - UI Component Tests (Manual)

**Triggers**:
- Manual trigger via GitHub Actions UI

**Jobs**:
- **iOS UI Tests**: SwiftUI view tests, gesture handlers, accessibility tests

**Test Plan**: `UITests.xctestplan`

**Required for merge**: ❌ No - Informational only

#### 4. **performance.yml** - Performance Benchmarks (Non-blocking)

**Triggers**:
- After unit tests pass on PR

**Jobs**:
- **Performance Tests**: Benchmarks in Release configuration
- **Upload Metrics**: JSON reports uploaded as artifacts (90-day retention)

**Test Plan**: `PerformanceTests.xctestplan`

**Required for merge**: ❌ No - Non-blocking

---

## Dynamic Simulator Creation

**⚠️ CRITICAL**: GitHub Actions `macos-26` runners don't have iPhone simulators pre-installed.

### Problem

Available simulators on GitHub Actions runners:
- ✅ Apple TV (tvOS)
- ✅ Apple Watch (watchOS)
- ✅ Apple Vision Pro (visionOS)
- ❌ **NO iPhone simulators** (must be created)

Without simulator creation, all iOS tests fail with:
```
xcodebuild: error: Unable to find a destination matching the provided destination specifier:
        { platform:iOS Simulator, name:iPhone 17 Pro }
```

### Solution

All iOS workflows include a "Create iPhone Simulator" step that:

1. **Detects latest iOS runtime** using `xcrun simctl list runtimes`
2. **Tries multiple iPhone models** (fallback chain):
   - iPhone 16 Pro
   - iPhone 16
   - iPhone 15 Pro
   - iPhone 15
3. **Creates simulator** named "iPhone-Test"
4. **Boots simulator** before tests run

### Implementation

```yaml
- name: Create iPhone Simulator
  run: |
    echo "📱 Creating iPhone simulator for testing"

    # Get latest iOS runtime
    RUNTIME=$(xcrun simctl list runtimes iOS -j | jq -r '.runtimes | sort_by(.version) | last | .identifier')
    echo "Using runtime: $RUNTIME"

    # Try multiple device types (fallback chain)
    for DEVICE in "iPhone-16-Pro" "iPhone-16" "iPhone-15-Pro" "iPhone-15"; do
      DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.$DEVICE"
      UDID=$(xcrun simctl create "iPhone-Test" "$DEVICE_TYPE" "$RUNTIME" 2>&1 || echo "")

      if [[ -n "$UDID" && "$UDID" != *"error"* ]]; then
        echo "✅ Created simulator: $UDID"
        xcrun simctl boot "$UDID" || true
        break
      fi
    done

- name: Build for iOS Simulator
  run: |
    xcodebuild build \
      -scheme SwiftCompartido \
      -sdk iphonesimulator \
      -destination 'platform=iOS Simulator,name=iPhone-Test' \
      CODE_SIGNING_ALLOWED=NO
```

### Affected Workflows

- `.github/workflows/tests.yml`
- `.github/workflows/ui-tests.yml`
- `.github/workflows/long-tests.yml`
- `.github/workflows/performance.yml`

### Why This Matters

- Generic destinations like `platform=iOS Simulator` don't work (no actual devices)
- Placeholder destinations only work for build-for-testing, not actual test execution
- Simulator name must be consistent across steps (use `iPhone-Test` in all workflows)

---

## Branch Protection Rules

The `main` branch has **required status checks** that must pass before PRs can be merged.

### Current Protection Rules

**Required Status Checks**:
- `iOS Tests (Short)` - Fast unit tests on iOS Simulator
- `macOS Tests (Short)` - Fast unit tests on macOS
- `Code Quality` - Linting and quality checks

**Configuration**:
- **Direct pushes**: ❌ Blocked
- **PR required**: ✅ Yes
- **PR review required**: ❌ No (optional)
- **Strict status checks**: ✅ Yes (branch must be up-to-date)

### Viewing Current Protections

```bash
gh api repos/intrusive-memory/SwiftCompartido/branches/main/protection/required_status_checks
```

**Output**:
```json
{
  "strict": true,
  "contexts": [
    "iOS Tests (Short)",
    "macOS Tests (Short)",
    "Code Quality"
  ]
}
```

### Updating Branch Protections

**⚠️ IMPORTANT**: Update branch protections when CI workflow job names change.

**When to Update**:
- ✅ When CI workflow job names change
- ✅ When test jobs are added or removed
- ✅ When platforms are added or removed (iOS, macOS)
- ✅ When test structure is reorganized (short vs long tests)

**How to Update**:

```bash
gh api --method PATCH repos/intrusive-memory/SwiftCompartido/branches/main/protection/required_status_checks \
  -H "Accept: application/vnd.github.v3+json" \
  --input - <<'EOF'
{
  "strict": true,
  "contexts": [
    "iOS Tests (Short)",
    "macOS Tests (Short)",
    "Code Quality"
  ]
}
EOF
```

**Best Practices**:
- Keep checks minimal but essential (fast feedback loop)
- Align check names **exactly** with CI workflow job names
- Document protection changes in PR descriptions
- Test protection changes by creating a test PR

### Common Issues

#### Issue: PR can't merge with "Required status check missing"

**Cause**: Job name in workflow doesn't match branch protection rule.

**Fix**: Update job name in workflow or update branch protection rule.

**Example**:
```yaml
# Workflow file (.github/workflows/tests.yml)
jobs:
  test-ios:
    name: iOS Tests (Short)  # ← Must match branch protection exactly
```

#### Issue: Branch protection blocks valid PRs

**Cause**: Required check no longer exists (renamed or removed).

**Fix**: Remove outdated check from branch protection rules.

---

## Codecov Integration

SwiftCompartido uploads test coverage reports to Codecov for tracking coverage trends.

### Coverage Flags

- `ios`: iOS Simulator test coverage
- `macos`: macOS test coverage

### Viewing Coverage Reports

1. Visit: https://codecov.io/gh/intrusive-memory/SwiftCompartido
2. Select branch or PR
3. View coverage by flag (iOS vs macOS)

### Coverage Thresholds

- **Target**: 90% overall coverage
- **Current**: 95%+ across both platforms
- **Alerts**: PRs that decrease coverage by > 1%

---

## Local CI Testing

To test CI workflows locally before pushing:

### Using `act` (GitHub Actions locally)

```bash
# Install act
brew install act

# Run unit tests workflow
act pull_request -W .github/workflows/tests.yml

# Run long tests workflow
act schedule -W .github/workflows/long-tests.yml
```

### Manual Testing

```bash
# Run unit tests (same as CI)
xcodebuild test \
  -scheme SwiftCompartido \
  -testPlan UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -enableCodeCoverage YES \
  CODE_SIGNING_ALLOWED=NO

# Run macOS tests
xcodebuild test \
  -scheme SwiftCompartido \
  -testPlan UnitTests \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES \
  CODE_SIGNING_ALLOWED=NO
```

---

## Troubleshooting

### iOS Tests Fail with "Device not found"

**Cause**: iPhone simulator not created.

**Fix**: Add "Create iPhone Simulator" step before test step.

### macOS Tests Pass Locally but Fail in CI

**Cause**: Different Xcode version or macOS version.

**Fix**: Check workflow `runs-on: macos-26` matches local environment.

### Code Quality Check Fails with "TODO found"

**Cause**: TODO/FIXME comments in code.

**Fix**: Resolve or remove TODO comments before merging.

### Coverage Report Not Uploaded

**Cause**: Codecov token missing or expired.

**Fix**: Check GitHub Secrets for `CODECOV_TOKEN`.

---

## CI Performance Optimization

### Current Test Execution Times

- **Unit Tests (iOS)**: 2-5 minutes
- **Unit Tests (macOS)**: 2-5 minutes
- **Long Tests (iOS)**: 10-15 minutes
- **Long Tests (macOS)**: 10-15 minutes
- **Performance Tests**: 5-10 minutes

### Optimization Strategies

1. **Test Plan Organization**: Fast tests in `UnitTests.xctestplan`, slow tests in `LongTests.xctestplan`
2. **Parallel Execution**: iOS and macOS tests run in parallel
3. **Weekend Scheduling**: Long tests run on weekends to avoid PR delays
4. **Non-Blocking Performance**: Performance tests don't block PRs

---

## References

- Workflows: `.github/workflows/`
- Test Plans: `*.xctestplan` files
- Branch Protection: GitHub repository settings
- Codecov: https://codecov.io/gh/intrusive-memory/SwiftCompartido
- Workflow Guide: [.claude/WORKFLOW.md](../.claude/WORKFLOW.md)
