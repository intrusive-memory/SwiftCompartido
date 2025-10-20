//
//  SceneWidget.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//
//  Individual scene disclosure group with optional preScene content
//

import SwiftUI

/// A widget displaying an individual scene with optional pre-scene content
public struct SceneWidget: View {
    let scene: SceneData
    @Binding var isExpanded: Bool
    @Binding var preSceneExpanded: Bool
    @Environment(\.screenplayFontSize) var fontSize

    /// Creates a SceneWidget
    /// - Parameters:
    ///   - scene: The scene data to display
    ///   - isExpanded: Binding to control the scene's expanded/collapsed state
    ///   - preSceneExpanded: Binding to control the pre-scene content's expanded/collapsed state
    public init(scene: SceneData, isExpanded: Binding<Bool>, preSceneExpanded: Binding<Bool>) {
        self.scene = scene
        self._isExpanded = isExpanded
        self._preSceneExpanded = preSceneExpanded
    }

    private var sceneElementsAccessibilityHint: String {
        let count = scene.sceneElementModels.count
        return "\(count) elements"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // PreScene box (if exists)
            if scene.hasPreScene, let preSceneModels = scene.preSceneElementModels {
                PreSceneBox(
                    content: preSceneModels,
                    isExpanded: $preSceneExpanded
                )
                .padding(.bottom, 4)
            }

            // Scene disclosure group
            DisclosureGroup(
                isExpanded: $isExpanded,
                content: {
                    VStack(alignment: .leading, spacing: fontSize * 0.5) {
                        // Filter out Scene Heading since it's already shown in the label
                        let filteredElements = scene.sceneElementModels.filter { $0.elementType != .sceneHeading }

                        // Group dialogue blocks (Character + Parenthetical + Dialogue)
                        let dialogueBlocks = groupDialogueBlocks(elements: filteredElements)

                        ForEach(dialogueBlocks.indices, id: \.self) { blockIndex in
                            if dialogueBlocks[blockIndex].isDialogueBlock {
                                DialogueBlockView(block: dialogueBlocks[blockIndex])
                            } else {
                                let element = dialogueBlocks[blockIndex].elements[0]
                                if element.elementType == .action {
                                    ActionView(element: element)
                                } else {
                                    SceneElementView(element: element)
                                }
                            }
                        }
                    }
                    .padding(.top, fontSize * 0.67)
                    .padding(.bottom, fontSize * 1.0)
                },
                label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(scene.slugline)
                                .font(.custom("Courier New", size: fontSize))
                                .bold()
                                .underline()
                                .textCase(.uppercase)
                                .foregroundStyle(.primary)

                            Spacer()

                            if let location = scene.sceneLocation {
                                Text(location.lighting.standardAbbreviation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.secondary.opacity(0.1))
                                    )
                                    .accessibilityLabel("\(location.lighting.standardAbbreviation) scene")
                            }
                        }

                        // Display summary in collapsed state
                        if let summary = scene.summary, !isExpanded {
                            Text(summary)
                                .font(.custom("Courier New", size: fontSize * 0.83))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Scene: \(scene.slugline)")
            .accessibilityHint(sceneElementsAccessibilityHint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .padding(.leading, 24) // Scene indent
    }
}

// MARK: - Scene Element Views

/// Internal view for rendering individual scene elements with proper screenplay formatting
struct SceneElementView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // Leading margin/indent
                if leadingMarginWidth(totalWidth: geometry.size.width) > 0 {
                    Spacer()
                        .frame(width: leadingMarginWidth(totalWidth: geometry.size.width))
                }

                // Element text
                Text(element.elementText)
                    .font(fontForElement)
                    .foregroundStyle(colorForElement)
                    .textSelection(.enabled)
                    .multilineTextAlignment(textAlignment)

