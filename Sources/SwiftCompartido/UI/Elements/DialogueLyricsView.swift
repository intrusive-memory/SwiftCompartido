//
//  DialogueLyricsView.swift
//  SwiftCompartido
//
//  Lyrics view with proper screenplay formatting
//

import SwiftUI

/// Lyrics view with proper screenplay formatting (25% left margin, 25% right margin, italic)
///
/// This view works with any type conforming to `DisplayableElement`,
/// allowing it to be used with both `GuionElementModel` and `ElementReference`.
@available(iOS 26.0, macOS 26.0, *)
public struct DialogueLyricsView<Element: DisplayableElement>: View {
    let element: Element
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: Element) {
        self.element = element
    }

    public var body: some View {
        // Calculate fixed character widths instead of using GeometryReader
        // This eliminates layout calculations during scroll
        let characterWidth = fontSize * ScreenplayPageFormat.courierCharacterAspectRatio
        let leftMarginWidth = characterWidth * (ScreenplayPageFormat.charactersPerLine * 0.25)  // 25% of 65 characters
        let contentMaxWidth = characterWidth * (ScreenplayPageFormat.charactersPerLine * 0.50)   // 50% of 65 characters

        HStack(alignment: .top, spacing: 0) {
            // 25% left margin for lyrics (16.25 characters)
            Spacer()
                .frame(width: leftMarginWidth)

            Text(element.elementText)
                .font(.custom("Courier New", size: fontSize))
                .italic()
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: contentMaxWidth, alignment: .leading)

            Spacer()
        }
        .fixedSize(horizontal: false, vertical: false)
    }
}
