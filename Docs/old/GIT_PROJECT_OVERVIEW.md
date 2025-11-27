# GitProject Overview

**Status**: Planning Complete ✅
**Last Updated**: 2025-11-21
**Next Phase**: Implementation

## Quick Start

GitProject adds Git repository integration to SwiftCompartido, enabling screenplay projects to be version-controlled with native Git LFS support for large media files.

## Documentation Index

| Document | Purpose |
|----------|---------|
| **[GIT_PROJECT_REQUIREMENTS.md](GIT_PROJECT_REQUIREMENTS.md)** | Complete requirements, API design, and workflows |
| **[GIT_LIBRARY_COMPARISON.md](GIT_LIBRARY_COMPARISON.md)** | Library evaluation and recommendation (SwiftGitX) |
| **[GIT_PHASE6_INTEGRATION.md](GIT_PHASE6_INTEGRATION.md)** | Integration with SwiftCompartido's storage architecture |
| **[GIT_AUTHENTICATION.md](GIT_AUTHENTICATION.md)** | Automatic credential detection and authentication strategy |

## Key Decisions

### ✅ Recommended Git Library: SwiftGitX

**Repository**: https://github.com/ibrahimcetin/SwiftGitX

**Rationale**:
- Modern async/await API
- Active maintenance (v0.1.9, August 2025)
- Swift Package Manager support
- Zero dependencies beyond libgit2
- Clean Swift API (no C types exposed)

**Score**: 7.55/10 (highest among candidates)

### ✅ Git LFS Strategy: Hybrid Approach

**macOS**: Shell out to `git lfs` CLI
- Most macOS users have Homebrew
- Battle-tested implementation
- Quick to implement

**iOS**: Deferred or native implementation
- Option 1: Defer LFS support on iOS (Phase 1)
- Option 2: Implement native Swift LFS (Phase 4)

**Git LFS files follow Phase 6 pattern**: Always stored as file references, never in-memory

### ✅ Storage Pattern

```
~/Library/Application Support/SwiftCompartido/
├── git-repositories/
│   └── {repoID}/          # Cloned repositories
│       ├── screenplay.fountain
│       └── .git/
└── lfs-files/
    └── {fileID}/          # Downloaded LFS content
        └── audio.mp3
```

- Each repository gets UUID-based folder
- LFS files stored in `TypedDataFileReference` (Phase 6)
- Temporary clones use cache directory
- Cascade delete cleanup on repository removal

### ✅ Authentication Strategy: Zero-Configuration

**Design Principle**: Authentication should "just work" without user setup.

**Automatic credential detection priority**:
1. **SSH Keys** (for `git@` URLs)
   - Automatically detects `~/.ssh/id_ed25519`, `~/.ssh/id_rsa`, etc.
   - No configuration required if keys exist

2. **Environment Tokens** (for HTTPS URLs)
   - `GITHUB_TOKEN` → github.com
   - `GITLAB_TOKEN` → gitlab.com
   - `BITBUCKET_TOKEN` → bitbucket.org
   - `GIT_TOKEN` → fallback for any provider

3. **Git Credential Helpers**
   - Uses macOS `git-credential-osxkeychain` automatically

4. **Keychain Direct Access**
   - Queries macOS Keychain for stored credentials

5. **User Prompt** (last resort)
   - Only if all automatic methods fail
   - Credentials saved to Keychain for future use

**No user configuration required** - GitProject automatically uses whichever method is available.

## Core Features

### Phase 1: Core Git Operations (MVP)
- ✅ Requirements documented
- ✅ Library selected (SwiftGitX)
- 🔲 Clone, pull, push, commit operations
- 🔲 `GitRepositoryModel` and `GitCommitModel` SwiftData models
- 🔲 `GitProjectService` async/await API
- 🔲 Unit and integration tests

### Phase 2: Git LFS Support (macOS)
- ✅ Strategy documented
- 🔲 Shell out to `git lfs` CLI
- 🔲 `.gitattributes` parsing
- 🔲 Phase 6 file reference integration
- 🔲 LFS download progress reporting

### Phase 3: UI Components
- ✅ Designs documented
- 🔲 `GitCloneView` - Clone repositories
- 🔲 `GitStatusView` - Repository state
- 🔲 `GitCommitView` - Commit changes
- 🔲 Integration with `GuionViewer`

### Phase 4: Advanced Features
- 🔲 iOS native LFS support
- 🔲 Merge conflict resolution UI
- 🔲 Branch management UI
- 🔲 Diff visualization

## SwiftData Models

### GitRepositoryModel

