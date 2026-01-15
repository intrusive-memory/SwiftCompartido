# SwiftCompartido Scripts

This directory contains utility scripts for testing, development, and voice management.

## Voice Download Tools

### 📱 download-premium-voices.applescript

**Interactive AppleScript that guides users through downloading Enhanced and Premium system voices.**

**What it does:**
1. Opens System Settings → Accessibility → Read & Speak
2. Navigates to System voice selection panel
3. Guides user to download Enhanced/Premium voices for their language
4. Optionally attempts automatic download

**Usage:**
```bash
./Scripts/download-premium-voices.applescript
```

**Requirements:**
- macOS 26.0+
- User must approve System Events automation when prompted

**Integration into your app:**

1. **Bundle the script** in your app's Resources:
   ```
   YourApp.app/Contents/Resources/Scripts/download-premium-voices.applescript
   ```

2. **Use VoiceDownloadHelper** (included in SwiftCompartido):
   ```swift
   import SwiftCompartido

   VoiceDownloadHelper.promptUserToDownloadPremiumVoices { result in
       switch result {
       case .success:
           print("Voice download launched successfully")
       case .failure(let error):
           print("Error: \(error)")
       }
   }
   ```

3. **Add to Info.plist**:
   ```xml
   <key>NSAppleEventsUsageDescription</key>
   <string>This app automates System Settings to help you download Premium voices.</string>
   ```

**See:** [Voice Download Guide](../Docs/VOICE_DOWNLOAD_GUIDE.md) for complete documentation.

---

### 🔧 VoiceDownloadHelper.swift

**Swift helper class for programmatic voice download and management.**

**Features:**
- Prompt users to download Premium voices
- Check installed voices and quality
- SwiftUI integration with ready-to-use buttons
- Automatic script discovery and execution

**API:**
```swift
// Check voice status
if VoiceDownloadHelper.isUsingPremiumVoice() {
    print("Using Premium voice!")
}

// Get installed voices
let voices = VoiceDownloadHelper.getInstalledVoices()

// Prompt for download
VoiceDownloadHelper.promptUserToDownloadPremiumVoices { result in
    // Handle result
}
```

**SwiftUI Components:**
```swift
// Ready-to-use button
DownloadPremiumVoicesButton(label: "Download Premium Voices") { success in
    print("Completed: \(success)")
}

// View modifier for sheets
.presentVoiceDownload(isPresented: $showVoiceDownload)
```

---

### 🎨 VoiceDownloadExample.swift

**Example SwiftUI app demonstrating voice download integration.**

**Features:**
- Display current system voice status
- List all installed voices with quality indicators
- Test Text-to-Speech with sample text
- Download Premium voices button
- Voice quality badges (Premium ⭐, Enhanced, Standard)

**How to use:**
1. Copy into a new SwiftUI macOS app project
2. Import SwiftCompartido package
3. Set deployment target to macOS 26.0+
4. Run to see voice management UI

**Perfect for:**
- Reference implementation for settings screens
- Testing voice download workflow
- Demonstrating voice quality differences to users

---

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
