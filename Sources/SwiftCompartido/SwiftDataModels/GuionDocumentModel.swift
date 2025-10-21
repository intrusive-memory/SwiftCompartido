//
//  GuionDocumentModel.swift
//  FountainDocumentApp
//
//  Copyright (c) 2025
//

import Foundation
#if canImport(SwiftData)
import SwiftData

/// SwiftData model representing a complete screenplay document.
///
/// This is the root model for screenplay storage, containing all elements,
/// title page entries, document metadata, and source file tracking.
///
/// ## Overview
///
/// `GuionDocumentModel` is the persistent storage representation of a screenplay,
/// designed to work seamlessly with SwiftData for automatic persistence and iCloud sync.
///
/// ## Features
///
/// - **Screenplay Storage**: Complete element tree with title page metadata
/// - **SwiftData Integration**: Automatic persistence and iCloud sync
/// - **Source File Tracking** (NEW in 1.4.3): Track and detect changes to imported files
/// - **Location Management**: Parse and cache scene locations
/// - **Serialization**: Save and load to various formats
///
/// ## Example - Basic Usage
///
/// ```swift
/// let document = GuionDocumentModel(filename: "MyScript.guion")
///
/// let sceneHeading = GuionElementModel(
///     elementText: "INT. COFFEE SHOP - DAY",
///     elementType: "Scene Heading"
/// )
/// document.elements.append(sceneHeading)
///
/// modelContext.insert(document)
/// ```
///
/// ## Example - Source File Tracking
///
/// ```swift
/// // When importing a screenplay file
/// let parser = try await FountainParser(string: fountainText)
/// let document = await GuionDocumentParserSwiftData.parse(
///     script: parser.screenplay,
///     in: modelContext
/// )
///
/// // Track the source file
/// let success = document.setSourceFile(sourceURL)
/// try modelContext.save()
///
/// // Later: check for updates
/// switch document.sourceFileStatus() {
/// case .modified:
///     // Source file has changed - prompt user to re-import
///     showUpdatePrompt()
/// case .upToDate:
///     // All good
///     break
/// case .fileNotFound, .fileNotAccessible:
///     // Handle errors
///     showError()
/// case .noSourceFile:
///     // Document wasn't imported from a file
///     break
/// }
/// ```
///
/// ## Topics
///
/// ### Creating Documents
/// - ``init(filename:rawContent:suppressSceneNumbers:)``
///
/// ### Document Properties
/// - ``filename``
/// - ``rawContent``
/// - ``suppressSceneNumbers``
///
/// ### Content
/// - ``elements``
/// - ``titlePage``
///
/// ### Source File Tracking (NEW in 1.4.3)
/// - ``sourceFileBookmark``
/// - ``lastImportDate``
/// - ``sourceFileModificationDate``
/// - ``setSourceFile(_:)``
/// - ``resolveSourceFileURL()``
/// - ``isSourceFileModified()``
/// - ``sourceFileStatus()``
/// - ``SourceFileStatus``
///
/// ### Location Management
/// - ``reparseAllLocations()``
/// - ``sceneLocations``
///
/// ### Serialization
/// - ``save(to:)``
/// - ``load(from:in:)``
/// - ``validate()``
@Model
public final class GuionDocumentModel {
    public var filename: String?
    public var rawContent: String?
    public var suppressSceneNumbers: Bool

    @Relationship(deleteRule: .cascade, inverse: \GuionElementModel.document)
    public var elements: [GuionElementModel]

    /// Elements sorted by orderIndex (screenplay sequence order)
    ///
    /// **CRITICAL**: Always use this property when displaying, exporting, or processing elements
    /// to maintain screenplay sequence order. The `elements` relationship array does NOT guarantee
    /// order in SwiftData - sorting by orderIndex is required.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // DO: Use sortedElements for display/export
    /// for element in document.sortedElements {
    ///     print(element.elementText)
    /// }
    ///
    /// // DON'T: Use elements directly (order not guaranteed)
    /// for element in document.elements {  // ❌ Wrong - may be out of order
    ///     print(element.elementText)
    /// }
    /// ```
    ///
    /// - SeeAlso: `GuionElementModel.chapterIndex`, `GuionElementModel.orderIndex`
    public var sortedElements: [GuionElementModel] {
        elements.sorted {
            if $0.chapterIndex != $1.chapterIndex {
                return $0.chapterIndex < $1.chapterIndex
            }
            return $0.orderIndex < $1.orderIndex
        }
    }