                // Trailing margin
                if trailingMarginWidth(totalWidth: geometry.size.width) > 0 {
                    Spacer()
                        .frame(width: trailingMarginWidth(totalWidth: geometry.size.width))
                }
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: false)
        .padding(.vertical, verticalPadding)
    }

    // MARK: - Screenplay Formatting Calculations

    /// Calculate leading margin based on element type (as percentage of total width)
    private func leadingMarginWidth(totalWidth: CGFloat) -> CGFloat {
        switch element.elementType {
        case .character:
            return totalWidth * 0.40 // 40% left margin
        case .parenthetical:
            return totalWidth * 0.32 // 32% left margin
        case .dialogue:
            return totalWidth * 0.25 // 25% left margin
        case .transition:
            return totalWidth * 0.65 // 65% left margin (right-aligned effect)
        case .action:
            return totalWidth * 0.10 // 10% left margin
        default:
            return 0
        }
    }

    /// Calculate trailing margin based on element type
    private func trailingMarginWidth(totalWidth: CGFloat) -> CGFloat {
        switch element.elementType {
        case .parenthetical:
            return totalWidth * 0.30 // 30% right margin
        case .dialogue:
            return totalWidth * 0.25 // 25% right margin
        case .action:
            return totalWidth * 0.10 // 10% right margin
        default:
            return 0
        }
    }

    /// Calculate content width (remaining space after margins)
    private func contentWidth(totalWidth: CGFloat) -> CGFloat {
        let leading = leadingMarginWidth(totalWidth: totalWidth)
        let trailing = trailingMarginWidth(totalWidth: totalWidth)
        return totalWidth - leading - trailing
    }

    /// Text alignment based on element type
    private var textAlignment: TextAlignment {
        switch element.elementType {
        case .character:
            return .leading // Character names are typically left-aligned within their column
        case .transition:
            return .trailing // Transitions are right-aligned
        default:
            return .leading
        }
    }

    /// Frame alignment for the text within its container
    private var alignmentForElement: Alignment {
        switch element.elementType {
        case .transition:
            return .trailing
        default:
            return .leading
        }
    }

    /// Font for each element type - all use dynamic Courier New sizing
    private var fontForElement: Font {
        // Level 4 section headers (#### - production directives) - bold and slightly smaller
        if element.elementType == .sectionHeading(level: 4) {
            return .custom("Courier New", size: fontSize * 0.92).weight(.semibold)
        }

        // Parenthetical uses italic
        if element.elementType == .parenthetical {
            return .custom("Courier New", size: fontSize).italic()
        }

        // All other elements use dynamic Courier New sizing
        return .custom("Courier New", size: fontSize)
    }

    /// Color for each element type
    private var colorForElement: Color {
        // Level 4 section headers (production directives) - distinct color
        if element.elementType == .sectionHeading(level: 4) {
            return Color.blue.opacity(0.85)
        }

        switch element.elementType {
        case .parenthetical:
            return .secondary
        case .transition:
            return .primary
        default:
            return .primary
        }
    }

    /// Vertical padding between elements (increased for screen readability)
    private var verticalPadding: CGFloat {
        switch element.elementType {
        case .sceneHeading:
            return fontSize * 0.67 // 2em spacing before scene headings
        case .character:
            return fontSize * 0.5 // 1.5em spacing before character names
        case .transition:
            return fontSize * 0.67 // 2em spacing before transitions
        case .action:
            return fontSize * 0.35
        default:
            return fontSize * 0.08
        }
    }

}

// MARK: - Dialogue Block Grouping

/// Represents a block of elements - either a dialogue block or a single non-dialogue element
public struct DialogueBlock {
    public let elements: [GuionElementModel]
    public let isDialogueBlock: Bool

    public init(elements: [GuionElementModel], isDialogueBlock: Bool) {
        self.elements = elements
        self.isDialogueBlock = isDialogueBlock
    }
}

/// Groups elements into dialogue blocks (Character + Parentheticals + Dialogue) and standalone elements
public func groupDialogueBlocks(elements: [GuionElementModel]) -> [DialogueBlock] {
    var blocks: [DialogueBlock] = []
    var currentBlock: [GuionElementModel] = []
    var inDialogueBlock = false

    for element in elements {
        switch element.elementType {
        case .character:
            // Start a new dialogue block
            if !currentBlock.isEmpty {
                // Save previous block
                blocks.append(DialogueBlock(elements: currentBlock, isDialogueBlock: inDialogueBlock))
                currentBlock = []
            }
            currentBlock.append(element)
            inDialogueBlock = true

        case .parenthetical, .dialogue, .lyrics:
            // Add to current dialogue block if we're in one
            if inDialogueBlock {
                currentBlock.append(element)
            } else {
                // Treat as standalone if not in a dialogue block
                blocks.append(DialogueBlock(elements: [element], isDialogueBlock: false))
            }

        default:
            // Non-dialogue element - save current block and add as standalone
            if !currentBlock.isEmpty {
                blocks.append(DialogueBlock(elements: currentBlock, isDialogueBlock: inDialogueBlock))
                currentBlock = []
                inDialogueBlock = false
            }
            blocks.append(DialogueBlock(elements: [element], isDialogueBlock: false))
        }
    }

    // Don't forget the last block
    if !currentBlock.isEmpty {
        blocks.append(DialogueBlock(elements: currentBlock, isDialogueBlock: inDialogueBlock))
    }

    return blocks
}

