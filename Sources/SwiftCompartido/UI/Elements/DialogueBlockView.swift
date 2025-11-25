//
//  DialogueBlockView.swift
//  SwiftCompartido
//
//  View for rendering a dialogue block with background styling
//

import SwiftUI

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

/// View for rendering a dialogue block (Character + Parentheticals + Dialogue) with background styling
public struct DialogueBlockView: View {
    let block: DialogueBlock
    @Environment(\.screenplayFontSize) var fontSize

    public init(block: DialogueBlock) {
        self.block = block
    }

    public var body: some View {
        // Calculate fixed character widths instead of using GeometryReader
        // This eliminates layout calculations during scroll
        let characterWidth = fontSize * ScreenplayPageFormat.courierCharacterAspectRatio
        let backgroundLeftMargin = characterWidth * 14.3   // 22% of 65 characters = 14.3 characters
        let backgroundWidth = characterWidth * 36.4        // 56% of 65 characters = 36.4 characters

        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 20)
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
        .background(
            // Background positioned to cover only dialogue text area (22% to 78% of width)
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: backgroundLeftMargin)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
                    )
                    .frame(width: backgroundWidth)

                Spacer()
            }
        )
    }
}
