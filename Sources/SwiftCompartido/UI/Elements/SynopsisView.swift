//
//  SynopsisView.swift
//  SwiftCompartido
//
//  Synopsis/outline summary view
//

import SwiftUI

/// Synopsis/outline summary view
/// Brief description of a scene or section
public struct SynopsisView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        Text(element.elementText)
            .font(.custom("Courier New", size: fontSize * 0.9).italic())
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, fontSize * 0.25)
    }
}
