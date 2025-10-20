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
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // 25% left margin for lyrics
                Spacer()
                    .frame(width: geometry.size.width * 0.25)

                Text(element.elementText)
                    .font(.custom("Courier New", size: fontSize))
                    .italic()
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: geometry.size.width * 0.50, // 100% - 25% - 25% = 50%
                        alignment: .leading
                    )

                // 25% right margin
                Spacer()
                    .frame(width: geometry.size.width * 0.25)
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
