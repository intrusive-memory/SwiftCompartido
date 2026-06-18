//
//  SpeakableElement.swift
//  SwiftCompartido
//
//  Protocol for types that expose glosa-annotated spoken text and performance data.
//  Allows sharing audio-generation code between GuionElementModel and ElementReference.
//

import Foundation

/// Protocol for types that expose glosa-annotated spoken text and performance data.
///
/// This protocol enables code reuse between `GuionElementModel` (SwiftData model)
/// and `ElementReference` (Transferable DTO from App Intents) when generating audio
/// or displaying spoken text with breath/pause annotations.
///
/// By conforming to this protocol, both types can use the same audio generation
/// and breath-overlay rendering code without duplication.
///
/// ## Example
///
/// ```swift
/// func generateAudio<T: SpeakableElement>(for element: T) {
///     let text = element.spokenText
///     let breathPoints = element.breathOffsets
///     // Generate TTS with breath hints at specified offsets
/// }
/// ```
@available(iOS 26.0, macOS 26.0, *)
public protocol SpeakableElement {
  /// The spoken prose for this element, with inline glosa notes stripped.
  ///
  /// - Returns: `glosaSpokenText` if available, otherwise falls back to `elementText`
  var spokenText: String { get }

  /// Unicode-scalar boundary offsets in `spokenText` where breath hints are located.
  ///
  /// - Returns: `glosaBreathOffsets` if available, otherwise empty array
  var breathOffsets: [Int] { get }

  /// Composed LLM performance-direction string for this line, if any.
  ///
  /// - Returns: `glosaInstruct` if available, otherwise `nil`
  var instruct: String? { get }
}
