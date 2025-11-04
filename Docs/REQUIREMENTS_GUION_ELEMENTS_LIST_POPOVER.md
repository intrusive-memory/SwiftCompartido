# Requirements: GuionElementsList Popover Delegate

## Overview

Add interactive popover support to `GuionElementsList` that displays contextual content and controls (e.g., GENERATE button) when hovering or long-pressing screenplay elements.

**Key Features:**
- Environment-based closure pattern (SwiftUI-idiomatic)
- Interactive content support (buttons, controls)
- Multi-platform: hover (macOS/iPad trackpad) and long-press (iOS touch)
- Size-constrained: 400pt wide × 100pt tall maximum
- Auto-dismiss when leaving element/popover area

## Functional Requirements

### FR-1: Delegate Protocol Definition

**FR-1.1**: Create a protocol `GuionElementPopoverDelegate` that provides popover content
- Protocol must be thread-safe (`@MainActor`)
- Must support generic SwiftUI view content
- Should use `@ViewBuilder` pattern for flexible content creation

**FR-1.2**: Delegate method signature
```swift
@MainActor
protocol GuionElementPopoverDelegate {
    associatedtype PopoverContent: View

    @ViewBuilder
    func popoverContent(for element: GuionElement) -> PopoverContent
}
```

**FR-1.3**: Alternative: Closure-based approach (SwiftUI-friendly)
```swift
struct GuionElementPopoverProvider<Content: View> {
    let content: (GuionElement) -> Content
}
```

### FR-2: GuionElementsList Integration

**FR-2.1**: Add optional popover parameter to `GuionElementsList`
- Parameter must be optional (nil = no popovers)
- Should use type-erased wrapper for flexibility
- Must not break existing API (backward compatible)

**FR-2.2**: Example API usage
```swift
GuionElementsList(document: screenplay) { element in
    Button("Action") { }
}
.popoverDelegate { element in
    VStack {
        Text(element.content)
        Text("Chapter \(element.chapterIndex)")
    }
}
```

**FR-2.3**: Pass delegate to row views
- Delegate should be passed via environment or parameter
- Each row should independently manage its hover state
- Rows without delegate should behave identically to current implementation

### FR-3: Hover Detection

**FR-3.1**: Platform-specific hover support
- **macOS**: Use `.onHover` modifier
- **iOS/iPadOS**: Use `.onHover` for trackpad/mouse support
- **iOS (touch)**: Use long-press gesture (see FR-8)

**FR-3.2**: Hover timing behavior for interactive popovers
- Show popover after **300ms** hover delay (configurable)
- **Extended hover area**: Popover stays visible while mouse is over:
  - The screenplay element row, OR
  - The popover itself
- Dismiss only when mouse leaves BOTH element and popover
- **Grace period**: 100ms transition time when moving from element to popover (prevents flicker)
- Cancel pending popover if user moves to different element

**FR-3.3**: Hover state management
- Each element row maintains its own hover state
- Only one popover visible at a time
- Moving from element A to element B: hide A's popover, show B's popover after delay

### FR-4: Popover Display

**FR-4.1**: Popover positioning and size
- Display popover **above** the hovered element by default
- Fallback to below if insufficient space above
- Align popover center with element center (horizontal)
- Respect safe area insets
- **Size constraints:**
  - Maximum width: **400pt**
  - Maximum height: **100pt**
  - Content should scroll if it exceeds height limit

**FR-4.2**: Popover appearance
- Semi-transparent background blur (`.ultraThinMaterial` on macOS, `.regularMaterial` on iOS)
- Rounded corners (12pt radius)
- Subtle shadow for depth
- Padding: 12pt on all sides

**FR-4.3**: Popover interaction
- Popover **MUST support interaction** (buttons, controls, etc.)
- Mouse/touch events on popover content are handled normally
- Primary use case: GENERATE button and audio generation controls
- Popover stays visible while user interacts with controls
- User can still scroll the underlying list (popover moves with element)

**FR-4.4**: Z-index and layering
- Popover appears in `.overlay` layer above list
- Does not affect list layout or scrolling
- Multiple popovers never stack (only one visible)

### FR-5: Performance Requirements

**FR-5.1**: Lazy content creation
- Popover content must only be created when hover occurs
- Do not pre-render popovers for all elements
- Dispose of popover content immediately when hover ends

**FR-5.2**: Scroll performance
- Hovering while scrolling should not cause lag
- Rapidly moving mouse over elements should not create popover spam
- Debounce hover events to prevent excessive rendering

**FR-5.3**: Memory management
- No strong reference cycles between delegate and list
- Hover state should not retain element references unnecessarily
- Popover views cleaned up when dismissed