```swift
@Model
final class GitRepositoryModel: @unchecked Sendable {
    @Attribute(.unique) var id: UUID
    var localPath: String
    var remoteURL: String?
    var currentBranch: String
    var lastSync: Date?
    var lfsEnabled: Bool

    @Relationship(deleteRule: .nullify) var document: GuionDocumentModel?
    @Relationship(deleteRule: .cascade) var lfsFiles: [TypedDataStorage]
    @Relationship(deleteRule: .cascade) var commits: [GitCommitModel]
}
```

### GitCommitModel

```swift
@Model
final class GitCommitModel: @unchecked Sendable {
    @Attribute(.unique) var sha: String
    var message: String
    var authorName: String
    var authorEmail: String
    var timestamp: Date

    @Relationship(deleteRule: .nullify) var repository: GitRepositoryModel?
}
```

## API Design

### GitProjectService

```swift
@MainActor
final class GitProjectService {
    /// Clone repository with progress reporting
    func clone(
        remoteURL: String,
        localPath: String,
        progress: @escaping (Double, String) -> Void
    ) async throws -> GitRepositoryModel

    /// Pull latest changes
    func pull(
        repository: GitRepositoryModel,
        progress: @escaping (Double, String) -> Void
    ) async throws

    /// Push local commits
    func push(
        repository: GitRepositoryModel,
        progress: @escaping (Double, String) -> Void
    ) async throws

    /// Create commit
    func commit(
        repository: GitRepositoryModel,
        message: String
    ) async throws -> GitCommitModel

    /// Fetch LFS files (macOS only in Phase 2)
    func fetchLFS(
        repository: GitRepositoryModel,
        progress: @escaping (Double, String) -> Void
    ) async throws

    /// Get repository status
    func status(
        repository: GitRepositoryModel
    ) async throws -> RepositoryStatus
}
```

## Example Workflows

### Clone Repository (Automatic Authentication)

```swift
let service = GitProjectService(modelContext: modelContext)

// Authentication happens automatically - no credential setup needed!
// GitProject will:
// 1. Check for GITHUB_TOKEN environment variable
// 2. Check for SSH keys in ~/.ssh/
// 3. Query git credential helper
// 4. Check macOS Keychain
// 5. Prompt user only if all else fails

let repository = try await service.clone(
    remoteURL: "https://github.com/user/screenplay.git",
    localPath: storage.folderURL.path
) { progress, message in
    print("\(Int(progress * 100))%: \(message)")
}

// Repository saved to SwiftData automatically
```

### Commit Changes

```swift
// Export document to Git format
try await document.exportToGit(repository: repository)

// Commit changes
let commit = try await service.commit(
    repository: repository,
    message: "Updated Act 2 dialogue"
)

// Push to remote
try await service.push(repository: repository) { progress, message in
    print("Pushing: \(Int(progress * 100))%")
}
```

### Import with LFS

```swift
let document = try await service.importDocument(
    repository: repository
)

// LFS files downloaded on-demand
for element in document.sortedElements {
    if let audio = element.generatedAudio {
        // Audio already available via file reference
        playAudio(audio.fileReference.url)
    }
}
```

## Default LFS File Patterns

```gitattributes
# Audio files
*.mp3 filter=lfs diff=lfs merge=lfs -text
*.wav filter=lfs diff=lfs merge=lfs -text
*.aac filter=lfs diff=lfs merge=lfs -text
*.m4a filter=lfs diff=lfs merge=lfs -text

# Image files
*.png filter=lfs diff=lfs merge=lfs -text
*.jpg filter=lfs diff=lfs merge=lfs -text

# Video files
*.mp4 filter=lfs diff=lfs merge=lfs -text
*.mov filter=lfs diff=lfs merge=lfs -text

# PDF files
*.pdf filter=lfs diff=lfs merge=lfs -text
```

## Optional: Setting Up Environment Tokens

While GitProject works without configuration, you can optionally set up environment tokens for seamless private repository access:

### GitHub
```bash
# Generate token: https://github.com/settings/tokens
export GITHUB_TOKEN="ghp_your_token_here"

# Make permanent (add to ~/.zshrc)
echo 'export GITHUB_TOKEN="ghp_your_token_here"' >> ~/.zshrc
```

### GitLab
```bash
# Generate token: https://gitlab.com/-/profile/personal_access_tokens
export GITLAB_TOKEN="glpat_your_token_here"
echo 'export GITLAB_TOKEN="glpat_your_token_here"' >> ~/.zshrc
```

### Bitbucket
```bash
# Generate app password: https://bitbucket.org/account/settings/app-passwords/
export BITBUCKET_TOKEN="your_app_password_here"
echo 'export BITBUCKET_TOKEN="your_app_password_here"' >> ~/.zshrc
```

