# SwiftCompartido Telemetry Requirements

**Priority**: 🟢 MEDIUM  
**Status**: Not Started  
**Effort Estimate**: 1-2 hours  
**Dependencies**: None

## Context

SwiftCompartido provides shared utilities used across all repos. Memory leaks could be hiding in:
1. **MemoryManager** - GPU cache clearing might not work
2. **Caching utilities** - If any exist
3. **Data structures** - Shared state retention

This repo is less likely to be the leak source, but needs instrumentation to rule it out.

## Objectives

1. **Verify MemoryManager.clearGPUCache() actually works**
2. **Track Metal buffer state** before/after clear
3. **Report any shared cache growth**
4. **Ensure no shared state accumulates**

## Telemetry Points

### 1. MemoryManager GPU Cache Clearing

**File**: `Sources/SwiftCompartido/MemoryManager.swift`

Verify GPU cache is actually cleared:

```swift
public actor MemoryManager {
    public static let shared = MemoryManager()
    
    public func clearGPUCache() async {
        // TELEMETRY: Before clear
        let beforeMB = getCurrentMetalMemory()
        await telemetry?.capture(.gpuCacheClearStart(metalAllocatedMB: beforeMB))
        
        // Existing clear logic
        // ... Metal synchronization, cache clearing ...
        
        // TELEMETRY: After clear
        let afterMB = getCurrentMetalMemory()
        let freedMB = beforeMB - afterMB
        await telemetry?.capture(.gpuCacheClearComplete(
            freedMB: freedMB,
            metalAllocatedMB: afterMB
        ))
    }
    
    private func getCurrentMetalMemory() -> Double {
        guard let device = MTLCreateSystemDefaultDevice() else { return 0.0 }
        return Double(device.currentAllocatedSize) / 1024 / 1024
    }
}
```

### 2. Memory Pressure Monitoring

**File**: `Sources/SwiftCompartido/MemoryManager.swift`

Track system memory pressure:

```swift
public func reportMemoryPressure() -> MemoryPressureReport {
    // Get system memory stats
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    
    guard result == KERN_SUCCESS else {
        return MemoryPressureReport(residentMB: 0, availableMB: 0, pressure: .unknown)
    }
    
    let residentMB = Double(info.resident_size) / 1024 / 1024
    
    return MemoryPressureReport(
        residentMB: residentMB,
        availableMB: getAvailableMemory(),
        pressure: calculatePressure()
    )
}
```

### 3. Shared State Tracking

If SwiftCompartido has any shared caches or singletons:

```swift
public func reportSharedState() -> SharedStateTelemetry {
    return SharedStateTelemetry(
        singletonCount: activeSingletons.count,
        cacheSize: sharedCache.count,
        memoryFootprintMB: estimateMemoryFootprint()
    )
}
```

## Data Structures

### Telemetry Events

```swift
public enum CompartidoTelemetryEvent: Sendable {
    case gpuCacheClearStart(metalAllocatedMB: Double)
    case gpuCacheClearComplete(freedMB: Double, metalAllocatedMB: Double)
    case memoryPressure(residentMB: Double, availableMB: Double)
    case sharedStateGrowth(singletonCount: Int, cacheSizeMB: Double)
}
```

### Telemetry Reporter Protocol

```swift
public protocol CompartidoTelemetryReporter: Sendable {
    func capture(_ event: CompartidoTelemetryEvent) async
}
```

### Integration

```swift
// Global telemetry setter for MemoryManager
public extension MemoryManager {
    func setTelemetry(_ reporter: CompartidoTelemetryReporter?) async {
        telemetry = reporter
    }
}
```

## Implementation Checklist

### Phase 1: Infrastructure (30 min)
- [ ] Create `CompartidoTelemetryEvent` enum
- [ ] Create `CompartidoTelemetryReporter` protocol
- [ ] Add `telemetry` property to `MemoryManager`

### Phase 2: Core Instrumentation (1 hour)
- [ ] Instrument `clearGPUCache()` - before/after
- [ ] Add `getCurrentMetalMemory()` helper
- [ ] Add `reportMemoryPressure()` method

### Phase 3: Testing (30 min)
- [ ] Unit test: GPU cache clear telemetry
- [ ] Integration test: reports to Produciesta

## Testing Strategy

### Unit Tests

```swift
func testGPUCacheClearTelemetry() async throws {
    let mockTelemetry = MockTelemetryReporter()
    let manager = MemoryManager.shared
    await manager.setTelemetry(mockTelemetry)
    
    await manager.clearGPUCache()
    
    XCTAssertEqual(mockTelemetry.events.count, 2)
    XCTAssert(mockTelemetry.events[0] is .gpuCacheClearStart)
    XCTAssert(mockTelemetry.events[1] is .gpuCacheClearComplete)
}
```

### Integration Test

```bash
bin/produciesta ~/test-project --telemetry | grep "Compartido"
```

Expected:
```
📊 [Compartido] GPU cache clear: 450.2 MB freed
```

## Success Criteria

### Must Have
- [x] `clearGPUCache()` reports Metal memory before/after
- [x] GPU cache clear effectiveness measurable
- [x] Memory pressure can be queried

### Nice to Have
- [ ] Shared state tracking (if applicable)
- [ ] Singleton lifecycle monitoring

## Expected Findings

**Scenario 1: GPU Cache Not Clearing**
```
GPU cache clear start: 450.2 MB
GPU cache clear complete: freed 0.0 MB ⚠️
```
→ `clearGPUCache()` called but Metal memory not released

**Scenario 2: GPU Cache Clears Correctly**
```
GPU cache clear start: 450.2 MB
GPU cache clear complete: freed 448.1 MB ✅
```
→ GPU cache works correctly, leak is elsewhere

## Next Steps After Instrumentation

1. **Run telemetry test**
2. **Verify GPU cache clears Metal memory**
3. **If GPU cache broken**: Fix Metal synchronization
4. **If GPU cache works**: Leak is in VoxAlta or Secuencia

## References

- **Produciesta telemetry**: [TELEMETRY_FINDINGS.md](../Produciesta/TELEMETRY_FINDINGS.md)
- **Coordination doc**: [MULTI_REPO_TELEMETRY.md](../Produciesta/MULTI_REPO_TELEMETRY.md)
- **MemoryManager**: `Sources/SwiftCompartido/MemoryManager.swift`

---

**Ready to start?** Open a new Claude Code window in `/Users/stovak/Projects/SwiftCompartido` and follow this REQUIREMENTS document.
