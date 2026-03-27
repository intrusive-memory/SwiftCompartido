//
//  PandocDocumentParser.swift
//  SwiftCompartido
//
//  Universal document parser using bundled Pandoc converter.
//  Supports: DOCX, ODT, RTF (macOS only)
//

import Foundation

/// Universal document parser using bundled Pandoc converter.
///
/// This parser converts document formats (DOCX, ODT, RTF) to Markdown via Pandoc,
/// then parses the Markdown into screenplay elements with GitHub-style rendering.
///
/// **Supported formats:**
/// - DOCX: Microsoft Word 2007+ (Office Open XML)
/// - ODT: OpenDocument Text (LibreOffice, Google Docs)
/// - RTF: Rich Text Format (Universal compatibility)
///
/// **Platform availability**: macOS only (Process API not available on iOS)
///
/// ## Example
///
/// ```swift
/// let docxUrl = URL(fileURLWithPath: "screenplay.docx")
/// let (elements, titlePage) = try PandocDocumentParser.parse(url: docxUrl)
/// ```
///
public enum PandocDocumentParser {

  /// Supported file extensions
  public static let supportedExtensions = ["docx", "odt", "rtf"]

  /// Parse a document file into screenplay elements and metadata.
  ///
  /// Automatically detects format from file extension and uses appropriate
  /// Pandoc input format for conversion.
  ///
  /// - Parameter url: URL to the document file (.docx, .odt, or .rtf)
  /// - Returns: Tuple containing:
  ///   - elements: Array of GuionElement objects
  ///   - titlePage: Array of dictionaries with document metadata
  /// - Throws: Error if the file cannot be read or parsed
  public static func parse(url: URL) throws -> (
    elements: [GuionElement],
    titlePage: [[String: [String]]]
  ) {
    #if os(macOS)
      // Detect format from extension
      let ext = url.pathExtension.lowercased()
      guard supportedExtensions.contains(ext) else {
        throw PandocParserError.unsupportedFormat(ext)
      }

      // Find Pandoc binary
      guard let pandocPath = getPandocPath() else {
        throw PandocParserError.pandocNotAvailable
      }

      // Convert to markdown using Pandoc
      let markdown = try convertToMarkdown(
        documentUrl: url,
        inputFormat: ext,
        pandocPath: pandocPath
      )

      // Parse markdown using existing MarkdownParser
      let (elements, titlePage, _) = try MarkdownParser.parse(markdown)
      return (elements, titlePage)
    #else
      // iOS doesn't support Process - document import not available
      throw PandocParserError.platformNotSupported
    #endif
  }

  /// Check if Pandoc is available on the system.
  ///
  /// Checks for bundled Pandoc first, then falls back to system installation.
  ///
  /// - Returns: True if Pandoc is available, false otherwise
  public static func isPandocAvailable() -> Bool {
    #if os(macOS)
      return getPandocPath() != nil
    #else
      return false
    #endif
  }

  // MARK: - Private Methods

  #if os(macOS)
    /// Get the path to the Pandoc binary.
    ///
    /// Checks in this order:
    /// 1. Bundled Pandoc in app resources
    /// 2. System Pandoc in common installation locations
    ///
    /// - Returns: URL to Pandoc binary, or nil if not found
    private static func getPandocPath() -> URL? {
      // 1. Check for bundled Pandoc (production)
      if let bundled = Bundle.main.url(
        forResource: "pandoc",
        withExtension: nil,
        subdirectory: "Binaries"
      ) {
        return bundled
      }

      // 2. Fallback to system Pandoc (development)
      let systemPaths = [
        "/opt/homebrew/bin/pandoc",  // Apple Silicon Homebrew
        "/usr/local/bin/pandoc",  // Intel Homebrew
        "/usr/bin/pandoc",  // System installation
      ]

      for path in systemPaths {
        if FileManager.default.fileExists(atPath: path) {
          return URL(fileURLWithPath: path)
        }
      }

      return nil
    }

    /// Convert a document to Markdown using Pandoc.
    ///
    /// - Parameters:
    ///   - documentUrl: URL to the source document
    ///   - inputFormat: Pandoc input format ("docx", "odt", or "rtf")
    ///   - pandocPath: URL to the Pandoc binary
    /// - Returns: Markdown string
    /// - Throws: PandocParserError if conversion fails
    private static func convertToMarkdown(
      documentUrl: URL,
      inputFormat: String,
      pandocPath: URL
    ) throws -> String {
      let process = Process()
      process.executableURL = pandocPath
      process.arguments = [
        "-f", inputFormat,  // Input format
        "-t", "markdown",  // Output format
        "--standalone",  // Include metadata
        "--wrap=preserve",  // Don't wrap long lines
        documentUrl.path,  // Input file
      ]

      let outputPipe = Pipe()
      let errorPipe = Pipe()
      process.standardOutput = outputPipe
      process.standardError = errorPipe

      try process.run()
      process.waitUntilExit()

      guard process.terminationStatus == 0 else {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
        throw PandocParserError.conversionFailed(errorMessage)
      }

      let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
      guard let markdown = String(data: data, encoding: .utf8) else {
        throw PandocParserError.invalidEncoding
      }

      return markdown
    }
  #endif
}

/// Errors that can occur during Pandoc document parsing.
public enum PandocParserError: LocalizedError {
  case pandocNotAvailable
  case unsupportedFormat(String)
  case conversionFailed(String)
  case invalidEncoding
  case corruptedFile
  case passwordProtected
  case platformNotSupported

  public var errorDescription: String? {
    switch self {
    case .pandocNotAvailable:
      return "Document converter not available. Please reinstall the application."
    case .unsupportedFormat(let ext):
      return "Unsupported file format: .\(ext). Supported formats: DOCX, ODT, RTF"
    case .conversionFailed(let message):
      return "Failed to convert document: \(message)"
    case .invalidEncoding:
      return "Invalid text encoding in converted document"
    case .corruptedFile:
      return "File appears to be corrupted"
    case .passwordProtected:
      return "Password-protected files are not supported"
    case .platformNotSupported:
      return "Document import is only supported on macOS. iOS support coming in future release."
    }
  }
}