    @Relationship(deleteRule: .cascade, inverse: \TitlePageEntryModel.document)
    public var titlePage: [TitlePageEntryModel]

    /// Generated AI content associated with this document
    ///
    /// Examples:
    /// - Document-level embeddings for semantic search
    /// - Auto-generated summaries
    /// - Generated cover images
    public var generatedContent: [TypedDataStorage]?

    // MARK: - Source File Tracking (NEW in 1.4.3)

    /// Security-scoped bookmark to the original source file
    ///
    /// This bookmark maintains access to the file across app launches, even in sandboxed applications.
    /// Created by calling `setSourceFile(_:)` when importing a screenplay.
    ///
    /// - Note: For sandboxed macOS apps, the user must select the file via an open panel to create
    ///   a valid bookmark.
    ///
    /// - SeeAlso: `setSourceFile(_:)`, `resolveSourceFileURL()`
    public var sourceFileBookmark: Data?

    /// Date when this document was last imported from source
    ///
    /// Automatically set by `setSourceFile(_:)` to track when the import occurred.
    /// Useful for displaying "last updated" information to users.
    ///
    /// - SeeAlso: `setSourceFile(_:)`
    public var lastImportDate: Date?

    /// Modification date of source file at time of import
    ///
    /// Used to detect if the source file has been modified since import by comparing against
    /// the current file modification date. Updated automatically by `setSourceFile(_:)`.
    ///
    /// - SeeAlso: `isSourceFileModified()`, `sourceFileStatus()`
    public var sourceFileModificationDate: Date?

    public init(filename: String? = nil, rawContent: String? = nil, suppressSceneNumbers: Bool = false) {
        self.filename = filename
        self.rawContent = rawContent
        self.suppressSceneNumbers = suppressSceneNumbers
        self.elements = []
        self.titlePage = []
        self.sourceFileBookmark = nil
        self.lastImportDate = nil
        self.sourceFileModificationDate = nil
    }

    /// Reparse all scene heading locations (useful for migration or updates)
    public func reparseAllLocations() {
        for element in sortedElements where element.elementType == .sceneHeading {
            element.reparseLocation()
        }
    }

    /// Get all scene elements with their cached locations in screenplay order
    public var sceneLocations: [(element: GuionElementModel, location: SceneLocation)] {
        return sortedElements.compactMap { element in
            guard let location = element.cachedSceneLocation else { return nil }
            return (element, location)
        }
    }

    // MARK: - Source File Tracking Methods (NEW in 1.4.3)

    /// Resolve the source file bookmark to a URL
    ///
    /// This method converts the stored bookmark into a URL that can be used to
    /// access the original source file. The bookmark is automatically refreshed if it becomes stale.
    ///
    /// - Returns: URL if bookmark can be resolved and file is accessible, nil otherwise
    ///
    /// ## Usage
    ///
    /// ```swift
    /// if let sourceURL = document.resolveSourceFileURL() {
    ///     let accessing = sourceURL.startAccessingSecurityScopedResource()
    ///     defer {
    ///         if accessing {
    ///             sourceURL.stopAccessingSecurityScopedResource()
    ///         }
    ///     }
    ///
    ///     // Work with the file
    ///     let updatedText = try String(contentsOf: sourceURL)
    /// }
    /// ```
    ///
    /// - Note: For sandboxed apps, you must call `startAccessingSecurityScopedResource()` before
    ///   accessing the file, and `stopAccessingSecurityScopedResource()` when done.
    ///
    /// - SeeAlso: `setSourceFile(_:)`, `sourceFileStatus()`
    public func resolveSourceFileURL() -> URL? {
        guard let bookmarkData = sourceFileBookmark else { return nil }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Bookmark is stale, try to recreate it
                if let newBookmark = try? url.bookmarkData(
                    options: [],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    sourceFileBookmark = newBookmark
                }
            }

