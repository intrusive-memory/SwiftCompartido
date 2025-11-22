//
//  GitDiffView.swift
//  SwiftCompartido
//
//  Visual diff view for comparing branches or commits.
//

import SwiftUI
import SwiftData

/// Visual diff view for comparing changes between branches.
///
/// Shows changed files with visual indicators for additions, deletions, and modifications.
/// Designed for screenplay-specific diff viewing.
///
/// ## Example Usage
///
/// ```swift
/// struct CompareView: View {
///     let repository: GitRepositoryModel
///
///     var body: some View {
///         GitDiffView(
///             repository: repository,
///             baseBranch: "main",
///             compareBranch: "feature/new-scene"
///         )
///     }
/// }
/// ```
public struct GitDiffView: View {

    // MARK: - Types

    enum ChangeType {
        case added
        case modified
        case deleted

        var color: Color {
            switch self {
            case .added: return .green
            case .modified: return .orange
            case .deleted: return .red
            }
        }

        var icon: String {
            switch self {
            case .added: return "plus.circle.fill"
            case .modified: return "pencil.circle.fill"
            case .deleted: return "minus.circle.fill"
            }
        }
    }

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var changedFiles: [String] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    // MARK: - Properties

    /// The repository to compare in
    public let repository: GitRepositoryModel

    /// The base branch for comparison
    public let baseBranch: String

    /// The branch to compare against base
    public let compareBranch: String

    // MARK: - Initialization

    /// Creates a new diff view.
    ///
    /// - Parameters:
    ///   - repository: The repository
    ///   - baseBranch: The base branch
    ///   - compareBranch: The branch to compare
    public init(
        repository: GitRepositoryModel,
        baseBranch: String,
        compareBranch: String
    ) {
        self.repository = repository
        self.baseBranch = baseBranch
        self.compareBranch = compareBranch
    }

    // MARK: - Body

    public var body: some View {
        List {
            // Comparison info section
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Base")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(baseBranch)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("Compare")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(compareBranch)
                            .fontWeight(.medium)
                    }
                }
            }

            // Changed files section
            if isLoading {
                Section {
                    ProgressView("Loading changes...")
                }
            } else if changedFiles.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("No Differences")
                            .font(.headline)
                        Text("These branches are identical")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else {
                Section {
                    ForEach(changedFiles, id: \.self) { file in
                        FileChangeRow(
                            fileName: file,
                            changeType: determineChangeType(for: file)
                        )
                    }
                } header: {
                    Text("\(changedFiles.count) Changed Files")
                }
            }

            // Error section
            if let error = errorMessage {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("Compare Branches")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadDiff() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .task {
            await loadDiff()
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadDiff() async {
        isLoading = true
        errorMessage = nil

        do {
            let service = GitProjectService()
            changedFiles = try await service.diff(
                from: baseBranch,
                to: compareBranch,
                in: repository
            )
            isLoading = false
        } catch {
            errorMessage = "Failed to load diff: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func determineChangeType(for file: String) -> ChangeType {
        // Simplified - in real implementation, check git status
        // For now, assume all are modifications
        return .modified
    }
}

// MARK: - File Change Row

private struct FileChangeRow: View {
    let fileName: String
    let changeType: GitDiffView.ChangeType

    var body: some View {
        HStack {
            Image(systemName: changeType.icon)
                .foregroundStyle(changeType.color)

            VStack(alignment: .leading) {
                Text(fileName)
                    .font(.body)

                Text(changeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var changeLabel: String {
        switch changeType {
        case .added: return "Added"
        case .modified: return "Modified"
        case .deleted: return "Deleted"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Diff View") {
    NavigationStack {
        GitDiffView(
            repository: GitRepositoryModel(
                localPath: "/Users/user/screenplay",
                remoteURL: "https://github.com/user/screenplay.git"
            ),
            baseBranch: "main",
            compareBranch: "feature/new-scene"
        )
    }
    .modelContainer(for: [GitRepositoryModel.self], inMemory: true)
}
#endif
