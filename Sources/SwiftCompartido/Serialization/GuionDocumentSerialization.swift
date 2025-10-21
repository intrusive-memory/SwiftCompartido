//
//  GuionDocumentSerialization.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//

import Foundation
#if canImport(SwiftData)
import SwiftData

/// Errors that can occur during guion document serialization
public enum GuionSerializationError: LocalizedError {
    case encodingFailed(Error)
    case decodingFailed(Error)
    case corruptedFile(String)
    case unsupportedVersion(Int)
    case missingData

    public var errorDescription: String? {
        switch self {
        case .encodingFailed(let error):
            return "Failed to encode document: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode document: \(error.localizedDescription)"
        case .corruptedFile(let filename):
            return "The document '\(filename)' is corrupted and cannot be opened."
        case .unsupportedVersion(let version):
            return "This document was created with a newer version of the application (version \(version))."
        case .missingData:
            return "The document is missing required data."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .corruptedFile:
            return "Try opening the document in a different application or restoring from a backup."
        case .unsupportedVersion:
            return "Please update to the latest version of the application."
        case .encodingFailed, .decodingFailed, .missingData:
            return "Please try saving the document again or contact support if the problem persists."
        }
    }
}

/// Codable transfer object for GuionElementModel
struct GuionElementSnapshot: Codable {
    let elementText: String
    let elementType: String
    let isCentered: Bool
    let isDualDialogue: Bool
    let sceneNumber: String?
    let sectionDepth: Int
    let sceneId: String?
    let summary: String?

    // Cached location data
    let locationLighting: String?
    let locationScene: String?
    let locationSetup: String?
    let locationTimeOfDay: String?
    let locationModifiers: [String]?

    init(from model: GuionElementModel) {
        self.elementText = model.elementText
        self.elementType = model.elementType.description
        self.isCentered = model.isCentered
        self.isDualDialogue = model.isDualDialogue
        self.sceneNumber = model.sceneNumber
        self.sectionDepth = model.sectionDepth
        self.sceneId = model.sceneId
        self.summary = model.summary
        self.locationLighting = model.locationLighting
        self.locationScene = model.locationScene
        self.locationSetup = model.locationSetup
        self.locationTimeOfDay = model.locationTimeOfDay
        self.locationModifiers = model.locationModifiers
    }

    func toModel() -> GuionElementModel {
        let model = GuionElementModel(
            elementText: elementText,
            elementType: ElementType(string: elementType),
            isCentered: isCentered,
            isDualDialogue: isDualDialogue,
            sceneNumber: sceneNumber,
            sectionDepth: sectionDepth,
            summary: summary,
            sceneId: sceneId
        )

        // Restore cached location data directly (bypass parsing)
        model.locationLighting = locationLighting
        model.locationScene = locationScene
        model.locationSetup = locationSetup
        model.locationTimeOfDay = locationTimeOfDay
        model.locationModifiers = locationModifiers

        return model
    }
}

/// Codable transfer object for TitlePageEntryModel
struct TitlePageEntrySnapshot: Codable {
    let key: String
    let values: [String]

    init(from model: TitlePageEntryModel) {
        self.key = model.key
        self.values = model.values
    }

    func toModel() -> TitlePageEntryModel {
        return TitlePageEntryModel(key: key, values: values)
    }
}

/// Codable transfer object for GuionDocumentModel
struct GuionDocumentSnapshot: Codable {
    let version: Int
    let filename: String?
    let rawContent: String?
    let suppressSceneNumbers: Bool
    let elements: [GuionElementSnapshot]
    let titlePage: [TitlePageEntrySnapshot]

    static let currentVersion = 1

    init(from model: GuionDocumentModel) {
        self.version = Self.currentVersion
        self.filename = model.filename
        self.rawContent = model.rawContent
        self.suppressSceneNumbers = model.suppressSceneNumbers
        self.elements = model.sortedElements.map { GuionElementSnapshot(from: $0) }
        self.titlePage = model.titlePage.map { TitlePageEntrySnapshot(from: $0) }
    }

