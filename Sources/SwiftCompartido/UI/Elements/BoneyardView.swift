//
//  BoneyardView.swift
//  SwiftCompartido
//
//  Boneyard view for omitted/commented-out content
//

import SwiftUI

/// Boneyard view for omitted/commented-out content
///
/// This view works with any type conforming to `DisplayableElement`,
/// allowing it to be used with both `GuionElementModel` and `ElementReference`.
/// Content that has been commented out using /* ... */ block syntax
///
/// This view works with any type conforming to `DisplayableElement`,
/// allowing it to be used with both `GuionElementModel` and `ElementReference`.
@available(iOS 26.0, macOS 26.0, *)
public struct BoneyardView<Element: DisplayableElement>: View {
  let element: Element
  @Environment(\.screenplayFontSize) var fontSize

  public init(element: Element) {
    self.element = element
  }

  public var body: some View {
    Text(element.elementText)
      .font(.custom("Courier New", size: fontSize * 0.83))
      .foregroundStyle(.secondary.opacity(0.5))
      .strikethrough(true, color: .secondary.opacity(0.5))
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
