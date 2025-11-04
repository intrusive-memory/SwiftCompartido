//
//  GuionElementsListWithPopover.swift
//  SwiftCompartido
//
//  Example usage of GuionElementsList with interactive popovers
//

import SwiftUI
import SwiftData

/// Example view demonstrating popover usage with GuionElementsList
///
/// This example shows how to add interactive popovers that display
/// element metadata and a GENERATE button for audio generation.
public struct GuionElementsListWithPopover: View {
    let document: GuionDocumentModel
    @State private var isGenerating: Set<PersistentIdentifier> = []

    public init(document: GuionDocumentModel) {
        self.document = document
    }

    public var body: some View {
        GuionElementsList(document: document)
            .guionElementPopover { element in
                popoverContent(for: element)
            }
    }

    /// Creates popover content for an element
    @ViewBuilder
    private func popoverContent(for element: GuionElementModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Element metadata
            Text(element.elementText.prefix(50))
                .font(.caption)
                .lineLimit(2)

            HStack {
                // Chapter and order info
                Text("Ch \(element.chapterIndex), #\(element.orderIndex)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                // Generate button
                if element.elementType == .dialogue || element.elementType == .action {
                    generateButton(for: element)
                }
            }
        }
    }

    /// Creates the GENERATE button for audio generation
    @ViewBuilder
    private func generateButton(for element: GuionElementModel) -> some View {
        Button {
            generateAudio(for: element)
        } label: {
            if isGenerating.contains(element.id) {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("Generate", systemImage: "waveform")
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(isGenerating.contains(element.id))
    }

    /// Generates audio for the element
    private func generateAudio(for element: GuionElementModel) {
        isGenerating.insert(element.id)

        // Simulate async generation
        Task {
            try? await Task.sleep(for: .seconds(2))
            isGenerating.remove(element.id)
        }
    }
}

// MARK: - Preview

#Preview("GuionElementsList with Popover") {
    @Previewable @State var document = GuionDocumentModel(filename: "Example.guion")

    GuionElementsListWithPopover(document: document)
        .modelContainer(for: [GuionDocumentModel.self, GuionElementModel.self], inMemory: true)
}

// MARK: - Usage Examples

/// # Basic Popover Usage
///
/// Display simple metadata in a popover:
///
/// ```swift
/// GuionElementsList(document: screenplay)
///     .guionElementPopover { element in
///         VStack(alignment: .leading) {
///             Text(element.elementText.prefix(50))
///             Text("Type: \(element.elementType.description)")
///                 .font(.caption)
///         }
///     }
/// ```
///
/// # Interactive Popover with Button
///
/// Add a GENERATE button for audio generation:
///
/// ```swift
/// GuionElementsList(document: screenplay)
///     .guionElementPopover { element in
///         VStack {
///             Text(element.elementText.prefix(50))
///             Button("Generate Audio") {
///                 generateAudio(for: element)
///             }
///             .buttonStyle(.borderedProminent)
///             .controlSize(.small)
///         }
///     }
/// ```
///
/// # Conditional Popover Content
///
/// Show different content based on element type:
///
/// ```swift
/// GuionElementsList(document: screenplay)
///     .guionElementPopover { element in
///         switch element.elementType {
///         case .dialogue:
///             VStack {
///                 Text("Dialogue: \(element.elementText.prefix(30))")
///                 Button("Generate Voice") { }
///             }
///         case .action:
///             VStack {
///                 Text("Action: \(element.elementText.prefix(30))")
///                 Button("Generate Narration") { }
///             }
///         default:
///             Text(element.elementText.prefix(50))
///         }
///     }
/// ```
///
/// # With Progress Tracking
///
/// Combine popovers with element progress tracking:
///
/// ```swift
/// @State private var progressState = ElementProgressState()
///
/// GuionElementsList(document: screenplay)
///     .environment(progressState)
///     .guionElementPopover { element in
///         VStack {
///             Text(element.elementText.prefix(50))
///             Button("Generate") {
///                 Task {
///                     let tracker = element.progressTracker(using: progressState)
///                     try await tracker.withProgress(
///                         startMessage: "Generating audio...",
///                         completeMessage: "Audio generated!"
///                     ) {
///                         try await generateAudio(element)
///                     }
///                 }
///             }
///         }
///     }
/// ```
///
/// # With Trailing Columns
///
/// Combine popovers with trailing column buttons:
///
/// ```swift
/// GuionElementsList(document: screenplay) { element in
///     Button("▶︎") {
///         playAudio(for: element)
///     }
/// }
/// .guionElementPopover { element in
///     VStack {
///         Text("Preview: \(element.elementText.prefix(30))")
///         Button("Generate New") {
///             generateAudio(for: element)
///         }
///     }
/// }
/// ```
///
/// # Custom Hover Delay
///
/// Adjust the hover delay for faster/slower popover appearance:
///
/// ```swift
/// GuionElementsList(document: screenplay)
///     .guionElementPopover(hoverDelay: 0.5) { element in
///         Text(element.elementText.prefix(50))
///     }
/// ```
