//
//  TextPackReader.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//
//  Reads .guion TextPack bundles into screenplay data

import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

/// Reader for loading .guion TextPack bundles
public struct TextPackReader {

    /// Read a TextPack bundle and create a GuionParsedScreenplay
    /// - Parameter fileWrapper: The FileWrapper representing the TextPack bundle
    /// - Returns: GuionParsedScreenplay loaded from the bundle
    /// - Throws: Errors if the bundle is invalid or files cannot be read
    public static func readTextPack(from fileWrapper: FileWrapper) throws -> GuionParsedScreenplay {
        guard fileWrapper.isDirectory,
              let fileWrappers = fileWrapper.fileWrappers else {
            throw TextPackError.notADirectory
        }

        // 1. Read info.json (optional but recommended)
        var info: TextPackInfo?
        if let infoWrapper = fileWrappers["info.json"],
           let infoData = infoWrapper.regularFileContents {
            info = try? JSONDecoder.textPackDecoder.decode(TextPackInfo.self, from: infoData)
        }

        // 2. Read screenplay.fountain (required)
        guard let screenplayWrapper = fileWrappers["screenplay.fountain"],
              let screenplayData = screenplayWrapper.regularFileContents,
              let screenplayContent = String(data: screenplayData, encoding: .utf8) else {
            throw TextPackError.missingScreenplayFile
        }

        // 3. Parse the Fountain content
        let screenplay = try GuionParsedScreenplay(string: screenplayContent)

        // Create new screenplay with metadata from info.json if available
        if let info = info {
            return GuionParsedScreenplay(
                filename: info.filename,
                elements: screenplay.elements,
                titlePage: screenplay.titlePage,
                suppressSceneNumbers: info.suppressSceneNumbers
            )
        }

        return screenplay
    }

    #if canImport(SwiftData)
    /// Read a TextPack bundle into a GuionDocumentModel
    /// - Parameters:
    ///   - fileWrapper: The FileWrapper representing the TextPack bundle
    ///   - context: The ModelContext to use
    ///   - generateSummaries: Whether to generate AI summaries (default: false)
    /// - Returns: GuionDocumentModel loaded from the bundle
    /// - Throws: Errors if the bundle is invalid or files cannot be read
    @MainActor
    public static func readTextPack(
        from fileWrapper: FileWrapper,
        in context: ModelContext,
        generateSummaries: Bool = false
    ) async throws -> GuionDocumentModel {
        // First read as GuionParsedScreenplay
        let screenplay = try readTextPack(from: fileWrapper)

        // Then convert to GuionDocumentModel
        return await GuionDocumentModel.from(screenplay, in: context, generateSummaries: generateSummaries)
    }
    #endif

    // MARK: - Resource File Reading

    /// Read character data from TextPack Resources
    /// - Parameter fileWrapper: The TextPack bundle FileWrapper
    /// - Returns: TextPackCharacterList if available, nil otherwise
    public static func readCharacters(from fileWrapper: FileWrapper) -> TextPackCharacterList? {
        guard let resourcesWrapper = fileWrapper.fileWrappers?["Resources"],
              let charactersWrapper = resourcesWrapper.fileWrappers?["characters.json"],
              let data = charactersWrapper.regularFileContents else {
            return nil
        }

        return try? JSONDecoder.textPackDecoder.decode(TextPackCharacterList.self, from: data)
    }

    /// Read location data from TextPack Resources
    /// - Parameter fileWrapper: The TextPack bundle FileWrapper
    /// - Returns: LocationList if available, nil otherwise
    public static func readLocations(from fileWrapper: FileWrapper) -> LocationList? {
        guard let resourcesWrapper = fileWrapper.fileWrappers?["Resources"],
              let locationsWrapper = resourcesWrapper.fileWrappers?["locations.json"],
              let data = locationsWrapper.regularFileContents else {
            return nil
        }

        return try? JSONDecoder.textPackDecoder.decode(LocationList.self, from: data)
    }

    /// Read element data from TextPack Resources
    /// - Parameter fileWrapper: The TextPack bundle FileWrapper
    /// - Returns: ElementList if available, nil otherwise
    public static func readElements(from fileWrapper: FileWrapper) -> ElementList? {
        guard let resourcesWrapper = fileWrapper.fileWrappers?["Resources"],
              let elementsWrapper = resourcesWrapper.fileWrappers?["elements.json"],
              let data = elementsWrapper.regularFileContents else {
            return nil
        }

        return try? JSONDecoder.textPackDecoder.decode(ElementList.self, from: data)
    }

    /// Read title page data from TextPack Resources
    /// - Parameter fileWrapper: The TextPack bundle FileWrapper
    /// - Returns: TitlePageData if available, nil otherwise
    public static func readTitlePage(from fileWrapper: FileWrapper) -> TitlePageData? {
        guard let resourcesWrapper = fileWrapper.fileWrappers?["Resources"],
              let titlePageWrapper = resourcesWrapper.fileWrappers?["titlepage.json"],
              let data = titlePageWrapper.regularFileContents else {
            return nil
        }

        return try? JSONDecoder.textPackDecoder.decode(TitlePageData.self, from: data)
    }
}

// MARK: - TextPack Errors

/// Errors that can occur when reading TextPack bundles
public enum TextPackError: LocalizedError {
    case notADirectory
    case missingScreenplayFile
    case invalidJSON(String)
    case unsupportedVersion(String)

    public var errorDescription: String? {
        switch self {
        case .notADirectory:
            return "TextPack file is not a directory bundle"
        case .missingScreenplayFile:
            return "TextPack bundle is missing screenplay.fountain file"
        case .invalidJSON(let filename):
            return "Invalid JSON in file: \(filename)"
        case .unsupportedVersion(let version):
            return "Unsupported TextPack version: \(version)"
        }
    }
}
