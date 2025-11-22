//
//  GitLFSIntegrationTests.swift
//  SwiftCompartidoTests
//
//  Integration tests for Git LFS operations in GitProjectService.
//

import Testing
import Foundation
import SwiftData
@testable import SwiftCompartido

@Suite("Git LFS Integration Tests")
struct GitLFSIntegrationTests {

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
            .appendingPathComponent("GitLFSTests-\(UUID().uuidString)")

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func createMockGitRepository(at path: URL) throws {
        // Create .git directory
        let gitDir = path.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        // Create basic git structure
        try FileManager.default.createDirectory(at: gitDir.appendingPathComponent("objects"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: gitDir.appendingPathComponent("refs"), withIntermediateDirectories: true)

        // Create HEAD file
        try "ref: refs/heads/main".write(to: gitDir.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)
    }

    // MARK: - LFS Detection Tests

    @Test("Check LFS not installed in empty directory")
    func testLFSNotInstalledEmpty() async throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        try createMockGitRepository(at: tempDir)

        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: tempDir.path,
            remoteURL: nil
        )

        let isInstalled = await service.isLFSInstalled(in: repository)
        #expect(isInstalled == false)
    }

    @Test("Check LFS installed when .git/lfs exists")
    func testLFSInstalledWhenDirectoryExists() async throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        try createMockGitRepository(at: tempDir)

        // Create .git/lfs directory
        let lfsDir = tempDir.appendingPathComponent(".git/lfs")
        try FileManager.default.createDirectory(at: lfsDir, withIntermediateDirectories: true)

        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: tempDir.path,
            remoteURL: nil
        )

        let isInstalled = await service.isLFSInstalled(in: repository)
        #expect(isInstalled == true)
    }

    @Test("Check LFS in nonexistent repository returns false")
    func testLFSCheckNonexistentRepo() async {
        let service = await GitProjectService()

        let repository = GitRepositoryModel(
            localPath: "/nonexistent/path",
            remoteURL: nil
        )

        let isInstalled = await service.isLFSInstalled(in: repository)
        #expect(isInstalled == false)
    }

    // MARK: - Pattern Management Tests

    @Test("Track LFS pattern creates .gitattributes")
    func testTrackPatternCreatesFile() async throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        try createMockGitRepository(at: tempDir)

        // Create .git/lfs directory to simulate LFS installed
        let lfsDir = tempDir.appendingPathComponent(".git/lfs")
        try FileManager.default.createDirectory(at: lfsDir, withIntermediateDirectories: true)

        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: tempDir.path,
            remoteURL: nil
        )

        try await service.trackLFSPattern("*.mp3", in: repository)

        // Verify .gitattributes was created
        let attributesURL = tempDir.appendingPathComponent(".gitattributes")
        #expect(FileManager.default.fileExists(atPath: attributesURL.path))

        // Verify content
        let parser = GitAttributesParser()
        let patterns = try parser.getLFSPatterns(from: attributesURL)
        #expect(patterns.contains("*.mp3"))
    }

    @Test("Track multiple patterns")
    func testTrackMultiplePatterns() async throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        try createMockGitRepository(at: tempDir)

        // Create .git/lfs directory
        let lfsDir = tempDir.appendingPathComponent(".git/lfs")
        try FileManager.default.createDirectory(at: lfsDir, withIntermediateDirectories: true)

        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: tempDir.path,
            remoteURL: nil
        )

        try await service.trackLFSPattern("*.mp3", in: repository)
        try await service.trackLFSPattern("*.wav", in: repository)
        try await service.trackLFSPattern("*.pdf", in: repository)

        // Verify all patterns were added
        let patterns = try await service.listLFSPatterns(in: repository)
        #expect(patterns.count == 3)
        #expect(patterns.contains("*.mp3"))
        #expect(patterns.contains("*.wav"))
        #expect(patterns.contains("*.pdf"))
    }

    @Test("Untrack pattern removes from .gitattributes")
    func testUntrackPattern() async throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        try createMockGitRepository(at: tempDir)

        // Create .git/lfs directory
        let lfsDir = tempDir.appendingPathComponent(".git/lfs")
        try FileManager.default.createDirectory(at: lfsDir, withIntermediateDirectories: true)

        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: tempDir.path,
            remoteURL: nil
        )

        // Track multiple patterns
        try await service.trackLFSPattern("*.mp3", in: repository)
        try await service.trackLFSPattern("*.wav", in: repository)
        try await service.trackLFSPattern("*.pdf", in: repository)

        // Untrack one
        try await service.untrackLFSPattern("*.wav", from: repository)

        // Verify pattern was removed
        let patterns = try await service.listLFSPatterns(in: repository)
        #expect(patterns.count == 2)
        #expect(patterns.contains("*.mp3"))
        #expect(patterns.contains("*.pdf"))
        #expect(!patterns.contains("*.wav"))
    }

    @Test("List patterns from nonexistent .gitattributes returns empty")
    func testListPatternsNonexistentFile() async throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        try createMockGitRepository(at: tempDir)

        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: tempDir.path,
            remoteURL: nil
        )

        let patterns = try await service.listLFSPatterns(in: repository)
        #expect(patterns.isEmpty)
    }

    @Test("Track pattern on nonexistent repository throws")
    func testTrackPatternNonexistentRepo() async throws {
        let service = await GitProjectService()

        let repository = GitRepositoryModel(
            localPath: "/nonexistent/path",
            remoteURL: nil
        )

        await #expect(throws: GitProjectService.GitError.self) {
            try await service.trackLFSPattern("*.mp3", in: repository)
        }
    }

    @Test("Untrack pattern on nonexistent repository throws")
    func testUntrackPatternNonexistentRepo() async throws {
        let service = await GitProjectService()

        let repository = GitRepositoryModel(
            localPath: "/nonexistent/path",
            remoteURL: nil
        )

        await #expect(throws: GitProjectService.GitError.self) {
            try await service.untrackLFSPattern("*.mp3", from: repository)
        }
    }

    // MARK: - Model Synchronization Tests

    @Test("Track pattern updates model")
    func testTrackPatternUpdatesModel() async throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        try createMockGitRepository(at: tempDir)

        // Create .git/lfs directory
        let lfsDir = tempDir.appendingPathComponent(".git/lfs")
        try FileManager.default.createDirectory(at: lfsDir, withIntermediateDirectories: true)

        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: tempDir.path,
            remoteURL: nil
        )

        #expect(repository.lfsFiles.isEmpty)

        try await service.trackLFSPattern("*.mp3", in: repository)

        #expect(repository.lfsFiles.contains("*.mp3"))
    }

    @Test("Untrack pattern updates model")
    func testUntrackPatternUpdatesModel() async throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        try createMockGitRepository(at: tempDir)

        // Create .git/lfs directory
        let lfsDir = tempDir.appendingPathComponent(".git/lfs")
        try FileManager.default.createDirectory(at: lfsDir, withIntermediateDirectories: true)

        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: tempDir.path,
            remoteURL: nil
        )

        try await service.trackLFSPattern("*.mp3", in: repository)
        try await service.trackLFSPattern("*.wav", in: repository)

        #expect(repository.lfsFiles.contains("*.mp3"))
        #expect(repository.lfsFiles.contains("*.wav"))

        try await service.untrackLFSPattern("*.mp3", from: repository)

        #expect(!repository.lfsFiles.contains("*.mp3"))
        #expect(repository.lfsFiles.contains("*.wav"))
    }

    // MARK: - Integration with .gitattributes Parser Tests

    @Test("Parser and service work together")
    func testParserServiceIntegration() async throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        try createMockGitRepository(at: tempDir)

        // Create .git/lfs directory
        let lfsDir = tempDir.appendingPathComponent(".git/lfs")
        try FileManager.default.createDirectory(at: lfsDir, withIntermediateDirectories: true)

        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: tempDir.path,
            remoteURL: nil
        )

        // Track patterns using service
        try await service.trackLFSPattern("*.mp3", in: repository)
        try await service.trackLFSPattern("*.wav", in: repository)

        // Verify using parser
        let parser = GitAttributesParser()
        let attributesURL = tempDir.appendingPathComponent(".gitattributes")
        let patterns = try parser.getLFSPatterns(from: attributesURL)

        #expect(patterns.count == 2)
        #expect(patterns.contains("*.mp3"))
        #expect(patterns.contains("*.wav"))
    }

    // MARK: - Default Patterns Tests

    @Test("Default LFS patterns are comprehensive")
    func testDefaultPatterns() {
        let patterns = GitAttributesParser.defaultLFSPatterns

        // Should have patterns for all major multimedia types
        #expect(patterns.count >= 15)

        // Audio
        #expect(patterns.contains("*.mp3"))
        #expect(patterns.contains("*.wav"))
        #expect(patterns.contains("*.m4a"))

        // Video
        #expect(patterns.contains("*.mp4"))
        #expect(patterns.contains("*.mov"))

        // Images
        #expect(patterns.contains("*.png"))
        #expect(patterns.contains("*.jpg"))

        // PDF
        #expect(patterns.contains("*.pdf"))
    }

    // MARK: - Error Handling Tests

    @Test("List patterns error handling")
    func testListPatternsErrorHandling() async throws {
        let service = await GitProjectService()

        let repository = GitRepositoryModel(
            localPath: "/nonexistent/path",
            remoteURL: nil
        )

        await #expect(throws: GitProjectService.GitError.self) {
            try await service.listLFSPatterns(in: repository)
        }
    }

    // MARK: - Concurrent Operations Tests

    @Test("Concurrent pattern tracking")
    func testConcurrentPatternTracking() async throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        try createMockGitRepository(at: tempDir)

        // Create .git/lfs directory
        let lfsDir = tempDir.appendingPathComponent(".git/lfs")
        try FileManager.default.createDirectory(at: lfsDir, withIntermediateDirectories: true)

        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: tempDir.path,
            remoteURL: nil
        )

        // Track multiple patterns concurrently
        async let task1 = service.trackLFSPattern("*.mp3", in: repository)
        async let task2 = service.trackLFSPattern("*.wav", in: repository)
        async let task3 = service.trackLFSPattern("*.pdf", in: repository)

        try await task1
        try await task2
        try await task3

        // Verify all patterns were added
        let patterns = try await service.listLFSPatterns(in: repository)
        #expect(patterns.count == 3)
    }

    // MARK: - SwiftData Persistence Tests

    @Test("Repository LFS state persists")
    func testLFSStatePersistence() async throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        try createMockGitRepository(at: tempDir)

        // Create .git/lfs directory
        let lfsDir = tempDir.appendingPathComponent(".git/lfs")
        try FileManager.default.createDirectory(at: lfsDir, withIntermediateDirectories: true)

        let modelContext = try createTestModelContext()
        let service = await GitProjectService(modelContext: modelContext)

        let repository = GitRepositoryModel(
            localPath: tempDir.path,
            remoteURL: nil
        )

        try await service.trackLFSPattern("*.mp3", in: repository)
        try await service.trackLFSPattern("*.wav", in: repository)

        // Verify model was updated
        #expect(repository.lfsFiles.count == 2)
        #expect(repository.lfsFiles.contains("*.mp3"))
        #expect(repository.lfsFiles.contains("*.wav"))
    }
}
