import Foundation

/// The status of an AI service request throughout its lifecycle.
///
/// `RequestStatus` tracks the state of a request from submission through completion or failure.
/// This type is Sendable and can be safely observed across actor boundaries.
///
/// ## Example
/// ```swift
/// switch status {
/// case .pending:
///     print("Request queued")
/// case .executing(let progress):
///     print("Executing: \(progress ?? 0)%")
/// case .completed(let response):
///     print("Completed with \(response.content)")
/// case .failed(let error):
///     print("Failed: \(error)")
/// case .cancelled:
///     print("Cancelled by user")
/// }
/// ```
public enum RequestStatus: Sendable {

    /// Request has been submitted but not yet started execution.
    case pending

    /// Request is currently executing.
    /// - Parameter progress: Optional progress value between 0.0 and 1.0.
    case executing(progress: Double?)

    /// Request completed successfully.
    /// - Parameter response: The response data from the provider.
    case completed(AIResponseData)

    /// Request failed with an error.
    /// - Parameter error: The error that caused the failure.
    case failed(AIServiceError)

    /// Request was cancelled before completion.
    case cancelled

    // MARK: - Convenience Properties

    /// Whether the request is still in progress (pending or executing).
    public var isInProgress: Bool {
        switch self {
        case .pending, .executing:
            return true
        case .completed, .failed, .cancelled:
            return false
        }
    }

    /// Whether the request has finished (completed, failed, or cancelled).
    public var isFinished: Bool {
        !isInProgress
    }

    /// Whether the request completed successfully.
    public var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }

    /// Whether the request failed.
    public var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }

    /// Whether the request was cancelled.
    public var isCancelled: Bool {
        if case .cancelled = self {
            return true
        }
        return false
    }

    /// The response data if completed, nil otherwise.
    public var responseData: AIResponseData? {
        if case .completed(let response) = self {
            return response
        }
        return nil
    }

    /// The error if failed, nil otherwise.
    public var error: AIServiceError? {
        if case .failed(let error) = self {
            return error
        }
        return nil
    }

    /// The progress if executing, nil otherwise.
    public var progress: Double? {
        if case .executing(let progress) = self {
            return progress
        }
        return nil
    }

    // MARK: - Description

    /// Human-readable description of the status.
    public var description: String {
        switch self {
        case .pending:
            return "Pending"
        case .executing(let progress):
            if let progress = progress {
                return "Executing (\(Int(progress * 100))%)"
            }
            return "Executing"
        case .completed:
            return "Completed"
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        case .cancelled:
            return "Cancelled"
        }
    }
}

// MARK: - Request Tracking

/// A tracked request with its current status and metadata.
///
/// `TrackedRequest` combines a request, its current status, and timing information
/// for observability and debugging.
public struct TrackedRequest: Sendable, Identifiable {

    /// The original request.
    public let request: AIRequest

    /// The current status of the request.
    public let status: RequestStatus

    /// The provider ID this request is assigned to.
    public let providerID: String

    /// When the request was submitted.
    public let submittedAt: Date

    /// When execution started (if applicable).
    public let startedAt: Date?

    /// When the request finished (if applicable).
    public let finishedAt: Date?

    /// Unique identifier (same as request.id).
    public var id: UUID { request.id }

    /// Duration of the request if finished, or current duration if in progress.
    public var duration: TimeInterval? {
        if let finished = finishedAt {
            return finished.timeIntervalSince(submittedAt)
        } else if let started = startedAt {
            return Date().timeIntervalSince(started)
        }
        return nil
    }

