//
//  DialogueTextView.swift
//  SwiftCompartido
//
//  Dialogue text view with proper screenplay formatting
//

import SwiftUI

/// Dialogue text view with proper screenplay formatting (25% left margin, 25% right margin)
///
/// This view works with any type conforming to `DisplayableElement`,
/// allowing it to be used with both `GuionElementModel` and `ElementReference`.
@available(iOS 26.0, macOS 26.0, *)
public struct DialogueTextView<Element: DisplayableElement>: View {
  let element: Element
  @Environment(\.screenplayFontSize) var fontSize

  public init(element: Element) {
    self.element = element
  }

  public var body: some View {
    HStack {
      Spacer()
        .frame(minWidth: 100)  // 25% left margin

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

      Spacer()
        .frame(minWidth: 100)  // 25% right margin
    }
  }
}
