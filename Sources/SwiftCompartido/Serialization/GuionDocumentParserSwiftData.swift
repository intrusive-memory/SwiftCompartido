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

    /// Parse a GuionParsedElementCollection into SwiftData models
    /// - Parameters:
    ///   - script: The GuionParsedElementCollection to parse
    ///   - modelContext: The ModelContext to use
    ///   - generateSummaries: Whether to generate AI summaries for scene headings (default: false)
    /// - Returns: The created GuionDocumentModel
    @MainActor
    public static func parse(script: GuionParsedElementCollection, in modelContext: ModelContext, generateSummaries: Bool = false) async -> GuionDocumentModel {
        return await parse(script: script, in: modelContext, generateSummaries: generateSummaries, progress: nil)
    }

    /// Parse a GuionParsedElementCollection into SwiftData models with progress reporting
    ///
    /// This method provides progress updates during element conversion and optional
    /// AI summary generation for scene headings.
    ///
    /// - Parameters:
    ///   - script: The GuionParsedElementCollection to parse
    ///   - modelContext: The ModelContext to use
    ///   - generateSummaries: Whether to generate AI summaries for scene headings (default: false)
    ///   - progress: Optional progress tracker for monitoring conversion progress
    ///
    /// - Returns: The created GuionDocumentModel
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let progress = OperationProgress(totalUnits: Int64(screenplay.elements.count)) { update in
    ///     print("Converting: \(update.description)")
    /// }
    ///
    /// let document = await GuionDocumentParserSwiftData.parse(
    ///     script: screenplay,
    ///     in: modelContext,
    ///     generateSummaries: true,
    ///     progress: progress
    /// )
    /// ```
    @MainActor
    public static func parse(
        script: GuionParsedElementCollection,
        in modelContext: ModelContext,
        generateSummaries: Bool = false,
        progress: OperationProgress?
    ) async -> GuionDocumentModel {
        // Use the new conversion method from GuionDocumentModel
        return await GuionDocumentModel.from(script, in: modelContext, generateSummaries: generateSummaries, progress: progress)
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
        return try await loadAndParse(from: url, in: modelContext, generateSummaries: generateSummaries, progress: nil)
    }

    /// Load a guion document from URL and parse into SwiftData with progress reporting
    /// - Parameters:
    ///   - url: The URL of the document
    ///   - modelContext: The ModelContext to use
    ///   - generateSummaries: Whether to generate AI summaries for scene headings (default: false)
    ///   - progress: Optional progress tracker for monitoring load and conversion progress
    /// - Returns: The created GuionDocumentModel
    /// - Throws: Parsing errors
    @MainActor
    public static func loadAndParse(
        from url: URL,
        in modelContext: ModelContext,
        generateSummaries: Bool = false,
        progress: OperationProgress?
    ) async throws -> GuionDocumentModel {
        let pathExtension = url.pathExtension.lowercased()

        switch pathExtension {
        case "highland":
            let script = try GuionParsedElementCollection(highland: url)
            return await parse(script: script, in: modelContext, generateSummaries: generateSummaries, progress: progress)
        case "textbundle":
            let script = try GuionParsedElementCollection(textBundle: url)
            return await parse(script: script, in: modelContext, generateSummaries: generateSummaries, progress: progress)
        case "fountain":
            let script = try await GuionParsedElementCollection(file: url.path, progress: progress)
            return await parse(script: script, in: modelContext, generateSummaries: generateSummaries, progress: progress)
        case "fdx":
            let data = try Data(contentsOf: url)
            let parser = FDXParser()
            do {
                let parsed = try parser.parse(data: data, filename: url.lastPathComponent)

                // Convert FDX parsed document to GuionParsedElementCollection
                let elements = parsed.elements.map { GuionElement(from: $0) }

                // Convert title page entries to the expected format
                var titlePageDict: [String: [String]] = [:]
                for entry in parsed.titlePageEntries {
                    titlePageDict[entry.key] = entry.values
                }
                let titlePage = titlePageDict.isEmpty ? [] : [titlePageDict]

                let screenplay = GuionParsedElementCollection(
                    filename: parsed.filename,
                    elements: elements,
                    titlePage: titlePage,
                    suppressSceneNumbers: parsed.suppressSceneNumbers
                )

                // Use the new conversion method with progress
                return await GuionDocumentModel.from(screenplay, in: modelContext, generateSummaries: generateSummaries, progress: progress)
            } catch {
                throw GuionDocumentParserError.invalidFDX
            }
        default:
            throw GuionDocumentParserError.unsupportedFileType(pathExtension)
        }
    }

    /// Convert a SwiftData model back to a GuionParsedElementCollection
    /// - Parameter model: The GuionDocumentModel to convert
    /// - Returns: A GuionParsedElementCollection instance
    public static func toFountainScript(from model: GuionDocumentModel) -> GuionParsedElementCollection {
        // Use the new conversion method from GuionDocumentModel
        return model.toGuionParsedElementCollection()
    }

    /// Convert a SwiftData model into FDX data
    /// - Parameter model: The GuionDocumentModel to convert
    /// - Returns: XML data representing the guion in FDX format
    public static func toFDXData(from model: GuionDocumentModel) -> Data {
        return FDXDocumentWriter.makeFDX(from: model)
    }
}
#endif
