# GitProject Authentication Strategy

**Last Updated**: 2025-11-21
**Status**: Design Phase
**Priority**: Critical - Must be seamless and automatic

## Overview

GitProject provides **zero-configuration authentication** by automatically detecting and using credentials from:
1. Environment variables (`GITHUB_TOKEN`, `GITLAB_TOKEN`, etc.)
2. SSH keys (`~/.ssh/id_rsa`, `~/.ssh/id_ed25519`, etc.)
3. Git credential helpers (macOS Keychain, git-credential-osxkeychain)
4. Interactive prompts (last resort)

**Design Principle**: No muss, no fuss - authentication should "just work" without user configuration.

## Authentication Priority Order

When accessing a Git repository, GitProject follows this priority order:

```mermaid
flowchart TD
    Start([Git Operation]) --> DetectURL{URL Type?}

    DetectURL -->|SSH URL| SSHFlow[SSH Authentication Flow]
    DetectURL -->|HTTPS URL| HTTPSFlow[HTTPS Authentication Flow]

    SSHFlow --> CheckSSHKey{SSH Key Exists?}
    CheckSSHKey -->|Yes| UseSSHKey[Use SSH Key]
    CheckSSHKey -->|No| ErrorNoSSH[Error: No SSH Key]
    UseSSHKey --> Success([Authenticated])

    HTTPSFlow --> CheckEnvToken{Provider Token<br/>in Environment?}
    CheckEnvToken -->|Yes| UseEnvToken[Use Token from Environment]
    CheckEnvToken -->|No| CheckGitCred

    UseEnvToken --> InjectToken[Inject into HTTPS URL]
    InjectToken --> Success

    CheckGitCred{Git Credential<br/>Helper Available?}
    CheckGitCred -->|Yes| UseGitCred[Query git-credential-osxkeychain]
    CheckGitCred -->|No| CheckKeychain

    UseGitCred --> Success

    CheckKeychain{Keychain<br/>Has Credentials?}
    CheckKeychain -->|Yes| UseKeychain[Use Keychain Credentials]
    CheckKeychain -->|No| PromptUser

    UseKeychain --> Success

    PromptUser[Prompt User for Credentials]
    PromptUser --> SaveKeychain[Save to Keychain]
    SaveKeychain --> Success
```

### Priority Levels

1. **SSH Keys** (for `git@` URLs)
   - `~/.ssh/id_ed25519` (preferred)
   - `~/.ssh/id_rsa`
   - `~/.ssh/id_ecdsa`
   - Custom keys via `SSH_AUTH_SOCK`

2. **Environment Tokens** (for HTTPS URLs)
   - `GITHUB_TOKEN` → github.com
   - `GITLAB_TOKEN` → gitlab.com
   - `BITBUCKET_TOKEN` → bitbucket.org
   - `GIT_TOKEN` → fallback for any provider

3. **Git Credential Helpers**
   - `git-credential-osxkeychain` (macOS)
   - `git-credential-manager` (cross-platform)

4. **macOS Keychain Direct**
   - Query Keychain for stored Git credentials
   - Use `Security` framework

5. **Interactive Prompt**
   - Only if all else fails
   - Save to Keychain for future use

## Environment Variable Detection

### Supported Providers

| Provider | Environment Variable | URL Pattern | Notes |
|----------|---------------------|-------------|-------|
| **GitHub** | `GITHUB_TOKEN` | `github.com` | Personal access tokens or GitHub App tokens |
| **GitLab** | `GITLAB_TOKEN` | `gitlab.com` | Project/group access tokens |
| **Bitbucket** | `BITBUCKET_TOKEN` | `bitbucket.org` | App passwords |
| **Gitea** | `GITEA_TOKEN` | Custom domain | Self-hosted Git service |
| **Azure DevOps** | `AZURE_DEVOPS_TOKEN` | `dev.azure.com` | Personal access tokens |
| **Generic** | `GIT_TOKEN` | Any domain | Fallback for unlisted providers |

### Token Detection Logic

