import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Converts screenplay elements to a formatted attributed string
/// following standard screenplay formatting conventions
@MainActor
public struct ScreenplayTextRenderer {

    // MARK: - Formatting Constants

    /// Standard Courier 12pt font used in screenplays
    private static let courierFont: Font = {
        #if canImport(AppKit)
        return NSFont(name: "Courier", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .regular)
        #else
        return UIFont(name: "Courier", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .regular)
        #endif
    }()

    /// Page width in points (8.5" at 72 DPI)
    private static let pageWidth: CGFloat = 612

    /// Left margin for most elements (1.5")
    private static let standardLeftMargin: CGFloat = 108

    /// Character name indent (3.7" from left)
    private static let characterIndent: CGFloat = 266.4

    /// Dialogue indent (2.5" from left)
    private static let dialogueIndent: CGFloat = 180

    /// Dialogue right margin (6.5" from left)
    private static let dialogueRightMargin: CGFloat = 468

    /// Parenthetical indent (3.1" from left)
    private static let parentheticalIndent: CGFloat = 223.2

    /// Transition alignment (right-aligned at 7")
    private static let transitionIndent: CGFloat = 504

    // MARK: - Public API

    /// Renders a document as a formatted attributed string
    public static func render(document: GuionDocumentModel) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Render title page if present
        if !document.titlePage.isEmpty {
            result.append(renderTitlePage(document.titlePage))
            result.append(NSAttributedString(string: "\n\n\n"))
        }

        // Render all elements in order
        for element in document.sortedElements {
            result.append(renderElement(element))
        }

        return result
    }

    // MARK: - Title Page Rendering

    private static func renderTitlePage(_ entries: [TitlePageEntryModel]) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for entry in entries {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.paragraphSpacing = 12

            let attrs: [NSAttributedString.Key: Any] = [
                .font: courierFont,
                .paragraphStyle: style
            ]

            let line = NSAttributedString(
                string: "\(entry.key.uppercased()): \(entry.value)\n",
                attributes: attrs
            )
            result.append(line)
        }

        return result
    }

    // MARK: - Element Rendering

    private static func renderElement(_ element: GuionElementModel) -> NSAttributedString {
        switch element.elementType {
        case .sceneHeading:
            return renderSceneHeading(element)
        case .action:
            return renderAction(element)
        case .character:
            return renderCharacter(element)
        case .dialogue:
            return renderDialogue(element)
        case .parenthetical:
            return renderParenthetical(element)
        case .transition:
            return renderTransition(element)
        case .lyrics:
            return renderLyrics(element)
        case .section, .synopsis:
            return renderSection(element)
        case .pageBreak:
            return renderPageBreak()
        case .centeredText:
            return renderCentered(element)
        case .titlePage:
            return NSAttributedString() // Already rendered above
        case .dualDialogue:
            return renderDualDialogue(element)
        case .boneyard:
            return NSAttributedString() // Don't render boneyard
        }
    }

    private static func renderSceneHeading(_ element: GuionElementModel) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = standardLeftMargin
        style.headIndent = standardLeftMargin
        style.paragraphSpacing = 12
        style.paragraphSpacingBefore = 12

        let attrs: [NSAttributedString.Key: Any] = [
            .font: courierFont,
            .paragraphStyle: style
        ]

        return NSAttributedString(
            string: element.text.uppercased() + "\n",
            attributes: attrs
        )
    }

    private static func renderAction(_ element: GuionElementModel) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = standardLeftMargin
        style.headIndent = standardLeftMargin
        style.paragraphSpacing = 12

        let attrs: [NSAttributedString.Key: Any] = [
            .font: courierFont,
            .paragraphStyle: style
        ]

        return NSAttributedString(
            string: element.text + "\n",
            attributes: attrs
        )
    }

    private static func renderCharacter(_ element: GuionElementModel) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = characterIndent
        style.headIndent = characterIndent
        style.paragraphSpacingBefore = 12

        let attrs: [NSAttributedString.Key: Any] = [
            .font: courierFont,
            .paragraphStyle: style
        ]

        return NSAttributedString(
            string: element.text.uppercased() + "\n",
            attributes: attrs
        )
    }

    private static func renderDialogue(_ element: GuionElementModel) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = dialogueIndent
        style.headIndent = dialogueIndent
        style.tailIndent = -dialogueRightMargin

        let attrs: [NSAttributedString.Key: Any] = [
            .font: courierFont,
            .paragraphStyle: style
        ]

        return NSAttributedString(
            string: element.text + "\n",
            attributes: attrs
        )
    }

    private static func renderParenthetical(_ element: GuionElementModel) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = parentheticalIndent
        style.headIndent = parentheticalIndent

        let attrs: [NSAttributedString.Key: Any] = [
            .font: courierFont,
            .paragraphStyle: style
        ]

        return NSAttributedString(
            string: element.text + "\n",
            attributes: attrs
        )
    }

    private static func renderTransition(_ element: GuionElementModel) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        style.firstLineHeadIndent = transitionIndent
        style.paragraphSpacing = 12
        style.paragraphSpacingBefore = 12

        let attrs: [NSAttributedString.Key: Any] = [
            .font: courierFont,
            .paragraphStyle: style
        ]

        return NSAttributedString(
            string: element.text.uppercased() + "\n",
            attributes: attrs
        )
    }

    private static func renderLyrics(_ element: GuionElementModel) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = dialogueIndent
        style.headIndent = dialogueIndent

        let attrs: [NSAttributedString.Key: Any] = [
            .font: courierFont,
            .paragraphStyle: style,
            .obliqueness: 0.15 // Italics approximation
        ]

        return NSAttributedString(
            string: element.text + "\n",
            attributes: attrs
        )
    }

    private static func renderSection(_ element: GuionElementModel) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = standardLeftMargin
        style.headIndent = standardLeftMargin
        style.paragraphSpacing = 6

        let attrs: [NSAttributedString.Key: Any] = [
            .font: courierFont,
            .paragraphStyle: style,
            .foregroundColor: Color.gray
        ]

        return NSAttributedString(
            string: "# \(element.text)\n",
            attributes: attrs
        )
    }

    private static func renderPageBreak() -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacing = 24
        style.paragraphSpacingBefore = 24

        let attrs: [NSAttributedString.Key: Any] = [
            .font: courierFont,
            .paragraphStyle: style,
            .foregroundColor: Color.lightGray
        ]

        return NSAttributedString(
            string: "===\n",
            attributes: attrs
        )
    }

    private static func renderCentered(_ element: GuionElementModel) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacing = 12

        let attrs: [NSAttributedString.Key: Any] = [
            .font: courierFont,
            .paragraphStyle: style
        ]

        return NSAttributedString(
            string: element.text + "\n",
            attributes: attrs
        )
    }

    private static func renderDualDialogue(_ element: GuionElementModel) -> NSAttributedString {
        // Simplified - dual dialogue would need column layout
        // For now, render sequentially
        return renderDialogue(element)
    }
}

// MARK: - Platform Aliases

#if canImport(AppKit)
typealias Font = NSFont
typealias Color = NSColor
#else
typealias Font = UIFont
typealias Color = UIColor
#endif
