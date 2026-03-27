//
//  MediaFileStorage.swift
//  SwiftCompartido
//
//  Utility for handling media file storage, MIME type detection, and security-scoped bookmarks
//

import AVFoundation
import Foundation
import SwiftData
import UniformTypeIdentifiers

#if canImport(AppKit)
  import AppKit
#endif
#if canImport(UIKit)
  import UIKit
#endif

/// Utility for handling media file storage operations
///
/// Provides functionality for:
/// - MIME type detection from file extensions and content
/// - File size-based storage strategy determination
/// - Security-scoped bookmark creation and resolution
/// - Metadata extraction from media files
/// - File validation
public enum MediaFileStorage {

  // MARK: - Constants

  /// File size threshold for determining storage strategy (1MB)
  public static let fileSizeThreshold = 1_000_000

  // MARK: - MIME Type Detection

  /// Detect MIME type from file URL
  ///
  /// - Parameter url: File URL to analyze
  /// - Returns: MIME type string (e.g., "audio/mpeg", "image/jpeg")
  public static func detectMIMEType(from url: URL) -> String {
    let pathExtension = url.pathExtension.lowercased()

    // Use UTType for accurate MIME type detection
    if let utType = UTType(filenameExtension: pathExtension) {
      if let mimeType = utType.preferredMIMEType {
        return mimeType
      }
    }

    // Fallback to manual mapping for common types
    switch pathExtension {
    case "mp3":
      return "audio/mpeg"
    case "wav":
      return "audio/wav"
    case "m4a", "aac":
      return "audio/mp4"
    case "ogg":
      return "audio/ogg"
    case "flac":
      return "audio/flac"
    case "jpg", "jpeg":
      return "image/jpeg"
    case "png":
      return "image/png"
    case "heic":
      return "image/heic"
    case "gif":
      return "image/gif"
    case "tiff", "tif":
      return "image/tiff"
    case "webp":
      return "image/webp"
    case "mp4":
      return "video/mp4"
    case "mov":
      return "video/quicktime"
    case "avi":
      return "video/x-msvideo"
    case "mkv":
      return "video/x-matroska"
    case "webm":
      return "video/webm"
    case "pdf":
      return "application/pdf"
    case "txt":
      return "text/plain"
    case "md", "markdown":
      return "text/markdown"
    case "html", "htm":
      return "text/html"
    case "rtf":
      return "application/rtf"
    case "doc", "docx":
      return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    default:
      return "application/octet-stream"
    }
  }

  // MARK: - Storage Strategy

  /// Determine storage strategy based on file size
  ///
  /// - Parameter fileSize: Size of the file in bytes
  /// - Returns: `.memory` for files < 1MB, `.file` for files >= 1MB
  public static func determineStorageStrategy(fileSize: Int) -> StorageStrategy {
    return fileSize < fileSizeThreshold ? .memory : .file
  }

  public enum StorageStrategy {
    case memory  // Store in binaryValue field
    case file  // Store in file with fileReference
  }

  // MARK: - Security-Scoped Bookmarks

