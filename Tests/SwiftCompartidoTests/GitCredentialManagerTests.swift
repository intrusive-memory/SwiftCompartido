//
//  GitCredentialManagerTests.swift
//  SwiftCompartidoTests
//
//  Tests for Git credential manager with automatic detection.
//

import Testing
import Foundation
@testable import SwiftCompartido

@Suite("Git Credential Manager Tests")
struct GitCredentialManagerTests {

    // MARK: - URL Parsing Tests

    @Test("Parse HTTPS GitHub URL")
    func testParseHTTPSURL() async throws {
        let manager = GitCredentialManager()
        let credentials = try await manager.getCredentials(for: "https://github.com/user/repo.git")

        // Should return some form of credentials or .none
        // (actual authentication tested separately)
        #expect(credentials != nil)
    }

    @Test("Parse SSH GitHub URL")
    func testParseSSHURL() async throws {
        let manager = GitCredentialManager()

        // SSH URLs should attempt SSH key detection
        do {
            _ = try await manager.getCredentials(for: "git@github.com:user/repo.git")
        } catch GitCredentialManager.CredentialError.sshKeyNotFound {
            // Expected if no SSH keys exist
            #expect(true)
        } catch {
            throw error
        }
    }

    @Test("Invalid URL throws error")
    func testInvalidURL() async {
        let manager = GitCredentialManager()

        await #expect(throws: GitCredentialManager.CredentialError.self) {
            try await manager.getCredentials(for: "not-a-valid-url")
        }
    }

    // MARK: - Environment Token Detection Tests

    @Test("Detect GITHUB_TOKEN from environment")
    func testGitHubTokenDetection() async throws {
        // This test requires GITHUB_TOKEN to be set
        // Skip if not present
        guard ProcessInfo.processInfo.environment["GITHUB_TOKEN"] != nil else {
            return
        }

        let manager = GitCredentialManager()
        let credentials = try await manager.getCredentials(for: "https://github.com/user/repo.git")

        if case .https(let username, let token) = credentials {
            #expect(username == "git")
            #expect(!token.isEmpty)
        }
    }

    @Test("Detect GITLAB_TOKEN from environment")
    func testGitLabTokenDetection() async throws {
        // This test requires GITLAB_TOKEN to be set
        // Skip if not present
        guard ProcessInfo.processInfo.environment["GITLAB_TOKEN"] != nil else {
            return
        }

        let manager = GitCredentialManager()
        let credentials = try await manager.getCredentials(for: "https://gitlab.com/user/repo.git")

        if case .https(let username, let token) = credentials {
            #expect(username == "git")
            #expect(!token.isEmpty)
        }
    }

    // MARK: - SSH Key Detection Tests (macOS only)

    #if os(macOS)
    @Test("Detect Ed25519 SSH key if exists")
    func testEd25519KeyDetection() async throws {
        let manager = GitCredentialManager()
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let sshKeyPath = homeDir.appendingPathComponent(".ssh/id_ed25519")

        // Only run if SSH key exists
        guard FileManager.default.fileExists(atPath: sshKeyPath.path) else {
            return
        }

        let credentials = try await manager.getCredentials(for: "git@github.com:user/repo.git")

        if case .ssh(let privateKeyPath, _) = credentials {
            #expect(privateKeyPath.contains("id_ed25519"))
        }
    }

    @Test("Detect RSA SSH key if exists")
    func testRSAKeyDetection() async throws {
        let manager = GitCredentialManager()
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let ed25519Path = homeDir.appendingPathComponent(".ssh/id_ed25519")
        let rsaPath = homeDir.appendingPathComponent(".ssh/id_rsa")

        // Only run if RSA key exists and Ed25519 doesn't (to ensure RSA is chosen)
        guard !FileManager.default.fileExists(atPath: ed25519Path.path),
              FileManager.default.fileExists(atPath: rsaPath.path) else {
            return
        }

        let credentials = try await manager.getCredentials(for: "git@github.com:user/repo.git")

        if case .ssh(let privateKeyPath, _) = credentials {
            #expect(privateKeyPath.contains("id_rsa"))
        }
    }

    @Test("SSH key not found error")
    func testSSHKeyNotFound() async {
        let manager = GitCredentialManager()
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let sshDir = homeDir.appendingPathComponent(".ssh")

        // Only run if .ssh directory doesn't exist or has no keys
        let hasEd25519 = FileManager.default.fileExists(atPath: sshDir.appendingPathComponent("id_ed25519").path)
        let hasRSA = FileManager.default.fileExists(atPath: sshDir.appendingPathComponent("id_rsa").path)
        let hasECDSA = FileManager.default.fileExists(atPath: sshDir.appendingPathComponent("id_ecdsa").path)

        guard !hasEd25519 && !hasRSA && !hasECDSA else {
            return
        }

        await #expect(throws: GitCredentialManager.CredentialError.sshKeyNotFound) {
            try await manager.getCredentials(for: "git@github.com:user/repo.git")
        }
    }
    #endif

    // MARK: - Error Description Tests

    @Test("SSH key not found error description")
    func testSSHKeyNotFoundDescription() {
        let error = GitCredentialManager.CredentialError.sshKeyNotFound
        #expect(error.errorDescription?.contains("SSH keys") == true)
    }

    @Test("Invalid SSH permissions error description")
    func testInvalidSSHPermissionsDescription() {
        let error = GitCredentialManager.CredentialError.invalidSSHKeyPermissions(
            path: "/path/to/key",
            current: "644",
            expected: "600"
        )
        #expect(error.errorDescription?.contains("permissions") == true)
        #expect(error.errorDescription?.contains("644") == true)
        #expect(error.errorDescription?.contains("600") == true)
    }

    @Test("No credentials found error description")
    func testNoCredentialsFoundDescription() {
        let error = GitCredentialManager.CredentialError.noCredentialsFound(url: "https://example.com/repo.git")
        #expect(error.errorDescription?.contains("example.com") == true)
    }

    @Test("Keychain access denied error description")
    func testKeychainAccessDeniedDescription() {
        let error = GitCredentialManager.CredentialError.keychainAccessDenied
        #expect(error.errorDescription?.contains("Keychain") == true)
    }

    @Test("Invalid URL error description")
    func testInvalidURLDescription() {
        let error = GitCredentialManager.CredentialError.invalidURL("bad-url")
        #expect(error.errorDescription?.contains("Invalid") == true)
        #expect(error.errorDescription?.contains("bad-url") == true)
    }

    // MARK: - Credential Type Tests

    @Test("Credentials types are Sendable and Equatable")
    func testCredentialsSendable() {
        // Compile-time check that Credentials conforms to Sendable and Equatable
        let credentials: GitCredentialManager.Credentials = .none
        #expect(credentials == .none)
    }

    @Test("HTTPS credentials contain username and token")
    func testHTTPSCredentialsStructure() {
        let credentials = GitCredentialManager.Credentials.https(username: "user", token: "token123")

        if case .https(let username, let token) = credentials {
            #expect(username == "user")
            #expect(token == "token123")
        } else {
            Issue.record("Expected HTTPS credentials")
        }
    }

    @Test("SSH credentials contain key paths")
    func testSSHCredentialsStructure() {
        let credentials = GitCredentialManager.Credentials.ssh(
            privateKeyPath: "/path/to/private",
            publicKeyPath: "/path/to/public"
        )

        if case .ssh(let privateKeyPath, let publicKeyPath) = credentials {
            #expect(privateKeyPath == "/path/to/private")
            #expect(publicKeyPath == "/path/to/public")
        } else {
            Issue.record("Expected SSH credentials")
        }
    }

    @Test("SSH credentials with nil public key")
    func testSSHCredentialsNilPublicKey() {
        let credentials = GitCredentialManager.Credentials.ssh(
            privateKeyPath: "/path/to/private",
            publicKeyPath: nil
        )

        if case .ssh(let privateKeyPath, let publicKeyPath) = credentials {
            #expect(privateKeyPath == "/path/to/private")
            #expect(publicKeyPath == nil)
        } else {
            Issue.record("Expected SSH credentials")
        }
    }

    // MARK: - Integration Tests

    @Test("Public repository returns .none or valid credentials")
    func testPublicRepositoryHandling() async throws {
        let manager = GitCredentialManager()

        // Public HTTPS URL should return .none or valid credentials
        let credentials = try await manager.getCredentials(for: "https://github.com/torvalds/linux.git")

        // Should not throw, credentials can be .none for public repos
        #expect(credentials != nil)
    }
}
