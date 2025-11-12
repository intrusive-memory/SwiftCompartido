//
//  MarkdownSectionHeadingView.swift
//  SwiftCompartido
//
//  GitHub-style markdown heading rendering
//

import SwiftUI

/// GitHub-style markdown heading view (H1-H6)
public struct MarkdownSectionHeadingView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    public init(element: GuionElementModel) {
        self.element = element
    }

    var level: Int {
        if case .sectionHeading(let lvl) = element.elementType {
            return lvl
        }
        return 1
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(element.elementText)
                .font(fontForLevel)
                .fontWeight(weightForLevel)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, topPaddingForLevel)
                .padding(.bottom, bottomPaddingForLevel)

            // GitHub-style bottom border for H1 and H2
            if level <= 2 {
                Divider()
                    .overlay(Color.gray.opacity(0.3))
            }
        }
    }

    private var fontForLevel: Font {
        switch level {
        case 1:
            return .system(size: fontSize * 2.0) // H1: 2em
        case 2:
            return .system(size: fontSize * 1.5) // H2: 1.5em
        case 3:
            return .system(size: fontSize * 1.25) // H3: 1.25em
        case 4:
            return .system(size: fontSize * 1.0) // H4: 1em
        case 5:
            return .system(size: fontSize * 0.875) // H5: 0.875em
        case 6:
            return .system(size: fontSize * 0.85) // H6: 0.85em
        default:
            return .system(size: fontSize)
        }
    }

    private var weightForLevel: Font.Weight {
        switch level {
        case 1, 2:
            return .semibold
        case 3, 4, 5, 6:
            return .semibold
        default:
            return .regular
        }
    }

    private var topPaddingForLevel: CGFloat {
        switch level {
        case 1:
            return fontSize * 0.67 // GitHub: 0.67em
        case 2:
            return fontSize * 0.67 // GitHub: 0.67em
        case 3:
            return fontSize * 0.67
        case 4:
            return fontSize * 0.67
        case 5:
            return fontSize * 0.67
        case 6:
            return fontSize * 0.67
        default:
            return 0
        }
    }

    private var bottomPaddingForLevel: CGFloat {
        switch level {
        case 1:
            return fontSize * 0.42 // GitHub: 0.42em
        case 2:
            return fontSize * 0.42 // GitHub: 0.42em
        case 3:
            return fontSize * 0.42
        case 4:
            return fontSize * 0.42
        case 5:
            return fontSize * 0.42
        case 6:
            return fontSize * 0.42
        default:
            return 0
        }
    }
}
