//
//  SceneLocation.swift
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

/// Lighting/setting type for a scene heading.
///
/// Represents whether a scene takes place inside (interior), outside (exterior),
/// or a combination of both.
///
/// ## Overview
///
/// Scene headings in screenplays traditionally begin with a lighting indicator
/// that tells the reader where the action takes place. This enum captures all
/// standard and variant forms of these indicators.
///
/// ## Example
///
/// ```swift
/// let lighting = SceneLighting.interior
/// print(lighting.description) // "Interior"
/// print(lighting.standardAbbreviation) // "INT"
/// ```
///
/// ## Topics
///
/// ### Lighting Types
/// - ``interior``
/// - ``exterior``
/// - ``interiorExterior``
/// - ``interiorExteriorAlt``
/// - ``interiorExteriorShort``
/// - ``unknown``
///
/// ### Properties
/// - ``description``
/// - ``standardAbbreviation``
public enum SceneLighting: String, Codable, Sendable {
    case interior = "INT"
    case exterior = "EXT"
    case interiorExterior = "INT/EXT"
    case interiorExteriorAlt = "INT./EXT."
    case interiorExteriorShort = "I/E"
    case unknown = "UNKNOWN"

    /// Returns the full description
    public var description: String {
        switch self {
        case .interior: return "Interior"
        case .exterior: return "Exterior"
        case .interiorExterior, .interiorExteriorAlt, .interiorExteriorShort: return "Interior/Exterior"
        case .unknown: return "Unknown"
        }
    }

    /// Returns the standard abbreviation
    public var standardAbbreviation: String {
        switch self {
        case .interior: return "INT"
        case .exterior: return "EXT"
        case .interiorExterior, .interiorExteriorAlt, .interiorExteriorShort: return "INT/EXT"
        case .unknown: return ""
        }
    }
}

/// Parsed location information from a scene heading/slugline.
///
/// This structure breaks down a screenplay scene heading into its component parts,
/// making it easy to analyze, search, and organize scenes by location.
///
/// ## Overview
///
/// A typical scene heading like "INT. COFFEE SHOP - KITCHEN - DAY" contains:
/// - Lighting: INT (interior)
/// - Scene: COFFEE SHOP
/// - Setup: KITCHEN (optional sub-location)
/// - Time of Day: DAY
///
/// `SceneLocation` automatically parses these components from raw scene heading text.
///
/// ## Example
///
/// ```swift
/// let location = SceneLocation.parse("INT. COFFEE SHOP - KITCHEN - DAY")
/// print(location.lighting) // .interior
/// print(location.scene) // "COFFEE SHOP"
/// print(location.setup) // "KITCHEN"
/// print(location.timeOfDay) // "DAY"
/// print(location.fullLocation) // "COFFEE SHOP - KITCHEN"
/// ```
///
/// ## Topics
///
/// ### Parsing
/// - ``parse(_:)``
///
/// ### Location Components
/// - ``lighting``
/// - ``scene``
/// - ``setup``
/// - ``timeOfDay``
/// - ``modifiers``
/// - ``originalText``
///
/// ### Computed Properties
/// - ``fullLocation``
/// - ``locationKey``
///
/// ### Creating Locations
/// - ``init(lighting:scene:setup:timeOfDay:modifiers:originalText:)``
public struct SceneLocation: Codable, Sendable {
    /// The lighting/setting (INT, EXT, INT/EXT, etc.).
    public let lighting: SceneLighting

    /// The main scene location (e.g., "COFFEE SHOP", "WILL'S BEDROOM").
    public let scene: String

    /// Optional setup/modifier (e.g., "KITCHEN", "FRONT HALL").
    ///
    /// This represents a sub-location within the main scene, such as a specific
    /// room within a building.
    public let setup: String?

    /// Time of day (e.g., "DAY", "NIGHT", "DAWN", "DUSK").
    public let timeOfDay: String?

    /// Any additional modifiers (e.g., "CONTINUOUS", "LATER", year markers).
    ///
    /// Modifiers typically appear in parentheses or brackets:
    /// - "DAY (1973)"
    /// - "NIGHT (CONTINUOUS)"
    public let modifiers: [String]

    /// The original full slugline text as it appeared in the screenplay.
    public let originalText: String

