//
//  PopoverDismissEnvironment.swift
//  SwiftCompartido
//
//  Coordinator for dismissing popovers on scroll
//
//  This coordinator is injected via .environmentObject() rather than .environment()
//  to ensure that views subscribing to the @Published shouldDismiss property
//  receive updates when the property changes. Using @EnvironmentObject properly
//  subscribes the view to the ObservableObject, allowing .onChange() to fire.
//

import SwiftUI

/// Observable object to coordinate popover dismissal across multiple rows
///
/// This coordinator is injected into the view hierarchy via `.environmentObject()`
/// and consumed via `@EnvironmentObject` to ensure proper observation of the
/// `@Published shouldDismiss` property.
@MainActor
public class PopoverDismissCoordinator: ObservableObject {
    @Published public var shouldDismiss: Bool = false

    public init() {}

    /// Triggers dismissal of all popovers
    ///
    /// Sets `shouldDismiss` to `true`, then automatically resets it after 50ms
    /// to allow for future dismissal events. Views observing this coordinator
    /// via `@EnvironmentObject` will receive the change and can respond via
    /// `.onChange(of: coordinator.shouldDismiss)`.
    public func triggerDismiss() {
        shouldDismiss = true
        // Reset after a short delay to allow for future dismissals
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            self?.shouldDismiss = false
        }
    }
}