            return url
        } catch {
            return nil
        }
    }

    /// Set the source file from a URL, creating a bookmark
    ///
    /// This method creates a bookmark to the source file and records the current
    /// modification date and import timestamp. Call this immediately after importing a screenplay
    /// to enable source file tracking.
    ///
    /// - Parameter url: The URL to the source file (must be user-selected for sandboxed apps)
    /// - Returns: True if bookmark was created successfully, false if creation failed
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // After parsing a screenplay
    /// let parser = try await FountainParser(string: fountainText)
    /// let document = await GuionDocumentParserSwiftData.parse(
    ///     script: parser.screenplay,
    ///     in: modelContext
    /// )
    ///
    /// // Set the source file
    /// let success = document.setSourceFile(sourceURL)
    /// if success {
    ///     try modelContext.save()
    /// } else {
    ///     // Handle bookmark creation failure
    ///     print("Failed to create bookmark")
    /// }
    /// ```
    ///
    /// ## Properties Updated
    ///
    /// This method automatically updates:
    /// - `sourceFileBookmark` - Bookmark data
    /// - `lastImportDate` - Set to current date/time
    /// - `sourceFileModificationDate` - Set to file's modification date
    ///
    /// - Note: For sandboxed macOS apps, the URL must come from a user file selection
    ///   (NSOpenPanel) to create a valid bookmark.
    ///
    /// - SeeAlso: `resolveSourceFileURL()`, `isSourceFileModified()`, `sourceFileStatus()`
    @discardableResult
    public func setSourceFile(_ url: URL) -> Bool {
        do {
            // Create bookmark
            let bookmarkData = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            sourceFileBookmark = bookmarkData
            lastImportDate = Date()

            // Get file modification date
            let resourceValues = try url.resourceValues(forKeys: [.contentModificationDateKey])
            sourceFileModificationDate = resourceValues.contentModificationDate

            return true
        } catch {
            return false
        }
    }

    /// Check if the source file has been modified since last import
    ///
    /// This is a convenience method that returns `true` only if the source file exists, is accessible,
    /// and has a newer modification date than when it was last imported.
    ///
    /// - Returns: True if source file exists and has been modified, false otherwise
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Simple check on app launch or periodically
    /// if document.isSourceFileModified() {
    ///     showUpdateAlert {
    ///         try await reimportFromSource(document: document)
    ///     }
    /// }
    /// ```
    ///
    /// ## Return Values
    ///
    /// Returns `true` only when:
    /// - Source file bookmark exists
    /// - Bookmark can be resolved to a URL
    /// - File exists at that URL
    /// - File's current modification date > stored modification date
    ///
    /// Returns `false` for all other cases, including errors.
    ///
    /// - Note: For more detailed status information (e.g., distinguishing between "file not found"
    ///   and "no source file set"), use `sourceFileStatus()` instead.
    ///
    /// - SeeAlso: `sourceFileStatus()`, `setSourceFile(_:)`
    public func isSourceFileModified() -> Bool {
        guard let url = resolveSourceFileURL(),
              let lastModDate = sourceFileModificationDate else {
            return false
        }

        do {
            let resourceValues = try url.resourceValues(forKeys: [.contentModificationDateKey])
            guard let currentModDate = resourceValues.contentModificationDate else {
                return false
            }

            // File is modified if current date is newer than stored date
            return currentModDate > lastModDate
        } catch {
            return false
        }
    }

    /// Get detailed information about the source file status
    ///
    /// This method provides comprehensive status information about the source file, allowing you to
    /// handle different scenarios appropriately (e.g., file moved, permissions issue, or modified).
    ///
    /// - Returns: SourceFileStatus enum value describing the current state
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let status = document.sourceFileStatus()
    ///
    /// switch status {
    /// case .modified:
    ///     // Source file has changed - prompt user to update
    ///     showUpdateAlert {
    ///         try await reimportFromSource(document: document)
    ///     }
    ///
    /// case .upToDate:
    ///     showMessage("Document is up to date")
    ///
    /// case .noSourceFile:
    ///     // Document wasn't imported from a file
    ///     break
    ///
    /// case .fileNotAccessible:
    ///     showError("Cannot access source file - check permissions")
    ///
    /// case .fileNotFound:
    ///     showError("Source file was moved or deleted")
    /// }
    /// ```
    ///
    /// ## Status Values
    ///
    /// - `.noSourceFile`: No source file bookmark set (document wasn't imported from file)
    /// - `.fileNotAccessible`: Bookmark exists but cannot be resolved (permissions issue)
    /// - `.fileNotFound`: File moved or deleted since import
    /// - `.modified`: File exists and has been modified since import
    /// - `.upToDate`: File exists and hasn't changed since import
    ///
    /// ## SwiftUI Integration
    ///
    /// ```swift
    /// struct DocumentStatusBadge: View {
    ///     let document: GuionDocumentModel
    ///
    ///     var body: some View {
    ///         let status = document.sourceFileStatus()
    ///
    ///         if status.shouldPromptForUpdate {
    ///             Label("Update Available", systemImage: "arrow.triangle.2.circlepath")
    ///                 .foregroundStyle(.orange)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - SeeAlso: `SourceFileStatus`, `isSourceFileModified()`, `setSourceFile(_:)`
    public func sourceFileStatus() -> SourceFileStatus {
        guard sourceFileBookmark != nil else {
            return .noSourceFile
        }

        guard let url = resolveSourceFileURL() else {
            return .fileNotAccessible
        }

        // Check if file still exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .fileNotFound
        }

        if isSourceFileModified() {
            return .modified
        }

        return .upToDate
    }

    // MARK: - Conversion Methods

    /// Calculate chapter-aware ordering for an element
    ///
    /// Chapter-based ordering uses a composite key (chapterIndex, orderIndex):
    /// - chapterIndex 0: Elements before first chapter (title page, opening scenes)
    /// - chapterIndex 1: Elements in Chapter 1
    /// - chapterIndex 2: Elements in Chapter 2
    /// - etc.
    ///
    /// Within each chapter, orderIndex starts at 1 and increments sequentially.
    /// Chapters are detected via section heading level 2.
    ///
    /// - Parameters:
    ///   - element: The element to calculate ordering for
    ///   - currentChapter: Current chapter number (0 = before first chapter, 1 = chapter 1, etc.)
    ///   - positionInChapter: Position within the current chapter (starts at 1)
    ///
    /// - Returns: Tuple of (chapterIndex, orderIndex)
    private static func calculateOrderIndex(
        for element: GuionElement,
        currentChapter: inout Int,
        positionInChapter: inout Int
    ) -> (chapterIndex: Int, orderIndex: Int) {
        // Check if this is a chapter heading (section heading level 2)
        if case .sectionHeading(let level) = element.elementType, level == 2 {
            // New chapter found
            currentChapter += 1
            positionInChapter = 1  // Chapter heading gets position 1
            return (chapterIndex: currentChapter, orderIndex: positionInChapter)
        }

        // Regular element - use current chapter and increment position
        positionInChapter += 1
        return (chapterIndex: currentChapter, orderIndex: positionInChapter)
    }

    /// Create a GuionDocumentModel from a GuionParsedElementCollection
    /// - Parameters:
    ///   - screenplay: The screenplay to convert
    ///   - context: The ModelContext to use
    ///   - generateSummaries: Whether to generate AI summaries for scene headings (default: false)
    /// - Returns: The created GuionDocumentModel
    @MainActor
    public static func from(
        _ screenplay: GuionParsedElementCollection,
        in context: ModelContext,
        generateSummaries: Bool = false
    ) async -> GuionDocumentModel {
        return await from(screenplay, in: context, generateSummaries: generateSummaries, progress: nil)
    }

    /// Create a GuionDocumentModel from a GuionParsedElementCollection with progress reporting
    ///
    /// This method provides progress updates as elements are converted to SwiftData models.
    /// If `generateSummaries` is enabled, progress includes AI summary generation.
    ///
    /// - Parameters:
    ///   - screenplay: The screenplay to convert
    ///   - context: The ModelContext to use
    ///   - generateSummaries: Whether to generate AI summaries for scene headings (default: false)
    ///   - progress: Optional progress tracker for monitoring conversion progress
    ///
    /// - Returns: The created GuionDocumentModel
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let progress = OperationProgress(totalUnits: Int64(screenplay.elements.count)) { update in
    ///     print("Converting: \(update.description) - \(Int((update.fractionCompleted ?? 0) * 100))%")
    /// }
    ///
    /// let document = await GuionDocumentModel.from(
    ///     screenplay,
    ///     in: modelContext,
    ///     generateSummaries: true,
    ///     progress: progress
    /// )
    /// ```
    @MainActor
    public static func from(
        _ screenplay: GuionParsedElementCollection,
        in context: ModelContext,
        generateSummaries: Bool = false,
        progress: OperationProgress?
    ) async -> GuionDocumentModel {
        // Calculate total work units
        let titlePageWork = screenplay.titlePage.reduce(0) { $0 + $1.count }
        let totalUnits = Int64(titlePageWork + screenplay.elements.count)
        progress?.setTotalUnitCount(totalUnits)

        var completedUnits: Int64 = 0

        let document = GuionDocumentModel(
            filename: screenplay.filename,
            rawContent: screenplay.stringFromDocument(),
            suppressSceneNumbers: screenplay.suppressSceneNumbers
        )

        // Convert title page entries
        progress?.update(completedUnits: completedUnits, description: "Converting title page...")

        for dictionary in screenplay.titlePage {
            for (key, values) in dictionary {
                let entry = TitlePageEntryModel(key: key, values: values)
                entry.document = document
                document.titlePage.append(entry)

                completedUnits += 1
                if completedUnits % 5 == 0 {
                    progress?.update(completedUnits: completedUnits, description: "Converting title page...")
                }
            }
        }

        // Generate summaries for scene headings if requested
        if generateSummaries {
            progress?.update(completedUnits: completedUnits, description: "Extracting scene structure...")

            let outline = screenplay.extractOutline()
            var elementsWithSummaries: [GuionElement] = []
            var skipIndices = Set<Int>()
            var sceneCount = 0

            for (index, element) in screenplay.elements.enumerated() {
                // Check for cancellation every 10 elements
                if index % 10 == 0 {
                    try? Task.checkCancellation()
                }

                // Skip if already processed (e.g., OVER BLACK that was handled with scene)
                if skipIndices.contains(index) {
                    continue
                }

                // Add the original element
                elementsWithSummaries.append(element)

                completedUnits += 1
                if completedUnits % 10 == 0 {
                    progress?.update(completedUnits: completedUnits, description: "Converting elements (\(index + 1)/\(screenplay.elements.count))...")
                }

                // Check if this is a scene heading that needs a summary
                if element.elementType == .sceneHeading,
                   let sceneId = element.sceneId,
                   let scene = outline.first(where: { $0.sceneId == sceneId }) {

                    sceneCount += 1
                    progress?.update(completedUnits: completedUnits, description: "Generating summary for scene \(sceneCount)...")

                    // Generate summary
                    if let summaryText = await SceneSummarizer.summarizeScene(scene, from: screenplay, outline: outline) {
                        // Check if next element is OVER BLACK
                        if index + 1 < screenplay.elements.count {
                            let nextElement = screenplay.elements[index + 1]
                            if nextElement.elementType == .action &&
                               nextElement.elementText.uppercased().contains("OVER BLACK") {
                                // Add OVER BLACK element before summary
                                elementsWithSummaries.append(nextElement)
                                skipIndices.insert(index + 1)
                            }
                        }

                        // Create summary element as #### SUMMARY: text
                        // Note: Leading space is required because Fountain parser preserves the space after hashtags
                        let summaryElement = GuionElement(
                            elementType: .sectionHeading(level: 4),
                            elementText: " SUMMARY: \(summaryText)"
                        )
                        elementsWithSummaries.append(summaryElement)
                    }
                }
            }

            // Convert all elements including inserted summaries to models with chapter-based ordering
            progress?.update(completedUnits: completedUnits, description: "Creating SwiftData models...")

            var currentChapter = 0
            var positionInChapter = 0

            for (index, element) in elementsWithSummaries.enumerated() {
                if index % 10 == 0 {
                    try? Task.checkCancellation()
                }

                let (chapterIndex, orderIndex) = Self.calculateOrderIndex(
                    for: element,
                    currentChapter: &currentChapter,
                    positionInChapter: &positionInChapter
                )

                let elementModel = GuionElementModel(from: element, chapterIndex: chapterIndex, orderIndex: orderIndex)
                elementModel.document = document
                document.elements.append(elementModel)
            }
        } else {
            // Convert elements without summaries with chapter-based ordering
            progress?.update(completedUnits: completedUnits, description: "Converting elements...")

            var currentChapter = 0
            var positionInChapter = 0

            for (index, element) in screenplay.elements.enumerated() {
                // Check for cancellation every 10 elements
                if index % 10 == 0 {
                    try? Task.checkCancellation()
                }

                let (chapterIndex, orderIndex) = Self.calculateOrderIndex(
                    for: element,
                    currentChapter: &currentChapter,
                    positionInChapter: &positionInChapter
                )

                let elementModel = GuionElementModel(from: element, chapterIndex: chapterIndex, orderIndex: orderIndex)
                elementModel.document = document
                document.elements.append(elementModel)

                completedUnits += 1
                if completedUnits % 10 == 0 {
                    progress?.update(completedUnits: completedUnits, description: "Converting elements (\(index + 1)/\(screenplay.elements.count))...")
                }
            }
        }

        progress?.complete(description: "Conversion complete - \(document.elements.count) elements")
        context.insert(document)
        return document
    }

    /// Convert this GuionDocumentModel to a GuionParsedElementCollection
    /// - Returns: GuionParsedElementCollection instance containing the document data
    public func toGuionParsedElementCollection() -> GuionParsedElementCollection {
        // Convert title page
        var titlePageDict: [String: [String]] = [:]
        for entry in titlePage {
            titlePageDict[entry.key] = entry.values
        }
        let titlePageArray = titlePageDict.isEmpty ? [] : [titlePageDict]

        // Convert elements using protocol-based conversion (MUST use sortedElements!)
        let convertedElements = sortedElements.map { GuionElement(from: $0) }

        return GuionParsedElementCollection(
            filename: filename,
            elements: convertedElements,
            titlePage: titlePageArray,
            suppressSceneNumbers: suppressSceneNumbers
        )
    }

    /// Extract hierarchical scene browser data from SwiftData models
    ///
    /// This method builds the chapter → scene group → scene hierarchy directly
    /// from the `elements` relationship, without converting to GuionParsedElementCollection.
    ///
    /// **Architecture**: Returns structure with references to GuionElementModel instances,
    /// not value copies. UI components read properties directly from models for reactive updates.
    ///
    /// - Returns: SceneBrowserData with model references
    public func extractSceneBrowserData() -> SceneBrowserData {
        // For Phase 1: Convert to screenplay and use existing extraction logic
        // TODO: Phase 2 will implement direct SwiftData traversal for better performance
        let screenplay = toGuionParsedElementCollection()
        let valueBasedData = screenplay.extractSceneBrowserData()

        // Map value-based structure to model-based structure
        return mapToModelBased(valueData: valueBasedData)
    }

    /// Map value-based SceneBrowserData to model-based SceneBrowserData
    private func mapToModelBased(valueData: SceneBrowserData) -> SceneBrowserData {
        // Build lookup dictionary: sceneId -> GuionElementModel (for scene headings)
        var sceneHeadingLookup: [String: GuionElementModel] = [:]
        for element in elements {
            if let sceneId = element.sceneId, element.elementType == .sceneHeading {
                sceneHeadingLookup[sceneId] = element
            }
        }

        // Build lookup for all elements by text+type (for scene content matching)
        // This allows us to find model equivalents of value-based elements
        var elementLookup: [[String: String]: [GuionElementModel]] = [:]
        for element in elements {
            let key = ["text": element.elementText, "type": element.elementType.description]
            if elementLookup[key] == nil {
                elementLookup[key] = []
            }
            elementLookup[key]?.append(element)
        }

        // Map chapters
        let mappedChapters = valueData.chapters.map { chapter in
            // Map scene groups
            let mappedSceneGroups = chapter.sceneGroups.map { sceneGroup in
                // Map scenes
                let mappedScenes = sceneGroup.scenes.map { scene in
                    // Find the scene heading model by sceneId
                    let sceneHeadingModel = scene.sceneId.flatMap { sceneHeadingLookup[$0] }

                    // Find scene content element models
                    var sceneElementModels: [GuionElementModel] = []

                    // Add the scene heading first
                    if let heading = sceneHeadingModel {
                        sceneElementModels.append(heading)
                    }

                    // Add all scene content elements
                    if let valueElements = scene.sceneElements {
                        // Track which models we've already used to avoid duplicates
                        var usedModels = Set<ObjectIdentifier>()
                        if let heading = sceneHeadingModel {
                            usedModels.insert(ObjectIdentifier(heading))
                        }

                        for valueElement in valueElements {
                            let key = ["text": valueElement.elementText, "type": valueElement.elementType.description]
                            if let candidates = elementLookup[key] {
                                // Find first unused match
                                if let match = candidates.first(where: { !usedModels.contains(ObjectIdentifier($0)) }) {
                                    sceneElementModels.append(match)
                                    usedModels.insert(ObjectIdentifier(match))
                                }
                            }
                        }
                    }

                    // Find preScene element models
                    var preSceneElementModels: [GuionElementModel]? = nil
                    if let preSceneValues = scene.preSceneElements {
                        var preSceneModels: [GuionElementModel] = []
                        var usedModels = Set<ObjectIdentifier>()

                        for valueElement in preSceneValues {
                            let key = ["text": valueElement.elementText, "type": valueElement.elementType.description]
                            if let candidates = elementLookup[key] {
                                if let match = candidates.first(where: { !usedModels.contains(ObjectIdentifier($0)) }) {
                                    preSceneModels.append(match)
                                    usedModels.insert(ObjectIdentifier(match))
                                }
                            }
                        }

                        if !preSceneModels.isEmpty {
                            preSceneElementModels = preSceneModels
                        }
                    }

                    return SceneData(
                        sceneHeadingModel: sceneHeadingModel,
                        sceneElementModels: sceneElementModels,
                        preSceneElementModels: preSceneElementModels,
                        sceneLocation: scene.sceneLocation
                    )
                }

                return SceneGroupData(
                    element: sceneGroup.element,
                    scenes: mappedScenes
                )
            }

            return ChapterData(
                element: chapter.element,
                sceneGroups: mappedSceneGroups
            )
        }

        return SceneBrowserData(
            title: valueData.title,
            chapters: mappedChapters
        )
    }
}

// MARK: - Source File Status

/// Status of the source file associated with a GuionDocumentModel
public enum SourceFileStatus: Sendable {
    /// No source file has been set
    case noSourceFile

    /// Source file bookmark exists but cannot be resolved (permissions issue)
    case fileNotAccessible

    /// Source file has been moved or deleted
    case fileNotFound

    /// Source file exists and has been modified since last import
    case modified

    /// Source file exists and is up to date
    case upToDate

    /// Human-readable description
    public var description: String {
        switch self {
        case .noSourceFile:
            return "No source file"
        case .fileNotAccessible:
            return "Cannot access source file"
        case .fileNotFound:
            return "Source file not found"
        case .modified:
            return "Source file has been modified"
        case .upToDate:
            return "Up to date"
        }
    }

    /// Whether the user should be prompted to update
    public var shouldPromptForUpdate: Bool {
        return self == .modified
    }
}

#endif
