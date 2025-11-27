# GitProject Quick Start Guide

**For Developers**: How to use GitProject with SwiftCompartido
**Last Updated**: 2025-11-21

## TL;DR

GitProject adds Git repository integration to SwiftCompartido with **zero-configuration authentication**. Just set environment variables or use SSH keys - no other setup required.

## Authentication (Choose One)

### Option 1: SSH Keys (Recommended)

```bash
# Generate Ed25519 key (if you don't have one)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key
pbcopy < ~/.ssh/id_ed25519.pub

# Add to GitHub: https://github.com/settings/keys
# Add to GitLab: https://gitlab.com/-/profile/keys
# Add to Bitbucket: https://bitbucket.org/account/settings/ssh-keys/
```

**Done!** GitProject will automatically use your SSH key for `git@` URLs.

### Option 2: Environment Tokens

```bash
# GitHub
export GITHUB_TOKEN="ghp_your_token_here"

# GitLab
export GITLAB_TOKEN="glpat_your_token_here"

# Bitbucket
export BITBUCKET_TOKEN="your_app_password_here"

# Make permanent
echo 'export GITHUB_TOKEN="ghp_your_token_here"' >> ~/.zshrc
source ~/.zshrc
```

**Generate tokens**:
- GitHub: https://github.com/settings/tokens (scopes: `repo`, `read:user`)
- GitLab: https://gitlab.com/-/profile/personal_access_tokens (scopes: `read_repository`, `write_repository`)
- Bitbucket: https://bitbucket.org/account/settings/app-passwords/ (permissions: Repositories - Read/Write)

**Done!** GitProject will automatically use tokens for HTTPS URLs.

### Option 3: Do Nothing

If you already use Git on your Mac, GitProject will automatically use:
- Your existing SSH keys from `~/.ssh/`
- Your git credential helper (`git-credential-osxkeychain`)
- Credentials stored in macOS Keychain

**No setup required!**

## Basic Usage

### Clone a Repository

```swift
import SwiftCompartido
import SwiftData

@MainActor
func cloneScreenplay() async throws {
    let service = GitProjectService(modelContext: modelContext)

    // Clone (authentication happens automatically)
    let repository = try await service.clone(
        remoteURL: "https://github.com/user/my-screenplay.git",
        localPath: "/path/to/local/repo"
    ) { progress, message in
        print("\(Int(progress * 100))%: \(message)")
    }

    // Import screenplay to SwiftData
    let document = try await service.importDocument(repository: repository)

    print("Screenplay imported: \(document.title ?? "Untitled")")
}
```

### Commit and Push Changes

```swift
@MainActor
func saveChanges(document: GuionDocumentModel, message: String) async throws {
    guard let repository = document.gitRepository else {
        throw GitProjectError.notGitTracked
    }

    let service = GitProjectService(modelContext: modelContext)

    // Export document to Git format
    try await document.exportToGit(repository: repository)

    // Commit changes
    let commit = try await service.commit(
        repository: repository,
        message: message
    )

    // Push to remote (authentication happens automatically)
    try await service.push(repository: repository) { progress, message in
        print("Pushing: \(Int(progress * 100))%")
    }

    print("Changes pushed: \(commit.sha)")
}
```

### Pull Latest Changes

```swift
@MainActor
func syncChanges(repository: GitRepositoryModel) async throws {
    let service = GitProjectService(modelContext: modelContext)

    // Pull latest (authentication happens automatically)
    try await service.pull(repository: repository) { progress, message in
        print("Pulling: \(Int(progress * 100))%")
    }

    print("Repository updated")
}
```

## Supported Providers

GitProject automatically detects and authenticates with:

| Provider | Environment Variable | URL Pattern |
|----------|---------------------|-------------|
| **GitHub** | `GITHUB_TOKEN` | `github.com` |
| **GitLab** | `GITLAB_TOKEN` | `gitlab.com` |
| **Bitbucket** | `BITBUCKET_TOKEN` | `bitbucket.org` |
| **Azure DevOps** | `AZURE_DEVOPS_TOKEN` | `dev.azure.com` |
| **Generic** | `GIT_TOKEN` | Any domain |

## Authentication Priority

When accessing a Git repository, GitProject tries methods in this order:

1. **SSH Keys** (for `git@` URLs)
   - `~/.ssh/id_ed25519` (preferred)
   - `~/.ssh/id_rsa`
   - `~/.ssh/id_ecdsa`

2. **Environment Tokens** (for HTTPS URLs)
   - Provider-specific: `GITHUB_TOKEN`, `GITLAB_TOKEN`, etc.
   - Generic fallback: `GIT_TOKEN`

3. **Git Credential Helper**
   - `git-credential-osxkeychain` (macOS default)

4. **macOS Keychain**
   - Direct query for stored credentials

5. **User Prompt**
   - Only if all else fails
   - Credentials saved to Keychain

## Troubleshooting

### "Authentication failed"

**Check environment token**:
```bash
echo $GITHUB_TOKEN
# Should output: ghp_abc123...
```

**Check SSH key**:
```bash
ls -la ~/.ssh/
# Look for id_ed25519 or id_rsa

ssh -T git@github.com
# Should output: Hi username! You've successfully authenticated...
```

### "No SSH key found"

