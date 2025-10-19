//
//  FDXParser.swift
//  SwiftGuion
//

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public struct FDXParsedElement: GuionElementProtocol, Sendable {
    public var elementText: String
    public var elementType: ElementType
    public var isCentered: Bool
    public var isDualDialogue: Bool
    public var sceneNumber: String?
    public var sceneId: String?
    public var summary: String?

    /// The depth level for section headings (deprecated, use elementType.level instead)
    @available(*, deprecated, message: "Use elementType.level instead")
    public var sectionDepth: Int {
        get { elementType.level }
        set {
            if case .sectionHeading = elementType {
                elementType = .sectionHeading(level: newValue)
            }
        }
    }

    public init(elementText: String, elementType: ElementType, isCentered: Bool, isDualDialogue: Bool, sceneNumber: String?, sectionDepth: Int, sceneId: String? = nil, summary: String? = nil) {
        self.elementText = elementText
        // Handle section depth in the element type
        if case .sectionHeading = elementType {
            self.elementType = .sectionHeading(level: sectionDepth)
        } else {
            self.elementType = elementType
        }
        self.isCentered = isCentered
        self.isDualDialogue = isDualDialogue
        self.sceneNumber = sceneNumber
        self.sceneId = sceneId
        self.summary = summary
    }
}

public struct FDXParsedTitlePageEntry: Sendable {
    public let key: String
    public let values: [String]

    public init(key: String, values: [String]) {
        self.key = key
        self.values = values
    }
}

public struct FDXParsedDocument: Sendable {
    public let filename: String?
    public let rawXML: String
    public let suppressSceneNumbers: Bool
    public let elements: [FDXParsedElement]
    public let titlePageEntries: [FDXParsedTitlePageEntry]

    public init(filename: String?, rawXML: String, suppressSceneNumbers: Bool, elements: [FDXParsedElement], titlePageEntries: [FDXParsedTitlePageEntry]) {
        self.filename = filename
        self.rawXML = rawXML
        self.suppressSceneNumbers = suppressSceneNumbers
        self.elements = elements
        self.titlePageEntries = titlePageEntries
    }
}

public enum FDXParserError: Error {
    case unableToParse
}

#if canImport(FoundationXML) || os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || targetEnvironment(macCatalyst)
/// Parses Final Draft FDX format files into GuionElements
public final class FDXParser: NSObject, @unchecked Sendable {
    private enum Section {
        case none
        case scriptContent
        case titlePage
    }

    private var section: Section = .none
    private var elementStack: [String] = []

    private var isProcessingScriptParagraph = false
    private var isProcessingTitlePageParagraph = false
    private var currentParagraphType: String?
    private var currentParagraphText = ""
    private var currentTitleParagraphText = ""
    private var currentSceneNumber: String?
    private var currentSectionDepth = 0
    private var currentIsCentered = false
    private var currentIsDualDialogue = false
    private var textBuffer = ""
    private var capturingText = false

    private var elements: [FDXParsedElement] = []
    private var titlePageLines: [String] = []

    private var parsedFilename: String?
    private var rawXML: String = ""

    // Progress tracking
    private var progress: OperationProgress?
    private var elementCount: Int = 0
    private var lastProgressUpdate: Int = 0

    public func parse(data: Data, filename: String?) throws -> FDXParsedDocument {
        reset()

        parsedFilename = filename
        rawXML = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw FDXParserError.unableToParse
        }

        let titleEntries: [FDXParsedTitlePageEntry]
        if titlePageLines.isEmpty {
            titleEntries = []
        } else {
            titleEntries = [FDXParsedTitlePageEntry(key: "Title Page", values: titlePageLines)]
        }

        return FDXParsedDocument(
            filename: parsedFilename,
            rawXML: rawXML,
            suppressSceneNumbers: false,
            elements: elements,
            titlePageEntries: titleEntries
        )
    }

    /// Async version of parse with progress reporting support.
    ///
    /// This method parses an FDX file with progress updates and cancellation support.
    /// Progress is reported as XML elements are parsed and converted.
    ///
    /// - Parameters:
    ///   - data: The FDX XML data to parse
    ///   - filename: Optional filename for the document
    ///   - progress: Optional progress tracker for monitoring parse progress
    ///
    /// - Throws: `FDXParserError.unableToParse` if parsing fails, or `CancellationError` if cancelled
    ///
    /// - Returns: The parsed FDX document
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let progress = OperationProgress(totalUnits: nil) { update in
    ///     print("Parsing FDX: \(Int((update.fractionCompleted ?? 0) * 100))%")
    /// }
    ///
    /// let document = try await parser.parse(data: fdxData, filename: "script.fdx", progress: progress)
    /// ```
    public func parse(data: Data, filename: String?, progress: OperationProgress?) async throws -> FDXParsedDocument {
        reset()

        self.progress = progress
        parsedFilename = filename
        rawXML = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)

        // Check for cancellation before starting
        try Task.checkCancellation()

        progress?.update(completedUnits: 0, description: "Parsing FDX XML...")

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw FDXParserError.unableToParse
        }

        // Final progress update
        progress?.complete(description: "Parsing complete - \(elements.count) elements")

        let titleEntries: [FDXParsedTitlePageEntry]
        if titlePageLines.isEmpty {
            titleEntries = []
        } else {
            titleEntries = [FDXParsedTitlePageEntry(key: "Title Page", values: titlePageLines)]
        }

        return FDXParsedDocument(
            filename: parsedFilename,
            rawXML: rawXML,
            suppressSceneNumbers: false,
            elements: elements,
            titlePageEntries: titleEntries
        )
    }

    private func reset() {
        section = .none
        elementStack = []
        isProcessingScriptParagraph = false
        isProcessingTitlePageParagraph = false
        currentParagraphType = nil
        currentParagraphText = ""
        currentTitleParagraphText = ""
        currentSceneNumber = nil
        currentSectionDepth = 0
        currentIsCentered = false
        currentIsDualDialogue = false
        textBuffer = ""
        capturingText = false
        elements = []
        titlePageLines = []
        parsedFilename = nil
        rawXML = ""
        progress = nil
        elementCount = 0
        lastProgressUpdate = 0
    }

    private func normalizedElementType(_ type: String) -> ElementType {
        switch type {
        case "New Act":
            return .sectionHeading(level: currentSectionDepth)
        case "Scene Heading":
            return .sceneHeading
        case "Action":
            return .action
        case "Character":
            return .character
        case "Dialogue":
            return .dialogue
        case "Parenthetical":
            return .parenthetical
        case "Transition":
            return .transition
        case "Synopsis":
            return .synopsis
        case "Comment":
            return .comment
        case "Boneyard":
            return .boneyard
        case "Lyrics":
            return .lyrics
        case "Page Break":
            return .pageBreak
        case "Section Heading":
            return .sectionHeading(level: currentSectionDepth)
        case "Centered":
            return .action // Centered is a formatting flag, not a type
        default:
            return .action // Default to action for unknown types
        }
    }
}