    /// Create a scene location from components.
    ///
    /// - Parameters:
    ///   - lighting: The lighting/setting (INT, EXT, etc.)
    ///   - scene: The main location name
    ///   - setup: Optional sub-location (default: nil)
    ///   - timeOfDay: Optional time indicator (default: nil)
    ///   - modifiers: Additional temporal/contextual markers (default: empty array)
    ///   - originalText: The original scene heading text
    public init(
        lighting: SceneLighting,
        scene: String,
        setup: String? = nil,
        timeOfDay: String? = nil,
        modifiers: [String] = [],
        originalText: String
    ) {
        self.lighting = lighting
        self.scene = scene
        self.setup = setup
        self.timeOfDay = timeOfDay
        self.modifiers = modifiers
        self.originalText = originalText
    }

    /// Full location name combining scene and setup.
    ///
    /// - Returns: The scene name, or "SCENE - SETUP" if setup is present
    ///
    /// ## Example
    /// ```swift
    /// let loc1 = SceneLocation.parse("INT. HOUSE - KITCHEN - DAY")
    /// print(loc1.fullLocation) // "HOUSE - KITCHEN"
    ///
    /// let loc2 = SceneLocation.parse("EXT. PARK - DAY")
    /// print(loc2.fullLocation) // "PARK"
    /// ```
    public var fullLocation: String {
        if let setup = setup, !setup.isEmpty {
            return "\(scene) - \(setup)"
        }
        return scene
    }

    /// A normalized location key for grouping scenes by location.
    ///
    /// This property provides a consistent key for comparing and grouping scenes,
    /// normalizing case and special characters for reliable matching.
    ///
    /// - Returns: Uppercased, trimmed location key
    ///
    /// ## Example
    /// ```swift
    /// let loc1 = SceneLocation.parse("INT. Will's House - DAY")
    /// let loc2 = SceneLocation.parse("INT. WILL'S HOUSE - NIGHT")
    /// print(loc1.locationKey == loc2.locationKey) // true (normalized)
    /// ```
    public var locationKey: String {
        let normalized = fullLocation
            .uppercased()
            .trimmingCharacters(in: .whitespaces)
            // Normalize apostrophes
            .replacingOccurrences(of: "'", with: "'")
            .replacingOccurrences(of: "'", with: "'")
            .replacingOccurrences(of: "'", with: "'")
        return normalized
    }

