//
//  GitCredentialManager.swift
//  SwiftCompartido
//
//  Automatic Git credential detection and management.
//  Supports SSH keys, environment tokens, Git credential helpers, and macOS Keychain.
//

import Foundation
#if canImport(Security)
import Security
#endif

/// Manages Git authentication credentials with automatic detection.
///
/// `GitCredentialManager` implements zero-configuration authentication by automatically
/// detecting and using available credentials in this priority order:
///
/// 1. **SSH Keys** (for `git@` URLs) - `~/.ssh/id_ed25519`, `~/.ssh/id_rsa`, etc.
/// 2. **Environment Tokens** - `GITHUB_TOKEN`, `GITLAB_TOKEN`, `BITBUCKET_TOKEN`, `GIT_TOKEN`
/// 3. **Git Credential Helpers** - `git-credential-osxkeychain` on macOS
/// 4. **macOS Keychain** - Direct query for stored credentials
/// 5. **User Prompt** - Last resort (credentials saved to Keychain)
///
/// ## Example - Automatic Authentication
///
/// ```swift
/// let manager = GitCredentialManager()
///
/// // Automatically detects and uses available credentials
/// let credentials = try await manager.getCredentials(
///     for: "https://github.com/user/repo.git"
/// )
///
/// switch credentials {
/// case .ssh(let keyPath):
///     print("Using SSH key: \(keyPath)")
/// case .https(let username, let password):
///     print("Using HTTPS with username: \(username)")
/// }
/// ```
///
/// ## Zero Configuration
///
/// No user setup required - GitCredentialManager automatically uses whichever
/// authentication method is available on the system.
public final class GitCredentialManager {

    // MARK: - Types

    /// Git authentication credentials.
    public enum Credentials: Sendable, Equatable {
        /// SSH key authentication (for git@ URLs).
        case ssh(privateKeyPath: String, publicKeyPath: String?)

        /// HTTPS authentication with username and personal access token.
        case https(username: String, token: String)

        /// No authentication required (public repository).
        case none
    }

    /// Errors that can occur during credential detection.
    public enum CredentialError: Error, LocalizedError, Equatable {
        case sshKeyNotFound
        case invalidSSHKeyPermissions(path: String, current: String, expected: String)
        case noCredentialsFound(url: String)
        case keychainAccessDenied
        case invalidURL(String)

        public var errorDescription: String? {
            switch self {
            case .sshKeyNotFound:
                return "No SSH keys found in ~/.ssh/"
            case .invalidSSHKeyPermissions(let path, let current, let expected):
                return "SSH key '\(path)' has invalid permissions '\(current)' (expected '\(expected)')"
            case .noCredentialsFound(let url):
                return "No credentials found for '\(url)'"
            case .keychainAccessDenied:
                return "Access to macOS Keychain was denied"
            case .invalidURL(let url):
                return "Invalid Git URL: '\(url)'"
            }
        }
    }

    // MARK: - Properties

    private let fileManager = FileManager.default

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Get credentials for a Git remote URL with automatic detection.
    ///
    /// - Parameter remoteURL: The Git remote URL (e.g., "git@github.com:user/repo.git" or "https://github.com/user/repo.git")
    /// - Returns: Detected credentials
    /// - Throws: `CredentialError` if no valid credentials are found
    public func getCredentials(for remoteURL: String) async throws -> Credentials {
        guard let url = parseGitURL(remoteURL) else {
            throw CredentialError.invalidURL(remoteURL)
        }

        // Priority 1: SSH keys for git@ URLs
        if url.scheme == "ssh" || remoteURL.hasPrefix("git@") {
            return try detectSSHKey()
        }

        // Priority 2: Environment tokens for HTTPS URLs
        if let credentials = try detectEnvironmentToken(for: url.host) {
            return credentials
        }

        // Priority 3: Git credential helper
        if let credentials = try await queryGitCredentialHelper(for: remoteURL) {
            return credentials
        }

        // Priority 4: macOS Keychain
        #if canImport(Security)
        if let credentials = try queryKeychain(for: url.host) {
            return credentials
        }
        #endif

        // Priority 5: Return .none for public repositories
        // (SwiftGitX will handle prompting if authentication is actually required)
        return .none
    }

    /// Save HTTPS credentials to macOS Keychain for future use.
    ///
    /// - Parameters:
    ///   - username: Git username
    ///   - token: Personal access token or password
    ///   - host: Git host (e.g., "github.com")
    /// - Throws: `CredentialError.keychainAccessDenied` if save fails
    public func saveCredentials(username: String, token: String, for host: String) throws {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: host,
            kSecAttrAccount as String: username,
            kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
            kSecValueData as String: token.data(using: .utf8)!,
            kSecAttrLabel as String: "Git: \(host)"
        ]

        // Delete existing entry
        SecItemDelete(query as CFDictionary)

