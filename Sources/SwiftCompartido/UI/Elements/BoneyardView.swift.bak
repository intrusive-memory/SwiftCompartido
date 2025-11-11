//
//  BoneyardView.swift
//  SwiftCompartido
//
//  Boneyard view for omitted/commented-out content
//

import SwiftUI

/// Boneyard view for omitted/commented-out content
/// Content that has been commented out using /* ... */ block syntax
public struct BoneyardView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        Text(element.elementText)
            .font(.custom("Courier New", size: fontSize * 0.83))
            .foregroundStyle(.secondary.opacity(0.5))
            .strikethrough(true, color: .secondary.opacity(0.5))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, fontSize * 0.17)
    }
}