```swift
enum GitProvider {
    case github
    case gitlab
    case bitbucket
    case azureDevOps
    case gitea(domain: String)
    case generic

    var tokenEnvironmentVariable: String {
        switch self {
        case .github: return "GITHUB_TOKEN"
        case .gitlab: return "GITLAB_TOKEN"
        case .bitbucket: return "BITBUCKET_TOKEN"
        case .azureDevOps: return "AZURE_DEVOPS_TOKEN"
        case .gitea: return "GITEA_TOKEN"
        case .generic: return "GIT_TOKEN"
        }
    }

    static func detect(from url: String) -> GitProvider {
        if url.contains("github.com") { return .github }
        if url.contains("gitlab.com") { return .gitlab }
        if url.contains("bitbucket.org") { return .bitbucket }
        if url.contains("dev.azure.com") { return .azureDevOps }
        return .generic
    }
}

struct EnvironmentCredentialProvider {
    func getToken(for url: String) -> String? {
        let provider = GitProvider.detect(from: url)

        // Try provider-specific token first
        if let token = ProcessInfo.processInfo.environment[provider.tokenEnvironmentVariable] {
            return token
        }

        // Fall back to generic GIT_TOKEN
        if let token = ProcessInfo.processInfo.environment["GIT_TOKEN"] {
            return token
        }

        return nil
    }
}
```

### HTTPS URL Rewriting

When a token is available, rewrite HTTPS URLs to include authentication:

```swift
func injectToken(_ token: String, into url: String) -> String {
    // Input: https://github.com/user/repo.git
    // Output: https://x-access-token:TOKEN@github.com/user/repo.git

    guard let urlComponents = URLComponents(string: url) else {
        return url
    }

    var components = urlComponents

    // GitHub uses 'x-access-token' as username
    if url.contains("github.com") {
        components.user = "x-access-token"
        components.password = token
    }
    // GitLab uses 'oauth2' as username
    else if url.contains("gitlab.com") {
        components.user = "oauth2"
        components.password = token
    }
    // Bitbucket uses username from token metadata
    else if url.contains("bitbucket.org") {
        components.user = "x-token-auth"
        components.password = token
    }
    // Generic: just use token as password
    else {
        components.user = "git"
        components.password = token
    }

    return components.string ?? url
}
```

**Example transformations**:
```
# GitHub
https://github.com/user/repo.git
→ https://x-access-token:ghp_abc123@github.com/user/repo.git

# GitLab
https://gitlab.com/user/repo.git
→ https://oauth2:glpat-xyz789@gitlab.com/user/repo.git

# Bitbucket
https://bitbucket.org/user/repo.git
→ https://x-token-auth:BBTK_abc123@bitbucket.org/user/repo.git
```

## SSH Key Detection

### Standard SSH Key Locations

```swift
struct SSHKeyProvider {
    private let fileManager = FileManager.default
    private let homeDirectory = NSHomeDirectory()

    func findSSHKey() -> URL? {
        let sshDir = URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".ssh")

        // Priority order: Ed25519 > RSA > ECDSA
        let keyPaths = [
            "id_ed25519",      // Modern, recommended
            "id_rsa",          // Traditional
            "id_ecdsa",        // Alternative
            "id_dsa"           // Legacy (discouraged)
        ]

        for keyPath in keyPaths {
            let keyURL = sshDir.appendingPathComponent(keyPath)
            if fileManager.fileExists(atPath: keyURL.path) {
                return keyURL
            }
        }

        return nil
    }

    func hasSSHKey() -> Bool {
        findSSHKey() != nil
    }
}
```

### SSH Agent Integration

Use `SSH_AUTH_SOCK` for SSH agent forwarding:

```swift
func useSSHAgent() -> Bool {
    guard let agentSocket = ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"] else {
        return false
    }

    // Verify agent is running
    let agentURL = URL(fileURLWithPath: agentSocket)
    return FileManager.default.fileExists(atPath: agentURL.path)
}
```

### SSH Key Passphrase Handling

