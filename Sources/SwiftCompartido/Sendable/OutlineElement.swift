//
//  OutlineElement.swift
//  SwiftFountain
//
//  Copyright (c) 2025
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

/// An element in the guión outline/structure
public struct OutlineElement: Codable {
    public var id: String
    public var index: Int
    public var isCollapsed: Bool
    public var level: Int
    public var range: [Int]
    public var rawString: String
    public var string: String
    public var type: String
    public var sceneDirective: String? // For level 3 headers, stores the directive name
    public var sceneDirectiveDescription: String? // For level 3 headers, stores the full description after the colon
    public var parentId: String? // ID of parent element in the hierarchy
    public var childIds: [String] // Array of child element IDs
    public var isEndMarker: Bool // True if this is an END chapter marker
    public var sceneId: String? // UUID linking to GuionElement.sceneId for Scene Heading elements
    public var isSynthetic: Bool // True if this element was synthetically generated (not in original screenplay)
    public var hasHierarchyError: Bool // True if this element has a hierarchy/formatting error

    public init(id: String = UUID().uuidString, index: Int, isCollapsed: Bool = false, level: Int, range: [Int], rawString: String, string: String, type: String, sceneDirective: String? = nil, sceneDirectiveDescription: String? = nil, parentId: String? = nil, childIds: [String] = [], isEndMarker: Bool = false, sceneId: String? = nil, isSynthetic: Bool = false, hasHierarchyError: Bool = false) {
        self.id = id
        self.index = index
        self.isCollapsed = isCollapsed
        self.level = level
        self.range = range
        self.rawString = rawString
        self.string = string
        self.type = type
        self.sceneDirective = sceneDirective
        self.sceneDirectiveDescription = sceneDirectiveDescription
        self.parentId = parentId
        self.childIds = childIds
        self.isEndMarker = isEndMarker
        self.sceneId = sceneId
        self.isSynthetic = isSynthetic
        self.hasHierarchyError = hasHierarchyError
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case index
        case isCollapsed
        case level
        case range
        case rawString
        case string
        case type
        case sceneDirective
        case sceneDirectiveDescription
        case parentId
        case childIds
        case isEndMarker
        case sceneId
        case isSynthetic
        case hasHierarchyError
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.index = try container.decodeIfPresent(Int.self, forKey: .index) ?? 0
        self.isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        self.level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 0
        self.range = try container.decodeIfPresent([Int].self, forKey: .range) ?? []
        self.rawString = try container.decodeIfPresent(String.self, forKey: .rawString) ?? ""
        self.string = try container.decodeIfPresent(String.self, forKey: .string) ?? ""
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.sceneDirective = try container.decodeIfPresent(String.self, forKey: .sceneDirective)
        self.sceneDirectiveDescription = try container.decodeIfPresent(String.self, forKey: .sceneDirectiveDescription)
        self.parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        self.childIds = try container.decodeIfPresent([String].self, forKey: .childIds) ?? []
        self.isEndMarker = try container.decodeIfPresent(Bool.self, forKey: .isEndMarker) ?? false
        self.sceneId = try container.decodeIfPresent(String.self, forKey: .sceneId)
        self.isSynthetic = try container.decodeIfPresent(Bool.self, forKey: .isSynthetic) ?? false
        self.hasHierarchyError = try container.decodeIfPresent(Bool.self, forKey: .hasHierarchyError) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Don't encode synthetic elements - they should be regenerated on load
        if isSynthetic {
            return
        }

        try container.encode(id, forKey: .id)
        try container.encode(index, forKey: .index)
        try container.encode(isCollapsed, forKey: .isCollapsed)
        try container.encode(level, forKey: .level)
        try container.encode(range, forKey: .range)
        try container.encode(rawString, forKey: .rawString)
        try container.encode(string, forKey: .string)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(sceneDirective, forKey: .sceneDirective)
        try container.encodeIfPresent(sceneDirectiveDescription, forKey: .sceneDirectiveDescription)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        if !childIds.isEmpty {
            try container.encode(childIds, forKey: .childIds)
        }
        if isEndMarker {
            try container.encode(isEndMarker, forKey: .isEndMarker)
        }
        try container.encodeIfPresent(sceneId, forKey: .sceneId)
        if hasHierarchyError {
            try container.encode(hasHierarchyError, forKey: .hasHierarchyError)
        }
    }
    
