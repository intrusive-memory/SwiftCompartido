//
//  GuionViewer.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//
//  Simple viewer component for displaying screenplay documents from SwiftData
//

#if canImport(SwiftUI)
import SwiftUI
@preconcurrency import SwiftData

/// Simple viewer for displaying GuionDocumentModel using GuionElementsList
///
/// ## Overview
///
/// GuionViewer is a lightweight wrapper around `GuionElementsList` that provides a simple API
/// for displaying screenplay documents from SwiftData. The viewer has been simplified in version
/// 1.4.3 from 479 lines to 52 lines by removing complex file loading, error handling, and
/// hierarchical display logic.
///
/// ## Architecture
///
/// The viewer uses a **flat, list-based architecture**:
/// - Elements displayed sequentially in document order
/// - No grouping or hierarchy
/// - Direct SwiftData @Query for efficient updates
/// - Simple switch/case for element type rendering
///
/// ## Usage
///
/// ### Basic Display
///
/// ```swift
/// import SwiftUI
/// import SwiftData
///
/// struct ScreenplayView: View {
///     let document: GuionDocumentModel
///
///     var body: some View {
///         GuionViewer(document: document)
///             .environment(\.screenplayFontSize, 12)
///     }
/// }
/// ```
///
/// ### With Document Query
///
/// ```swift
/// struct DocumentListView: View {
///     @Query private var documents: [GuionDocumentModel]
///
///     var body: some View {
///         List(documents) { document in
///             NavigationLink(document.title ?? "Untitled") {
///                 GuionViewer(document: document)
///             }
///         }
///     }
/// }
/// ```
///
/// ### Font Size Control
///
/// ```swift
/// struct CustomFontView: View {
///     @State private var fontSize: CGFloat = 12
///
///     var body: some View {
///         VStack {
///             GuionViewer(document: document)
///                 .environment(\.screenplayFontSize, fontSize)
///
///             Slider(value: $fontSize, in: 8...18)
///         }
///     }
/// }
/// ```
///
/// ## Migration from 1.4.2
///
/// **Old API (deprecated):**
/// ```swift
/// let screenplay = parser.parse(text)
/// GuionViewer(screenplay: screenplay)
/// ```
///
/// **New API (1.4.3+):**
/// ```swift
/// // Parse and convert to SwiftData
/// let screenplay = parser.parse(text)
/// let document = await GuionDocumentParserSwiftData.parse(
///     script: screenplay,
///     in: modelContext
/// )
///
/// // Display using document model
/// GuionViewer(document: document)
/// ```
///
/// ## See Also
///
/// - `GuionElementsList` - The underlying list component
/// - `GuionDocumentModel` - SwiftData model for screenplay documents
/// - `GuionElementModel` - SwiftData model for individual screenplay elements
///
public struct GuionViewer: View {
    /// The document to display
    private let document: GuionDocumentModel

    /// Font size state
    @State private var fontSize: CGFloat = 12

    /// Create a viewer from a GuionDocumentModel
    /// - Parameter document: The SwiftData document to display
    public init(document: GuionDocumentModel) {
        self.document = document
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Title bar with font controls
            HStack {
                Text(document.title ?? "Untitled")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                // Font size controls
                HStack(spacing: 12) {
                    Button {
                        decreaseFontSize()
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.title3)
                    }
                    .keyboardShortcut("-", modifiers: .command)
                    .help("Decrease font size (⌘-)")
                    .accessibilityLabel("Decrease font size")
                    .accessibilityHint("Decreases the screenplay font size by 1 point")
                    .accessibilityValue("\(Int(fontSize)) points")

                    Text("\(Int(fontSize))pt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 30)
                        .accessibilityLabel("Current font size: \(Int(fontSize)) points")
                        .accessibilityAddTraits(.updatesFrequently)

                    Button {
                        increaseFontSize()
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                    }
                    .keyboardShortcut("=", modifiers: .command)
                    .help("Increase font size (⌘=)")
                    .accessibilityLabel("Increase font size")
                    .accessibilityHint("Increases the screenplay font size by 1 point")
                    .accessibilityValue("\(Int(fontSize)) points")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            Divider()

            // Screenplay content
            GuionElementsList(document: document)
                .environment(\.screenplayFontSize, fontSize)
        }
    }

    private func increaseFontSize() {
        fontSize = min(24, fontSize + 1)
    }

    private func decreaseFontSize() {
        fontSize = max(8, fontSize - 1)
    }
}

// MARK: - Preview

#Preview("GuionViewer") {
    // Note: Requires SwiftData ModelContext with GuionDocumentModel data
    Text("GuionViewer requires SwiftData context")
        .frame(width: 600, height: 800)
}

#endif // canImport(SwiftUI)
