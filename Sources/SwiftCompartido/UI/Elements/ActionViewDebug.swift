//
//  ActionViewDebug.swift
//  SwiftCompartido
//
//  DEBUG VERSION - Helps identify truncation issues
//

import SwiftUI

/// DEBUG: Action line view with visual debugging aids
public struct ActionViewDebug: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize
    @State private var textHeight: CGFloat = 0
    @State private var containerHeight: CGFloat = 0

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Debug info
            Text("DEBUG: Action Line")
                .font(.caption2)
                .foregroundStyle(.orange)

            Text("Text: \(element.elementText.prefix(50))...")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Text Height: \(Int(textHeight)) | Container: \(Int(containerHeight))")
                .font(.caption2)
                .foregroundStyle(.blue)

            // Actual view with debug borders
            GeometryReader { geometry in
                HStack(alignment: .top, spacing: 0) {
                    // 10% left margin for action
                    Spacer()
                        .frame(width: geometry.size.width * 0.10)
                        .background(Color.green.opacity(0.2)) // DEBUG: Show left margin

                    Text(element.elementText)
                        .font(.custom("Courier New", size: fontSize))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(
                            maxWidth: geometry.size.width * 0.80,
                            alignment: .leading
                        )
                        .background(
                            GeometryReader { textGeometry in
                                Color.yellow.opacity(0.2) // DEBUG: Show text area
                                    .onAppear {
                                        textHeight = textGeometry.size.height
                                    }
                            }
                        )

                    // 10% right margin
                    Spacer()
                        .frame(width: geometry.size.width * 0.10)
                        .background(Color.green.opacity(0.2)) // DEBUG: Show right margin
                }
                .frame(width: geometry.size.width, alignment: .leading)
                .background(
                    GeometryReader { containerGeometry in
                        Color.red.opacity(0.1) // DEBUG: Show container
                            .onAppear {
                                containerHeight = containerGeometry.size.height
                            }
                    }
                )
            }
            .fixedSize(horizontal: false, vertical: false)
            .padding(.vertical, fontSize * 0.35)
            .border(Color.purple, width: 2) // DEBUG: Show outer boundary

            Divider()
        }
    }
}