    /// Returns "outline" for API compatibility with GuionElement
    public var elementType: String {
        return "outline"
    }
    
    /// Returns true if this is a scene directive (level 3 section header)
    public var isSceneDirective: Bool {
        if level != 3 { return false }
        if type == "sectionHeader" { return true }
        return type == "sceneHeader" && sceneDirective != nil
    }
    
    /// Returns true if this is a chapter-level header (level 2)
    public var isChapter: Bool {
        guard level == 2 && type == "sectionHeader" && !isEndMarker else { return false }

        // Filter out technical directives (SHOT:, CUT TO:, etc.)
        let upperString = string.uppercased()
        let technicalDirectives = ["SHOT:", "CUT TO:", "FADE IN:", "FADE OUT:", "DISSOLVE TO:", "MATCH CUT:", "SMASH CUT:"]

        return !technicalDirectives.contains { upperString.hasPrefix($0) }
    }
    
    /// Returns true if this is the main title (level 1)
    public var isMainTitle: Bool {
        return level == 1 && type == "sectionHeader"
    }
    
    /// Get the parent element from the outline list
    /// - Parameter outline: The complete outline list
    /// - Returns: The parent OutlineElement, or nil if no parent exists
    public func parent(from outline: OutlineList) -> OutlineElement? {
        guard let parentId = parentId else { return nil }
        return outline.first { $0.id == parentId }
    }
    
    /// Get all direct children elements from the outline list
    /// - Parameter outline: The complete outline list
    /// - Returns: Array of child OutlineElements
    public func children(from outline: OutlineList) -> [OutlineElement] {
        return outline.filter { childIds.contains($0.id) }
    }
    
    /// Get all descendant elements (children, grandchildren, etc.) from the outline list
    /// - Parameter outline: The complete outline list
    /// - Returns: Array of all descendant OutlineElements
    public func descendants(from outline: OutlineList) -> [OutlineElement] {
        var descendants: [OutlineElement] = []
        let directChildren = children(from: outline)

        for child in directChildren {
            descendants.append(child)
            descendants.append(contentsOf: child.descendants(from: outline))
        }

        return descendants
    }

    /// Get the text of a scene as a single string
    ///
    /// This method extracts all the content of a scene from the guión, starting from the
    /// scene heading and continuing until the next scene heading or structural element.
    /// It returns the complete text including action, dialogue, parentheticals, and all other
    /// elements that belong to this scene.
    ///
    /// - Parameters:
    ///   - script: The GuionParsedElementCollection containing the elements
    ///   - outline: The complete outline list (optional, will be generated if not provided)
    /// - Returns: The complete text of the scene including the scene heading and all content.
    ///            For non-scene elements, returns the element's string property.
    ///
    /// - Example:
    /// ```swift
    /// let script = try GuionParsedElementCollection(string: fountainText)
    /// let outline = script.extractOutline()
    ///
    /// // Find a scene
    /// if let scene = outline.first(where: { $0.type == "sceneHeader" }) {
    ///     let text = scene.sceneText(from: script, outline: outline)
    ///     print(text)
    ///     // Output:
    ///     // INT. COFFEE SHOP - DAY
    ///     //
    ///     // JANE sits at a table, typing on her laptop.
    ///     //
    ///     // JOHN
    ///     // Hey, Jane!
    ///     //
    ///     // JANE
    ///     // (looking up)
    ///     // Oh, hi John!
    /// }
    /// ```
    public func sceneText(from script: GuionParsedElementCollection, outline: OutlineList? = nil) -> String {
        // Only works for scene headers
        guard type == "sceneHeader" else { return string }

        // Collect elements that belong to this scene
        var sceneElements: [String] = []

        // Add the scene heading
        sceneElements.append(string)

        // Now we need to get the actual guión elements between this scene and the next
        // We'll need to iterate through the GuionParsedElementCollection elements and find those that
        // correspond to this scene

        // Use sceneId for matching if available (preferred method for duplicate headings)
        var foundScene = false
        var currentSceneElements: [String] = []

        if let sceneId = self.sceneId {
            // UUID-based matching (handles duplicate headings correctly)
            for element in script.elements {
                // Check if this is our scene heading by UUID
                if element.elementType == .sceneHeading && element.sceneId == sceneId {
                    foundScene = true
                    continue // Skip the heading since we already added it
                }

                // If we found our scene, collect elements until the next scene
                if foundScene {
                    // Stop at the next scene heading
                    if element.elementType == .sceneHeading {
                        break
                    }

                    // Add the element text
                    currentSceneElements.append(element.elementText)
                }
            }
        } else {
            // Fallback to text-based matching for backwards compatibility
            // Note: This will fail for scripts with duplicate scene headings
            for element in script.elements {
                // Check if this is our scene heading by text
                if element.elementType == .sceneHeading &&
                   element.elementText.trimmingCharacters(in: .whitespaces) == self.string.trimmingCharacters(in: .whitespaces) {
                    foundScene = true
                    continue // Skip the heading since we already added it
                }

                // If we found our scene, collect elements until the next scene
                if foundScene {
                    // Stop at the next scene heading
                    if element.elementType == .sceneHeading {
                        break
                    }

                    // Add the element text
                    currentSceneElements.append(element.elementText)
                }
            }
        }

        // Combine all elements with appropriate spacing
        if !currentSceneElements.isEmpty {
            sceneElements.append(contentsOf: currentSceneElements)
        }

        return sceneElements.joined(separator: "\n\n")
    }
}

