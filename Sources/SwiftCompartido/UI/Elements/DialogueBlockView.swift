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
