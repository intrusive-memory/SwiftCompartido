//
//  ElementMetadataButton.swift
//  SwiftCompartido
//
//  Button to display element metadata in a popover
//

import SwiftUI
import SwiftData

/// Button that displays element metadata in a popover
///
/// Shows information about the element including:
/// - Element type and text
/// - Position (chapter and order index)
/// - Generated content count
/// - Scene information (for scene headings)
///
/// ## Usage
/// ```swift
/// GuionElementsList(document: screenplay) { element in
///     ElementMetadataButton(element: element)
/// }
/// ```
public struct ElementMetadataButton: View {
    /// The screenplay element this button displays metadata for
    let element: GuionElementModel

    /// Popover presentation state
    @State private var showingMetadata = false

    public init(element: GuionElementModel) {
        self.element = element
    }

    public var body: some View {
        Button {
            showingMetadata = true
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Show element details")
        .popover(isPresented: $showingMetadata) {
            MetadataView(element: element)
                .frame(minWidth: 250, minHeight: 150)
                .padding()
        }
    }
}

// MARK: - Metadata View

/// View displaying element metadata
private struct MetadataView: View {
    let element: GuionElementModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Element Details")
                .font(.headline)

            Divider()

            // Basic info
            InfoRow(label: "Type", value: element.elementType.description)
            InfoRow(label: "Chapter", value: "\(element.chapterIndex)")
            InfoRow(label: "Order", value: "\(element.orderIndex)")

            // Text content (truncated)
            VStack(alignment: .leading, spacing: 4) {
                Text("Content:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(element.elementText.prefix(100) + (element.elementText.count > 100 ? "..." : ""))
                    .font(.body)
                    .lineLimit(3)
            }

            // Scene info (if applicable)
            if let sceneLocation = element.cachedSceneLocation {
                Divider()
                Text("Scene Information")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                InfoRow(label: "Lighting", value: sceneLocation.lighting.description)
                InfoRow(label: "Location", value: sceneLocation.scene)
                if let timeOfDay = sceneLocation.timeOfDay {
                    InfoRow(label: "Time", value: timeOfDay)
                }
            }

            // Generated content count
            if let generatedContent = element.generatedContent, !generatedContent.isEmpty {
                Divider()
                Text("Generated Content")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                InfoRow(label: "Audio", value: "\(audioCount)")
                InfoRow(label: "Images", value: "\(imageCount)")
                InfoRow(label: "Total", value: "\(generatedContent.count)")
            }

            Spacer()
        }
    }

    private var audioCount: Int {
        element.generatedContent?.filter { $0.mimeType.hasPrefix("audio/") }.count ?? 0
    }

    private var imageCount: Int {
        element.generatedContent?.filter { $0.mimeType.hasPrefix("image/") }.count ?? 0
    }
}

/// Simple info row with label and value
private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
        }
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
        elementText: "INT. COFFEE SHOP - DAY",
        elementType: .sceneHeading,
        chapterIndex: 1,
        orderIndex: 5
    )
    container.mainContext.insert(element)

    return ElementMetadataButton(element: element)
        .modelContainer(container)
        .padding()
}

#Preview("In List Context") {
    @Previewable @Query var documents: [GuionDocumentModel]

    if let doc = documents.first {
        GuionElementsList(document: doc) { element in
            ElementMetadataButton(element: element)
                .frame(width: 30)
        }
        .modelContainer(for: [GuionDocumentModel.self, GuionElementModel.self])
    } else {
        Text("No documents available")
    }
}
