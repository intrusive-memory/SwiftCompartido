//
//  SceneHeadingView.swift
//  SwiftCompartido
//
//  Scene heading view (slugline) with proper screenplay formatting
//

import SwiftUI

/// Scene heading view (slugline) with proper screenplay formatting
/// Scene headings are full-width, bold, uppercase
///
/// This view works with any type conforming to `DisplayableElement`,
/// allowing it to be used with both `GuionElementModel` and `ElementReference`.
@available(iOS 26.0, macOS 26.0, *)
public struct SceneHeadingView<Element: DisplayableElement>: View {
    let element: Element
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: Element) {
        self.element = element
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            Text(element.elementText)
                .font(.custom("Courier New", size: fontSize * 1.5).weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
