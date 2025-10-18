//
//  GeneratedImageData.swift
//  SwiftHablare
//
//  Phase 6D: Typed image data structures
//

import Foundation

/// Typed data structure for generated image content.
///
/// This is the in-memory representation of generated images that includes
/// metadata about the generation. Images are typically stored in files
/// due to size, so this struct holds metadata and optional data.
///
/// ## Example
/// ```swift
/// let imageData = GeneratedImageData(
///     imageData: pngData,
///     format: .png,
///     width: 1024,
///     height: 1024,
///     model: "dall-e-3"
/// )
/// ```
@available(macOS 15.0, iOS 17.0, *)
public struct GeneratedImageData: Codable, Sendable, SerializableTypedData {

    // MARK: - Image Format

    /// Image format enumeration
    public enum ImageFormat: String, Codable, Sendable {
        case png = "png"
        case jpeg = "jpeg"
        case jpg = "jpg"
        case webp = "webp"
        case heic = "heic"

        public var mimeType: String {
            switch self {
            case .png: return "image/png"
            case .jpeg, .jpg: return "image/jpeg"
            case .webp: return "image/webp"
            case .heic: return "image/heic"
            }
        }

        public var fileExtension: String {
            return rawValue
        }
    }

    // MARK: - Properties

    /// The image data (may be nil if stored in file)
    ///
    /// For file-based storage, this will be nil and data loaded from file reference.
    public let imageData: Data?

    /// Image format
    public let format: ImageFormat

    /// Image width in pixels
    public let width: Int

    /// Image height in pixels
    public let height: Int

    /// Model identifier that generated this image
    public let model: String

    /// Revised prompt (if the model modified the original prompt)
    ///
    /// Some models like DALL-E 3 may revise prompts for safety or quality.
    public let revisedPrompt: String?

    /// File size in bytes (if image data present)
    public var fileSize: Int {
        imageData?.count ?? 0
    }

    // MARK: - Initialization

    /// Creates generated image data
    ///
    /// - Parameters:
    ///   - imageData: The image data (nil if stored in file)
    ///   - format: Image format
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - model: Model identifier
    ///   - revisedPrompt: Revised prompt (optional)
    public init(
        imageData: Data?,
        format: ImageFormat,
        width: Int,
        height: Int,
        model: String,
        revisedPrompt: String? = nil
    ) {
        self.imageData = imageData
        self.format = format
        self.width = width
        self.height = height
        self.model = model
        self.revisedPrompt = revisedPrompt
    }

    // MARK: - SerializableTypedData Conformance

    /// Prefers plist format for image metadata
    public var preferredFormat: SerializationFormat {
        .plist
    }
}

/// Configuration for image generation requests.
///
/// Contains parameters that control how images are generated,
/// such as size, quality, and style settings.
@available(macOS 15.0, iOS 17.0, *)
public struct ImageGenerationConfig: Codable, Sendable {

    /// Image size options based on video aspect ratios
    ///
    /// Designed for storyboard and video production workflows.
    /// All sizes use standard video/cinema aspect ratios.
    public enum ImageSize: String, Codable, Sendable {
        // Square (1:1) - Social media, thumbnails
        case square256 = "256x256"       // DALL-E 2 only
        case square512 = "512x512"       // DALL-E 2 only
        case square1024 = "1024x1024"    // DALL-E 2 & 3

        // 16:9 Wide (Standard HD video, YouTube, most TVs)
        case wide16x9 = "1792x1024"      // DALL-E 3 only (1.75:1 ≈ 16:9)

        // 9:16 Portrait (Vertical video, Stories, TikTok, Reels)
        case portrait9x16 = "1024x1792"  // DALL-E 3 only (9:16)

        // 4:3 (Classic TV, IMAX, some cinema)
        // Note: Not directly supported by DALL-E, use square1024 or wide16x9

        // 1.85:1 (American cinema standard)
        // Note: Use wide16x9 as closest approximation

        // 2.40:1 (Anamorphic widescreen, cinematic)
        // Note: Use wide16x9 as closest approximation

        /// Actual pixel width
        public var width: Int {
            switch self {
            case .square256: return 256
            case .square512: return 512
            case .square1024: return 1024
            case .wide16x9: return 1792
            case .portrait9x16: return 1024
            }
        }

        /// Actual pixel height
        public var height: Int {
            switch self {
            case .square256: return 256
            case .square512: return 512
            case .square1024: return 1024
            case .wide16x9: return 1024
            case .portrait9x16: return 1792
            }
        }

        /// Aspect ratio as a decimal (width / height)
        public var aspectRatio: Double {
            return Double(width) / Double(height)
        }

        /// Human-readable aspect ratio description
        public var aspectRatioDescription: String {
            switch self {
            case .square256, .square512, .square1024:
                return "1:1 (Square)"
            case .wide16x9:
                return "16:9 (Widescreen)"
            case .portrait9x16:
                return "9:16 (Portrait)"
            }
        }

        /// Use case description for video production
        public var useCase: String {
            switch self {
            case .square256, .square512, .square1024:
                return "Social media, thumbnails, Instagram posts"
            case .wide16x9:
                return "YouTube, HD video, TV, presentations"
            case .portrait9x16:
                return "Stories, TikTok, Reels, vertical video"
            }
        }
    }

    /// Quality options
    public enum Quality: String, Codable, Sendable {
        case standard = "standard"
        case hd = "hd"
    }

    /// Style options
    public enum Style: String, Codable, Sendable {
        case vivid = "vivid"
        case natural = "natural"
    }

    /// Desired image size
    public var size: ImageSize

    /// Image quality (standard or HD)
    public var quality: Quality

    /// Image style (vivid or natural)
    public var style: Style

    /// Number of images to generate (must be 1)
    ///
    /// Note: While DALL-E 2 API supports generating multiple images (1-10),
    /// the current implementation only supports single image generation since
    /// the AIRequestor protocol returns a single TypedData result.
    /// Batch generation may be added in a future phase.
    public var numberOfImages: Int

    /// Creates an image generation configuration
    ///
    /// - Parameters:
    ///   - size: Image size (default: square1024)
    ///   - quality: Quality setting (default: standard)
    ///   - style: Style setting (default: vivid)
    ///   - numberOfImages: Number of images (default: 1)
    public init(
        size: ImageSize = .square1024,
        quality: Quality = .standard,
        style: Style = .vivid,
        numberOfImages: Int = 1
    ) {
        self.size = size
        self.quality = quality
        self.style = style
        self.numberOfImages = numberOfImages
    }

    // MARK: - Presets

    /// Default configuration (1:1 square)
    public static let `default` = ImageGenerationConfig()

    /// HD quality square configuration
    public static let hd = ImageGenerationConfig(
        size: .square1024,
        quality: .hd,
        style: .vivid
    )

    /// Natural style configuration
    public static let natural = ImageGenerationConfig(
        size: .square1024,
        quality: .standard,
        style: .natural
    )

    /// Widescreen video format (16:9 for YouTube, TV)
    public static let widescreen = ImageGenerationConfig(
        size: .wide16x9,
        quality: .hd,
        style: .vivid
    )

    /// Portrait video format (9:16 for Stories, TikTok, Reels)
    public static let portrait = ImageGenerationConfig(
        size: .portrait9x16,
        quality: .hd,
        style: .vivid
    )

    /// Storyboard preset (widescreen HD for video production)
    public static let storyboard = ImageGenerationConfig(
        size: .wide16x9,
        quality: .hd,
        style: .natural
    )
}
