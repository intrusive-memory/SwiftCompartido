# GEMINI.md

**⚠️ Read [AGENTS.md](AGENTS.md) first** for universal project documentation, architecture, and development guidelines.

This file contains instructions specific to Google Gemini agents working on SwiftCompartido.

## Quick Reference

**Project**: SwiftCompartido - Screenplay parsing, storage, and SwiftUI display library
**Platforms**: iOS 26.0+, macOS 26.0+
**Architecture**: Phase 6 - file-based storage with DTO pattern for actor isolation

For detailed project info, see **[AGENTS.md](AGENTS.md)**.

## Gemini-Specific Configuration

Gemini agents should use standard CLI tools since MCP (Model Context Protocol) servers are not available.

### Build Commands

Use `xcodebuild` directly for all build and test operations:

```bash
# Build library
xcodebuild build -scheme SwiftCompartido -destination 'platform=macOS'

# Run tests
xcodebuild test -scheme SwiftCompartido -destination 'platform=macOS'

# Build GuionViewer reference app
cd GuionViewer
xcodebuild build -scheme GuionViewer -destination 'platform=macOS'
```

### Test Commands

```bash
# Run all tests
xcodebuild test -scheme SwiftCompartido -destination 'platform=macOS'

# Run specific test
xcodebuild test -scheme SwiftCompartido \
  -destination 'platform=macOS' \
  -only-testing:SwiftCompartidoTests/GuionDocumentSnapshotTests
```

## Gemini-Specific Critical Rules

1. **Use standard CLI tools** - No MCP access, use direct `xcodebuild`, `git`, `gh` commands
2. **Follow Xcode best practices** - Use proper schemes and destinations
3. **NEVER use `swift build` or `swift test`** - SwiftData/SwiftUI require Xcode build system
4. **Test both platforms** - macOS 26.0+ and iOS 26.0+ (if applicable)

## Future Gemini Integrations

Placeholder for future Gemini-specific features:
- Gemini API integration patterns (if needed)
- Gemini Code Assist workflows (if available)
- Gemini-specific automation tools

For now, follow standard CLI workflows as documented in [AGENTS.md](AGENTS.md).
