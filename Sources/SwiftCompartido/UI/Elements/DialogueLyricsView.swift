//
//  DialogueLyricsView.swift
//  SwiftCompartido
//
//  Lyrics view with proper screenplay formatting
//

import SwiftUI

/// Lyrics view with proper screenplay formatting (25% left margin, 25% right margin, italic)
public struct DialogueLyricsView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        // Calculate fixed character widths instead of using GeometryReader
        // This eliminates layout calculations during scroll
        let characterWidth = fontSize * ScreenplayPageFormat.courierCharacterAspectRatio
        let leftMarginWidth = characterWidth * 16.25  // 25% of 65 characters = 16.25 characters
        let contentMaxWidth = characterWidth * 32.5   // 50% of 65 characters = 32.5 characters

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
