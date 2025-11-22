//
//  GitProjectSetupSheet.swift
//  SwiftCompartido
//
//  Modal sheet for initializing Git on a new screenplay project or cloning an existing one.
//

import SwiftUI
import SwiftData

/// Modal sheet for setting up Git integration on a screenplay project.
///
/// Provides two setup workflows:
/// - **New Repository**: Initialize Git in the current project directory
/// - **Clone Repository**: Clone an existing remote repository
///
/// ## Example Usage
///
/// ```swift
/// struct DocumentView: View {
///     @State private var showingGitSetup = false
///     @Environment(\.modelContext) private var modelContext
///
///     var body: some View {
///         Button("Enable Version Control") {
///             showingGitSetup = true
///         }
///         .sheet(isPresented: $showingGitSetup) {
///             GitProjectSetupSheet { repository in
///                 print("Repository created: \(repository.localPath)")
///             }
///         }
///     }
/// }
/// ```
public struct GitProjectSetupSheet: View {

    // MARK: - Types

    /// Setup mode selection
    enum SetupMode: String, CaseIterable {
        case newRepository = "New Repository"
        case clone = "Clone Repository"
    }

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedMode: SetupMode = .newRepository
    @State private var localPath: String = ""
    @State private var remoteURL: String = ""
    @State private var branchName: String = "main"
    @State private var enableLFS: Bool = true
    @State private var isProcessing: Bool = false
    @State private var progress: Double = 0.0
    @State private var progressMessage: String = ""
    @State private var errorMessage: String?

    // MARK: - Properties

    /// Callback when repository setup completes successfully
    private let onComplete: (GitRepositoryModel) -> Void

    // MARK: - Initialization

