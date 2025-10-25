//
//  PDFScreenplayParser.swift
//  SwiftCompartido
//
//  Copyright (c) 2025
//
//  Parses PDF files into screenplay format using PDFKit and Foundation Models.
//

import Foundation
import PDFKit

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Error Types

/// Errors that can occur during PDF screenplay parsing
public enum PDFScreenplayParserError: Error, LocalizedError {
    case unableToOpenPDF
    case emptyPDF
    case textExtractionFailed
    case foundationModelsUnavailable
    case conversionFailed(String)
    case parsingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .unableToOpenPDF:
            return "Unable to open PDF file. The file may be corrupted or password-protected."
        case .emptyPDF:
            return "PDF contains no pages"
        case .textExtractionFailed:
            return "Failed to extract text from PDF. The PDF may contain only images (OCR not yet supported)."
        case .foundationModelsUnavailable:
            return "Foundation Models not available. This feature requires iOS 26+/macOS 26+ with Apple Intelligence enabled."
        case .conversionFailed(let reason):
            return "Failed to convert to screenplay format: \(reason)"
        case .parsingFailed(let error):
            return "Failed to parse screenplay: \(error.localizedDescription)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unableToOpenPDF:
            return "Verify the PDF file is not corrupted and try again."
        case .emptyPDF:
            return "Ensure the PDF contains screenplay content."
        case .textExtractionFailed:
            return "Try exporting the PDF with embedded text, or use a different PDF source."
        case .foundationModelsUnavailable:
            return "Update to iOS 26+/macOS 26+ and enable Apple Intelligence in Settings."
        case .conversionFailed:
            return "The PDF content may not be in a recognizable screenplay format."
        case .parsingFailed:
            return "The conversion to Fountain format may have produced invalid syntax."
        }
    }
}

// MARK: - PDFScreenplayParser

/// Parses PDF files into screenplay format using PDFKit and Foundation Models
///
/// ## Overview
///
/// PDFScreenplayParser extracts text from PDF files and converts it to
/// Fountain-formatted screenplays using Apple's on-device language model.
///
/// ## Requirements
///
/// - iOS 26+ / Mac Catalyst 26+
/// - PDFKit available on both platforms
/// - Foundation Models for AI conversion (optional)
///
/// ## Usage
///
/// ```swift
/// // Simple usage
/// let screenplay = try await PDFScreenplayParser.parse(from: pdfURL)
///
/// // With progress tracking
/// let progress = OperationProgress(totalUnits: 100) { update in
///     print("\(update.description) - \(Int((update.fractionCompleted ?? 0) * 100))%")
/// }
/// let screenplay = try await PDFScreenplayParser.parse(
///     from: pdfURL,
///     progress: progress
/// )
/// ```
@available(iOS 26.0, macCatalyst 26.0, *)
public final class PDFScreenplayParser {

    // MARK: - Public API

    /// Parse a PDF file into a screenplay
    ///
    /// This method performs a three-phase workflow:
    /// 1. Extract text from PDF using PDFKit (20% of progress)
    /// 2. Convert to Fountain format using Foundation Models (60% of progress)
    /// 3. Parse Fountain into screenplay structure (20% of progress)
    ///
    /// - Parameters:
    ///   - url: URL to the PDF file
    ///   - progress: Optional progress reporting
    /// - Returns: Parsed screenplay collection
    /// - Throws: `PDFScreenplayParserError` for various failure conditions
    public static func parse(
        from url: URL,
        progress: OperationProgress? = nil
    ) async throws -> GuionParsedElementCollection {

        // Phase 1: Extract text from PDF (20%)
        progress?.update(completedUnits: 0, description: "Extracting text from PDF...", force: true)
        let pdfText = try extractText(from: url, progress: progress)
        progress?.update(completedUnits: 20, description: "Text extracted", force: true)

        // Phase 2: Convert to Fountain using Foundation Models (60%)
        progress?.update(completedUnits: 20, description: "Converting to screenplay format...", force: true)
        let fountainText = try await convertToFountain(pdfText, progress: progress)
        progress?.update(completedUnits: 80, description: "Conversion complete", force: true)

        // Phase 3: Parse Fountain into screenplay (20%)
        progress?.update(completedUnits: 80, description: "Parsing screenplay elements...", force: true)
        do {
            let screenplay = try await GuionParsedElementCollection(
                string: fountainText,
                progress: progress
            )
            progress?.complete(description: "Screenplay parsed successfully")
            return screenplay
        } catch {
            throw PDFScreenplayParserError.parsingFailed(error)
        }
    }

    // MARK: - Private Implementation

    /// Extract text from all pages of a PDF
    ///
    /// - Parameters:
    ///   - pdfURL: URL to the PDF file
    ///   - progress: Optional progress reporting for page-by-page extraction
    /// - Returns: Extracted text from all pages
    /// - Throws: `PDFScreenplayParserError` if PDF cannot be read or contains no text
    private static func extractText(
        from pdfURL: URL,
        progress: OperationProgress? = nil
    ) throws -> String {

        // Validate file exists
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            throw PDFScreenplayParserError.unableToOpenPDF
        }

