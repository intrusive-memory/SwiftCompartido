//
//  CommentView.swift
//  SwiftCompartido
//
//  Comment view for inline screenplay notes
//

import SwiftUI

/// Comment view for inline screenplay notes
/// Notes that appear in source but not in formatted output
public struct CommentView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        Text("[[" + element.elementText + "]]")
            .font(.custom("Courier New", size: fontSize * 0.83))
            .foregroundStyle(.secondary.opacity(0.6))
            .italic()
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, fontSize * 0.17)
    }
}
