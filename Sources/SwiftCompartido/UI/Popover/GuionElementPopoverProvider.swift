//
//  GuionElementPopoverProvider.swift
//  SwiftCompartido
//
//  Type-erased wrapper for providing popover content for GuionElements
//

import SwiftUI

/// Type-erased provider for popover content
///
/// This provider wraps a closure that generates SwiftUI views for element popovers.
/// It uses type erasure to allow any View type to be provided while maintaining
/// type safety through the environment system.
///
/// ## Usage
///
/// ```swift
/// GuionElementsList(document: screenplay)
///     .guionElementPopover { element in
///         VStack {
///             Text(element.content)
///             Button("Generate") { }
///         }
///     }
/// ```
@MainActor
public struct GuionElementPopoverProvider: Sendable {
    private let _content: @Sendable @MainActor (GuionElementModel) -> AnyView

    /// Creates a popover provider with the given content closure
    ///
    /// - Parameter content: A closure that takes a GuionElementModel and returns a View
    public init<Content: View>(
        @ViewBuilder content: @escaping @Sendable @MainActor (GuionElementModel) -> Content
    ) {
        self._content = { element in
            AnyView(content(element))
        }
    }

    /// Returns the popover content for the given element
    ///
    /// - Parameter element: The element to generate popover content for
    /// - Returns: The type-erased view content
    public func callAsFunction(_ element: GuionElementModel) -> AnyView {
        _content(element)
    }
}
