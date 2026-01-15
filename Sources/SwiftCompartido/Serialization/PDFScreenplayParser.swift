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
    /// This method uses Apple Intelligence to intelligently convert screenplay text
    /// from PDF format to proper Fountain syntax while preserving all content.
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
        // Try Foundation Models first (iOS 26+/macOS 26+ with Apple Intelligence)
        do {
            return try await convertToFountainWithAI(text, progress: progress)
        } catch {
            // If Foundation Models unavailable or fails, fall back to basic conversion
            progress?.update(
                completedUnits: 20,
                description: "Apple Intelligence unavailable, using fallback conversion...",
                additionalInfo: "⚠️ AI-powered parsing unavailable. Falling back to heuristic conversion. Results may be less accurate for non-standard screenplay formats. To enable AI parsing: 1) Enable Apple Intelligence in System Settings, 2) Ensure device has M1+/A17 Pro+ chip, 3) iOS 26.2+ or macOS 26.0+",
                force: true
            )
            return await convertToFountainBasic(text, progress: progress)
        }
        #else
        // Foundation Models not available on this platform
        progress?.update(
            completedUnits: 20,
            description: "Using heuristic screenplay conversion...",
            additionalInfo: "ℹ️ Apple Intelligence not available on this platform. Using heuristic conversion. For AI-powered parsing, upgrade to iOS 26.2+ or macOS 26.0+ with M1+/A17 Pro+ chip.",
            force: true
        )
        return await convertToFountainBasic(text, progress: progress)
        #endif
    }

    /// Convert to Fountain using Foundation Models (Apple Intelligence)
    ///
    /// Uses on-device AI to intelligently parse screenplay structure and convert
    /// to proper Fountain format while preserving all text content.
    ///
    /// **NOTE**: Foundation Models implementation is prepared but currently falls back
    /// to heuristic conversion. The AI-powered conversion will be enabled once the
    /// FoundationModels framework API is finalized in iOS 26/macOS 26 SDK.
    ///
    /// - Parameters:
    ///   - text: Extracted PDF text
    ///   - progress: Optional progress reporting
    /// - Returns: AI-converted Fountain screenplay text
    /// - Throws: `PDFScreenplayParserError` if Foundation Models unavailable or conversion fails
    @available(iOS 26.0, macCatalyst 26.0, *)
    private static func convertToFountainWithAI(
        _ text: String,
        progress: OperationProgress?
    ) async throws -> String {
        #if canImport(FoundationModels)
        progress?.update(
            completedUnits: 30,
            description: "Checking Apple Intelligence availability...",
            force: true
        )

        // Check if the system language model is available
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw PDFScreenplayParserError.foundationModelsUnavailable
        }

        progress?.update(
            completedUnits: 35,
            description: "Analyzing screenplay structure with Apple Intelligence...",
            force: true
        )

        // Build the system prompt that teaches the model Fountain format
        let systemPrompt = buildFountainConversionPrompt()

        // Build the user prompt with the extracted text
        let userPrompt = """
        Convert the following screenplay text to Fountain format. Preserve ALL text exactly as written, including all dialogue, action, character names, scene headings, and transitions. Maintain the original story order and content.

        CRITICAL: Your output MUST be in valid Fountain screenplay format. Do NOT include any explanations, markdown formatting, code blocks, or additional text. Output ONLY the Fountain-formatted screenplay text, starting immediately with the screenplay content.

        PDF TEXT:
        \(text)

        OUTPUT (Fountain format only, no explanations):
        """

        progress?.update(
            completedUnits: 40,
            description: "Converting to Fountain format with AI...",
            force: true
        )

        // Create a language model session with the system prompt
        let session = LanguageModelSession(
            model: model,
            instructions: systemPrompt
        )

        progress?.update(
            completedUnits: 50,
            description: "Generating Fountain screenplay...",
            force: true
        )

        // Generate the Fountain format using the AI model
        let response = try await session.respond(to: Prompt(userPrompt))

        progress?.update(
            completedUnits: 75,
            description: "AI conversion complete",
            force: true
        )

        return response.content

        #else
        throw PDFScreenplayParserError.foundationModelsUnavailable
        #endif
    }

    /// Build the system prompt that teaches Foundation Models how to convert to Fountain format
    ///
    /// This prompt provides comprehensive Fountain syntax rules so the AI can accurately
    /// convert screenplay text while preserving all content.
    ///
    /// - Returns: System prompt string with Fountain format instructions
    private static func buildFountainConversionPrompt() -> String {
        return """
        You are a screenplay formatting expert. Your task is to convert screenplay text extracted from PDF files into proper Fountain format.

        CRITICAL RULES:
        1. Preserve ALL text exactly as written - do not summarize, omit, or add content
        2. Maintain the original story order and scene sequence
        3. Keep all dialogue word-for-word
        4. Preserve all action descriptions verbatim
        5. Output ONLY the Fountain-formatted screenplay - no explanations or comments

        FOUNTAIN FORMAT RULES:

        SCENE HEADINGS:
        - Start with INT. or EXT. or INT./EXT. or I/E.
        - Must be in ALL CAPS
        - Example: INT. BEDROOM - NIGHT
        - Always on their own line with blank line before and after

        ACTION:
        - Regular text describing what happens
        - Full sentences, proper capitalization
        - Blank line before and after paragraphs
        - Example: John walks into the room. He looks around nervously.

        CHARACTER NAMES:
        - ALL CAPS
        - On their own line before dialogue
        - Can include (V.O.) or (O.S.) for voice over or off-screen
        - Example: JOHN
        - Example: MARY (V.O.)

        DIALOGUE:
        - Immediately follows character name
        - Regular capitalization
        - Can span multiple lines
        - Example:
        JOHN
        I can't believe this is happening.

        PARENTHETICALS:
        - Goes between character name and dialogue
        - Wrapped in parentheses
        - Describes how dialogue is delivered
        - Example:
        JOHN
        (whispering)
        We need to leave now.

        TRANSITIONS:
        - Right-aligned by using > at start
        - ALL CAPS
        - Example: > FADE TO:
        - Example: > CUT TO:

        CENTERED TEXT:
        - For titles or special formatting
        - Wrapped with > and <
        - Example: > THE END <

        NOTES:
        - Wrapped in [[ ]]
        - For production notes
        - Example: [[This scene was shot on location]]

        FORMATTING:
        - Use blank lines to separate elements
        - Don't add extra markup or markdown formatting
        - Keep the screenplay clean and readable
        - Preserve original line breaks in dialogue

        COMMON PDF EXTRACTION ISSUES TO FIX:
        - Remove page numbers
        - Remove headers and footers
        - Remove "CONTINUED" markers
        - Fix broken scene headings (may be split across lines)
        - Fix broken character names
        - Reassemble dialogue that may be split across pages

        Your goal: Output valid Fountain format that preserves 100% of the screenplay content.
        """
    }

    /// Basic conversion to Fountain format (fallback without Foundation Models)
    ///
    /// This applies heuristic rules to detect screenplay structure:
    /// - Scene headings (INT./EXT. patterns)
    /// - Character names (ALL CAPS lines)
    /// - Dialogue (text following character names)
    /// - Action (paragraph text)
    ///
    /// Also filters out common non-screenplay elements:
    /// - Page numbers
    /// - Headers and footers
    /// - Draft information
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

        // Filter out page numbers and headers/footers
        lines = filterPageNumbersAndHeaders(lines)

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

    /// Filter out page numbers, headers, and footers from extracted PDF lines
    ///
    /// Common patterns filtered:
    /// - Simple page numbers (1, 2, 123, etc.)
    /// - "Page X" formats
    /// - Numbers with dots or periods (1., 2., etc.)
    /// - Draft information (DRAFT, FINAL DRAFT, dates)
    /// - Very short lines that are likely headers/footers
    /// - Lines with only punctuation or numbers
    ///
    /// - Parameter lines: Array of text lines from PDF
    /// - Returns: Filtered array with page numbers and headers removed
    private static func filterPageNumbersAndHeaders(_ lines: [String]) -> [String] {
        return lines.filter { line in
            guard !line.isEmpty else { return true }

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return true }

            // Filter out simple page numbers (just digits, optionally with period)
            let digitsAndPeriod = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))
            if trimmed.trimmingCharacters(in: digitsAndPeriod).isEmpty && trimmed.count < 6 {
                return false
            }

            // Filter out "Page X" patterns
            if trimmed.range(of: "^(Page|PAGE|p\\.|P\\.)\\s*\\d+", options: .regularExpression) != nil {
                return false
            }

            // Filter out common draft markers
            let draftPatterns = [
                "DRAFT", "FINAL DRAFT", "FIRST DRAFT", "SECOND DRAFT", "THIRD DRAFT",
                "REVISED", "SHOOTING SCRIPT", "PRODUCTION DRAFT"
            ]
            let upperTrimmed = trimmed.uppercased()
            for pattern in draftPatterns {
                if upperTrimmed == pattern || upperTrimmed.hasPrefix(pattern + " ") {
                    return false
                }
            }

            // Filter out date-only lines (common in headers)
            // Match patterns like "January 1, 2025" or "01/01/2025" or "1-1-2025"
            if trimmed.range(of: "^\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}$", options: .regularExpression) != nil {
                return false
            }
            if trimmed.range(of: "^(January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{1,2},?\\s+\\d{4}$", options: [.regularExpression, .caseInsensitive]) != nil {
                return false
            }

            // Filter out very short lines (likely headers/footers) unless they look like character names or scene elements
            if trimmed.count < 3 {
                return false
            }

            // Keep the line
            return true
        }
    }

    /// Build the Foundation Models prompt for converting text to Fountain
}
