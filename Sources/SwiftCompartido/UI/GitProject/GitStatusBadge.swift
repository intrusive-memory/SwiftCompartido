//
//  GitStatusBadge.swift
//  SwiftCompartido
//
//  Compact badge showing Git repository status.
//

import SwiftUI
import SwiftData

/// Compact badge displaying Git repository sync status.
///
/// Shows current branch, modified files count, and sync status indicators.
/// Designed for display in document metadata panels and list rows.
///
/// ## Example Usage
///
/// ```swift
/// struct DocumentMetadataView: View {
///     let document: GuionDocumentModel
///
///     var body: some View {
///         VStack {
///             if let repository = document.gitRepository {
///                 GitStatusBadge(repository: repository)
///             }
///         }
///     }
/// }
/// ```
public struct GitStatusBadge: View {

    // MARK: - Properties

    /// The repository to display status for
    public let repository: GitRepositoryModel

    /// Whether to show detailed status
    public var detailed: Bool = false

    // MARK: - Initialization

    /// Creates a new Git status badge.
    ///
    /// - Parameters:
    ///   - repository: The repository to display status for
    ///   - detailed: Whether to show detailed status (default: false)
    public init(repository: GitRepositoryModel, detailed: Bool = false) {
        self.repository = repository
        self.detailed = detailed
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 8) {
            // Git icon
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.secondary)

            // Branch name
            Text(repository.currentBranch)
                .font(.caption)
                .fontWeight(.medium)

            // LFS indicator
            if repository.lfsEnabled {
                Image(systemName: "externaldrive.fill")
                    .foregroundStyle(.blue)
                    .help("Git LFS Enabled")
            }

            // Last sync time
            if let lastSync = repository.lastSync {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.green)
                    .help("Last synced \(lastSync, style: .relative)")
            }
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.5))
        .cornerRadius(6)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Clean Status") {
    GitStatusBadge(repository: GitRepositoryModel(
        localPath: "/Users/user/screenplay",
        remoteURL: "https://github.com/user/screenplay.git"
    ))
    .modelContainer(for: [GitRepositoryModel.self], inMemory: true)
    .padding()
}

#Preview("With Changes") {
    GitStatusBadge(repository: GitRepositoryModel(
        localPath: "/Users/user/screenplay",
        remoteURL: "https://github.com/user/screenplay.git"
    ))
    .modelContainer(for: [GitRepositoryModel.self], inMemory: true)
    .padding()
}
#endif
