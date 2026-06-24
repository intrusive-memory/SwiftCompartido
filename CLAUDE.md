---
type: doc
---

# CLAUDE.md

**⚠️ Read [AGENTS.md](AGENTS.md) first** for universal project documentation, architecture, and development guidelines.

This file contains instructions specific to Claude Code agents working on SwiftCompartido.

## Quick Reference

**Project**: SwiftCompartido - Screenplay parsing, storage, and SwiftUI display library
**Platforms**: iOS 26.0+, macOS 26.0+
**Architecture**: Phase 6 - file-based storage with DTO pattern for actor isolation

For detailed project info, see **[AGENTS.md](AGENTS.md)**.

## Claude-Specific Build Preferences

**CRITICAL**: NEVER use `swift build` or `swift test` to compile or test Swift projects. ALWAYS use `xcodebuild` (or XcodeBuildMCP tools when available) instead.

- **Local builds**: Use XcodeBuildMCP tools (`swift_package_build`, `swift_package_test`, `build_macos`, `test_macos`, etc.)
- **CI/CD workflows**: Use `xcodebuild build` and `xcodebuild test` with appropriate `-scheme` and `-destination` flags
- This applies to Swift packages, Xcode projects, and all Swift-based projects

### Why xcodebuild over swift build?

SwiftCompartido uses SwiftData and SwiftUI which work best with Xcode's build system. The `swift build` command may not properly configure the environment for these frameworks.

## MCP Server Configuration

### XcodeBuildMCP

**CRITICAL**: XcodeBuildMCP is installed and should be used for ALL Xcode operations instead of direct `xcodebuild` or `xcrun` commands.

**Available Operations**:
- **Building**: `build_sim`, `build_device`, `build_macos`, `build_run_sim`, `build_run_macos`
- **Testing**: `test_sim`, `test_device`, `test_macos`
- **Simulator Management**: `list_sims`, `boot_sim`, `open_sim`, `install_app_sim`, `launch_app_sim`, `stop_app_sim`, `erase_sims`
- **Device Management**: `list_devices`, `install_app_device`, `launch_app_device`, `stop_app_device`
- **UI Automation**: `tap`, `swipe`, `type_text`, `screenshot`, `describe_ui`, `long_press`, `gesture`
- **Project Info**: `discover_projs`, `list_schemes`, `show_build_settings`, `get_sim_app_path`, `get_device_app_path`, `get_mac_app_path`
- **Swift Packages**: `swift_package_build`, `swift_package_test`, `swift_package_run`, `swift_package_clean`
- **Scaffolding**: `scaffold_ios_project`, `scaffold_macos_project`
- **Utilities**: `clean`, `get_app_bundle_id`, `set_sim_appearance`, `set_sim_location`, `record_sim_video`

**Usage Pattern**:
```swift
// ❌ DON'T use direct xcodebuild
xcodebuild -scheme SwiftCompartido -destination 'platform=macOS'

// ✅ DO use XcodeBuildMCP tools
// Use build_macos or test_macos with scheme parameter
```

**Benefits**:
- Structured output instead of parsing xcodebuild text
- Built-in error handling and retry logic
- Faster incremental builds with experimental build system
- Automatic simulator discovery by name
- Better CI/CD integration

### App Store Connect MCP

**CRITICAL**: App Store Connect MCP is installed and should be used for App Store metrics, TestFlight, and **Xcode Cloud CI/CD monitoring**.

**Available Operations**:
- **Apps**: `list_apps`, `get_app` - App metadata and details
- **Financial**: `get_sales_report`, `get_revenue_metrics`, `get_subscription_metrics` - Revenue and subscription analytics
- **Xcode Cloud**: `get_xcode_cloud_summary`, `list_xcode_cloud_products`, `get_xcode_cloud_workflows`, `get_xcode_cloud_builds`, `get_xcode_cloud_build_details` - **Full CI/CD workflow monitoring** ✨
- **TestFlight**: `get_testflight_metrics`, `get_beta_testers` - Beta testing data
- **Reviews**: `get_customer_reviews`, `get_review_metrics` - Customer feedback
- **Analytics**: `get_app_analytics` - User engagement metrics
- **Health**: `test_connection`, `get_api_stats` - API status and rate limits

**Usage Pattern**:
```bash
# ❌ DON'T manually call App Store Connect API
curl -H "Authorization: Bearer ..." https://api.appstoreconnect.apple.com/v1/apps

# ✅ DO use appstore-connect MCP (via Claude)
# "Show me TestFlight metrics for SwiftCompartido"
# "What's the success rate of my CI/CD workflows?"
```

## Claude-Specific Critical Rules

1. **ALWAYS use XcodeBuildMCP tools** instead of direct `xcodebuild` commands
2. **NEVER use `swift build` or `swift test`** - Use `xcodebuild` or XcodeBuildMCP instead
3. **Leverage MCP servers** for automation and monitoring
4. **Follow global CLAUDE.md patterns** from `~/.claude/CLAUDE.md`:
   - Complete candor in communication
   - Never expose secrets or environment variables
   - Use `xcodebuild` for all Swift projects
   - Follow git safety protocols

## Global Claude Settings

Your global Claude instructions: `~/.claude/CLAUDE.md`

Key patterns from global config:
- **Communication Style**: Complete candor, flag risks up front
- **Security**: NEVER echo environment variables or credentials
- **Swift Build Preference**: ALWAYS use `xcodebuild` over `swift build`
- **Git Safety**: Never force push, skip hooks, or use destructive commands without confirmation
- **GitHub Actions CI/CD**: Always use `macos-26` or later, specify exact iOS versions

See `~/.claude/CLAUDE.md` for complete global instructions.
