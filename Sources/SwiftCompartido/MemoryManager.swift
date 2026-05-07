import Foundation
import Metal

// MARK: - Telemetry Events

/// Telemetry events emitted by SwiftCompartido for memory monitoring
public enum CompartidoTelemetryEvent: Sendable {
    /// GPU cache clear operation started
    case gpuCacheClearStart(metalAllocatedMB: Double)

    /// GPU cache clear operation completed
    case gpuCacheClearComplete(freedMB: Double, metalAllocatedMB: Double)

    /// System memory pressure detected
    case memoryPressure(residentMB: Double, availableMB: Double)

    /// Shared state growth detected
    case sharedStateGrowth(singletonCount: Int, cacheSizeMB: Double)
}

// MARK: - Telemetry Reporter Protocol

/// Protocol for capturing telemetry events from SwiftCompartido
public protocol CompartidoTelemetryReporter: Sendable {
    /// Capture a telemetry event
    /// - Parameter event: The event to capture
    func capture(_ event: CompartidoTelemetryEvent) async
}

// MARK: - Memory Manager

/// Actor responsible for managing memory and GPU cache operations
public actor MemoryManager {
    /// Shared singleton instance
    public static let shared = MemoryManager()

    /// Optional telemetry reporter for memory operations
    private var telemetry: CompartidoTelemetryReporter?

    /// Private initializer to enforce singleton pattern
    private init() {}

    /// Set the telemetry reporter for this memory manager
    /// - Parameter reporter: The telemetry reporter to use, or nil to disable telemetry
    public func setTelemetry(_ reporter: CompartidoTelemetryReporter?) async {
        telemetry = reporter
    }
}
