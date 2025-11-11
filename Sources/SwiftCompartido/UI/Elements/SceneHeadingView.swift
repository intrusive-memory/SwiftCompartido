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
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            Text(element.elementText)
                .font(.custom("Courier New", size: fontSize * 1.5).weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