    /// Parse a scene heading/slugline into components.
    ///
    /// This method intelligently parses a screenplay scene heading into its constituent
    /// parts, handling various formatting styles and edge cases.
    ///
    /// - Parameter slugline: The raw scene heading text to parse
    /// - Returns: A `SceneLocation` with parsed components
    ///
    /// ## Supported Formats
    ///
    /// This parser handles a wide variety of scene heading formats:
    ///
    /// **Basic Format:**
    /// ```
    /// INT. LOCATION - TIME
    /// EXT. LOCATION - TIME
    /// ```
    ///
    /// **With Sub-location:**
    /// ```
    /// INT. HOUSE - KITCHEN - DAY
    /// EXT. BUILDING - LOBBY - NIGHT
    /// ```
    ///
    /// **With Modifiers:**
    /// ```
    /// INT. OFFICE - DAY (1973)
    /// EXT. PARK - NIGHT (CONTINUOUS)
    /// ```
    ///
    /// **Alternate Lighting Formats:**
    /// ```
    /// INT/EXT. CAR - DAY
    /// INT./EXT. DOORWAY - DAWN
    /// I/E. WINDOW - DUSK
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// let location = SceneLocation.parse("INT. COFFEE SHOP - KITCHEN - DAY (1995)")
    ///
    /// print(location.lighting) // .interior
    /// print(location.scene) // "COFFEE SHOP"
    /// print(location.setup) // "KITCHEN"
    /// print(location.timeOfDay) // "DAY"
    /// print(location.modifiers) // ["1995"]
    /// ```
    public static func parse(_ slugline: String) -> SceneLocation {
        var text = slugline.trimmingCharacters(in: .whitespaces)

        // Extract lighting (INT, EXT, INT/EXT, INT./EXT, I/E)
        let lightingPatterns: [(SceneLighting, String)] = [
            (.interiorExteriorAlt, "^INT\\./EXT\\.?"),
            (.interiorExterior, "^INT/EXT\\.?"),
            (.interiorExteriorShort, "^I/E\\.?"),
            (.interior, "^INT\\.?"),
            (.exterior, "^EXT\\.?")
        ]

        var lighting: SceneLighting = .unknown
        for (lightingType, pattern) in lightingPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                lighting = lightingType
                text = String(text[Range(match.range, in: text)!.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Split by dash to separate location from time
        // The last dash typically separates time of day
        let parts = text.components(separatedBy: " - ")

        var locationPart = ""
        var timePart: String? = nil
        var modifiers: [String] = []

        if parts.count >= 2 {
            // Everything except the last part is location
            locationPart = parts.dropLast().joined(separator: " - ")
            timePart = parts.last

            // Extract modifiers from time part (e.g., "DAY (1973)" or "NIGHT [CONTINUOUS]")
            if let timeText = timePart {
                // Extract content in parentheses or brackets
                let modifierPattern = "[\\(\\[]([^\\)\\]]+)[\\)\\]]"
                if let regex = try? NSRegularExpression(pattern: modifierPattern),
                   let nsText = timeText as NSString? {
                    let matches = regex.matches(in: timeText, range: NSRange(location: 0, length: nsText.length))
                    for match in matches.reversed() {
                        if match.numberOfRanges > 1 {
                            let modifierRange = match.range(at: 1)
                            let modifier = nsText.substring(with: modifierRange)
                            modifiers.insert(modifier, at: 0)
                        }
                    }
                    // Remove modifiers from time part
                    timePart = regex.stringByReplacingMatches(
                        in: timeText,
                        range: NSRange(location: 0, length: nsText.length),
                        withTemplate: ""
                    ).trimmingCharacters(in: .whitespaces)
                }
            }
        } else if parts.count == 1 {
            // No dash, entire thing is location
            locationPart = parts[0]
        }

        // Parse location into scene and setup
        // Common patterns: "LOCATION", "LOCATION SUBAREA", "LOCATION (DETAIL)"
        locationPart = locationPart.trimmingCharacters(in: .whitespaces)

        var scene = locationPart
        var setup: String? = nil

        // Try to intelligently split location into scene and setup
        // Look for common setup patterns
        let locationWords = locationPart.split(separator: " ")
        if locationWords.count > 1 {
            // Common setup keywords (order matters - check longer phrases first)
            let setupKeywords = [
                "MASTER BEDROOM", "FRONT HALL", "BACK YARD", "FRONT YARD",
                "LIVING ROOM", "DINING ROOM",
                "KITCHEN", "BEDROOM", "BATHROOM", "HALLWAY", "GARAGE",
                "BASEMENT", "ATTIC", "OFFICE", "LOBBY", "ROOM",
                "ENTRANCE", "EXIT"
            ]

            for keyword in setupKeywords {
                if locationPart.uppercased().contains(keyword) {
                    // Try to split at the keyword
                    let upperLocation = locationPart.uppercased()
                    if let range = upperLocation.range(of: keyword) {
                        let beforeKeyword = String(locationPart[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                        let fromKeyword = String(locationPart[range.lowerBound...]).trimmingCharacters(in: .whitespaces)

                        if !beforeKeyword.isEmpty {
                            scene = beforeKeyword
                            setup = fromKeyword
                        }
                        break
                    }
                }
            }
        }

        return SceneLocation(
            lighting: lighting,
            scene: scene,
            setup: setup,
            timeOfDay: timePart?.isEmpty == false ? timePart : nil,
            modifiers: modifiers,
            originalText: slugline
        )
    }
}

extension SceneLocation: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []

        if lighting != .unknown {
            parts.append(lighting.standardAbbreviation)
        }

        parts.append(fullLocation)

        if let time = timeOfDay {
            parts.append("- \(time)")
        }

        if !modifiers.isEmpty {
            parts.append("(\(modifiers.joined(separator: ", ")))")
        }

        return parts.joined(separator: " ")
    }
}

extension SceneLocation: Equatable {
    public static func == (lhs: SceneLocation, rhs: SceneLocation) -> Bool {
        return lhs.lighting == rhs.lighting &&
               lhs.scene == rhs.scene &&
               lhs.setup == rhs.setup &&
               lhs.timeOfDay == rhs.timeOfDay &&
               lhs.modifiers == rhs.modifiers &&
               lhs.originalText == rhs.originalText
    }
}

extension SceneLocation: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(lighting)
        hasher.combine(scene)
        hasher.combine(setup)
        hasher.combine(timeOfDay)
        hasher.combine(modifiers)
        hasher.combine(originalText)
    }
}
