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

            Text(element.elementText)
                .font(.custom("Courier New", size: fontSize))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
                .frame(minWidth: 100) // 25% right margin
        }
        .padding(.horizontal, 20)
    }
}
