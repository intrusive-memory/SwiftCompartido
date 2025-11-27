# Debug Build Features

This document describes the debug-only features available in SwiftCompartido for development and debugging purposes.

## Debug Borders for GuionElement Views

### Overview

All GuionElement views (ActionView, SceneHeadingView, DialogueTextView, etc.) automatically display a **1px red border** in DEBUG builds. This helps developers:

- Visualize element boundaries
- Debug spacing and layout issues
- Identify rendering problems
- Understand element composition

### How It Works

The debug border feature uses Swift's conditional compilation to only add borders in DEBUG builds:

```swift
#if DEBUG
content
    .border(Color.red, width: 1)
#else
content
#endif
```

**In DEBUG builds:**
- All GuionElement views have visible red borders
- No performance impact (borders are native SwiftUI)
- Automatically enabled, no configuration needed

**In RELEASE builds:**
- No borders rendered
- Zero overhead
- Clean production appearance

### Building with Debug Features

#### Debug Build (with borders)

```bash
# iOS Simulator
./build.sh

# macOS
xcodebuild build \
  -scheme SwiftCompartido \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
```

#### Release Build (no borders)

```bash
# iOS Simulator
xcodebuild build \
  -scheme SwiftCompartido \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO

# macOS
xcodebuild build \
  -scheme SwiftCompartido \
  -destination 'platform=macOS' \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO
```

### Implementation Details

**DebugBorderModifier.swift**
- View modifier that conditionally adds borders
- Only active in DEBUG configuration
- Applied to all element views via `.debugBorder()` extension

**GuionElementRow.swift**
- Each element type has `.debugBorder()` applied
- Applied in the `elementView` computed property
- Covers all 12 element types:
  - ActionView
  - SceneHeadingView
  - DialogueCharacterView
  - DialogueTextView
  - DialogueParentheticalView
  - DialogueLyricsView
  - TransitionView
  - SectionHeadingView
  - SynopsisView
  - CommentView
  - BoneyardView
  - PageBreakView

### Adding Debug Features to Custom Views

You can use the `.debugBorder()` modifier on any SwiftUI view:

```swift
import SwiftUI

struct MyCustomView: View {
    var body: some View {
        Text("My Content")
            .debugBorder()  // Red border in DEBUG builds only
    }
}
```

### Customizing Debug Borders

To change the border color or width, modify `DebugBorderModifier.swift`:

```swift
struct DebugBorderModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if DEBUG
        content
            .border(Color.blue, width: 2)  // Blue, 2px border
        #else
        content
        #endif
    }
}
```

### Future Debug Features

Planned additions:
- Element type labels overlaid on elements
- Performance metrics display
- Memory usage indicators
- Touch/hover area visualization
- Relationship graph visualization

## Best Practices

1. **Always test in DEBUG mode first** to identify layout issues
2. **Verify RELEASE builds** before shipping to ensure borders are removed
3. **Use debug borders** when adjusting spacing, padding, or alignment
4. **Create screenshots** in DEBUG mode for bug reports (shows element boundaries)

## Troubleshooting

**Borders not showing:**
- Verify you're building with `-configuration Debug`
- Check that `DEBUG` flag is set in build settings
- Confirm the view is actually being rendered

**Borders showing in production:**
- Double-check build configuration is `Release`
- Verify no `DEBUG` flag in release build settings
- Clean build folder and rebuild

## See Also

- [UI Components Documentation](../AI-REFERENCE.md#ui-components)
- [Element Views](../Sources/SwiftCompartido/UI/Elements/)
- [Build Script](../build.sh)
