//
//  SynopsisView.swift
//  SwiftCompartido
//
//  Synopsis/outline summary view
//

import SwiftUI

/// Synopsis/outline summary view
///
/// This view works with any type conforming to `DisplayableElement`,
/// allowing it to be used with both `GuionElementModel` and `ElementReference`.
/// Brief description of a scene or section
///
/// This view works with any type conforming to `DisplayableElement`,
/// allowing it to be used with both `GuionElementModel` and `ElementReference`.
@available(iOS 26.0, macOS 26.0, *)
public struct SynopsisView<Element: DisplayableElement>: View {
  let element: Element
  @Environment(\.screenplayFontSize) var fontSize

  public init(element: Element) {
    self.element = element
  }

  public var body: some View {
    Text(element.elementText)
      .font(.custom("Courier New", size: fontSize * 0.9).italic())
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
