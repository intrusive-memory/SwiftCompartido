import Foundation

/// Errors that can occur during progress reporting operations.
///
/// These errors are distinct from the operation being tracked. For example,
/// if parsing fails, it will throw a parsing error, not a `ProgressError`.
/// Progress errors indicate problems with the progress reporting mechanism itself.
public enum ProgressError: LocalizedError, Sendable {
    /// The operation was cancelled by the user or system.
    ///
    /// This typically corresponds to `Task.isCancelled` being true during
    /// a long-running operation.
    case cancelled

    /// The progress state is invalid or inconsistent.
    ///
    /// - Parameter message: A description of the invalid state
    case invalidState(String)

    /// Progress reporting failed due to an underlying error.
    ///
    /// This wraps errors from the progress reporting system itself, not the
    /// operation being tracked.
    ///
    /// - Parameter error: The underlying error that caused the failure
    case progressReportingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Operation was cancelled"
        case .invalidState(let message):
            return "Invalid progress state: \(message)"
        case .progressReportingFailed(let error):
            return "Progress reporting failed: \(error.localizedDescription)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .cancelled:
            return "The operation was cancelled before completion. You can retry if needed."
        case .invalidState:
            return "This may indicate a bug in the progress reporting system. Please report this issue."
        case .progressReportingFailed:
            return "The operation may have completed despite the progress reporting failure."
        }
    }
}
