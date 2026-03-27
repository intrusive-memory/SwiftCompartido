//
//  ActionView.swift
//  SwiftCompartido
//
//  Action line view with proper screenplay formatting
//

import SwiftUI

/// Action line view with proper screenplay formatting (10% left margin, 10% right margin)
///
/// This view works with any type conforming to `DisplayableElement`,
/// allowing it to be used with both `GuionElementModel` and `ElementReference`.
@available(iOS 26.0, macOS 26.0, *)
public struct ActionView<Element: DisplayableElement>: View {
  let element: Element
  @Environment(\.screenplayFontSize) var fontSize

  public init(element: Element) {
    self.element = element
  }

  public var body: some View {
    // Use pre-computed formatted text if available (NEW in 5.4.0)
    // Falls back to runtime formatting for backward compatibility
    Text(
      element.formattedText
        ?? FountainTextFormatter.format(
          element.elementText,
          baseFont: .custom("Courier New", size: fontSize)
        )
    )
    .font(.custom("Courier New", size: fontSize))
    .foregroundStyle(.primary)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
