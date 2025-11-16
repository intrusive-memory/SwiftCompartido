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
    @Environment(\.guionElementContextMenu) private var contextMenuProvider

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        Text(FountainTextFormatter.format(
            element.elementText,
            baseFont: .custom("Courier New", size: fontSize)
        ))
            .font(.custom("Courier New", size: fontSize))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contextMenu {
                if let provider = contextMenuProvider {
                    provider.menuBuilder(element)
                }
            }
    }
}
