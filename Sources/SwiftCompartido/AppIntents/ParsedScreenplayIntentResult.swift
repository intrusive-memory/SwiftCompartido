//
//  ParsedScreenplayIntentResult.swift
//  SwiftCompartido
//
//  Custom IntentResult type for returning ScreenplayElementsReference from App Intents.
//

import AppIntents
import Foundation

/// Result type for screenplay parsing intents.
///
/// This struct wraps `ScreenplayElementsReference` and conforms to `IntentResult` protocols
/// to enable returning screenplay data from App Intents.
///
/// **Usage**:
/// ```swift
/// public func perform() async throws -> ParsedScreenplayIntentResult {
///     let reference = ScreenplayElementsReference(...)
///     return .result(value: reference)
/// }
/// ```
@available(iOS 26.0, macOS 26.0, *)
public struct ParsedScreenplayIntentResult: Sendable {
    // This is a marker type - the actual result is created via .result() static method
}

@available(iOS 26.0, macOS 26.0, *)
extension ParsedScreenplayIntentResult {
    /// Creates a result with a screenplay reference value.
    ///
    /// - Parameter value: The screenplay elements reference
    /// - Returns: An intent result
    public static func result(value: ScreenplayElementsReference) -> some IntentResult & ReturnsValue<ScreenplayElementsReference> {
        // Based on AppIntents examples, .result(value:) should work for Transferable types
        return .result(value: value)
    }

    /// Creates a result with a screenplay reference value and dialog message.
    ///
    /// - Parameters:
    ///   - value: The screenplay elements reference
    ///   - dialog: Dialog message to display
    /// - Returns: An intent result
    public static func result(value: ScreenplayElementsReference, dialog: IntentDialog) -> some IntentResult & ReturnsValue<ScreenplayElementsReference> & ProvidesDialog {
        return .result(value: value, dialog: dialog)
    }
}
