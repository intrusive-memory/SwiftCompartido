import Testing
import Foundation
import SwiftFijos
@testable import SwiftCompartido

@Test func testSceneLightingParsing() {
    // Test INT
    let int = SceneLocation.parse("INT. COFFEE SHOP - DAY")
    #expect(int.lighting == .interior)
    #expect(int.scene == "COFFEE SHOP")
    #expect(int.timeOfDay == "DAY")

    // Test EXT
    let ext = SceneLocation.parse("EXT. PARK - NIGHT")
    #expect(ext.lighting == .exterior)
    #expect(ext.scene == "PARK")
    #expect(ext.timeOfDay == "NIGHT")

    // Test INT/EXT
    let intExt = SceneLocation.parse("INT/EXT. CAR - DAY")
    #expect(intExt.lighting == .interiorExterior)
    #expect(intExt.scene == "CAR")

    // Test INT./EXT
    let intExtAlt = SceneLocation.parse("INT./EXT. BUILDING - NIGHT")
    #expect(intExtAlt.lighting == .interiorExteriorAlt)

    // Test I/E
    let ie = SceneLocation.parse("I/E. SPACESHIP - DAY")
    #expect(ie.lighting == .interiorExteriorShort)
}

@Test func testSceneAndSetupParsing() {
    // Simple scene without setup
    let simple = SceneLocation.parse("INT. COFFEE SHOP - DAY")
    #expect(simple.scene == "COFFEE SHOP")
    #expect(simple.setup == nil)
    #expect(simple.fullLocation == "COFFEE SHOP")

    // Scene with setup (bedroom)
    let bedroom = SceneLocation.parse("INT. WILL'S BEDROOM - NIGHT")
    #expect(bedroom.scene == "WILL'S")
    #expect(bedroom.setup == "BEDROOM")
    #expect(bedroom.fullLocation == "WILL'S - BEDROOM")

    // Scene with setup (kitchen)
    let kitchen = SceneLocation.parse("INT. BLOOM HOUSE KITCHEN - DAY")
    #expect(kitchen.scene == "BLOOM HOUSE")
    #expect(kitchen.setup == "KITCHEN")
    #expect(kitchen.fullLocation == "BLOOM HOUSE - KITCHEN")

    // Scene with setup (master bedroom)
    let masterBedroom = SceneLocation.parse("INT. BLOOM HOUSE MASTER BEDROOM - NIGHT")
    #expect(masterBedroom.scene == "BLOOM HOUSE")
    #expect(masterBedroom.setup == "MASTER BEDROOM")

    // Scene with setup (hallway)
    let hallway = SceneLocation.parse("INT. HOSPITAL HALLWAY - DAY")
    #expect(hallway.scene == "HOSPITAL")
    #expect(hallway.setup == "HALLWAY")
}

@Test func testTimeOfDayParsing() {
    // Standard times
    let day = SceneLocation.parse("INT. ROOM - DAY")
    #expect(day.timeOfDay == "DAY")

    let night = SceneLocation.parse("EXT. STREET - NIGHT")
    #expect(night.timeOfDay == "NIGHT")

    let dawn = SceneLocation.parse("EXT. FIELD - DAWN")
    #expect(dawn.timeOfDay == "DAWN")

    let dusk = SceneLocation.parse("EXT. BEACH - DUSK")
    #expect(dusk.timeOfDay == "DUSK")

    // No time specified
    let noTime = SceneLocation.parse("EXT. APPROACHING THE HOUSE")
    #expect(noTime.timeOfDay == nil)
}

@Test func testModifierParsing() {
    // Year modifier
    let year = SceneLocation.parse("INT. WILL'S BEDROOM - NIGHT (1973)")
    #expect(year.timeOfDay == "NIGHT")
    #expect(year.modifiers.contains("1973"))

    // Continuous modifier
    let continuous = SceneLocation.parse("EXT. BLOOM BACK YARD - NIGHT [CONTINUOUS]")
    #expect(continuous.timeOfDay == "NIGHT")
    #expect(continuous.modifiers.contains("CONTINUOUS"))

    // Multiple modifiers
    let multiple = SceneLocation.parse("INT. ROOM - DAY (FLASHBACK) [LATER]")
    #expect(multiple.timeOfDay == "DAY")
    #expect(multiple.modifiers.contains("FLASHBACK"))
    #expect(multiple.modifiers.contains("LATER"))

    // Modifier in time position
    let present = SceneLocation.parse("INT. HALF-DARK PARIS APARTMENT - (PRESENT) DAY")
    #expect(present.timeOfDay == "DAY")
    #expect(present.modifiers.contains("PRESENT"))
}

