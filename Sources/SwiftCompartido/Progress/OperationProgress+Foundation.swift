import Foundation

/// Extension to bridge OperationProgress with Foundation.Progress
///
/// This allows SwiftCompartido's OperationProgress to update a Foundation.Progress object,
/// enabling integration with system progress reporting (e.g., ProgressView, NSProgress).
///
/// ## Usage
///
/// ```swift
/// // Create a Foundation.Progress object
/// let foundationProgress = Progress(totalUnitCount: 100)
///
/// // Create an OperationProgress that updates it
/// let operationProgress = OperationProgress.bridged(to: foundationProgress)
///
/// // Use operationProgress with SwiftCompartido parsers
/// let screenplay = try await GuionParsedElementCollection(
///     file: path,
///     progress: operationProgress
/// )
///
/// // foundationProgress automatically updates as parsing progresses
/// ```
extension OperationProgress {

  /// Creates an OperationProgress that bridges to a Foundation.Progress object
  ///
  /// Updates to the OperationProgress will automatically update the Foundation.Progress
  /// object's `completedUnitCount`, making it suitable for use with system progress UI.
  ///
  /// - Parameters:
  ///   - foundationProgress: The Foundation.Progress object to update
  ///   - totalUnits: Optional total units (if nil, uses Foundation.Progress.totalUnitCount)
  /// - Returns: An OperationProgress configured to update the Foundation.Progress
  public static func bridged(
    to foundationProgress: Progress,
    totalUnits: Int64? = nil
  ) -> OperationProgress {
    let total = totalUnits ?? foundationProgress.totalUnitCount

    return OperationProgress(totalUnits: total) { update in
      // Update Foundation.Progress on main thread for UI compatibility
      Task { @MainActor in
        foundationProgress.completedUnitCount = update.completedUnits

        // Update localized descriptions
        foundationProgress.localizedDescription = update.description

        if let additionalInfo = update.additionalInfo {
          foundationProgress.localizedAdditionalDescription = additionalInfo
        }
      }
    }
  }
}
