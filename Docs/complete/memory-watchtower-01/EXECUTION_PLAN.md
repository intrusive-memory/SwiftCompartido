---
feature_name: OPERATION MEMORY WATCHTOWER
starting_point_commit: 30ae49aea062a90ef489b64e4ff4f615d25ca502
iteration: 1
---

# EXECUTION_PLAN.md — SwiftCompartido Telemetry

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

## Mission Overview

Instrument SwiftCompartido's `MemoryManager` with telemetry to verify GPU cache clearing effectiveness and track memory pressure. This addresses potential memory leaks by making Metal memory allocation and clearing operations observable.

**Source**: `REQUIREMENTS_telemetry.md`  
**Target File**: `Sources/SwiftCompartido/MemoryManager.swift`  
**Priority**: 🟢 MEDIUM  
**Estimated Effort**: 1-2 hours

## Work Units

| Work Unit | Directory | Sorties | Layer | Dependencies |
|-----------|-----------|---------|-------|--------------|
| SwiftCompartido Telemetry | /Users/stovak/Projects/SwiftCompartido | 3 | 1 | none |

## Sortie Definitions

### Sortie 1: Telemetry Infrastructure

**Entry criteria**:
- [ ] First sortie — no prerequisites
- [ ] MemoryManager.swift exists at `Sources/SwiftCompartido/MemoryManager.swift`

**Tasks**:
1. Create `CompartidoTelemetryEvent` enum in MemoryManager.swift with 4 cases: `gpuCacheClearStart(metalAllocatedMB:)`, `gpuCacheClearComplete(freedMB:metalAllocatedMB:)`, `memoryPressure(residentMB:availableMB:)`, `sharedStateGrowth(singletonCount:cacheSizeMB:)`
2. Create `CompartidoTelemetryReporter` protocol conforming to `Sendable` with `func capture(_ event: CompartidoTelemetryEvent) async`
3. Add private `telemetry: CompartidoTelemetryReporter?` property to `MemoryManager` actor
4. Add public `func setTelemetry(_ reporter: CompartidoTelemetryReporter?) async` method to MemoryManager

**Exit criteria**:
- [ ] `CompartidoTelemetryEvent` enum defined with all 4 cases
- [ ] `CompartidoTelemetryReporter` protocol defined and marked `Sendable`
- [ ] MemoryManager has telemetry property and setter method
- [ ] Code compiles without errors: `xcodebuild build -scheme SwiftCompartido -destination 'platform=macOS'` succeeds

**Priority**: 9.84 — Foundation (establishes telemetry types for 2+ sorties), blocks 2 sorties

---

### Sortie 2: Core Instrumentation

**Entry criteria**:
- [ ] Sortie 1 complete (telemetry infrastructure exists)
- [ ] MemoryManager has telemetry property available

**Tasks**:
1. Implement `private func getCurrentMetalMemory() -> Double` helper that queries `MTLCreateSystemDefaultDevice()` and returns `currentAllocatedSize` in MB
2. Instrument existing `clearGPUCache()` method with telemetry capture: capture `.gpuCacheClearStart` before clearing, capture `.gpuCacheClearComplete` after clearing with freed MB calculation
3. Implement `public func reportMemoryPressure() -> MemoryPressureReport` method using `mach_task_basic_info` to get resident memory and calculate pressure level

**Exit criteria**:
- [ ] `getCurrentMetalMemory()` method implemented and returns Metal memory in MB
- [ ] `clearGPUCache()` calls `telemetry?.capture()` before and after GPU cache clearing logic
- [ ] `reportMemoryPressure()` method implemented with mach task info query
- [ ] Code compiles without errors: `xcodebuild build -scheme SwiftCompartido -destination 'platform=macOS'` succeeds
- [ ] No telemetry calls crash when `telemetry` is nil (optional chaining works)

**Priority**: 7.00 — Higher risk (Metal/mach system APIs), blocks 1 sortie

---

### Sortie 3: Testing & Verification

**Entry criteria**:
- [ ] Sortie 2 complete (core instrumentation exists)
- [ ] `clearGPUCache()` has telemetry capture points
- [ ] `reportMemoryPressure()` method exists

**Tasks**:
1. Create mock telemetry reporter class `MockTelemetryReporter` in test target that records captured events
2. Write unit test `testGPUCacheClearTelemetry()` that verifies clearGPUCache() emits 2 events (start and complete)
3. Write unit test `testMemoryPressureReporting()` that verifies reportMemoryPressure() returns valid resident/available memory values
4. Add integration test verification comment explaining how to test with Produciesta CLI (per REQUIREMENTS spec line 174-181)

**Exit criteria**:
- [ ] `MockTelemetryReporter` test helper exists and records events
- [ ] Unit test for GPU cache clear telemetry passes
- [ ] Unit test for memory pressure reporting passes
- [ ] All tests pass: `xcodebuild test -scheme SwiftCompartido -destination 'platform=macOS'` succeeds
- [ ] Integration test instructions documented in test file comments

**Priority**: 2.00 — Leaf node (no dependents), simple test code

---

## Parallelism Structure

**Critical Path**: Sortie 1 → Sortie 2 → Sortie 3 (length: 3 sorties)

**Parallel Execution Groups**:
- **Sequential only** (strict dependency chain):
  - SwiftCompartido Telemetry: Sortie 1 → Sortie 2 → Sortie 3 (Supervising Agent)

**Agent Constraints**:
- **Supervising agent**: Handles all sorties (all have build/test verification steps)
- **Sub-agents**: None (no parallelizable work in this plan)

**Parallelism Metrics**:
- Current: 1 work unit, sequential execution
- Maximum: 1 agent (all sorties require builds)
- Agent allocation: 1 supervising agent + 0 sub-agents

**Build Constraints**: All 3 sorties restricted to supervising agent (build/test steps required)

---

## Open Questions & Missing Documentation

**Status**: ✓ No blocking issues

All criteria are machine-verifiable, all dependencies are standard macOS/iOS frameworks (Metal, mach), and all referenced files either exist or will be created as part of the plan.

---

## Summary

| Metric | Value |
|--------|-------|
| Work units | 1 |
| Total sorties | 3 |
| Dependency structure | sequential |
| Total atomic tasks | 11 |
| Primary file modified | Sources/SwiftCompartido/MemoryManager.swift |
| Test files created | Tests/SwiftCompartidoTests/MemoryManagerTelemetryTests.swift |
