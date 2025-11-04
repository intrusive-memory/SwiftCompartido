//
//  PopoverDismissEnvironment.swift
//  SwiftCompartido
//
//  Environment for dismissing popovers on scroll
//

import SwiftUI

/// Observable object to coordinate popover dismissal across multiple rows
@MainActor
public class PopoverDismissCoordinator: ObservableObject {
    @Published public var shouldDismiss: Bool = false

    public init() {}

    public func triggerDismiss() {
        shouldDismiss = true
        // Reset after a short delay to allow for future dismissals
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            shouldDismiss = false
        }
    }
}

/// Environment key for popover dismiss coordinator
struct PopoverDismissCoordinatorKey: EnvironmentKey {
    static let defaultValue: PopoverDismissCoordinator? = nil
}

extension EnvironmentValues {
    var popoverDismissCoordinator: PopoverDismissCoordinator? {
        get { self[PopoverDismissCoordinatorKey.self] }
        set { self[PopoverDismissCoordinatorKey.self] = newValue }
    }
}