@Test func testComplexSceneHeadings() {
    // Scene with parenthetical detail
    let detail = SceneLocation.parse("INT. TINY PARIS RESTAURANT (LA RUE 14°) - NIGHT (1998)")
    #expect(detail.scene.contains("PARIS RESTAURANT"))
    #expect(detail.timeOfDay == "NIGHT")
    #expect(detail.modifiers.contains("1998"))

    // Scene with slash in location
    let slash = SceneLocation.parse("INT. 747 / FLYING - NIGHT")
    #expect(slash.scene.contains("747"))
    #expect(slash.timeOfDay == "NIGHT")

    // Scene with multiple dashes in location
    let multiDash = SceneLocation.parse("EXT. FIELD AT THE SWAMP EDGE - NIGHT")
    #expect(multiDash.scene.contains("FIELD"))
    #expect(multiDash.timeOfDay == "NIGHT")
}

@Test func testLocationKeyNormalization() {
    // Test that similar locations have the same key
    let loc1 = SceneLocation.parse("INT. COFFEE SHOP - DAY")
    let loc2 = SceneLocation.parse("INT. COFFEE SHOP - NIGHT")
    let loc3 = SceneLocation.parse("EXT. COFFEE SHOP - DAY")

    // Same location, different time should have same key
    #expect(loc1.locationKey == loc2.locationKey)

    // Different lighting should have different key (since fullLocation is the same)
    // Actually no, locationKey only uses fullLocation, not lighting
    #expect(loc1.locationKey == loc3.locationKey)

    // Test curly apostrophe normalization
    let curly = SceneLocation.parse("INT. WILL'S BEDROOM - NIGHT")
    let straight = SceneLocation.parse("INT. WILL'S BEDROOM - NIGHT")
    #expect(curly.locationKey == straight.locationKey)
}

@Test func testGuionElementSceneLocation() {
    // Test scene heading element
    let sceneElement = GuionElement(elementType: .sceneHeading, elementText: "INT. COFFEE SHOP - DAY")
    let location = sceneElement.sceneLocation
    #expect(location != nil)
    #expect(location?.lighting == .interior)
    #expect(location?.scene == "COFFEE SHOP")
    #expect(location?.timeOfDay == "DAY")

    // Test non-scene heading element
    let actionElement = GuionElement(elementType: .action, elementText: "John walks in.")
    #expect(actionElement.sceneLocation == nil)
}

@Test func testExtractSceneLocations() async throws {
    let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
    let script = try await GuionParsedElementCollection(file: fountainURL.path)

    let scenes = script.extractSceneLocations()

    // Should have scene locations
    #expect(!scenes.isEmpty, "Should extract scene locations from Big Fish")

    // Verify first scene (Big Fish starts with an INT scene)
    if let firstScene = scenes.first {
        #expect(firstScene.location.lighting == .interior)
        #expect(firstScene.sceneHeading.elementType == .sceneHeading)
        #expect(firstScene.sceneIndex >= 0)
    }

    // All scenes should have valid scene headings
    for scene in scenes {
        #expect(scene.sceneHeading.elementType == .sceneHeading)
        #expect(!scene.location.originalText.isEmpty)
    }
}

