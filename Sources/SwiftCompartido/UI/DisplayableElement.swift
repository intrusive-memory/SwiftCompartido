//
//  DisplayableElement.swift
//  SwiftCompartido
//
//  Protocol for types that can be displayed in screenplay element views.
//  Allows sharing view code between GuionElementModel and ElementReference.
//

import Foundation
@preconcurrency import SwiftData

/// Protocol for types that can be displayed as screenplay elements
///
/// This protocol enables code reuse between `GuionElementModel` (SwiftData model)
/// and `ElementReference` (Transferable DTO from App Intents).
///
/// By conforming to this protocol, both types can use the same set of views
/// (SceneHeadingView, ActionView, etc.) without code duplication.
///
/// Note: We don't inherit from Identifiable here because both GuionElementModel
/// and ElementReference already conform to it with their own `id` properties.
@available(iOS 26.0, macOS 26.0, *)
public protocol DisplayableElement {
  /// The type of screenplay element (scene heading, dialogue, action, etc.)
  var elementType: ElementType { get }

  /// The text content of the element
  var elementText: String { get }

  /// The chapter index (0-based)
  var chapterIndex: Int { get }

  /// The order index within the chapter (0-based)
  var orderIndex: Int { get }

  /// Pre-formatted AttributedString with Fountain formatting (bold, italic, underline)
  /// If nil, views will format at runtime using FountainTextFormatter
  var formattedText: AttributedString? { get }
}

// MARK: - GuionElementModel Conformance

@available(iOS 26.0, macOS 26.0, *)
extension GuionElementModel: DisplayableElement {
  // GuionElementModel already has all required properties
  // No additional implementation needed
}

// MARK: - ElementReference Conformance

@available(iOS 26.0, macOS 26.0, *)
extension ElementReference: DisplayableElement {
  // ElementReference already has 'id' property (PersistentIdentifier)
  // No need to redefine it here

  /// ElementReference doesn't support pre-formatted text
  /// Views will format at runtime
  public var formattedText: AttributedString? {
    return nil
  }
}
