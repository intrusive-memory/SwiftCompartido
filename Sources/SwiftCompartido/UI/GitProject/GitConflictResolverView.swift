//
//  GitConflictResolverView.swift
//  SwiftCompartido
//
//  UI for resolving merge conflicts in Git repositories.
//

import SwiftUI
import SwiftData

/// View for resolving merge conflicts that occur during branch merges.
///
/// Displays all conflicted files and provides resolution options:
/// - Accept current branch changes (ours)
/// - Accept incoming branch changes (theirs)
/// - Manual resolution with conflict markers
///
/// ## Example Usage
///
/// ```swift
/// struct MergeView: View {
///     let repository: GitRepositoryModel
///     @State private var hasConflicts = false
///
///     var body: some View {
///         if hasConflicts {
///             GitConflictResolverView(
///                 repository: repository,
///                 onResolved: {
///                     hasConflicts = false
///                 }
///             )
///         }
///     }
/// }
/// ```
public struct GitConflictResolverView: View {

    // MARK: - Types

    enum ResolutionStrategy {
        case acceptOurs
        case acceptTheirs
        case manual

        var label: String {
            switch self {
            case .acceptOurs: return "Accept Current"
            case .acceptTheirs: return "Accept Incoming"
            case .manual: return "Manual Edit"
            }
        }

        var icon: String {
            switch self {
            case .acceptOurs: return "arrow.left.circle.fill"
            case .acceptTheirs: return "arrow.right.circle.fill"
            case .manual: return "pencil.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .acceptOurs: return .blue
            case .acceptTheirs: return .green
            case .manual: return .orange
            }
        }
    }

    struct ConflictedFile: Identifiable, Hashable {
        let id = UUID()
        let path: String
        let content: String

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: ConflictedFile, rhs: ConflictedFile) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var conflictedFiles: [ConflictedFile] = []
    @State private var selectedFile: ConflictedFile?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isResolving: Bool = false

    // MARK: - Properties

    /// The repository with conflicts
    public let repository: GitRepositoryModel

    /// Callback when all conflicts are resolved
    public let onResolved: () -> Void

    // MARK: - Initialization

    /// Creates a new conflict resolver view.
    ///
    /// - Parameters:
    ///   - repository: The repository with conflicts
    ///   - onResolved: Callback when all conflicts are resolved
    public init(
        repository: GitRepositoryModel,
        onResolved: @escaping () -> Void
    ) {
        self.repository = repository
        self.onResolved = onResolved
    }

    // MARK: - Body