### FR-6: Accessibility Requirements

**FR-6.1**: Keyboard navigation
- Popovers should appear when element receives keyboard focus
- Arrow keys navigate between elements, triggering popovers
- Same 300ms delay applies to keyboard focus

**FR-6.2**: VoiceOver support
- Popover content must be readable by VoiceOver
- Use `.accessibilityElement(children: .combine)` to merge content
- Provide accessible label: "Additional information: [popover content]"

**FR-6.3**: Reduced motion support
- Respect `@Environment(\.accessibilityReduceMotion)`
- Disable fade-in animation if reduced motion is enabled
- Popover appears instantly (still with 300ms delay)

### FR-7: Configuration Options

**FR-7.1**: Configurable hover delay
```swift
.popoverDelegate(hoverDelay: 500) { element in
    // Content
}
```

**FR-7.2**: Configurable popover style
```swift
.popoverDelegate(style: .compact) { element in
    // Content
}

enum PopoverStyle {
    case compact    // Minimal padding, small shadow
    case standard   // Default appearance
    case prominent  // Larger padding, strong shadow
}
```

**FR-7.3**: Disable popovers per element
- Delegate should be able to return `EmptyView()` to skip popover for specific elements
- No popover shown if delegate returns nil content (optional protocol method)

### FR-8: Touch Gesture Support

**FR-8.1**: Long-press gesture for touch devices
- **Long-press duration**: 500ms
- Trigger popover display after successful long-press
- Provide haptic feedback when popover appears (`.impact` style, medium intensity)
- Works on iPhone and iPad (touch-only devices)

**FR-8.2**: Long-press dismissal
- **Tap outside** element or popover to dismiss
- **Tap inside** popover to interact (buttons, controls)
- **Scroll gesture** on list dismisses popover
- **Tap on different element** dismisses current popover, does NOT trigger long-press on new element

**FR-8.3**: Long-press visual feedback
- Element should highlight during long-press (subtle background tint)
- Progress indicator (optional): Show radial progress during 500ms delay
- Cancel long-press if finger moves more than 10pt from original position

**FR-8.4**: Platform detection
- Automatically use hover on devices with mouse/trackpad
- Automatically use long-press on touch-only devices
- Support both simultaneously on iPad (trackpad + touch)

## Non-Functional Requirements

### NFR-1: Code Quality

- All new code must have 90%+ test coverage
- Follow existing SwiftCompartido architecture patterns
- Use Swift 6 concurrency model (`@MainActor`, `Sendable`)
- Document public APIs with DocC comments

### NFR-2: Platform Compatibility

- Must work on iOS 26.0+, macOS 26.0+, Mac Catalyst 26.0+
- Gracefully degrade on platforms without hover support
- Respect platform-specific design guidelines (HIG)

### NFR-3: Backward Compatibility

- Existing `GuionElementsList` usage must continue to work unchanged
- No breaking changes to public API
- Popovers are opt-in feature via modifier

### NFR-4: Performance Benchmarks

- Popover display latency: < 50ms after hover delay expires
- No frame drops when hovering rapidly over elements
- Memory footprint: < 1MB for 100 active popover states

## User Stories

### US-1: Display Element Metadata
**As a** screenplay editor
**I want to** see element metadata when hovering over elements
**So that** I can quickly understand context without opening detail views

**Acceptance Criteria:**
- Hover over element shows popover with metadata
- Popover includes chapter index, element type, word count
- Popover appears within 300ms of hover start
- Popover dismisses immediately when hover ends

### US-2: Generate Audio from Popover
**As a** screenplay editor
**I want to** click a GENERATE button in the hover popover
**So that** I can generate audio for elements without leaving the list view

**Acceptance Criteria:**
- Popover contains interactive GENERATE button
- Button remains clickable while popover is visible
- Popover shows generation status (pending, in progress, completed)
- Popover includes voice name and model used
- Popover stays visible during generation process
- Can interact with button via hover (macOS) or long-press (iOS)

### US-3: Custom Popover Content
**As a** developer integrating SwiftCompartido
**I want to** provide custom popover content for my use case
**So that** I can show app-specific metadata

**Acceptance Criteria:**
- Can pass closure that returns arbitrary SwiftUI view
- Popover renders custom content correctly
- Custom content respects popover styling and positioning

## Technical Design Notes

### Recommended Approach: Environment-Based

