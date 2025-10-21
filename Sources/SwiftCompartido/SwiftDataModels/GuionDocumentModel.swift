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

    @Relationship(deleteRule: .cascade, inverse: \TitlePageEntryModel.document)
    public var titlePage: [TitlePageEntryModel]

    // MARK: - Source File Tracking (NEW in 1.4.3)

    /// Security-scoped bookmark to the original source file
    ///
    /// This bookmark maintains access to the file across app launches, even in sandboxed applications.
    /// Created by calling `setSourceFile(_:)` when importing a screenplay.
    ///
    /// - Note: For sandboxed macOS apps, the user must select the file via an open panel to create
    ///   a valid security-scoped bookmark.
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
        for element in elements where element.elementType == .sceneHeading {
            element.reparseLocation()
        }
    }

    /// Get all scene elements with their cached locations
    public var sceneLocations: [(element: GuionElementModel, location: SceneLocation)] {
        return elements.compactMap { element in
            guard let location = element.cachedSceneLocation else { return nil }
            return (element, location)
        }
    }

    // MARK: - Source File Tracking Methods (NEW in 1.4.3)

    /// Resolve the source file bookmark to a URL
    ///
    /// This method converts the stored security-scoped bookmark into a URL that can be used to
    /// access the original source file. The bookmark is automatically refreshed if it becomes stale.
    ///
    /// - Returns: URL if bookmark can be resolved and file is accessible, nil otherwise
    ///
    /// ## Usage
    ///
    /// ```swift
    /// if let sourceURL = document.resolveSourceFileURL() {
    ///     // Start security-scoped access
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
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Bookmark is stale, try to recreate it
                if let newBookmark = try? url.bookmarkData(
                    options: .withSecurityScope,
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

    /// Set the source file from a URL, creating a security-scoped bookmark
    ///
    /// This method creates a security-scoped bookmark to the source file and records the current
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
    ///     print("Failed to create security-scoped bookmark")
    /// }
    /// ```
    ///
    /// ## Properties Updated
    ///
    /// This method automatically updates:
    /// - `sourceFileBookmark` - Security-scoped bookmark data
    /// - `lastImportDate` - Set to current date/time
    /// - `sourceFileModificationDate` - Set to file's modification date
    ///
    /// - Note: For sandboxed macOS apps, the URL must come from a user file selection
    ///   (NSOpenPanel) to create a valid security-scoped bookmark.
    ///
    /// - SeeAlso: `resolveSourceFileURL()`, `isSourceFileModified()`, `sourceFileStatus()`
    @discardableResult
    public func setSourceFile(_ url: URL) -> Bool {
        do {
            // Create security-scoped bookmark
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
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

            // Convert all elements including inserted summaries to models
            progress?.update(completedUnits: completedUnits, description: "Creating SwiftData models...")

            for (index, element) in elementsWithSummaries.enumerated() {
                if index % 10 == 0 {
                    try? Task.checkCancellation()
                }

                let elementModel = GuionElementModel(from: element)
                elementModel.document = document
                document.elements.append(elementModel)
            }
        } else {
            // Convert elements without summaries
            progress?.update(completedUnits: completedUnits, description: "Converting elements...")

            for (index, element) in screenplay.elements.enumerated() {
                // Check for cancellation every 10 elements
                if index % 10 == 0 {
                    try? Task.checkCancellation()
                }

                let elementModel = GuionElementModel(from: element)
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

        // Convert elements using protocol-based conversion
        let convertedElements = elements.map { GuionElement(from: $0) }

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

/// SwiftData model representing a single screenplay element.
///
/// This persistent model stores screenplay elements with automatic scene location
/// caching for improved performance.
///
/// ## Overview
///
/// `GuionElementModel` extends ``GuionElementProtocol`` with SwiftData persistence
/// and intelligent location caching. When a scene heading is created or modified,
/// the location is automatically parsed and cached for quick access.
///
/// ## Example
///
/// ```swift
/// let element = GuionElementModel(
///     elementText: "INT. COFFEE SHOP - DAY",
///     elementType: "Scene Heading"
/// )
///
/// // Location is automatically parsed and cached
/// if let location = element.cachedSceneLocation {
///     print(location.scene) // "COFFEE SHOP"
///     print(location.lighting) // .interior
/// }
/// ```
///
/// ## Topics
///
/// ### Creating Elements
/// - ``init(elementText:elementType:isCentered:isDualDialogue:sceneNumber:sectionDepth:summary:sceneId:)``
/// - ``init(from:summary:)``
///
/// ### Element Properties
/// - ``elementText``
/// - ``elementType``
/// - ``isCentered``
/// - ``isDualDialogue``
/// - ``sceneNumber``
/// - ``sectionDepth``
/// - ``sceneId``
/// - ``summary``
///
/// ### Location Caching
/// - ``cachedSceneLocation``
/// - ``reparseLocation()``
///
/// ### Updating Elements
/// - ``updateText(_:)``
/// - ``updateType(_:)``
@Model
public final class GuionElementModel: GuionElementProtocol {
    public var elementText: String

    /// Internal storage for element type as string (required for SwiftData)
    private var _elementTypeString: String

    /// The type of screenplay element
    public var elementType: ElementType {
        get {
            // Convert from stored string to enum
            var type = ElementType(string: _elementTypeString)
            // If section heading, use stored depth
            if case .sectionHeading = type {
                type = .sectionHeading(level: _sectionDepth)
            }
            return type
        }
        set {
            // Track previous type for location handling
            let wasSceneHeading = elementType == .sceneHeading
            let isSceneHeading = newValue == .sceneHeading

            // Store enum as string
            _elementTypeString = newValue.description
            // Update section depth if applicable
            if case .sectionHeading(let level) = newValue {
                _sectionDepth = level
            }

            // Update location data if scene heading status changed
            if isSceneHeading && !wasSceneHeading {
                // Became a scene heading - parse location
                parseAndStoreLocation()
            } else if !isSceneHeading && wasSceneHeading {
                // Was a scene heading, no longer is - clear location
                parseAndStoreLocation()
            }
        }
    }

    public var isCentered: Bool
    public var isDualDialogue: Bool
    public var sceneNumber: String?

    /// Internal storage for section depth (required for SwiftData persistence)
    private var _sectionDepth: Int

    /// The depth level for section headings (deprecated, use elementType.level instead)
    @available(*, deprecated, message: "Use elementType.level instead")
    public var sectionDepth: Int {
        get { elementType.level }
        set {
            if case .sectionHeading = elementType {
                _sectionDepth = newValue
                // Need to update the element type to reflect new level
                elementType = .sectionHeading(level: newValue)
            }
        }
    }

    public var sceneId: String?

    // SwiftData-specific properties
    public var summary: String?
    public var document: GuionDocumentModel?

    // Cached parsed location data
    public var locationLighting: String?      // Raw value of SceneLighting enum
    public var locationScene: String?         // Primary location name
    public var locationSetup: String?         // Optional sub-location
    public var locationTimeOfDay: String?     // Time of day
    public var locationModifiers: [String]?   // Additional modifiers

    public init(elementText: String, elementType: ElementType, isCentered: Bool = false, isDualDialogue: Bool = false, sceneNumber: String? = nil, sectionDepth: Int = 0, summary: String? = nil, sceneId: String? = nil) {
        self.elementText = elementText
        self._elementTypeString = elementType.description
        self.isCentered = isCentered
        self.isDualDialogue = isDualDialogue
        self.sceneNumber = sceneNumber
        // Set section depth from enum if provided
        self._sectionDepth = elementType.level > 0 ? elementType.level : sectionDepth
        self.summary = summary
        self.sceneId = sceneId

        // Parse location if this is a scene heading
        if elementType == .sceneHeading {
            self.parseAndStoreLocation()
        }
    }

    /// Initialize from any GuionElementProtocol conforming type
    public convenience init<T: GuionElementProtocol>(from element: T, summary: String? = nil) {
        self.init(
            elementText: element.elementText,
            elementType: element.elementType,
            isCentered: element.isCentered,
            isDualDialogue: element.isDualDialogue,
            sceneNumber: element.sceneNumber,
            sectionDepth: element.elementType.level,
            summary: summary,
            sceneId: element.sceneId
        )
    }

    /// Parse and store location data from elementText
    private func parseAndStoreLocation() {
        guard elementType == .sceneHeading else {
            // Clear location data if not a scene heading
            locationLighting = nil
            locationScene = nil
            locationSetup = nil
            locationTimeOfDay = nil
            locationModifiers = nil
            return
        }

        let location = SceneLocation.parse(elementText)

        // Store parsed components
        locationLighting = location.lighting.rawValue
        locationScene = location.scene
        locationSetup = location.setup
        locationTimeOfDay = location.timeOfDay
        locationModifiers = location.modifiers.isEmpty ? nil : location.modifiers
    }

    /// Get the cached scene location (reconstructed from stored properties)
    /// Returns nil if this is not a scene heading or location hasn't been parsed
    public var cachedSceneLocation: SceneLocation? {
        guard elementType == .sceneHeading,
              let lightingRaw = locationLighting,
              let scene = locationScene else {
            return nil
        }

        let lighting = SceneLighting(rawValue: lightingRaw) ?? .unknown

        return SceneLocation(
            lighting: lighting,
            scene: scene,
            setup: locationSetup,
            timeOfDay: locationTimeOfDay,
            modifiers: locationModifiers ?? [],
            originalText: elementText
        )
    }

    /// Force reparse the location (useful for migration or manual updates)
    public func reparseLocation() {
        parseAndStoreLocation()
    }

    /// Update element text and automatically reparse location if needed
    public func updateText(_ newText: String) {
        guard newText != elementText else { return }
        elementText = newText
        if elementType == .sceneHeading {
            parseAndStoreLocation()
        }
    }

    /// Update element type and automatically reparse location if needed
    public func updateType(_ newType: ElementType) {
        guard newType != elementType else { return }
        let wasSceneHeading = elementType == .sceneHeading
        let isSceneHeading = newType == .sceneHeading

        elementType = newType

        if isSceneHeading && !wasSceneHeading {
            // Became a scene heading - parse location
            parseAndStoreLocation()
        } else if !isSceneHeading && wasSceneHeading {
            // Was a scene heading, no longer is - clear location
            parseAndStoreLocation()
        }
    }
}

@Model
public final class TitlePageEntryModel {
    public var key: String
    public var values: [String]

    public var document: GuionDocumentModel?

    public init(key: String, values: [String]) {
        self.key = key
        self.values = values
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
