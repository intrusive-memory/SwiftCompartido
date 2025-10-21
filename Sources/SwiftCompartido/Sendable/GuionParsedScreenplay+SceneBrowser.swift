//
//  FountainScript+SceneBrowser.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//
//  Extension to extract hierarchical scene browser data from GuionParsedElementCollection
//

import Foundation

extension GuionParsedElementCollection {
    /// Extract hierarchical scene browser data
    ///
    /// This method builds a hierarchical structure from the outline:
    /// - Title (Level 1) → Chapters (Level 2) → Scene Groups (Level 3) → Scenes
    /// - Detects and attaches OVER BLACK content as preScene elements
    /// - Uses existing outline infrastructure for hierarchy
    ///
    /// If no chapters exist, creates a synthetic chapter containing all content.
    /// If no outline elements exist, creates scenes from all scene headers.
    ///
    /// - Returns: SceneBrowserData containing the complete hierarchy
    public func extractSceneBrowserData() -> SceneBrowserData {
        let outline = extractOutline()

        // Find the root/title element (Level 1)
        var title = outline.first { $0.isMainTitle }

        // If no level 1 title, create synthetic one from screenplay title
        if title == nil {
            var titleText = "Untitled"

            // Extract title from title page
            for titlePageSection in titlePage {
                if let titleArray = titlePageSection["Title"] ?? titlePageSection["title"] {
                    if let firstTitle = titleArray.first, !firstTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        titleText = firstTitle.trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            }

            title = OutlineElement(
                id: "synthetic-title",
                index: -1,
                level: 1,
                range: [0, 0],
                rawString: "# \(titleText)",
                string: titleText,
                type: "sectionHeader",
                isSynthetic: true
            )
        }

        // Find all chapters (Level 2 elements)
        let chapterElements = outline.filter { $0.isChapter }

        // Build chapter data
        let chapters: [ChapterData]

        if chapterElements.isEmpty {
            // No chapters found - create synthetic hierarchy
            chapters = buildSyntheticHierarchy(outline: outline, titleId: title!.id)
        } else {
            // Build chapter data with scene groups and scenes
            chapters = chapterElements.map { chapterElement in
                buildChapterData(chapter: chapterElement, outline: outline)
            }
        }

        return SceneBrowserData(title: title, chapters: chapters)
    }

    /// Build synthetic hierarchy when outline structure is missing
    /// Creates Level 2 "Scenes" and Level 3 "Main" elements as needed
    private func buildSyntheticHierarchy(outline: OutlineList, titleId: String) -> [ChapterData] {
        // Find all scene groups (Level 3) - these may exist even without chapters
        var sceneGroupElements = outline.filter { $0.level == 3 && $0.type == "sectionHeader" }

        // Find all scenes
        let allScenes = outline.filter { $0.type == "sceneHeader" }

        if allScenes.isEmpty {
            // No scenes at all - return empty
            return []
        }

        // If no level 3 scene groups exist, create synthetic "Main"
        if sceneGroupElements.isEmpty {
            let syntheticMainGroup = OutlineElement(
                id: "synthetic-main",
                index: -3,
                level: 3,
                range: [0, 0],
                rawString: "### Main",
                string: "Main",
                type: "sectionHeader",
                parentId: "synthetic-scenes",
                isSynthetic: true
            )
            sceneGroupElements = [syntheticMainGroup]
        }

        // Build scene groups with collected scenes
        let sceneGroups = sceneGroupElements.map { sceneGroupElement in
            // If this is the synthetic main group, assign all scenes to it
            if sceneGroupElement.isSynthetic {
                return SceneGroupData(
                    element: sceneGroupElement,
                    scenes: buildScenesWithOverBlack(sceneElements: allScenes, outline: outline)
                )
            } else {
                return buildSceneGroupData(sceneGroup: sceneGroupElement, outline: outline)
            }
        }

        // Create synthetic "Scenes" chapter (Level 2)
        let syntheticScenesChapter = OutlineElement(
            id: "synthetic-scenes",
            index: -2,
            level: 2,
            range: [0, 0],
            rawString: "## Scenes",
            string: "Scenes",
            type: "sectionHeader",
            parentId: titleId,
            isSynthetic: true
        )

        let chapterData = ChapterData(
            element: syntheticScenesChapter,
            sceneGroups: sceneGroups
        )

        return [chapterData]
    }

    /// Build chapter data with its scene groups
    private func buildChapterData(chapter: OutlineElement, outline: OutlineList) -> ChapterData {
        // Find scene groups (Level 3) that are children of this chapter
        let sceneGroupElements = outline.filter { element in
            element.level == 3 && element.parentId == chapter.id
        }

        // Build scene group data
        let sceneGroups = sceneGroupElements.map { sceneGroupElement in
            buildSceneGroupData(sceneGroup: sceneGroupElement, outline: outline)
        }

        return ChapterData(element: chapter, sceneGroups: sceneGroups)
    }

    /// Build scene group data with its scenes
    private func buildSceneGroupData(sceneGroup: OutlineElement, outline: OutlineList) -> SceneGroupData {
        // Find ALL scene headers that are descendants of this scene group
        // This handles the case where scenes might have been incorrectly nested
        var sceneElements: [OutlineElement] = []

        // Start with direct children
        let directChildren = outline.filter { element in
            element.type == "sceneHeader" && element.parentId == sceneGroup.id
        }

        // For each direct child scene, also collect any scenes that mistakenly have it as a parent
        for directScene in directChildren {
            sceneElements.append(directScene)

            // Find any scenes that were incorrectly nested under this scene
            let nestedScenes = collectNestedScenes(under: directScene, in: outline)
            sceneElements.append(contentsOf: nestedScenes)
        }

        // If no direct children but the scene group itself is a scene header, use it
        if sceneElements.isEmpty && sceneGroup.type == "sceneHeader" {
            sceneElements = [sceneGroup]
        }

        // Build scene data with OVER BLACK detection
        let scenes = buildScenesWithOverBlack(sceneElements: sceneElements, outline: outline)

        return SceneGroupData(element: sceneGroup, scenes: scenes)
    }

    /// Recursively collect scenes that were nested under another scene
    private func collectNestedScenes(under parent: OutlineElement, in outline: OutlineList) -> [OutlineElement] {
        var result: [OutlineElement] = []

        let children = outline.filter { element in
            element.type == "sceneHeader" && element.parentId == parent.id
        }

        for child in children {
            result.append(child)
            // Recursively collect any further nested scenes
            result.append(contentsOf: collectNestedScenes(under: child, in: outline))
        }

        return result
    }

    /// Build scene data with OVER BLACK detection and attachment
    private func buildScenesWithOverBlack(sceneElements: [OutlineElement], outline: OutlineList) -> [SceneData] {
        var result: [SceneData] = []
        var pendingOverBlack: [GuionElement]?

        for sceneElement in sceneElements {
            // Extract actual scene elements with proper types
            let sceneGuionElements = extractSceneElements(for: sceneElement)

            // Check if this is an OVER BLACK scene
            if isOverBlackScene(sceneElement) {
                // Store OVER BLACK content to attach to next scene
                pendingOverBlack = sceneGuionElements
                continue
            }

            // Parse scene location
            let location = SceneLocation.parse(sceneElement.string)

            // Note: Summary is accessed from GuionElement directly via model in SwiftData mode
            // Value-based SceneData reads from element's summary property

            // Create scene data
            let sceneData = SceneData(
                element: sceneElement,
                sceneElements: sceneGuionElements,
                preSceneElements: pendingOverBlack,
                sceneLocation: location
            )

            result.append(sceneData)

            // Clear pending OVER BLACK after attaching
            pendingOverBlack = nil
        }

        // If there's remaining OVER BLACK at the end, create a standalone scene for it
        if let overBlack = pendingOverBlack, !overBlack.isEmpty {
            // This is an edge case: OVER BLACK at the end with no following scene
            // We'll ignore it or could create a special end marker
        }

        return result
    }

    /// Check if a scene element is an OVER BLACK scene
    private func isOverBlackScene(_ element: OutlineElement) -> Bool {
        return element.string.uppercased().contains("OVER BLACK")
    }

    /// Extract actual scene elements directly from the screenplay
    private func extractSceneElements(for sceneElement: OutlineElement) -> [GuionElement] {
        // Try sceneId-based extraction first (preferred method)
        if let sceneId = sceneElement.sceneId {
            var sceneElements: [GuionElement] = []
            var inScene = false

            for element in elements {
                // Check if this element starts the scene (by matching sceneId)
                if element.elementType == .sceneHeading && element.sceneId == sceneId {
                    inScene = true
                    continue // Skip the scene heading itself (it's already in the outline)
                }

                // Check if we've reached the next scene (any scene heading after we've started)
                if inScene && element.elementType == .sceneHeading {
                    break
                }

                // Collect all elements between this scene heading and the next
                // Note: Only scene headings have sceneIds; dialogue, action, etc. do not
                if inScene {
                    sceneElements.append(element)
                }
            }

            return sceneElements
        }

        // Fallback: Use text-based parsing when sceneId is not available
        // This handles synthetic scenes, manually constructed outlines, or imported data without UUIDs
        return extractSceneElementsByRange(for: sceneElement)
    }

    /// Extract scene elements by matching text (fallback for scenes without sceneId)
    private func extractSceneElementsByRange(for sceneElement: OutlineElement) -> [GuionElement] {
        var sceneElements: [GuionElement] = []
        var foundSceneHeading = false

        // Normalize the scene heading text for comparison
        let targetText = sceneElement.string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find the scene heading by matching text and collect elements after it
        for element in elements {
            // Check if this is our scene heading
            if !foundSceneHeading {
                if element.elementType == .sceneHeading {
                    let elementText = element.elementText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if elementText == targetText {
                        foundSceneHeading = true
                        continue // Skip the scene heading itself
                    }
                }
                continue
            }

            // Once we've found our scene, collect elements until the next scene heading
            if element.elementType == .sceneHeading {
                break
            }

            sceneElements.append(element)
        }

        return sceneElements
    }

    /// Parse scene content text into GuionElements (legacy fallback)
    private func parseSceneContent(sceneText: String) -> [GuionElement] {
        // The sceneText already includes all elements from the scene
        // We need to parse it back into GuionElements
        // For now, we'll create a simple action element
        // This could be enhanced to properly parse the content

        guard !sceneText.isEmpty else { return [] }

        // Split by double newlines to get separate elements
        let parts = sceneText.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Skip the first part if it's the scene heading
        let contentParts = parts.dropFirst()

        if contentParts.isEmpty {
            return []
        }

        // Convert parts to GuionElements
        // This is a simplified approach - ideally we'd re-parse properly
        return contentParts.map { part in
            GuionElement(elementType: .action, elementText: part)
        }
    }
}

// MARK: - Helper Extensions

extension OutlineElement {
    /// Check if this element represents a scene directive (Level 3 with metadata)
    var hasDirective: Bool {
        return level == 3 && sceneDirective != nil
    }
}