```swift
// 1. Define environment key
struct GuionElementPopoverKey: EnvironmentKey {
    static let defaultValue: GuionElementPopoverProvider? = nil
}

extension EnvironmentValues {
    var guionElementPopover: GuionElementPopoverProvider? {
        get { self[GuionElementPopoverKey.self] }
        set { self[GuionElementPopoverKey.self] = newValue }
    }
}

// 2. Type-erased provider
struct GuionElementPopoverProvider {
    private let _content: (GuionElement) -> AnyView

    init<Content: View>(@ViewBuilder content: @escaping (GuionElement) -> Content) {
        self._content = { element in AnyView(content(element)) }
    }

    func callAsFunction(_ element: GuionElement) -> AnyView {
        _content(element)
    }
}

// 3. View modifier
extension View {
    func guionElementPopover<Content: View>(
        hoverDelay: TimeInterval = 0.3,
        @ViewBuilder content: @escaping (GuionElement) -> Content
    ) -> some View {
        self.environment(\.guionElementPopover, GuionElementPopoverProvider(content: content))
    }
}

// 4. Usage in GuionElementsList row (with interactive popover support)
struct GuionElementRow: View {
    let element: GuionElement
    @Environment(\.guionElementPopover) private var popoverProvider
    @State private var isHoveringElement = false
    @State private var isHoveringPopover = false
    @State private var showPopover = false
    @State private var hoverTask: Task<Void, Never>?

    private var isHovering: Bool {
        isHoveringElement || isHoveringPopover
    }

    var body: some View {
        // Row content
        .onHover { hovering in
            isHoveringElement = hovering

            if hovering {
                // Start hover delay
                hoverTask?.cancel()
                hoverTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    if isHoveringElement { showPopover = true }
                }
            } else {
                hoverTask?.cancel()
                // Grace period before dismissing
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    if !isHovering { showPopover = false }
                }
            }
        }
        .overlay(alignment: .top) {
            if showPopover, let provider = popoverProvider {
                provider(element)
                    .frame(maxWidth: 400, maxHeight: 100)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(radius: 8)
                    .offset(y: -8)
                    .onHover { hoveringPopover in
                        isHoveringPopover = hoveringPopover
                        if !isHovering {
                            showPopover = false
                        }
                    }
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            // Touch device support
            showPopover = true
            #if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            #endif
        }
    }
}
```

## Implementation Methodology

### Development Approach

**Iterative, phased implementation** with continuous testing and integration. Each phase delivers working functionality that can be tested independently.

### Implementation Phases

#### Phase 1: Core Infrastructure (2-3 days)
**Goal**: Establish popover provider pattern and basic display

**Tasks:**
1. Create `GuionElementPopoverProvider` type-erased wrapper
2. Define `GuionElementPopoverKey` environment key
3. Implement `.guionElementPopover()` view modifier
4. Add environment support to `GuionElementsList`
5. Write unit tests for provider initialization and environment propagation

**Deliverable**: Popover infrastructure works, but no display yet

**Success Criteria:**
- Environment values propagate correctly to row views
- Type-erased provider accepts any View content
- All unit tests pass (90%+ coverage)

---

#### Phase 2: Hover Display (2-3 days)
**Goal**: Display read-only popovers on hover (macOS/trackpad)

**Tasks:**
1. Add hover detection to element rows (`.onHover` modifier)
2. Implement 300ms delay timing with Task cancellation
3. Create popover overlay with positioning logic
4. Apply size constraints (400pt × 100pt)
5. Add styling (material background, shadow, corners)
6. Write tests for hover state management and timing

**Deliverable**: Non-interactive popovers appear on hover

**Success Criteria:**
- Popover appears after 300ms hover delay
- Popover dismisses immediately on hover end
- Only one popover visible at a time
- Positioning works (above/below element)
- Size constraints enforced

---

#### Phase 3: Interactive Support (2-3 days)
**Goal**: Enable interaction with popover content (buttons, controls)

**Tasks:**
1. Add hover detection to popover itself (`.onHover` on overlay)
2. Implement extended hover area logic (element OR popover)
3. Add 100ms grace period for transitions
4. Refactor hover state management (separate element/popover states)
5. Test button clicks and control interaction
6. Write integration tests for interactive behavior

**Deliverable**: Buttons and controls inside popovers are fully functional

**Success Criteria:**
- Mouse can move from element to popover without dismissing
- 100ms grace period prevents flicker
- Buttons inside popover are clickable
- Popover stays visible during interaction
- Dismiss logic works correctly (leaves both areas)

---

#### Phase 4: Touch Gesture Support (2-3 days)
**Goal**: Add long-press support for iOS touch devices

**Tasks:**
1. Add `.onLongPressGesture(minimumDuration: 0.5)` to element rows
2. Implement haptic feedback on long-press trigger
3. Add visual feedback during long-press (highlight)
4. Implement tap-outside-to-dismiss logic
5. Add scroll-to-dismiss behavior
6. Test on iOS simulator (iPhone and iPad)
7. Write tests for long-press gesture recognition

