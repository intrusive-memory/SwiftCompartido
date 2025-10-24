//
//  TypedDataVideoView.swift
//  SwiftCompartido
//
//  SwiftUI view for displaying and playing video content from TypedDataStorage
//

import SwiftUI
import SwiftData
import AVKit

/// SwiftUI view for displaying and playing video content from TypedDataStorage
///
/// Provides video playback for TypedDataStorage records with MIME type `video/*`.
/// Uses AVPlayer for video playback with native platform controls.
///
/// ## Example
/// ```swift
/// TypedDataVideoView(record: videoRecord, storageArea: storage)
///     .frame(height: 400)
/// ```
public struct TypedDataVideoView: View {

    // MARK: - Properties

    /// The video storage record to display
    let record: TypedDataStorage

    /// Optional storage area for file-based content
    let storageArea: StorageAreaReference?

    /// AV Player
    @State private var player: AVPlayer?

    /// Error state
    @State private var error: Error?

    /// Loading state
    @State private var isLoading: Bool = true

    // MARK: - Initialization

    /// Creates a video view for a TypedDataStorage record
    ///
    /// - Parameters:
    ///   - record: The video storage record
    ///   - storageArea: Optional storage area for file-based content
    public init(record: TypedDataStorage, storageArea: StorageAreaReference? = nil) {
        self.record = record
        self.storageArea = storageArea
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading video...")
            } else if let error = error {
                ErrorView(error: error)
            } else if let player = player {
                VideoPlayer(player: player)
            } else {
                Text("No video available")
                    .foregroundColor(.secondary)
            }
        }
        .task {
            await loadVideo()
        }
        .onDisappear {
            // Stop playback when view disappears
            player?.pause()
        }
    }

    // MARK: - Loading

    /// Loads video from the record
    private func loadVideo() async {
        do {
            let videoURL: URL

            // Check if file-based
            if let fileRef = record.fileReference, let storage = storageArea {
                videoURL = fileRef.fileURL(in: storage)
            } else if let binaryValue = record.binaryValue {
                // Create temporary file for in-memory video data
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(record.imageFormat ?? "mp4")

                try binaryValue.write(to: tempURL)
                videoURL = tempURL
            } else {
                throw TypedDataError.fileOperationFailed(
                    operation: "load video",
                    reason: "No video data or file reference available"
                )
            }

            player = AVPlayer(url: videoURL)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
}

/// Error view for displaying load errors
private struct ErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Failed to load video")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct TypedDataVideoView_Previews: PreviewProvider {
    static var previews: some View {
        let record = TypedDataStorage(
            providerId: "test",
            requestorID: "video.test",
            mimeType: "video/mp4",
            binaryValue: nil,
            prompt: "Sample video content",
            imageFormat: "mp4",  // Using imageFormat for video format
            width: 1920,
            height: 1080
        )

        TypedDataVideoView(record: record)
            .frame(width: 640, height: 360)
    }
}
#endif
