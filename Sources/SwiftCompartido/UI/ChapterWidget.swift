//
//  ChapterWidget.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//
//  Level 2 chapter disclosure with scene groups
//

import SwiftUI

/// A widget displaying a chapter (Level 2) with its contained scene groups
public struct ChapterWidget: View {
    let chapter: ChapterData
    @Binding var isExpanded: Bool
    @Binding var expandedSceneGroups: Set<String>
    @Binding var expandedScenes: Set<String>
    @Binding var expandedPreScenes: Set<String>
    @Environment(\.screenplayFontSize) var fontSize

    /// Creates a ChapterWidget
    /// - Parameters:
    ///   - chapter: The chapter data to display
    ///   - isExpanded: Binding to control the chapter's expanded/collapsed state
    ///   - expandedSceneGroups: Binding to the set of expanded scene group IDs
    ///   - expandedScenes: Binding to the set of expanded scene IDs
    ///   - expandedPreScenes: Binding to the set of expanded pre-scene IDs
    public init(
        chapter: ChapterData,
        isExpanded: Binding<Bool>,
        expandedSceneGroups: Binding<Set<String>>,
        expandedScenes: Binding<Set<String>>,
        expandedPreScenes: Binding<Set<String>>
    ) {
        self.chapter = chapter
        self._isExpanded = isExpanded
        self._expandedSceneGroups = expandedSceneGroups
        self._expandedScenes = expandedScenes
        self._expandedPreScenes = expandedPreScenes
    }

    private var chapterNumber: Int? {
        ScreenplayPageFormat.extractChapterNumber(from: chapter.title)
    }

    private var startingPageNumber: Int {
        ScreenplayPageFormat.startingPageNumber(forChapter: chapterNumber)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Page break before chapter (reduced spacing)
            Spacer()
                .frame(height: fontSize * 2)

            DisclosureGroup(
                isExpanded: $isExpanded,
                content: {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(chapter.sceneGroups) { sceneGroup in
                            SceneGroupWidget(
                                sceneGroup: sceneGroup,
                                isExpanded: Binding(
                                    get: { expandedSceneGroups.contains(sceneGroup.id) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedSceneGroups.insert(sceneGroup.id)
                                        } else {
                                            expandedSceneGroups.remove(sceneGroup.id)
                                        }
                                    }
                                ),
                                expandedScenes: $expandedScenes,
                                expandedPreScenes: $expandedPreScenes
                            )
                        }
                    }
                    .padding(.top, 8)
                },
                label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                if chapter.element.isSynthetic {
                                    Text("INFERRED:")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                }
                                Text(chapter.title)
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(chapter.element.isSynthetic ? .secondary : .primary)
                            }

                            // Display starting page number
                            Text("Page \(startingPageNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Spacer()
                    }
                }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Chapter: \(chapter.title), starting page \(startingPageNumber)")
            .accessibilityHint("\(chapter.sceneGroups.count) scene groups")
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.05))
            )
            .overlay(
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                }
            )
        }
    }
}

// MARK: - Previews

#Preview("Chapter Collapsed") {
    ChapterWidget(
        chapter: ChapterData(
            element: OutlineElement(
                id: "chapter-1",
                index: 0,
                level: 2,
                range: [0, 500],
                rawString: "## CHAPTER 1",
                string: "CHAPTER 1",
                type: "sectionHeader"
            ),
            sceneGroups: [
                SceneGroupData(
                    element: OutlineElement(
                        id: "group-1",
                        index: 1,
                        level: 3,
                        range: [10, 100],
                        rawString: "### PROLOGUE",
                        string: "PROLOGUE",
                        type: "sectionHeader"
                    ),
                    scenes: []
                )
            ]
        ),
        isExpanded: .constant(false),
        expandedSceneGroups: .constant([]),
        expandedScenes: .constant([]),
        expandedPreScenes: .constant([])
    )
    .padding()
}

#Preview("Chapter Expanded") {
    ScrollView {
        ChapterWidget(
            chapter: ChapterData(
                element: OutlineElement(
                    id: "chapter-1",
                    index: 0,
                    level: 2,
                    range: [0, 500],
                    rawString: "## CHAPTER 1",
                    string: "CHAPTER 1",
                    type: "sectionHeader"
                ),
                sceneGroups: [
                    SceneGroupData(
                        element: OutlineElement(
                            id: "group-1",
                            index: 1,
                            level: 3,
                            range: [10, 100],
                            rawString: "### PROLOGUE S#{{SERIES: 1001}}",
                            string: "PROLOGUE",
                            type: "sectionHeader",
                            sceneDirective: "PROLOGUE",
                            sceneDirectiveDescription: "S#{{SERIES: 1001}}"
                        ),
                        scenes: [
                            SceneData(
                                element: OutlineElement(
                                    id: "scene-1",
                                    index: 2,
                                    level: 0,
                                    range: [20, 60],
                                    rawString: "INT. STEAM ROOM - DAY",
                                    string: "INT. STEAM ROOM - DAY",
                                    type: "sceneHeader"
                                ),
                                sceneElements: [
                                    GuionElement(elementType: .action, elementText: "Bernard and Killian sit in a steam room.")
                                ],
                                sceneLocation: SceneLocation.parse("INT. STEAM ROOM - DAY")
                            )
                        ]
                    ),
                    SceneGroupData(
                        element: OutlineElement(
                            id: "group-2",
                            index: 3,
                            level: 3,
                            range: [110, 200],
                            rawString: "### THE MURDER",
                            string: "THE MURDER",
                            type: "sectionHeader"
                        ),
                        scenes: [
                            SceneData(
                                element: OutlineElement(
                                    id: "scene-2",
                                    index: 4,
                                    level: 0,
                                    range: [120, 180],
                                    rawString: "INT. HOME - DAY",
                                    string: "INT. HOME - DAY",
                                    type: "sceneHeader"
                                ),
                                sceneElements: [
                                    GuionElement(elementType: .action, elementText: "Bernard examines his outfit.")
                                ],
                                sceneLocation: SceneLocation.parse("INT. HOME - DAY")
                            )
                        ]
                    )
                ]
            ),
            isExpanded: .constant(true),
            expandedSceneGroups: .constant(["group-1"]),
            expandedScenes: .constant(["scene-1"]),
            expandedPreScenes: .constant([])
        )
        .padding()
    }
}

#Preview("Synthetic Chapter") {
    ChapterWidget(
        chapter: ChapterData(
            element: OutlineElement(
                id: "chapter-synthetic",
                index: 0,
                level: 2,
                range: [0, 0],
                rawString: "",
                string: "(Untitled Section)",
                type: "sectionHeader",
                isSynthetic: true
            ),
            sceneGroups: [
                SceneGroupData(
                    element: OutlineElement(
                        id: "group-1",
                        index: 1,
                        level: 3,
                        range: [10, 100],
                        rawString: "### SCENE GROUP",
                        string: "SCENE GROUP",
                        type: "sectionHeader"
                    ),
                    scenes: []
                )
            ]
        ),
        isExpanded: .constant(true),
        expandedSceneGroups: .constant([]),
        expandedScenes: .constant([]),
        expandedPreScenes: .constant([])
    )
    .padding()
}
