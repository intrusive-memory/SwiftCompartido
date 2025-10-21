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
import SwiftData

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

    /// Create a viewer from a GuionDocumentModel
    /// - Parameter document: The SwiftData document to display
    public init(document: GuionDocumentModel) {
        self.document = document
    }

    public var body: some View {
        GuionElementsList(document: document)
    }
}

// MARK: - Preview

#Preview("GuionViewer") {
    // Note: Requires SwiftData ModelContext with GuionDocumentModel data
    Text("GuionViewer requires SwiftData context")
        .frame(width: 600, height: 800)
}

#endif // canImport(SwiftUI)
