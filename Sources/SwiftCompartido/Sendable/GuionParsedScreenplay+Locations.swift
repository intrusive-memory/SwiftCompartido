//
//  FountainScript+Locations.swift
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

/// A scene with its associated location and element index
public struct SceneWithLocation: Sendable {
    /// The parsed location information
    public let location: SceneLocation

    /// The index of this scene in the script's elements array
    public let sceneIndex: Int

    /// The scene heading element
    public let sceneHeading: GuionElement

    /// Optional scene number if present
    public let sceneNumber: String?

    public init(location: SceneLocation, sceneIndex: Int, sceneHeading: GuionElement, sceneNumber: String? = nil) {
        self.location = location
        self.sceneIndex = sceneIndex
        self.sceneHeading = sceneHeading
        self.sceneNumber = sceneNumber
    }
}

/// Grouping of scenes by location for production planning
public struct LocationGroup: Sendable {
    /// The normalized location key
    public let locationKey: String

    /// A representative location (from the first scene)
    public let representativeLocation: SceneLocation

    /// All scenes at this location
    public let scenes: [SceneWithLocation]

    /// Count of scenes at this location
    public var sceneCount: Int { scenes.count }

    /// All lighting types used at this location
    public var lightingTypes: Set<SceneLighting> {
        Set(scenes.map { $0.location.lighting })
    }

    /// All times of day used at this location
    public var timesOfDay: Set<String> {
        Set(scenes.compactMap { $0.location.timeOfDay })
    }

    /// Whether this location has both interior and exterior scenes
    public var hasMultipleLightingTypes: Bool {
        lightingTypes.count > 1
    }

    public init(locationKey: String, representativeLocation: SceneLocation, scenes: [SceneWithLocation]) {
        self.locationKey = locationKey
        self.representativeLocation = representativeLocation
        self.scenes = scenes
    }
}

// MARK: - GuionElement Extension

extension GuionElement {
    /// Parse the location from this element if it's a scene heading
    /// Returns nil if this is not a scene heading
    public var sceneLocation: SceneLocation? {
        guard elementType == .sceneHeading else {
            return nil
        }
        return SceneLocation.parse(elementText)
    }
}

// MARK: - GuionParsedScreenplay Extension

extension GuionParsedScreenplay {
    /// Extract all scene locations from the script
    /// - Returns: Array of scenes with their parsed locations
    public func extractSceneLocations() -> [SceneWithLocation] {
        var scenes: [SceneWithLocation] = []

        for (index, element) in elements.enumerated() {
            guard element.elementType == .sceneHeading else {
                continue
            }

            let location = SceneLocation.parse(element.elementText)
            let scene = SceneWithLocation(
                location: location,
                sceneIndex: index,
                sceneHeading: element,
                sceneNumber: element.sceneNumber
            )
            scenes.append(scene)
        }

        return scenes
    }

    /// Group scenes by location for production planning
    /// - Returns: Dictionary mapping location keys to location groups
    public func groupScenesByLocation() -> [String: LocationGroup] {
        let scenes = extractSceneLocations()
        var groups: [String: [SceneWithLocation]] = [:]

        // Group scenes by normalized location key
        for scene in scenes {
            let key = scene.location.locationKey
            groups[key, default: []].append(scene)
        }

        // Convert to LocationGroup objects
        var locationGroups: [String: LocationGroup] = [:]
        for (key, sceneList) in groups {
            guard let firstScene = sceneList.first else { continue }

            let group = LocationGroup(
                locationKey: key,
                representativeLocation: firstScene.location,
                scenes: sceneList
            )
            locationGroups[key] = group
        }

        return locationGroups
    }

    /// Get location groups sorted by scene count (most used locations first)
    /// - Returns: Array of location groups sorted by frequency
    public func getLocationsByFrequency() -> [LocationGroup] {
        let groups = groupScenesByLocation()
        return groups.values.sorted { $0.sceneCount > $1.sceneCount }
    }

    /// Get location groups sorted by first appearance in script
    /// - Returns: Array of location groups sorted by order of appearance
    public func getLocationsByAppearance() -> [LocationGroup] {
        let groups = groupScenesByLocation()
        return groups.values.sorted { group1, group2 in
            let firstIndex1 = group1.scenes.first?.sceneIndex ?? Int.max
            let firstIndex2 = group2.scenes.first?.sceneIndex ?? Int.max
            return firstIndex1 < firstIndex2
        }
    }

    /// Get all scenes at a specific location
    /// - Parameter locationKey: The normalized location key to search for
    /// - Returns: Array of scenes at that location, or empty array if not found
    public func scenes(at locationKey: String) -> [SceneWithLocation] {
        let groups = groupScenesByLocation()
        return groups[locationKey]?.scenes ?? []
    }

    /// Get all unique locations in the script
    /// - Returns: Array of all unique location keys
    public func allLocations() -> [String] {
        return Array(groupScenesByLocation().keys).sorted()
    }

    /// Write location breakdown to JSON file
    /// - Parameter url: The file URL to write to
    public func writeLocationBreakdownJSON(to url: URL) throws {
        let groups = getLocationsByAppearance()

        // Create a serializable structure
        let breakdown: [[String: Any]] = groups.map { group in
            [
                "location": group.representativeLocation.fullLocation,
                "locationKey": group.locationKey,
                "sceneCount": group.sceneCount,
                "lighting": Array(group.lightingTypes).map { $0.standardAbbreviation },
                "timesOfDay": Array(group.timesOfDay).sorted(),
                "scenes": group.scenes.map { scene in
                    [
                        "sceneIndex": scene.sceneIndex,
                        "sceneNumber": scene.sceneNumber as Any,
                        "heading": scene.sceneHeading.elementText,
                        "lighting": scene.location.lighting.standardAbbreviation,
                        "timeOfDay": scene.location.timeOfDay as Any,
                        "modifiers": scene.location.modifiers
                    ]
                }
            ]
        }

        let jsonData = try JSONSerialization.data(withJSONObject: breakdown, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: url)
    }
}
