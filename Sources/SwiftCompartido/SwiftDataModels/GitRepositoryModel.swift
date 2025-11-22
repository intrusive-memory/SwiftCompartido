//
//  GitRepositoryModel.swift
//  SwiftCompartido
//
//  Copyright (c) 2025
//

import Foundation
#if canImport(SwiftData)
import SwiftData

/// SwiftData model representing a Git repository associated with a screenplay project.
///
/// This model stores metadata about a cloned Git repository, including remote URL,
/// current branch, sync status, and LFS configuration. Git operations are managed
/// through `GitProjectService`.
///
/// ## Overview
///
/// `GitRepositoryModel` enables version control integration for screenplay projects,
/// treating Git functionality as project-scoped (not file-scoped). Each repository
/// can optionally be linked to a `GuionDocumentModel` for seamless import/export.
///
/// ## Features
///
/// - **Repository Metadata**: Remote URL, current branch, last sync timestamp
/// - **LFS Support**: Automatic Git LFS detection and file management
/// - **SwiftData Integration**: Automatic persistence with cascade delete rules
/// - **Commit History**: Optional caching of commit metadata for performance
/// - **Phase 6 Compliant**: LFS files stored as file references, not in-memory
///
/// ## Example - Clone and Link
///
/// ```swift
/// let service = GitProjectService(modelContext: modelContext)
///
/// let repository = try await service.clone(
///     remoteURL: "https://github.com/user/screenplay.git",
///     localPath: "/path/to/repo"
/// )
///
/// // Import screenplay from repository
/// let document = try await service.importDocument(repository: repository)
///
/// // Link repository to document
/// document.gitRepository = repository
/// try modelContext.save()
/// ```
///
/// ## Example - Check Status
///
/// ```swift
/// let status = try await service.status(repository: repository)
///
/// if status.isDirty {
///     print("Uncommitted changes: \(status.modifiedFiles.count) files")
/// }
///
/// if status.commitsAhead > 0 {
///     print("Ready to push \(status.commitsAhead) commits")
/// }
/// ```
///
/// ## Topics
///
/// ### Creating Repositories
/// - ``init(id:localPath:remoteURL:)``
///
/// ### Repository Properties
/// - ``id``
/// - ``localPath``
/// - ``remoteURL``
/// - ``currentBranch``
/// - ``lastSync``
/// - ``lfsEnabled``
///
/// ### Relationships
/// - ``document``
/// - ``lfsFiles``
/// - ``commits``
///
/// ### Validation
/// - ``validate()``
@Model
public final class GitRepositoryModel: @unchecked Sendable {
    /// Unique identifier for this repository
    @Attribute(.unique)
    public var id: UUID

    /// Local file system path where repository is cloned
    ///
    /// This path is managed by `StorageAreaReference` and follows the pattern:
    /// `~/Library/Application Support/SwiftCompartido/git-repositories/{id}/`
    ///
    /// ## Example
    ///
    /// ```swift
    /// let storage = StorageAreaReference.persistent(
    ///     requestID: repository.id,
    ///     folderName: "git-repositories"
    /// )
    /// repository.localPath = storage.folderURL.path
    /// ```
    public var localPath: String

    /// Remote repository URL (HTTPS or SSH)
    ///
    /// Examples:
    /// - `https://github.com/user/screenplay.git`
    /// - `git@github.com:user/screenplay.git`
    /// - `https://gitlab.com/user/screenplay.git`
    ///
    /// Authentication is handled automatically by `GitCredentialManager`:
    /// - SSH: Uses `~/.ssh/id_ed25519`, `~/.ssh/id_rsa`, etc.
    /// - HTTPS: Uses `GITHUB_TOKEN`, `GITLAB_TOKEN` environment variables
    ///
    /// - SeeAlso: `GIT_AUTHENTICATION.md`
    public var remoteURL: String?

    /// Current checked-out branch name
    ///
    /// Defaults to `"main"` for new repositories.
    /// Updated automatically when switching branches.
    ///
    /// ## Example
    ///
    /// ```swift
    /// print(repository.currentBranch)  // "main"
    ///
    /// // After checking out feature branch
    /// try await gitService.checkout(repository: repository, branch: "feature/new-scene")
    /// print(repository.currentBranch)  // "feature/new-scene"
    /// ```
    public var currentBranch: String

    /// Timestamp of last successful fetch/pull operation
    ///
    /// Updated automatically by `GitProjectService.pull()` and `GitProjectService.fetch()`.
    /// Useful for displaying "last synced" information to users.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let lastSync = repository.lastSync {
    ///     let formatter = RelativeDateTimeFormatter()
    ///     print("Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))")
    /// }
    /// ```
    public var lastSync: Date?

    /// Indicates whether Git LFS is enabled for this repository
    ///
    /// Automatically detected during clone/fetch by checking for:
    /// - `.gitattributes` with LFS filter configuration
    /// - `.git/hooks/pre-push` LFS hooks
    /// - LFS pointer files in repository
    ///
    /// When `true`, `GitProjectService` will automatically fetch LFS files
    /// using either CLI (`git lfs pull`) on macOS or native implementation.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if repository.lfsEnabled {
    ///     try await gitService.fetchLFS(repository: repository) { progress, message in
    ///         print("LFS: \(Int(progress * 100))% - \(message)")
    ///     }
    /// }
    /// ```
    public var lfsEnabled: Bool