    public var body: some View {
        NavigationSplitView {
            // File list
            List(conflictedFiles, selection: $selectedFile) { file in
                ConflictFileRow(file: file)
                    .tag(file as ConflictedFile?)
            }
            .navigationTitle("Resolve Conflicts")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await completeResolution() }
                    } label: {
                        Label("Complete", systemImage: "checkmark")
                    }
                    .disabled(isResolving || !conflictedFiles.isEmpty)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Loading conflicts...")
                } else if conflictedFiles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("All Conflicts Resolved")
                            .font(.headline)
                        Text("Ready to complete the merge")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } detail: {
            // Conflict resolution detail
            if let file = selectedFile {
                ConflictDetailView(
                    file: file,
                    repository: repository,
                    onResolved: { resolvedFile in
                        removeResolvedFile(resolvedFile)
                    }
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.left")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Select a File")
                        .font(.headline)
                    Text("Choose a conflicted file to resolve")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await loadConflicts()
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadConflicts() async {
        isLoading = true
        errorMessage = nil

        do {
            let service = GitProjectService()
            let conflictPaths = try await service.listConflictedFiles(in: repository)

            // Load file contents
            var files: [ConflictedFile] = []
            for path in conflictPaths {
                let fullPath = URL(fileURLWithPath: repository.localPath)
                    .appendingPathComponent(path)

                if let content = try? String(contentsOf: fullPath, encoding: .utf8) {
                    files.append(ConflictedFile(path: path, content: content))
                }
            }

            conflictedFiles = files
            isLoading = false
        } catch {
            errorMessage = "Failed to load conflicts: \(error.localizedDescription)"
            isLoading = false
        }
    }

    @MainActor
    private func removeResolvedFile(_ file: ConflictedFile) {
        conflictedFiles.removeAll { $0.id == file.id }

        // Auto-select next file if available
        if !conflictedFiles.isEmpty {
            selectedFile = conflictedFiles.first
        } else {
            selectedFile = nil
        }
    }

    @MainActor
    private func completeResolution() async {
        isResolving = true
        defer { isResolving = false }

        do {
            let service = GitProjectService()

            // Create a merge commit
            try await service.commit(
                repository: repository,
                message: "Resolve merge conflicts"
            )

            onResolved()
            dismiss()
        } catch {
            errorMessage = "Failed to complete merge: \(error.localizedDescription)"
        }
    }
}

// MARK: - Conflict File Row

private struct ConflictFileRow: View {
    let file: GitConflictResolverView.ConflictedFile

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            VStack(alignment: .leading) {
                Text(file.path)
                    .font(.body)

                Text("\(conflictCount) conflicts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var conflictCount: Int {
        // Count conflict markers in file
        let markers = file.content.components(separatedBy: "<<<<<<<")
        return max(0, markers.count - 1)
    }
}

// MARK: - Conflict Detail View

private struct ConflictDetailView: View {
    let file: GitConflictResolverView.ConflictedFile
    let repository: GitRepositoryModel
    let onResolved: (GitConflictResolverView.ConflictedFile) -> Void

    @State private var resolvedContent: String = ""
    @State private var isResolving: Bool = false
    @State private var showingManualEditor: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // File header
            HStack {
                VStack(alignment: .leading) {
                    Text(file.path)
                        .font(.headline)
                    Text("\(conflictCount) conflicts to resolve")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isResolving {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding()
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .systemGray6))
            #endif

            Divider()

            // Conflict preview
            ScrollView {
                Text(file.content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // Resolution actions
            HStack(spacing: 16) {
                Button {
                    Task { await resolveConflict(strategy: .acceptOurs) }
                } label: {
                    Label("Accept Current", systemImage: "arrow.left.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isResolving)

                Button {
                    Task { await resolveConflict(strategy: .acceptTheirs) }
                } label: {
                    Label("Accept Incoming", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isResolving)

                Button {
                    showingManualEditor = true
                } label: {
                    Label("Manual Edit", systemImage: "pencil.circle.fill")
                }
                .buttonStyle(.bordered)
                .disabled(isResolving)
            }
            .padding()
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .systemGray6))
            #endif

            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingManualEditor) {
            ManualConflictEditor(
                file: file,
                repository: repository,
                onSave: { resolvedText in
                    resolvedContent = resolvedText
                    Task {
                        await saveResolvedContent()
                    }
                }
            )
        }
    }

    private var conflictCount: Int {
        let markers = file.content.components(separatedBy: "<<<<<<<")
        return max(0, markers.count - 1)
    }

    @MainActor
    private func resolveConflict(strategy: GitConflictResolverView.ResolutionStrategy) async {
        isResolving = true
        errorMessage = nil

        do {
            let service = GitProjectService()

            switch strategy {
            case .acceptOurs:
                try await service.resolveConflict(
                    file: file.path,
                    in: repository,
                    strategy: "ours"
                )
            case .acceptTheirs:
                try await service.resolveConflict(
                    file: file.path,
                    in: repository,
                    strategy: "theirs"
                )
            case .manual:
                showingManualEditor = true
                isResolving = false
                return
            }

            onResolved(file)
        } catch {
            errorMessage = error.localizedDescription
        }

        isResolving = false
    }

    @MainActor
    private func saveResolvedContent() async {
        isResolving = true
        errorMessage = nil

        do {
            let filePath = URL(fileURLWithPath: repository.localPath)
                .appendingPathComponent(file.path)

            try resolvedContent.write(to: filePath, atomically: true, encoding: .utf8)

            // Mark as resolved
            let service = GitProjectService()
            try await service.stageFile(file.path, in: repository)

            onResolved(file)
        } catch {
            errorMessage = error.localizedDescription
        }

        isResolving = false
    }
}

// MARK: - Manual Conflict Editor

private struct ManualConflictEditor: View {
    @Environment(\.dismiss) private var dismiss

    let file: GitConflictResolverView.ConflictedFile
    let repository: GitRepositoryModel
    let onSave: (String) -> Void

    @State private var editedContent: String

    init(
        file: GitConflictResolverView.ConflictedFile,
        repository: GitRepositoryModel,
        onSave: @escaping (String) -> Void
    ) {
        self.file = file
        self.repository = repository
        self.onSave = onSave
        _editedContent = State(initialValue: file.content)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Editor
                TextEditor(text: $editedContent)
                    .font(.system(.body, design: .monospaced))
                    .padding()

                // Conflict marker info
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Remove conflict markers (<<<<<<<, =======, >>>>>>>) when done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                #if os(macOS)
                .background(Color(nsColor: .controlBackgroundColor))
                #else
                .background(Color(uiColor: .systemGray6))
                #endif
            }
            .navigationTitle("Edit \(file.path)")
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
                    Button("Save") {
                        onSave(editedContent)
                        dismiss()
                    }
                    .disabled(hasConflictMarkers)
                }
            }
        }
    }

    private var hasConflictMarkers: Bool {
        editedContent.contains("<<<<<<<") ||
        editedContent.contains("=======") ||
        editedContent.contains(">>>>>>>")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Conflict Resolver") {
    let container = try! ModelContainer(
        for: GitRepositoryModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let repository = GitRepositoryModel(
        localPath: "/Users/user/screenplay",
        remoteURL: "https://github.com/user/screenplay.git"
    )
    container.mainContext.insert(repository)

    return GitConflictResolverView(
        repository: repository,
        onResolved: {
            print("Conflicts resolved!")
        }
    )
    .modelContainer(container)
}
#endif