**Deliverable**: Full touch device support via long-press

**Success Criteria:**
- 500ms long-press triggers popover on iOS
- Haptic feedback occurs on trigger
- Visual feedback during press
- Tap outside dismisses popover
- Scrolling dismisses popover
- Long-press cancels if finger moves >10pt

---

#### Phase 5: Accessibility & Polish (1-2 days)
**Goal**: Ensure accessibility compliance and smooth UX

**Tasks:**
1. Add keyboard focus support (popover appears on focus)
2. Implement VoiceOver support (accessible labels)
3. Add reduced motion support (disable animations)
4. Optimize scroll performance (dismiss on scroll start)
5. Add fade-in/fade-out animations
6. Write accessibility tests
7. Perform manual testing with VoiceOver

**Deliverable**: Fully accessible, polished feature

**Success Criteria:**
- Keyboard navigation triggers popovers
- VoiceOver reads popover content correctly
- Reduced motion setting respected
- No frame drops during scroll
- Animations smooth and subtle

---

#### Phase 6: Integration & Documentation (1-2 days)
**Goal**: Integrate with existing codebase and document

**Tasks:**
1. Add example usage to sample app/tests
2. Write DocC documentation for public API
3. Update `GUION_ELEMENTS_LIST_COLUMNS.md` with popover section
4. Create example popover content for GENERATE button
5. Perform end-to-end testing on all platforms
6. Code review and final adjustments

**Deliverable**: Feature ready for production use

**Success Criteria:**
- Documentation complete and accurate
- Example code demonstrates all features
- All 437+ existing tests still pass
- New tests achieve 90%+ coverage
- Code review approved

---

### Risk Mitigation

**Risk 1: Hover state bugs with extended area**
- **Mitigation**: Extensive unit tests for state transitions
- **Contingency**: Add debug logging for hover state changes during development

**Risk 2: Performance impact on list scrolling**
- **Mitigation**: Performance tests with 100+ elements, lazy content creation
- **Contingency**: Add `.onAppear`/`.onDisappear` optimizations if needed

**Risk 3: Platform-specific gesture conflicts**
- **Mitigation**: Test on all platforms early (iOS, macOS, Catalyst)
- **Contingency**: Make gesture support configurable per-platform

**Risk 4: Accessibility issues not caught in automated tests**
- **Mitigation**: Manual testing with VoiceOver, keyboard-only navigation
- **Contingency**: User testing with accessibility tools before release

**Risk 5: Breaking changes to existing GuionElementsList users**
- **Mitigation**: Comprehensive backward compatibility tests
- **Contingency**: Feature flag to disable popovers if issues arise

---

### Code Review Process

1. **Phase completion**: Submit PR after each phase
2. **Self-review checklist**:
   - [ ] All tests pass (existing + new)
   - [ ] 90%+ coverage for new code
   - [ ] DocC comments on public APIs
   - [ ] No compiler warnings
   - [ ] Follows Swift 6 concurrency model
   - [ ] No performance regressions
3. **Peer review focus**:
   - Architecture consistency with existing patterns
   - Edge case handling (rapid hovers, multiple elements)
   - Memory management (no retain cycles)
   - Accessibility compliance
4. **Approval criteria**: 2+ approvers, all CI checks pass

---

### Integration Strategy

**Backward Compatibility:**
- Feature is opt-in via `.guionElementPopover()` modifier
- Existing `GuionElementsList` usage unchanged
- No modifications to `GuionElement` model
- Environment value defaults to `nil` (no popovers)

**Version Requirements:**
- Target: SwiftCompartido 3.4.0 (new minor version)
- Reason: New public API (view modifier), non-breaking addition

**Rollout Plan:**
1. Merge to `development` branch after all phases complete
2. Beta testing period: 1 week with sample app
3. Address any bugs/issues from beta testing
4. Merge to `main` via PR
5. Tag release: `v3.4.0`
6. Update CHANGELOG.md with feature description

---

## Testing Plan

### Overview

Comprehensive testing strategy covering unit, integration, UI, performance, and accessibility testing across all supported platforms.

**Testing Philosophy:**
- **Test-driven development**: Write tests during/immediately after implementation
- **Platform coverage**: Test on iOS, macOS, and Mac Catalyst
- **Automation first**: Automate everything that can be automated
- **Manual validation**: Supplement with manual testing for UX and accessibility

---

### Test Data & Fixtures