        // Add new entry
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialError.keychainAccessDenied
        }
        #else
        throw CredentialError.keychainAccessDenied
        #endif
    }

    // MARK: - SSH Key Detection

    private func detectSSHKey() throws -> Credentials {
        #if os(macOS)
        let sshDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")

        // Check for Ed25519 key (modern, recommended)
        let ed25519Private = sshDir.appendingPathComponent("id_ed25519")
        let ed25519Public = sshDir.appendingPathComponent("id_ed25519.pub")

        if fileManager.fileExists(atPath: ed25519Private.path) {
            try validateSSHKeyPermissions(ed25519Private)
            return .ssh(
                privateKeyPath: ed25519Private.path,
                publicKeyPath: fileManager.fileExists(atPath: ed25519Public.path) ? ed25519Public.path : nil
            )
        }

        // Check for RSA key (legacy)
        let rsaPrivate = sshDir.appendingPathComponent("id_rsa")
        let rsaPublic = sshDir.appendingPathComponent("id_rsa.pub")

        if fileManager.fileExists(atPath: rsaPrivate.path) {
            try validateSSHKeyPermissions(rsaPrivate)
            return .ssh(
                privateKeyPath: rsaPrivate.path,
                publicKeyPath: fileManager.fileExists(atPath: rsaPublic.path) ? rsaPublic.path : nil
            )
        }

        // Check for ECDSA key
        let ecdsaPrivate = sshDir.appendingPathComponent("id_ecdsa")
        let ecdsaPublic = sshDir.appendingPathComponent("id_ecdsa.pub")

        if fileManager.fileExists(atPath: ecdsaPrivate.path) {
            try validateSSHKeyPermissions(ecdsaPrivate)
            return .ssh(
                privateKeyPath: ecdsaPrivate.path,
                publicKeyPath: fileManager.fileExists(atPath: ecdsaPublic.path) ? ecdsaPublic.path : nil
            )
        }

        throw CredentialError.sshKeyNotFound
        #else
        // SSH key authentication is only supported on macOS
        throw CredentialError.sshKeyNotFound
        #endif
    }

    #if os(macOS)
    private func validateSSHKeyPermissions(_ keyPath: URL) throws {
        let attributes = try fileManager.attributesOfItem(atPath: keyPath.path)
        let posixPermissions = attributes[.posixPermissions] as? Int ?? 0

        // SSH keys must be 0600 (read/write for owner only)
        let expectedPermissions = 0o600

        if posixPermissions != expectedPermissions {
            let currentOctal = String(format: "%o", posixPermissions)
            let expectedOctal = String(format: "%o", expectedPermissions)
            throw CredentialError.invalidSSHKeyPermissions(
                path: keyPath.path,
                current: currentOctal,
                expected: expectedOctal
            )
        }
    }
    #endif

    // MARK: - Environment Token Detection

    private func detectEnvironmentToken(for host: String?) throws -> Credentials? {
        guard let host = host else { return nil }

        let environment = ProcessInfo.processInfo.environment

        // Check provider-specific tokens
        if host.contains("github.com"), let token = environment["GITHUB_TOKEN"] {
            return .https(username: "git", token: token)
        }

        if host.contains("gitlab.com"), let token = environment["GITLAB_TOKEN"] {
            return .https(username: "git", token: token)
        }

        if host.contains("bitbucket.org"), let token = environment["BITBUCKET_TOKEN"] {
            return .https(username: "git", token: token)
        }

        // Check generic GIT_TOKEN
        if let token = environment["GIT_TOKEN"] {
            return .https(username: "git", token: token)
        }

        return nil
    }

    // MARK: - Git Credential Helper

    private func queryGitCredentialHelper(for url: String) async throws -> Credentials? {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["credential", "fill"]

        let inputPipe = Pipe()
        let outputPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        // Write URL to stdin
        let input = "url=\(url)\n\n"
        guard let inputData = input.data(using: .utf8) else { return nil }

        do {
            try process.run()
            try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
            try inputPipe.fileHandleForWriting.close()

            let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            process.waitUntilExit()

            // Parse credential helper output
            var username: String?
            var password: String?

            for line in output.components(separatedBy: .newlines) {
                let parts = line.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }

                let key = String(parts[0])
                let value = String(parts[1])

                if key == "username" {
                    username = value
                } else if key == "password" {
                    password = value
                }
            }

            if let username = username, let password = password {
                return .https(username: username, token: password)
            }
        } catch {
            // Git credential helper failed or not available
            return nil
        }
        #endif

        return nil
    }

    // MARK: - Keychain Query

    private func queryKeychain(for host: String?) throws -> Credentials? {
        #if canImport(Security)
        guard let host = host else { return nil }

        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: host,
            kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
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

        return .https(username: username, token: password)
        #else
        return nil
        #endif
    }

    // MARK: - URL Parsing

    private func parseGitURL(_ urlString: String) -> (scheme: String, host: String?)? {
        // Handle git@ URLs (SSH)
        if urlString.hasPrefix("git@") {
            let parts = urlString.dropFirst(4).split(separator: ":")
            guard let host = parts.first else { return nil }
            return (scheme: "ssh", host: String(host))
        }

        // Handle standard URLs - must have valid scheme
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              scheme.lowercased() == "https" || scheme.lowercased() == "http" || scheme.lowercased() == "ssh" else {
            return nil
        }

        return (scheme: scheme, host: url.host)
    }
}
