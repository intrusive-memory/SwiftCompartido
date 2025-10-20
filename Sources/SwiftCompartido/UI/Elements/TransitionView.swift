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
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // 65% left margin for right-aligned effect
                Spacer()
                    .frame(width: geometry.size.width * 0.65)

                Text(element.elementText)
                    .font(.custom("Courier New", size: fontSize))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: geometry.size.width * 0.35, alignment: .trailing)
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: false)
        .padding(.vertical, fontSize * 0.67)
    }
}