```swift
func unlockSSHKey(keyPath: URL) async throws -> String? {
    // Try SSH agent first (no passphrase needed)
    if useSSHAgent() {
        return nil  // Agent handles key
    }

    // Check if key is encrypted
    let keyData = try Data(contentsOf: keyPath)
    let keyString = String(data: keyData, encoding: .utf8) ?? ""

    guard keyString.contains("ENCRYPTED") else {
        return nil  // No passphrase needed
    }

    // Try Keychain first
    if let passphrase = try? retrieveSSHPassphrase(for: keyPath) {
        return passphrase
    }

    // Prompt user
    let passphrase = await promptForSSHPassphrase(keyPath: keyPath)

    // Save to Keychain
    try? saveSSHPassphrase(passphrase, for: keyPath)

    return passphrase
}
```

## Git Credential Helper Integration

Use macOS built-in git credential helper:

```swift
struct GitCredentialHelper {
    func getCredentials(for url: String) async throws -> (username: String, password: String)? {
        // Use git-credential-osxkeychain on macOS
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["credential", "fill"]

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe

        // Write credential request
        let input = "protocol=https\nhost=\(extractHost(from: url))\n\n"
        inputPipe.fileHandleForWriting.write(input.data(using: .utf8)!)
        inputPipe.fileHandleForWriting.closeFile()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }

        // Parse output
        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let outputString = String(data: output, encoding: .utf8) ?? ""

        return parseCredentialOutput(outputString)
    }

    func saveCredentials(url: String, username: String, password: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["credential", "approve"]

        let inputPipe = Pipe()
        process.standardInput = inputPipe

        let input = """
        protocol=https
        host=\(extractHost(from: url))
        username=\(username)
        password=\(password)

        """
        inputPipe.fileHandleForWriting.write(input.data(using: .utf8)!)
        inputPipe.fileHandleForWriting.closeFile()

        try process.run()
        process.waitUntilExit()
    }
}
```

## Keychain Integration

### Direct Keychain Access (macOS)

```swift
import Security

struct KeychainCredentialProvider {
    func getCredentials(for url: String) throws -> (username: String, password: String)? {
        let host = extractHost(from: url)

        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: host,
            kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let existingItem = item as? [String: Any],
              let passwordData = existingItem[kSecValueData as String] as? Data,
              let password = String(data: passwordData, encoding: .utf8),
              let username = existingItem[kSecAttrAccount as String] as? String else {
            return nil
        }

        return (username, password)
    }

    func saveCredentials(url: String, username: String, password: String) throws {
        let host = extractHost(from: url)

        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: host,
            kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
            kSecAttrAccount as String: username,
            kSecValueData as String: password.data(using: .utf8)!,
            kSecAttrLabel as String: "Git: \(host)"
        ]

        // Delete existing item (if any)
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
}
```

## Unified Credential Manager

### GitCredentialManager

```swift
@MainActor
final class GitCredentialManager: @unchecked Sendable {
    private let environmentProvider = EnvironmentCredentialProvider()
    private let sshKeyProvider = SSHKeyProvider()
    private let gitCredentialHelper = GitCredentialHelper()
    private let keychainProvider = KeychainCredentialProvider()

    /// Automatically detect and return appropriate credentials for URL
    func getCredentials(for url: String) async throws -> GitCredentials {
        // 1. Check if SSH URL
        if url.hasPrefix("git@") || url.hasPrefix("ssh://") {
            return try await getSSHCredentials()
        }

        // 2. HTTPS URL - try environment tokens first
        if let token = environmentProvider.getToken(for: url) {
            let authenticatedURL = injectToken(token, into: url)
            return .https(url: authenticatedURL, token: token)
        }

        // 3. Try git credential helper
        if let (username, password) = try? await gitCredentialHelper.getCredentials(for: url) {
            let authenticatedURL = injectUsernamePassword(username: username, password: password, into: url)
            return .https(url: authenticatedURL, token: password)
        }

        // 4. Try Keychain directly
        if let (username, password) = try? keychainProvider.getCredentials(for: url) {
            let authenticatedURL = injectUsernamePassword(username: username, password: password, into: url)
            return .https(url: authenticatedURL, token: password)
        }

        // 5. Last resort: prompt user
        return try await promptForCredentials(url: url)
    }

    private func getSSHCredentials() async throws -> GitCredentials {
        guard let keyPath = sshKeyProvider.findSSHKey() else {
            throw GitAuthError.noSSHKeyFound
        }

        let passphrase = try await unlockSSHKey(keyPath: keyPath)

        return .ssh(keyPath: keyPath, passphrase: passphrase)
    }

    private func promptForCredentials(url: String) async throws -> GitCredentials {
        // Show UI prompt for username/password or token
        let credentials = await showCredentialPrompt(for: url)

        // Save to Keychain and git credential helper
        try? await gitCredentialHelper.saveCredentials(
            url: url,
            username: credentials.username,
            password: credentials.password
        )
        try? keychainProvider.saveCredentials(
            url: url,
            username: credentials.username,
            password: credentials.password
        )

        let authenticatedURL = injectUsernamePassword(
            username: credentials.username,
            password: credentials.password,
            into: url
        )

        return .https(url: authenticatedURL, token: credentials.password)
    }
}

enum GitCredentials {
    case ssh(keyPath: URL, passphrase: String?)
    case https(url: String, token: String)
}

enum GitAuthError: Error {
    case noSSHKeyFound
    case noCredentialsAvailable
    case keychainAccessDenied
    case invalidToken
}
```

