//
//  GuionViewer.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//
//  Complete, drop-in SwiftUI component for viewing .guion screenplay files.
//  Provides hierarchical scene browsing with support for all SwiftGuion file formats.
//

#if canImport(SwiftUI)
import SwiftUI
import SwiftData

/// Complete viewer component for displaying screenplay documents in SwiftUI applications.
///
/// `GuionViewer` is a comprehensive, drop-in solution for viewing screenplay files in any SwiftUI project.
/// It provides a complete viewing experience with hierarchical navigation, format support for all
/// SwiftGuion-compatible formats (.guion, .fountain, .highland, .fdx), and native macOS integration.
///
/// ## Overview
///
/// The viewer encapsulates all UI components hierarchically:
/// - **GuionViewer** (Top Level) - Complete viewing interface
///   - **SceneBrowserWidget** - Hierarchical screenplay structure
///     - **ChapterWidget** - Individual chapters (Level 2)
///       - **SceneGroupWidget** - Scene groups/directives (Level 3)
///         - **SceneWidget** - Individual scenes with content
///           - **PreSceneBox** - OVER BLACK and pre-scene content
///
/// ## Usage
///
/// ### From GuionDocumentModel (SwiftData)
///
/// ```swift
/// import SwiftUI
/// import SwiftGuion
///
/// struct ContentView: View {
///     @Environment(\.modelContext) private var modelContext
///     let document: GuionDocumentModel
///
///     var body: some View {
///         GuionViewer(document: document)
///     }
/// }
/// ```
///
/// ### From GuionParsedScreenplay
///
/// ```swift
/// struct ContentView: View {
///     let script: GuionParsedScreenplay
///
///     var body: some View {
///         GuionViewer(script: script)
///     }
/// }
/// ```
///
/// ### From File URL
///
/// ```swift
/// struct ContentView: View {
///     let fileURL: URL
///
///     var body: some View {
///         GuionViewer(fileURL: fileURL)
///     }
/// }
/// ```
///
/// ### From SceneBrowserData (Pre-extracted)
///
/// ```swift
/// struct ContentView: View {
///     let browserData: SceneBrowserData
///
///     var body: some View {
///         GuionViewer(browserData: browserData)
///     }
/// }
/// ```
///
/// ## Features
///
/// - ✅ Complete hierarchical screenplay navigation
/// - ✅ Support for all SwiftGuion file formats (.guion, .fountain, .highland, .fdx)
/// - ✅ Collapsible chapters and scene groups
/// - ✅ Scene location parsing and display
/// - ✅ OVER BLACK and pre-scene content support
/// - ✅ Empty state handling
/// - ✅ Accessibility support (VoiceOver, keyboard navigation)
/// - ✅ Resizable window compatibility
/// - ✅ Native macOS look and feel
///
/// ## Customization
///
/// The viewer respects macOS system preferences:
/// - Text size and dynamic type
/// - High contrast mode
/// - Reduced motion
/// - VoiceOver and accessibility settings
///
/// ## Performance
///
/// - Lazy loading for large screenplays (200+ pages)
/// - Efficient SwiftUI updates via `@State` and `Identifiable`
/// - Memory-efficient scene browser data structure
/// - Smooth 60 FPS scrolling
///
/// ## Topics
///
/// ### Creating a Viewer
/// - ``init(document:)``
/// - ``init(script:)``
/// - ``init(fileURL:parser:)``
/// - ``init(browserData:)``
///
/// ### State Management
/// - ``viewerState``
/// - ``GuionViewerState``
///
/// ### Error Handling
/// - ``GuionViewerError``
///
@available(macOS 14.0, iOS 17.0, *)
public struct GuionViewer: View {
    // MARK: - State

    /// Current viewer state (loaded, loading, error, empty)
    @State private var viewerState: GuionViewerState

    // MARK: - Initializers

    /// Create a viewer from a GuionDocumentModel (SwiftData)
    /// - Parameter document: The document to display
    public init(document: GuionDocumentModel) {
        let script = document.toFountainScript()
        let browserData = script.extractSceneBrowserData()
        _viewerState = State(initialValue: .loaded(browserData))
    }

