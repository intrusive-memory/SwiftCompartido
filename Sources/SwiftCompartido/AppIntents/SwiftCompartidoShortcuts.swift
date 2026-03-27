//
//  SwiftCompartidoShortcuts.swift
//  SwiftCompartido
//
//  App Shortcuts provider for Siri integration.
//

import AppIntents

/// App Shortcuts provider for SwiftCompartido screenplay parsing intents.
///
/// This provider registers App Intents with Siri, enabling voice commands like:
/// - "Import screenplay with SwiftCompartido"
/// - "Parse screenplay file in SwiftCompartido"
/// - "Query screenplay elements in SwiftCompartido"
/// - "Get screenplay dialogue in SwiftCompartido"
/// - "Export screenplay in SwiftCompartido"
/// - "Extract characters in SwiftCompartido"
/// - "Get voice casting in SwiftCompartido"
/// - "Set voice casting in SwiftCompartido"
///
/// **Usage in Shortcuts**:
/// Users can invoke these intents via:
/// 1. Voice commands (Siri)
/// 2. Shortcuts app (iOS/macOS)
/// 3. Programmatic intent execution
///
/// **Example Voice Workflow**:
/// ```
/// User: "Import screenplay with SwiftCompartido"
/// Siri: [Opens file picker or uses provided file]
/// → ParseScreenplayFileIntent executes
/// → Returns ScreenplayElementsReference
/// → Can chain to voice generation, analysis, etc.
/// ```
@available(iOS 26.0, macOS 26.0, *)
public struct SwiftCompartidoShortcuts: AppShortcutsProvider {

  @AppShortcutsBuilder
  public static var appShortcuts: [AppShortcut] {
    // Parse & Import
    AppShortcut(
      intent: ParseScreenplayFileIntent(),
      phrases: [
        "Import screenplay with \(.applicationName)",
        "Parse screenplay file in \(.applicationName)",
        "Parse a screenplay in \(.applicationName)",
        "Import a script with \(.applicationName)",
      ],
      shortTitle: "Parse Screenplay",
      systemImageName: "doc.text"
    )

    // Query Elements
    AppShortcut(
      intent: QueryScreenplayElementsIntent(),
      phrases: [
        "Query screenplay elements in \(.applicationName)",
        "Get screenplay dialogue in \(.applicationName)",
        "Search screenplay in \(.applicationName)",
        "Find screenplay elements in \(.applicationName)",
      ],
      shortTitle: "Query Elements",
      systemImageName: "doc.text.magnifyingglass"
    )

    // Export
    AppShortcut(
      intent: ExportScreenplayIntent(),
      phrases: [
        "Export screenplay with \(.applicationName)",
        "Convert screenplay in \(.applicationName)",
        "Save screenplay as in \(.applicationName)",
      ],
      shortTitle: "Export Screenplay",
      systemImageName: "square.and.arrow.up"
    )

    // Extract Characters
    AppShortcut(
      intent: ExtractCharactersIntent(),
      phrases: [
        "Extract characters in \(.applicationName)",
        "Get character list from \(.applicationName)",
        "List characters in \(.applicationName)",
      ],
      shortTitle: "Extract Characters",
      systemImageName: "person.2"
    )

    // Get Voice Casting
    AppShortcut(
      intent: GetVoiceCastingIntent(),
      phrases: [
        "Get voice casting in \(.applicationName)",
        "Show voice assignments in \(.applicationName)",
        "List voice casting in \(.applicationName)",
      ],
      shortTitle: "Get Voice Casting",
      systemImageName: "person.wave.2"
    )

    // Set Voice Casting
    AppShortcut(
      intent: SetVoiceCastingIntent(),
      phrases: [
        "Set voice casting in \(.applicationName)",
        "Assign voice in \(.applicationName)",
        "Map character voice in \(.applicationName)",
      ],
      shortTitle: "Set Voice Casting",
      systemImageName: "waveform"
    )
  }
}
