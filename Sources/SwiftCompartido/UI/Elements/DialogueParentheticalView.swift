//
//  DialogueParentheticalView.swift
//  SwiftCompartido
//
//  Parenthetical view with proper screenplay formatting
//

import SwiftUI

/// Parenthetical view with proper screenplay formatting (32% left margin, 30% right margin)
public struct DialogueParentheticalView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: GuionElementModel) {
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
