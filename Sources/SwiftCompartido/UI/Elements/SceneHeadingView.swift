//
//  SceneHeadingView.swift
//  SwiftCompartido
//
//  Scene heading view (slugline) with proper screenplay formatting
//

import SwiftUI

/// Scene heading view (slugline) with proper screenplay formatting
/// Scene headings are full-width, bold, uppercase
public struct SceneHeadingView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        Text(element.elementText)
            .font(.custom("Courier New", size: fontSize).weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, fontSize * 0.67)
    }
}
