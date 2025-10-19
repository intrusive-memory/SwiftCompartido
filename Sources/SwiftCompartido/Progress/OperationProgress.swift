import Foundation

/// A thread-safe progress tracker for long-running operations.
///
/// `OperationProgress` manages progress state and delivers batched updates to a
/// progress handler. It automatically throttles updates to avoid overwhelming
/// the handler with too many callbacks.
///
/// ## Usage
///
/// Create an `OperationProgress` instance and pass it to operations that support
/// progress reporting:
///
/// ```swift
/// let progress = OperationProgress(totalUnits: 1000) { update in
///     print("Progress: \(Int((update.fractionCompleted ?? 0) * 100))%")
/// }
///
/// for i in 0..<1000 {
///     // Do work...
///     progress.increment(by: 1, description: "Processing item \(i)")
/// }
///
/// progress.complete()
/// ```
///
/// ## Thread Safety
///
/// `OperationProgress` is thread-safe and can be updated from multiple concurrent
/// contexts. It uses internal synchronization to ensure consistent state.
///
/// ## Update Batching
///
/// To avoid excessive callbacks, updates are batched based on time. The progress
/// handler will be called at most once per `updateInterval` (default 100ms).
/// The final update when `complete()` is called is always delivered immediately.
///
/// - SeeAlso: `ProgressUpdate`, `ProgressHandler`
public final class OperationProgress: @unchecked Sendable {
    // MARK: - State

    /// The total number of work units, or nil for indeterminate progress.
    public private(set) var totalUnitCount: Int64?

    /// The number of work units completed so far.
    public private(set) var completedUnitCount: Int64 = 0

    /// Whether the operation has been marked as cancelled.
    public private(set) var isCancelled: Bool = false

    // MARK: - Private State

    private let handler: ProgressHandler?
    private let updateInterval: TimeInterval
    private var lastUpdateTime: Date?
    private let lock = NSLock()
    private var lastDescription: String = ""

    // MARK: - Initialization

    /// Creates a new operation progress tracker.
    ///
    /// - Parameters:
    ///   - totalUnits: The total units of work expected, or nil for indeterminate progress
    ///   - updateInterval: Minimum time between progress updates (default: 0.1 seconds)
    ///   - handler: Optional closure to receive progress updates
    public init(
        totalUnits: Int64? = nil,
        updateInterval: TimeInterval = 0.1,
        handler: ProgressHandler? = nil
    ) {
        self.totalUnitCount = totalUnits
        self.updateInterval = updateInterval
        self.handler = handler
    }

    // MARK: - Progress Updates

    /// Updates the completed units count and reports progress if needed.
    ///
    /// Progress updates are batched based on `updateInterval` to avoid excessive
    /// handler callbacks. The update will be delivered if enough time has passed
    /// since the last update.
    ///
    /// - Parameters:
    ///   - completedUnits: The new completed units count
    ///   - description: A human-readable description of the current operation
    ///   - additionalInfo: Optional additional information
    ///   - force: If true, bypasses the update interval and delivers immediately
    public func update(
        completedUnits: Int64,
        description: String,
        additionalInfo: String? = nil,
        force: Bool = false
    ) {
        lock.lock()
        defer { lock.unlock() }

        self.completedUnitCount = completedUnits
        self.lastDescription = description

        // Check if enough time has passed since last update
        let now = Date()
        let shouldUpdate = force ||
            lastUpdateTime == nil ||
            now.timeIntervalSince(lastUpdateTime!) >= updateInterval

        guard shouldUpdate, let handler = handler else {
            return
        }

        lastUpdateTime = now

        // Create and deliver the update
        let update = createUpdate(description: description, additionalInfo: additionalInfo)
        handler(update)
    }

    /// Increments the completed units count by a delta.
    ///
    /// This is a convenience method that adds to the current `completedUnitCount`.
    ///
    /// - Parameters:
    ///   - delta: The number of units to add (default: 1)
    ///   - description: A human-readable description
    ///   - additionalInfo: Optional additional information
    ///   - force: If true, bypasses the update interval
    public func increment(
        by delta: Int64 = 1,
        description: String,
        additionalInfo: String? = nil,
        force: Bool = false
    ) {
        lock.lock()
        defer { lock.unlock() }

        self.completedUnitCount += delta
        self.lastDescription = description

        // Check if enough time has passed since last update
        let now = Date()
        let shouldUpdate = force ||
            lastUpdateTime == nil ||
            now.timeIntervalSince(lastUpdateTime!) >= updateInterval

        guard shouldUpdate, let handler = handler else {
            return
        }

        lastUpdateTime = now

        // Create and deliver the update
        let update = createUpdate(description: description, additionalInfo: additionalInfo)
        handler(update)
    }

    /// Marks the operation as complete and delivers a final progress update.
    ///
    /// This sets `completedUnitCount` equal to `totalUnitCount` (if determinate)
    /// and delivers a final update immediately, bypassing the update interval.
    ///
    /// - Parameter description: Optional custom completion message
    public func complete(description: String? = nil) {
        lock.lock()
        if let total = totalUnitCount {
            self.completedUnitCount = total
        }
        let finalDescription = description ?? lastDescription
        lock.unlock()

        update(
            completedUnits: completedUnitCount,
            description: finalDescription,
            force: true
        )
    }

    /// Marks the operation as cancelled.
    ///
    /// This sets the `isCancelled` flag to true. The operation itself is
    /// responsible for checking this flag (or `Task.isCancelled`) and
    /// stopping work.
    public func cancel() {
        lock.lock()
        defer { lock.unlock() }
        self.isCancelled = true
    }

    /// Sets the total unit count.
    ///
    /// This can be called to change from indeterminate to determinate progress,
    /// or to adjust the total as more information becomes available.
    ///
    /// - Parameter totalUnits: The new total unit count, or nil for indeterminate
    public func setTotalUnitCount(_ totalUnits: Int64?) {
        lock.lock()
        defer { lock.unlock() }
        self.totalUnitCount = totalUnits
    }

    // MARK: - Private Helpers

    private func createUpdate(description: String, additionalInfo: String?) -> ProgressUpdate {
        // Called with lock held
        if let total = totalUnitCount {
            return .determinate(
                completedUnits: completedUnitCount,
                totalUnits: total,
                description: description,
                additionalInfo: additionalInfo
            )
        } else {
            return .indeterminate(
                completedUnits: completedUnitCount,
                description: description,
                additionalInfo: additionalInfo
            )
        }
    }
}