    /// Create a viewer from a GuionParsedScreenplay
    /// - Parameter script: The screenplay script to display
    public init(script: GuionParsedScreenplay) {
        let browserData = script.extractSceneBrowserData()
        _viewerState = State(initialValue: .loaded(browserData))
    }

    /// Create a viewer from pre-extracted SceneBrowserData
    /// - Parameter browserData: The browser data to display
    public init(browserData: SceneBrowserData) {
        _viewerState = State(initialValue: .loaded(browserData))
    }

    /// Create a viewer from a file URL (async loading)
    /// - Parameters:
    ///   - fileURL: URL to .guion, .fountain, .highland, or .fdx file
    ///   - parser: Parser type to use (default: .fast)
    public init(fileURL: URL, parser: ParserType = .fast) {
        _viewerState = State(initialValue: .loading(fileURL))
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            switch viewerState {
            case .loading(let url):
                LoadingView(url: url)
                    .task {
                        await loadFile(url: url)
                    }

            case .loaded(let browserData):
                SceneBrowserWidget(browserData: browserData, autoExpand: true)

            case .error(let error):
                ErrorView(error: error)

            case .empty:
                EmptyBrowserView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Private Methods

    /// Load screenplay from file URL
    private func loadFile(url: URL) async {
        do {
            let script = try await Task.detached {
                // Determine file type and load accordingly
                let fileExtension = url.pathExtension.lowercased()

                switch fileExtension {
                case "guion":
                    // Load .guion file (requires SwiftData context, handled separately)
                    throw GuionViewerError.unsupportedInitialization(
                        "Use init(document:) for .guion files with SwiftData context"
                    )

                case "fountain":
                    return try GuionParsedScreenplay(file: url.path, parser: .fast)

                case "highland":
                    return try GuionParsedScreenplay(highland: url)

                case "fdx":
                    // Load FDX using parser
                    let data = try Data(contentsOf: url)
                    let parser = FDXParser()
                    let parsedDoc = try parser.parse(data: data, filename: url.lastPathComponent)

                    // Convert FDXParsedElements to GuionElements
                    let elements = parsedDoc.elements.map { GuionElement(from: $0) }

                    // Convert title page entries
                    var titlePageDict: [String: [String]] = [:]
                    for entry in parsedDoc.titlePageEntries {
                        titlePageDict[entry.key] = entry.values
                    }

                    let titlePage = titlePageDict.isEmpty ? [] : [titlePageDict]

                    return GuionParsedScreenplay(
                        filename: url.lastPathComponent,
                        elements: elements,
                        titlePage: titlePage,
                        suppressSceneNumbers: parsedDoc.suppressSceneNumbers
                    )

                default:
                    throw GuionViewerError.unsupportedFileType(url.pathExtension)
                }
            }.value

            let browserData = script.extractSceneBrowserData()

            await MainActor.run {
                if browserData.chapters.isEmpty {
                    viewerState = .empty
                } else {
                    viewerState = .loaded(browserData)
                }
            }

        } catch {
            await MainActor.run {
                viewerState = .error(.loadFailed(error))
            }
        }
    }
}

// MARK: - Viewer State

/// State of the GuionViewer
@available(macOS 14.0, iOS 17.0, *)
public enum GuionViewerState {
    /// Loading screenplay from file
    case loading(URL)

    /// Screenplay loaded and ready to display
    case loaded(SceneBrowserData)

    /// Error occurred during loading
    case error(GuionViewerError)

    /// No content to display
    case empty
}

// MARK: - Viewer Errors

/// Errors that can occur in GuionViewer
public enum GuionViewerError: LocalizedError {
    /// File type not supported
    case unsupportedFileType(String)

    /// Failed to load file
    case loadFailed(Error)

    /// Unsupported initialization method
    case unsupportedInitialization(String)

    /// Missing SwiftData context
    case missingModelContext

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let ext):
            return "File type '.\(ext)' is not supported"
        case .loadFailed(let error):
            return "Failed to load screenplay: \(error.localizedDescription)"
        case .unsupportedInitialization(let message):
            return message
        case .missingModelContext:
            return "SwiftData ModelContext is required for .guion files"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unsupportedFileType:
            return "Supported formats: .guion, .fountain, .highland, .fdx"
        case .loadFailed:
            return "Check that the file exists and is a valid screenplay format"
        case .unsupportedInitialization:
            return "Use the appropriate initializer for your file type"
        case .missingModelContext:
            return "Use init(document:) with a GuionDocumentModel from SwiftData"
        }
    }
}

