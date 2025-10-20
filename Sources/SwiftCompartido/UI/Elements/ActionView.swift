//
//  ActionView.swift
//  SwiftCompartido
//
//  Action line view with proper screenplay formatting
//

import SwiftUI

/// Action line view with proper screenplay formatting (10% left margin, 10% right margin)
public struct ActionView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // 10% left margin for action
                Spacer()
                    .frame(width: geometry.size.width * 0.10)

                Text(element.elementText)
                    .font(.custom("Courier New", size: fontSize))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: geometry.size.width * 0.80, // 100% - 10% - 10% = 80%
                        alignment: .leading
                    )

                // 10% right margin
                Spacer()
                    .frame(width: geometry.size.width * 0.10)
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, fontSize * 0.35)
    }
}