        // Open PDF document
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw PDFScreenplayParserError.unableToOpenPDF
        }

        // Check for empty PDF
        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw PDFScreenplayParserError.emptyPDF
        }

        // Note: Progress is managed by parent parse() method
        // We report sub-progress within the extraction phase if needed

        // Extract text from all pages
        var fullText = ""
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            if let pageText = page.string {
                fullText += pageText + "\n\n"
            }

            // Report progress for each page (within 0-20% range)
            if pageCount > 1 {
                let pageProgress = Int64((Double(pageIndex + 1) / Double(pageCount)) * 20.0)
                progress?.update(
                    completedUnits: pageProgress,
                    description: "Reading page \(pageIndex + 1) of \(pageCount)..."
                )
            }
        }

        // Validate we got text
        let trimmedText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw PDFScreenplayParserError.textExtractionFailed
        }

        return fullText
    }

    /// Convert extracted text to Fountain format using Foundation Models
    ///
    /// - Parameters:
    ///   - text: Extracted PDF text
    ///   - progress: Optional progress reporting
    /// - Returns: Text formatted as Fountain screenplay
    /// - Throws: `PDFScreenplayParserError` if conversion fails
    private static func convertToFountain(
        _ text: String,
        progress: OperationProgress?
    ) async throws -> String {

        #if canImport(FoundationModels)
        // TODO: Implement Foundation Models API when available
        // For now, use basic preprocessing
        return await convertToFountainBasic(text, progress: progress)
        #else
        // Foundation Models not available
        throw PDFScreenplayParserError.foundationModelsUnavailable
        #endif
    }

    /// Basic conversion to Fountain format (fallback without Foundation Models)
    ///
    /// This applies heuristic rules to detect screenplay structure:
    /// - Scene headings (INT./EXT. patterns)
    /// - Character names (ALL CAPS lines)
    /// - Dialogue (text following character names)
    /// - Action (paragraph text)
    ///
    /// - Parameters:
    ///   - text: Extracted PDF text
    ///   - progress: Optional progress reporting
    /// - Returns: Best-effort Fountain formatting
    private static func convertToFountainBasic(
        _ text: String,
        progress: OperationProgress?
    ) async -> String {

        // Report progress for conversion phase (within 20-80% range)
        progress?.update(completedUnits: 40, description: "Applying screenplay formatting...", force: true)

        // Clean up the text
        var lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // Apply heuristic formatting
        var formattedLines: [String] = []

        for line in lines {
            guard !line.isEmpty else {
                formattedLines.append("")
                continue
            }

            // Detect scene headings (INT./EXT. in all caps at start)
            if line.range(of: "^(INT\\.|EXT\\.|INT/EXT\\.|I/E\\.)", options: .regularExpression) != nil {
                // Ensure scene heading has proper spacing
                if let last = formattedLines.last, !last.isEmpty {
                    formattedLines.append("")
                }
                formattedLines.append(line.uppercased())
                formattedLines.append("")
                continue
            }

            // Detect character names (short ALL CAPS lines, not starting with INT/EXT)
            let isAllCaps = line == line.uppercased()
            let isShort = line.count < 40
            let hasLetters = line.rangeOfCharacter(from: .letters) != nil

            if isAllCaps && isShort && hasLetters && !line.hasPrefix("INT") && !line.hasPrefix("EXT") {
                // Likely a character name
                if let last = formattedLines.last, !last.isEmpty {
                    formattedLines.append("")
                }
                formattedLines.append(line)
                continue
            }

            // Everything else is likely action or dialogue
            formattedLines.append(line)
        }

        return formattedLines.joined(separator: "\n")
    }

    /// Build the Foundation Models prompt for converting text to Fountain
    ///
    /// - Parameter text: The extracted PDF text
    /// - Returns: Formatted prompt for the language model
    private static func buildConversionPrompt(_ text: String) -> String {
        return """
        Convert this screenplay text to Fountain format. Follow these rules:

        SCENE HEADINGS:
        - Format as: INT./EXT. LOCATION - TIME OF DAY
        - Always in ALL CAPS
        - Examples: INT. COFFEE SHOP - DAY, EXT. PARK - NIGHT

        CHARACTER NAMES:
        - Always in ALL CAPS
        - On their own line above dialogue
        - Examples: JOHN, SARAH, VOICE OVER

        DIALOGUE:
        - Plain text below character name
        - No special formatting needed

        PARENTHETICALS:
        - Wrapped in (parentheses)
        - On their own line within dialogue
        - Examples: (laughing), (to Sarah), (into phone)

        ACTION:
        - Plain text paragraphs
        - Between other elements
        - Describe what happens on screen

        TRANSITIONS:
        - End with colon
        - Examples: CUT TO:, FADE OUT., DISSOLVE TO:

        SECTION HEADINGS:
        - Use # for acts (# ACT ONE)
        - Use ## for sequences (## OPENING SEQUENCE)
        - Use ### for scene groups (### THE HEIST)

        IMPORTANT:
        - Preserve all dialogue word-for-word
        - Preserve all story content
        - Only reformat to valid Fountain syntax
        - Ensure proper spacing between elements

        Original text:
        \(text)
        """
    }
}
