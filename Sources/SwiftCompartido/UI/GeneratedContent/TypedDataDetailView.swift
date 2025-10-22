//
//  TypedDataDetailView.swift
//  SwiftCompartido
//
//  Detail view that displays TypedDataStorage content using the appropriate viewer
//

import SwiftUI
import SwiftData

/// Detail view that displays TypedDataStorage content using the appropriate viewer based on MIME type
///
/// Automatically selects the correct view:
/// - Text: TypedDataTextView
/// - Audio: TypedDataAudioView
/// - Image: TypedDataImageView
/// - Video: TypedDataVideoView
/// - Embedding: Shows embedding metadata
///
/// ## Example
/// ```swift
/// if let selectedItem = selectedContent {
///     TypedDataDetailView(record: selectedItem, storageArea: storage)
/// }
/// ```
public struct TypedDataDetailView: View {

    // MARK: - Properties

    /// The storage record to display
    let record: TypedDataStorage

    /// Optional storage area for file-based content
    let storageArea: StorageAreaReference?

    // MARK: - Initialization

    /// Creates a detail view for a TypedDataStorage record
    ///
    /// - Parameters:
    ///   - record: The storage record to display
    ///   - storageArea: Optional storage area for file-based content
    public init(record: TypedDataStorage, storageArea: StorageAreaReference? = nil) {
        self.record = record
        self.storageArea = storageArea
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with metadata
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: iconForMimeType(record.mimeType))
                        .font(.title2)
                        .foregroundColor(colorForMimeType(record.mimeType))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.mimeType)
                            .font(.headline)

                        if let provider = record.providerId.components(separatedBy: ".").last {
                            Text(provider.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Metadata badge
                    if let element = record.owningElement {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Ch \(element.chapterIndex)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Pos \(element.orderIndex)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    }
                }

                // Prompt
                if !record.prompt.isEmpty {
                    Text(record.prompt)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)

            Divider()

            // Content viewer based on MIME type
            Group {
                if record.mimeType.hasPrefix("text/") {
                    TypedDataTextView(record: record, storageArea: storageArea)
                } else if record.mimeType.hasPrefix("audio/") {
                    TypedDataAudioView(record: record, storageArea: storageArea)
                } else if record.mimeType.hasPrefix("image/") {
                    TypedDataImageView(record: record, storageArea: storageArea, contentMode: .fit)
                } else if record.mimeType.hasPrefix("video/") {
                    TypedDataVideoView(record: record, storageArea: storageArea)
                } else if record.mimeType == "application/x-embedding" {
                    embeddingView
                } else {
                    unsupportedView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Specialized Views

    /// View for embedding content
    private var embeddingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 48))
                .foregroundColor(.purple)

            VStack(spacing: 8) {
                if let dimensions = record.dimensions {
                    HStack {
                        Text("Dimensions:")
                            .fontWeight(.medium)
                        Text("\(dimensions)")
                            .foregroundColor(.secondary)
                    }
                }

                if let tokenCount = record.tokenCount {
                    HStack {
                        Text("Tokens:")
                            .fontWeight(.medium)
                        Text("\(tokenCount)")
                            .foregroundColor(.secondary)
                    }
                }

                if let inputText = record.inputText {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Input Text:")
                            .fontWeight(.medium)
                        Text(inputText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    /// View for unsupported content types
    private var unsupportedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Unsupported Content Type")
                .font(.headline)

            Text(record.mimeType)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Helpers

    /// Returns SF Symbol icon name for MIME type
    private func iconForMimeType(_ mimeType: String) -> String {
        if mimeType.hasPrefix("text/") {
            return "doc.text"
        } else if mimeType.hasPrefix("audio/") {
            return "waveform"
        } else if mimeType.hasPrefix("image/") {
            return "photo"
        } else if mimeType.hasPrefix("video/") {
            return "video"
        } else if mimeType == "application/x-embedding" {
            return "point.3.connected.trianglepath.dotted"
        } else {
            return "doc"
        }
    }

    /// Returns color for MIME type
    private func colorForMimeType(_ mimeType: String) -> Color {
        if mimeType.hasPrefix("text/") {
            return .blue
        } else if mimeType.hasPrefix("audio/") {
            return .green
        } else if mimeType.hasPrefix("image/") {
            return .orange
        } else if mimeType.hasPrefix("video/") {
            return .red
        } else if mimeType == "application/x-embedding" {
            return .purple
        } else {
            return .gray
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TypedDataDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Audio preview
            TypedDataDetailView(
                record: TypedDataStorage(
                    providerId: "elevenlabs",
                    requestorID: "tts.rachel",
                    mimeType: "audio/mpeg",
                    binaryValue: Data(),
                    prompt: "Generate audio for this dialogue",
                    audioFormat: "mp3",
                    durationSeconds: 5.5,
                    voiceID: "rachel",
                    voiceName: "Rachel"
                )
            )
            .previewDisplayName("Audio")

            // Image preview
            TypedDataDetailView(
                record: TypedDataStorage(
                    providerId: "openai",
                    requestorID: "dalle.3",
                    mimeType: "image/png",
                    binaryValue: Data(),
                    prompt: "A coffee shop interior",
                    imageFormat: "png",
                    width: 1024,
                    height: 1024
                )
            )
            .previewDisplayName("Image")

            // Embedding preview
            TypedDataDetailView(
                record: TypedDataStorage(
                    providerId: "openai",
                    requestorID: "embeddings",
                    mimeType: "application/x-embedding",
                    binaryValue: Data(),
                    prompt: "Scene heading for embedding",
                    tokenCount: 10,
                    dimensions: 1536
                )
            )
            .previewDisplayName("Embedding")
        }
        .frame(width: 600, height: 400)
    }
}
#endif
