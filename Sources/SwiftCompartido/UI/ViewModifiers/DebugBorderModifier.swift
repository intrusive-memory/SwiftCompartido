//
//  DebugBorderModifier.swift
//  SwiftCompartido
//
//  Debug border modifier for GuionElement views
//

import SwiftUI

/// View modifier that adds a 1px border in DEBUG builds only
struct DebugBorderModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if DEBUG
        content
            .border(Color.red, width: 1)
        #else
        content
        #endif
    }
}

extension View {
    /// Adds a 1px red border to the view in DEBUG builds only
    ///
    /// This is useful for visualizing element boundaries during development.
    /// In release builds, this modifier has no effect.
    ///
    /// ## Example
    ///
    /// ```swift
    /// Text("Hello World")
    ///     .debugBorder()
    /// ```
    public func debugBorder() -> some View {
        modifier(DebugBorderModifier())
    }
}
