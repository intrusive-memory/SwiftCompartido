//
//  MarkdownListItemReferenceView.swift
//  SwiftCompartido
//
//  Simplified markdown list item view for ElementReference
//

import SwiftUI

/// Simplified markdown list item view for ElementReference
///
/// This is a simplified version of MarkdownListItemView that works with
/// ElementReference. It uses simple bullet points for both ordered and
/// unordered lists since ElementReference doesn't have access to the
/// full document context needed for proper numbering.
@available(iOS 26.0, macOS 26.0, *)
struct MarkdownListItemReferenceView: View {
    let element: ElementReference
    @Environment(\.screenplayFontSize) var fontSize

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.custom("Courier New", size: fontSize))
                .foregroundColor(.primary)

            Text(element.elementText)
                .font(.custom("Courier New", size: fontSize))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, fontSize * 2)
    }
}