    @MainActor
    func toModel(in modelContext: ModelContext) -> GuionDocumentModel {
        let documentModel = GuionDocumentModel(
            filename: filename,
            rawContent: rawContent,
            suppressSceneNumbers: suppressSceneNumbers
        )

        // Create all title page entries
        for titleSnapshot in titlePage {
            let entry = titleSnapshot.toModel()
            entry.document = documentModel
            documentModel.titlePage.append(entry)
        }

        // Create all elements
        for elementSnapshot in elements {
            let element = elementSnapshot.toModel()
            element.document = documentModel
            documentModel.elements.append(element)
        }

        modelContext.insert(documentModel)
        return documentModel
    }
}

/// Extension to GuionDocumentModel for file serialization
extension GuionDocumentModel {

    /// Save the document to a .guion file
    /// - Parameter url: The URL to save to
    /// - Throws: GuionSerializationError if encoding or file writing fails
    public func save(to url: URL) throws {
        do {
            let snapshot = GuionDocumentSnapshot(from: self)
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch let error as EncodingError {
            throw GuionSerializationError.encodingFailed(error)
        } catch {
            throw GuionSerializationError.encodingFailed(error)
        }
    }

    /// Load a .guion file from disk
    /// - Parameters:
    ///   - url: The URL to load from
    ///   - modelContext: The ModelContext to insert the loaded document into
    /// - Returns: The loaded GuionDocumentModel
    /// - Throws: GuionSerializationError if decoding or file reading fails
    @MainActor
    public static func load(from url: URL, in modelContext: ModelContext) throws -> GuionDocumentModel {
        do {
            let data = try Data(contentsOf: url)
            let decoder = PropertyListDecoder()
            let snapshot = try decoder.decode(GuionDocumentSnapshot.self, from: data)

            // Check version compatibility
            if snapshot.version > GuionDocumentSnapshot.currentVersion {
                throw GuionSerializationError.unsupportedVersion(snapshot.version)
            }

            return snapshot.toModel(in: modelContext)
        } catch let error as DecodingError {
            throw GuionSerializationError.decodingFailed(error)
        } catch let error as GuionSerializationError {
            throw error
        } catch {
            throw GuionSerializationError.corruptedFile(url.lastPathComponent)
        }
    }

    /// Validate the document's data integrity
    /// - Throws: GuionSerializationError if validation fails
    public func validate() throws {
        // Check required fields
        guard filename != nil || rawContent != nil else {
            throw GuionSerializationError.missingData
        }

        // Verify relationships are intact
        for element in elements {
            if element.document !== self {
                throw GuionSerializationError.corruptedFile(filename ?? "unknown")
            }
        }

        for entry in titlePage {
            if entry.document !== self {
                throw GuionSerializationError.corruptedFile(filename ?? "unknown")
            }
        }

        // Verify scene locations are cached for scene headings
        for element in elements where element.elementType == .sceneHeading {
            if element.locationLighting == nil || element.locationScene == nil {
                // Re-parse if missing
                element.reparseLocation()
            }
        }
    }
}

/// Extension to serialize/deserialize to Data (for FileDocument)
extension GuionDocumentModel {

    /// Encode the document to binary data
    /// - Returns: Binary data representing the document
    /// - Throws: GuionSerializationError if encoding fails
    public func encodeToBinaryData() throws -> Data {
        do {
            let snapshot = GuionDocumentSnapshot(from: self)
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            return try encoder.encode(snapshot)
        } catch let error as EncodingError {
            throw GuionSerializationError.encodingFailed(error)
        } catch {
            throw GuionSerializationError.encodingFailed(error)
        }
    }

    /// Decode a document from binary data
    /// - Parameters:
    ///   - data: Binary data representing the document
    ///   - modelContext: The ModelContext to insert the document into
    /// - Returns: The decoded GuionDocumentModel
    /// - Throws: GuionSerializationError if decoding fails
    @MainActor
    public static func decodeFromBinaryData(_ data: Data, in modelContext: ModelContext) throws -> GuionDocumentModel {
        do {
            let decoder = PropertyListDecoder()
            let snapshot = try decoder.decode(GuionDocumentSnapshot.self, from: data)

            // Check version compatibility
            if snapshot.version > GuionDocumentSnapshot.currentVersion {
                throw GuionSerializationError.unsupportedVersion(snapshot.version)
            }

            return snapshot.toModel(in: modelContext)
        } catch let error as DecodingError {
            throw GuionSerializationError.decodingFailed(error)
        } catch let error as GuionSerializationError {
            throw error
        } catch {
            throw GuionSerializationError.corruptedFile("data")
        }
    }
}

#endif
