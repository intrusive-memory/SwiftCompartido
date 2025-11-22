//
//  GitQuickActionsMenu.swift
//  SwiftCompartido
//
//  Quick actions menu for Git operations in toolbars.
//

import SwiftUI
import SwiftData

/// Quick actions menu for common Git operations.
///
/// Provides convenient access to commit, pull, push, and sync operations
/// from document toolbars and context menus.
///
/// ## Example Usage
///
/// ```swift
/// struct DocumentView: View {
///     let repository: GitRepositoryModel
///
///     var body: some View {
///         Text("Screenplay")
///             .toolbar {
///                 ToolbarItemGroup {
///                     GitQuickActionsMenu(repository: repository)
///                 }
///             }
///     }
/// }
/// ```
public struct GitQuickActionsMenu: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var status: GitProjectService.RepositoryStatus?
    @State private var showingCommitSheet: Bool = false
    @State private var showingConfigView: Bool = false
    @State private var isPerformingAction: Bool = false

    // MARK: - Properties

    /// The repository to perform actions on
    public let repository: GitRepositoryModel

    // MARK: - Initialization

    /// Creates a new Git quick actions menu.
    ///
    /// - Parameter repository: The repository to perform actions on
    public init(repository: GitRepositoryModel) {
        self.repository = repository
    }

    // MARK: - Body

    public var body: some View {
        Menu {
            // Status section
            Section {
                statusLabel
            }

            // Quick actions
            Section {
                Button {
                    showingCommitSheet = true
                } label: {
                    Label("Commit", systemImage: "square.and.pencil")
                }
                .disabled(isPerformingAction || (status?.modifiedFiles ?? 0) == 0)

                Button {
                    Task {
                        await performPull()
                    }
                } label: {
                    Label("Pull", systemImage: "arrow.down.circle")
                }
                .disabled(isPerformingAction)

                Button {
                    Task {
                        await performPush()
                    }
                } label: {
                    Label("Push", systemImage: "arrow.up.circle")
                }
                .disabled(isPerformingAction || (status?.commitsAhead ?? 0) == 0)

                Button {
                    Task {
                        await performSync()
                    }
                } label: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isPerformingAction)
            }

            // Configuration
            Section {
                Button {
                    showingConfigView = true
                } label: {
                    Label("Git Settings", systemImage: "gearshape")
                }
            }

        } label: {
            Image(systemName: "arrow.triangle.branch")
        }
        .sheet(isPresented: $showingConfigView) {
            NavigationStack {
                GitProjectConfigurationView(repository: repository)
            }
        }
        .sheet(isPresented: $showingCommitSheet) {
            CommitSheet(repository: repository, status: status)
        }
        .task {
            await refreshStatus()
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var statusLabel: some View {
        if let status = status {
            Label {
                Text(repository.currentBranch)
            } icon: {
                Image(systemName: "arrow.triangle.branch")
            }

            if status.modifiedFiles > 0 {
                Label("\(status.modifiedFiles) modified", systemImage: "pencil.circle")
            }

            if status.commitsAhead > 0 {
                Label("\(status.commitsAhead) ahead", systemImage: "arrow.up.circle")
            }

            if status.commitsBehind > 0 {
                Label("\(status.commitsBehind) behind", systemImage: "arrow.down.circle")
            }

            if status.modifiedFiles == 0 && status.commitsAhead == 0 && status.commitsBehind == 0 {
                Label("Up to date", systemImage: "checkmark.circle")
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func refreshStatus() async {
        do {
            let service = GitProjectService()
            status = try await service.status(repository: repository)
        } catch {
            // Silently fail for menu
        }
    }

    @MainActor
    private func performPull() async {
        isPerformingAction = true

        do {
            let service = GitProjectService()
            try await service.pull(repository: repository) { _, _ in }
            await refreshStatus()
        } catch {
            // Handle error silently or show alert
        }

        isPerformingAction = false
    }

    @MainActor
    private func performPush() async {
        isPerformingAction = true

        do {
            let service = GitProjectService()
            try await service.push(repository: repository) { _, _ in }
            await refreshStatus()
        } catch {
            // Handle error silently or show alert
        }

        isPerformingAction = false
    }

    @MainActor
    private func performSync() async {
        await performPull()
        if (status?.commitsAhead ?? 0) > 0 {
            await performPush()
        }
    }
}

// MARK: - Commit Sheet

private struct CommitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let repository: GitRepositoryModel
    let status: GitProjectService.RepositoryStatus?

    @State private var commitMessage: String = ""
    @State private var isCommitting: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Commit Message") {
                    TextEditor(text: $commitMessage)
                        .frame(minHeight: 100)
                }

                if let status = status {
                    Section("Files to Commit (\(status.modifiedFiles))") {
                        ForEach(status.modifiedPaths.prefix(10), id: \.self) { path in
                            Text(path)
                                .font(.caption)
                                .lineLimit(1)
                        }

                        if status.modifiedPaths.count > 10 {
                            Text("... and \(status.modifiedPaths.count - 10) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Commit Changes")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Commit") {
                        Task {
                            await performCommit()
                        }
                    }
                    .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCommitting)
                }
            }
        }
    }

    @MainActor
    private func performCommit() async {
        isCommitting = true

        do {
            let service = GitProjectService()
            try await service.commit(
                repository: repository,
                message: commitMessage,
                author: nil
            )

            dismiss()
        } catch {
            // Handle error
        }

        isCommitting = false
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Quick Actions Menu") {
    NavigationStack {
        Text("Screenplay Document")
            .toolbar {
                ToolbarItemGroup {
                    GitQuickActionsMenu(repository: GitRepositoryModel(
                        localPath: "/Users/user/screenplay",
                        remoteURL: "https://github.com/user/screenplay.git"
                    ))
                }
            }
    }
    .modelContainer(for: [GitRepositoryModel.self], inMemory: true)
}
#endif