### SSH (Recommended)
```bash
# Generate Ed25519 key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key and add to GitHub/GitLab/Bitbucket
pbcopy < ~/.ssh/id_ed25519.pub
```

**Once configured, GitProject uses these credentials automatically - no further action needed!**

## Implementation Roadmap

### Week 1-2: Core Git
- [ ] Add SwiftGitX dependency
- [ ] Implement `GitRepositoryModel`, `GitCommitModel`
- [ ] Build `GitProjectService` (clone, pull, push, commit)
- [ ] Write 50+ unit tests

### Week 3-4: LFS Support
- [ ] Implement macOS LFS via CLI
- [ ] Parse `.gitattributes`
- [ ] Integrate with Phase 6 storage
- [ ] Write 20+ LFS integration tests

### Week 5-6: UI Components
- [ ] Build `GitCloneView`
- [ ] Build `GitStatusView`
- [ ] Build `GitCommitView`
- [ ] Add Git controls to `GuionViewer`

### Future: Advanced Features
- [ ] iOS native LFS (if feasible)
- [ ] Merge conflict UI
- [ ] Branch management
- [ ] Visual diff viewer

## Known Limitations

1. **iOS LFS**: Deferred until native implementation (Phase 4)
2. **Pre-1.0 Library**: SwiftGitX API may change before 1.0 release
3. **macOS LFS Dependency**: Requires `git lfs` CLI installed (Homebrew)
4. **No Visual Merge**: Merge conflicts shown as raw text initially
5. **Large Repos**: Cloning 100+ MB repositories may be slow on slow connections

## Performance Targets

- Clone 10 MB repository: < 5 seconds
- Clone 100 MB repository: < 30 seconds
- LFS download (10 files, 50 MB total): < 10 seconds
- Commit 100 files: < 2 seconds
- Push 10 commits: < 5 seconds

All operations must be async and non-blocking.

## Security Considerations

- ✅ Automatic credential detection (SSH keys, environment tokens, Keychain)
- ✅ Secure Keychain storage (NEVER SwiftData or UserDefaults)
- ✅ Token sanitization in logs (credentials never exposed in error messages)
- ✅ SSH key permission validation (0600 for private keys)
- ✅ Support for all major Git providers (GitHub, GitLab, Bitbucket, Azure DevOps)
- ✅ Path validation (prevent directory traversal)
- ✅ URL validation (prevent SSRF attacks)
- ✅ File size limits (500 MB max LFS file)
- ✅ Repository size warnings (100 MB+ repos)

## Testing Requirements

- **Minimum 90% coverage** (consistent with SwiftCompartido standards)
- **50+ unit tests** for Git operations
- **20+ integration tests** for LFS workflows
- **10+ UI tests** for Git components
- **Performance tests** for large repositories

## Next Steps

1. **Review documentation** - Read all three docs thoroughly
2. **Add SwiftGitX** - Update `Package.swift`
3. **Implement models** - Start with `GitRepositoryModel`
4. **Build service** - Implement `GitProjectService` core operations
5. **Write tests** - Aim for 90%+ coverage from day 1
6. **Build UI** - After service layer is stable

## Questions & Answers

### Why SwiftGitX over SwiftGit2?
- SwiftGit2 unmaintained since 2019
- SwiftGitX has async/await and SPM support
- SwiftGitX actively maintained (August 2025)

### Why not pure Swift (gitmeta/git)?
- Unclear maintenance status (last commit 2019)
- No public API documentation
- Unknown Swift concurrency support

### Why shell out for LFS instead of native?
- libgit2 doesn't support LFS natively
- CLI is battle-tested and works everywhere
- Native implementation is high effort (weeks)
- Can revisit in Phase 4 for iOS

### How does this integrate with Phase 6?
- Git repos stored in `StorageAreaReference.persistent`
- LFS files use `TypedDataFileReference` (file pointers)
- No in-memory buffering of large files
- Cascade delete cleanup on repository removal

### What about merge conflicts?
- Phase 1: Show raw conflict markers
- Phase 4: Build visual conflict resolution UI
- Auto-resolution strategies (ours/theirs) available

## Resources

- **SwiftGitX**: https://github.com/ibrahimcetin/SwiftGitX
- **libgit2 docs**: https://libgit2.org/docs/
- **Git LFS spec**: https://github.com/git-lfs/git-lfs/tree/main/docs/spec
- **Phase 6 architecture**: `CLAUDE.md`
- **SwiftCompartido API**: `AI-REFERENCE.md`

---

**Ready to implement?** Start with `GIT_PROJECT_REQUIREMENTS.md` for detailed specifications.
