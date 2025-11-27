# Git Library Comparison for GitProject

**Last Updated**: 2025-11-21
**Status**: Recommendation Phase

## Quick Recommendation

**Use SwiftGitX** - Modern, actively maintained, async/await support, SPM compatible

## Detailed Comparison

| Feature | SwiftGitX | gitmeta/git | SwiftGit2 |
|---------|-----------|-------------|-----------|
| **Repository** | [ibrahimcetin/SwiftGitX](https://github.com/ibrahimcetin/SwiftGitX) | [gitmeta/git](https://github.com/gitmeta/git) | [SwiftGit2/SwiftGit2](https://github.com/SwiftGit2/SwiftGit2) |
| **Latest Version** | 0.1.9 (Aug 2025) | Unknown | 0.6.0 (May 2019) |
| **License** | MIT | MIT | MIT |
| **Last Updated** | August 2025 | April 2019 | May 2019 |
| **Maintenance** | ✅ Active | ❌ Unclear | ❌ Stale |
| **Swift Package Manager** | ✅ Yes | ❓ Unknown | ❌ No (Carthage only) |
| **Dependencies** | libgit2 only | ✅ Zero | cmake, libssh2, libtool, autoconf, automake, pkg-config |
| **Async/Await** | ✅ Yes | ❓ Unknown | ❌ No |
| **API Design** | Modern Swift, Git CLI-like | ❓ Unknown | Value-based, immutable |
| **Platform Support** | macOS, iOS | macOS, iOS | macOS (iOS unclear) |
| **Low-Level Exposure** | ❌ No C types | ✅ Pure Swift | Some C exposure |
| **Git LFS Support** | ❌ No (manual) | ❌ No | ❌ No |
| **Contributors** | 3 | Unknown | Multiple |
| **GitHub Stars** | ~50 | ~100 | 684 |
| **Maturity** | ⚠️ Pre-1.0 | ❓ Unknown | ✅ Mature |
| **Known Issues** | API may change | None documented | Missing git push, no SPM |

## Scoring (out of 10)

| Criteria | SwiftGitX | gitmeta/git | SwiftGit2 | Weight |
|----------|-----------|-------------|-----------|--------|
| **Maintenance** | 9 | 2 | 3 | 25% |
| **Modern Swift** | 10 | 5 | 4 | 20% |
| **SPM Support** | 10 | 5 | 0 | 15% |
| **Dependencies** | 8 | 10 | 2 | 10% |
| **Documentation** | 7 | 3 | 8 | 10% |
| **Maturity** | 5 | 4 | 9 | 10% |
| **Community** | 4 | 3 | 7 | 5% |
| **LFS Support** | 0 | 0 | 0 | 5% |
| **Total** | **7.55** | **3.95** | **4.00** | |

## Detailed Analysis

### SwiftGitX ✅ Recommended

**Strengths**:
- **Active Development**: Latest release August 2025, ongoing maintenance
- **Modern Swift**: Full async/await support, no C types exposed
- **Clean API**: Git CLI-like design, intuitive for developers
- **SPM Support**: Easy integration into SwiftCompartido
- **Minimal Dependencies**: Only requires libgit2 (standard C library)

**Weaknesses**:
- **Pre-1.0**: API stability not guaranteed (currently 0.1.9)
- **Small Team**: Only 3 contributors (bus factor concern)
- **No LFS**: Requires custom implementation or shelling out to CLI

**Best For**: New projects prioritizing modern Swift and ongoing maintenance

---

### gitmeta/git ⚠️ Not Recommended

**Strengths**:
- **Zero Dependencies**: Pure Swift implementation
- **iOS/macOS Support**: Native to both platforms
- **App Store Ready**: Already distributed via App Store

**Weaknesses**:
- **Stale Maintenance**: Last commit April 2019 (6+ years)
- **Unknown API**: No public documentation available
- **Unknown Features**: Unclear if it supports modern Swift features
- **Unknown SPM Support**: Not documented

**Best For**: Projects requiring zero dependencies and willing to fork/maintain

---

### SwiftGit2 ⚠️ Not Recommended

**Strengths**:
- **Mature**: Well-tested, widely used in production
- **Good Documentation**: Clear API docs and examples
- **Thread-Safe**: Value-based design prevents concurrency issues

**Weaknesses**:
- **Abandoned**: Last release May 2019 (6+ years)
- **No SPM**: Carthage only (incompatible with SwiftCompartido's SPM workflow)
- **Heavy Dependencies**: Requires 6+ build tools (cmake, libssh2, etc.)
- **Missing Features**: No git push, incomplete API
- **No Async/Await**: Pre-Swift concurrency era

**Best For**: Legacy projects already using Carthage and Swift 5.3

## Git LFS Support Analysis

**Critical Finding**: None of the libraries support Git LFS natively.

### Root Cause
- libgit2 (underlying C library) doesn't support LFS
- libgit2 provides filter APIs (`git_filter_register`) but requires manual implementation
- This is a known pain point that led GitKraken to abandon libgit2 in 2023

### Proposed Solutions

#### Option 1: Shell Out to `git lfs` CLI ✅ Recommended
```swift
func fetchLFS(repoPath: String) async throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["lfs", "pull"]
    process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
    try process.run()
    process.waitUntilExit()
}
```

**Pros**:
- Leverages battle-tested LFS implementation
- Works with all LFS providers (GitHub, GitLab, Bitbucket)
- Simple to implement

**Cons**:
- External dependency on `git lfs` binary
- Difficult to distribute on iOS (would need sideloading)
- Less control over progress reporting

**Verdict**: Best for macOS-first deployment, iOS support delayed

---

#### Option 2: Implement Native Swift LFS
```swift
// Use libgit2 filter API
git_filter_register("lfs", lfsFilter, priority: 100)

// Implement LFS protocol manually
func smudgeFile(pointer: LFSPointer) async throws -> Data {
    let url = lfsServerURL.appendingPathComponent(pointer.oid)
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}
```

**Pros**:
- Full control over LFS operations
- No external dependencies
- Works on iOS without jailbreak
- Better progress reporting

**Cons**:
- High implementation effort (weeks to months)
- Need to implement entire LFS protocol
- Must handle all LFS server variations

**Verdict**: Future enhancement after core Git operations are stable

---

#### Option 3: Hybrid Approach ✅ Recommended for iOS
- **macOS**: Shell out to `git lfs` CLI (most users have Homebrew)
- **iOS**: Implement minimal LFS support for common use cases
- **Both**: Graceful degradation when LFS unavailable

```swift
#if os(macOS)
func fetchLFS() async throws {
    try await shellOutToGitLFS()
}
#else
func fetchLFS() async throws {
    if lfsServerSupportsHTTP {
        try await nativeLFSFetch()
    } else {
        throw GitProjectError.lfsUnsupported
    }
}
#endif
```

## Implementation Roadmap

### Phase 1: Core Git (SwiftGitX)
- [x] Evaluate library candidates
- [ ] Add SwiftGitX dependency to `Package.swift`
- [ ] Implement `GitRepositoryModel` and `GitCommitModel`
- [ ] Build `GitProjectService` with clone, pull, push, commit
- [ ] Write unit tests for Git operations

### Phase 2: macOS LFS (CLI-based)
- [ ] Detect `git lfs` binary availability
- [ ] Implement shell-out wrapper for LFS operations
- [ ] Parse `.gitattributes` for LFS file patterns
- [ ] Integrate with Phase 6 storage (file references)
- [ ] Write integration tests for LFS workflow

### Phase 3: UI Components
- [ ] Build `GitCloneView` for repository cloning
- [ ] Build `GitStatusView` for repository state
- [ ] Build `GitCommitView` for creating commits
- [ ] Add Git controls to `GuionViewer`

### Phase 4: iOS Support
- [ ] Evaluate native LFS implementation feasibility
- [ ] Implement minimal LFS support for common scenarios
- [ ] Test on iOS 26.0+ Simulator (arm64)

## Decision Matrix

| Scenario | Recommendation |
|----------|----------------|
| **macOS-first, need Git now** | SwiftGitX + shell out to `git lfs` |
| **iOS-first, need Git now** | SwiftGitX + defer LFS support |
| **Need LFS on iOS** | Implement native Swift LFS (high effort) |
| **Production-critical** | Wait for SwiftGitX to reach 1.0 |
| **Zero dependencies required** | Fork gitmeta/git and modernize |
| **Legacy Carthage project** | SwiftGit2 (but migrate to SPM soon) |

## References

- [SwiftGitX Repository](https://github.com/ibrahimcetin/SwiftGitX)
- [gitmeta/git Repository](https://github.com/gitmeta/git)
- [SwiftGit2 Repository](https://github.com/SwiftGit2/SwiftGit2)
- [libgit2 Official Site](https://libgit2.org/)
- [Git LFS Protocol](https://github.com/git-lfs/git-lfs/blob/main/docs/api/README.md)
- [GitKraken's libgit2 Migration](https://www.gitkraken.com/blog/gitkraken-client-migrating-from-libgit2-to-git-executable)

## Next Steps

1. Add SwiftGitX to `Package.swift`
2. Create `GitRepositoryModel` and `GitCommitModel` SwiftData models
3. Implement `GitProjectService` with async/await APIs
4. Write comprehensive tests (unit + integration)
5. Build UI components for Git workflows
6. Document usage patterns in `AI-REFERENCE.md`
