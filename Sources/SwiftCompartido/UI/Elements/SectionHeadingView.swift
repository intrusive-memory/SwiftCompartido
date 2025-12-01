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
        Group {
            if level <= 3 {
                VStack(spacing: 0) {
                    Spacer(minLength: spacingForLevel)
                    formattedText
                        .font(fontForLevel)
                        .foregroundStyle(colorForLevel)
                        .textSelection(.disabled)  // TEMP: Disabled to allow custom context menu
                        .frame(maxWidth: .infinity, alignment: alignmentForLevel)
                }
            } else {
                formattedText
                    .font(fontForLevel)
                    .foregroundStyle(colorForLevel)
                    .textSelection(.disabled)  // TEMP: Disabled to allow custom context menu
                    .frame(maxWidth: .infinity, alignment: alignmentForLevel)
                    .padding(.vertical, paddingForLevel)
            }
        }
    }

    /// Renders text with bold and italic formatting using AttributedString
    /// Includes greyed-out hashtag prefix to visually identify outline level
    private var formattedText: Text {
        // Greyed-out hashtag prefix (# for level 1, ## for level 2, etc.)
        let hashtagPrefix = String(repeating: "#", count: level)
        var prefixAttributedString = AttributedString(hashtagPrefix)
        prefixAttributedString.foregroundColor = .secondary.opacity(0.5)

        // Add space between hashtags and text
        let spacer = AttributedString(" ")

        // Parse the element text with formatting
        let textAttributedString = parseFormattedText(element.elementText)

        // Combine: hashtags + space + text
        let combined = prefixAttributedString + spacer + textAttributedString
        return Text(combined)
    }

    /// Parses text with **bold** and *italic* markers into AttributedString
    private func parseFormattedText(_ text: String) -> AttributedString {
        var attributedString = AttributedString()
        var currentText = ""
        var i = text.startIndex

        while i < text.endIndex {
            // Check for **bold**
            if i < text.index(text.endIndex, offsetBy: -1),
               text[i] == "*",
               text[text.index(after: i)] == "*" {
                // Add accumulated text
                if !currentText.isEmpty {
                    attributedString += AttributedString(currentText)
                    currentText = ""
                }
                // Find closing **
                i = text.index(i, offsetBy: 2)
                var boldText = ""
                while i < text.endIndex {
                    if i < text.index(text.endIndex, offsetBy: -1),
                       text[i] == "*",
                       text[text.index(after: i)] == "*" {
                        var boldAttributedString = AttributedString(boldText)
                        boldAttributedString.inlinePresentationIntent = .stronglyEmphasized
                        attributedString += boldAttributedString
                        i = text.index(i, offsetBy: 2)
                        break
                    }
                    boldText.append(text[i])
                    i = text.index(after: i)
                }
                continue
            }

            // Check for *italic*
            if text[i] == "*" {
                // Add accumulated text
                if !currentText.isEmpty {
                    attributedString += AttributedString(currentText)
                    currentText = ""
                }
                // Find closing *
                i = text.index(after: i)
                var italicText = ""
                while i < text.endIndex {
                    if text[i] == "*" {
                        var italicAttributedString = AttributedString(italicText)
                        italicAttributedString.inlinePresentationIntent = .emphasized
                        attributedString += italicAttributedString
                        i = text.index(after: i)
                        break
                    }
                    italicText.append(text[i])
                    i = text.index(after: i)
                }
                continue
            }

            currentText.append(text[i])
            i = text.index(after: i)
        }

        // Add remaining text
        if !currentText.isEmpty {
            attributedString += AttributedString(currentText)
        }

        return attributedString
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

    private var spacingForLevel: CGFloat {
        switch level {
        case 1:
            return 30 // Title - most spacing
        case 2:
            return 25 // Act - significant spacing
        case 3:
            return 20 // Sequence - moderate spacing
        default:
            return 0
        }
    }

    private var paddingForLevel: CGFloat {
        switch level {
        case 4:
            return fontSize * 0.5 // Production directives need vertical separation
        default:
            return 0
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
            return fontSize * 0.25
        }
    }
}
