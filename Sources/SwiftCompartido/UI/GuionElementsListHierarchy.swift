//
//  GuionElementsListHierarchy.swift
//  SwiftCompartido
//
//  Hierarchical disclosure group support for GuionElementsList
//

import SwiftUI
import SwiftData

// MARK: - Hierarchy Node

/// Represents a node in the hierarchical element tree
public struct HierarchyNode: Identifiable, Sendable {
    public let id: PersistentIdentifier
    public let elementType: ElementType
    public let elementText: String
    public let children: [HierarchyNode]
    public let level: Int

    /// The title to display for this node
    public var title: String {
        return elementText
    }

    /// Whether this node should be displayed as a disclosure group
    public var isDisclosureGroup: Bool {
        switch elementType {
        case .sectionHeading(let sectionLevel) where sectionLevel <= 3:
            return true
        case .sceneHeading:
            return true
        default:
            return false
        }
    }
}

// MARK: - Hierarchy Builder

/// Mutable wrapper for building hierarchy nodes
private class MutableHierarchyNode {
    let id: PersistentIdentifier
    let elementType: ElementType
    let elementText: String
    var children: [MutableHierarchyNode] = []
    let level: Int

    init(id: PersistentIdentifier, elementType: ElementType, elementText: String, level: Int) {
        self.id = id
        self.elementType = elementType
        self.elementText = elementText
        self.level = level
    }

    func toImmutable() -> HierarchyNode {
        HierarchyNode(
            id: id,
            elementType: elementType,
            elementText: elementText,
            children: children.map { $0.toImmutable() },
            level: level
        )
    }
}

/// Builds a hierarchical tree from a flat list of elements
public final class HierarchyBuilder: @unchecked Sendable {

    /// Builds a hierarchical tree from elements with progress reporting
    ///
    /// - Parameters:
    ///   - elements: Flat list of elements in order
    ///   - spacingMap: Pre-computed spacing map for elements
    ///   - progress: Optional progress tracker for reporting build progress
    /// - Returns: Array of root-level hierarchy nodes
    public static func buildHierarchy(
        from elements: [GuionElementModel],
        spacingMap: [PersistentIdentifier: Bool],
        progress: OperationProgress? = nil
    ) -> [HierarchyNode] {
        guard !elements.isEmpty else { return [] }

        progress?.update(completedUnits: 0, description: "Building hierarchy...", force: true)

        var roots: [MutableHierarchyNode] = []
        var stack: [MutableHierarchyNode] = []

        for (index, element) in elements.enumerated() {
            // Report progress every 100 elements
            if index % 100 == 0 {
                let completed = Int64(index)
                progress?.update(
                    completedUnits: completed,
                    description: "Building hierarchy (\(index)/\(elements.count))..."
                )
            }

            let currentLevel = hierarchyLevel(for: element)

            // Create mutable node
            let node = MutableHierarchyNode(
                id: element.persistentModelID,
                elementType: element.elementType,
                elementText: element.elementText,
                level: currentLevel
            )

            // Pop stack until we find a valid parent (level < current)
            while !stack.isEmpty && stack.last!.level >= currentLevel {
                stack.removeLast()
            }

            // Add to parent's children or to roots
            if let parent = stack.last {
                parent.children.append(node)
            } else {
                roots.append(node)
            }

            // Only push disclosure-eligible nodes to stack
            if shouldPushToStack(element: element, level: currentLevel) {
                stack.append(node)
            }
        }

        progress?.complete(description: "Hierarchy built (\(elements.count) elements)")

        return roots.map { $0.toImmutable() }
    }

    /// Determines the hierarchy level for an element
    ///
    /// - Level 1: # (sectionHeading level 1)
    /// - Level 2: ## (sectionHeading level 2)
    /// - Level 3: ### (sectionHeading level 3)
    /// - Level 4: Scene headings
    /// - Level 5: Other elements (nested under scenes)
    private static func hierarchyLevel(for element: GuionElementModel) -> Int {
        switch element.elementType {
        case .sectionHeading(let level):
            return level // 1, 2, 3, 4, 5, 6
        case .sceneHeading:
            return 4
        default:
            return 5 // Content elements go under scenes
        }
    }

    /// Determines if an element should be pushed to the stack (can have children)
    private static func shouldPushToStack(element: GuionElementModel, level: Int) -> Bool {
        switch element.elementType {
        case .sectionHeading(let sectionLevel) where sectionLevel <= 3:
            return true
        case .sceneHeading:
            return true
        default:
            return false
        }
    }
}

// MARK: - Hierarchy Section View

/// Recursive view for rendering hierarchical sections with disclosure groups
struct HierarchySection<TrailingContent: View>: View {
    let node: HierarchyNode
    let elements: [GuionElementModel]
    let spacingMap: [PersistentIdentifier: Bool]
    let fontSize: CGFloat
    let trailingContent: ((GuionElementModel) -> TrailingContent)?
    @Binding var disclosureStates: [PersistentIdentifier: Bool]

    private var isExpanded: Bool {
        disclosureStates[node.id] ?? false
    }

    /// Find the element by ID from the flat list
    private var element: GuionElementModel? {
        elements.first { $0.persistentModelID == node.id }
    }

    var body: some View {
        if let element = element {
            if node.isDisclosureGroup {
                // Render as disclosure group
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { isExpanded },
                        set: { disclosureStates[node.id] = $0 }
                    )
                ) {
                    // Render children
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        ForEach(node.children) { childNode in
                            HierarchySection(
                                node: childNode,
                                elements: elements,
                                spacingMap: spacingMap,
                                fontSize: fontSize,
                                trailingContent: trailingContent,
                                disclosureStates: $disclosureStates
                            )
                        }
                    }
                } label: {
                    // Section heading or scene heading
                    ElementRowContainer(
                        element: element,
                        needsSpacing: spacingMap[node.id] == true,
                        fontSize: fontSize,
                        trailingContent: trailingContent
                    )
                }
                .id(node.id)
            } else {
                // Render as regular element
                VStack(spacing: 0) {
                    ElementRowContainer(
                        element: element,
                        needsSpacing: spacingMap[node.id] == true,
                        fontSize: fontSize,
                        trailingContent: trailingContent
                    )
                    .id(node.id)

                    // Render children if any
                    if !node.children.isEmpty {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(node.children) { childNode in
                                HierarchySection(
                                    node: childNode,
                                    elements: elements,
                                    spacingMap: spacingMap,
                                    fontSize: fontSize,
                                    trailingContent: trailingContent,
                                    disclosureStates: $disclosureStates
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

extension HierarchyNode: Hashable {
    public static func == (lhs: HierarchyNode, rhs: HierarchyNode) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
