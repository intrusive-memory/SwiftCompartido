//
//  GuionElementPopoverEnvironment.swift
//  SwiftCompartido
//
//  Environment key for GuionElementPopover support
//

import SwiftUI

/// Environment key for GuionElementPopover provider
///
/// This key allows popover providers to be passed through the SwiftUI environment
/// to child views, enabling popover functionality throughout the view hierarchy.
struct GuionElementPopoverKey: EnvironmentKey {
  static let defaultValue: GuionElementPopoverProvider? = nil
}

extension EnvironmentValues {
  /// The current GuionElementPopover provider
  ///
  /// Set this value to enable popovers on GuionElementsList rows.
  /// When `nil` (the default), no popovers are displayed.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// // Set via view modifier (recommended)
  /// GuionElementsList(document: screenplay)
  ///     .guionElementPopover { element in
  ///         Text("Popover for \(element.content)")
  ///     }
  ///
  /// // Or access directly in custom views
  /// @Environment(\.guionElementPopover) var popoverProvider
  /// ```
  var guionElementPopover: GuionElementPopoverProvider? {
    get { self[GuionElementPopoverKey.self] }
    set { self[GuionElementPopoverKey.self] = newValue }
  }
}
