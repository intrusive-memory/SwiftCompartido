//
//  GitProjectConfigurationView.swift
//  SwiftCompartido
//
//  Main configuration panel for Git integration on screenplay projects.
//

import SwiftUI
import SwiftData

/// Main configuration panel for managing Git version control on a screenplay project.
///
/// Displays repository status, provides quick actions for Git operations,
/// and shows repository metadata.
///
/// ## Example Usage
///
/// ```swift
/// struct DocumentView: View {
///     let repository: GitRepositoryModel
///
///     var body: some View {
///         GitProjectConfigurationView(repository: repository)
///     }
/// }
/// ```
public struct GitProjectConfigurationView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var repositoryStatus: GitProjectService.RepositoryStatus?
    @State private var isRefreshing: Bool = false
    @State private var commitMessage: String = ""
    @State private var showingCommitSheet: Bool = false
    @State private var currentOperation: GitOperation?
    @State private var operationProgress: Double = 0.0
    @State private var operationMessage: String = ""
    @State private var errorMessage: String?

    // MARK: - Properties

    /// The repository to configure
    public let repository: GitRepositoryModel

    /// Git service (created lazily)
    private var gitService: GitProjectService {
        GitProjectService()
    }

    // MARK: - Types

    private enum GitOperation: String {
        case pull = "Pulling"
        case push = "Pushing"
        case commit = "Committing"
        case fetch = "Fetching"
    }

    // MARK: - Initialization

    /// Creates a new Git project configuration view.
    ///
    /// - Parameter repository: The repository to configure
    public init(repository: GitRepositoryModel) {
        self.repository = repository
    }

    // MARK: - Body

    public var body: some View {
        List {
            // Status Section
            statusSection

            // Quick Actions
            quickActionsSection

            // Repository Info
            repositoryInfoSection

            // LFS Configuration
            if repository.lfsEnabled {
                lfsSection
            }

            // Error Display
            if let error = errorMessage {
                errorSection(error)
            }
        }
        .navigationTitle("Git Configuration")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await refreshStatus()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isRefreshing || currentOperation != nil)
            }
        }
        .sheet(isPresented: $showingCommitSheet) {
            commitSheet
        }
        .overlay {
            if currentOperation != nil {
                operationProgressOverlay
            }
        }
        .task {
            await refreshStatus()
        }
    }

    // MARK: - View Sections

    private var statusSection: some View {
        Section("Repository Status") {
            if let status = repositoryStatus {
                LabeledContent("Branch", value: repository.currentBranch)

                if status.modifiedFiles > 0 {
                    LabeledContent("Modified Files", value: "\(status.modifiedFiles)")
                        .foregroundStyle(.orange)
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Working tree clean")
                    }
                }

                if status.commitsAhead > 0 {
                    LabeledContent("Commits Ahead", value: "\(status.commitsAhead)")
                        .foregroundStyle(.blue)
                }

                if status.commitsBehind > 0 {
                    LabeledContent("Commits Behind", value: "\(status.commitsBehind)")
                        .foregroundStyle(.orange)
                }

                if let lastSync = repository.lastSync {
                    LabeledContent("Last Sync") {
                        Text(lastSync, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }

            } else if isRefreshing {
                HStack {
                    ProgressView()
                    Text("Checking status...")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Unable to check status")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickActionsSection: some View {
        Section("Quick Actions") {
            // Commit button
            Button {
                showingCommitSheet = true
            } label: {
                Label("Commit Changes", systemImage: "square.and.pencil")
            }
            .disabled(currentOperation != nil || (repositoryStatus?.modifiedFiles ?? 0) == 0)

            // Pull button
            Button {
                Task {
                    await performPull()
                }
            } label: {
                Label("Pull Changes", systemImage: "arrow.down.circle")
            }
            .disabled(currentOperation != nil)

            // Push button
            Button {
                Task {
                    await performPush()
                }
            } label: {
                Label("Push Changes", systemImage: "arrow.up.circle")
            }
            .disabled(currentOperation != nil || (repositoryStatus?.commitsAhead ?? 0) == 0)

            // Sync button (pull then push)
            Button {
                Task {
                    await performSync()
                }
            } label: {
                Label("Sync", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(currentOperation != nil)
        }
    }

    private var repositoryInfoSection: some View {
        Section("Repository Information") {
            LabeledContent("Local Path") {
                Text(repository.localPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let remoteURL = repository.remoteURL {
                LabeledContent("Remote URL") {
                    HStack {
                        Text(remoteURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button {
                            #if os(iOS)
                            UIPasteboard.general.string = remoteURL
                            #elseif os(macOS)
                            NSPasteboard.general.setString(remoteURL, forType: .string)
                            #endif
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            LabeledContent("Git LFS") {
                HStack {
                    Image(systemName: repository.lfsEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(repository.lfsEnabled ? .green : .secondary)
                    Text(repository.lfsEnabled ? "Enabled" : "Disabled")
                }
            }
        }
    }

    private var lfsSection: some View {
        Section("Git LFS Patterns") {
            if repository.lfsFiles.isEmpty {
                Text("No LFS patterns configured")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(repository.lfsFiles, id: \.self) { pattern in
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.blue)
                        Text(pattern)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
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

    // MARK: - Commit Sheet

    private var commitSheet: some View {
        NavigationStack {
            Form {
                Section("Commit Message") {
                    TextEditor(text: $commitMessage)
                        .frame(minHeight: 100)
                }

                if let status = repositoryStatus {
                    Section("Files to Commit") {
                        ForEach(status.modifiedPaths, id: \.self) { path in
                            HStack {
                                Image(systemName: "doc.badge.ellipsis")
                                    .foregroundStyle(.orange)
                                Text(path)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
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
                        showingCommitSheet = false
                        commitMessage = ""
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Commit") {
                        Task {
                            await performCommit()
                        }
                    }
                    .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Operation Progress Overlay

    private var operationProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if let operation = currentOperation {
                    Text(operation.rawValue)
                        .font(.headline)
                }

                ProgressView(value: operationProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)

                Text(operationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial)
            .cornerRadius(12)
        }
    }

    // MARK: - Git Operations

    @MainActor
    private func refreshStatus() async {
        isRefreshing = true
        errorMessage = nil

        do {
            let service = gitService
            let status = try await service.status(repository: repository)
            repositoryStatus = status
        } catch {
            errorMessage = "Failed to check status: \(error.localizedDescription)"
        }

        isRefreshing = false
    }

    @MainActor
    private func performCommit() async {
        currentOperation = .commit
        operationProgress = 0.0
        operationMessage = "Creating commit..."
        showingCommitSheet = false

        do {
            let service = gitService

            // Add all modified files
            operationProgress = 0.3
            operationMessage = "Staging changes..."

            // Commit
            operationProgress = 0.6
            operationMessage = "Writing commit..."

            try await service.commit(
                repository: repository,
                message: commitMessage,
                author: nil
            )

            operationProgress = 1.0
            operationMessage = "Complete!"

            commitMessage = ""
            currentOperation = nil

            // Refresh status
            await refreshStatus()

        } catch {
            errorMessage = "Failed to commit: \(error.localizedDescription)"
            currentOperation = nil
        }
    }

    @MainActor
    private func performPull() async {
        currentOperation = .pull
        operationProgress = 0.0
        operationMessage = "Fetching changes..."

        do {
            let service = gitService

            try await service.pull(repository: repository) { progress, message in
                Task { @MainActor in
                    self.operationProgress = progress
                    self.operationMessage = message
                }
            }

            operationProgress = 1.0
            operationMessage = "Complete!"
            currentOperation = nil

            // Refresh status
            await refreshStatus()

        } catch {
            errorMessage = "Failed to pull: \(error.localizedDescription)"
            currentOperation = nil
        }
    }

    @MainActor
    private func performPush() async {
        currentOperation = .push
        operationProgress = 0.0
        operationMessage = "Pushing changes..."

        do {
            let service = gitService

            try await service.push(repository: repository) { progress, message in
                Task { @MainActor in
                    self.operationProgress = progress
                    self.operationMessage = message
                }
            }

            operationProgress = 1.0
            operationMessage = "Complete!"
            currentOperation = nil

            // Refresh status
            await refreshStatus()

        } catch {
            errorMessage = "Failed to push: \(error.localizedDescription)"
            currentOperation = nil
        }
    }

    @MainActor
    private func performSync() async {
        // Pull then push
        await performPull()

        if errorMessage == nil && (repositoryStatus?.commitsAhead ?? 0) > 0 {
            await performPush()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Configuration View") {
    NavigationStack {
        GitProjectConfigurationView(repository: GitRepositoryModel(
            localPath: "/Users/user/screenplay",
            remoteURL: "https://github.com/user/screenplay.git"
        ))
    }
    .modelContainer(for: [GitRepositoryModel.self], inMemory: true)
}

#Preview("With LFS") {
    NavigationStack {
        let repository = GitRepositoryModel(
            localPath: "/Users/user/screenplay",
            remoteURL: "https://github.com/user/screenplay.git"
        )
        repository.lfsEnabled = true
        repository.lfsFiles = ["*.mp3", "*.wav", "*.mp4", "*.png"]

        return GitProjectConfigurationView(repository: repository)
    }
    .modelContainer(for: [GitRepositoryModel.self], inMemory: true)
}
#endif
