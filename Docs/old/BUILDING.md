# Building SwiftCompartido

## Platform Support

SwiftCompartido supports iOS, macOS, and Mac Catalyst.

Supported platforms:
- ✅ iOS 26.0+
- ✅ macOS 26.0+
- ✅ Mac Catalyst 26.0+

## Building for macOS

The library now supports macOS 26.0+. You can use `swift build` and `swift test` directly on macOS, or use the build script for iOS and Mac Catalyst targets.

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
2. **For macOS apps**: Just add as a normal Swift Package dependency (requires macOS 26.0+)
3. **For Mac Catalyst apps**: Add as a dependency and ensure your app target includes Mac Catalyst

### Xcode Integration

In Xcode:
1. Add SwiftCompartido as a package dependency
2. Ensure your app target includes iOS, macOS (26.0+), or Mac Catalyst
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

**Problem**: You may be using an older version of macOS.

**Solution**: Ensure you're running macOS 26.0 or later, or use `./build.sh` to build for iOS Simulator/Catalyst targets.

### Error: "No such module 'SwiftCompartido'"

**Problem**: The module wasn't built for the target platform.

**Solution**:
1. Clean with `./build.sh --action clean`
2. Build with `./build.sh`
3. Make sure your app target includes iOS, macOS 26.0+, or Mac Catalyst

### Error: "Unsupported platform"

**Problem**: Trying to use on an unsupported platform or OS version.

**Solution**: Ensure your app target is set to iOS 26.0+, macOS 26.0+, or Mac Catalyst 26.0+.

## Questions?

See `CLAUDE.md` for complete architecture documentation and development guidelines.
