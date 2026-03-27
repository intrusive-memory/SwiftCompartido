//
//  PopoverDismissEnvironment.swift
//  SwiftCompartido
//
//  Environment key for popover dismissal callbacks
//
//  Phase 4C Optimization: Replaced @EnvironmentObject with lightweight closure-based approach
//  to reduce view invalidations when dismissal is triggered.
//

import SwiftUI

/// Environment key for popover dismissal callback
///
/// This key provides a lightweight closure-based approach to popover dismissal,
/// avoiding the overhead of @EnvironmentObject/@Published which invalidates
/// all observing views when the state changes.
///
/// Usage in list view:
/// ```swift
/// @State private var dismissID = UUID()
///
/// GuionElementsList()
///     .environment(\.popoverDismissAction, { dismissID = UUID() })
///     .environment(\.popoverDismissID, dismissID)
/// ```
///
/// Usage in row view:
/// ```swift
/// @Environment(\.popoverDismissAction) var dismissAction
/// @Environment(\.popoverDismissID) var dismissID
///
/// .onChange(of: dismissID) { _, _ in
///     // Dismiss popover
/// }
/// ```
private struct PopoverDismissActionKey: EnvironmentKey {
  nonisolated(unsafe) static let defaultValue: (() -> Void)? = nil
}

private struct PopoverDismissIDKey: EnvironmentKey {
  static let defaultValue = UUID()
}

extension EnvironmentValues {
  /// Closure to trigger popover dismissal
  public var popoverDismissAction: (() -> Void)? {
    get { self[PopoverDismissActionKey.self] }
    set { self[PopoverDismissActionKey.self] = newValue }
  }

  /// ID that changes when popovers should dismiss
  public var popoverDismissID: UUID {
    get { self[PopoverDismissIDKey.self] }
    set { self[PopoverDismissIDKey.self] = newValue }
  }
}

/// Legacy coordinator for backward compatibility
///
/// This class is deprecated in favor of the environment key approach.
/// Existing code can continue using it, but new code should use the environment keys.
@available(
  *, deprecated, message: "Use environment keys popoverDismissAction and popoverDismissID instead"
)
@MainActor
public class PopoverDismissCoordinator: ObservableObject {
  @Published public var shouldDismiss: Bool = false

  public init() {}

  public func triggerDismiss() {
    shouldDismiss = true
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(50))
      self?.shouldDismiss = false
    }
  }
}
