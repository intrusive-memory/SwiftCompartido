//
//  PreSceneBox.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//
//  Expandable/collapsable box for OVER BLACK content attached to scenes
//

import SwiftUI
import SwiftData

/// A collapsible box displaying pre-scene content (OVER BLACK) with an expandable disclosure
public struct PreSceneBox: View {
    let content: [GuionElementModel]
    @Binding var isExpanded: Bool
    @Environment(\.screenplayFontSize) var fontSize

    /// Creates a PreSceneBox with the given content and expansion state
    /// - Parameters:
    ///   - content: Array of GuionElementModels representing the pre-scene content
    ///   - isExpanded: Binding to control the expanded/collapsed state
    public init(content: [GuionElementModel], isExpanded: Binding<Bool>) {
        self.content = content
        self._isExpanded = isExpanded
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with chevron
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)

                    Text("OVER BLACK")
                        .font(.custom("Courier New", size: fontSize * 0.83))
                        .italic()
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    Color.secondary.opacity(0.1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("OVER BLACK content")
            .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
            .accessibilityAddTraits(.isButton)

            // Content (conditionally shown)
            if isExpanded {
                VStack(alignment: .center, spacing: 4) {
                    ForEach(content.indices, id: \.self) { index in
                        // Pre-scene content is typically centered and italic
                        Text(content[index].elementText)
                            .font(.custom("Courier New", size: fontSize))
                            .italic()
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    Color.secondary.opacity(0.05)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