// MARK: - Dialogue Block View

/// View for rendering a dialogue block (Character + Parentheticals + Dialogue) with background styling
struct DialogueBlockView: View {
    let block: DialogueBlock
    @Environment(\.screenplayFontSize) var fontSize

    var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.33) {
            ForEach(block.elements.indices, id: \.self) { index in
                let element = block.elements[index]

                if element.elementType == .character {
                    DialogueCharacterView(element: element)
                } else if element.elementType == .parenthetical {
                    DialogueParentheticalView(element: element)
                } else if element.elementType == .dialogue {
                    DialogueTextView(element: element)
                } else if element.elementType == .lyrics {
                    DialogueLyricsView(element: element)
                }
            }
        }
        .padding(.top, fontSize * 0.57)
        .padding(.bottom, fontSize * 0.85)
        .background(
            GeometryReader { geometry in
                // Background positioned to cover only dialogue text area (25% to 75% of width)
                HStack(spacing: 0) {
                    Spacer()
                        .frame(width: geometry.size.width * 0.22)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
                        )
                        .frame(width: geometry.size.width * 0.56)
                        .padding(.horizontal, 12)
                        .padding(.vertical, fontSize * 0.13)

                    Spacer()
                }
            }
        )
    }
}

// MARK: - Dialogue Element Views

/// Character name view with proper screenplay formatting (40% left margin)
struct DialogueCharacterView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // 40% left margin for character names
                Spacer()
                    .frame(width: geometry.size.width * 0.40)

                Text(element.elementText)
                    .font(.custom("Courier New", size: fontSize * 0.75).weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: geometry.size.width * 0.60, alignment: .leading)

                Spacer()
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: false)
    }
}

/// Parenthetical view with proper screenplay formatting (32% left margin, 30% right margin)
struct DialogueParentheticalView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // 32% left margin for parentheticals
                Spacer()
                    .frame(width: geometry.size.width * 0.32)

                Text(element.elementText)
                    .font(.custom("Courier New", size: fontSize * 0.65))
                    .italic()
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: geometry.size.width * 0.38, // 100% - 32% - 30% = 38%
                        alignment: .leading
                    )

                // 30% right margin
                Spacer()
                    .frame(width: geometry.size.width * 0.30)
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Dialogue text view with proper screenplay formatting (25% left margin, 25% right margin)
struct DialogueTextView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // 25% left margin for dialogue
                Spacer()
                    .frame(width: geometry.size.width * 0.25)

                Text(element.elementText)
                    .font(.custom("Courier New", size: fontSize))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: geometry.size.width * 0.50, // 100% - 25% - 25% = 50%
                        alignment: .leading
                    )

                // 25% right margin
                Spacer()
                    .frame(width: geometry.size.width * 0.25)
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: false)
    }
}

/// Lyrics view with proper screenplay formatting (25% left margin, 25% right margin, italic)
struct DialogueLyricsView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // 25% left margin for lyrics
                Spacer()
                    .frame(width: geometry.size.width * 0.25)

                Text(element.elementText)
                    .font(.custom("Courier New", size: fontSize))
                    .italic()
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: geometry.size.width * 0.50, // 100% - 25% - 25% = 50%
                        alignment: .leading
                    )

                // 25% right margin
                Spacer()
                    .frame(width: geometry.size.width * 0.25)
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Action View

/// Action line view with proper screenplay formatting (10% left margin, 10% right margin)
struct ActionView: View {
    let element: GuionElementModel
    @Environment(\.screenplayFontSize) var fontSize

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // 10% left margin for action
                Spacer()
                    .frame(width: geometry.size.width * 0.10)

                Text(element.elementText)
                    .font(.custom("Courier New", size: fontSize))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: geometry.size.width * 0.80, // 100% - 10% - 10% = 80%
                        alignment: .leading
                    )

                // 10% right margin
                Spacer()
                    .frame(width: geometry.size.width * 0.10)
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, fontSize * 0.35)
    }
}
