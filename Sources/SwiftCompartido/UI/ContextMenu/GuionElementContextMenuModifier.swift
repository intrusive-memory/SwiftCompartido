//
//  GuionElementContextMenuModifier.swift
//  SwiftCompartido
//
//  Context menu system for screenplay elements
//

import SwiftUI

/// View modifier that adds context menus to screenplay elements
///
/// Provides an extensible context menu system for `GuionElementsList` that works with both
/// mouse (right-click) and touch (long-press) interfaces.
///
/// ## Platform Support
/// - **macOS**: Right-click to show context menu
/// - **iOS**: Long-press to show context menu
///
/// ## Usage
/// ```swift
/// GuionElementsList(document: screenplay)
///     .guionElementContextMenu { element in
///         Button("Generate Audio") {
///             generateAudio(for: element)
///         }
///         Button("Copy Text") {
///             copyText(element.elementText)
///         }
///     }
/// ```
public struct GuionElementContextMenuModifier<MenuContent: View>: ViewModifier {
    let menuBuilder: @Sendable @MainActor (GuionElementModel) -> MenuContent

    public func body(content: Content) -> some View {
        content
            .environment(\.guionElementContextMenu, GuionElementContextMenuProvider(menuBuilder: menuBuilder))
    }
}

// MARK: - View Extension

extension View {
    /// Add context menu to screenplay elements in GuionElementsList
    ///
    /// Context menus appear on:
    /// - **macOS**: Right-click
    /// - **iOS**: Long-press
    ///
    /// ## Example
    /// ```swift
    /// GuionElementsList(document: screenplay)
    ///     .guionElementContextMenu { element in
    ///         if element.isSpeakable {
    ///             Button("Generate Audio", systemImage: "waveform") {
    ///                 generateAudio(for: element)
    ///             }
    ///         }
    ///     }
    /// ```
    ///
    /// - Parameter content: Closure that builds menu items for an element
    /// - Returns: View with context menu support
    public func guionElementContextMenu<Content: View>(
        @ViewBuilder content: @escaping @Sendable @MainActor (GuionElementModel) -> Content
    ) -> some View {
        modifier(GuionElementContextMenuModifier(menuBuilder: content))
    }
}

// MARK: - Environment Support

/// Provider for context menu content
public struct GuionElementContextMenuProvider: Sendable {
    let menuBuilder: @Sendable @MainActor (GuionElementModel) -> AnyView

    public init<Content: View>(menuBuilder: @escaping @Sendable @MainActor (GuionElementModel) -> Content) {
        self.menuBuilder = { element in
            AnyView(menuBuilder(element))
        }
    }
}

/// Environment key for context menu provider
private struct GuionElementContextMenuKey: EnvironmentKey {
    static let defaultValue: GuionElementContextMenuProvider? = nil
}

extension EnvironmentValues {
    /// Context menu provider for screenplay elements
    public var guionElementContextMenu: GuionElementContextMenuProvider? {
        get { self[GuionElementContextMenuKey.self] }
        set { self[GuionElementContextMenuKey.self] = newValue }
    }
}