**Mock Screenplay Documents:**
```swift
// Small document (10 elements)
let smallScreenplay = GuionParsedElementCollection(elements: [
    GuionElement(type: .action, content: "INT. OFFICE - DAY", ...),
    GuionElement(type: .dialogue, content: "Hello world", ...),
    // ... 8 more
])

// Large document (100 elements) for performance testing
let largeScreenplay = GuionParsedElementCollection(elements: generateElements(count: 100))

// Document with varied element types
let mixedTypeScreenplay = GuionParsedElementCollection(elements: [
    // Action, dialogue, character, transition, etc.
])
```

**Mock Popover Content:**
```swift
// Simple text popover
let textPopover = { element in
    Text("Element \(element.orderIndex)")
}

// Interactive popover with button
let interactivePopover = { element in
    VStack {
        Text(element.content.prefix(20))
        Button("Generate") {
            // Action
        }
    }
}

// Complex popover (max size)
let complexPopover = { element in
    VStack(spacing: 8) {
        Text("Long content that scrolls...")
        // Content exceeding 100pt height
        Button("Action 1") { }
        Button("Action 2") { }
    }
}
```

---

### Testing Environments

**Simulators:**
- **macOS**: Native Mac target (Apple Silicon)
- **iOS**: iPhone 17 Pro Simulator (iOS 26.0)
- **iPad**: iPad Pro 13" Simulator (iPadOS 26.0) - both touch and trackpad
- **Mac Catalyst**: macOS target with Catalyst variant

**Real Devices (if available):**
- iPhone (touch gestures)
- iPad with Magic Trackpad (hover + touch)
- Mac with trackpad (hover)

**Xcode Version:**
- Xcode 17.0+ (supports iOS 26.0)

---

### Test Coverage

**Unit Tests (Sources/SwiftCompartidoTests/PopoverTests/)**

File: `GuionElementPopoverProviderTests.swift`
- [ ] Popover provider initialization with various content types
- [ ] Type erasure works correctly (accepts different View types)
- [ ] Provider `callAsFunction` returns correct content
- [ ] Memory management (no retain cycles)

File: `GuionElementPopoverEnvironmentTests.swift`
- [ ] Environment value propagation to row views
- [ ] Environment value defaults to `nil` when not set
- [ ] Multiple nested views receive same environment value
- [ ] Environment value can be overridden in subviews

File: `HoverStateManagementTests.swift`
- [ ] Hover state transitions (off → on → off)
- [ ] Hover delay timing (300ms default)
- [ ] Custom hover delay timing (100ms, 500ms, 1000ms)
- [ ] Hover task cancellation when hover ends early
- [ ] Multiple rapid hovers (debouncing)
- [ ] Extended hover area (element + popover)
- [ ] Grace period timing (100ms transition)
- [ ] Only one popover visible at a time

File: `PopoverSizingTests.swift`
- [ ] Size constraints enforcement (400pt × 100pt max)
- [ ] Content scaling within constraints
- [ ] Content scrolling when exceeding height
- [ ] Width constraint on narrow screens
- [ ] Popover fits within safe area

File: `LongPressGestureTests.swift`
- [ ] Long-press gesture recognition (500ms duration)
- [ ] Long-press cancellation on finger movement (>10pt threshold)
- [ ] Long-press cancellation on lift before duration
- [ ] Haptic feedback trigger (verify mock called)
- [ ] Visual feedback state during press

---

**Integration Tests (Sources/SwiftCompartidoTests/Integration/)**

File: `GuionElementsListPopoverIntegrationTests.swift`
- [ ] Popover display in full GuionElementsList
- [ ] Popover content matches element data
- [ ] Only one popover visible at a time (switching elements)
- [ ] Popover positioning (above element by default)
- [ ] Popover positioning (below when insufficient space above)
- [ ] Interactive controls inside popover (button clicks)
- [ ] Popover remains visible while interacting
- [ ] Dismiss on hover end (leaves both element and popover)
- [ ] Dismiss on tap outside (touch devices)
- [ ] Dismiss on scroll gesture
- [ ] Content scrolling when exceeding 100pt height
- [ ] Multiple elements with different popover content
- [ ] Element without popover (returns `EmptyView`)

File: `PopoverAccessibilityIntegrationTests.swift`
- [ ] Keyboard navigation triggers popover on focus
- [ ] Tab key moves between elements, shows/hides popovers
- [ ] Popover content accessible to VoiceOver
- [ ] Accessible labels correct ("Additional information: ...")
- [ ] Interactive elements inside popover are focusable
- [ ] Reduced motion disables animations
- [ ] VoiceOver announces popover appearance/dismissal

---

**UI Tests (UITests/PopoverUITests.swift)**