## Usage in GitProjectService

### Automatic Authentication

```swift
@MainActor
final class GitProjectService {
    private let credentialManager = GitCredentialManager()

    func clone(
        remoteURL: String,
        localPath: String,
        progress: @escaping (Double, String) -> Void
    ) async throws -> GitRepositoryModel {
        // Automatically get credentials
        let credentials = try await credentialManager.getCredentials(for: remoteURL)

        // Use credentials with SwiftGitX
        let repository: Repository

        switch credentials {
        case .ssh(let keyPath, let passphrase):
            repository = try await cloneWithSSH(
                url: remoteURL,
                keyPath: keyPath,
                passphrase: passphrase,
                to: localPath,
                progress: progress
            )

        case .https(let authenticatedURL, _):
            repository = try await cloneWithHTTPS(
                url: authenticatedURL,
                to: localPath,
                progress: progress
            )
        }

        // Create SwiftData model
        let model = GitRepositoryModel(
            localPath: localPath,
            remoteURL: remoteURL
        )

        return model
    }
}
```

## Environment Variable Configuration

### Setting Up Tokens

Users can set tokens in their shell profile:

**~/.zshrc or ~/.bashrc**:
```bash
# GitHub
export GITHUB_TOKEN="ghp_abc123def456ghi789"

# GitLab
export GITLAB_TOKEN="glpat-xyz789abc123def456"

# Bitbucket
export BITBUCKET_TOKEN="BBTK_abc123def456"

# Generic fallback
export GIT_TOKEN="generic_token_for_self_hosted"
```

### Detecting Token Availability

```swift
struct EnvironmentTokenChecker {
    func checkAvailableTokens() -> [GitProvider: Bool] {
        let providers: [GitProvider] = [.github, .gitlab, .bitbucket, .azureDevOps, .generic]
        var availability: [GitProvider: Bool] = [:]

        for provider in providers {
            let hasToken = ProcessInfo.processInfo.environment[provider.tokenEnvironmentVariable] != nil
            availability[provider] = hasToken
        }

        return availability
    }

    func showTokenStatus() {
        let tokens = checkAvailableTokens()

        print("Git Token Status:")
        print("  GitHub: \(tokens[.github]! ? "✅" : "❌")")
        print("  GitLab: \(tokens[.gitlab]! ? "✅" : "❌")")
        print("  Bitbucket: \(tokens[.bitbucket]! ? "✅" : "❌")")
        print("  Azure DevOps: \(tokens[.azureDevOps]! ? "✅" : "❌")")
        print("  Generic: \(tokens[.generic]! ? "✅" : "❌")")
    }
}
```

## Security Considerations

### Token Storage

**❌ NEVER store tokens in**:
- SwiftData models
- UserDefaults
- Plain text files
- Git repositories

**✅ ALWAYS store tokens in**:
- Environment variables (runtime only)
- macOS Keychain (persistent)
- Git credential helpers

### Token Visibility

