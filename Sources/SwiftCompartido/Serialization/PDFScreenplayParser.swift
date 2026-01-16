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

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Types

/// Formatted text extracted from a PDF page with layout and style information
private struct PDFPageContent {
    let plainText: String
    let formattedText: String  // Text with formatting annotations
    let pageNumber: Int

    /// Create formatted text representation from attributed string
    static func from(page: PDFPage, pageNumber: Int) -> PDFPageContent {
        let plainText = page.string ?? ""

        // Try to get attributed string for formatting information
        guard let attributedString = page.attributedString else {
            return PDFPageContent(plainText: plainText, formattedText: plainText, pageNumber: pageNumber)
        }

        // Build formatted representation with style annotations
        var formattedText = ""
        let fullRange = NSRange(location: 0, length: attributedString.length)

        attributedString.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
            let substring = (attributedString.string as NSString).substring(with: range)

            // Skip empty strings
            guard !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                formattedText.append(substring)
                return
            }

            // Extract font information
            var styleAnnotations: [String] = []

            #if os(macOS)
            if let font = attributes[.font] as? NSFont {
                // Check for bold
                if font.fontDescriptor.symbolicTraits.contains(.bold) {
                    styleAnnotations.append("BOLD")
                }
                // Check for italic
                if font.fontDescriptor.symbolicTraits.contains(.italic) {
                    styleAnnotations.append("ITALIC")
                }
                // Note larger fonts (potential headings)
                if font.pointSize > 13 {
                    styleAnnotations.append("LARGE")
                }
            }
            #elseif os(iOS)
            if let font = attributes[.font] as? UIFont {
                // Check for bold
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    styleAnnotations.append("BOLD")
                }
                // Check for italic
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    styleAnnotations.append("ITALIC")
                }
                // Note larger fonts (potential headings)
                if font.pointSize > 13 {
                    styleAnnotations.append("LARGE")
                }
            }
            #endif

            // Check for all caps (common in scene headings and character names)
            let trimmed = substring.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed == trimmed.uppercased() && trimmed != trimmed.lowercased() {
                styleAnnotations.append("CAPS")
            }

            // Append text with style annotations if present
            if !styleAnnotations.isEmpty {
                formattedText.append("[\(styleAnnotations.joined(separator: ","))]")
            }
            formattedText.append(substring)
        }

        return PDFPageContent(
            plainText: plainText,
            formattedText: formattedText,
            pageNumber: pageNumber
        )
    }
}

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
    /// 1. Extract text from PDF page-by-page using PDFKit (20% of progress)
    /// 2. Convert each page to Fountain format using Foundation Models (60% of progress)
    /// 3. Parse Fountain into screenplay structure (20% of progress)
    ///
    /// **Page-by-Page Processing:**
    /// PDFs are processed one page at a time through Apple Intelligence to avoid
    /// token limits (4,096 tokens per request). Each page is typically 500-1,000 tokens,
    /// well within limits. Results are concatenated into final Fountain screenplay.
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

        // Phase 1: Extract text from PDF page-by-page (20%)
        progress?.update(completedUnits: 0, description: "Extracting text from PDF...", force: true)
        let pages = try extractPages(from: url, progress: progress)
        progress?.update(completedUnits: 20, description: "Text extracted from \(pages.count) pages", force: true)

        #if DEBUG
        print("📄 [PDFParser] Extracted \(pages.count) pages from PDF")
        #endif

        // Phase 2: Convert pages to Fountain using Foundation Models (60%)
        progress?.update(completedUnits: 20, description: "Converting to screenplay format...", force: true)
        let fountainText = try await convertPagesToFountain(pages, progress: progress)
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

    /// Extract formatted content from all pages of a PDF
    ///
    /// This returns an array of PDFPageContent with both plain text and formatting information,
    /// enabling page-by-page AI processing with richer context to avoid token limits.
    ///
    /// - Parameters:
    ///   - pdfURL: URL to the PDF file
    ///   - progress: Optional progress reporting for page-by-page extraction
    /// - Returns: Array of page content with formatting information
    /// - Throws: `PDFScreenplayParserError` if PDF cannot be read or contains no text
    private static func extractPages(
        from pdfURL: URL,
        progress: OperationProgress? = nil
    ) throws -> [PDFPageContent] {

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

        #if DEBUG
        print("📄 [PDFParser] Extracting formatted content from \(pageCount) pages")
        #endif

        // Extract formatted content from all pages
        var pages: [PDFPageContent] = []
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                #if DEBUG
                print("⚠️ [PDFParser] Could not access page \(pageIndex + 1)")
                #endif
                continue
            }

            let pageContent = PDFPageContent.from(page: page, pageNumber: pageIndex + 1)

            // Only include pages with actual content
            if !pageContent.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pages.append(pageContent)

                #if DEBUG
                let charCount = pageContent.plainText.count
                let formattedCharCount = pageContent.formattedText.count
                let tokenEstimate = formattedCharCount / 3 // Rough estimate: 1 token ≈ 3 chars
                print("📄 [PDFParser] Page \(pageIndex + 1): \(charCount) chars plain, \(formattedCharCount) chars formatted (~\(tokenEstimate) tokens)")
                #endif
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

        // Validate we got content from at least one page
        guard !pages.isEmpty else {
            throw PDFScreenplayParserError.textExtractionFailed
        }

        #if DEBUG
        print("✅ [PDFParser] Successfully extracted \(pages.count) pages with formatting")
        #endif

        return pages
    }

    /// Convert pages to Fountain format using page-by-page AI processing
    ///
    /// This method processes each page individually through Apple Intelligence
    /// to avoid the 4,096 token context window limit. Results are concatenated
    /// into a complete Fountain screenplay.
    ///
    /// **Formatting Information:**
    /// Uses attributed string data (font, style, caps) to help AI recognize
    /// screenplay elements more accurately than plain text alone.
    ///
    /// **Error Handling:**
    /// - If AI fails on a few pages, they're converted with heuristics
    /// - If AI fails on >50% of pages, entire document falls back to heuristics
    /// - Individual page failures don't stop the overall conversion
    ///
    /// - Parameters:
    ///   - pages: Array of page content with formatting extracted from PDF
    ///   - progress: Optional progress reporting (updated per-page)
    /// - Returns: Complete Fountain-formatted screenplay
    /// - Throws: `PDFScreenplayParserError` if conversion fails completely
    private static func convertPagesToFountain(
        _ pages: [PDFPageContent],
        progress: OperationProgress?
    ) async throws -> String {
        #if canImport(FoundationModels)
        #if DEBUG
        print("🔍 [PDFParser] convertPagesToFountain: Processing \(pages.count) pages")
        print("🔍 [PDFParser] FoundationModels available, attempting page-by-page AI conversion")
        #endif

        // Try page-by-page AI conversion
        var convertedPages: [String] = []
        var failedPages = 0
        let totalPages = pages.count

        for (index, pageContent) in pages.enumerated() {
            let pageNumber = index + 1

            // Update progress for this page (within 20-80% range)
            let baseProgress: Int64 = 20
            let rangeSize: Int64 = 60
            let pageProgress = baseProgress + Int64((Double(rangeSize) * Double(pageNumber)) / Double(totalPages))
            progress?.update(
                completedUnits: pageProgress,
                description: "Converting page \(pageNumber) of \(totalPages)...",
                force: true
            )

            // Try AI conversion for this page with formatting info
            do {
                let convertedPage = try await convertPageToFountainWithAI(pageContent)
                convertedPages.append(convertedPage)

                #if DEBUG
                print("✅ [PDFParser] Page \(pageNumber) converted with AI (using formatting)")
                #endif
            } catch {
                // This page failed - try basic conversion as fallback
                failedPages += 1

                #if DEBUG
                print("⚠️ [PDFParser] Page \(pageNumber) AI conversion failed: \(error)")
                print("⚠️ [PDFParser] Using heuristic conversion for page \(pageNumber)")
                #endif

                let basicPage = await convertPageToFountainBasic(pageContent.plainText)
                convertedPages.append(basicPage)
            }
        }

        // If more than 50% of pages failed AI conversion, consider it a failure
        let failureRate = Double(failedPages) / Double(totalPages)
        if failureRate > 0.5 {
            #if DEBUG
            print("⚠️ [PDFParser] High AI failure rate (\(failedPages)/\(totalPages) pages)")
            print("⚠️ [PDFParser] Falling back to full basic conversion")
            #endif

            progress?.update(
                completedUnits: 20,
                description: "Apple Intelligence unavailable, using fallback conversion...",
                additionalInfo: "⚠️ AI-powered parsing unavailable for this document. Falling back to heuristic conversion. Results may be less accurate for non-standard screenplay formats.",
                force: true
            )

            // Re-process all pages with basic conversion for consistency
            return await convertAllPagesToFountainBasic(pages, progress: progress)
        }

        #if DEBUG
        print("✅ [PDFParser] Page-by-page AI conversion succeeded")
        print("✅ [PDFParser] Success: \(totalPages - failedPages)/\(totalPages) pages")
        print("✅ [PDFParser] Failed: \(failedPages)/\(totalPages) pages (used heuristics)")
        #endif

        // Concatenate all converted pages with page breaks
        let fountainText = convertedPages.joined(separator: "\n\n")
        return fountainText

        #else
        #if DEBUG
        print("ℹ️ [PDFParser] convertPagesToFountain: FoundationModels NOT available at compile time")
        print("ℹ️ [PDFParser] Using basic conversion for all pages")
        #endif

        // Foundation Models not available on this platform
        progress?.update(
            completedUnits: 20,
            description: "Using heuristic screenplay conversion...",
            additionalInfo: "ℹ️ Apple Intelligence not available on this platform. Using heuristic conversion. For AI-powered parsing, upgrade to iOS 26.2+ or macOS 26.0+ with M1+/A17 Pro+ chip.",
            force: true
        )
        return await convertAllPagesToFountainBasic(pages, progress: progress)
        #endif
    }

    /// Convert a single page to Fountain using Foundation Models (Apple Intelligence)
    ///
    /// Uses on-device AI to intelligently parse screenplay structure and convert
    /// to proper Fountain format while preserving all text content.
    ///
    /// **Formatting-Aware Processing:**
    /// This method uses attributed string data (font styles, caps) to provide
    /// richer context to the AI, improving recognition of screenplay elements.
    ///
    /// **Page-by-Page Processing:**
    /// Designed for single-page conversion to avoid the 4,096 token context window limit.
    /// Average screenplay pages are 500-1,000 tokens, well within the limit.
    ///
    /// - Parameter pageContent: Page content with formatting information
    /// - Returns: AI-converted Fountain screenplay text for this page
    /// - Throws: `PDFScreenplayParserError` if Foundation Models unavailable or conversion fails
    @available(iOS 26.0, macCatalyst 26.0, *)
    private static func convertPageToFountainWithAI(
        _ pageContent: PDFPageContent
    ) async throws -> String {
        #if canImport(FoundationModels)
        #if DEBUG
        print("🤖 [PDFParser] Page \(pageContent.pageNumber): Attempting AI conversion with formatting")
        let charCount = pageContent.formattedText.count
        let tokenEstimate = charCount / 3
        print("🤖 [PDFParser] Page \(pageContent.pageNumber): \(charCount) chars formatted (~\(tokenEstimate) tokens)")
        #endif

        // Check if the system language model is available (cached after first check)
        let model = SystemLanguageModel.default

        guard model.isAvailable else {
            #if DEBUG
            print("❌ [PDFParser] Page \(pageContent.pageNumber): Apple Intelligence NOT available")
            #endif
            throw PDFScreenplayParserError.foundationModelsUnavailable
        }

        // Build the system prompt that teaches the model Fountain format
        let systemPrompt = buildFountainConversionPrompt()

        // Build the user prompt with formatted text
        let userPrompt = """
        Convert the following screenplay page to Fountain format. This is page \(pageContent.pageNumber) of a screenplay. Preserve ALL text exactly as written, including all dialogue, action, character names, scene headings, and transitions.

        CRITICAL: Your output MUST be in valid Fountain screenplay format. Do NOT include any explanations, markdown formatting, code blocks, or additional text. Output ONLY the Fountain-formatted screenplay text, starting immediately with the screenplay content.

        If this page starts mid-scene or mid-dialogue, that's normal - just convert what's present.

        FORMATTING ANNOTATIONS:
        The text below includes formatting annotations in brackets to help you identify screenplay elements:
        - [BOLD] = Bold text (often scene headings)
        - [ITALIC] = Italic text (sometimes used for emphasis)
        - [LARGE] = Larger font (often scene headings or titles)
        - [CAPS] = All uppercase text (scene headings, character names, transitions)

        Use these formatting cues along with screenplay conventions to accurately identify:
        - Scene headings (BOLD + CAPS + starts with INT./EXT.)
        - Character names (CAPS, short lines before dialogue)
        - Dialogue (normal text following character names)
        - Action (normal text, full sentences)
        - Transitions (CAPS, right-aligned cues like "FADE TO:")

        PAGE \(pageContent.pageNumber) TEXT WITH FORMATTING:
        \(pageContent.formattedText)

        OUTPUT (Fountain format only, no explanations):
        """

        // Create a language model session with the system prompt
        let session = LanguageModelSession(
            model: model,
            instructions: systemPrompt
        )

        // Generate the Fountain format using the AI model
        do {
            let response = try await session.respond(to: Prompt(userPrompt))

            #if DEBUG
            print("✅ [PDFParser] Page \(pageContent.pageNumber): AI conversion succeeded")
            print("✅ [PDFParser] Page \(pageContent.pageNumber): Output \(response.content.count) chars")
            #endif

            return response.content
        } catch {
            #if DEBUG
            print("❌ [PDFParser] Page \(pageContent.pageNumber): AI request failed: \(error)")
            if let errorDesc = (error as? LocalizedError)?.errorDescription {
                print("❌ [PDFParser] Page \(pageContent.pageNumber): \(errorDesc)")
            }
            #endif
            throw PDFScreenplayParserError.conversionFailed(error.localizedDescription)
        }

        #else
        #if DEBUG
        print("❌ [PDFParser] FoundationModels not available at compile time")
        #endif
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

    /// Convert a single page to Fountain format using basic heuristics
    ///
    /// This applies the same heuristic rules as `convertToFountainBasic()` but for a single page.
    /// Used as a fallback when AI conversion fails for individual pages.
    ///
    /// - Parameter pageText: Text from a single PDF page
    /// - Returns: Fountain-formatted text for this page
    private static func convertPageToFountainBasic(_ pageText: String) async -> String {
        // Clean up the text
        var lines = pageText.components(separatedBy: .newlines)
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

    /// Convert all pages to Fountain format using basic heuristics
    ///
    /// This is used when AI conversion fails for the majority of pages or when
    /// Foundation Models is not available. Processes all pages with heuristics
    /// and concatenates results.
    ///
    /// - Parameters:
    ///   - pages: Array of page content from PDF
    ///   - progress: Optional progress reporting
    /// - Returns: Complete Fountain-formatted screenplay
    private static func convertAllPagesToFountainBasic(
        _ pages: [PDFPageContent],
        progress: OperationProgress?
    ) async -> String {
        var convertedPages: [String] = []
        let totalPages = pages.count

        for (index, pageContent) in pages.enumerated() {
            let pageNumber = index + 1

            // Update progress for this page (within 20-80% range)
            let baseProgress: Int64 = 20
            let rangeSize: Int64 = 60
            let pageProgress = baseProgress + Int64((Double(rangeSize) * Double(pageNumber)) / Double(totalPages))
            progress?.update(
                completedUnits: pageProgress,
                description: "Converting page \(pageNumber) of \(totalPages) (heuristic)...",
                force: true
            )

            let convertedPage = await convertPageToFountainBasic(pageContent.plainText)
            convertedPages.append(convertedPage)
        }

        return convertedPages.joined(separator: "\n\n")
    }

    /// Build the Foundation Models prompt for converting text to Fountain
}