These tests run on actual simulators and verify visual behavior:

```swift
@Test("Hover interaction on macOS")
@available(macOS 26.0, *)
func testHoverInteractionMacOS() async throws {
    // Test hover over element, verify popover appears
    // Test mouse move to popover, verify popover stays visible
    // Test mouse leave, verify popover dismisses
}

@Test("Long-press interaction on iOS")
@available(iOS 26.0, *)
func testLongPressInteractionIOS() async throws {
    // Test long-press on element, verify popover appears
    // Test tap on button inside popover
    // Test tap outside, verify dismiss
}

@Test("Visual feedback during long-press")
@available(iOS 26.0, *)
func testLongPressVisualFeedback() async throws {
    // Verify element highlights during long-press
    // Verify highlight disappears on release
}

@Test("Popover positioning adapts to screen space")
func testPopoverPositioning() async throws {
    // Test element near top of screen: popover below
    // Test element near bottom: popover above
    // Test element in middle: popover above (default)
}

@Test("Button interaction inside popover")
func testPopoverButtonInteraction() async throws {
    // Hover/long-press to show popover
    // Click button inside popover
    // Verify button action executed
    // Verify popover stays visible during interaction
}
```

Manual UI Testing Checklist:
- [ ] Hover over element on Mac trackpad → popover appears smoothly
- [ ] Move mouse from element into popover → popover stays visible
- [ ] Click button inside popover → button action fires
- [ ] Move mouse away → popover dismisses smoothly
- [ ] Long-press element on iPhone → haptic feedback + popover
- [ ] Tap button in popover on iPhone → action fires
- [ ] Tap outside popover on iPhone → popover dismisses
- [ ] Scroll list with popover visible → popover dismisses
- [ ] Rapidly hover over multiple elements → only one popover visible

---

**Performance Tests (Sources/SwiftCompartidoTests/Performance/)**

File: `PopoverPerformanceTests.swift`

```swift
@Test("Popover display latency under 50ms")
func testPopoverDisplayLatency() async throws {
    let start = Date()
    // Trigger hover, wait for delay to expire
    try await Task.sleep(for: .milliseconds(300))
    // Measure time from delay expiration to popover render
    let latency = Date().timeIntervalSince(start) - 0.3
    #expect(latency < 0.05) // < 50ms
}

@Test("No frame drops with 100 elements and rapid hovers")
func testScrollPerformanceWithPopovers() async throws {
    let largeList = GuionElementsList(document: largeScreenplay)
        .guionElementPopover { element in
            complexPopover(element)
        }

    // Simulate scroll + rapid hovers
    // Measure frame rate
    let frameRate = measureFrameRate(during: scrollAndHover)
    #expect(frameRate >= 60) // No drops from 60fps
}

@Test("Memory footprint with active popovers")
func testMemoryFootprint() async throws {
    let initialMemory = getCurrentMemoryUsage()

    // Create 100 popover states
    for element in largeScreenplay.elements {
        showPopover(for: element)
        try await Task.sleep(for: .milliseconds(10))
        dismissPopover(for: element)
    }

    let finalMemory = getCurrentMemoryUsage()
    let increase = finalMemory - initialMemory
    #expect(increase < 1_000_000) // < 1MB
}

@Test("Long-press gesture detection latency")
@available(iOS 26.0, *)
func testLongPressLatency() async throws {
    // Simulate touch down
    let start = Date()
    // Wait for gesture recognition
    try await Task.sleep(for: .milliseconds(500))
    // Measure time from gesture complete to popover render
    let latency = Date().timeIntervalSince(start) - 0.5
    #expect(latency < 0.05) // < 50ms
}
```

Performance Testing Procedure:
1. Run performance tests on all platforms (iOS, macOS, Catalyst)
2. Profile with Instruments (Time Profiler, Allocations)
3. Verify no memory leaks (Leaks instrument)
4. Check energy impact (iOS Energy Log)
5. Validate against benchmarks:
   - Popover display latency: < 50ms ✓
   - No frame drops at 60fps ✓
   - Memory footprint: < 1MB for 100 states ✓

---

**Accessibility Tests**

File: `PopoverAccessibilityTests.swift`

Automated Tests:
- [ ] VoiceOver labels present and descriptive
- [ ] Interactive elements have accessibility traits
- [ ] Popover content combines into single element
- [ ] Keyboard focus triggers popover display
- [ ] Reduced motion setting disables animations
- [ ] Dynamic type support (text scales correctly)
- [ ] Contrast ratios meet WCAG 2.1 standards

