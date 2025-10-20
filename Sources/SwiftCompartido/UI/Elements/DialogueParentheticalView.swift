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
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // 32% left margin for parentheticals
                Spacer()
                    .frame(width: geometry.size.width * 0.32)

                Text(element.elementText)
                    .font(.custom("Courier New", size: fontSize * 0.65))
                    .italic()
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: geometry.size.width * 0.38, // 100% - 32% - 30% = 38%
                        alignment: .leading
                    )

                // 30% right margin
                Spacer()
                    .frame(width: geometry.size.width * 0.30)
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
