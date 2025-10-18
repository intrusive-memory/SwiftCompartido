//
//  ElementType.swift
//  SwiftGuion
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

/// Strongly-typed enumeration representing screenplay element types.
///
/// This enum provides type-safe representation of all Fountain screenplay elements,
/// replacing the previous string-based approach for improved compile-time safety
/// and better pattern matching support.
///
/// ## Overview
///
/// Element types represent the building blocks of a screenplay:
/// - **Scene Elements**: Scene headings that define locations and time
/// - **Action Elements**: Narrative description and action
/// - **Dialogue Elements**: Character names, dialogue, and parentheticals
/// - **Structural Elements**: Transitions, section headings, and page breaks
/// - **Metadata Elements**: Comments, synopses, and boneyard (omitted content)
///
/// ## Outline Support
///
/// Per the Fountain.io specification, section headings support hierarchical outlines:
/// - Level 1 (`#`): Title/Script name
/// - Level 2 (`##`): Act
/// - Level 3 (`###`): Sequence
/// - Level 4 (`####`): Scene group
/// - Level 5 (`#####`): Sub-scene
/// - Level 6 (`######`): Beat
///
/// Outline summaries are represented by ``synopsis`` and are denoted in Fountain
/// with a single equals sign (`=`).
///
/// ## Example
///
/// ```swift
/// // Create element types
/// let scene = ElementType.sceneHeading
/// let act = ElementType.sectionHeading(level: 2)
/// let dialogue = ElementType.dialogue
///
/// // Pattern matching
/// switch element.elementType {
/// case .sceneHeading:
///     print("New scene")
/// case .sectionHeading(let level):
///     print("Section at level \(level)")
/// case .dialogue:
///     print("Character speaking")
/// default:
///     break
/// }
/// ```
///
/// ## Topics
///
/// ### Element Cases
/// - ``sceneHeading``
/// - ``action``
/// - ``character``
/// - ``dialogue``
/// - ``parenthetical``
/// - ``transition``
/// - ``sectionHeading(level:)``
/// - ``synopsis``
/// - ``comment``
/// - ``boneyard``
/// - ``lyrics``
/// - ``pageBreak``
///
/// ### Initialization
/// - ``init(string:)``
///
/// ### Properties
/// - ``level``
/// - ``isSectionHeading``
/// - ``isDialogueRelated``
///
public enum ElementType: Equatable, Sendable, Hashable {
    /// Scene heading element (slugline).
    ///
    /// Examples: `INT. OFFICE - DAY`, `EXT. PARK - NIGHT`
    case sceneHeading

    /// Action or narrative description.
    ///
    /// Action elements describe what happens on screen.
    case action

    /// Character name.
    ///
    /// Appears above dialogue to indicate who is speaking.
    case character

    /// Dialogue text.
    ///
    /// The words spoken by a character.
    case dialogue

    /// Parenthetical direction within dialogue.
    ///
    /// Brief action or tone indicators within character speech.
    /// Example: `(laughing)`
    case parenthetical

    /// Transition between scenes.
    ///
    /// Examples: `CUT TO:`, `FADE OUT.`, `DISSOLVE TO:`
    case transition

    /// Section heading for screenplay outline structure.
    ///
    /// Supports hierarchical organization with levels 1-6.
    /// The level corresponds to the number of `#` characters in Fountain format.
    ///
    /// - Parameter level: The hierarchy level (1-6)
    ///   - 1: Title/Script name
    ///   - 2: Act
    ///   - 3: Sequence
    ///   - 4: Scene group
    ///   - 5: Sub-scene
    ///   - 6: Beat
    case sectionHeading(level: Int)

    /// Synopsis or outline summary.
    ///
    /// Brief description of a scene or section, denoted in Fountain with `=`.
    /// Also known as "Outline Summary" in Fountain specification.
    case synopsis

    /// Inline comment.
    ///
    /// Notes that appear in the source but not in formatted output.
    /// Denoted with `[[ comment text ]]` in Fountain.
    case comment