extension FDXParser: XMLParserDelegate {
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        elementStack.append(elementName)

        switch elementName {
        case "Content":
            if elementStack.count >= 2 && elementStack[elementStack.count - 2] == "FinalDraft" {
                section = .scriptContent
            } else if elementStack.contains("TitlePage") {
                section = .titlePage
            }
        case "Paragraph":
            let parent = elementStack.dropLast().last
            if section == .scriptContent && parent == "Content" {
                isProcessingScriptParagraph = true
                currentParagraphType = attributeDict["Type"] ?? "Action"
                currentParagraphText = ""
                currentSceneNumber = nil
                currentSectionDepth = Int(attributeDict["Level"] ?? "0") ?? 0
                currentIsCentered = (attributeDict["Type"] == "Centered")
                currentIsDualDialogue = (attributeDict["DualDialogue"]?.lowercased() == "yes")
            } else if section == .titlePage && parent == "Content" {
                isProcessingTitlePageParagraph = true
                currentTitleParagraphText = ""
            }
        case "SceneProperties" where isProcessingScriptParagraph:
            currentSceneNumber = attributeDict["Number"]
        case "Text":
            if isProcessingScriptParagraph || isProcessingTitlePageParagraph {
                textBuffer = ""
                capturingText = true
            }
        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard capturingText else { return }
        textBuffer.append(string)
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "Text":
            if capturingText {
                if isProcessingScriptParagraph {
                    currentParagraphText.append(textBuffer)
                } else if isProcessingTitlePageParagraph {
                    currentTitleParagraphText.append(textBuffer)
                }
            }
            textBuffer = ""
            capturingText = false
        case "Paragraph":
            let parent = elementStack.dropLast().last
            if isProcessingScriptParagraph && parent == "Content" {
                let trimmedText = currentParagraphText.replacingOccurrences(of: "\r", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                let elementType = normalizedElementType(currentParagraphType ?? "Action")
                if !trimmedText.isEmpty || elementType == .pageBreak {
                    let isCentered = currentIsCentered

                    // Generate UUID for Scene Heading elements
                    var sceneId: String? = nil
                    if elementType == .sceneHeading {
                        sceneId = UUID().uuidString
                    }

                    let parsedElement = FDXParsedElement(
                        elementText: trimmedText,
                        elementType: elementType,
                        isCentered: isCentered,
                        isDualDialogue: currentIsDualDialogue,
                        sceneNumber: currentSceneNumber,
                        sectionDepth: currentSectionDepth,
                        sceneId: sceneId
                    )
                    elements.append(parsedElement)

                    // Report progress every 10 elements
                    elementCount += 1
                    if elementCount - lastProgressUpdate >= 10 {
                        progress?.update(
                            completedUnits: Int64(elementCount),
                            description: "Parsing FDX... (\(elementCount) elements)"
                        )
                        lastProgressUpdate = elementCount

                        // Check for cancellation
                        if Task.isCancelled {
                            parser.abortParsing()
                        }
                    }
                }
                isProcessingScriptParagraph = false
                currentParagraphType = nil
                currentParagraphText = ""
                currentSceneNumber = nil
                currentSectionDepth = 0
                currentIsCentered = false
                currentIsDualDialogue = false
            } else if isProcessingTitlePageParagraph && parent == "Content" {
                let trimmed = currentTitleParagraphText.replacingOccurrences(of: "\r", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    titlePageLines.append(trimmed)
                }
                isProcessingTitlePageParagraph = false
                currentTitleParagraphText = ""
            }
        case "Content":
            section = .none
        default:
            break
        }

        if !elementStack.isEmpty {
            elementStack.removeLast()
        }
    }
}
#else
public final class FDXParser {
    public func parse(data: Data, filename: String?) throws -> FDXParsedDocument {
        throw FDXParserError.unableToParse
    }
}
#endif