```swift
// Sanitize URLs in logs - never expose tokens
func sanitizeURL(_ url: String) -> String {
    var sanitized = url

    // Remove embedded credentials
    if let range = sanitized.range(of: #"://[^@]+@"#, options: .regularExpression) {
        sanitized.replaceSubrange(range, with: "://***@")
    }

    return sanitized
}

// Example:
// Input:  https://x-access-token:ghp_abc123@github.com/user/repo.git
// Output: https://***@github.com/user/repo.git
```

### SSH Key Permissions

Validate SSH key file permissions:

```swift
func validateSSHKeyPermissions(keyPath: URL) throws {
    let attributes = try FileManager.default.attributesOfItem(atPath: keyPath.path)
    let permissions = attributes[.posixPermissions] as? NSNumber

    // SSH keys should be 0600 (read/write owner only)
    if permissions?.intValue != 0o600 {
        throw GitAuthError.insecureSSHKeyPermissions
    }
}
```

## Error Handling

### Authentication Failure Flow

```swift
func handleAuthenticationError(_ error: Error, for url: String) async throws -> GitCredentials {
    switch error {
    case GitAuthError.noSSHKeyFound:
        // Offer to generate SSH key or switch to HTTPS
        let action = await promptUserAction(
            message: "No SSH key found. Generate new key or use HTTPS?"
        )

        if action == .generateKey {
            let keyPath = try await generateSSHKey()
            return .ssh(keyPath: keyPath, passphrase: nil)
        } else {
            // Convert to HTTPS and retry
            let httpsURL = convertToHTTPS(url)
            return try await credentialManager.getCredentials(for: httpsURL)
        }

    case GitAuthError.invalidToken:
        // Token expired or invalid - prompt for new one
        showAlert("Git token invalid or expired. Please provide new credentials.")
        return try await promptForCredentials(url: url)

    case GitAuthError.keychainAccessDenied:
        // User denied Keychain access - try environment or prompt
        if let token = environmentProvider.getToken(for: url) {
            return .https(url: injectToken(token, into: url), token: token)
        }
        return try await promptForCredentials(url: url)

    default:
        throw error
    }
}
```

## Testing Strategy

### Unit Tests

```swift
@Test("Environment token detection for GitHub")
func testGitHubTokenDetection() async throws {
    setenv("GITHUB_TOKEN", "ghp_test123", 1)
    defer { unsetenv("GITHUB_TOKEN") }

    let provider = EnvironmentCredentialProvider()
    let token = provider.getToken(for: "https://github.com/user/repo.git")

    #expect(token == "ghp_test123")
}

@Test("SSH key priority - Ed25519 over RSA")
func testSSHKeyPriority() async throws {
    // Create test SSH directory with multiple keys
    let testSSHDir = FileManager.default.temporaryDirectory.appendingPathComponent(".ssh")
    try FileManager.default.createDirectory(at: testSSHDir, withIntermediateDirectories: true)

    let rsaKey = testSSHDir.appendingPathComponent("id_rsa")
    let ed25519Key = testSSHDir.appendingPathComponent("id_ed25519")

    try "rsa key".write(to: rsaKey, atomically: true, encoding: .utf8)
    try "ed25519 key".write(to: ed25519Key, atomically: true, encoding: .utf8)

    let provider = SSHKeyProvider()
    let selectedKey = provider.findSSHKey()

    #expect(selectedKey?.lastPathComponent == "id_ed25519")
}

@Test("URL rewriting with token injection")
func testURLRewriting() async throws {
    let original = "https://github.com/user/repo.git"
    let token = "ghp_abc123"

    let rewritten = injectToken(token, into: original)

    #expect(rewritten == "https://x-access-token:ghp_abc123@github.com/user/repo.git")
}
```

### Integration Tests

```swift
@Test("Clone with environment token authentication")
func testCloneWithEnvToken() async throws {
    setenv("GITHUB_TOKEN", "ghp_real_token", 1)
    defer { unsetenv("GITHUB_TOKEN") }

    let service = GitProjectService(modelContext: modelContext)
    let repo = try await service.clone(
        remoteURL: "https://github.com/test/public-repo.git",
        localPath: tempDirectory.path
    )

    #expect(repo.remoteURL == "https://github.com/test/public-repo.git")
    #expect(FileManager.default.fileExists(atPath: repo.localPath))
}

@Test("Clone with SSH key authentication")
func testCloneWithSSH() async throws {
    // Assumes ~/.ssh/id_ed25519 exists
    let service = GitProjectService(modelContext: modelContext)
    let repo = try await service.clone(
        remoteURL: "git@github.com:test/public-repo.git",
        localPath: tempDirectory.path
    )

    #expect(repo.remoteURL == "git@github.com:test/public-repo.git")
}
```