Manual Accessibility Testing:
1. **VoiceOver (macOS/iOS)**
   - Enable VoiceOver
   - Navigate to GuionElementsList with VO cursor
   - Verify element content is read aloud
   - Trigger popover via keyboard focus
   - Verify popover content is read aloud
   - Verify "Additional information" context is provided
   - Navigate to button inside popover
   - Verify button label and action are clear

2. **Keyboard-Only Navigation (macOS)**
   - Disable trackpad/mouse
   - Tab through GuionElementsList
   - Verify popovers appear on focus
   - Verify 300ms delay still applies
   - Tab into popover, interact with button
   - Verify popover dismisses when focus leaves

3. **Reduced Motion**
   - Enable "Reduce Motion" in System Settings
   - Trigger popover via hover
   - Verify no fade-in animation (instant appearance)
   - Verify popover still respects 300ms delay
   - Verify functionality otherwise identical

4. **Increased Contrast**
   - Enable "Increase Contrast" in System Settings
   - Verify popover background material remains visible
   - Verify text contrast ratio ≥ 4.5:1

5. **Dynamic Type**
   - Set text size to maximum
   - Verify popover content scales
   - Verify 100pt height constraint accommodates larger text
   - Verify content scrolls if needed

---

### Platform-Specific Testing

**macOS Testing (primary hover platform)**
- [ ] Hover with trackpad → popover appears
- [ ] Hover with external mouse → popover appears
- [ ] Keyboard navigation → popover appears on focus
- [ ] Window resize → popover repositions correctly
- [ ] Multiple windows → popovers work independently
- [ ] Dark mode → popover material renders correctly
- [ ] Light mode → popover material renders correctly

**iOS Testing (primary touch platform)**
- [ ] Long-press on iPhone → haptic + popover
- [ ] Long-press on iPad → haptic + popover
- [ ] Tap outside → popover dismisses
- [ ] Scroll gesture → popover dismisses
- [ ] Rotation → popover repositions correctly
- [ ] Split-screen mode → popover respects safe area
- [ ] Dark mode → popover material renders correctly
- [ ] Landscape + portrait → both orientations work

**iPad with Trackpad/Mouse Testing (hybrid)**
- [ ] Hover with Magic Trackpad → popover appears
- [ ] Switch to touch → long-press works
- [ ] Both methods work in same session
- [ ] No conflicts between hover and touch gestures

**Mac Catalyst Testing**
- [ ] Hover with trackpad → popover appears
- [ ] Touch Bar support (if applicable)
- [ ] Window management → popovers work correctly
- [ ] Keyboard shortcuts don't conflict

---

### Test Execution Schedule

**During Development (Phases 1-6):**
- Run relevant unit tests after each task
- Run full test suite before phase completion
- Manual testing for new functionality

**Before Each PR:**
- Run all unit tests (must pass 100%)
- Run integration tests (must pass 100%)
- Run performance tests (must meet benchmarks)
- Manual smoke test on macOS and iOS

**Weekly (Development Period):**
- Full UI test suite on all platforms
- Accessibility testing (VoiceOver, keyboard)
- Performance profiling with Instruments

**Before Release (Final Week):**
- Complete test suite (all 437+ existing + new tests)
- Manual testing on real devices (if available)
- Beta testing with sample app (1 week)
- Full accessibility audit
- Final performance validation

---

### Continuous Integration

**GitHub Actions Workflow (Short Tests):**
```yaml
- name: Run Popover Unit Tests
  run: ./build.sh --action test --filter PopoverTests

- name: Run Popover Integration Tests
  run: ./build.sh --action test --filter PopoverIntegration
```

**Platforms to Test in CI:**
- iOS Simulator (iPhone 17 Pro)
- macOS (native)
- Mac Catalyst (if build succeeds)

**Test Reporting:**
- Codecov integration for coverage tracking
- Fail PR if coverage drops below 90%
- Fail PR if any test fails

---

### Bug Tracking & Triage

**During Development:**
- Use GitHub Issues for bugs found during testing
- Label: `bug`, `popover-feature`
- Priority: P0 (blocks release), P1 (must fix), P2 (nice to have)

**Triage Criteria:**
- **P0 - Critical**: Crashes, data loss, core functionality broken
- **P1 - High**: Accessibility issues, performance regressions, UX problems
- **P2 - Medium**: Edge cases, polish items, minor visual issues
- **P3 - Low**: Enhancement ideas, future improvements

**Bug Fix Process:**
1. Reproduce bug reliably
2. Write failing test case
3. Fix bug
4. Verify test passes
5. Verify no regressions
6. Code review + merge

---

### Test Success Criteria

**Phase Completion:**
- [ ] All unit tests for phase pass (100%)
- [ ] No regressions in existing tests (437 tests)
- [ ] Coverage ≥ 90% for new code in phase
- [ ] Manual testing confirms expected behavior

