//
//  GitCommitModel.swift
//  SwiftCompartido
//
//  Copyright (c) 2025
//

import Foundation
#if canImport(SwiftData)
import SwiftData

/// SwiftData model representing a Git commit in a repository's history.
///
/// This model stores metadata about individual commits, including SHA, message,
/// author information, and timestamp. Commits are optionally cached in SwiftData
/// for performance when displaying commit history.
///
/// ## Overview
///
/// `GitCommitModel` provides a persistent cache of Git commit metadata, avoiding
/// repeated queries to the Git repository. Commits are linked to their parent
/// `GitRepositoryModel` via a cascade delete relationship.
///
/// ## Features
///
/// - **Commit Metadata**: SHA, message, author, timestamp
/// - **SwiftData Integration**: Automatic persistence with parent repository
/// - **Cascade Delete**: Automatically deleted when repository is deleted
/// - **Query Optimization**: Fast access to commit history without Git queries
///
/// ## Example - Creating Commits
///
/// ```swift
/// let service = GitProjectService(modelContext: modelContext)
///
/// // Create a commit
/// let commit = try await service.commit(
///     repository: repository,
///     message: "Add Act 2 dialogue revisions"
/// )
///
/// print("Created commit: \(commit.sha)")
/// print("Author: \(commit.authorName) <\(commit.authorEmail)>")
/// print("Message: \(commit.message)")
/// ```
///
/// ## Example - Fetching History
///
/// ```swift
/// // Fetch and cache commit history
/// try await service.fetchCommitHistory(repository: repository, limit: 50)
///
/// // Display cached commits
/// for commit in repository.commits.sorted(by: { $0.timestamp > $1.timestamp }) {
///     print("\(commit.sha.prefix(7)) - \(commit.message)")
///     print("  by \(commit.authorName) on \(commit.timestamp.formatted())")
/// }
/// ```
///
/// ## Example - Filtering Commits
///
/// ```swift
/// // Find commits by author
/// let myCommits = repository.commits.filter { $0.authorEmail == "user@example.com" }
///
/// // Find recent commits
/// let recentCommits = repository.commits.filter {
///     $0.timestamp > Date().addingTimeInterval(-7 * 24 * 60 * 60)  // Last 7 days
/// }
/// ```
///
/// ## Topics
///
/// ### Creating Commits
/// - ``init(sha:message:authorName:authorEmail:timestamp:)``
///
/// ### Commit Properties
/// - ``sha``
/// - ``message``
/// - ``authorName``
/// - ``authorEmail``
/// - ``timestamp``
///
/// ### Relationships
/// - ``repository``
///
/// ### Formatting
/// - ``shortSHA``
/// - ``formattedMessage``
@Model
public final class GitCommitModel: @unchecked Sendable {
    /// Git commit SHA (full 40-character hash)
    ///
    /// Example: `"a3f5b2c1e8d9f7a6b4c3e2d1f0a9b8c7d6e5f4a3"`
    ///
    /// The SHA is marked as unique to prevent duplicate commits in the cache.
    ///
    /// ## Example
    ///
    /// ```swift
    /// print(commit.sha)           // Full SHA
    /// print(commit.shortSHA)      // First 7 characters
    /// ```
    @Attribute(.unique)
    public var sha: String

    /// Commit message (first line)
    ///
    /// For multi-line commit messages, this contains only the first line (subject).
    /// Full commit body can be queried from Git if needed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// commit.message = "Add new scene in coffee shop"
    /// // In Git: "Add new scene in coffee shop\n\nThis scene introduces the protagonist..."
    /// ```
    public var message: String

    /// Author name from Git config
    ///
    /// Example: `"Jane Doe"`
    ///
    /// Extracted from `git config user.name` at commit time.
    public var authorName: String

    /// Author email from Git config
    ///
    /// Example: `"jane@example.com"`
    ///
    /// Extracted from `git config user.email` at commit time.
    public var authorEmail: String

    /// Timestamp when commit was created
    ///
    /// Uses the commit's author date (not committer date).
    ///
    /// ## Example
    ///
    /// ```swift
    /// let formatter = RelativeDateTimeFormatter()
    /// print(formatter.localizedString(for: commit.timestamp, relativeTo: Date()))
    /// // "2 hours ago"
    /// ```
    public var timestamp: Date

    /// Parent repository (optional)
    ///
    /// Links this commit to its repository. When the repository is deleted,
    /// all associated commits are automatically deleted (cascade).
    ///
    /// **Delete Rule**: `.nullify` - Deleting a commit does NOT delete the repository.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let repo = commit.repository {
    ///     print("Commit in repository: \(repo.remoteURL ?? "local")")
    /// }
    /// ```
    @Relationship(deleteRule: .nullify)
    public var repository: GitRepositoryModel?

    // MARK: - Initialization

    /// Creates a new Git commit model
    ///
    /// - Parameters:
    ///   - sha: Full 40-character commit SHA
    ///   - message: Commit message (first line)
    ///   - authorName: Author's name from Git config
    ///   - authorEmail: Author's email from Git config
    ///   - timestamp: Commit creation timestamp
    ///
    /// ## Example
    ///
    /// ```swift
    /// let commit = GitCommitModel(
    ///     sha: "a3f5b2c1e8d9f7a6b4c3e2d1f0a9b8c7d6e5f4a3",
    ///     message: "Add Act 2 dialogue",
    ///     authorName: "Jane Doe",
    ///     authorEmail: "jane@example.com",
    ///     timestamp: Date()
    /// )
    ///
    /// commit.repository = repository
    /// modelContext.insert(commit)
    /// try modelContext.save()
    /// ```
    public init(
        sha: String,
        message: String,
        authorName: String,
        authorEmail: String,
        timestamp: Date
    ) {
        self.sha = sha
        self.message = message
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.timestamp = timestamp
    }

    // MARK: - Convenience Properties

    /// Shortened SHA (first 7 characters)
    ///
    /// Standard Git short SHA format for display purposes.
    ///
    /// ## Example
    ///
    /// ```swift
    /// print(commit.shortSHA)  // "a3f5b2c"
    /// ```
    public var shortSHA: String {
        String(sha.prefix(7))
    }

    /// Formatted commit message with author and date
    ///
    /// Example: `"a3f5b2c - Add Act 2 dialogue (Jane Doe, 2 hours ago)"`
    ///
    /// ## Example
    ///
    /// ```swift
    /// print(commit.formattedMessage)
    /// // "a3f5b2c - Add Act 2 dialogue (Jane Doe, 2 hours ago)"
    /// ```
    public var formattedMessage: String {
        let formatter = RelativeDateTimeFormatter()
        let relativeTime = formatter.localizedString(for: timestamp, relativeTo: Date())
        return "\(shortSHA) - \(message) (\(authorName), \(relativeTime))"
    }
}

#endif
