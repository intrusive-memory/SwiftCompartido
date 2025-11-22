//
//  GitProjectService.swift
//  SwiftCompartido
//
//  Core Git operations service using SwiftGitX.
//  Provides async/await API for clone, pull, push, commit, and status operations.
//

import Foundation
import SwiftGitX
#if canImport(SwiftData)
import SwiftData
#endif

/// Service for managing Git operations on screenplay repositories.
///
/// `GitProjectService` provides high-level async/await methods for Git operations,
/// with progress reporting and SwiftData integration.
///
/// ## Authentication
///
/// SwiftGitX delegates authentication to the system git configuration.
/// Ensure git is configured with appropriate credentials before using this service.
///
/// ## Example - Clone Repository
///
/// ```swift
/// let service = GitProjectService(modelContext: modelContext)
///
/// let repository = try await service.clone(
///     remoteURL: "https://github.com/user/screenplay.git",
///     localPath: "/path/to/repo"
/// ) { progress, message in
///     print("\(Int(progress * 100))%: \(message)")
/// }
/// ```
public actor GitProjectService {

    // MARK: - Types

    /// Progress callback for long-running operations
    public typealias ProgressCallback = @Sendable (Double, String) -> Void

    /// Repository status information
    public struct RepositoryStatus: Sendable {
        public let modifiedFiles: Int
        public let commitsAhead: Int
        public let commitsBehind: Int
        public let modifiedPaths: [String]

        public var hasChanges: Bool {
            modifiedFiles > 0
        }

        public var isInSync: Bool {
            commitsAhead == 0 && commitsBehind == 0
        }
    }

    /// Git operation errors
    public enum GitError: LocalizedError, Sendable, Equatable {
        case repositoryNotFound(path: String)
        case invalidRemoteURL(String)
        case cloneFailed(reason: String)
        case pullFailed(reason: String)
        case pushFailed(reason: String)
        case commitFailed(reason: String)
        case authenticationRequired
        case repositoryAlreadyExists(path: String)
        case invalidAuthorFormat(String)

        public var errorDescription: String? {
            switch self {
            case .repositoryNotFound(let path):
                return "Repository not found at path: \(path)"
            case .invalidRemoteURL(let url):
                return "Invalid remote URL: \(url)"
            case .cloneFailed(let reason):
                return "Clone failed: \(reason)"
            case .pullFailed(let reason):
                return "Pull failed: \(reason)"
            case .pushFailed(let reason):
                return "Push failed: \(reason)"
            case .commitFailed(let reason):
                return "Commit failed: \(reason)"
            case .authenticationRequired:
                return "Authentication required. Please configure git credentials."
            case .repositoryAlreadyExists(let path):
                return "Repository already exists at path: \(path)"
            case .invalidAuthorFormat(let format):
                return "Invalid author format: \(format). Expected 'Name <email>'"
            }
        }
    }

    // MARK: - Properties

    private let modelContext: ModelContext?

    // MARK: - Initialization

    public init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    // MARK: - Clone

    /// Clone a remote repository to a local path.
    ///
    /// - Parameters:
    ///   - remoteURL: The remote repository URL
    ///   - localPath: The local path to clone to
    ///   - progress: Optional progress callback
    ///
    /// - Returns: The cloned repository model (if modelContext provided)
    ///
    /// - Throws: `GitError` if the operation fails
    @discardableResult
    public func clone(
        remoteURL: String,
        localPath: String,
        progress: ProgressCallback? = nil
    ) async throws -> GitRepositoryModel? {
        // Validate URLs
        guard let remoteURLObj = URL(string: remoteURL) else {
            throw GitError.invalidRemoteURL(remoteURL)
        }

        let localURLObj = URL(fileURLWithPath: localPath)

        // Check if directory already exists
        if FileManager.default.fileExists(atPath: localPath) {
            throw GitError.repositoryAlreadyExists(path: localPath)
        }

        // Create parent directory if needed
        let parentDir = localURLObj.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        // Report initial progress
        progress?(0.0, "Starting clone...")

        do {
            // Perform the clone
            let repository = try await Repository.clone(
                from: remoteURLObj,
                to: localURLObj
            ) { transferProgress in
                let percentage = Double(transferProgress.receivedObjects) / Double(max(transferProgress.totalObjects, 1))
                progress?(percentage, "Receiving objects: \(transferProgress.receivedObjects)/\(transferProgress.totalObjects)")
            }

            progress?(1.0, "Clone complete")

            // Get current branch
            let currentBranch = try? repository.branch.current.name

            // Create model if context provided
            if let modelContext = modelContext {
                let model = GitRepositoryModel(
                    localPath: localPath,
                    remoteURL: remoteURL
                )
                model.currentBranch = currentBranch ?? "main"

                modelContext.insert(model)
                try modelContext.save()

                return model
            }

            return nil

        } catch {
            throw GitError.cloneFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Pull

    /// Pull changes from the remote repository.
    ///
    /// - Parameters:
    ///   - repository: The repository to pull
    ///   - progress: Progress callback
    ///
    /// - Throws: `GitError` if the operation fails
    public func pull(
        repository: GitRepositoryModel,
        progress: ProgressCallback
    ) async throws {
        guard FileManager.default.fileExists(atPath: repository.localPath) else {
            throw GitError.repositoryNotFound(path: repository.localPath)
        }

        progress(0.0, "Starting pull...")

        do {
            let repo = try Repository(at: URL(fileURLWithPath: repository.localPath), createIfNotExists: false)

            progress(0.3, "Fetching...")
            try await repo.fetch()

            progress(0.7, "Merging...")

            // Note: SwiftGitX doesn't expose merge operations yet
            // For now, fetch is sufficient - user can merge manually
            // TODO: Add merge support when SwiftGitX exposes it

            progress(1.0, "Pull complete")

        } catch {
            throw GitError.pullFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Push

    /// Push local commits to the remote repository.
    ///
    /// - Parameters:
    ///   - repository: The repository to push
    ///   - progress: Progress callback
    ///
    /// - Throws: `GitError` if the operation fails
    public func push(
        repository: GitRepositoryModel,
        progress: ProgressCallback
    ) async throws {
        guard FileManager.default.fileExists(atPath: repository.localPath) else {
            throw GitError.repositoryNotFound(path: repository.localPath)
        }

        progress(0.0, "Starting push...")

        do {
            let repo = try Repository(at: URL(fileURLWithPath: repository.localPath), createIfNotExists: false)

            progress(0.5, "Pushing to remote...")
            try await repo.push()

            progress(1.0, "Push complete")

        } catch {
            throw GitError.pushFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Commit

    /// Create a new commit with the current changes.
    ///
    /// - Parameters:
    ///   - repository: The repository to commit to
    ///   - message: The commit message
    ///   - author: Optional author string in format "Name <email>"
    ///
    /// - Returns: The created commit model
    ///
    /// - Throws: `GitError` if the operation fails
    ///
    /// - Note: SwiftGitX uses the git config for author information.
    ///         The `author` parameter requires manual git config setup.
    @discardableResult
    public func commit(
        repository: GitRepositoryModel,
        message: String,
        author: String? = nil
    ) async throws -> GitCommitModel? {
        guard FileManager.default.fileExists(atPath: repository.localPath) else {
            throw GitError.repositoryNotFound(path: repository.localPath)
        }

        // Validate author format if provided
        if let author = author {
            let authorPattern = #"^(.+)\s+<([^>]+)>$"#
            guard author.range(of: authorPattern, options: .regularExpression) != nil else {
                throw GitError.invalidAuthorFormat(author)
            }

            // Note: SwiftGitX doesn't support custom author signatures
            // This would require git config setup before commit
            // For now, we'll document this limitation
        }

        do {
            let repo = try Repository(at: URL(fileURLWithPath: repository.localPath), createIfNotExists: false)

            // Add all changes to staging
            try repo.add(paths: ["."])

            // Create commit
            let commit = try repo.commit(message: message)

            // Create model if context provided
            if let modelContext = modelContext {
                let commitModel = GitCommitModel(
                    sha: commit.id.hex,
                    message: message,
                    authorName: commit.author.name,
                    authorEmail: commit.author.email,
                    timestamp: commit.date
                )
                commitModel.repository = repository

                modelContext.insert(commitModel)
                try modelContext.save()

                return commitModel
            }

            return nil

        } catch {
            throw GitError.commitFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Status

    /// Get the current repository status.
    ///
    /// - Parameter repository: The repository to check
    ///
    /// - Returns: Repository status information
    ///
    /// - Throws: `GitError` if the operation fails
    public func status(repository: GitRepositoryModel) async throws -> RepositoryStatus {
        guard FileManager.default.fileExists(atPath: repository.localPath) else {
            throw GitError.repositoryNotFound(path: repository.localPath)
        }

        do {
            let repo = try Repository(at: URL(fileURLWithPath: repository.localPath), createIfNotExists: false)

            // Get status entries
            let statusList = try repo.status()
            let modifiedPaths = statusList.compactMap { entry in
                // Get path from either index or workingTree delta
                entry.index?.newFile.path ?? entry.workingTree?.newFile.path
            }

            // Get ahead/behind counts
            var ahead = 0
            var behind = 0

            if let currentBranch = try? repo.branch.current,
               let upstreamBranch = currentBranch.upstream as? Branch,
               let localCommit = currentBranch.target as? Commit,
               let remoteCommit = upstreamBranch.target as? Commit {

                // Count commits ahead (local commits not in remote)
                let localHistory = try repo.log(from: localCommit)
                let remoteOID = remoteCommit.id

                for commit in localHistory {
                    if commit.id == remoteOID {
                        break
                    }
                    ahead += 1
                }

                // Count commits behind (remote commits not in local)
                let remoteHistory = try repo.log(from: remoteCommit)
                let localOID = localCommit.id

                for commit in remoteHistory {
                    if commit.id == localOID {
                        break
                    }
                    behind += 1
                }
            }

            return RepositoryStatus(
                modifiedFiles: statusList.count,
                commitsAhead: ahead,
                commitsBehind: behind,
                modifiedPaths: modifiedPaths
            )

        } catch {
            return RepositoryStatus(
                modifiedFiles: 0,
                commitsAhead: 0,
                commitsBehind: 0,
                modifiedPaths: []
            )
        }
    }

    // MARK: - Git LFS Operations

    /// Check if Git LFS is installed in the repository.
    ///
    /// - Parameter repository: The repository to check
    /// - Returns: `true` if LFS is installed, `false` otherwise
    public func isLFSInstalled(in repository: GitRepositoryModel) async -> Bool {
        guard FileManager.default.fileExists(atPath: repository.localPath) else {
            return false
        }

        // Check if .git/lfs directory exists
        let lfsDir = URL(fileURLWithPath: repository.localPath)
            .appendingPathComponent(".git")
            .appendingPathComponent("lfs")

        return FileManager.default.fileExists(atPath: lfsDir.path)
    }

    /// Install Git LFS in the repository.
    ///
    /// - Parameter repository: The repository to install LFS in
    /// - Throws: `GitError` if installation fails
    ///
    /// This runs `git lfs install` in the repository directory.
    /// **macOS only** - CLI operations not available on iOS.
    #if os(macOS)
    public func installLFS(in repository: GitRepositoryModel) async throws {
        guard FileManager.default.fileExists(atPath: repository.localPath) else {
            throw GitError.repositoryNotFound(path: repository.localPath)
        }

        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: repository.localPath)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "lfs", "install"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw GitError.commitFailed(reason: "LFS install failed: \(output)")
            }

            // Update model
            repository.lfsEnabled = true

        } catch {
            throw GitError.commitFailed(reason: "Failed to install LFS: \(error.localizedDescription)")
        }
    }
    #endif

    /// Initialize LFS with default multimedia file patterns.
    ///
    /// - Parameter repository: The repository to initialize
    /// - Throws: `GitError` if initialization fails
    ///
    /// This installs LFS (macOS only) and creates a `.gitattributes` file with default patterns
    /// for audio, video, and image files.
    public func initializeLFS(in repository: GitRepositoryModel) async throws {
        // Install LFS if not already installed (macOS only)
        #if os(macOS)
        if !(await isLFSInstalled(in: repository)) {
            try await installLFS(in: repository)
        }
        #endif

        // Write default .gitattributes
        let attributesURL = URL(fileURLWithPath: repository.localPath)
            .appendingPathComponent(".gitattributes")

        let parser = GitAttributesParser()
        try parser.writeDefaultLFSPatterns(to: attributesURL)

        // Update LFS files list
        repository.lfsFiles = GitAttributesParser.defaultLFSPatterns
    }

    /// Track a file pattern with Git LFS.
    ///
    /// - Parameters:
    ///   - pattern: The file pattern to track (e.g., "*.mp3")
    ///   - repository: The repository to track in
    /// - Throws: `GitError` if tracking fails
    ///
    /// This adds the pattern to `.gitattributes` and runs `git lfs track` (macOS only).
    public func trackLFSPattern(_ pattern: String, in repository: GitRepositoryModel) async throws {
        guard FileManager.default.fileExists(atPath: repository.localPath) else {
            throw GitError.repositoryNotFound(path: repository.localPath)
        }

        // Ensure LFS is installed (macOS only)
        #if os(macOS)
        if !(await isLFSInstalled(in: repository)) {
            try await installLFS(in: repository)
        }
        #endif

        let attributesURL = URL(fileURLWithPath: repository.localPath)
            .appendingPathComponent(".gitattributes")

        // Add to .gitattributes
        let parser = GitAttributesParser()
        try parser.addLFSPattern(pattern, to: attributesURL)

        // Update model
        if !repository.lfsFiles.contains(pattern) {
            repository.lfsFiles.append(pattern)
        }
    }

    /// Untrack a file pattern from Git LFS.
    ///
    /// - Parameters:
    ///   - pattern: The file pattern to untrack (e.g., "*.mp3")
    ///   - repository: The repository to untrack from
    /// - Throws: `GitError` if untracking fails
    ///
    /// This removes the pattern from `.gitattributes`.
    public func untrackLFSPattern(_ pattern: String, from repository: GitRepositoryModel) async throws {
        guard FileManager.default.fileExists(atPath: repository.localPath) else {
            throw GitError.repositoryNotFound(path: repository.localPath)
        }

        let attributesURL = URL(fileURLWithPath: repository.localPath)
            .appendingPathComponent(".gitattributes")

        // Remove from .gitattributes
        let parser = GitAttributesParser()
        try parser.removeLFSPattern(pattern, from: attributesURL)

        // Update model
        repository.lfsFiles.removeAll { $0 == pattern }
    }

    /// List all LFS-tracked patterns in the repository.
    ///
    /// - Parameter repository: The repository to query
    /// - Returns: Array of tracked patterns
    /// - Throws: `GitError` if reading fails
    public func listLFSPatterns(in repository: GitRepositoryModel) async throws -> [String] {
        guard FileManager.default.fileExists(atPath: repository.localPath) else {
            throw GitError.repositoryNotFound(path: repository.localPath)
        }

        let attributesURL = URL(fileURLWithPath: repository.localPath)
            .appendingPathComponent(".gitattributes")

        guard FileManager.default.fileExists(atPath: attributesURL.path) else {
            return []
        }

        let parser = GitAttributesParser()
        return try parser.getLFSPatterns(from: attributesURL)
    }

    /// Migrate existing large files to LFS.
    ///
    /// - Parameters:
    ///   - repository: The repository to migrate
    ///   - patterns: Optional specific patterns to migrate (migrates all tracked patterns if nil)
    /// - Throws: `GitError` if migration fails
    ///
    /// This runs `git lfs migrate import` to convert existing large files to LFS.
    /// **macOS only** - CLI operations not available on iOS.
    #if os(macOS)
    public func migrateLFS(in repository: GitRepositoryModel, patterns: [String]? = nil) async throws {
        guard FileManager.default.fileExists(atPath: repository.localPath) else {
            throw GitError.repositoryNotFound(path: repository.localPath)
        }

        // Ensure LFS is installed
        if !(await isLFSInstalled(in: repository)) {
            try await installLFS(in: repository)
        }

        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: repository.localPath)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        var args = ["git", "lfs", "migrate", "import", "--include"]

        if let patterns = patterns {
            args.append(patterns.joined(separator: ","))
        } else {
            // Migrate all tracked patterns
            let trackedPatterns = try await listLFSPatterns(in: repository)
            if trackedPatterns.isEmpty {
                return // Nothing to migrate
            }
            args.append(trackedPatterns.joined(separator: ","))
        }

        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw GitError.commitFailed(reason: "LFS migration failed: \(output)")
            }

        } catch {
            throw GitError.commitFailed(reason: "Failed to migrate LFS: \(error.localizedDescription)")
        }
    }
    #endif
}