**Feature Completion:**
- [ ] All 437+ existing tests pass (100%)
- [ ] All new tests pass (50+ new tests)
- [ ] Overall coverage ≥ 95% (matches current)
- [ ] Performance benchmarks met (all platforms)
- [ ] Accessibility audit complete (no violations)
- [ ] Manual testing complete (all platforms)
- [ ] Beta testing complete (no critical bugs)
- [ ] Code review approved (2+ reviewers)

---

## Testing Requirements

### Test Coverage

**Unit Tests:**
- [ ] Popover provider initialization with various content types
- [ ] Environment value propagation to row views
- [ ] Hover state management (show/hide logic)
- [ ] Hover delay timing (300ms default, custom values)
- [ ] Multiple rapid hovers (debouncing)
- [ ] Extended hover area (element + popover)
- [ ] Grace period timing (100ms transition)
- [ ] Size constraints enforcement (400pt × 100pt max)
- [ ] Long-press gesture recognition (500ms duration)
- [ ] Long-press cancellation on finger movement (>10pt)

**Integration Tests:**
- [ ] Popover display in full GuionElementsList
- [ ] Popover content matches element data
- [ ] Only one popover visible at a time
- [ ] Popover positioning (above/below element)
- [ ] Interactive controls inside popover (button clicks)
- [ ] Popover remains visible while interacting
- [ ] Dismiss on tap outside (touch devices)
- [ ] Dismiss on scroll gesture
- [ ] Content scrolling when exceeding 100pt height

**UI Tests:**
- [ ] Hover interaction on macOS simulator
- [ ] Long-press interaction on iOS simulator
- [ ] Haptic feedback on long-press completion
- [ ] Visual feedback during long-press
- [ ] Keyboard focus triggers popover
- [ ] VoiceOver reads popover content
- [ ] Reduced motion disables animations
- [ ] Button interaction inside popover works correctly

**Performance Tests:**
- [ ] 100 elements with popovers: no lag during scroll
- [ ] Memory footprint with active popovers
- [ ] Popover display latency < 50ms
- [ ] Long-press gesture detection latency
- [ ] Interactive popover performance (button responsiveness)

## Design Decisions

All open questions have been resolved. Here are the finalized design decisions:

### 1. Popover Dismissal
**Decision**: Auto-dismiss only when mouse/finger leaves the element area
- Popovers are NOT manually dismissible via close button or escape key
- On hover devices: Dismiss when mouse leaves both element AND popover
- On touch devices: Dismiss when tapping outside element/popover or scrolling list
- **Rationale**: Keeps interaction model simple and predictable

### 2. Popover Interaction Support
**Decision**: Popovers MUST support interaction (buttons, controls, etc.)
- Primary use case: GENERATE button for audio generation
- Popover remains visible while user interacts with controls
- Extended hover area includes both element and popover
- 100ms grace period when transitioning from element to popover
- **Rationale**: Enables core functionality without requiring separate UI for generation controls

### 3. Popover Size Constraints
**Decision**: Enforce maximum dimensions with scrolling if needed
- **Maximum width**: 400pt
- **Maximum height**: 100pt
- Content scrolls if it exceeds height limit
- **Rationale**: Ensures consistent, compact UI; prevents unwieldy popovers that obscure too much content

### 4. Touch Device Support
**Decision**: Full support via long-press gesture
- **Long-press duration**: 500ms
- Haptic feedback on popover appearance
- Tap outside to dismiss
- Visual feedback during long-press (highlight + optional progress indicator)
- **Rationale**: Makes GENERATE functionality accessible on all platforms (iPhone, iPad, Mac)

## Success Criteria

- [ ] API is SwiftUI-idiomatic and easy to use
- [ ] No performance degradation in GuionElementsList
- [ ] 90%+ test coverage for new code
- [ ] Documentation includes usage examples
- [ ] Works consistently across iOS, macOS, Mac Catalyst
- [ ] Accessibility features fully implemented
- [ ] Zero breaking changes to existing API

## Future Enhancements (Out of Scope)

- **Popover pinning**: Click/tap to pin popover and keep it visible even when moving away
- **Popover transitions**: Custom animations for show/hide beyond basic fade
- **Popover templates**: Pre-built popover layouts for common use cases (metadata view, audio controls, etc.)
- **Popover caching**: Cache rendered popovers for frequently hovered elements to improve performance
- **3D Touch support**: Use force touch on supported devices for alternative trigger method
- **Popover arrows**: Add visual arrow pointing from popover to element (iOS-style callout)
