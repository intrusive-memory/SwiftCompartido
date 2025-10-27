//
//  ElementProgressTrackerExamples.swift
//  SwiftCompartido
//
//  Examples demonstrating different ways to use ElementProgressTracker
//

import SwiftUI
import SwiftData

/// Examples showing various progress tracking patterns
///
/// Demonstrates:
/// 1. Basic progress tracking with tracker
/// 2. Using withProgress convenience method
/// 3. Using withSteps for multi-step operations
public struct ElementProgressTrackerExamples: View {
    let document: GuionDocumentModel

    @State private var progressState = ElementProgressState()

    public init(document: GuionDocumentModel) {
        self.document = document
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Progress Tracker Examples")
                .font(.headline)
                .padding()

            GuionElementsList(document: document) { element in
                HStack(spacing: 12) {
                    // Example 1: Basic tracking
                    Button("Basic") {
                        Task {
                            await basicProgressExample(element)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    // Example 2: With progress convenience
                    Button("Convenience") {
                        Task {
                            await withProgressExample(element)
                        }
                    }
                    .buttonStyle(.bordered)

                    // Example 3: Step-based
                    Button("Steps") {
                        Task {
                            await stepsExample(element)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(width: 300)
            }
            .environment(progressState)
        }
    }

    // MARK: - Example 1: Basic Progress Tracking

    /// Basic usage with manual progress updates
    private func basicProgressExample(_ element: GuionElementModel) async {
        // Get scoped progress tracker
        let tracker = element.progressTracker(using: progressState)

        // Manual progress tracking
        tracker.setProgress(0.0, message: "Starting...")
        try? await Task.sleep(for: .milliseconds(500))

        tracker.setProgress(0.33, message: "Step 1...")
        try? await Task.sleep(for: .milliseconds(500))

        tracker.setProgress(0.66, message: "Step 2...")
        try? await Task.sleep(for: .milliseconds(500))

        tracker.setComplete(message: "Done!")
    }

    // MARK: - Example 2: Using withProgress Convenience Method

    /// Using the withProgress convenience method for automatic error handling
    private func withProgressExample(_ element: GuionElementModel) async {
        let tracker = element.progressTracker(using: progressState)

        do {
            try await tracker.withProgress(
                startMessage: "Processing element...",
                completeMessage: "Processing complete!"
            ) { updateProgress in
                // Simulate multi-stage operation
                updateProgress(0.2, "Analyzing content...")
                try await Task.sleep(for: .milliseconds(400))

                updateProgress(0.5, "Processing...")
                try await Task.sleep(for: .milliseconds(400))

                updateProgress(0.8, "Finalizing...")
                try await Task.sleep(for: .milliseconds(400))

                // Return result
                return "Success"
            }
        } catch {
            // Errors are automatically reported via tracker.setError()
            print("Operation failed: \(error)")
        }
    }

    // MARK: - Example 3: Step-Based Progress

    /// Using withSteps for operations with discrete steps
    private func stepsExample(_ element: GuionElementModel) async {
        let tracker = element.progressTracker(using: progressState)

        let steps = [
            "Analyzing text...",
            "Generating audio...",
            "Applying effects...",
            "Saving file..."
        ]

        do {
            try await tracker.withSteps(steps) { index, step in
                print("Executing step \(index): \(step)")
                try await Task.sleep(for: .milliseconds(400))

                // Simulate occasional error
                if index == 2 && Bool.random() {
                    throw NSError(domain: "Example", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Random error in step \(index)"
                    ])
                }
            }
        } catch {
            print("Step failed: \(error)")
        }
    }
}

// MARK: - Real-World Example: Audio Generation

/// Real-world example showing audio generation with progress tracking
public struct AudioGenerationWithTrackerExample: View {
    let element: GuionElementModel

    @Environment(ElementProgressState.self) private var progressState
    @Environment(\.modelContext) private var modelContext

    public var body: some View {
        Button("Generate Audio") {
            Task {
                await generateAudioWithTracker()
            }
        }
    }

    private func generateAudioWithTracker() async {
        let tracker = element.progressTracker(using: progressState)

        do {
            // Use withProgress for automatic error handling
            let audioData = try await tracker.withProgress(
                startMessage: "Preparing TTS...",
                completeMessage: "Audio generated!"
            ) { updateProgress in

                // Step 1: Prepare text
                updateProgress(0.1, "Preparing text...")
                let text = element.elementText
                guard !text.isEmpty else {
                    throw NSError(domain: "AudioGen", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Empty text"
                    ])
                }

                // Step 2: Generate audio
                updateProgress(0.3, "Generating audio...")
                let audio = try await generateTTS(text: text) { progress in
                    updateProgress(0.3 + (progress * 0.5), "Generating audio...")
                }

                // Step 3: Save
                updateProgress(0.9, "Saving...")
                try await saveAudio(audio, for: element)

                return audio
            }

            print("Generated \(audioData.count) bytes of audio")

        } catch {
            print("Audio generation failed: \(error)")
            // Error is automatically shown in progress bar
        }
    }

    private func generateTTS(text: String, onProgress: @escaping (Double) -> Void) async throws -> Data {
        // Simulate TTS generation with progress
        for i in 1...5 {
            try await Task.sleep(for: .milliseconds(200))
            onProgress(Double(i) / 5.0)
        }
        return Data(count: 1024)
    }

    private func saveAudio(_ data: Data, for element: GuionElementModel) async throws {
        let record = TypedDataStorage(
            id: UUID(),
            providerId: "tts-provider",
            requestorID: "tts.voice",
            mimeType: "audio/mpeg",
            binaryValue: data,
            prompt: "Generated for element",
            audioFormat: "mp3"
        )

        if element.generatedContent == nil {
            element.generatedContent = []
        }
        element.generatedContent?.append(record)

        modelContext.insert(record)
        try modelContext.save()
    }
}

// MARK: - Query Progress Example

/// Example showing how to query progress state
public struct ProgressQueryExample: View {
    let element: GuionElementModel

    @Environment(ElementProgressState.self) private var progressState

    public var body: some View {
        VStack(spacing: 8) {
            // Check if element has progress
            if element.hasVisibleProgress(in: progressState) {
                Text("⏳ Operation in progress")
                    .font(.caption)
                    .foregroundStyle(.blue)

                // Get current progress
                if let progress = element.currentProgress(in: progressState) {
                    HStack {
                        Text("\(Int(progress.progress * 100))%")
                        if let message = progress.message {
                            Text("- \(message)")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            } else {
                Text("No active operations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Start Operation") {
                Task {
                    await performOperation()
                }
            }
        }
    }

    private func performOperation() async {
        let tracker = element.progressTracker(using: progressState)

        tracker.setProgress(0.0, message: "Starting...")
        try? await Task.sleep(for: .seconds(1))

        tracker.setProgress(0.5, message: "Processing...")
        try? await Task.sleep(for: .seconds(1))

        tracker.setComplete(message: "Done!")
    }
}

// MARK: - Preview

#Preview("Tracker Examples") {
    @Previewable @Query var documents: [GuionDocumentModel]

    if let doc = documents.first {
        ElementProgressTrackerExamples(document: doc)
            .modelContainer(for: [
                GuionDocumentModel.self,
                GuionElementModel.self,
                TypedDataStorage.self
            ])
    } else {
        Text("No documents available")
    }
}