  #if os(macOS)
    /// Create security-scoped bookmark for a file URL (macOS only)
    ///
    /// - Parameter url: File URL to create bookmark for
    /// - Returns: Bookmark data
    /// - Throws: Error if bookmark creation fails
    public static func createSecurityScopedBookmark(for url: URL) throws -> Data {
      return try url.bookmarkData(
        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
    }

    /// Resolve security-scoped bookmark to file URL (macOS only)
    ///
    /// - Parameter bookmarkData: Bookmark data to resolve
    /// - Returns: Resolved file URL, or nil if resolution fails
    public static func resolveSecurityScopedBookmark(_ bookmarkData: Data) -> URL? {
      var isStale = false
      do {
        let url = try URL(
          resolvingBookmarkData: bookmarkData,
          options: .withSecurityScope,
          relativeTo: nil,
          bookmarkDataIsStale: &isStale
        )

        if isStale {
          print("⚠️ [MediaFileStorage] Bookmark is stale, may need to recreate")
        }

        return url
      } catch {
        print("❌ [MediaFileStorage] Failed to resolve bookmark: \(error)")
        return nil
      }
    }
  #else
    /// Create security-scoped bookmark for a file URL (iOS fallback - standard bookmark)
    ///
    /// - Parameter url: File URL to create bookmark for
    /// - Returns: Bookmark data
    /// - Throws: Error if bookmark creation fails
    public static func createSecurityScopedBookmark(for url: URL) throws -> Data {
      return try url.bookmarkData(
        options: [],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
    }

    /// Resolve security-scoped bookmark to file URL (iOS fallback - standard bookmark)
    ///
    /// - Parameter bookmarkData: Bookmark data to resolve
    /// - Returns: Resolved file URL, or nil if resolution fails
    public static func resolveSecurityScopedBookmark(_ bookmarkData: Data) -> URL? {
      var isStale = false
      do {
        let url = try URL(
          resolvingBookmarkData: bookmarkData,
          options: [],
          relativeTo: nil,
          bookmarkDataIsStale: &isStale
        )

        if isStale {
          print("⚠️ [MediaFileStorage] Bookmark is stale, may need to recreate")
        }

        return url
      } catch {
        print("❌ [MediaFileStorage] Failed to resolve bookmark: \(error)")
        return nil
      }
    }
  #endif

  // MARK: - Metadata Extraction

  /// Extract metadata from audio file
  ///
  /// - Parameter url: Audio file URL
  /// - Returns: Audio metadata (duration, bitrate, channels, sample rate)
  /// - Throws: Error if metadata extraction fails
  public static func extractAudioMetadata(from url: URL) async throws -> AudioMetadata {
    let asset = AVURLAsset(url: url)

    let duration = try await asset.load(.duration)
    let durationSeconds = CMTimeGetSeconds(duration)

    // Get audio tracks
    let tracks = try await asset.load(.tracks)
    let audioTracks = tracks.filter { $0.mediaType == .audio }

    var channels: Int?
    var sampleRate: Int?
    var bitRate: Int?

    if let firstAudioTrack = audioTracks.first {
      let formatDescriptions = try await firstAudioTrack.load(.formatDescriptions)
      if let formatDescription = formatDescriptions.first {
        let basic = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        if let basic = basic {
          channels = Int(basic.pointee.mChannelsPerFrame)
          sampleRate = Int(basic.pointee.mSampleRate)
        }
      }

      // Estimate bitrate from file size and duration
      let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
      if durationSeconds > 0 {
        bitRate = Int(Double(fileSize * 8) / durationSeconds)
      }
    }

    return AudioMetadata(
      durationSeconds: durationSeconds,
      channels: channels,
      sampleRate: sampleRate,
      bitRate: bitRate
    )
  }

  public struct AudioMetadata {
    public let durationSeconds: Double
    public let channels: Int?
    public let sampleRate: Int?
    public let bitRate: Int?

    public init(durationSeconds: Double, channels: Int?, sampleRate: Int?, bitRate: Int?) {
      self.durationSeconds = durationSeconds
      self.channels = channels
      self.sampleRate = sampleRate
      self.bitRate = bitRate
    }
  }

  /// Extract metadata from image file
  ///
  /// - Parameter url: Image file URL
  /// - Returns: Image metadata (width, height, color space)
  /// - Throws: Error if metadata extraction fails
  public static func extractImageMetadata(from url: URL) throws -> ImageMetadata {
    #if canImport(AppKit)
      guard let image = NSImage(contentsOf: url),
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData)
      else {
        throw MediaFileStorageError.metadataExtractionFailed
      }

      return ImageMetadata(
        width: bitmap.pixelsWide,
        height: bitmap.pixelsHigh,
        colorSpace: bitmap.colorSpaceName.rawValue
      )
    #else
      guard let image = UIImage(contentsOfFile: url.path) else {
        throw MediaFileStorageError.metadataExtractionFailed
      }

      return ImageMetadata(
        width: Int(image.size.width * image.scale),
        height: Int(image.size.height * image.scale),
        colorSpace: nil
      )
    #endif
  }

  public struct ImageMetadata {
    public let width: Int
    public let height: Int
    public let colorSpace: String?

    public init(width: Int, height: Int, colorSpace: String?) {
      self.width = width
      self.height = height
      self.colorSpace = colorSpace
    }
  }

  /// Extract metadata from video file
  ///
  /// - Parameter url: Video file URL
  /// - Returns: Video metadata (duration, resolution, codec)
  /// - Throws: Error if metadata extraction fails
  public static func extractVideoMetadata(from url: URL) async throws -> VideoMetadata {
    let asset = AVURLAsset(url: url)

    let duration = try await asset.load(.duration)
    let durationSeconds = CMTimeGetSeconds(duration)

    // Get video tracks
    let tracks = try await asset.load(.tracks)
    let videoTracks = tracks.filter { $0.mediaType == .video }

    var width: Int?
    var height: Int?
    var codec: String?

    if let firstVideoTrack = videoTracks.first {
      let naturalSize = try await firstVideoTrack.load(.naturalSize)
      width = Int(naturalSize.width)
      height = Int(naturalSize.height)

      let formatDescriptions = try await firstVideoTrack.load(.formatDescriptions)
      if let formatDescription = formatDescriptions.first {
        let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
        codec = fourCCToString(codecType)
      }
    }

    return VideoMetadata(
      durationSeconds: durationSeconds,
      width: width,
      height: height,
      codec: codec
    )
  }

  public struct VideoMetadata {
    public let durationSeconds: Double
    public let width: Int?
    public let height: Int?
    public let codec: String?

    public init(durationSeconds: Double, width: Int?, height: Int?, codec: String?) {
      self.durationSeconds = durationSeconds
      self.width = width
      self.height = height
      self.codec = codec
    }
  }

  /// Extract metadata from document file
  ///
  /// - Parameter url: Document file URL
  /// - Returns: Document metadata (page count, author, title)
  /// - Throws: Error if metadata extraction fails
  public static func extractDocumentMetadata(from url: URL) throws -> DocumentMetadata {
    // PDF metadata extraction (basic)
    let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0

    return DocumentMetadata(
      pageCount: nil,  // Would require PDFKit
      author: nil,
      title: url.deletingPathExtension().lastPathComponent,
      fileSize: fileSize
    )
  }

  public struct DocumentMetadata {
    public let pageCount: Int?
    public let author: String?
    public let title: String?
    public let fileSize: Int

    public init(pageCount: Int?, author: String?, title: String?, fileSize: Int) {
      self.pageCount = pageCount
      self.author = author
      self.title = title
      self.fileSize = fileSize
    }
  }

  // MARK: - File Validation

  /// Validate that file type is allowed for media attachment
  ///
  /// - Parameter url: File URL to validate
  /// - Returns: true if file type is allowed, false otherwise
  public static func isAllowedFileType(_ url: URL) -> Bool {
    let mimeType = detectMIMEType(from: url)
    return isAllowedMIMEType(mimeType)
  }

  /// Validate that MIME type is allowed
  ///
  /// - Parameter mimeType: MIME type to validate
  /// - Returns: true if MIME type is allowed, false otherwise
  public static func isAllowedMIMEType(_ mimeType: String) -> Bool {
    let lowercased = mimeType.lowercased()
    return lowercased.hasPrefix("audio/") || lowercased.hasPrefix("image/")
      || lowercased.hasPrefix("video/") || lowercased.hasPrefix("application/pdf")
      || lowercased.hasPrefix("text/")
  }

  // MARK: - File Name Sanitization

  /// Sanitize filename for safe storage
  ///
  /// - Parameter filename: Original filename
  /// - Returns: Sanitized filename
  public static func sanitizeFileName(_ filename: String) -> String {
    // Remove or replace unsafe characters
    let unsafe = CharacterSet(charactersIn: ":/\\?%*|\"<>")
    let components = filename.components(separatedBy: unsafe)
    return components.joined(separator: "_")
  }

  // MARK: - Document Bundle File Storage

  /// Create a TypedDataStorage instance from a file URL using appropriate storage strategy
  ///
  /// - Parameters:
  ///   - fileURL: URL of the file to store
  ///   - documentDirectory: Directory where the document's files are stored (for file-based storage)
  ///   - providerId: Provider ID for the storage record
  ///   - requestorID: Requestor ID for the storage record
  /// - Returns: TypedDataStorage instance with either binaryValue (small) or fileReference (large)
  /// - Throws: Error if file cannot be read or stored
  public static func createStorage(
    from fileURL: URL,
    documentDirectory: URL?,
    providerId: String,
    requestorID: String
  ) throws -> TypedDataStorage {
    // Get file attributes
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    guard let fileSize = attributes[.size] as? Int else {
      throw MediaFileStorageError.fileAccessDenied
    }

    // Detect MIME type
    let mimeType = detectMIMEType(from: fileURL)

    // Determine storage strategy
    let strategy = determineStorageStrategy(fileSize: fileSize)

    switch strategy {
    case .memory:
      // Small files: store in binaryValue
      let fileData = try Data(contentsOf: fileURL)
      return TypedDataStorage(
        id: UUID(),
        providerId: providerId,
        requestorID: requestorID,
        mimeType: mimeType,
        binaryValue: fileData
      )

    case .file:
      // Large files: store in document bundle with fileReference
      guard let documentDirectory = documentDirectory else {
        // Fallback to memory if no document directory provided
        let fileData = try Data(contentsOf: fileURL)
        return TypedDataStorage(
          id: UUID(),
          providerId: providerId,
          requestorID: requestorID,
          mimeType: mimeType,
          binaryValue: fileData
        )
      }

      // Generate request ID for this file
      let requestID = UUID()

      // Create assets/requestID directory structure
      let assetsDir = documentDirectory.appendingPathComponent("assets", isDirectory: true)
      let requestDir = assetsDir.appendingPathComponent(requestID.uuidString, isDirectory: true)
      try FileManager.default.createDirectory(at: requestDir, withIntermediateDirectories: true)

      // Generate sanitized filename
      let originalFilename = fileURL.lastPathComponent
      let sanitizedFilename = sanitizeFileName(originalFilename)
      let destinationURL = requestDir.appendingPathComponent(sanitizedFilename)

      // Copy file to document bundle
      try FileManager.default.copyItem(at: fileURL, to: destinationURL)

      // Create file reference
      let fileReference = try TypedDataFileReference.from(
        requestID: requestID,
        fileURL: destinationURL,
        mimeType: mimeType,
        includeChecksum: false
      )

      return TypedDataStorage(
        id: UUID(),
        providerId: providerId,
        requestorID: requestorID,
        mimeType: mimeType,
        binaryValue: nil,
        fileReference: fileReference
      )
    }
  }

  /// Resolve a file reference to an absolute URL
  ///
  /// - Parameters:
  ///   - fileReference: TypedDataFileReference from TypedDataStorage
  ///   - documentDirectory: Directory where the document's files are stored
  /// - Returns: Absolute URL to the file, or nil if not found
  public static func resolveFileReference(
    _ fileReference: TypedDataFileReference, documentDirectory: URL
  ) -> URL? {
    let fileURL = fileReference.fileURL(in: documentDirectory)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return nil
    }
    return fileURL
  }

  // MARK: - Helper Methods

  /// Convert FourCC code to string representation
  private static func fourCCToString(_ code: FourCharCode) -> String {
    let bytes: [UInt8] = [
      UInt8((code >> 24) & 0xFF),
      UInt8((code >> 16) & 0xFF),
      UInt8((code >> 8) & 0xFF),
      UInt8(code & 0xFF),
    ]
    return String(bytes: bytes, encoding: .utf8) ?? "unknown"
  }
}

// MARK: - Errors

public enum MediaFileStorageError: Error, LocalizedError {
  case metadataExtractionFailed
  case fileAccessDenied
  case insufficientDiskSpace
  case unsupportedFileType(String)

  public var errorDescription: String? {
    switch self {
    case .metadataExtractionFailed:
      return "Failed to extract metadata from media file"
    case .fileAccessDenied:
      return "Access to file was denied. Check file permissions."
    case .insufficientDiskSpace:
      return "Insufficient disk space to store media file"
    case .unsupportedFileType(let type):
      return "Unsupported file type: \(type)"
    }
  }
}
