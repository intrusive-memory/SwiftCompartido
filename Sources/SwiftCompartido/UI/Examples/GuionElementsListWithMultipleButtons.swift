//
//  GuionElementsListWithMultipleButtons.swift
//  SwiftCompartido
//
//  Example showing how to combine multiple element buttons in GuionElementsList
//

import SwiftUI
import SwiftData

/// Example view demonstrating multiple buttons per element row
///
/// Shows three different layout patterns:
/// 1. Horizontal layout with all buttons visible
/// 2. Conditional buttons based on element type
/// 3. Compact layout with Menu for actions
public struct GuionElementsListWithMultipleButtons: View {
    let document: GuionDocumentModel

    public init(document: GuionDocumentModel) {
        self.document = document
    }

    public var body: some View {
        TabView {
            // Pattern 1: All buttons visible
            allButtonsLayout
                .tabItem {
                    Label("All Buttons", systemImage: "rectangle.3.group")
                }

            // Pattern 2: Conditional buttons
            conditionalLayout
                .tabItem {
                    Label("Conditional", systemImage: "line.3.horizontal.decrease.circle")
                }

            // Pattern 3: Compact menu
            compactMenuLayout
                .tabItem {
                    Label("Compact", systemImage: "ellipsis.circle")
                }
        }
    }

    // MARK: - Pattern 1: All Buttons Visible

    private var allButtonsLayout: some View {
        GuionElementsList(document: document) { element in
            HStack(spacing: 8) {
                // Audio generation button
                GenerateAudioElementButton(element: element)
                    .frame(width: 50)

                // Metadata button
                ElementMetadataButton(element: element)
                    .frame(width: 30)

                Divider()
                    .frame(height: 20)

                // Position indicator
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(element.chapterIndex)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(element.orderIndex)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 30)
            }
            .frame(width: 150)
        }
    }

    // MARK: - Pattern 2: Conditional Buttons

    private var conditionalLayout: some View {
        GuionElementsList(document: document) { element in
            HStack(spacing: 8) {
                // Always show metadata
                ElementMetadataButton(element: element)

                // Only show audio button for dialogue and action
                if element.elementType == .dialogue || element.elementType == .action {
                    GenerateAudioElementButton(element: element)
                }

                // Only show scene info for scene headings
                if element.elementType == .sceneHeading,
                   let location = element.cachedSceneLocation {
                    Text(location.lighting.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .frame(minWidth: 80, maxWidth: 150)
        }
    }

    // MARK: - Pattern 3: Compact Menu

    private var compactMenuLayout: some View {
        GuionElementsList(document: document) { element in
            HStack(spacing: 4) {
                // Quick audio count indicator
                if let audioCount = element.generatedContent?.filter({ $0.mimeType.hasPrefix("audio/") }).count,
                   audioCount > 0 {
                    Text("\(audioCount)")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                } else {
                    Color.clear.frame(width: 20)
                }

                // Compact menu with all actions
                Menu {
                    Button {
                        // Generate audio action
                    } label: {
                        Label("Generate Audio", systemImage: "waveform")
                    }

                    Button {
                        // View metadata action
                    } label: {
                        Label("View Details", systemImage: "info.circle")
                    }

                    Divider()

                    Button {
                        // Delete element action
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 60)
        }
    }
}

// MARK: - Preview

#Preview("Multiple Buttons") {
    @Previewable @Query var documents: [GuionDocumentModel]

    if let doc = documents.first {
        GuionElementsListWithMultipleButtons(document: doc)
            .modelContainer(for: [
                GuionDocumentModel.self,
                GuionElementModel.self,
                TypedDataStorage.self
            ])
    } else {
        Text("No documents available")
    }
}
