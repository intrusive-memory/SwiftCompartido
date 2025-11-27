//
//  DialogueTextView.swift
//  SwiftCompartido
//
//  Dialogue text view with proper screenplay formatting
//

import SwiftUI

/// Dialogue text view with proper screenplay formatting (25% left margin, 25% right margin)
public struct DialogueTextView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        HStack {
            Spacer()
                .frame(minWidth: 100) // 25% left margin

            // Use pre-computed formatted text if available (NEW in 5.4.0)
            // Falls back to runtime formatting for backward compatibility
            Text(element.formattedText ?? FountainTextFormatter.format(
                element.elementText,
                baseFont: .custom("Courier New", size: fontSize)
            ))
                .font(.custom("Courier New", size: fontSize))
                .foregroundStyle(.primary)
                .textSelection(.disabled)  // TEMP: Disabled to allow custom context menu
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
                .frame(minWidth: 100) // 25% right margin
        }
    }
}
