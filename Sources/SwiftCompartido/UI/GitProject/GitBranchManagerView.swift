//
//  GitBranchManagerView.swift
//  SwiftCompartido
//
//  Branch management UI for Git repositories.
//

import SwiftUI
import SwiftData

/// Branch management view for creating, switching, and deleting branches.
///
/// Provides comprehensive branch management including:
/// - List all branches with current branch indicator
/// - Create new branches
/// - Switch between branches
/// - Delete branches (with confirmation)
/// - Merge branches with conflict detection
///
/// ## Example Usage
///
/// ```swift
/// struct RepositoryView: View {
///     let repository: GitRepositoryModel
///
///     var body: some View {
///         GitBranchManagerView(repository: repository)
///     }
/// }
/// ```
public struct GitBranchManagerView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var branches: [String] = []
    @State private var isLoading: Bool = false
    @State private var showingCreateBranch: Bool = false
    @State private var showingMergeBranch: Bool = false
    @State private var newBranchName: String = ""
    @State private var selectedBranchForMerge: String? = nil
    @State private var branchToDelete: String? = nil
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isPerformingOperation: Bool = false

    // MARK: - Properties

    /// The repository to manage branches for
    public let repository: GitRepositoryModel

    // MARK: - Initialization

    /// Creates a new branch manager view.
    ///
    /// - Parameter repository: The repository to manage branches for
    public init(repository: GitRepositoryModel) {
        self.repository = repository
    }

    // MARK: - Body

    public var body: some View {
        List {
            // Current branch section
            Section("Current Branch") {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(repository.currentBranch)
                        .fontWeight(.semibold)
                }
            }

            // Branches list
            Section {
                if isLoading {
                    ProgressView()
                } else if branches.isEmpty {
                    Text("No branches found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(branches, id: \.self) { branch in
                        BranchRow(
                            branch: branch,
                            isCurrent: branch == repository.currentBranch,
                            onSwitch: {
                                Task { await switchToBranch(branch) }
                            },
                            onDelete: {
                                branchToDelete = branch
                            },
                            onMerge: {
                                selectedBranchForMerge = branch
                                showingMergeBranch = true
                            }
                        )
                    }
                }
            } header: {
                Text("All Branches (\(branches.count))")
            }

            // Success/Error messages
            if let success = successMessage {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(success)
                    }
                }
            }

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
        .navigationTitle("Branches")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateBranch = true
                } label: {
                    Label("New Branch", systemImage: "plus")
                }
                .disabled(isPerformingOperation)
            }

            ToolbarItem(placement: .secondaryAction) {
                Button {
                    Task { await loadBranches() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .sheet(isPresented: $showingCreateBranch) {
            CreateBranchSheet(onCreate: { name in
                Task { await createBranch(named: name) }
                showingCreateBranch = false
            })
        }
        .alert("Merge Branch", isPresented: $showingMergeBranch) {
            Button("Cancel", role: .cancel) {
                selectedBranchForMerge = nil
            }
            Button("Merge") {
                if let branch = selectedBranchForMerge {
                    Task { await mergeBranch(branch) }
                }
            }
        } message: {
            if let branch = selectedBranchForMerge {
                Text("Merge '\(branch)' into '\(repository.currentBranch)'?")
            }
        }
        .alert("Delete Branch", isPresented: .constant(branchToDelete != nil)) {
            Button("Cancel", role: .cancel) {
                branchToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let branch = branchToDelete {
                    Task { await deleteBranch(branch) }
                }
            }
        } message: {
            if let branch = branchToDelete {
                Text("Delete branch '\(branch)'? This cannot be undone.")
            }
        }
        .task {
            await loadBranches()
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadBranches() async {
        isLoading = true
        errorMessage = nil

        do {
            let service = GitProjectService()
            branches = try await service.listBranches(in: repository)
            isLoading = false
        } catch {
            errorMessage = "Failed to load branches: \(error.localizedDescription)"
            isLoading = false
        }
    }

    @MainActor
    private func createBranch(named name: String) async {
        isPerformingOperation = true
        errorMessage = nil
        successMessage = nil

        do {
            let service = GitProjectService()
            try await service.createBranch(named: name, in: repository, checkout: true)
            successMessage = "Created and switched to branch '\(name)'"
            await loadBranches()
        } catch {
            errorMessage = "Failed to create branch: \(error.localizedDescription)"
        }

        isPerformingOperation = false
    }

    @MainActor
    private func switchToBranch(_ branch: String) async {
        isPerformingOperation = true
        errorMessage = nil
        successMessage = nil

        do {
            let service = GitProjectService()
            try await service.switchBranch(to: branch, in: repository)
            successMessage = "Switched to branch '\(branch)'"
            await loadBranches()
        } catch {
            errorMessage = "Failed to switch branch: \(error.localizedDescription)"
        }

        isPerformingOperation = false
    }

    @MainActor
    private func deleteBranch(_ branch: String) async {
        isPerformingOperation = true
        errorMessage = nil
        successMessage = nil

        do {
            let service = GitProjectService()
            try await service.deleteBranch(named: branch, in: repository)
            successMessage = "Deleted branch '\(branch)'"
            branchToDelete = nil
            await loadBranches()
        } catch {
            errorMessage = "Failed to delete branch: \(error.localizedDescription)"
        }

        isPerformingOperation = false
    }

    @MainActor
    private func mergeBranch(_ branch: String) async {
        isPerformingOperation = true
        errorMessage = nil
        successMessage = nil

        do {
            let service = GitProjectService()
            let hasConflicts = try await !service.mergeBranch(branch, into: repository)

            if hasConflicts {
                errorMessage = "Merge conflicts detected. Please resolve manually."
            } else {
                successMessage = "Successfully merged '\(branch)' into '\(repository.currentBranch)'"
            }

            selectedBranchForMerge = nil
        } catch {
            errorMessage = "Failed to merge branch: \(error.localizedDescription)"
        }

        isPerformingOperation = false
    }
}

// MARK: - Branch Row

private struct BranchRow: View {
    let branch: String
    let isCurrent: Bool
    let onSwitch: () -> Void
    let onDelete: () -> Void
    let onMerge: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(branch)
                    .fontWeight(isCurrent ? .semibold : .regular)

                if isCurrent {
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !isCurrent {
                Menu {
                    Button {
                        onSwitch()
                    } label: {
                        Label("Switch to Branch", systemImage: "arrow.triangle.branch")
                    }

                    Button {
                        onMerge()
                    } label: {
                        Label("Merge into Current", systemImage: "arrow.triangle.merge")
                    }

                    Divider()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Create Branch Sheet

private struct CreateBranchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var branchName: String = ""

    let onCreate: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Branch Name", text: $branchName, prompt: Text("feature/new-feature"))
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                } footer: {
                    Text("Use lowercase with hyphens or slashes (e.g., feature/my-feature)")
                        .font(.caption)
                }
            }
            .navigationTitle("New Branch")
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
                    Button("Create") {
                        onCreate(branchName)
                        dismiss()
                    }
                    .disabled(branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Branch Manager") {
    NavigationStack {
        GitBranchManagerView(repository: GitRepositoryModel(
            localPath: "/Users/user/screenplay",
            remoteURL: "https://github.com/user/screenplay.git"
        ))
    }
    .modelContainer(for: [GitRepositoryModel.self], inMemory: true)
}
#endif
