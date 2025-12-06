//
//  DialogueParentheticalView.swift
//  SwiftCompartido
//
//  Parenthetical view with proper screenplay formatting
//

import SwiftUI

/// Parenthetical view with proper screenplay formatting (32% left margin, 30% right margin)
///
/// This view works with any type conforming to `DisplayableElement`,
/// allowing it to be used with both `GuionElementModel` and `ElementReference`.
@available(iOS 26.0, macOS 26.0, *)
public struct DialogueParentheticalView<Element: DisplayableElement>: View {
    let element: Element
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: Element) {
        self.element = element
    }

    public var body: some View {
        // Calculate fixed character widths instead of using GeometryReader
        // This eliminates layout calculations during scroll
        let characterWidth = fontSize * ScreenplayPageFormat.courierCharacterAspectRatio
        let leftMarginWidth = characterWidth * (ScreenplayPageFormat.charactersPerLine * 0.32)  // 32% of 65 characters
        let contentMaxWidth = characterWidth * (ScreenplayPageFormat.charactersPerLine * 0.38)  // 38% of 65 characters

        HStack(alignment: .top, spacing: 0) {
            // 32% left margin for parentheticals (20.8 characters)
            Spacer()
                .frame(width: leftMarginWidth)

            Text(element.elementText)
                .font(.custom("Courier New", size: fontSize * 0.65))
                .italic()
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: contentMaxWidth, alignment: .leading)

            Spacer()
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
