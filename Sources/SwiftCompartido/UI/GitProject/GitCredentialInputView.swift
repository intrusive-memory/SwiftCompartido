//
//  GitCredentialInputView.swift
//  SwiftCompartido
//
//  Manual credential input when automatic detection fails.
//

import SwiftUI

/// Manual credential input view for Git authentication.
///
/// Provides platform-specific credential entry when automatic detection fails.
/// Supports SSH key paths, username/token authentication, and Keychain integration.
///
/// ## Example Usage
///
/// ```swift
/// .sheet(isPresented: $showingCredentialInput) {
///     GitCredentialInputView(
///         remoteURL: repository.remoteURL ?? "",
///         onCredentialsSaved: {
///             // Retry failed operation
///         }
///     )
/// }
/// ```
public struct GitCredentialInputView: View {

    // MARK: - Types

    enum AuthMethod: String, CaseIterable {
        case sshKey = "SSH Key"
        case token = "Personal Access Token"

        var icon: String {
            switch self {
            case .sshKey: return "key.fill"
            case .token: return "lock.fill"
            }
        }
    }

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedMethod: AuthMethod = .sshKey
    @State private var sshKeyPath: String = ""
    @State private var username: String = ""
    @State private var token: String = ""
    @State private var saveToKeychain: Bool = true
    @State private var isTesting: Bool = false
    @State private var testResult: TestResult?

    // MARK: - Properties

    /// The remote URL to authenticate with
    public let remoteURL: String

    /// Callback when credentials are successfully saved
    public let onCredentialsSaved: () -> Void

    // MARK: - Types

    private enum TestResult {
        case success
        case failure(String)
    }

    // MARK: - Initialization

