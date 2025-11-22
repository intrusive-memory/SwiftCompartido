//
//  GitCommitHistoryView.swift
//  SwiftCompartido
//
//  Display commit history with filtering and search capabilities.
//

import SwiftUI
import SwiftData

/// Display commit history for a Git repository.
///
/// Shows commits with filtering by author, date range, and search.
/// Each commit displays SHA, message, author, timestamp, and file count.
///
/// ## Example Usage
///
/// ```swift
/// struct RepositoryView: View {
///     let repository: GitRepositoryModel
///
///     var body: some View {
///         GitCommitHistoryView(repository: repository)
///     }
/// }
/// ```
public struct GitCommitHistoryView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var commits: [GitCommitModel] = []
    @State private var isLoading: Bool = false
    @State private var searchText: String = ""
    @State private var selectedDateRange: DateRange = .all
    @State private var errorMessage: String?

    // MARK: - Properties

    /// The repository to display commits for
    public let repository: GitRepositoryModel

    // MARK: - Types

    private enum DateRange: String, CaseIterable {
        case all = "All Time"
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"

        var date: Date? {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .all:
                return nil
            case .today:
                return calendar.startOfDay(for: now)
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: now)
            case .month:
                return calendar.date(byAdding: .month, value: -1, to: now)
            case .year:
                return calendar.date(byAdding: .year, value: -1, to: now)
            }
        }
    }

    // MARK: - Initialization

    /// Creates a new commit history view.
    ///
    /// - Parameter repository: The repository to display commits for
    public init(repository: GitRepositoryModel) {
        self.repository = repository
    }

    // MARK: - Body

    public var body: some View {
        List {
            // Filter controls
            Section {
                Picker("Time Range", selection: $selectedDateRange) {
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Commits list
            if isLoading {
                loadingSection
            } else if filteredCommits.isEmpty {
                emptySection
            } else {
                commitsSection
            }

            // Error display
            if let error = errorMessage {
                errorSection(error)
            }
        }
        .navigationTitle("Commit History")
        .searchable(text: $searchText, prompt: "Search commits, authors...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await loadCommits()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .task {
            await loadCommits()
        }
    }

    // MARK: - View Sections

    private var loadingSection: some View {
        Section {
            HStack {
                ProgressView()
                Text("Loading commits...")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptySection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text("No commits found")
                    .font(.headline)

                if !searchText.isEmpty {
                    Text("Try adjusting your search or filters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }

    private var commitsSection: some View {
        Section {
            ForEach(filteredCommits) { commit in
                CommitRow(commit: commit)
            }
        } header: {
            Text("\(filteredCommits.count) commits")
        }
    }

    private func errorSection(_ error: String) -> some View {
        Section {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Filtered Commits

    private var filteredCommits: [GitCommitModel] {
        var filtered = commits

        // Filter by date range
        if let rangeDate = selectedDateRange.date {
            filtered = filtered.filter { $0.timestamp >= rangeDate }
        }

        // Filter by search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter {
                $0.message.lowercased().contains(searchLower) ||
                $0.authorName.lowercased().contains(searchLower) ||
                $0.authorEmail.lowercased().contains(searchLower) ||
                $0.sha.lowercased().contains(searchLower)
            }
        }

        return filtered
    }

    // MARK: - Data Loading

    @MainActor
    private func loadCommits() async {
        isLoading = true
        errorMessage = nil

        // Load commits from cached data in SwiftData
        // In a real implementation, you might also refresh from git
        commits = repository.commits.sorted { $0.timestamp > $1.timestamp }

        isLoading = false
    }
}

// MARK: - Commit Row

private struct CommitRow: View {
    let commit: GitCommitModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // SHA and timestamp
            HStack {
                Text(commit.sha.prefix(7))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(commit.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Commit message
            Text(commit.message)
                .font(.body)
                .lineLimit(2)

            // Author info
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(commit.authorName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                #if os(iOS)
                UIPasteboard.general.string = commit.sha
                #elseif os(macOS)
                NSPasteboard.general.setString(commit.sha, forType: .string)
                #endif
            } label: {
                Label("Copy SHA", systemImage: "doc.on.doc")
            }

            Button {
                #if os(iOS)
                UIPasteboard.general.string = commit.message
                #elseif os(macOS)
                NSPasteboard.general.setString(commit.message, forType: .string)
                #endif
            } label: {
                Label("Copy Message", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("With Commits") {
    let container = try! ModelContainer(
        for: GitRepositoryModel.self, GitCommitModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let repository = GitRepositoryModel(
        localPath: "/Users/user/screenplay",
        remoteURL: "https://github.com/user/screenplay.git"
    )

    // Add sample commits
    let commit1 = GitCommitModel(
        sha: "abc123def456",
        message: "Add new scene with dialogue",
        authorName: "John Doe",
        authorEmail: "john@example.com",
        timestamp: Date().addingTimeInterval(-3600)
    )

    let commit2 = GitCommitModel(
        sha: "def456ghi789",
        message: "Fix typo in character name",
        authorName: "Jane Smith",
        authorEmail: "jane@example.com",
        timestamp: Date().addingTimeInterval(-7200)
    )

    let commit3 = GitCommitModel(
        sha: "ghi789jkl012",
        message: "Update title page metadata",
        authorName: "John Doe",
        authorEmail: "john@example.com",
        timestamp: Date().addingTimeInterval(-86400)
    )

    repository.commits = [commit1, commit2, commit3]
    container.mainContext.insert(repository)

    return NavigationStack {
        GitCommitHistoryView(repository: repository)
    }
    .modelContainer(container)
}

#Preview("Empty") {
    NavigationStack {
        GitCommitHistoryView(repository: GitRepositoryModel(
            localPath: "/Users/user/screenplay",
            remoteURL: "https://github.com/user/screenplay.git"
        ))
    }
    .modelContainer(for: [GitRepositoryModel.self], inMemory: true)
}
#endif
