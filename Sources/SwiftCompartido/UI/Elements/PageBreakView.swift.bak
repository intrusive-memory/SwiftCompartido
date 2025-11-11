//
//  PageBreakView.swift
//  SwiftCompartido
//
//  Page break view for forced page breaks in screenplay
//

import SwiftUI

/// Page break view for forced page breaks in screenplay
/// Displays as a visual divider
public struct PageBreakView: View {
    @Environment(\.screenplayFontSize) var fontSize

    public init() {}

    public var body: some View {
        VStack(spacing: 4) {
            Divider()
                .background(Color.secondary.opacity(0.3))

            Text("• • •")
                .font(.custom("Courier New", size: fontSize * 0.75))
                .foregroundStyle(.secondary.opacity(0.5))

            Divider()
                .background(Color.secondary.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, fontSize * 0.5)
    }
}
