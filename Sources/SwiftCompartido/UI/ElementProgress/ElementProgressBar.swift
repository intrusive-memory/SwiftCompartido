//
//  ElementProgressBar.swift
//  SwiftCompartido
//
//  Progress bar view for GuionElementModel operations
//

import SwiftUI
import SwiftData

/// Progress bar that appears below GuionElementsList items
///
/// Automatically shows when progress starts and hides after completion.
/// Access progress state via the environment.
public struct ElementProgressBar: View {
    /// The element to show progress for
    let element: GuionElementModel

    /// Progress state from environment
    @Environment(ElementProgressState.self) private var progressState

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        if progressState.hasVisibleProgress(for: element.persistentModelID),
           let progress = progressState.progress(for: element.persistentModelID) {
            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: progress.progress, total: 1.0)
                    .tint(progress.isComplete ? .green : .blue)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                // Optional message
                if let message = progress.message {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.2), value: progressState.hasVisibleProgress(for: element.persistentModelID))
        }
    }
}

// MARK: - Preview

#Preview("Progress States") {
    PreviewWrapper()
}

private struct PreviewWrapper: View {
    @State private var progressState = ElementProgressState()

    var body: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: GuionElementModel.self,
            configurations: config
        )

        let element1 = GuionElementModel(
            elementText: "Element with no progress",
            elementType: .dialogue,
            orderIndex: 1
        )

        let element2 = GuionElementModel(
            elementText: "Element with active progress",
            elementType: .dialogue,
            orderIndex: 2
        )

        let element3 = GuionElementModel(
            elementText: "Element with completed progress",
            elementType: .dialogue,
            orderIndex: 3
        )

        container.mainContext.insert(element1)
        container.mainContext.insert(element2)
        container.mainContext.insert(element3)

        progressState.setProgress(0.6, for: element2.persistentModelID, message: "Generating audio...")
        progressState.setComplete(for: element3.persistentModelID, message: "Complete!")

        return VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("No progress")
                    .font(.body)
                ElementProgressBar(element: element1)
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            VStack(alignment: .leading, spacing: 4) {
                Text("Active progress (60%)")
                    .font(.body)
                ElementProgressBar(element: element2)
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            VStack(alignment: .leading, spacing: 4) {
                Text("Completed")
                    .font(.body)
                ElementProgressBar(element: element3)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
        }
        .modelContainer(container)
        .environment(progressState)
    }
}