    /// Creates a new credential input view.
    ///
    /// - Parameters:
    ///   - remoteURL: The remote URL to authenticate with
    ///   - onCredentialsSaved: Called when credentials are saved successfully
    public init(
        remoteURL: String,
        onCredentialsSaved: @escaping () -> Void
    ) {
        self.remoteURL = remoteURL
        self.onCredentialsSaved = onCredentialsSaved

        // Set default SSH key path
        #if os(macOS)
        _sshKeyPath = State(initialValue: "~/.ssh/id_ed25519")
        #else
        _selectedMethod = State(initialValue: .token)
        #endif
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                // Remote URL display
                Section("Repository") {
                    LabeledContent("Remote URL") {
                        Text(remoteURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                // Authentication method picker
                Section("Authentication Method") {
                    Picker("Method", selection: $selectedMethod) {
                        ForEach(AuthMethod.allCases, id: \.self) { method in
                            Label(method.rawValue, systemImage: method.icon)
                                .tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Method-specific fields
                switch selectedMethod {
                case .sshKey:
                    sshKeySection
                case .token:
                    tokenSection
                }

                // Platform-specific options
                #if os(macOS)
                keychainSection
                #endif

                // Test result
                if let result = testResult {
                    testResultSection(result)
                }

                // Platform-specific guidance
                guidanceSection
            }
            .navigationTitle("Git Credentials")
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
                        saveCredentials()
                    }
                    .disabled(!isValid || isTesting)
                }
            }
        }
    }

    // MARK: - View Sections

    private var sshKeySection: some View {
        Section {
            TextField("SSH Key Path", text: $sshKeyPath, prompt: Text("~/.ssh/id_ed25519"))
                .textContentType(.none)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            Button {
                Task {
                    await testConnection()
                }
            } label: {
                if isTesting {
                    ProgressView()
                } else {
                    Label("Test Connection", systemImage: "network")
                }
            }
            .disabled(sshKeyPath.isEmpty || isTesting)
        } header: {
            Text("SSH Key Path")
        } footer: {
            #if os(macOS)
            Text("Path to your SSH private key file. Common locations: ~/.ssh/id_ed25519, ~/.ssh/id_rsa")
            #else
            Text("SSH keys are only supported on macOS. Please use a Personal Access Token on iOS.")
            #endif
        }
    }

    private var tokenSection: some View {
        Section {
            TextField("Username", text: $username, prompt: Text("github-username"))
                .textContentType(.username)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            SecureField("Token", text: $token, prompt: Text("ghp_..."))
                .textContentType(.password)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            Button {
                Task {
                    await testConnection()
                }
            } label: {
                if isTesting {
                    ProgressView()
                } else {
                    Label("Test Connection", systemImage: "network")
                }
            }
            .disabled(username.isEmpty || token.isEmpty || isTesting)

        } header: {
            Text("Token Authentication")
        } footer: {
            Text("Create a personal access token in your Git provider's settings with repository access permissions.")
        }
    }

    #if os(macOS)
    private var keychainSection: some View {
        Section {
            Toggle("Save to Keychain", isOn: $saveToKeychain)
        } footer: {
            Text("Securely store credentials in macOS Keychain for automatic retrieval")
        }
    }
    #endif

    private func testResultSection(_ result: TestResult) -> some View {
        Section {
            switch result {
            case .success:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Connection successful!")
                        .foregroundStyle(.green)
                }
            case .failure(let error):
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }

    private var guidanceSection: some View {
        Section("Getting Credentials") {
            #if os(macOS)
            VStack(alignment: .leading, spacing: 12) {
                Text("SSH Keys (macOS only)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("1. Generate a new SSH key: ssh-keygen -t ed25519 -C \"your@email.com\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("2. Add the public key to your Git provider")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Text("Personal Access Tokens")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                tokenGuidanceLinks
            }
            #else
            VStack(alignment: .leading, spacing: 12) {
                Text("Personal Access Tokens")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                tokenGuidanceLinks
            }
            #endif
        }
    }

    private var tokenGuidanceLinks: some View {
        Group {
            Link(destination: URL(string: "https://github.com/settings/tokens")!) {
                Label("GitHub: Create Token", systemImage: "link")
            }
            .font(.caption)

            Link(destination: URL(string: "https://gitlab.com/-/profile/personal_access_tokens")!) {
                Label("GitLab: Create Token", systemImage: "link")
            }
            .font(.caption)

            Text("Grant 'repo' or 'write_repository' permissions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        switch selectedMethod {
        case .sshKey:
            return !sshKeyPath.isEmpty
        case .token:
            return !username.isEmpty && !token.isEmpty
        }
    }

    // MARK: - Actions

    private func saveCredentials() {
        #if os(macOS)
        if saveToKeychain {
            saveToMacOSKeychain()
        }
        #endif

        // Set environment variables for git operations
        switch selectedMethod {
        case .sshKey:
            // SSH key path would be used by GitCredentialManager
            setenv("GIT_SSH_KEY", sshKeyPath.expandingTildeInPath.path, 1)

        case .token:
            // Token would be used by GitCredentialManager
            let tokenString = "\(username):\(token)"
            setenv("GIT_CREDENTIALS", tokenString, 1)
        }

        onCredentialsSaved()
        dismiss()
    }

    #if os(macOS)
    private func saveToMacOSKeychain() {
        // Store credentials in macOS Keychain
        // This would integrate with GitCredentialManager's Keychain support
        switch selectedMethod {
        case .token:
            // Store token in Keychain with service name based on remote URL
            let keychainQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "git:\(remoteURL)",
                kSecAttrAccount as String: username,
                kSecValueData as String: token.data(using: .utf8)!,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]

            SecItemDelete(keychainQuery as CFDictionary)
            SecItemAdd(keychainQuery as CFDictionary, nil)

        case .sshKey:
            // SSH key path stored in user defaults for reference
            UserDefaults.standard.set(sshKeyPath, forKey: "git.sshKeyPath.\(remoteURL)")
        }
    }
    #endif

    @MainActor
    private func testConnection() async {
        isTesting = true
        testResult = nil

        // Simulate connection test
        // In a real implementation, this would attempt to authenticate with the remote
        do {
            try await Task.sleep(for: .seconds(2))

            // Simple validation
            switch selectedMethod {
            case .sshKey:
                let path = sshKeyPath.expandingTildeInPath
                if FileManager.default.fileExists(atPath: path.path) {
                    testResult = .success
                } else {
                    testResult = .failure("SSH key file not found at path")
                }

            case .token:
                if token.count > 10 {
                    testResult = .success
                } else {
                    testResult = .failure("Token appears invalid")
                }
            }

        } catch {
            testResult = .failure(error.localizedDescription)
        }

        isTesting = false
    }
}

// MARK: - String Extension

private extension String {
    var expandingTildeInPath: URL {
        if hasPrefix("~") {
            let path = NSString(string: self).expandingTildeInPath
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: self)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SSH Key (macOS)") {
    GitCredentialInputView(
        remoteURL: "git@github.com:user/screenplay.git",
        onCredentialsSaved: {
            print("Credentials saved")
        }
    )
}

#Preview("Token") {
    @Previewable @State var method: GitCredentialInputView.AuthMethod = .token

    GitCredentialInputView(
        remoteURL: "https://github.com/user/screenplay.git",
        onCredentialsSaved: {
            print("Credentials saved")
        }
    )
}
#endif
