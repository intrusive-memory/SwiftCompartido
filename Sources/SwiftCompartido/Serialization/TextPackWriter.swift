//
//  TextPackWriter.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//
//  Creates .guion TextPack bundles from screenplay data

import Foundation

/// Writer for creating .guion TextPack bundles
public struct TextPackWriter {

    /// Create a TextPack bundle from a GuionParsedScreenplay
    /// - Parameter screenplay: The screenplay to export
    /// - Returns: FileWrapper representing the TextPack bundle
    public static func createTextPack(from screenplay: GuionParsedScreenplay) throws -> FileWrapper {
        let fileWrappers: [String: FileWrapper] = [:]
        let bundle = FileWrapper(directoryWithFileWrappers: fileWrappers)

        // 1. Create info.json
        let info = TextPackInfo(
            filename: screenplay.filename,
            suppressSceneNumbers: screenplay.suppressSceneNumbers,
            resources: [
                "characters.json",
                "locations.json",
                "elements.json",
                "titlepage.json"
            ]
        )

        let infoData = try JSONEncoder.textPackEncoder.encode(info)
        bundle.addRegularFile(withContents: infoData, preferredFilename: "info.json")

        // 2. Create screenplay.fountain
        let fountainContent = screenplay.stringFromDocument()
        let fountainData = Data(fountainContent.utf8)
        bundle.addRegularFile(withContents: fountainData, preferredFilename: "screenplay.fountain")

        // 3. Create Resources directory
        let resources = try createResourcesDirectory(from: screenplay)
        resources.preferredFilename = "Resources"
        bundle.addFileWrapper(resources)

        return bundle
    }

    /// Create a TextPack bundle from a GuionDocumentModel
    /// - Parameter document: The document model to export
    /// - Returns: FileWrapper representing the TextPack bundle
    public static func createTextPack(from document: GuionDocumentModel) throws -> FileWrapper {
        // Convert to GuionParsedScreenplay first
        let screenplay = document.toGuionParsedScreenplay()
        return try createTextPack(from: screenplay)
    }