@Test func testGroupScenesByLocation() async throws {
    let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
    let script = try await GuionParsedElementCollection(file: fountainURL.path)

    let groups = script.groupScenesByLocation()

    // Should have location groups
    #expect(!groups.isEmpty, "Should group scenes by location")

    // Each group should have at least one scene
    for (_, group) in groups {
        #expect(group.sceneCount > 0, "Each group should have at least one scene")
        #expect(!group.locationKey.isEmpty, "Each group should have a location key")
        #expect(!group.representativeLocation.scene.isEmpty, "Each group should have a representative location")
    }

    // Find a location that appears multiple times
    let multiSceneGroups = groups.values.filter { $0.sceneCount > 1 }
    if let multiSceneGroup = multiSceneGroups.first {
        print("Location '\(multiSceneGroup.representativeLocation.fullLocation)' has \(multiSceneGroup.sceneCount) scenes")

        // Verify all scenes in group have matching location keys
        for scene in multiSceneGroup.scenes {
            #expect(scene.location.locationKey == multiSceneGroup.locationKey)
        }
    }
}

@Test func testGetLocationsByFrequency() async throws {
    let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
    let script = try await GuionParsedElementCollection(file: fountainURL.path)

    let locationsByFrequency = script.getLocationsByFrequency()

    // Should be sorted by frequency (most scenes first)
    #expect(!locationsByFrequency.isEmpty)

    // Verify sorting
    for i in 0..<(locationsByFrequency.count - 1) {
        let current = locationsByFrequency[i]
        let next = locationsByFrequency[i + 1]
        #expect(current.sceneCount >= next.sceneCount,
                "Locations should be sorted by frequency: \(current.representativeLocation.fullLocation) (\(current.sceneCount)) >= \(next.representativeLocation.fullLocation) (\(next.sceneCount))")
    }

    // Print top 5 locations
    print("\nTop locations by frequency:")
    for (index, group) in locationsByFrequency.prefix(5).enumerated() {
        print("  \(index + 1). \(group.representativeLocation.fullLocation) - \(group.sceneCount) scenes")
    }
}

@Test func testGetLocationsByAppearance() async throws {
    let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
    let script = try await GuionParsedElementCollection(file: fountainURL.path)

    let locationsByAppearance = script.getLocationsByAppearance()

    // Should be sorted by first appearance
    #expect(!locationsByAppearance.isEmpty)

    // Verify sorting
    for i in 0..<(locationsByAppearance.count - 1) {
        let current = locationsByAppearance[i]
        let next = locationsByAppearance[i + 1]

        let currentFirstIndex = current.scenes.first?.sceneIndex ?? Int.max
        let nextFirstIndex = next.scenes.first?.sceneIndex ?? Int.max

        #expect(currentFirstIndex <= nextFirstIndex,
                "Locations should be sorted by appearance order")
    }
}

@Test func testLightingAndTimeAnalysis() async throws {
    let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
    let script = try await GuionParsedElementCollection(file: fountainURL.path)

    let groups = script.groupScenesByLocation()

    // Find locations with multiple lighting types
    let mixedLightingGroups = groups.values.filter { $0.hasMultipleLightingTypes }
    if !mixedLightingGroups.isEmpty {
        print("\nLocations with multiple lighting types:")
        for group in mixedLightingGroups.prefix(3) {
            print("  \(group.representativeLocation.fullLocation): \(group.lightingTypes.map { $0.standardAbbreviation })")
        }
    }

    // Verify lighting types are captured
    for group in groups.values {
        #expect(!group.lightingTypes.isEmpty, "Each group should have at least one lighting type")
    }

    // Find locations with multiple times of day
    let multiTimeGroups = groups.values.filter { $0.timesOfDay.count > 1 }
    if !multiTimeGroups.isEmpty {
        print("\nLocations with multiple times of day:")
        for group in multiTimeGroups.prefix(3) {
            print("  \(group.representativeLocation.fullLocation): \(Array(group.timesOfDay))")
        }
    }
}

@Test func testScenesAtLocation() async throws {
    let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
    let script = try await GuionParsedElementCollection(file: fountainURL.path)

    let allGroups = script.groupScenesByLocation()

    // Get a location that has multiple scenes
    if let testLocation = allGroups.values.first(where: { $0.sceneCount > 1 }) {
        let scenes = script.scenes(at: testLocation.locationKey)

        #expect(scenes.count == testLocation.sceneCount)
        #expect(!scenes.isEmpty)

        // Verify all scenes match the location
        for scene in scenes {
            #expect(scene.location.locationKey == testLocation.locationKey)
        }
    }
}

