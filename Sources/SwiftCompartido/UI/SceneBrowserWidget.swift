//
//  SceneBrowserWidget.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//
//  Main scene browser container displaying hierarchical outline structure
//

import SwiftUI

/// Main scene browser widget displaying the hierarchical outline structure of a screenplay
public struct SceneBrowserWidget: View {
    let browserData: SceneBrowserData
    let autoExpand: Bool

    @State private var expandedChapters: Set<String> = []
    @State private var expandedSceneGroups: Set<String> = []
    @State private var expandedScenes: Set<String> = []
    @State private var expandedPreScenes: Set<String> = []
    @State private var currentFontSize: CGFloat = 12
    @State private var lastWidth: CGFloat = 0

    /// Creates a SceneBrowserWidget from SceneBrowserData
    /// - Parameters:
    ///   - browserData: The scene browser data containing the screenplay structure
    ///   - autoExpand: If true, automatically expands first two levels (chapters and scene groups) on load. Default is true.
    public init(browserData: SceneBrowserData, autoExpand: Bool = true) {
        self.browserData = browserData
        self.autoExpand = autoExpand
    }

    /// Creates a SceneBrowserWidget directly from a GuionParsedScreenplay
    /// - Parameters:
    ///   - script: The GuionParsedScreenplay to extract browser data from
    ///   - autoExpand: If true, automatically expands first two levels (chapters and scene groups) on load. Default is true.
    public init(script: GuionParsedScreenplay, autoExpand: Bool = true) {
        self.browserData = script.extractSceneBrowserData()
        self.autoExpand = autoExpand
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // Title header (Level 1 - always visible)
                if let title = browserData.title {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            if title.isSynthetic {
                                Text("INFERRED:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                            }
                            Text(title.string)
                                .font(.largeTitle)
                                .bold()
                                .foregroundStyle(title.isSynthetic ? .secondary : .primary)
                        }
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel("Script title: \(title.string)")

                        Divider()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }

                // Scrollable chapter list or empty state
                if browserData.chapters.isEmpty {
                    EmptyBrowserView()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(browserData.chapters) { chapter in
                                ChapterWidget(
                                    chapter: chapter,
                                    isExpanded: Binding(
                                        get: { expandedChapters.contains(chapter.id) },
                                        set: { isExpanded in
                                            if isExpanded {
                                                expandedChapters.insert(chapter.id)
                                            } else {
                                                expandedChapters.remove(chapter.id)
                                            }
                                        }
                                    ),
                                    expandedSceneGroups: $expandedSceneGroups,
                                    expandedScenes: $expandedScenes,
                                    expandedPreScenes: $expandedPreScenes
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .accessibilityLabel("Scene browser")
                    .accessibilityHint("\(browserData.chapters.count) chapters")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .environment(\.screenplayFontSize, currentFontSize)
            .accessibilityElement(children: .contain)
            .onAppear {
                if autoExpand {
                    expandFirstTwoLevels()
                }
                // Calculate initial font size
                updateFontSize(for: geometry.size.width)
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                // Recalculate font size when window width changes
                updateFontSize(for: newWidth)
            }
        }
    }

    /// Update font size based on available width
    private func updateFontSize(for width: CGFloat) {
        // Only recalculate if width changed significantly (more than 1 point)
        guard abs(width - lastWidth) > 1 else { return }

        lastWidth = width
        let newFontSize = ScreenplayPageFormat.calculateFontSize(forWidth: width)

        // Animate font size changes for smooth resizing
        withAnimation(.easeInOut(duration: 0.15)) {
            currentFontSize = newFontSize
        }
    }

    /// Automatically expands the first two levels (chapters and scene groups) to show the scene list
    private func expandFirstTwoLevels() {
        // Expand all chapters (Level 2)
        expandedChapters = Set(browserData.chapters.map { $0.id })

        // Expand all scene groups within chapters (Level 3)
        var sceneGroupIDs: Set<String> = []
        for chapter in browserData.chapters {
            for sceneGroup in chapter.sceneGroups {
                sceneGroupIDs.insert(sceneGroup.id)
            }
        }
        expandedSceneGroups = sceneGroupIDs
    }
}

// MARK: - Empty State View

/// View displayed when no chapters are found in the screenplay
public struct EmptyBrowserView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Chapters Found")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("This screenplay doesn't have chapter markers (##).")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No chapters found. This screenplay doesn't have chapter markers.")
    }
}

// MARK: - Previews

#Preview("Scene Browser - Simple") {
    SceneBrowserWidget(
        browserData: SceneBrowserData(
            title: OutlineElement(
                id: "title",
                index: 0,
                level: 1,
                range: [0, 10],
                rawString: "# Test Script",
                string: "Test Script",
                type: "sectionHeader"
            ),
            chapters: [
                ChapterData(
                    element: OutlineElement(
                        id: "chapter-1",
                        index: 1,
                        level: 2,
                        range: [10, 100],
                        rawString: "## CHAPTER 1",
                        string: "CHAPTER 1",
                        type: "sectionHeader"
                    ),
                    sceneGroups: [
                        SceneGroupData(
                            element: OutlineElement(
                                id: "group-1",
                                index: 2,
                                level: 3,
                                range: [20, 80],
                                rawString: "### PROLOGUE",
                                string: "PROLOGUE",
                                type: "sectionHeader"
                            ),
                            scenes: [
                                SceneData(
                                    element: OutlineElement(
                                        id: "scene-1",
                                        index: 3,
                                        level: 0,
                                        range: [30, 70],
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
                        )
                    ]
                )
            ]
        )
    )
    .frame(width: 400, height: 600)
}

#Preview("Scene Browser - Empty") {
    SceneBrowserWidget(
        browserData: SceneBrowserData(
            title: OutlineElement(
                id: "title",
                index: 0,
                level: 1,
                range: [0, 10],
                rawString: "# Untitled Script",
                string: "Untitled Script",
                type: "sectionHeader"
            ),
            chapters: []
        )
    )
    .frame(width: 400, height: 600)
}