    /// Create a TextPack bundle from a GuionParsedScreenplay with progress reporting
    ///
    /// This async version provides progress updates through five stages:
    /// 1. Creating info.json (10%)
    /// 2. Generating screenplay.fountain (30%)
    /// 3. Extracting character data (20%)
    /// 4. Extracting location data (20%)
    /// 5. Writing resource files (20%)
    ///
    /// - Parameters:
    ///   - screenplay: The screenplay to export
    ///   - progress: Optional progress tracker for monitoring export progress
    ///
    /// - Throws: `CancellationError` if the task is cancelled during export
    ///
    /// - Returns: FileWrapper representing the TextPack bundle
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let progress = OperationProgress(totalUnits: 5) { update in
    ///     print("Export: \(update.description) - \(Int((update.fractionCompleted ?? 0) * 100))%")
    /// }
    ///
    /// let bundle = try await TextPackWriter.createTextPack(
    ///     from: screenplay,
    ///     progress: progress
    /// )
    /// ```
    public static func createTextPack(
        from screenplay: GuionParsedScreenplay,
        progress: OperationProgress?
    ) async throws -> FileWrapper {
        // Set total stages
        progress?.setTotalUnitCount(5)

        // Check cancellation before starting
        try Task.checkCancellation()

        // Stage 1: Create info.json (10%)
        progress?.update(completedUnits: 0, description: "Creating bundle metadata...")

        let fileWrappers: [String: FileWrapper] = [:]
        let bundle = FileWrapper(directoryWithFileWrappers: fileWrappers)

        let info = TextPackInfo(
            filename: screenplay.filename,
            suppressSceneNumbers: screenplay.suppressSceneNumbers,
            resources: [
                "characters.json",
                "locations.json",
                "elements.json",
                "titlepage.json"
            ]
        )

        let infoData = try JSONEncoder.textPackEncoder.encode(info)
        bundle.addRegularFile(withContents: infoData, preferredFilename: "info.json")

        progress?.update(completedUnits: 1, description: "Metadata created")

        // Check cancellation
        try Task.checkCancellation()

        // Stage 2: Create screenplay.fountain (30%)
        progress?.update(completedUnits: 1, description: "Generating screenplay text...")

        let fountainContent = screenplay.stringFromDocument()
        let fountainData = Data(fountainContent.utf8)
        bundle.addRegularFile(withContents: fountainData, preferredFilename: "screenplay.fountain")

        progress?.update(completedUnits: 2, description: "Screenplay generated")

        // Check cancellation
        try Task.checkCancellation()

        // Stage 3-5: Create Resources directory (60%)
        progress?.update(completedUnits: 2, description: "Creating resources...")

        let resources = try await createResourcesDirectory(from: screenplay, progress: progress)
        resources.preferredFilename = "Resources"
        bundle.addFileWrapper(resources)

        // Complete
        progress?.complete(description: "Export complete")

        return bundle
    }

    /// Create a TextPack bundle from a GuionDocumentModel with progress reporting
    /// - Parameters:
    ///   - document: The document model to export
    ///   - progress: Optional progress tracker
    /// - Returns: FileWrapper representing the TextPack bundle
    public static func createTextPack(
        from document: GuionDocumentModel,
        progress: OperationProgress?
    ) async throws -> FileWrapper {
        // Convert to GuionParsedScreenplay first
        let screenplay = document.toGuionParsedScreenplay()
        return try await createTextPack(from: screenplay, progress: progress)
    }

    // MARK: - Private Helpers

    private static func createResourcesDirectory(from screenplay: GuionParsedScreenplay) throws -> FileWrapper {
        let resourceWrappers: [String: FileWrapper] = [:]
        let resourcesDir = FileWrapper(directoryWithFileWrappers: resourceWrappers)

        // 1. characters.json
        let characters = extractCharacterData(from: screenplay)
        let charactersData = try JSONEncoder.textPackEncoder.encode(characters)
        resourcesDir.addRegularFile(withContents: charactersData, preferredFilename: "characters.json")

        // 2. locations.json
        let locations = extractLocationData(from: screenplay)
        let locationsData = try JSONEncoder.textPackEncoder.encode(locations)
        resourcesDir.addRegularFile(withContents: locationsData, preferredFilename: "locations.json")

        // 3. elements.json
        let elements = ElementList(elements: screenplay.elements.map { ElementData(from: $0) })
        let elementsData = try JSONEncoder.textPackEncoder.encode(elements)
        resourcesDir.addRegularFile(withContents: elementsData, preferredFilename: "elements.json")

        // 4. titlepage.json
        let titlePage = TitlePageData(titlePage: screenplay.titlePage)
        let titlePageData = try JSONEncoder.textPackEncoder.encode(titlePage)
        resourcesDir.addRegularFile(withContents: titlePageData, preferredFilename: "titlepage.json")

        return resourcesDir
    }

    /// Async version of createResourcesDirectory with progress reporting
    private static func createResourcesDirectory(
        from screenplay: GuionParsedScreenplay,
        progress: OperationProgress?
    ) async throws -> FileWrapper {
        let resourceWrappers: [String: FileWrapper] = [:]
        let resourcesDir = FileWrapper(directoryWithFileWrappers: resourceWrappers)

        // Stage 3: Extract characters (20%)
        try Task.checkCancellation()
        progress?.update(completedUnits: 2, description: "Extracting character data...")

        let characters = extractCharacterData(from: screenplay)
        let charactersData = try JSONEncoder.textPackEncoder.encode(characters)
        resourcesDir.addRegularFile(withContents: charactersData, preferredFilename: "characters.json")

        progress?.update(completedUnits: 3, description: "Characters extracted")

        // Stage 4: Extract locations (20%)
        try Task.checkCancellation()
        progress?.update(completedUnits: 3, description: "Extracting location data...")

        let locations = extractLocationData(from: screenplay)
        let locationsData = try JSONEncoder.textPackEncoder.encode(locations)
        resourcesDir.addRegularFile(withContents: locationsData, preferredFilename: "locations.json")

        progress?.update(completedUnits: 4, description: "Locations extracted")

        // Stage 5: Write remaining resources (20%)
        try Task.checkCancellation()
        progress?.update(completedUnits: 4, description: "Writing resource files...")

        let elements = ElementList(elements: screenplay.elements.map { ElementData(from: $0) })
        let elementsData = try JSONEncoder.textPackEncoder.encode(elements)
        resourcesDir.addRegularFile(withContents: elementsData, preferredFilename: "elements.json")

        let titlePage = TitlePageData(titlePage: screenplay.titlePage)
        let titlePageData = try JSONEncoder.textPackEncoder.encode(titlePage)
        resourcesDir.addRegularFile(withContents: titlePageData, preferredFilename: "titlepage.json")

        progress?.update(completedUnits: 5, description: "Resources written")

        return resourcesDir
    }

    private static func extractCharacterData(from screenplay: GuionParsedScreenplay) -> TextPackCharacterList {
        // Use existing character extraction
        let characterInfo = screenplay.extractCharacters()

        // Extract scene IDs from outline
        let outline = screenplay.extractOutline()
        let sceneElements = outline.filter { $0.type == "sceneHeader" }

        let characterDataList: [CharacterData] = characterInfo.map { (name, info) in
            // Map scene indices to scene IDs
            let sceneIds: [String] = info.scenes.compactMap { sceneIndex in
                guard sceneIndex >= 0 && sceneIndex < sceneElements.count else { return nil }
                return sceneElements[sceneIndex].sceneId
            }

            return CharacterData(
                name: name,
                scenes: sceneIds,
                dialogueLines: info.counts.lineCount,
                dialogueWords: info.counts.wordCount,
                firstAppearance: sceneIds.first
            )
        }

        return TextPackCharacterList(characters: characterDataList)
    }

    private static func extractLocationData(from screenplay: GuionParsedScreenplay) -> LocationList {
        // Extract unique locations from scene headings
        var locationMap: [String: LocationData] = [:]

        for element in screenplay.elements where element.elementType == .sceneHeading {
            let location = SceneLocation.parse(element.elementText)

            let key = element.elementText

            if let existing = locationMap[key] {
                // Add scene ID to existing location
                if let sceneId = element.sceneId {
                    var sceneIds = existing.sceneIds
                    if !sceneIds.contains(sceneId) {
                        sceneIds.append(sceneId)
                        locationMap[key] = LocationData(
                            id: existing.id,
                            rawLocation: existing.rawLocation,
                            lighting: existing.lighting,
                            scene: existing.scene,
                            setup: existing.setup,
                            timeOfDay: existing.timeOfDay,
                            modifiers: existing.modifiers,
                            sceneIds: sceneIds
                        )
                    }
                }
            } else {
                // Create new location entry
                locationMap[key] = LocationData(
                    rawLocation: element.elementText,
                    lighting: location.lighting.rawValue,
                    scene: location.scene,
                    setup: location.setup,
                    timeOfDay: location.timeOfDay,
                    modifiers: location.modifiers,
                    sceneIds: element.sceneId != nil ? [element.sceneId!] : []
                )
            }
        }

        return LocationList(locations: Array(locationMap.values))
    }
}

// MARK: - JSONEncoder Extension

extension JSONEncoder {
    /// JSON encoder configured for TextPack files (pretty printed, ISO8601 dates)
    static var textPackEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    /// JSON decoder configured for TextPack files (ISO8601 dates)
    static var textPackDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
