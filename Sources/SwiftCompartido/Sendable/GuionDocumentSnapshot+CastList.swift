//
//  GuionDocumentSnapshot+CastList.swift
//  SwiftCompartido
//
//  Apple Intelligence-powered cast list generation from screenplay content
//

import Foundation

#if canImport(FoundationModels)
  import FoundationModels
#endif

// MARK: - Cast List Generation with Apple Intelligence

extension GuionDocumentSnapshot {

  /// Generate a cast list using Apple Intelligence by analyzing screenplay content.
  ///
  /// This method uses Foundation Models to intelligently analyze the screenplay and generate
  /// a cast list with character names extracted from dialogue and character elements.
  ///
  /// ## Overview
  ///
  /// The AI analyzes:
  /// - Character names from `.character` elements
  /// - Speaking roles from `.dialogue` elements
  /// - Character importance based on dialogue frequency
  /// - Character relationships and descriptions from action lines
  ///
  /// ## Availability
  ///
  /// Requires:
  /// - iOS 26.2+ or macOS 26.0+
  /// - Apple Intelligence enabled in System Settings
  /// - M1+ Mac or A17 Pro+ device
  ///
  /// ## Fallback Behavior
  ///
  /// If Apple Intelligence is unavailable, this method returns `nil` and reports
  /// the unavailability via the progress callback. You can fall back to extracting
  /// character names directly from elements using ``characters``.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Generate cast list in background
  /// Task.detached {
  ///     do {
  ///         let progress = OperationProgress(totalUnits: 100) { update in
  ///             print("Progress (\(update.completedUnits)/\(update.totalUnits ?? 100)): \(update.description)")
  ///         }
  ///
  ///         if let castList = try await snapshot.generateCastList(progress: progress) {
  ///             // Add cast list to custom pages
  ///             snapshot.customPages = [castList]
  ///         }
  ///     } catch {
  ///         print("Cast list generation failed: \(error)")
  ///     }
  /// }
  /// ```
  ///
  /// - Parameter progress: Optional progress tracker for reporting updates
  /// - Returns: A `CastListPage` with AI-generated character list, or `nil` if unavailable
  /// - Throws: Error if AI generation fails (excluding unavailability)
  @available(iOS 26.2, macOS 26.0, *)
  public func generateCastList(
    progress: OperationProgress? = nil
  ) async throws -> CastListPage? {
    #if canImport(FoundationModels)

      progress?.update(
        completedUnits: 10,
        description: "Checking Apple Intelligence availability...",
        force: true
      )

      // Check if the system language model is available
      let model = SystemLanguageModel.default
      guard model.isAvailable else {
        progress?.update(
          completedUnits: 100,
          description: "Apple Intelligence unavailable",
          additionalInfo: "⚠️ Apple Intelligence is not available. Cast list generation requires:\n"
            + "1) Apple Intelligence enabled in System Settings\n"
            + "2) M1+ Mac or A17 Pro+ device\n" + "3) iOS 26.2+ or macOS 26.0+",
          force: true
        )
        return nil
      }

      progress?.update(
        completedUnits: 20,
        description: "Analyzing screenplay structure...",
        force: true
      )

      // Build the system prompt that teaches the model how to analyze screenplays
      let systemPrompt = buildCastListGenerationPrompt()

      // Build screenplay context from elements
      let screenplayText = buildScreenplayContext()

      // Build the user prompt
      let userPrompt = """
        Analyze the following screenplay and generate a comprehensive cast list.

        Extract all character names from the screenplay, including:
        - Main characters (those with significant dialogue)
        - Supporting characters (those with some dialogue)
        - Minor characters (those with minimal dialogue)

        For each character, provide:
        - Character name (as it appears in the screenplay, usually UPPERCASE)
        - Brief role description (1-2 sentences about who they are and their role in the story)

        CRITICAL: Your output MUST be valid JSON in this exact format:
        {
          "characters": [
            {
              "name": "CHARACTER NAME",
              "description": "Brief role description"
            }
          ]
        }

        Do NOT include any explanations, markdown formatting, or additional text.
        Output ONLY the JSON object, starting with the opening brace.

        SCREENPLAY TEXT:
        \(screenplayText)

        OUTPUT (JSON only):
        """

      progress?.update(
        completedUnits: 30,
        description: "Creating Apple Intelligence session...",
        force: true
      )

      // Create a language model session with the system prompt
      let session = LanguageModelSession(
        model: model,
        instructions: systemPrompt
      )

      progress?.update(
        completedUnits: 40,
        description: "Generating cast list with AI...",
        force: true
      )

      // Generate the cast list using the AI model
      let response = try await session.respond(to: Prompt(userPrompt))

      progress?.update(
        completedUnits: 80,
        description: "AI generation complete, parsing results...",
        force: true
      )

      // Parse the JSON response
      let castList = try parseCastListResponse(response.content)

      progress?.update(
        completedUnits: 100,
        description: "Cast list generated successfully",
        force: true
      )

      return castList

    #else
      // Foundation Models not available on this platform
      progress?.update(
        completedUnits: 100,
        description: "Apple Intelligence not available on this platform",
        additionalInfo:
          "ℹ️ Foundation Models framework is not available. Cast list generation requires iOS 26.2+ or macOS 26.0+",
        force: true
      )
      return nil
    #endif
  }

