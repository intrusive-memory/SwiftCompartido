//
//  ProviderCategory.swift
//  SwiftHablare
//
//  Phase 6A: Provider category classification
//

import Foundation

/// Categories of AI service capabilities.
///
/// Used to classify requestors by the type of data they generate,
/// enabling filtering and UI organization.
///
/// ## Design Rationale
///
/// Provider categories are **generic** and **data-type focused**:
/// - ❌ NOT "voice provider" (too specific)
/// - ✅ "audio" (generic category)
///
/// Categories describe **what the requestor generates**, not how:
/// - `.text` - Generates text content (chat, completion, translation)
/// - `.audio` - Generates audio data (TTS, audio generation, music)
/// - `.image` - Generates images (DALL-E, Stable Diffusion, Midjourney)
/// - `.video` - Generates video content (motion, animation, editing)
/// - `.embedding` - Generates vector embeddings (text, image, audio)
/// - `.code` - Generates code (completion, generation, transformation)
/// - `.structuredData` - Generates structured data (JSON, tables, graphs)
///
/// A single provider may offer **multiple requestors** across different categories:
/// - OpenAI: text requestor, image requestor, embedding requestor
/// - ElevenLabs: audio requestor (TTS), audio requestor (sound effects)
///
/// ## Example Usage
///
/// ```swift
/// // Filter requestors by category
/// let audioRequestors = provider.availableRequestors()
///     .filter { $0.category == .audio }
///
/// // UI organization
/// struct RequestorPicker: View {
///     var body: some View {
///         ForEach(ProviderCategory.allCases) { category in
///             Section(category.displayName) {
///                 // Show requestors for this category
///             }
///         }
///     }
/// }
/// ```
@available(macOS 15.0, iOS 17.0, *)
public enum ProviderCategory: String, Codable, Sendable, CaseIterable, Identifiable {

    /// Text generation (chat, completion, translation)
    ///
    /// Examples:
    /// - OpenAI GPT-4 chat completions
    /// - Anthropic Claude message generation
    /// - Apple Intelligence on-device text
    case text

    /// Audio generation (TTS, music, sound effects)
    ///
    /// Examples:
    /// - ElevenLabs text-to-speech
    /// - OpenAI TTS
    /// - Audio generation models
    case audio

    /// Image generation and manipulation
    ///
    /// Examples:
    /// - DALL-E 3
    /// - Stable Diffusion
    /// - Midjourney
    case image

    /// Video generation and editing
    ///
    /// Examples:
    /// - Runway ML
    /// - Pika Labs
    /// - Video synthesis models
    case video

    /// Vector embeddings (text, image, audio)
    ///
    /// Examples:
    /// - OpenAI text embeddings
    /// - Image embeddings
    /// - Audio embeddings
    case embedding

    /// Code generation and completion
    ///
    /// Examples:
    /// - GitHub Copilot
    /// - OpenAI Codex
    /// - Code transformation models
    case code

    /// Structured data generation (JSON, tables, graphs)
    ///
    /// Examples:
    /// - JSON schema generation
    /// - Data extraction
    /// - Knowledge graph creation
    case structuredData

    // MARK: - Identifiable

    public var id: String { rawValue }

    // MARK: - Display Properties

    /// Human-readable display name for UI
    public var displayName: String {
        switch self {
        case .text: return "Text Generation"
        case .audio: return "Audio Generation"
        case .image: return "Image Generation"
        case .video: return "Video Generation"
        case .embedding: return "Embeddings"
        case .code: return "Code Generation"
        case .structuredData: return "Structured Data"
        }
    }

    /// SF Symbol name for UI icons
    public var symbolName: String {
        switch self {
        case .text: return "text.bubble"
        case .audio: return "waveform"
        case .image: return "photo"
        case .video: return "video"
        case .embedding: return "point.3.filled.connected.trianglepath.dotted"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .structuredData: return "tablecells"
        }
    }

    /// Brief description of category purpose
    public var description: String {
        switch self {
        case .text:
            return "Generate text content including chat, completion, and translation"
        case .audio:
            return "Generate audio including speech, music, and sound effects"
        case .image:
            return "Generate and manipulate images"
        case .video:
            return "Generate and edit video content"
        case .embedding:
            return "Generate vector embeddings for semantic search and similarity"
        case .code:
            return "Generate and transform code"
        case .structuredData:
            return "Generate structured data like JSON, tables, and graphs"
        }
    }

    // MARK: - File Storage Hints

    /// Typical size expectations for this category
    ///
    /// Helps determine if file storage is needed.
    /// Returns `nil` if size varies too widely to estimate.
    public var typicalSizeRange: ClosedRange<Int64>? {
        switch self {
        case .text:
            // Text is usually small (1KB - 100KB)
            return 1_000...100_000
        case .audio:
            // Audio files are large (100KB - 50MB)
            return 100_000...50_000_000
        case .image:
            // Images are medium-large (50KB - 10MB)
            return 50_000...10_000_000
        case .video:
            // Videos are very large (1MB - 500MB)
            return 1_000_000...500_000_000
        case .embedding:
            // Embeddings are small-medium (1KB - 10MB depending on dimensions)
            return 1_000...10_000_000
        case .code:
            // Code is usually small (1KB - 1MB)
            return 1_000...1_000_000
        case .structuredData:
            // Structured data varies widely
            return nil
        }
    }

    /// Whether this category typically needs file storage
    public var typicallyNeedsFileStorage: Bool {
        switch self {
        case .text, .code:
            return false // Usually fits in memory
        case .audio, .image, .video:
            return true // Usually too large for memory
        case .embedding, .structuredData:
            return false // Depends on size, use estimatedMaxSize
        }
    }
}
