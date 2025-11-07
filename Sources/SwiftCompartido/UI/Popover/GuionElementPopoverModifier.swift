//
//  GuionElementPopoverModifier.swift
//  SwiftCompartido
//
//  View modifier for adding popover support to GuionElementsList
//

import SwiftUI

/// View modifier that adds popover support to GuionElementsList
///
/// This modifier injects a GuionElementPopoverProvider into the environment,
/// enabling popover display on list rows when hovering or long-pressing elements.
struct GuionElementPopoverModifier<PopoverContent: View>: ViewModifier {
    let hoverDelay: TimeInterval
    let content: @Sendable @MainActor (GuionElementModel) -> PopoverContent

    func body(content: Content) -> some View {
        content
            .environment(
                \.guionElementPopover,
                GuionElementPopoverProvider(content: self.content)
            )
    }
}

extension View {
    /// Adds interactive popover support to GuionElementsList
    ///
    /// Popovers appear when hovering over elements (macOS/trackpad) or tapping
    /// the right edge (iOS touch). Popovers support interactive content like buttons and controls.
    ///
    /// - Parameters:
    ///   - hoverDelay: Time in seconds before popover appears after hover starts (default: 0.3)
    ///   - content: A ViewBuilder closure that generates popover content for each element
    ///
    /// - Returns: A view with popover support enabled
    ///
    /// ## Size Constraints
    ///
    /// Popovers automatically size to fit their content with padding.
    ///
    /// ## Platform Support
    ///
    /// - **macOS**: Hover over the 120pt tap target on the right edge (300ms delay)
    /// - **iOS with trackpad**: Hover support on the tap target
    /// - **iOS touch**: Tap the 120pt tap target on the right edge to toggle popover (with haptic feedback)
    ///
    /// ## Example
    ///
    /// ```swift
    /// GuionElementsList(document: screenplay)
    ///     .guionElementPopover { element in
    ///         VStack {
    ///             Text(element.content.prefix(50))
    ///             Button("Generate Audio") {
    ///                 // Generate audio for element
    ///             }
    ///         }
    ///     }
    /// ```
    ///
    /// ## Interaction Behavior
    ///
    /// - Popovers support interaction (buttons, controls work normally)
    /// - Popover stays visible while mouse is over element OR popover
    /// - 100ms grace period when transitioning from element to popover
    /// - Only one popover visible at a time
    /// - Auto-dismisses when mouse/touch leaves both element and popover
    ///
    /// ## Accessibility
    ///
    /// - Keyboard focus triggers popovers
    /// - VoiceOver reads popover content
    /// - Reduced motion setting respected
    public func guionElementPopover<Content: View>(
        hoverDelay: TimeInterval = 0.3,
        @ViewBuilder content: @escaping @Sendable @MainActor (GuionElementModel) -> Content
    ) -> some View {
        modifier(GuionElementPopoverModifier(hoverDelay: hoverDelay, content: content))
    }
}
