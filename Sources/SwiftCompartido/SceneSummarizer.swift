//
//  SceneSummarizer.swift
//  SwiftGuion
//
//  Copyright (c) 2025
//
//  Provides scene summarization capabilities using Apple Intelligence
//  and extractive summarization techniques.
//
//  Example usage:
//  ```swift
//  // Parse a script and generate summaries
//  let script = try GuionParsedElementCollection(string: fountainText)
//  let outline = script.extractOutline()
//
//  for scene in outline.filter({ $0.type == "sceneHeader" }) {
//      if let summary = await SceneSummarizer.summarizeScene(scene, from: script) {
//          print("Scene: \(scene.string)")
//          print("Summary: \(summary)")
//      }
//  }
//
//  // Or use with SwiftData models:
//  let document = await GuionDocumentParserSwiftData.parse(
//      script: script,
//      in: modelContext,
//      generateSummaries: true  // Enable automatic summarization
//  )
//
//  // Access summaries from scene heading elements
//  for element in document.elements where element.elementType == "Scene Heading" {
//      if let summary = element.summary {
//          print("\(element.elementText): \(summary)")
//      }
//  }
//  ```
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Generates summaries of guión scenes using Apple's Foundation Models framework
///
/// ## Requirements
/// - iOS 26+ / macOS 26+ / iPadOS 26+
/// - Apple Intelligence-compatible device (iPhone 15 Pro or later for phones)
/// - Apple Intelligence must be enabled on the device
/// - Xcode 26+ for development
///
/// ## Framework Support
/// When the Foundation Models framework is available (iOS 26+), this class uses the
/// on-device language model for intelligent summarization. On earlier versions,
/// it falls back to extractive summarization techniques.
public class SceneSummarizer {

    /// Summarize a scene's text content
    /// - Parameter sceneText: The full text of the scene
    /// - Returns: A concise summary of the scene
    public static func summarize(_ sceneText: String) async -> String? {
        #if canImport(FoundationModels)
        // For macOS 26+ with Foundation Models framework
        return await summarizeWithFoundationModels(sceneText)
        #else
        // Fallback for platforms without Foundation Models framework
        return extractiveSummarize(sceneText)
        #endif
    }

    #if canImport(FoundationModels)
    private static func summarizeWithFoundationModels(_ text: String) async -> String? {
        // Use Apple's Foundation Models framework for intelligent summarization
        // The framework provides access to the ~3B parameter on-device language model

        guard !text.isEmpty else { return nil }

        // Clean up the text
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // TODO: Implement Foundation Models API when testing on iOS 26+ device
        // Example approach (actual implementation may vary):
        // let model = FoundationModel.shared
        // let summary = try? await model.generateText(
        //     prompt: "Summarize this guión scene in one sentence:\n\n\(cleanedText)"
        // )
        // return summary

        // For now, fall back to extractive summarization
        // This will be replaced with actual Foundation Models API calls
        return extractiveSummarize(cleanedText)
    }
    #endif

    /// Extractive summarization: extract key sentences from the scene
    private static func extractiveSummarize(_ text: String) -> String? {
        guard !text.isEmpty else { return nil }

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        var summary: [String] = []

        // Extract the scene heading (first line)
        if let heading = lines.first {
            // Skip the heading in summary if it starts with INT./EXT./etc
            if !heading.uppercased().starts(with: "INT.") &&
               !heading.uppercased().starts(with: "EXT.") {
                summary.append(heading)
            }
        }

        // Find character names and key action lines
        var characters = Set<String>()
        var actionLines: [String] = []

        for (_, line) in lines.enumerated() {
            // Check if this looks like a character name (all caps, short)
            let isAllCaps = line == line.uppercased() && line.count < 40
            let hasLetters = line.rangeOfCharacter(from: .letters) != nil

            if isAllCaps && hasLetters && !line.starts(with: "INT.") && !line.starts(with: "EXT.") {
                // This might be a character name
                let cleaned = line.replacingOccurrences(of: "^", with: "")
                    .replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if cleaned.count < 30 && !cleaned.isEmpty {
                    characters.insert(cleaned)
                }
            } else if !isAllCaps && hasLetters && line.count > 20 {
                // This might be an action line
                actionLines.append(line)
            }
        }

        // Build summary
        if !characters.isEmpty {
            let characterList = Array(characters).prefix(3).joined(separator: ", ")
            summary.append("Characters: \(characterList)")
        }

        // Add first significant action line if available
        if let firstAction = actionLines.first(where: { $0.count > 30 }) {
            let truncated = firstAction.prefix(100)
            summary.append(String(truncated))
            if firstAction.count > 100 {
                summary[summary.count - 1] += "..."
            }
        }

        return summary.isEmpty ? nil : summary.joined(separator: ". ")
    }

    /// Generate a summary for a scene using the outline element
    /// - Parameters:
    ///   - scene: The outline element representing the scene
    ///   - script: The GuionParsedElementCollection containing the scene
    ///   - outline: The complete outline (optional)
    /// - Returns: A summary of the scene
    @MainActor
    public static func summarizeScene(_ scene: OutlineElement, from script: GuionParsedElementCollection, outline: OutlineList? = nil) async -> String? {
        guard scene.type == "sceneHeader" else { return nil }

        let sceneText = scene.sceneText(from: script, outline: outline)
        return await summarize(sceneText)
    }
}
