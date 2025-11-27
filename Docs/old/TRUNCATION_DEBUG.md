# Action & Dialogue Line Truncation Debugging Guide

## Problem
Both action lines and dialogue lines are being truncated with "..." instead of showing full multi-line paragraphs.

## Debugging Strategy

### Step 1: Identify Where Truncation Happens

Run this test to see if truncation is in the element views or parent containers:

```swift
// In Xcode Preview or test app
import SwiftUI
import SwiftCompartido

struct TruncationDebugView: View {
    let longText = """
    Bernard and Killian sit in a steam room at an upscale gym. The heat is oppressive, sweat dripping down their faces. They sit in silence for a moment, the tension palpable between them as steam rises around their bodies.
    """

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                // Test 1: Raw ActionView in isolation
                Group {
                    Text("Test 1: ActionView Isolated")
                        .font(.headline)

                    ActionView(element: GuionElementModel(
                        elementText: longText,
                        elementType: .action
                    ))
                    .environment(\.screenplayFontSize, 12)
                    .frame(height: 200) // Give it explicit height
                    .border(Color.red)
                }

                // Test 2: Raw DialogueTextView in isolation
                Group {
                    Text("Test 2: DialogueTextView Isolated")
                        .font(.headline)

                    DialogueTextView(element: GuionElementModel(
                        elementText: longText,
                        elementType: .dialogue
                    ))
                    .environment(\.screenplayFontSize, 12)
                    .frame(height: 200) // Give it explicit height
                    .border(Color.blue)
                }

                // Test 3: In VStack like SceneWidget uses
                Group {
                    Text("Test 3: In VStack (like SceneWidget)")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        ActionView(element: GuionElementModel(
                            elementText: longText,
                            elementType: .action
                        ))
                        .environment(\.screenplayFontSize, 12)
                    }
                    .border(Color.green)
                }

                // Test 4: Plain Text control
                Group {
                    Text("Test 4: Plain Text (no custom view)")
                        .font(.headline)

                    Text(longText)
                        .font(.custom("Courier New", size: 12))
                        .padding(.horizontal, 40)
                        .border(Color.orange)
                }
            }
            .padding()
        }
        .frame(width: 800, height: 1000)
    }
}
```

### Step 2: Check for `.lineLimit()` Modifiers

Search for any `.lineLimit()` calls that might be truncating text:

```bash
# In terminal
cd /Users/stovak/Projects/SwiftCompartido
grep -r "lineLimit" Sources/SwiftCompartido/UI/ --include="*.swift"
```

### Step 3: Check GeometryReader Height Issue

The problem might be that GeometryReader doesn't have an intrinsic height. Test this:

```swift
// Modified ActionView to see if height is the issue
public var body: some View {
    VStack(spacing: 0) {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                Spacer().frame(width: geometry.size.width * 0.10)

                Text(element.elementText)
                    .font(.custom("Courier New", size: fontSize))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: geometry.size.width * 0.80, alignment: .leading)
                    .background(Color.yellow.opacity(0.2)) // DEBUG

                Spacer().frame(width: geometry.size.width * 0.10)
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .background(Color.red.opacity(0.1)) // DEBUG
        .border(Color.purple, width: 2) // DEBUG
    }
    .fixedSize(horizontal: false, vertical: true) // CHANGED: vertical: true
    .padding(.vertical, fontSize * 0.35)
}
```

### Step 4: Common Truncation Causes

Check these common issues:

#### A. Parent Container with Fixed Height
```swift
// BAD - causes truncation
VStack {
    ActionView(...)
}
.frame(height: 100) // Fixed height truncates

// GOOD - allows expansion
VStack {
    ActionView(...)
}
.frame(maxHeight: .infinity) // Or no height constraint
```

#### B. Missing .fixedSize()
```swift
// BAD - may truncate
Text(longText)
    .frame(maxWidth: 300)

// GOOD - expands vertically
Text(longText)
    .frame(maxWidth: 300)
    .fixedSize(horizontal: false, vertical: true)
```

#### C. GeometryReader Without Height
```swift
// BAD - GeometryReader collapses to minimal height
GeometryReader { geometry in
    Text(longText)
}

// GOOD - fixedSize allows natural height
GeometryReader { geometry in
    Text(longText)
}
.fixedSize(horizontal: false, vertical: true)
```

#### D. Implicit LineLimit from Environment
```swift
// Check if there's an environment lineLimit being set
@Environment(\.lineLimit) var lineLimit
```

### Step 5: Check SceneWidget Container

Look at how SceneWidget uses these views:

```swift
VStack(alignment: .leading, spacing: fontSize * 0.5) {
    ForEach(...) { blockIndex in
        if dialogueBlocks[blockIndex].isDialogueBlock {
            DialogueBlockView(block: dialogueBlocks[blockIndex])
        } else {
            switch element.elementType {
            case .action:
                ActionView(element: element)
            // ...
```

Is there a height constraint on this VStack? Check for:
- `.frame(height: ...)`
- `.frame(maxHeight: ...)`
- Parent containers with fixed dimensions

### Step 6: Proposed Fix

Based on the issue affecting BOTH ActionView and DialogueTextView, try this fix:

**Change in ActionView.swift and DialogueTextView.swift:**

```swift
// CURRENT (line 41):
.fixedSize(horizontal: false, vertical: false)

// CHANGE TO:
.fixedSize(horizontal: false, vertical: true)
```

This tells SwiftUI:
- `horizontal: false` - Allow horizontal wrapping within maxWidth
- `vertical: true` - Expand vertically to fit ALL content (don't truncate)

## Quick Test Commands

```bash
# Build and test
swift build
swift test

# Search for truncation-causing modifiers
grep -r "lineLimit" Sources/SwiftCompartido/UI/
grep -r "\.frame(height:" Sources/SwiftCompartido/UI/
grep -r "\.frame(maxHeight:" Sources/SwiftCompartido/UI/
grep -r "truncationMode" Sources/SwiftCompartido/UI/
```

## Expected Behavior

✅ **Correct**: Multi-line paragraphs display in full, wrapping at margins
❌ **Bug**: Text shows "..." after one line

## Files to Check

1. `Sources/SwiftCompartido/UI/Elements/ActionView.swift` (line 41)
2. `Sources/SwiftCompartido/UI/Elements/DialogueTextView.swift` (line 41)
3. `Sources/SwiftCompartido/UI/SceneWidget.swift` (the VStack container)
4. `Sources/SwiftCompartido/UI/Elements/DialogueBlockView.swift`

## Next Steps

1. Run the TruncationDebugView above to see which test case shows truncation
2. Check if `.fixedSize(horizontal: false, vertical: true)` fixes it
3. If not, check parent containers in SceneWidget
4. Look for any environment modifiers affecting text
