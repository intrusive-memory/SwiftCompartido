//
//  GuionElementsListWithAudioButton.swift
//  SwiftCompartido
//
//  Example showing how to add a "Generate Audio" button to each element row
//

import SwiftUI
import SwiftData

/// Example view showing GuionElementsList with a "Generate Audio" button in each row
///
/// This demonstrates how to:
/// - Access the GuionElementModel for each row
/// - Use element properties (id, content, type) to generate audio
/// - Store generated audio in SwiftData via TypedDataStorage
/// - Associate audio with the element via generatedContent relationship
public struct GuionElementsListWithAudioButton: View {
    @Environment(\.modelContext) private var modelContext
    let document: GuionDocumentModel

    public init(document: GuionDocumentModel) {
        self.document = document
    }

    public var body: some View {
        GuionElementsList(document: document) { element in
            // Trailing column content - has full access to the element
            VStack(spacing: 4) {
                // Show existing audio count
                if let audioCount = element.generatedContent?.filter({ $0.mimeType.hasPrefix("audio/") }).count, audioCount > 0 {
                    Text("\(audioCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Generate audio button
                Button {
                    Task {
                        await generateAudio(for: element)
                    }
                } label: {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("Generate audio for this element")
            }
            .frame(width: 50)
        }
    }

    /// Generate audio for a specific element
    /// - Parameter element: The GuionElementModel to generate audio for
    private func generateAudio(for element: GuionElementModel) async {
        // Access element properties
        let content = element.elementText
        let elementType = element.elementType

        // Only generate audio for dialogue, character names, and action
        guard elementType == .dialogue || elementType == .character || elementType == .action else {
            print("Skipping audio generation for element type: \(elementType)")
            return
        }

        do {
            // TODO: Replace with your actual TTS service
            let audioData = try await generateTTSAudio(text: content)

            // Create TypedDataStorage record
            let audioRecord = TypedDataStorage(
                id: UUID(),
                providerId: "your-tts-provider",
                requestorID: "tts.default-voice",
                mimeType: "audio/mpeg",
                binaryValue: audioData,
                prompt: "Generate speech for: \(content.prefix(50))...",
                modelIdentifier: "tts-model-1",
                audioFormat: "mp3",
                durationSeconds: Double(audioData.count) / 16000, // Approximate
                voiceID: "default",
                voiceName: "Default Voice"
            )

            // Associate with element
            if element.generatedContent == nil {
                element.generatedContent = []
            }
            element.generatedContent?.append(audioRecord)

            // Save to SwiftData
            modelContext.insert(audioRecord)
            try modelContext.save()

            print("Generated audio for element: \(content.prefix(30))...")
        } catch {
            print("Failed to generate audio: \(error)")
        }
    }

    /// Mock TTS generation - replace with your actual implementation
    private func generateTTSAudio(text: String) async throws -> Data {
        // TODO: Replace with actual TTS service call
        // Example services: ElevenLabs, OpenAI TTS, Azure Speech, etc.
        try await Task.sleep(for: .milliseconds(500))
        return Data(count: 1024) // Mock audio data
    }
}

// MARK: - Alternative: Using File Storage for Large Audio

/// Example showing Phase 6 file-based storage for audio
public struct GuionElementsListWithFileBasedAudio: View {
    @Environment(\.modelContext) private var modelContext
    let document: GuionDocumentModel

    public init(document: GuionDocumentModel) {
        self.document = document
    }

    public var body: some View {
        GuionElementsList(document: document) { element in
            Button {
                Task {
                    await generateAndStoreAudioInFile(for: element)
                }
            } label: {
                Image(systemName: "waveform.circle")
            }
            .buttonStyle(.plain)
        }
    }

    /// Generate audio and store in file (recommended for larger audio files)
    private func generateAndStoreAudioInFile(for element: GuionElementModel) async {
        let content = element.elementText
        let requestID = UUID()

        do {
            // Generate audio
            let audioData = try await generateTTSAudio(text: content)

            // Create storage area reference
            let storage = StorageAreaReference.temporary(requestID: requestID)

            // Create TypedDataStorage record
            let audioRecord = TypedDataStorage(
                id: requestID,
                providerId: "your-tts-provider",
                requestorID: "tts.default-voice",
                mimeType: "audio/mpeg",
                prompt: "Generate speech for element",
                modelIdentifier: "tts-model-1",
                audioFormat: "mp3",
                durationSeconds: Double(audioData.count) / 16000,
                voiceID: "default",
                voiceName: "Default Voice"
            )

            // Save binary to file and create file reference
            try audioRecord.saveBinary(
                audioData,
                to: storage,
                fileName: "element_\(element.persistentModelID.hashValue).mp3",
                mode: .local
            )

            // Associate with element
            if element.generatedContent == nil {
                element.generatedContent = []
            }
            element.generatedContent?.append(audioRecord)

            // Save to SwiftData
            modelContext.insert(audioRecord)
            try modelContext.save()

            print("Generated and stored audio file for element")
        } catch {
            print("Failed to generate audio: \(error)")
        }
    }

    private func generateTTSAudio(text: String) async throws -> Data {
        try await Task.sleep(for: .milliseconds(500))
        return Data(count: 1024)
    }
}

// MARK: - Preview

#Preview("With Audio Button") {
    @Previewable @Query var documents: [GuionDocumentModel]

    if let doc = documents.first {
        GuionElementsListWithAudioButton(document: doc)
            .modelContainer(for: [GuionDocumentModel.self, GuionElementModel.self, TypedDataStorage.self])
    } else {
        Text("No documents available")
    }
}