Generate a new SSH key:
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
ssh-add ~/.ssh/id_ed25519
```

### "Token invalid or expired"

Regenerate your token and update the environment variable:
```bash
# Update token
export GITHUB_TOKEN="ghp_new_token_here"

# Make permanent
echo 'export GITHUB_TOKEN="ghp_new_token_here"' >> ~/.zshrc
```

### Check credential status programmatically

```swift
let checker = EnvironmentTokenChecker()
checker.showTokenStatus()

// Output:
// Git Token Status:
//   GitHub: ✅
//   GitLab: ❌
//   Bitbucket: ❌
//   Azure DevOps: ❌
//   Generic: ❌
```

## Security Best Practices

### ✅ DO

- Use SSH keys for personal development
- Use environment tokens for CI/CD and automation
- Store tokens in environment variables or Keychain
- Use fine-grained tokens with minimal scopes
- Rotate tokens regularly

### ❌ DON'T

- Hardcode tokens in source code
- Store tokens in UserDefaults or SwiftData
- Share tokens between projects (use separate tokens)
- Commit tokens to Git repositories
- Use tokens with excessive permissions

## Advanced: Custom Credential Handling

If you need custom authentication logic:

```swift
@MainActor
final class CustomGitCredentialManager: GitCredentialManager {
    override func getCredentials(for url: String) async throws -> GitCredentials {
        // Custom logic here
        if url.contains("my-custom-git-server.com") {
            return .https(
                url: injectCustomToken(into: url),
                token: getCustomToken()
            )
        }

        // Fall back to default behavior
        return try await super.getCredentials(for: url)
    }
}
```

## Git LFS Support

GitProject automatically handles Git LFS files:

```swift
// Clone repository with LFS files
let repository = try await service.clone(
    remoteURL: "https://github.com/user/screenplay-with-audio.git",
    localPath: "/path/to/repo"
)

// LFS files are automatically detected and downloaded
// Audio files stored as file references (Phase 6 architecture)
for element in document.sortedElements {
    if let audio = element.generatedAudio {
        // Audio already available via file reference
        playAudio(from: audio.fileReference.url)
    }
}
```

**Requirements**:
- macOS: `git lfs` installed (`brew install git-lfs`)
- iOS: Native LFS support (future enhancement)

## Complete Documentation

For detailed information, see:

- **[GIT_PROJECT_OVERVIEW.md](GIT_PROJECT_OVERVIEW.md)** - High-level overview
- **[GIT_AUTHENTICATION.md](GIT_AUTHENTICATION.md)** - Complete authentication guide
- **[GIT_PROJECT_REQUIREMENTS.md](GIT_PROJECT_REQUIREMENTS.md)** - Full specifications
- **[GIT_LIBRARY_COMPARISON.md](GIT_LIBRARY_COMPARISON.md)** - Library evaluation
- **[GIT_PHASE6_INTEGRATION.md](GIT_PHASE6_INTEGRATION.md)** - Architecture integration

## Example: Full Workflow

```swift
import SwiftCompartido
import SwiftData

@MainActor
class ScreenplayGitManager {
    let modelContext: ModelContext
    let service: GitProjectService

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.service = GitProjectService(modelContext: modelContext)
    }

    // 1. Clone repository
    func cloneScreenplay(from url: String) async throws -> GuionDocumentModel {
        let repository = try await service.clone(
            remoteURL: url,
            localPath: createLocalPath()
        ) { progress, message in
            print("\(Int(progress * 100))%: \(message)")
        }

        let document = try await service.importDocument(repository: repository)
        return document
    }

    // 2. Make changes
    func updateDialogue(document: GuionDocumentModel, element: GuionElementModel, newText: String) {
        element.elementText = newText
        try? modelContext.save()
    }

    // 3. Commit and push
    func saveToGit(document: GuionDocumentModel, message: String) async throws {
        guard let repository = document.gitRepository else {
            throw GitProjectError.notGitTracked
        }

        try await document.exportToGit(repository: repository)

        let commit = try await service.commit(
            repository: repository,
            message: message
        )

        try await service.push(repository: repository) { progress, msg in
            print("Push: \(Int(progress * 100))%")
        }

        print("Saved: \(commit.sha)")
    }

    // 4. Pull updates
    func syncFromGit(document: GuionDocumentModel) async throws {
        guard let repository = document.gitRepository else { return }

        try await service.pull(repository: repository) { progress, message in
            print("Pull: \(Int(progress * 100))%")
        }

        // Re-import document to pick up changes
        let updated = try await service.importDocument(repository: repository)
        document.elements = updated.elements
    }

    private func createLocalPath() -> String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let repoPath = base.appendingPathComponent("git-repositories/\(UUID())")
        return repoPath.path
    }
}

// Usage
let manager = ScreenplayGitManager(modelContext: modelContext)

// Clone
let document = try await manager.cloneScreenplay(from: "https://github.com/user/screenplay.git")

// Edit
manager.updateDialogue(document: document, element: document.sortedElements[0], newText: "New dialogue")

// Save
try await manager.saveToGit(document: document, message: "Updated Act 1 dialogue")

// Sync
try await manager.syncFromGit(document: document)
```

## Questions?

See the complete documentation in `Docs/`:
- Authentication issues → `GIT_AUTHENTICATION.md`
- Architecture questions → `GIT_PHASE6_INTEGRATION.md`
- Feature requests → `GIT_PROJECT_REQUIREMENTS.md`