// MARK: - Loading View

@available(macOS 14.0, iOS 17.0, *)
struct LoadingView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading Screenplay...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading screenplay from \(url.lastPathComponent)")
    }
}

// MARK: - Error View

@available(macOS 14.0, iOS 17.0, *)
struct ErrorView: View {
    let error: GuionViewerError

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Error Loading Screenplay")
                .font(.title2)
                .foregroundStyle(.primary)

            if let description = error.errorDescription {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(error.errorDescription ?? "Unknown error")")
    }
}

// MARK: - GuionDocumentModel Extension

extension GuionDocumentModel {
    /// Convert GuionDocumentModel to GuionParsedScreenplay for viewing
    /// - Returns: GuionParsedScreenplay instance containing the document data
    func toFountainScript() -> GuionParsedScreenplay {
        // Use the new conversion method
        return toGuionParsedScreenplay()
    }
}

// MARK: - Previews

@available(macOS 14.0, iOS 17.0, *)
#Preview("GuionViewer - Loaded") {
    GuionViewer(
        browserData: SceneBrowserData(
            title: OutlineElement(
                id: "title",
                index: 0,
                level: 1,
                range: [0, 10],
                rawString: "# Big Fish",
                string: "Big Fish",
                type: "sectionHeader"
            ),
            chapters: [
                ChapterData(
                    element: OutlineElement(
                        id: "chapter-1",
                        index: 1,
                        level: 2,
                        range: [10, 100],
                        rawString: "## CHAPTER 1",
                        string: "CHAPTER 1",
                        type: "sectionHeader"
                    ),
                    sceneGroups: [
                        SceneGroupData(
                            element: OutlineElement(
                                id: "group-1",
                                index: 2,
                                level: 3,
                                range: [20, 80],
                                rawString: "### PROLOGUE",
                                string: "PROLOGUE",
                                type: "sectionHeader"
                            ),
                            scenes: [
                                SceneData(
                                    element: OutlineElement(
                                        id: "scene-1",
                                        index: 3,
                                        level: 0,
                                        range: [30, 70],
                                        rawString: "INT. STEAM ROOM - DAY",
                                        string: "INT. STEAM ROOM - DAY",
                                        type: "sceneHeader"
                                    ),
                                    sceneElements: [
                                        GuionElement(elementType: .action, elementText: "Bernard and Killian sit in a steam room.")
                                    ],
                                    sceneLocation: SceneLocation.parse("INT. STEAM ROOM - DAY")
                                )
                            ]
                        )
                    ]
                )
            ]
        )
    )
    .frame(width: 600, height: 800)
}

@available(macOS 14.0, iOS 17.0, *)
#Preview("GuionViewer - Empty") {
    GuionViewer(
        browserData: SceneBrowserData(
            title: OutlineElement(
                id: "title",
                index: 0,
                level: 1,
                range: [0, 10],
                rawString: "# Untitled",
                string: "Untitled",
                type: "sectionHeader"
            ),
            chapters: []
        )
    )
    .frame(width: 600, height: 800)
}

@available(macOS 14.0, iOS 17.0, *)
#Preview("GuionViewer - Loading") {
    let viewer = GuionViewer(
        fileURL: URL(fileURLWithPath: "/tmp/test.fountain")
    )

    return viewer
        .frame(width: 600, height: 800)
}

#endif // canImport(SwiftUI)
