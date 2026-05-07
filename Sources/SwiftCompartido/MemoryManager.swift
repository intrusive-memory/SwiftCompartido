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

// MARK: - Memory Pressure Report

/// Report of current memory pressure state
public struct MemoryPressureReport: Sendable {
    /// Resident memory in MB
    public let residentMB: Double

    /// Available memory in MB
    public let availableMB: Double

    /// Memory pressure level
    public let pressureLevel: MemoryPressureLevel

    public init(residentMB: Double, availableMB: Double, pressureLevel: MemoryPressureLevel) {
        self.residentMB = residentMB
        self.availableMB = availableMB
        self.pressureLevel = pressureLevel
    }
}

/// Memory pressure level classification
public enum MemoryPressureLevel: Sendable {
    case low
    case moderate
    case high
    case critical
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

    // MARK: - GPU Memory Management

    /// Get current Metal memory allocation in MB
    /// - Returns: Current allocated Metal memory in megabytes
    private func getCurrentMetalMemory() -> Double {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return 0.0
        }

        let allocatedBytes = device.currentAllocatedSize
        let allocatedMB = Double(allocatedBytes) / (1024.0 * 1024.0)
        return allocatedMB
    }

    /// Clear GPU cache and report telemetry
    public func clearGPUCache() async {
        let startMemory = getCurrentMetalMemory()

        // Capture telemetry start event
        await telemetry?.capture(.gpuCacheClearStart(metalAllocatedMB: startMemory))

        // Perform GPU cache clearing
        // Note: Metal automatically manages most GPU memory, but we can force cleanup
        // by releasing references and allowing the system to reclaim memory
        guard let device = MTLCreateSystemDefaultDevice() else {
            await telemetry?.capture(.gpuCacheClearComplete(freedMB: 0.0, metalAllocatedMB: 0.0))
            return
        }

        // Force Metal to clean up by creating and destroying a command queue
        // This encourages Metal to release unused resources
        autoreleasepool {
            _ = device.makeCommandQueue()
        }

        let endMemory = getCurrentMetalMemory()
        let freedMB = max(0.0, startMemory - endMemory)

        // Capture telemetry completion event
        await telemetry?.capture(.gpuCacheClearComplete(freedMB: freedMB, metalAllocatedMB: endMemory))
    }

    // MARK: - Memory Pressure Monitoring

    /// Report current memory pressure state
    /// - Returns: A report containing resident memory, available memory, and pressure level
    public func reportMemoryPressure() async -> MemoryPressureReport {
        // Get this process's resident memory
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        guard kerr == KERN_SUCCESS else {
            let report = MemoryPressureReport(residentMB: 0.0, availableMB: 0.0, pressureLevel: .low)
            await telemetry?.capture(.memoryPressure(residentMB: 0.0, availableMB: 0.0))
            return report
        }

        let residentMB = Double(info.resident_size) / (1024.0 * 1024.0)

        // Get system-wide memory statistics
        var vmStats = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let hostPort = mach_host_self()
        let vmKerr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(hostPort,
                                 HOST_VM_INFO64,
                                 $0,
                                 &vmCount)
            }
        }

        // Get page size
        var pageSize: vm_size_t = 0
        host_page_size(hostPort, &pageSize)

        // Calculate available memory from system-wide statistics
        let availableMB: Double
        if vmKerr == KERN_SUCCESS {
            // Available memory = free pages + inactive pages (can be reclaimed)
            let availablePages = UInt64(vmStats.free_count) + UInt64(vmStats.inactive_count)
            availableMB = Double(availablePages * UInt64(pageSize)) / (1024.0 * 1024.0)
        } else {
            // Fallback: use physical memory if host statistics fail
            var physicalMemory: UInt64 = 0
            var size = MemoryLayout<UInt64>.size
            sysctlbyname("hw.memsize", &physicalMemory, &size, nil, 0)
            availableMB = Double(physicalMemory) / (1024.0 * 1024.0)
        }

        // Get total physical memory for pressure calculation
        var physicalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &physicalMemory, &size, nil, 0)
        let totalMemoryMB = Double(physicalMemory) / (1024.0 * 1024.0)

        // Determine pressure level based on available memory percentage
        let availablePercent = (availableMB / totalMemoryMB) * 100.0
        let pressureLevel: MemoryPressureLevel

        switch availablePercent {
        case 50...:
            pressureLevel = .low
        case 25..<50:
            pressureLevel = .moderate
        case 10..<25:
            pressureLevel = .high
        default:
            pressureLevel = .critical
        }

        let report = MemoryPressureReport(
            residentMB: residentMB,
            availableMB: availableMB,
            pressureLevel: pressureLevel
        )

        // Capture telemetry event
        await telemetry?.capture(.memoryPressure(residentMB: residentMB, availableMB: availableMB))

        return report
    }
}