    /// Associated screenplay document (optional)
    ///
    /// When a screenplay is imported from this repository, the document
    /// is linked here for bidirectional navigation.
    ///
    /// **Delete Rule**: `.nullify` - Deleting the repository does NOT delete
    /// the document. The document becomes a standalone file.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let document = try await gitService.importDocument(repository: repository)
    /// repository.document = document
    /// document.gitRepository = repository
    ///
    /// // Later: export changes back to repo
    /// try await document.exportToGit(repository: repository)
    /// ```
    @Relationship(deleteRule: .nullify)
    public var document: GuionDocumentModel?

    /// LFS file patterns tracked in this repository
    ///
    /// Stores file patterns (e.g., "*.mp3", "*.wav") configured in `.gitattributes`
    /// for Git LFS tracking. These patterns determine which files are stored as
    /// LFS pointers rather than full content in the Git repository.
    ///
    /// Automatically synchronized with `.gitattributes` by `GitProjectService`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// for pattern in repository.lfsFiles {
    ///     print("LFS tracked: \(pattern)")
    /// }
    /// // Output:
    /// // LFS tracked: *.mp3
    /// // LFS tracked: *.wav
    /// // LFS tracked: *.mp4
    /// ```
    public var lfsFiles: [String]

    /// Cached commit history (optional)
    ///
    /// Stores metadata about commits for performance (avoids querying Git repeatedly).
    /// Populated by `GitProjectService.fetchCommitHistory()`.
    ///
    /// **Delete Rule**: `.cascade` - Deleting the repository automatically deletes
    /// all commit records.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fetch and cache commit history
    /// try await gitService.fetchCommitHistory(repository: repository, limit: 50)
    ///
    /// // Display cached commits
    /// for commit in repository.commits {
    ///     print("\(commit.sha.prefix(7)) - \(commit.message)")
    /// }
    /// ```
    @Relationship(deleteRule: .cascade)
    public var commits: [GitCommitModel]

    // MARK: - Initialization

    /// Creates a new Git repository model
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - localPath: File system path where repository is cloned
    ///   - remoteURL: Remote repository URL (optional for local-only repos)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let repoID = UUID()
    /// let storage = StorageAreaReference.persistent(
    ///     requestID: repoID,
    ///     folderName: "git-repositories"
    /// )
    ///
    /// let repository = GitRepositoryModel(
    ///     id: repoID,
    ///     localPath: storage.folderURL.path,
    ///     remoteURL: "https://github.com/user/screenplay.git"
    /// )
    ///
    /// modelContext.insert(repository)
    /// try modelContext.save()
    /// ```
    public init(
        id: UUID = UUID(),
        localPath: String,
        remoteURL: String? = nil
    ) {
        self.id = id
        self.localPath = localPath
        self.remoteURL = remoteURL
        self.currentBranch = "main"
        self.lastSync = nil
        self.lfsEnabled = false
        self.lfsFiles = []
        self.commits = []
    }

    // MARK: - Validation

    /// Validates repository state
    ///
    /// Checks for:
    /// - Local path exists and is accessible
    /// - `.git` directory exists in local path
    /// - Remote URL is valid (if present)
    ///
    /// - Throws: `GitProjectError` if validation fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     try repository.validate()
    ///     print("Repository is valid")
    /// } catch {
    ///     print("Validation failed: \(error)")
    /// }
    /// ```
    public func validate() throws {
        // Check local path exists
        let localURL = URL(fileURLWithPath: localPath)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: localURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw GitProjectError.repositoryNotFound(localPath)
        }

        // Check .git directory exists
        let gitDir = localURL.appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw GitProjectError.notAGitRepository(localPath)
        }

        // Validate remote URL if present
        if let remoteURL = remoteURL {
            guard isValidGitURL(remoteURL) else {
                throw GitProjectError.invalidRemoteURL(remoteURL)
            }
        }
    }

    private func isValidGitURL(_ urlString: String) -> Bool {
        // Allow HTTPS and SSH URLs
        return urlString.hasPrefix("https://") ||
               urlString.hasPrefix("http://") ||
               urlString.hasPrefix("git@") ||
               urlString.hasPrefix("ssh://")
    }
}

// MARK: - GitProjectError

/// Errors that can occur during Git repository operations
public enum GitProjectError: Error, LocalizedError {
    case repositoryNotFound(String)
    case notAGitRepository(String)
    case invalidRemoteURL(String)
    case notGitTracked
    case authenticationFailed
    case networkUnavailable
    case mergeConflict([String])
    case invalidPath

    public var errorDescription: String? {
        switch self {
        case .repositoryNotFound(let path):
            return "Repository not found at path: \(path)"
        case .notAGitRepository(let path):
            return "Directory is not a Git repository: \(path)"
        case .invalidRemoteURL(let url):
            return "Invalid remote URL: \(url)"
        case .notGitTracked:
            return "Document is not associated with a Git repository"
        case .authenticationFailed:
            return "Git authentication failed. Check your credentials."
        case .networkUnavailable:
            return "Network unavailable. Git operations require an internet connection."
        case .mergeConflict(let files):
            return "Merge conflict in \(files.count) file(s): \(files.joined(separator: ", "))"
        case .invalidPath:
            return "Invalid repository path"
        }
    }
}

#endif