@Test func testAllLocations() async throws {
    let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
    let script = try await GuionParsedElementCollection(file: fountainURL.path)

    let locations = script.allLocations()

    #expect(!locations.isEmpty, "Should have locations")
    #expect(locations.sorted() == locations, "Locations should be sorted")

    print("\nTotal unique locations: \(locations.count)")
}

@Test func testWriteLocationBreakdownJSON() async throws {
    let fountainURL = try Fijos.getFixture("bigfish", extension: "fountain")
    let script = try await GuionParsedElementCollection(file: fountainURL.path)

    let tempDir = FileManager.default.temporaryDirectory
    let outputPath = tempDir.appendingPathComponent("bigfish-locations.json")

    try script.writeLocationBreakdownJSON(to: outputPath)

    #expect(FileManager.default.fileExists(atPath: outputPath.path))

    // Verify the JSON can be read back
    let data = try Data(contentsOf: outputPath)
    let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

    #expect(json != nil, "Should be able to parse location breakdown JSON")
    #expect(!json!.isEmpty, "Location breakdown should have content")

    // Verify structure of first location
    if let firstLocation = json?.first {
        #expect(firstLocation["location"] != nil, "Should have location field")
        #expect(firstLocation["locationKey"] != nil, "Should have locationKey field")
        #expect(firstLocation["sceneCount"] != nil, "Should have sceneCount field")
        #expect(firstLocation["lighting"] != nil, "Should have lighting field")
        #expect(firstLocation["scenes"] != nil, "Should have scenes field")
    }

    // Clean up
    try? FileManager.default.removeItem(at: outputPath)
}

@Test func testSceneLocationEquality() {
    let loc1 = SceneLocation.parse("INT. COFFEE SHOP - DAY")
    let loc2 = SceneLocation.parse("INT. COFFEE SHOP - DAY")
    let loc3 = SceneLocation.parse("INT. COFFEE SHOP - NIGHT")

    #expect(loc1 == loc2, "Identical locations should be equal")
    #expect(loc1 != loc3, "Different times should make locations unequal")
}

@Test func testSceneLocationDescription() {
    let location = SceneLocation.parse("INT. COFFEE SHOP - DAY (FLASHBACK)")

    let description = location.description
    #expect(description.contains("INT"))
    #expect(description.contains("COFFEE SHOP"))
    #expect(description.contains("DAY"))
    #expect(description.contains("FLASHBACK"))
}

@Test func testProductionScenario() async throws {
    // Simulate a production scenario where we need to schedule scenes by location

    let script = GuionParsedElementCollection(
        elements: [
            GuionElement(elementType: .sceneHeading, elementText: "INT. COFFEE SHOP - DAY"),
            GuionElement(elementType: .action, elementText: "Alice enters."),
            GuionElement(elementType: .sceneHeading, elementText: "EXT. PARK - DAY"),
            GuionElement(elementType: .action, elementText: "Bob walks."),
            GuionElement(elementType: .sceneHeading, elementText: "INT. COFFEE SHOP - NIGHT"),
            GuionElement(elementType: .action, elementText: "Alice returns."),
            GuionElement(elementType: .sceneHeading, elementText: "INT. COFFEE SHOP - DAY"),
            GuionElement(elementType: .action, elementText: "Alice meets Charlie."),
        ]
    )

    let groups = script.groupScenesByLocation()

    // Should have 2 locations (COFFEE SHOP and PARK)
    #expect(groups.count == 2, "Should have 2 unique locations")

    // Coffee shop should have 3 scenes
    let coffeeShopKey = "COFFEE SHOP"
    let coffeeShopGroup = groups.values.first { $0.representativeLocation.scene.uppercased() == coffeeShopKey }
    #expect(coffeeShopGroup?.sceneCount == 3, "Coffee shop should have 3 scenes")

    // Coffee shop should have both DAY and NIGHT scenes
    if let coffeeShop = coffeeShopGroup {
        #expect(coffeeShop.timesOfDay.count == 2, "Coffee shop should have 2 different times")
        #expect(coffeeShop.timesOfDay.contains("DAY"))
        #expect(coffeeShop.timesOfDay.contains("NIGHT"))
    }
}
