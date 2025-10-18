//
//  GuionElement.swift
//  SwiftGuion
//
//  Copyright (c) 2012-2013 Nima Yousefi & John August
//  Swift conversion (c) 2025
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

/// Protocol defining the core properties of a screenplay element.
///
/// This protocol defines the fundamental properties that all screenplay elements must have,
/// regardless of their storage mechanism (in-memory, SwiftData, etc.).
///
/// ## Overview
///
/// Screenplay elements represent the building blocks of a script, including:
/// - Scene headings (sluglines)
/// - Action lines
/// - Character names
/// - Dialogue
/// - Parentheticals
/// - Transitions
/// - And more
///
/// ## Conforming Types
///
/// - ``GuionElement``: Lightweight struct for in-memory representation
/// - ``GuionElementModel``: SwiftData model for persistent storage
///
/// ## Topics
///
/// ### Element Properties
/// - ``elementType``
/// - ``elementText``
///
/// ### Formatting
/// - ``isCentered``
/// - ``isDualDialogue``
///
/// ### Scene Information
/// - ``sceneNumber``
/// - ``sectionDepth``
/// - ``sceneId``
public protocol GuionElementProtocol {
    /// The type of screenplay element.
    ///
    /// Uses a strongly-typed enum for compile-time safety and pattern matching.
    ///
    /// Common element types include:
    /// - ``ElementType/sceneHeading``: INT. LOCATION - DAY
    /// - ``ElementType/action``: Narrative description
    /// - ``ElementType/character``: Character name
    /// - ``ElementType/dialogue``: Character speech
    /// - ``ElementType/parenthetical``: (action while speaking)
    /// - ``ElementType/transition``: FADE TO:
    /// - ``ElementType/sectionHeading(level:)``: # Act One
    var elementType: ElementType { get set }

    /// The actual text content of the element.
    var elementText: String { get set }

    /// Whether this element should be centered on the page.
    ///
    /// Centered elements are typically used for titles or special formatting.
    var isCentered: Bool { get set }

    /// Whether this element is part of dual dialogue.
    ///
    /// Dual dialogue allows two characters to speak simultaneously,
    /// displayed in side-by-side columns.
    var isDualDialogue: Bool { get set }

    /// The scene number, if this is a scene heading.
    ///
    /// Scene numbers can be automatic (1, 2, 3...) or custom (#123A#).
    var sceneNumber: String? { get set }

    /// The depth level for section headings.
    ///
    /// Section headings use `#` characters to indicate hierarchy:
    /// - `# Act One` = depth 1
    /// - `## Scene 1` = depth 2
    /// - `### Beat` = depth 3
    var sectionDepth: Int { get set }

    /// Unique identifier for the scene, used to correlate elements across parsing.
    ///
    /// This UUID helps track scenes even when their text changes or when
    /// multiple scenes have identical headings.
    var sceneId: String? { get set }

    /// AI-generated summary of the scene content (for Scene Heading elements).
    ///
    /// This field contains a concise summary of what happens in the scene,
    /// generated using Apple Intelligence or extractive summarization.
    /// Only populated for Scene Heading elements when summarization is enabled.
    var summary: String? { get set }
}

/// Lightweight struct representing a screenplay element.
///
/// This struct provides an efficient, value-type representation of screenplay elements
/// suitable for parsing, in-memory manipulation, and export operations.
///
/// ## Overview
///
/// `GuionElement` is the primary type used by ``GuionParsedScreenplay`` for parsing and
/// storing screenplay elements. It can be easily converted to ``GuionElementModel``
/// for persistent storage via SwiftData.
///
/// ## Example
///
/// ```swift
/// // Create a scene heading
/// let sceneHeading = GuionElement(
///     elementType: "Scene Heading",
///     elementText: "INT. COFFEE SHOP - DAY"
/// )
///
/// // Create dialogue
/// var character = GuionElement(elementType: "Character", elementText: "JOHN")
/// var dialogue = GuionElement(elementType: "Dialogue", elementText: "Hello, world!")
/// ```
///
/// ## Topics
///
/// ### Creating Elements
/// - ``init(elementType:elementText:)``
/// - ``init(type:text:)``
/// - ``init(from:)``
///
/// ### Element Properties
/// - ``elementType``
/// - ``elementText``
/// - ``isCentered``
/// - ``isDualDialogue``
/// - ``sceneNumber``
/// - ``sectionDepth``
/// - ``sceneId``
public struct GuionElement: GuionElementProtocol {
    public var elementType: ElementType
    public var elementText: String
    public var isCentered: Bool
    public var isDualDialogue: Bool
    public var sceneNumber: String?

