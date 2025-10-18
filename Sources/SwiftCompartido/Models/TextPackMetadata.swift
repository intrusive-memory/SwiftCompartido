//
//  TextPackMetadata.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//
//  Defines the JSON metadata structures for .guion TextPack bundles

import Foundation

// MARK: - TextPack Info (info.json)

/// Metadata for a .guion TextPack bundle
public struct TextPackInfo: Codable, Sendable {
    /// TextPack format version
    public let version: String

    /// Format identifier
    public let format: String

    /// Creation timestamp
    public let created: Date

    /// Last modified timestamp
    public let modified: Date

    /// Original filename
    public let filename: String?

    /// Whether to suppress scene numbers
    public let suppressSceneNumbers: Bool

    /// List of resource files included
    public let resources: [String]

    /// List of imported/attached files
    public let importedFiles: [String]

    public init(
        version: String = "1.0",
        format: String = "guion-textpack",
        created: Date = Date(),
        modified: Date = Date(),
        filename: String? = nil,
        suppressSceneNumbers: Bool = false,
        resources: [String] = [],
        importedFiles: [String] = []
    ) {
        self.version = version
        self.format = format
        self.created = created
        self.modified = modified
        self.filename = filename
        self.suppressSceneNumbers = suppressSceneNumbers
        self.resources = resources
        self.importedFiles = importedFiles
    }
}

// MARK: - Character Data (characters.json)

/// Character information extracted from screenplay
public struct CharacterData: Codable, Sendable, Identifiable {
    /// Unique identifier
    public let id: String

    /// Character name (as it appears in dialogue)
    public let name: String

    /// Scene IDs where character appears
    public let scenes: [String]

    /// Number of dialogue lines
    public let dialogueLines: Int

    /// Total words spoken
    public let dialogueWords: Int

    /// Scene ID of first appearance
    public let firstAppearance: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        scenes: [String],
        dialogueLines: Int,
        dialogueWords: Int,
        firstAppearance: String? = nil
    ) {
        self.id = id
        self.name = name
        self.scenes = scenes
        self.dialogueLines = dialogueLines
        self.dialogueWords = dialogueWords
        self.firstAppearance = firstAppearance
    }
}

/// Container for character list in TextPack format
public struct TextPackCharacterList: Codable, Sendable {
    public let characters: [CharacterData]

    public init(characters: [CharacterData]) {
        self.characters = characters
    }
}

// MARK: - Location Data (locations.json)

/// Location information extracted from scene headings
public struct LocationData: Codable, Sendable, Identifiable {
    /// Unique identifier
    public let id: String

    /// Raw location string from scene heading
    public let rawLocation: String

    /// Lighting (interior/exterior/etc)
    public let lighting: String

    /// Primary location name
    public let scene: String

    /// Setup/sub-location
    public let setup: String?

    /// Time of day
    public let timeOfDay: String?

    /// Additional modifiers
    public let modifiers: [String]

    /// Scene IDs using this location
    public let sceneIds: [String]

    public init(
        id: String = UUID().uuidString,
        rawLocation: String,
        lighting: String,
        scene: String,
        setup: String? = nil,
        timeOfDay: String? = nil,
        modifiers: [String] = [],
        sceneIds: [String]
    ) {
        self.id = id
        self.rawLocation = rawLocation
        self.lighting = lighting
        self.scene = scene
        self.setup = setup
        self.timeOfDay = timeOfDay
        self.modifiers = modifiers
        self.sceneIds = sceneIds
    }
}

/// Container for location list
public struct LocationList: Codable, Sendable {
    public let locations: [LocationData]

    public init(locations: [LocationData]) {
        self.locations = locations
    }
}

// MARK: - Element Data (elements.json)

/// Screenplay element for JSON export
public struct ElementData: Codable, Sendable, Identifiable {
    /// Unique identifier
    public let id: String

    /// Element type
    public let elementType: String

    /// Element text
    public let elementText: String

    /// Scene number (if applicable)
    public let sceneNumber: String?

    /// Scene ID (if applicable)
    public let sceneId: String?

    /// Centered flag
    public let isCentered: Bool

    /// Dual dialogue flag
    public let isDualDialogue: Bool

    /// Section depth
    public let sectionDepth: Int

    public init(
        id: String = UUID().uuidString,
        elementType: String,
        elementText: String,
        sceneNumber: String? = nil,
        sceneId: String? = nil,
        isCentered: Bool = false,
        isDualDialogue: Bool = false,
        sectionDepth: Int = 0
    ) {
        self.id = id
        self.elementType = elementType
        self.elementText = elementText
        self.sceneNumber = sceneNumber
        self.sceneId = sceneId
        self.isCentered = isCentered
        self.isDualDialogue = isDualDialogue
        self.sectionDepth = sectionDepth
    }

    /// Create from GuionElement
    public init(from element: GuionElement) {
        self.init(
            id: UUID().uuidString,
            elementType: element.elementType.description,
            elementText: element.elementText,
            sceneNumber: element.sceneNumber,
            sceneId: element.sceneId,
            isCentered: element.isCentered,
            isDualDialogue: element.isDualDialogue,
            sectionDepth: element.sectionDepth
        )
    }
}

/// Container for element list
public struct ElementList: Codable, Sendable {
    public let elements: [ElementData]

    public init(elements: [ElementData]) {
        self.elements = elements
    }
}

// MARK: - Title Page Data (titlepage.json)

/// Title page entry for JSON export
public struct TitlePageData: Codable, Sendable {
    public let titlePage: [[String: [String]]]

    public init(titlePage: [[String: [String]]]) {
        self.titlePage = titlePage
    }
}
