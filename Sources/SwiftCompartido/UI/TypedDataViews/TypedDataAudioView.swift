//
//  TypedDataAudioView.swift
//  SwiftCompartido
//
//  SwiftUI view for displaying and playing audio content from TypedDataStorage
//

import SwiftUI
import SwiftData

/// SwiftUI view for displaying and playing audio content from TypedDataStorage
///
/// Provides playback controls for audio from TypedDataStorage records with MIME type `audio/*`.
/// Integrates with AudioPlayerManager for audio playback.
///
/// ## Example
/// ```swift
/// TypedDataAudioView(record: audioRecord, storageArea: storage)
/// ```
public struct TypedDataAudioView: View {

    // MARK: - Properties

    /// The audio storage record to display
    let record: TypedDataStorage

    /// Optional storage area for file-based content
    let storageArea: StorageAreaReference?

    /// Audio player manager
    @StateObject private var playerManager = AudioPlayerManager()

    /// Error state
    @State private var error: Error?

    // MARK: - Initialization

    /// Creates an audio view for a TypedDataStorage record
    ///
    /// - Parameters:
    ///   - record: The audio storage record
    ///   - storageArea: Optional storage area for file-based content
    public init(record: TypedDataStorage, storageArea: StorageAreaReference? = nil) {
        self.record = record
        self.storageArea = storageArea
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 16) {
            // Audio Info
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "waveform")
                        .font(.title)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading) {
                        if let voiceName = record.voiceName {
                            Text(voiceName)
                                .font(.headline)
                        }

                        if let format = record.audioFormat {
                            Text(format.uppercased())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if let duration = record.durationSeconds {
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !record.prompt.isEmpty {
                    Text(record.prompt)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            // Playback Controls
            HStack(spacing: 20) {
                // Play/Pause Button
                Button(action: togglePlayback) {
                    Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                }
                .buttonStyle(.plain)
                .disabled(error != nil)

                // Stop Button
                Button(action: stop) {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 32))
                }
                .buttonStyle(.plain)
                .disabled(!playerManager.isPlaying)
            }

            // Error Display
            if let error = error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    // MARK: - Actions

    /// Toggles playback (play/pause)
    private func togglePlayback() {
        do {
            if playerManager.isPlaying {
                playerManager.pause()
                error = nil
            } else {
                // Start or resume playing
                if playerManager.currentAudioFile != nil {
                    playerManager.resume()
                    error = nil
                } else {
                    try playerManager.play(record: record, storageArea: storageArea)
                    error = nil
                }
            }
        } catch {
            self.error = error
        }
    }

    /// Stops playback
    private func stop() {
        playerManager.stop()
        error = nil
    }

    // MARK: - Helper

    /// Formats duration in seconds to MM:SS
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Preview

#if DEBUG
struct TypedDataAudioView_Previews: PreviewProvider {
    static var previews: some View {
        let record = TypedDataStorage(
            providerId: "elevenlabs",
            requestorID: "tts.rachel",
            mimeType: "audio/mpeg",
            binaryValue: Data(),  // Empty for preview
            prompt: "This is a sample text to be converted to speech",
            audioFormat: "mp3",
            durationSeconds: 5.5,
            voiceID: "rachel",
            voiceName: "Rachel"
        )

        TypedDataAudioView(record: record)
            .frame(width: 400, height: 250)
            .padding()
    }
}
#endif
