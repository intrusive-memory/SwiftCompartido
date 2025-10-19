//
//  GuionDocumentParserSwiftData.swift
//  SwiftFountain
//

import Foundation
#if canImport(SwiftData)
import SwiftData

// GuionElementSnapshot is now obsolete - use GuionElement directly with protocol-based conversion
// GuionTitleEntrySnapshot is now obsolete - use TitlePageEntryModel directly

public enum GuionDocumentParserError: Error {
    case unsupportedFileType(String)
    case invalidFDX
}

public class GuionDocumentParserSwiftData {

    /// Parse a GuionParsedScreenplay into SwiftData models
    /// - Parameters:
    ///   - script: The GuionParsedScreenplay to parse
    ///   - modelContext: The ModelContext to use
    ///   - generateSummaries: Whether to generate AI summaries for scene headings (default: false)
    /// - Returns: The created GuionDocumentModel
    @MainActor
    public static func parse(script: GuionParsedScreenplay, in modelContext: ModelContext, generateSummaries: Bool = false) async -> GuionDocumentModel {
        // Use the new conversion method from GuionDocumentModel
        return await GuionDocumentModel.from(script, in: modelContext, generateSummaries: generateSummaries)
    }

    /// Load a guion document from URL and parse into SwiftData
    /// - Parameters:
    ///   - url: The URL of the document
    ///   - modelContext: The ModelContext to use
    ///   - generateSummaries: Whether to generate AI summaries for scene headings (default: false)
    /// - Returns: The created GuionDocumentModel
    /// - Throws: Parsing errors
    @MainActor
    public static func loadAndParse(from url: URL, in modelContext: ModelContext, generateSummaries: Bool = false) async throws -> GuionDocumentModel {
        let pathExtension = url.pathExtension.lowercased()

        switch pathExtension {
        case "highland":
            let script = try GuionParsedScreenplay(highland: url)
            return await parse(script: script, in: modelContext, generateSummaries: generateSummaries)
        case "textbundle":
            let script = try GuionParsedScreenplay(textBundle: url)
            return await parse(script: script, in: modelContext, generateSummaries: generateSummaries)
        case "fountain":
            let script = try GuionParsedScreenplay(file: url.path)
            return await parse(script: script, in: modelContext, generateSummaries: generateSummaries)
        case "fdx":
            let data = try Data(contentsOf: url)
            let parser = FDXParser()
            do {
                let parsed = try parser.parse(data: data, filename: url.lastPathComponent)

                // Convert FDX parsed document to GuionParsedScreenplay
                let elements = parsed.elements.map { GuionElement(from: $0) }

                // Convert title page entries to the expected format
                var titlePageDict: [String: [String]] = [:]
                for entry in parsed.titlePageEntries {
                    titlePageDict[entry.key] = entry.values
                }
                let titlePage = titlePageDict.isEmpty ? [] : [titlePageDict]

                let screenplay = GuionParsedScreenplay(
                    filename: parsed.filename,
                    elements: elements,
                    titlePage: titlePage,
                    suppressSceneNumbers: parsed.suppressSceneNumbers
                )

                // Use the new conversion method
                return await GuionDocumentModel.from(screenplay, in: modelContext, generateSummaries: generateSummaries)
            } catch {
                throw GuionDocumentParserError.invalidFDX
            }
        default:
            throw GuionDocumentParserError.unsupportedFileType(pathExtension)
        }
    }

    /// Convert a SwiftData model back to a GuionParsedScreenplay
    /// - Parameter model: The GuionDocumentModel to convert
    /// - Returns: A GuionParsedScreenplay instance
    public static func toFountainScript(from model: GuionDocumentModel) -> GuionParsedScreenplay {
        // Use the new conversion method from GuionDocumentModel
        return model.toGuionParsedScreenplay()
    }

    /// Convert a SwiftData model into FDX data
    /// - Parameter model: The GuionDocumentModel to convert
    /// - Returns: XML data representing the guion in FDX format
    public static func toFDXData(from model: GuionDocumentModel) -> Data {
        return FDXDocumentWriter.makeFDX(from: model)
    }
}
#endif
