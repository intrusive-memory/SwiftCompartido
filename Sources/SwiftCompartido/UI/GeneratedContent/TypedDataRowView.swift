//
//  TypedDataRowView.swift
//  SwiftCompartido
//
//  List row view for TypedDataStorage items
//

import SwiftUI
import SwiftData

/// List row view for TypedDataStorage items
///
/// Displays a compact summary of the content with icon, prompt, and metadata.
///
/// ## Example
/// ```swift
/// List(items) { item in
///     TypedDataRowView(record: item)
///         .onTapGesture {
///             selectedItem = item
///         }
/// }
/// ```
public struct TypedDataRowView: View {

    // MARK: - Properties

    /// The storage record to display
    let record: TypedDataStorage

    /// Whether this row is selected
    let isSelected: Bool

    // MARK: - Initialization

    /// Creates a row view for a TypedDataStorage record
    ///
    /// - Parameters:
    ///   - record: The storage record to display
    ///   - isSelected: Whether this row is selected (default: false)
    public init(record: TypedDataStorage, isSelected: Bool = false) {
        self.record = record
        self.isSelected = isSelected
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconForMimeType(record.mimeType))
                .font(.title3)
                .foregroundColor(colorForMimeType(record.mimeType))
                .frame(width: 32, height: 32)
                .background(colorForMimeType(record.mimeType).opacity(0.1))
                .cornerRadius(6)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Prompt (truncated)
                Text(record.prompt.isEmpty ? "No prompt" : record.prompt)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundColor(record.prompt.isEmpty ? .secondary : .primary)

                // Metadata
                HStack(spacing: 12) {
                    // MIME type
                    Text(shortMimeType(record.mimeType))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Element position
                    if let element = record.owningElement {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Ch \(element.chapterIndex), Pos \(element.orderIndex)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Type-specific metadata
                    typeSpecificMetadata
                }
            }

            Spacer(minLength: 0)

            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }

    // MARK: - Type-Specific Metadata

    @ViewBuilder
    private var typeSpecificMetadata: some View {
        if record.mimeType.hasPrefix("audio/") {
            if let duration = record.durationSeconds {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(formatDuration(duration))
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        } else if record.mimeType.hasPrefix("image/") {
            if let width = record.width, let height = record.height {
                HStack(spacing: 4) {
                    Image(systemName: "aspectratio")
                        .font(.caption2)
                    Text("\(width)×\(height)")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        } else if record.mimeType.hasPrefix("text/") {
            if let wordCount = record.wordCount {
                HStack(spacing: 4) {
                    Image(systemName: "text.word.spacing")
                        .font(.caption2)
                    Text("\(wordCount) words")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        } else if record.mimeType == "application/x-embedding" {
            if let dimensions = record.dimensions {
                HStack(spacing: 4) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.caption2)
                    Text("\(dimensions)d")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
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

    /// Returns shortened MIME type for display
    private func shortMimeType(_ mimeType: String) -> String {
        let parts = mimeType.components(separatedBy: "/")
        if parts.count == 2 {
            return parts[1].uppercased()
        }
        return mimeType.uppercased()
    }

    /// Formats duration in seconds to MM:SS
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Preview

#if DEBUG
struct TypedDataRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            TypedDataRowView(
                record: TypedDataStorage(
                    providerId: "elevenlabs",
                    requestorID: "tts.rachel",
                    mimeType: "audio/mpeg",
                    binaryValue: Data(),
                    prompt: "Hello, how are you?",
                    audioFormat: "mp3",
                    durationSeconds: 5.5,
                    voiceID: "rachel",
                    voiceName: "Rachel"
                ),
                isSelected: false
            )

            Divider()

            TypedDataRowView(
                record: TypedDataStorage(
                    providerId: "openai",
                    requestorID: "dalle.3",
                    mimeType: "image/png",
                    binaryValue: Data(),
                    prompt: "A coffee shop interior with warm lighting",
                    imageFormat: "png",
                    width: 1024,
                    height: 1024
                ),
                isSelected: true
            )

            Divider()

            TypedDataRowView(
                record: TypedDataStorage(
                    providerId: "openai",
                    requestorID: "gpt-4",
                    mimeType: "text/plain",
                    textValue: "Generated text content",
                    prompt: "Summarize this scene",
                    wordCount: 150,
                    characterCount: 750
                ),
                isSelected: false
            )

            Divider()

            TypedDataRowView(
                record: TypedDataStorage(
                    providerId: "openai",
                    requestorID: "embeddings",
                    mimeType: "application/x-embedding",
                    binaryValue: Data(),
                    prompt: "EXT. PARK - DAY",
                    tokenCount: 10,
                    dimensions: 1536
                ),
                isSelected: false
            )
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
