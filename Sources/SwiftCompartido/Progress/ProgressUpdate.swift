import Foundation

/// Represents a snapshot of progress for a long-running operation.
///
/// `ProgressUpdate` is a lightweight, immutable struct that captures the current state
/// of an operation's progress. It is `Sendable`, making it safe to pass across actor
/// boundaries and thread contexts.
///
/// ## Usage
///
/// Progress updates are typically created by `OperationProgress` and delivered to
/// your progress handler:
///
/// ```swift
/// let handler: ProgressHandler = { update in
///     if let fraction = update.fractionCompleted {
///         print("Progress: \(Int(fraction * 100))%")
///     }
///     print(update.description)
/// }
/// ```
///
/// ## Progress Types
///
/// - **Determinate Progress**: When `totalUnits` is non-nil, `fractionCompleted`
///   represents actual progress (0.0 to 1.0)
/// - **Indeterminate Progress**: When `totalUnits` is nil, `fractionCompleted` is nil,
///   indicating unknown total work
///
/// - SeeAlso: `ProgressHandler`, `OperationProgress`
public struct ProgressUpdate: Sendable, Equatable {
    /// The fraction of work completed (0.0 to 1.0), or nil for indeterminate progress.
    ///
    /// This value is automatically calculated from `completedUnits` and `totalUnits`.
    /// If `totalUnits` is nil (indeterminate progress), this will be nil.
    public let fractionCompleted: Double?

    /// The number of work units completed so far.
    ///
    /// Units can represent anything meaningful to the operation: lines parsed,
    /// bytes written, elements processed, etc.
    public let completedUnits: Int64

    /// The total number of work units expected, or nil if unknown.
    ///
    /// When nil, the operation has indeterminate progress and `fractionCompleted`
    /// will also be nil.
    public let totalUnits: Int64?

    /// A human-readable description of the current operation.
    ///
    /// Examples: "Parsing screenplay...", "Writing bundle...", "Converting to SwiftData..."
    public let description: String

    /// Optional additional information about the current operation.
    ///
    /// This can include details like: "Processing line 523", "File 3 of 5", etc.
    public let additionalInfo: String?

    /// The time when this progress update was created.
    public let timestamp: Date

    /// Creates a new progress update.
    ///
    /// - Parameters:
    ///   - fractionCompleted: The fraction completed (0.0 to 1.0), or nil for indeterminate
    ///   - completedUnits: The number of units completed
    ///   - totalUnits: The total units expected, or nil if unknown
    ///   - description: A human-readable description of the current operation
    ///   - additionalInfo: Optional additional details
    ///   - timestamp: The time of this update (defaults to current time)
    public init(
        fractionCompleted: Double?,
        completedUnits: Int64,
        totalUnits: Int64?,
        description: String,
        additionalInfo: String? = nil,
        timestamp: Date = Date()
    ) {
        self.fractionCompleted = fractionCompleted
        self.completedUnits = completedUnits
        self.totalUnits = totalUnits
        self.description = description
        self.additionalInfo = additionalInfo
        self.timestamp = timestamp
    }

    /// Creates a determinate progress update (with known total).
    ///
    /// The fraction completed is automatically calculated as `completedUnits / totalUnits`.
    ///
    /// - Parameters:
    ///   - completedUnits: The number of units completed
    ///   - totalUnits: The total units expected
    ///   - description: A human-readable description
    ///   - additionalInfo: Optional additional details
    /// - Returns: A progress update with calculated fraction completed
    public static func determinate(
        completedUnits: Int64,
        totalUnits: Int64,
        description: String,
        additionalInfo: String? = nil
    ) -> ProgressUpdate {
        let fraction = totalUnits > 0 ? Double(completedUnits) / Double(totalUnits) : 0.0
        return ProgressUpdate(
            fractionCompleted: fraction,
            completedUnits: completedUnits,
            totalUnits: totalUnits,
            description: description,
            additionalInfo: additionalInfo
        )
    }

    /// Creates an indeterminate progress update (unknown total).
    ///
    /// Use this when the total amount of work cannot be determined in advance.
    ///
    /// - Parameters:
    ///   - completedUnits: The number of units completed so far
    ///   - description: A human-readable description
    ///   - additionalInfo: Optional additional details
    /// - Returns: A progress update with nil fraction completed
    public static func indeterminate(
        completedUnits: Int64,
        description: String,
        additionalInfo: String? = nil
    ) -> ProgressUpdate {
        return ProgressUpdate(
            fractionCompleted: nil,
            completedUnits: completedUnits,
            totalUnits: nil,
            description: description,
            additionalInfo: additionalInfo
        )
    }
}