  // MARK: - Private Helpers

  /// Build the system prompt that teaches the AI how to analyze screenplays for cast lists
  private func buildCastListGenerationPrompt() -> String {
    """
    You are an expert screenplay analyst specializing in character identification and cast list generation.

    Your task is to analyze screenplay text and extract all characters, identifying:
    - Character names (as they appear in the screenplay)
    - Character roles and importance in the story
    - Brief descriptions of each character's function in the narrative

    ## Screenplay Format Rules

    ### Character Identification

    1. **Character Names**: Always appear in UPPERCASE before dialogue
       - Example: "JANE" or "JOHN DOE" or "DETECTIVE SMITH"

    2. **Character Elements**:
       - Character names precede dialogue blocks
       - May include parentheticals with character state: "JANE (V.O.)" or "JOHN (CONT'D)"
       - Strip parentheticals when extracting names

    3. **Dialogue Elements**:
       - Text spoken by characters
       - Always preceded by a character name
       - Count frequency to determine character importance

    4. **Character Descriptions**:
       - Look for action lines that introduce characters
       - Extract age, role, personality traits when mentioned
       - Example: "JANE (30s), a sharp-witted detective, enters."

    ### Analysis Strategy

    1. **Primary Characters**:
       - Appear in 5+ dialogue blocks
       - Central to the story
       - Provide detailed descriptions

    2. **Supporting Characters**:
       - Appear in 2-4 dialogue blocks
       - Important but not central
       - Provide brief descriptions

    3. **Minor Characters**:
       - Appear in 1 dialogue block
       - Brief mentions acceptable

    ### Output Format

    Generate JSON with this structure:
    {
      "characters": [
        {
          "name": "CHARACTER NAME",
          "description": "1-2 sentence role description"
        }
      ]
    }

    - Sort by importance (dialogue frequency)
    - Remove duplicates (case-insensitive matching)
    - Strip parentheticals from names: "JANE (V.O.)" → "JANE"
    - Keep character names in UPPERCASE as they appear
    - Provide concise, informative descriptions

    Remember: Output ONLY valid JSON. No explanations, no markdown, no additional text.
    """
  }

  /// Build screenplay context from elements for AI analysis
  private func buildScreenplayContext() -> String {
    var context = ""

    // Include title if available
    if let title = title {
      context += "Title: \(title)\n\n"
    }

    // Build screenplay text from elements
    // Include scene headings, characters, dialogue, and action lines
    for element in elements {
      switch element.elementType {
      case .sceneHeading:
        context += "\n\(element.elementText)\n\n"
      case .character:
        context += "\(element.elementText)\n"
      case .dialogue:
        context += "\(element.elementText)\n"
      case .action:
        context += "\(element.elementText)\n\n"
      case .parenthetical:
        context += "(\(element.elementText))\n"
      case .transition:
        context += "\n\(element.elementText)\n\n"
      default:
        // Skip other element types for brevity
        break
      }
    }

    return context
  }

  /// Parse AI response JSON into a CastListPage
  private func parseCastListResponse(_ jsonString: String) throws -> CastListPage {
    // Clean up response (remove markdown code blocks if present)
    var cleanJSON = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
    if cleanJSON.hasPrefix("```json") {
      cleanJSON = cleanJSON.replacingOccurrences(of: "```json", with: "")
      cleanJSON = cleanJSON.replacingOccurrences(of: "```", with: "")
      cleanJSON = cleanJSON.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Parse JSON
    guard let data = cleanJSON.data(using: .utf8) else {
      throw CastListGenerationError.invalidJSONResponse
    }

    struct AIResponse: Codable {
      struct Character: Codable {
        let name: String
        let description: String
      }
      let characters: [Character]
    }

    let decoder = JSONDecoder()
    let response = try decoder.decode(AIResponse.self, from: data)

    // Convert to CastListPage
    let castMembers = response.characters.enumerated().map { (index, character) in
      CastListPage.CastMember(
        role: character.name,
        name: character.description,
        position: index
      )
    }

    return CastListPage(
      title: "Cast List",
      position: 0,
      printDots: true,
      items: castMembers
    )
  }
}

// MARK: - Error Types

/// Errors that can occur during cast list generation
public enum CastListGenerationError: LocalizedError {
  /// Apple Intelligence returned invalid JSON
  case invalidJSONResponse

  /// Apple Intelligence is not available
  case appleIntelligenceUnavailable

  /// AI generation failed
  case generationFailed(Error)

  public var errorDescription: String? {
    switch self {
    case .invalidJSONResponse:
      return "Failed to parse cast list from AI response. The AI did not return valid JSON."
    case .appleIntelligenceUnavailable:
      return
        "Apple Intelligence is not available on this device. Cast list generation requires iOS 26.2+ or macOS 26.0+ with Apple Intelligence enabled."
    case .generationFailed(let error):
      return "Cast list generation failed: \(error.localizedDescription)"
    }
  }
}
