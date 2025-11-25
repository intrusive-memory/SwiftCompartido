//
//  DialogueCharacterView.swift
//  SwiftCompartido
//
//  Character name view with proper screenplay formatting
//

import SwiftUI

/// Character name view with proper screenplay formatting (40% left margin)
public struct DialogueCharacterView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        // Calculate fixed character widths instead of using GeometryReader
        // This eliminates layout calculations during scroll
        let characterWidth = fontSize * ScreenplayPageFormat.courierCharacterAspectRatio
        let leftMarginWidth = characterWidth * 26  // 40% of 65 characters = 26 characters
        let contentMaxWidth = characterWidth * 39  // 60% of 65 characters = 39 characters

        HStack(alignment: .bottom, spacing: 0) {
            // 40% left margin for character names (26 characters)
            Spacer()
                .frame(width: leftMarginWidth)

            Text(element.elementText)
                .font(.custom("Courier New", size: fontSize * 0.75).weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: contentMaxWidth, alignment: .leading)

            Spacer()
        }
    }
}
