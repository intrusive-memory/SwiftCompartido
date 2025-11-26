//
//  TransitionView.swift
//  SwiftCompartido
//
//  Transition view with proper screenplay formatting
//

import SwiftUI

/// Transition view with proper screenplay formatting (right-aligned)
/// Examples: CUT TO:, FADE OUT., DISSOLVE TO:
public struct TransitionView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        // Calculate fixed character widths instead of using GeometryReader
        // This eliminates layout calculations during scroll
        let characterWidth = fontSize * ScreenplayPageFormat.courierCharacterAspectRatio
        let leftMarginWidth = characterWidth * (ScreenplayPageFormat.charactersPerLine * 0.65)  // 65% of 65 characters
        let contentMaxWidth = characterWidth * (ScreenplayPageFormat.charactersPerLine * 0.35)  // 35% of 65 characters

        HStack(alignment: .top, spacing: 0) {
            // 65% left margin for right-aligned effect (42.25 characters)
            Spacer()
                .frame(width: leftMarginWidth)

            Text(element.elementText)
                .font(.custom("Courier New", size: fontSize))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: contentMaxWidth, alignment: .trailing)
        }
        .fixedSize(horizontal: false, vertical: false)
    }
}
