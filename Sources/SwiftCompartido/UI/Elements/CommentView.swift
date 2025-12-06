//
//  CommentView.swift
//  SwiftCompartido
//
//  Comment view for inline screenplay notes
//

import SwiftUI

/// Comment view for inline screenplay notes
///
/// This view works with any type conforming to `DisplayableElement`,
/// allowing it to be used with both `GuionElementModel` and `ElementReference`.
/// Notes that appear in source but not in formatted output
///
/// This view works with any type conforming to `DisplayableElement`,
/// allowing it to be used with both `GuionElementModel` and `ElementReference`.
@available(iOS 26.0, macOS 26.0, *)
public struct CommentView<Element: DisplayableElement>: View {
    let element: Element
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: Element) {
        self.element = element
    }

    public var body: some View {
        Text("[[\(element.elementText)]]")
            .font(.custom("Courier New", size: fontSize * 0.83))
            .foregroundStyle(.secondary.opacity(0.6))
            .italic()
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