## Platform Considerations

### macOS
- ✅ Full support for all authentication methods
- ✅ Keychain integration native
- ✅ SSH keys standard location (~/.ssh/)
- ✅ git-credential-osxkeychain available

### iOS
- ⚠️ Limited SSH support (no ~/.ssh/ on iOS)
- ⚠️ Environment variables not persistent across launches
- ✅ Keychain integration available
- ❌ No git credential helpers

**iOS Strategy**:
1. Prioritize HTTPS tokens over SSH
2. Store tokens in Keychain (not environment)
3. Prompt user for token on first use
4. Embed SSH keys in app bundle (advanced use case)

## UI Components

### Credential Status View

```swift
struct GitCredentialStatusView: View {
    @State private var tokenStatus: [GitProvider: Bool] = [:]
    @State private var hasSSHKey: Bool = false

    var body: some View {
        Form {
            Section("Environment Tokens") {
                StatusRow(provider: "GitHub", hasToken: tokenStatus[.github] ?? false)
                StatusRow(provider: "GitLab", hasToken: tokenStatus[.gitlab] ?? false)
                StatusRow(provider: "Bitbucket", hasToken: tokenStatus[.bitbucket] ?? false)
            }

            Section("SSH Keys") {
                LabeledContent("SSH Key Found") {
                    Image(systemName: hasSSHKey ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(hasSSHKey ? .green : .red)
                }
            }

            Section {
                Link("Configure GitHub Token", destination: URL(string: "https://github.com/settings/tokens")!)
                Link("Configure GitLab Token", destination: URL(string: "https://gitlab.com/-/profile/personal_access_tokens")!)
            }
        }
        .onAppear {
            tokenStatus = EnvironmentTokenChecker().checkAvailableTokens()
            hasSSHKey = SSHKeyProvider().hasSSHKey()
        }
    }
}

struct StatusRow: View {
    let provider: String
    let hasToken: Bool

    var body: some View {
        LabeledContent(provider) {
            Image(systemName: hasToken ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(hasToken ? .green : .red)
        }
    }
}
```

## Documentation for Users

### Setup Guide

**Setting Up Git Authentication**

1. **For GitHub**:
   ```bash
   # Generate token at https://github.com/settings/tokens
   # Select scopes: repo, read:user
   export GITHUB_TOKEN="ghp_your_token_here"
   ```

2. **For GitLab**:
   ```bash
   # Generate token at https://gitlab.com/-/profile/personal_access_tokens
   # Select scopes: read_repository, write_repository
   export GITLAB_TOKEN="glpat_your_token_here"
   ```

3. **For SSH** (recommended):
   ```bash
   # Generate Ed25519 key (most secure)
   ssh-keygen -t ed25519 -C "your_email@example.com"

   # Add to ssh-agent
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519

   # Copy public key to clipboard
   pbcopy < ~/.ssh/id_ed25519.pub

   # Add to GitHub: https://github.com/settings/keys
   ```

4. **Make Permanent** (add to ~/.zshrc):
   ```bash
   echo 'export GITHUB_TOKEN="ghp_your_token_here"' >> ~/.zshrc
   source ~/.zshrc
   ```

## References

- [GitHub Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [GitLab Personal Access Tokens](https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html)
- [SSH Key Generation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
- [git-credential Documentation](https://git-scm.com/docs/git-credential)
- [macOS Keychain Services](https://developer.apple.com/documentation/security/keychain_services)

## Next Steps

1. Implement `GitCredentialManager` with all providers
2. Write comprehensive tests for authentication flow
3. Build UI for credential status and configuration
4. Document setup process in user guide
5. Test with real repositories (GitHub, GitLab, Bitbucket)