/// Collection of all outline elements
public typealias OutlineList = [OutlineElement]

/// Tree node representing an outline element with its children
public class OutlineTreeNode {
    public let element: OutlineElement
    public var children: [OutlineTreeNode] = []
    public weak var parent: OutlineTreeNode?
    
    public init(element: OutlineElement) {
        self.element = element
    }
    
    /// Add a child node
    public func addChild(_ child: OutlineTreeNode) {
        children.append(child)
        child.parent = self
    }
    
    /// Get all descendant nodes (children, grandchildren, etc.)
    public var descendants: [OutlineTreeNode] {
        var result: [OutlineTreeNode] = []
        for child in children {
            result.append(child)
            result.append(contentsOf: child.descendants)
        }
        return result
    }
    
    /// Check if this node has children
    public var hasChildren: Bool {
        return !children.isEmpty
    }
    
    /// Get the depth of this node in the tree (root = 0)
    public var depth: Int {
        var depth = 0
        var current = parent
        while current != nil {
            depth += 1
            current = current?.parent
        }
        return depth
    }
}

/// Tree structure for outline elements
public struct OutlineTree {
    public let root: OutlineTreeNode?
    private let nodeMap: [String: OutlineTreeNode]
    
    public init(from outline: OutlineList) {
        var nodeMap: [String: OutlineTreeNode] = [:]

        // Create nodes for all elements
        for element in outline {
            let node = OutlineTreeNode(element: element)
            nodeMap[element.id] = node
        }

        // Determine the root node preference order: explicit main title, otherwise top-level element
        let rootElement = outline.first(where: { $0.isMainTitle }) ?? outline.first(where: { !$0.isEndMarker && $0.parentId == nil }) ?? outline.first
        let rootNode = rootElement.flatMap { nodeMap[$0.id] }

        // Build the tree structure based on parent-child relationships
        for element in outline {
            guard let node = nodeMap[element.id] else { continue }

            if let parentId = element.parentId, let parentNode = nodeMap[parentId] {
                parentNode.addChild(node)
            } else if let rootNode, node !== rootNode, !element.isEndMarker, element.type != "blank" {
                // Attach orphaned elements (non-END) to the root to keep the tree contiguous
                rootNode.addChild(node)
            }
        }

        self.root = rootNode
        self.nodeMap = nodeMap
    }
    
    /// Find a node by element ID
    public func node(for elementId: String) -> OutlineTreeNode? {
        return nodeMap[elementId]
    }
    
    /// Get all nodes in the tree (flattened)
    public var allNodes: [OutlineTreeNode] {
        guard let root = root else { return [] }
        return [root] + root.descendants
    }
    
    /// Get all leaf nodes (nodes without children)
    public var leafNodes: [OutlineTreeNode] {
        return allNodes.filter { !$0.hasChildren }
    }
}

extension OutlineList {
    /// Create a tree structure from the outline list
    public func tree() -> OutlineTree {
        return OutlineTree(from: self)
    }
}

extension OutlineElement: Sendable {}
