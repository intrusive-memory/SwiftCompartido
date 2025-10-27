//
//  SectionHeadingView.swift
//  SwiftCompartido
//
//  Section heading view for screenplay outline structure
//

import SwiftUI

/// Section heading view for screenplay outline structure (levels 1-6)
/// Level 1: Title, Level 2: Act, Level 3: Sequence, Level 4: Scene group, Level 5: Sub-scene, Level 6: Beat
public struct SectionHeadingView: View {
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
        Text(element.elementText)
            .font(fontForLevel)
            .foregroundStyle(colorForLevel)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: alignmentForLevel)
            .padding(.vertical, verticalPaddingForLevel)
    }

    private var fontForLevel: Font {
        switch level {
        case 1:
            return .custom("Helvetica Neue", size: fontSize * 1.5).weight(.bold) // Title
        case 2:
            return .custom("Helvetica Neue", size: fontSize * 1.3).weight(.bold) // Act
        case 3:
            return .custom("Helvetica Neue", size: fontSize * 1.1).weight(.semibold) // Sequence
        case 4:
            return .custom("Helvetica Neue", size: fontSize * 0.92).weight(.semibold) // Scene group (production directives)
        case 5:
            return .custom("Helvetica Neue", size: fontSize).weight(.medium) // Sub-scene
        case 6:
            return .custom("Helvetica Neue", size: fontSize * 0.9).weight(.regular) // Beat
        default:
            return .custom("Helvetica Neue", size: fontSize)
        }
    }

    private var colorForLevel: Color {
        switch level {
        case 1, 2:
            return .primary
        case 3:
            return .primary.opacity(0.9)
        case 4:
            return Color.blue.opacity(0.85) // Production directives
        case 5, 6:
            return .secondary
        default:
            return .primary
        }
    }

    private var alignmentForLevel: Alignment {
        switch level {
        case 1:
            return .center // Title centered
        case 4:
            return .leading // Production directives left-aligned
        default:
            return .leading
        }
    }

    private var verticalPaddingForLevel: CGFloat {
        switch level {
        case 1:
            return fontSize * 1.0
        case 2:
            return fontSize * 0.83
        case 3:
            return fontSize * 0.67
        case 4:
            return fontSize * 0.5
        default:
            return fontSize * 0.33
        }
    }
}
