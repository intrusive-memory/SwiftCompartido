# Building SwiftCompartido

## Platform Support

SwiftCompartido is an **iOS and Mac Catalyst library only**. It does **NOT** support macOS standalone.

Supported platforms:
- ✅ iOS 26.0+
- ✅ Mac Catalyst 26.0+
- ❌ macOS standalone (not supported)

## Why `swift build` Doesn't Work

When you run `swift build` or `swift test` without specifying a target, Swift Package Manager tries to build for your host platform (macOS). This causes errors like:

```
error: the library 'SwiftCompartido' requires macos 10.13, but depends on the product 'TextBundle' which requires macos 10.14
```

**This is expected behavior** - the library is not designed to build for macOS standalone.

## How to Build

### Option 1: Use the Build Script (Recommended)

We provide a convenient build script that handles all the platform-specific flags:

```bash
# Build for iOS Simulator (default)
./build.sh

# Run all tests
./build.sh --action test

# Build for Mac Catalyst (arm64)
./build.sh --target catalyst-arm64

# Build for Mac Catalyst (x86_64)
./build.sh --target catalyst-x86

# Clean build artifacts
./build.sh --action clean
```

Run `./build.sh --help` for full usage information.

### Option 2: Use xcodebuild Directly

For iOS Simulator:

```bash
# Build
xcodebuild build \
  -scheme SwiftCompartido \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO

# Test
xcodebuild test \
  -scheme SwiftCompartido \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -enableCodeCoverage YES \
  -parallel-testing-enabled YES \
  CODE_SIGNING_ALLOWED=NO
```

For Mac Catalyst:

```bash
# arm64 (Apple Silicon)
swift build \
  -Xswiftc "-target" \
  -Xswiftc "arm64-apple-ios26.0-macabi"

# x86_64 (Intel)
swift build \
  -Xswiftc "-target" \
  -Xswiftc "x86_64-apple-ios26.0-macabi"
```

## Using in Your App

When integrating SwiftCompartido into your app:

1. **For iOS apps**: Just add as a normal Swift Package dependency
2. **For Mac Catalyst apps**: Add as a dependency and ensure your app target includes Mac Catalyst
3. **For macOS apps**: ❌ Not supported - use the iOS version with Mac Catalyst instead

### Xcode Integration

In Xcode:
1. Add SwiftCompartido as a package dependency
2. Ensure your app target includes iOS and/or Mac Catalyst (not macOS standalone)
3. Build and run normally - Xcode handles the platform selection

## CI/CD

GitHub Actions workflow uses the same approach:

```yaml
- name: Build for iOS Simulator
  run: |
    xcodebuild build \
      -scheme SwiftCompartido \
      -sdk iphonesimulator \
      -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
      CODE_SIGNING_ALLOWED=NO
```

See `.github/workflows/tests.yml` for the complete CI configuration.

## Troubleshooting

### Error: "requires macos X.X"

**Problem**: You're trying to build with `swift build` directly.

**Solution**: Use `./build.sh` or `xcodebuild` with iOS Simulator/Catalyst targets.

### Error: "No such module 'SwiftCompartido'"

**Problem**: The module wasn't built for the target platform.

**Solution**:
1. Clean with `./build.sh --action clean`
2. Build with `./build.sh`
3. Make sure your app target includes iOS or Mac Catalyst

### Error: "Unsupported platform"

**Problem**: Trying to use in a macOS standalone app.

**Solution**: Convert your app to Mac Catalyst or use it only on iOS.

## Questions?

See `CLAUDE.md` for complete architecture documentation and development guidelines.
