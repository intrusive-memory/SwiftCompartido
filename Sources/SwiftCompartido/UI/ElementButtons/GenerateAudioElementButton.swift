//
//  GenerateAudioElementButton.swift
//  SwiftCompartido
//
//  Button to generate text-to-speech audio for screenplay elements
//

import SwiftUI
import SwiftData

/// Button to generate TTS audio for dialogue, character, and action elements
///
/// This button generates audio for screenplay elements and stores it in SwiftData.
/// The audio is associated with the element via the generatedContent relationship.
///
/// ## Usage
/// ```swift
/// GuionElementsList(document: screenplay) { element in
///     GenerateAudioElementButton(element: element)
/// }
/// ```
public struct GenerateAudioElementButton: View {
    /// The screenplay element this button operates on
    let element: GuionElementModel

    /// SwiftData context for saving generated content
    @Environment(\.modelContext) private var modelContext

    /// Progress state for tracking generation progress
    @Environment(ElementProgressState.self) private var progressState

    /// Loading state indicator
    @State private var isGenerating = false

    /// Error message for alert display
    @State private var errorMessage: String?

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        Button {
            Task {
                await generateAudio()
            }
        } label: {
            if isGenerating {
                ProgressView()
                    .controlSize(.small)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: audioCount > 0 ? "waveform.circle.fill" : "waveform.circle")
                        .foregroundStyle(audioCount > 0 ? .blue : .primary)
                    if audioCount > 0 {
                        Text("\(audioCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isGenerating || !canGenerateAudio)
        .help(canGenerateAudio ? "Generate audio for this element" : "Audio generation not available for \(element.elementType)")
        .alert("Error Generating Audio", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// Check if audio generation is available for this element type
    private var canGenerateAudio: Bool {
        element.elementType == .dialogue ||
        element.elementType == .character ||
        element.elementType == .action
    }

    /// Count of existing audio files for this element
    private var audioCount: Int {
        element.generatedContent?.filter { $0.mimeType.hasPrefix("audio/") }.count ?? 0
    }

    /// Generate audio for the element
    private func generateAudio() async {
        isGenerating = true
        defer { isGenerating = false }

        // Get scoped progress tracker for this element
        let tracker = element.progressTracker(using: progressState)

        do {
            // Access element data
            let text = element.elementText
            let type = element.elementType

            // Skip if empty
            guard !text.isEmpty else {
                errorMessage = "Cannot generate audio for empty text"
                return
            }

            // Report initial progress
            tracker.setProgress(0.1, message: "Starting generation...")

            // TODO: Replace with your actual TTS service
            // Example services: ElevenLabs, OpenAI TTS, Azure Speech
            let audioData = try await mockGenerateTTS(text: text, progressHandler: { progress in
                tracker.setProgress(progress, message: "Generating audio...")
            })

            // Report saving progress
            tracker.setProgress(0.9, message: "Saving...")

            // Create TypedDataStorage record
            let audioRecord = TypedDataStorage(
                id: UUID(),
                providerId: "tts-provider",
                requestorID: "tts.default-voice",
                mimeType: "audio/mpeg",
                binaryValue: audioData,
                prompt: "Generate speech for \(type): \(text.prefix(50))...",
                modelIdentifier: "tts-1",
                audioFormat: "mp3",
                durationSeconds: Double(audioData.count) / 16000,
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

            // Mark as complete
            tracker.setComplete(message: "Audio generated!")

        } catch {
            errorMessage = error.localizedDescription
            tracker.setError(error)
        }
    }

    /// Mock TTS generation - replace with your actual implementation
    ///
    /// Example implementations:
    /// - ElevenLabs: Use ElevenLabs SDK
    /// - OpenAI: Use OpenAI API with TTS endpoint
    /// - Azure: Use Azure Cognitive Services Speech SDK
    private func mockGenerateTTS(text: String, progressHandler: @escaping (Double) -> Void) async throws -> Data {
        // Simulate progress over time
        for i in 1...5 {
            try await Task.sleep(for: .milliseconds(200))
            let progress = 0.1 + (Double(i) / 5.0) * 0.8 // Progress from 0.1 to 0.9
            progressHandler(progress)
        }

        // Return mock audio data
        // In production, replace with actual TTS service call
        return Data(count: 1024)
    }
}

// MARK: - Preview

#Preview("Single Button") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: GuionElementModel.self,
        configurations: config
    )

    let element = GuionElementModel(
        elementText: "This is sample dialogue text that will be converted to speech.",
        elementType: .dialogue,
        orderIndex: 1
    )
    container.mainContext.insert(element)

    return GenerateAudioElementButton(element: element)
        .modelContainer(container)
        .padding()
}

#Preview("In List Context") {
    @Previewable @Query var documents: [GuionDocumentModel]

    if let doc = documents.first {
        GuionElementsList(document: doc) { element in
            GenerateAudioElementButton(element: element)
                .frame(width: 50)
        }
        .modelContainer(for: [GuionDocumentModel.self, GuionElementModel.self, TypedDataStorage.self])
    } else {
        Text("No documents available")
    }
}
