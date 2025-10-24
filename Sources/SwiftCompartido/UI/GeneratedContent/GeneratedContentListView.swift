//
//  GeneratedContentListView.swift
//  SwiftCompartido
//
//  Master-detail view for browsing generated content with MIME type filtering
//

import SwiftUI
import SwiftData

/// MIME type filter options
public enum ContentTypeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case text = "Text"
    case audio = "Audio"
    case image = "Image"
    case video = "Video"
    case embedding = "Embedding"

    public var id: String { rawValue }

    /// MIME type prefix for filtering
    var mimeTypePrefix: String? {
        switch self {
        case .all: return nil
        case .text: return "text/"
        case .audio: return "audio/"
        case .image: return "image/"
        case .video: return "video/"
        case .embedding: return nil // Special case: exact match "application/x-embedding"
        }
    }

    /// Icon for the filter type
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .text: return "doc.text"
        case .audio: return "waveform"
        case .image: return "photo"
        case .video: return "video"
        case .embedding: return "point.3.connected.trianglepath.dotted"
        }
    }
}

/// Master-detail view for browsing and previewing generated content
///
/// Features:
/// - MIME type filtering (All, Text, Audio, Image, Video, Embedding)
/// - List of content items sorted by element order (chapterIndex, orderIndex)
/// - Preview pane showing selected item with appropriate viewer
/// - Audio playback support via AudioPlayerManager
///
/// ## Example
/// ```swift
/// struct ContentView: View {
///     @StateObject var audioPlayer = AudioPlayerManager()
///     let document: GuionDocumentModel
///     let storageArea: StorageAreaReference?
///
///     var body: some View {
///         GeneratedContentListView(
///             document: document,
///             storageArea: storageArea
///         )
///         .environmentObject(audioPlayer)
///     }
/// }
/// ```
public struct GeneratedContentListView: View {

    // MARK: - Properties

    /// The document whose content to display
    let document: GuionDocumentModel

    /// Optional storage area for file-based content
    let storageArea: StorageAreaReference?

    /// Current filter selection
    @State private var selectedFilter: ContentTypeFilter = .all

    /// Currently selected item for preview
    @State private var selectedItem: TypedDataStorage?

    /// Audio player manager (injected via environment)
    @EnvironmentObject private var audioPlayer: AudioPlayerManager

    // MARK: - Initialization

    /// Creates a list view for a document's generated content
    ///
    /// - Parameters:
    ///   - document: The document whose content to display
    ///   - storageArea: Optional storage area for file-based content
    public init(document: GuionDocumentModel, storageArea: StorageAreaReference? = nil) {
        self.document = document
        self.storageArea = storageArea
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Preview pane (top)
            if let selectedItem = selectedItem {
                TypedDataDetailView(record: selectedItem, storageArea: storageArea)
                    .frame(maxHeight: .infinity)
                    .background(Color(white: 0.95))

                Divider()
            } else {
                emptyStateView
                    .frame(maxHeight: .infinity)
                    .background(Color(white: 0.95))

                Divider()
            }

            // Filter picker
            Picker("Content Type", selection: $selectedFilter) {
                ForEach(ContentTypeFilter.allCases) { filter in
                    Label(filter.rawValue, systemImage: filter.icon)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: selectedFilter) { _, _ in
                // Clear selection when filter changes
                selectedItem = nil
            }

            Divider()

            // Content list (bottom)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredContent) { item in
                        TypedDataRowView(
                            record: item,
                            isSelected: selectedItem?.id == item.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleItemSelection(item)
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: .infinity)
        }
        .navigationTitle("Generated Content")
        .navigationSubtitle("\(filteredContent.count) items")
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Selection")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Select an item from the list below to preview")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed Properties

    /// Filtered content based on selected filter
    private var filteredContent: [TypedDataStorage] {
        switch selectedFilter {
        case .all:
            return document.sortedElementGeneratedContent
        case .text:
            return document.sortedElementGeneratedContent(mimeTypePrefix: "text/")
        case .audio:
            return document.sortedElementGeneratedContent(mimeTypePrefix: "audio/")
        case .image:
            return document.sortedElementGeneratedContent(mimeTypePrefix: "image/")
        case .video:
            return document.sortedElementGeneratedContent(mimeTypePrefix: "video/")
        case .embedding:
            // Special case: exact match for embeddings
            return document.sortedElementGeneratedContent.filter {
                $0.mimeType == "application/x-embedding"
            }
        }
    }

    // MARK: - Actions

    /// Handles item selection and starts audio playback if needed
    private func handleItemSelection(_ item: TypedDataStorage) {
        // Update selection
        selectedItem = item

        // If audio item, start playback
        if item.mimeType.hasPrefix("audio/") {
            do {
                // AudioPlayerManager accepts TypedDataStorage for audio playback
                try audioPlayer.play(record: item, storageArea: storageArea)
            } catch {
                print("Failed to play audio: \(error.localizedDescription)")
            }
        } else {
            // Stop any current audio playback for non-audio items
            audioPlayer.stop()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct GeneratedContentListView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview requires full SwiftData setup with ModelContainer
        // See tests for complete integration examples
        Text("GeneratedContentListView Preview")
            .frame(width: 800, height: 600)
    }
}
#endif