    /// Creates a new tracked request.
    ///
    /// - Parameters:
    ///   - request: The original request
    ///   - status: Current status
    ///   - providerID: Provider ID
    ///   - submittedAt: Submission timestamp
    ///   - startedAt: Start timestamp (optional)
    ///   - finishedAt: Finish timestamp (optional)
    public init(
        request: AIRequest,
        status: RequestStatus,
        providerID: String,
        submittedAt: Date = Date(),
        startedAt: Date? = nil,
        finishedAt: Date? = nil
    ) {
        self.request = request
        self.status = status
        self.providerID = providerID
        self.submittedAt = submittedAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    /// Creates a new tracked request with updated status.
    ///
    /// - Parameter status: The new status
    /// - Returns: A new tracked request with the updated status
    public func withStatus(_ status: RequestStatus) -> TrackedRequest {
        let now = Date()
        let newStartedAt: Date?
        let newFinishedAt: Date?

        switch status {
        case .executing:
            // Mark as started if not already started
            newStartedAt = startedAt ?? now
            newFinishedAt = finishedAt
        case .completed, .failed, .cancelled:
            // Mark as finished
            newStartedAt = startedAt
            newFinishedAt = finishedAt ?? now
        case .pending:
            // Pending state shouldn't have started/finished times
            newStartedAt = startedAt
            newFinishedAt = finishedAt
        }

        return TrackedRequest(
            request: request,
            status: status,
            providerID: providerID,
            submittedAt: submittedAt,
            startedAt: newStartedAt,
            finishedAt: newFinishedAt
        )
    }

    /// Creates a new tracked request with updated progress.
    ///
    /// - Parameter progress: The progress value (0.0 to 1.0)
    /// - Returns: A new tracked request with updated progress
    public func withProgress(_ progress: Double) -> TrackedRequest {
        withStatus(.executing(progress: progress))
    }
}

// MARK: - Request Statistics

/// Statistics about request execution.
public struct RequestStatistics: Sendable {

    /// Total number of requests tracked.
    public let totalRequests: Int

    /// Number of pending requests.
    public let pendingRequests: Int

    /// Number of executing requests.
    public let executingRequests: Int

    /// Number of completed requests.
    public let completedRequests: Int

    /// Number of failed requests.
    public let failedRequests: Int

    /// Number of cancelled requests.
    public let cancelledRequests: Int

    /// Average duration of completed requests in seconds.
    public let averageDuration: TimeInterval?

    /// Success rate (completed / (completed + failed)), between 0.0 and 1.0.
    public let successRate: Double?

    /// Creates request statistics.
    ///
    /// - Parameters:
    ///   - totalRequests: Total request count
    ///   - pendingRequests: Pending count
    ///   - executingRequests: Executing count
    ///   - completedRequests: Completed count
    ///   - failedRequests: Failed count
    ///   - cancelledRequests: Cancelled count
    ///   - averageDuration: Average duration
    ///   - successRate: Success rate
    public init(
        totalRequests: Int,
        pendingRequests: Int,
        executingRequests: Int,
        completedRequests: Int,
        failedRequests: Int,
        cancelledRequests: Int,
        averageDuration: TimeInterval?,
        successRate: Double?
    ) {
        self.totalRequests = totalRequests
        self.pendingRequests = pendingRequests
        self.executingRequests = executingRequests
        self.completedRequests = completedRequests
        self.failedRequests = failedRequests
        self.cancelledRequests = cancelledRequests
        self.averageDuration = averageDuration
        self.successRate = successRate
    }

    /// Creates statistics from a collection of tracked requests.
    ///
    /// - Parameter requests: The tracked requests to analyze
    /// - Returns: Statistics computed from the requests
    public static func from(_ requests: [TrackedRequest]) -> RequestStatistics {
        let pending = requests.filter { $0.status.isInProgress && !$0.status.isFinished }.count
        let executing = requests.filter {
            if case .executing = $0.status { return true }
            return false
        }.count
        let completed = requests.filter { $0.status.isCompleted }.count
        let failed = requests.filter { $0.status.isFailed }.count
        let cancelled = requests.filter { $0.status.isCancelled }.count

        let completedWithDuration = requests.compactMap { tracked -> TimeInterval? in
            guard tracked.status.isCompleted, let duration = tracked.duration else {
                return nil
            }
            return duration
        }

        let averageDuration = completedWithDuration.isEmpty ?
            nil : completedWithDuration.reduce(0, +) / Double(completedWithDuration.count)

        let totalFinished = completed + failed
        let successRate = totalFinished > 0 ? Double(completed) / Double(totalFinished) : nil

        return RequestStatistics(
            totalRequests: requests.count,
            pendingRequests: pending,
            executingRequests: executing,
            completedRequests: completed,
            failedRequests: failed,
            cancelledRequests: cancelled,
            averageDuration: averageDuration,
            successRate: successRate
        )
    }
}
