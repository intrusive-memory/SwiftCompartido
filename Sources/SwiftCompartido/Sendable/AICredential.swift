//
//  AICredential.swift
//  SwiftHablare
//
//  Credential types and validation for secure AI service authentication
//

import Foundation

/// Represents different types of credentials supported by AI service providers
public enum AICredentialType: String, Sendable, Codable {
    case apiKey = "api_key"
    case oauthToken = "oauth_token"
    case certificate = "certificate"
    case custom = "custom"
}

/// A secure credential for authenticating with AI service providers
public struct AICredential: Sendable, Codable {
    /// Unique identifier for the credential
    public let id: UUID

    /// Provider this credential belongs to
    public let providerID: String

    /// Type of credential
    public let type: AICredentialType

    /// Display name for UI purposes
    public let name: String

    /// Optional description
    public let description: String?

    /// Creation date
    public let createdAt: Date

    /// Last updated date
    public var updatedAt: Date

    /// Expiration date (nil if no expiration)
    public var expiresAt: Date?

    /// Whether this credential is currently valid
    public var isValid: Bool {
        guard let expiresAt else { return true }
        return Date() < expiresAt
    }

    /// Whether this credential is expired
    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt
    }

    /// Days until expiration (nil if no expiration or already expired)
    public var daysUntilExpiration: Int? {
        guard let expiresAt, !isExpired else { return nil }
        let interval = expiresAt.timeIntervalSinceNow
        return max(0, Int(interval / 86400))
    }

    /// Custom metadata (e.g., scopes, permissions)
    public var metadata: [String: String]

    /// Initialize a new credential
    public init(
        id: UUID = UUID(),
        providerID: String,
        type: AICredentialType,
        name: String,
        description: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        expiresAt: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.providerID = providerID
        self.type = type
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
        self.metadata = metadata
    }
}

/// Secure string wrapper that clears memory on deallocation
public final class SecureString: @unchecked Sendable {
    private var _value: String
    private let lock = NSLock()

    public init(_ value: String) {
        self._value = value
    }

    public var value: String {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    /// Clear the string from memory
    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        // Overwrite memory with zeros before deallocation
        let length = _value.utf8.count
        _value = String(repeating: "\0", count: length)
        _value = ""
    }

    deinit {
        clear()
    }
}

/// Validator for credential values
public struct AICredentialValidator: Sendable {
    /// Validate an API key format
    public static func validateAPIKey(_ key: String, for providerID: String) throws {
        // Trim whitespace
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if empty
        guard !trimmed.isEmpty else {
            throw AICredentialError.invalidFormat("API key cannot be empty")
        }

        // Check minimum length
        guard trimmed.count >= 8 else {
            throw AICredentialError.invalidFormat("API key must be at least 8 characters")
        }

        // Provider-specific validation
        switch providerID {
        case "openai":
            // OpenAI keys start with "sk-" or "sk-proj-"
            guard trimmed.hasPrefix("sk-") else {
                throw AICredentialError.invalidFormat("OpenAI API keys must start with 'sk-'")
            }

        case "anthropic":
            // Anthropic keys start with "sk-ant-"
            guard trimmed.hasPrefix("sk-ant-") else {
                throw AICredentialError.invalidFormat("Anthropic API keys must start with 'sk-ant-'")
            }

        case "elevenlabs":
            // ElevenLabs keys are 32 character hex strings
            let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
            let keyCharacterSet = CharacterSet(charactersIn: trimmed)
            guard trimmed.count == 32, hexCharacterSet.isSuperset(of: keyCharacterSet) else {
                throw AICredentialError.invalidFormat("ElevenLabs API keys must be 32-character hex strings")
            }

        default:
            // Generic validation for unknown providers
            // Just check for reasonable length
            guard trimmed.count >= 8 && trimmed.count <= 1024 else {
                throw AICredentialError.invalidFormat("API key length must be between 8 and 1024 characters")
            }
        }
    }

    /// Validate an OAuth token format
    public static func validateOAuthToken(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw AICredentialError.invalidFormat("OAuth token cannot be empty")
        }

        guard trimmed.count >= 16 else {
            throw AICredentialError.invalidFormat("OAuth token must be at least 16 characters")
        }
    }

    /// Validate a certificate data
    public static func validateCertificate(_ data: Data) throws {
        guard !data.isEmpty else {
            throw AICredentialError.invalidFormat("Certificate data cannot be empty")
        }

        guard data.count >= 100 else {
            throw AICredentialError.invalidFormat("Certificate data appears too small to be valid")
        }
    }
}

/// Errors related to credential management
public enum AICredentialError: LocalizedError, Sendable {
    case invalidFormat(String)
    case expired
    case notFound
    case alreadyExists
    case validationFailed(String)
    case keychainError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let message):
            return "Invalid credential format: \(message)"
        case .expired:
            return "Credential has expired"
        case .notFound:
            return "Credential not found"
        case .alreadyExists:
            return "Credential already exists"
        case .validationFailed(let message):
            return "Credential validation failed: \(message)"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        }
    }
}
