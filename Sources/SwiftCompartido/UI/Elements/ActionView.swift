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
        Text(element.elementText)
            .font(.custom("Courier New", size: fontSize))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40) // 10% left + 10% right margin approximation
            .padding(.vertical, fontSize * 0.35)
    }
}
