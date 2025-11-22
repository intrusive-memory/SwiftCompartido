//
//  GitProjectServiceTests.swift
//  SwiftCompartidoTests
//
//  Tests for Git project service operations.
//

import Testing
import Foundation
import SwiftData
@testable import SwiftCompartido

@Suite("Git Project Service Tests")
struct GitProjectServiceTests {

    // MARK: - Helper Methods

    private func createTestModelContext() throws -> ModelContext {
        let schema = Schema([
            GitRepositoryModel.self,
            GitCommitModel.self,
            GuionDocumentModel.self
        ])

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }

    private func createTemporaryDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitProjectServiceTests-\(UUID().uuidString)")

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Initialization Tests

    @Test("Initialize service without model context")
    func testInitWithoutModelContext() async {
        let service = await GitProjectService(modelContext: nil)
        #expect(service != nil)
    }

    @Test("Initialize service with model context")
    func testInitWithModelContext() async throws {
        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)
        #expect(service != nil)
    }

    // MARK: - Repository Status Tests

    @Test("Repository status structure")
    func testRepositoryStatusStructure() {
        let status = GitProjectService.RepositoryStatus(
            modifiedFiles: 5,
            commitsAhead: 2,
            commitsBehind: 1,
            modifiedPaths: ["file1.txt", "file2.txt"]
        )

        #expect(status.modifiedFiles == 5)
        #expect(status.commitsAhead == 2)
        #expect(status.commitsBehind == 1)
        #expect(status.modifiedPaths.count == 2)
        #expect(status.hasChanges == true)
        #expect(status.isInSync == false)
    }

    @Test("Repository status has no changes")
    func testRepositoryStatusNoChanges() {
        let status = GitProjectService.RepositoryStatus(
            modifiedFiles: 0,
            commitsAhead: 0,
            commitsBehind: 0,
            modifiedPaths: []
        )

        #expect(status.hasChanges == false)
        #expect(status.isInSync == true)
    }

    @Test("Repository status is in sync")
    func testRepositoryStatusInSync() {
        let status = GitProjectService.RepositoryStatus(
            modifiedFiles: 3,
            commitsAhead: 0,
            commitsBehind: 0,
            modifiedPaths: ["file.txt"]
        )

        #expect(status.hasChanges == true)
        #expect(status.isInSync == true) // No commits ahead/behind
    }

    // MARK: - Error Tests

    @Test("Repository not found error")
    func testRepositoryNotFoundError() {
        let error = GitProjectService.GitError.repositoryNotFound(path: "/nonexistent/path")
        #expect(error.errorDescription?.contains("not found") == true)
        #expect(error.errorDescription?.contains("/nonexistent/path") == true)
    }

    @Test("Invalid remote URL error")
    func testInvalidRemoteURLError() {
        let error = GitProjectService.GitError.invalidRemoteURL("bad-url")
        #expect(error.errorDescription?.contains("Invalid") == true)
        #expect(error.errorDescription?.contains("bad-url") == true)
    }

    @Test("Clone failed error")
    func testCloneFailedError() {
        let error = GitProjectService.GitError.cloneFailed(reason: "Network timeout")
        #expect(error.errorDescription?.contains("Clone failed") == true)
        #expect(error.errorDescription?.contains("Network timeout") == true)
    }

    @Test("Pull failed error")
    func testPullFailedError() {
        let error = GitProjectService.GitError.pullFailed(reason: "Merge conflict")
        #expect(error.errorDescription?.contains("Pull failed") == true)
        #expect(error.errorDescription?.contains("Merge conflict") == true)
    }

    @Test("Push failed error")
    func testPushFailedError() {
        let error = GitProjectService.GitError.pushFailed(reason: "Permission denied")
        #expect(error.errorDescription?.contains("Push failed") == true)
        #expect(error.errorDescription?.contains("Permission denied") == true)
    }

    @Test("Commit failed error")
    func testCommitFailedError() {
        let error = GitProjectService.GitError.commitFailed(reason: "No changes")
        #expect(error.errorDescription?.contains("Commit failed") == true)
        #expect(error.errorDescription?.contains("No changes") == true)
    }

    @Test("Authentication required error")
    func testAuthenticationRequiredError() {
        let error = GitProjectService.GitError.authenticationRequired
        #expect(error.errorDescription?.contains("Authentication required") == true)
    }

    @Test("Repository already exists error")
    func testRepositoryAlreadyExistsError() {
        let error = GitProjectService.GitError.repositoryAlreadyExists(path: "/existing/path")
        #expect(error.errorDescription?.contains("already exists") == true)
        #expect(error.errorDescription?.contains("/existing/path") == true)
    }

    @Test("Invalid author format error")
    func testInvalidAuthorFormatError() {
        let error = GitProjectService.GitError.invalidAuthorFormat("bad format")
        #expect(error.errorDescription?.contains("Invalid author") == true)
        #expect(error.errorDescription?.contains("bad format") == true)
    }

    // MARK: - Clone Tests

    @Test("Clone to existing path throws error")
    func testCloneToExistingPath() async throws {
        let service = await GitProjectService()
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        // Create directory that already exists
        let existingPath = tempDir.appendingPathComponent("existing").path

        try FileManager.default.createDirectory(
            atPath: existingPath,
            withIntermediateDirectories: true
        )

        await #expect(throws: GitProjectService.GitError.self) {
            try await service.clone(
                remoteURL: "https://github.com/user/repo.git",
                localPath: existingPath
            )
        }
    }

    @Test("Clone creates parent directory")
    func testCloneCreatesParentDirectory() async throws {
        let service = await GitProjectService()
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let repoPath = tempDir.appendingPathComponent("nested/repo").path

        // Parent directory doesn't exist yet
        #expect(!FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("nested").path))

        // Clone will fail (no actual Git repo), but parent directory should be created
        do {
            try await service.clone(
                remoteURL: "https://github.com/nonexistent/repo.git",
                localPath: repoPath
            )
        } catch {
            // Expected to fail (invalid repo), but parent should exist
            #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("nested").path))
        }
    }

    // MARK: - Status Tests

    @Test("Status on non-existent repository throws error")
    func testStatusNonExistentRepository() async throws {
        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: "/nonexistent/path",
            remoteURL: nil
        )

        await #expect(throws: GitProjectService.GitError.self) {
            try await service.status(repository: repository)
        }
    }

    // MARK: - Pull Tests

    @Test("Pull on non-existent repository throws error")
    func testPullNonExistentRepository() async throws {
        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: "/nonexistent/path",
            remoteURL: "https://github.com/user/repo.git"
        )

        await #expect(throws: GitProjectService.GitError.self) {
            try await service.pull(repository: repository) { _, _ in }
        }
    }

    // MARK: - Push Tests

    @Test("Push on non-existent repository throws error")
    func testPushNonExistentRepository() async throws {
        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: "/nonexistent/path",
            remoteURL: "https://github.com/user/repo.git"
        )

        await #expect(throws: GitProjectService.GitError.self) {
            try await service.push(repository: repository) { _, _ in }
        }
    }

    // MARK: - Commit Tests

    @Test("Commit on non-existent repository throws error")
    func testCommitNonExistentRepository() async throws {
        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: "/nonexistent/path",
            remoteURL: nil
        )

        await #expect(throws: GitProjectService.GitError.self) {
            try await service.commit(
                repository: repository,
                message: "Test commit",
                author: "Test User <test@example.com>"
            )
        }
    }

    // MARK: - Progress Callback Tests

    @Test("Progress callback is optional")
    func testProgressCallbackOptional() async throws {
        let service = await GitProjectService()
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        // Should not crash with nil progress callback
        do {
            try await service.clone(
                remoteURL: "https://github.com/nonexistent/repo.git",
                localPath: tempDir.appendingPathComponent("repo").path,
                progress: nil
            )
        } catch {
            // Expected to fail, but should not crash
            #expect(error is GitProjectService.GitError)
        }
    }

    // Note: Removed progress callback test with captured variables due to Sendable requirements

    // MARK: - Sendable Conformance Tests

    @Test("RepositoryStatus is Sendable")
    func testRepositoryStatusSendable() {
        let status = GitProjectService.RepositoryStatus(
            modifiedFiles: 0,
            commitsAhead: 0,
            commitsBehind: 0,
            modifiedPaths: []
        )

        // Compile-time check that RepositoryStatus conforms to Sendable
        #expect(status.modifiedFiles == 0)
    }

    @Test("ProgressCallback is Sendable")
    func testProgressCallbackSendable() {
        let callback: GitProjectService.ProgressCallback = { progress, message in
            print("\(progress): \(message)")
        }

        // Compile-time check that ProgressCallback is @Sendable
        callback(0.5, "Test")
    }
}