    /// The depth level for section headings.
    ///
    /// **Deprecated**: Use `elementType.level` instead. This property is maintained
    /// for backward compatibility but will be removed in a future version.
    ///
    /// Section headings use `#` characters to indicate hierarchy:
    /// - `# Act One` = depth 1
    /// - `## Scene 1` = depth 2
    /// - `### Beat` = depth 3
    @available(*, deprecated, message: "Use elementType.level instead")
    public var sectionDepth: Int {
        get {
            return elementType.level
        }
        set {
            // If setting a new depth on a section heading, update the enum
            if case .sectionHeading = elementType {
                elementType = .sectionHeading(level: newValue)
            }
        }
    }

    public var sceneId: String?
    public var summary: String?

    /// Creates a new screenplay element with the specified type and text.
    ///
    /// - Parameters:
    ///   - elementType: The type of element (default: `.action`)
    ///   - elementText: The text content (default: empty string)
    ///
    /// - Returns: A new `GuionElement` with default formatting properties
    ///
    /// ## Example
    /// ```swift
    /// let action = GuionElement(
    ///     elementType: .action,
    ///     elementText: "The door swings open."
    /// )
    /// ```
    public init(elementType: ElementType = .action, elementText: String = "") {
        self.elementType = elementType
        self.elementText = elementText
        self.isCentered = false
        self.sceneNumber = nil
        self.isDualDialogue = false
        self.sceneId = nil
        self.summary = nil
    }

    /// Creates a new screenplay element with the specified type and text.
    ///
    /// This is a convenience initializer with shorter parameter names.
    ///
    /// - Parameters:
    ///   - type: The type of element
    ///   - text: The text content
    public init(type: ElementType, text: String) {
        self.init(elementType: type, elementText: text)
    }

    /// Initialize from any `GuionElementProtocol` conforming type.
    ///
    /// This initializer allows conversion between different implementations
    /// of screenplay elements (e.g., from ``GuionElementModel`` to ``GuionElement``).
    ///
    /// - Parameter element: Any type conforming to `GuionElementProtocol`
    ///
    /// ## Example
    /// ```swift
    /// let model: GuionElementModel = // ... from SwiftData
    /// let element = GuionElement(from: model)
    /// ```
    public init<T: GuionElementProtocol>(from element: T) {
        // Handle section depth from deprecated property by updating element type if needed
        var elementType = element.elementType
        if case .sectionHeading = elementType {
            // Element type already has the correct level
        } else if elementType.isSectionHeading {
            // Should not happen, but handle it anyway
            elementType = .sectionHeading(level: element.elementType.level)
        }

        self.elementType = elementType
        self.elementText = element.elementText
        self.isCentered = element.isCentered
        self.isDualDialogue = element.isDualDialogue
        self.sceneNumber = element.sceneNumber
        self.sceneId = element.sceneId
        self.summary = element.summary
    }
}

extension GuionElement: Sendable {}

extension GuionElement: CustomStringConvertible {
    public var description: String {
        var typeOutput = elementType.description

        if isCentered {
            typeOutput += " (centered)"
        } else if isDualDialogue {
            typeOutput += " (dual dialogue)"
        } else if elementType.level > 0 {
            typeOutput += " (\(elementType.level))"
        }

        return "\(typeOutput): \(elementText)"
    }
}

// MARK: - Protocol Extensions
extension GuionElementProtocol {
    public var description: String {
        var typeOutput = elementType.description

        if isCentered {
            typeOutput += " (centered)"
        } else if isDualDialogue {
            typeOutput += " (dual dialogue)"
        } else if elementType.level > 0 {
            typeOutput += " (\(elementType.level))"
        }

        return "\(typeOutput): \(elementText)"
    }
}
