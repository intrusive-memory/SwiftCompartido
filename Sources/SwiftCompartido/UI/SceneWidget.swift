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

                                // Render element using dedicated view based on type
                                switch element.elementType {
                                case .action:
                                    ActionView(element: element)
                                case .sceneHeading:
                                    SceneHeadingView(element: element)
                                case .transition:
                                    TransitionView(element: element)
                                case .sectionHeading:
                                    SectionHeadingView(element: element)
                                case .synopsis:
                                    SynopsisView(element: element)
                                case .comment:
                                    CommentView(element: element)
                                case .boneyard:
                                    BoneyardView(element: element)
                                case .pageBreak:
                                    PageBreakView()
                                case .character, .dialogue, .parenthetical, .lyrics:
                                    // These should be handled by DialogueBlockView
                                    // This case should rarely be reached
                                    Text("Unexpected dialogue element outside block: \(element.elementType)")
                                        .foregroundStyle(.red)
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