    /// Boneyard (omitted content).
    ///
    /// Content that has been commented out using `/* ... */` block syntax.
    /// Useful for keeping old versions or notes without deleting them.
    case boneyard

    /// Lyrics.
    ///
    /// Song lyrics or sung dialogue, denoted with `~` in Fountain.
    case lyrics

    /// Page break.
    ///
    /// Forces a page break at this point, denoted with `===` in Fountain.
    case pageBreak
}

// MARK: - String Conversion

extension ElementType: CustomStringConvertible {
    /// String representation of the element type.
    ///
    /// Provides the canonical name for each element type, matching the
    /// previous string-based representation for backward compatibility.
    public var description: String {
        switch self {
        case .sceneHeading:
            return "Scene Heading"
        case .action:
            return "Action"
        case .character:
            return "Character"
        case .dialogue:
            return "Dialogue"
        case .parenthetical:
            return "Parenthetical"
        case .transition:
            return "Transition"
        case .sectionHeading:
            return "Section Heading"
        case .synopsis:
            return "Synopsis"
        case .comment:
            return "Comment"
        case .boneyard:
            return "Boneyard"
        case .lyrics:
            return "Lyrics"
        case .pageBreak:
            return "Page Break"
        }
    }
}

extension ElementType {
    /// Initialize an ElementType from a string representation.
    ///
    /// This initializer provides backward compatibility with the previous
    /// string-based element type system. It's used primarily during parsing
    /// and deserialization.
    ///
    /// - Parameter string: The string representation of the element type
    /// - Returns: The corresponding ElementType case, or `.action` as a fallback
    ///
    /// ## Example
    ///
    /// ```swift
    /// let type = ElementType(string: "Scene Heading")
    /// // type == .sceneHeading
    ///
    /// let invalid = ElementType(string: "Unknown")
    /// // invalid == .action (fallback)
    /// ```
    public init(string: String) {
        switch string {
        case "Scene Heading":
            self = .sceneHeading
        case "Action":
            self = .action
        case "Character":
            self = .character
        case "Dialogue":
            self = .dialogue
        case "Parenthetical":
            self = .parenthetical
        case "Transition":
            self = .transition
        case "Section Heading":
            self = .sectionHeading(level: 1)
        case "Synopsis":
            self = .synopsis
        case "Comment":
            self = .comment
        case "Boneyard":
            self = .boneyard
        case "Lyrics":
            self = .lyrics
        case "Page Break":
            self = .pageBreak
        default:
            // Default to action for unknown types
            self = .action
        }
    }
}

// MARK: - Properties

extension ElementType {
    /// The hierarchical level for section headings.
    ///
    /// Returns the level value for `.sectionHeading(level:)` cases,
    /// or 0 for all other element types.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let act = ElementType.sectionHeading(level: 2)
    /// print(act.level) // 2
    ///
    /// let dialogue = ElementType.dialogue
    /// print(dialogue.level) // 0
    /// ```
    public var level: Int {
        if case .sectionHeading(let level) = self {
            return level
        }
        return 0
    }

    /// Whether this element type is a section heading.
    ///
    /// Returns `true` for `.sectionHeading(level:)` cases, `false` otherwise.
    public var isSectionHeading: Bool {
        if case .sectionHeading = self {
            return true
        }
        return false
    }

    /// Whether this element type is related to dialogue.
    ///
    /// Returns `true` for character, dialogue, and parenthetical elements.
    /// These elements typically appear together in dialogue blocks.
    public var isDialogueRelated: Bool {
        switch self {
        case .character, .dialogue, .parenthetical:
            return true
        default:
            return false
        }
    }
}

// MARK: - Codable

extension ElementType: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case level
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)

        if typeString == "Section Heading" {
            let level = try container.decode(Int.self, forKey: .level)
            self = .sectionHeading(level: level)
        } else {
            self = ElementType(string: typeString)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .type)

        if case .sectionHeading(let level) = self {
            try container.encode(level, forKey: .level)
        }
    }
}
