//
//  GuionElementsListWithProgress.swift
//  SwiftCompartido
//
//  Example demonstrating element-level progress tracking in GuionElementsList
//

import SwiftUI
import SwiftData

/// Example view showing progress bars for element operations
///
/// Demonstrates:
/// - Progress bars that appear during operations
/// - Auto-hide after completion
/// - Progress tracking with ElementProgressState
/// - Integration with element buttons
public struct GuionElementsListWithProgress: View {
    let document: GuionDocumentModel

    /// Progress state for tracking operations
    @State private var progressState = ElementProgressState()

    public init(document: GuionDocumentModel) {
        self.document = document
    }

    public var body: some View {
        VStack {
            // Example controls
            ExampleControlsView(progressState: progressState, document: document)
                .padding()
                .background(Color.gray.opacity(0.1))

            // List with progress bars
            GuionElementsList(document: document) { element in
                GenerateAudioElementButton(element: element)
                    .frame(width: 50)
            }
            .environment(progressState)
        }
    }
}

/// Example controls for demonstrating progress functionality
private struct ExampleControlsView: View {
    let progressState: ElementProgressState
    let document: GuionDocumentModel

    @Query private var elements: [GuionElementModel]

    init(progressState: ElementProgressState, document: GuionDocumentModel) {
        self.progressState = progressState
        self.document = document

        let documentID = document.persistentModelID
        _elements = Query(
            filter: #Predicate<GuionElementModel> { element in
                element.document?.persistentModelID == documentID
            },
            sort: [
                SortDescriptor(\GuionElementModel.chapterIndex),
                SortDescriptor(\GuionElementModel.orderIndex)
            ]
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Progress Demo Controls")
                .font(.headline)

            HStack(spacing: 12) {
                // Simulate progress on first element
                Button("Simulate Progress") {
                    guard let firstElement = elements.first else { return }
                    Task {
                        await simulateProgress(for: firstElement)
                    }
                }
                .buttonStyle(.borderedProminent)

                // Clear all progress
                Button("Clear All") {
                    progressState.clearAll()
                }
                .buttonStyle(.bordered)
            }

            Text("Click 'Simulate Progress' to see the progress bar appear below an element")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func simulateProgress(for element: GuionElementModel) async {
        let elementID = element.persistentModelID

        // Simulate a multi-step operation
        progressState.setProgress(0.0, for: elementID, message: "Starting...")
        try? await Task.sleep(for: .milliseconds(300))

        progressState.setProgress(0.25, for: elementID, message: "Processing text...")
        try? await Task.sleep(for: .milliseconds(400))

        progressState.setProgress(0.5, for: elementID, message: "Generating audio...")
        try? await Task.sleep(for: .milliseconds(500))

        progressState.setProgress(0.75, for: elementID, message: "Finalizing...")
        try? await Task.sleep(for: .milliseconds(300))

        progressState.setComplete(for: elementID, message: "Complete!")
        // Progress bar will auto-hide after 2 seconds
    }
}

// MARK: - Preview

#Preview("With Progress") {
    @Previewable @Query var documents: [GuionDocumentModel]

    if let doc = documents.first {
        GuionElementsListWithProgress(document: doc)
            .modelContainer(for: [
                GuionDocumentModel.self,
                GuionElementModel.self,
                TypedDataStorage.self
            ])
    } else {
        Text("No documents available")
    }
}
