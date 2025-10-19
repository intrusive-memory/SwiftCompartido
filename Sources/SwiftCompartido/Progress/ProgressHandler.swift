import Foundation

/// A closure that receives progress updates during long-running operations.
///
/// Progress handlers are `@Sendable` closures, meaning they can be safely called
/// from any thread or actor context. The handler receives `ProgressUpdate` snapshots
/// as the operation progresses.
///
/// ## Usage
///
/// ```swift
/// let progressHandler: ProgressHandler = { update in
///     if let fraction = update.fractionCompleted {
///         print("Progress: \(Int(fraction * 100))%")
///     }
///     print(update.description)
/// }
///
/// let parser = try await FountainParser(
///     string: screenplay,
///     progress: OperationProgress(handler: progressHandler)
/// )
/// ```
///
/// ## Thread Safety
///
/// Your handler may be called from any thread. If you need to update UI, dispatch
/// to the main actor:
///
/// ```swift
/// let progressHandler: ProgressHandler = { update in
///     Task { @MainActor in
///         self.progressValue = update.fractionCompleted ?? 0
///         self.statusText = update.description
///     }
/// }
/// ```
///
/// ## Error Handling
///
/// If your progress handler throws an error, the operation will continue without
/// further progress updates. The operation itself will not be cancelled.
///
/// - SeeAlso: `ProgressUpdate`, `OperationProgress`
public typealias ProgressHandler = @Sendable (ProgressUpdate) -> Void
