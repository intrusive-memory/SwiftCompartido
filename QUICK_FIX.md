# Quick Fix for Action/Dialogue Truncation

## The Problem

GeometryReader combined with `.fixedSize(horizontal: false, vertical: false)` is causing truncation.

## Root Cause Analysis

1. **GeometryReader** doesn't have intrinsic height - it takes whatever the parent gives it
2. **`.fixedSize(vertical: false)`** tells SwiftUI "don't expand beyond parent height"
3. Result: Text gets truncated if it needs more height than parent provides

## Proposed Fix

Change `.fixedSize()` modifier in **TWO files**:

### File 1: ActionView.swift

**Current (line 41):**
```swift
.fixedSize(horizontal: false, vertical: false)
```

**Change to:**
```swift
.fixedSize(horizontal: false, vertical: true)
```

### File 2: DialogueTextView.swift

**Current (line 41):**
```swift
.fixedSize(horizontal: false, vertical: false)
```

**Change to:**
```swift
.fixedSize(horizontal: false, vertical: true)
```

## What This Does

- `horizontal: false` → Text wraps within the maxWidth constraint (good)
- `vertical: true` → View expands to show ALL content, no truncation (what we want)

## Alternative Fix (if above doesn't work)

If changing `.fixedSize()` doesn't work, the issue might be GeometryReader itself. Try removing GeometryReader entirely:

### ActionView.swift - Alternative Structure

```swift
public var body: some View {
    HStack(alignment: .top, spacing: 0) {
        // 10% left spacer
        Spacer()
            .frame(minWidth: 0)
            .layoutPriority(1)

        Text(element.elementText)
            .font(.custom("Courier New", size: fontSize))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(10)

        // 10% right spacer
        Spacer()
            .frame(minWidth: 0)
            .layoutPriority(1)
    }
    .padding(.horizontal, UIScreen.main.bounds.width * 0.10) // or geometry from parent
    .padding(.vertical, fontSize * 0.35)
}
```

## Test the Fix

After making changes, test with this screenplay fragment:

```fountain
INT. STEAM ROOM - DAY

Bernard and Killian sit in a steam room at an upscale gym. The heat is oppressive, sweat dripping down their faces. They sit in silence for a moment, the tension palpable between them as steam rises around their bodies.

BERNARD
I know what you did. I know everything. There's no point in pretending anymore. The evidence is overwhelming and the truth will come out eventually.
```

Both the action paragraph and Bernard's dialogue should display in full, wrapped across multiple lines.

## Quick Command to Apply Fix

```bash
cd /Users/stovak/Projects/SwiftCompartido

# Backup current files
cp Sources/SwiftCompartido/UI/Elements/ActionView.swift Sources/SwiftCompartido/UI/Elements/ActionView.swift.backup
cp Sources/SwiftCompartido/UI/Elements/DialogueTextView.swift Sources/SwiftCompartido/UI/Elements/DialogueTextView.swift.backup

# Apply fix (change vertical: false to vertical: true)
sed -i '' 's/\.fixedSize(horizontal: false, vertical: false)/.fixedSize(horizontal: false, vertical: true)/g' Sources/SwiftCompartido/UI/Elements/ActionView.swift
sed -i '' 's/\.fixedSize(horizontal: false, vertical: false)/.fixedSize(horizontal: false, vertical: true)/g' Sources/SwiftCompartido/UI/Elements/DialogueTextView.swift

# Test
swift build && swift test
```

## Verify the Fix

```bash
# Check the changes were applied
grep "fixedSize" Sources/SwiftCompartido/UI/Elements/ActionView.swift
grep "fixedSize" Sources/SwiftCompartido/UI/Elements/DialogueTextView.swift

# Should show: .fixedSize(horizontal: false, vertical: true)
```
