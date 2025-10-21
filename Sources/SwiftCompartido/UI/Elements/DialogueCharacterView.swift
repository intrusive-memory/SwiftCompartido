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
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // 40% left margin for character names
                Spacer()
                    .frame(width: geometry.size.width * 0.40)

                Text(element.elementText)
                    .font(.custom("Courier New", size: fontSize * 0.75).weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: geometry.size.width * 0.60, alignment: .leading)

                Spacer()
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: false)
        .padding(.top, fontSize * 1.5)    // More space above character name (separation from previous element)
        .padding(.bottom, fontSize * 0.2)  // Less space below character name (closer to dialogue)
    }
}