    /// Creates a new Git project setup sheet.
    ///
    /// - Parameter onComplete: Called when repository is successfully created or cloned
    public init(onComplete: @escaping (GitRepositoryModel) -> Void) {
        self.onComplete = onComplete
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                // Mode Picker
                Picker("Setup Mode", selection: $selectedMode) {
                    ForEach(SetupMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(isProcessing)

                // Mode-specific sections
                switch selectedMode {
                case .newRepository:
                    newRepositorySection
                case .clone:
                    cloneRepositorySection
                }

                // Common settings
                commonSettingsSection

                // Progress section (when processing)
                if isProcessing {
                    progressSection
                }

                // Error section
                if let error = errorMessage {
                    errorSection(error)
                }
            }
            .navigationTitle("Git Setup")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(selectedMode == .newRepository ? "Initialize" : "Clone") {
                        Task {
                            await performSetup()
                        }
                    }
                    .disabled(isProcessing || !isValid)
                }
            }
        }
    }

    // MARK: - View Sections

    private var newRepositorySection: some View {
        Section("Repository Location") {
            TextField("Local Path", text: $localPath, prompt: Text("/path/to/project"))
                .textContentType(.none)
                .autocorrectionDisabled()

            Text("The directory where your screenplay project is located")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Remote URL (Optional)", text: $remoteURL, prompt: Text("https://github.com/user/repo.git"))
                .textContentType(.URL)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            Text("Add a remote repository to push changes to")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var cloneRepositorySection: some View {
        Section("Clone Repository") {
            TextField("Remote URL", text: $remoteURL, prompt: Text("https://github.com/user/repo.git"))
                .textContentType(.URL)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            TextField("Local Path", text: $localPath, prompt: Text("/path/to/clone"))
                .textContentType(.none)
                .autocorrectionDisabled()

            Text("Repository will be cloned to this directory")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var commonSettingsSection: some View {
        Section("Settings") {
            TextField("Branch Name", text: $branchName, prompt: Text("main"))
                .textContentType(.none)
                .autocorrectionDisabled()

            Toggle("Enable Git LFS", isOn: $enableLFS)

            Text("LFS stores large media files (audio, video, images) efficiently")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var progressSection: some View {
        Section("Progress") {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: progress)
                Text(progressMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    // MARK: - Validation

    private var isValid: Bool {
        guard !localPath.isEmpty else { return false }

        if selectedMode == .clone {
            return !remoteURL.isEmpty && isValidGitURL(remoteURL)
        }

        return true
    }

    private func isValidGitURL(_ urlString: String) -> Bool {
        urlString.hasPrefix("https://") ||
        urlString.hasPrefix("http://") ||
        urlString.hasPrefix("git@") ||
        urlString.hasPrefix("ssh://")
    }

    // MARK: - Setup Actions

    @MainActor
    private func performSetup() async {
        isProcessing = true
        errorMessage = nil
        progress = 0.0

        do {
            let service = GitProjectService()
            let repository: GitRepositoryModel

            switch selectedMode {
            case .newRepository:
                repository = try await initializeRepository(service: service)
            case .clone:
                repository = try await cloneRepository(service: service)
            }

            // Initialize LFS if enabled
            if enableLFS {
                progressMessage = "Initializing Git LFS..."
                progress = 0.8
                try await service.initializeLFS(in: repository)
            }

            // Save to SwiftData
            modelContext.insert(repository)
            try modelContext.save()

            progress = 1.0
            progressMessage = "Complete!"

            // Dismiss and notify completion
            onComplete(repository)
            dismiss()

        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
        }
    }

    private func initializeRepository(service: GitProjectService) async throws -> GitRepositoryModel {
        progressMessage = "Creating repository..."
        progress = 0.3

        // Create local directory if needed
        let localURL = URL(fileURLWithPath: localPath)
        if !FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.createDirectory(at: localURL, withIntermediateDirectories: true)
        }

        // Initialize git repository using command line (macOS only)
        #if os(macOS)
        let initProcess = Process()
        initProcess.currentDirectoryURL = localURL
        initProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        initProcess.arguments = ["git", "init", "-b", branchName]
        try initProcess.run()
        initProcess.waitUntilExit()

        guard initProcess.terminationStatus == 0 else {
            throw GitProjectService.GitError.commitFailed(reason: "Failed to initialize Git repository")
        }

        progressMessage = "Repository initialized"
        progress = 0.6

        // Create repository model
        let repository = GitRepositoryModel(
            localPath: localPath,
            remoteURL: remoteURL.isEmpty ? nil : remoteURL
        )
        repository.currentBranch = branchName

        // Add remote if provided
        if !remoteURL.isEmpty {
            let remoteProcess = Process()
            remoteProcess.currentDirectoryURL = localURL
            remoteProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            remoteProcess.arguments = ["git", "remote", "add", "origin", remoteURL]
            try remoteProcess.run()
            remoteProcess.waitUntilExit()
        }

        return repository
        #else
        // On iOS, we'd need to use libgit2 directly
        throw GitProjectService.GitError.commitFailed(reason: "Git initialization not supported on iOS")
        #endif
    }

    private func cloneRepository(service: GitProjectService) async throws -> GitRepositoryModel {
        progressMessage = "Cloning repository..."
        progress = 0.1

        let clonedRepository = try await service.clone(
            remoteURL: remoteURL,
            localPath: localPath
        ) { currentProgress, message in
            Task { @MainActor in
                self.progress = currentProgress * 0.7 // Reserve 0.7-1.0 for LFS
                self.progressMessage = message
            }
        }

        guard let repository = clonedRepository else {
            throw GitProjectService.GitError.cloneFailed(reason: "Failed to create repository model")
        }

        repository.currentBranch = branchName
        return repository
    }
}

// MARK: - Preview

#if DEBUG
#Preview("New Repository") {
    GitProjectSetupSheet { repository in
        print("Repository created: \(repository.localPath)")
    }
    .modelContainer(for: [GitRepositoryModel.self], inMemory: true)
}

#Preview("Clone Repository") {
    @Previewable @State var mode: GitProjectSetupSheet.SetupMode = .clone

    GitProjectSetupSheet { repository in
        print("Repository cloned: \(repository.localPath)")
    }
    .modelContainer(for: [GitRepositoryModel.self], inMemory: true)
}
#endif
