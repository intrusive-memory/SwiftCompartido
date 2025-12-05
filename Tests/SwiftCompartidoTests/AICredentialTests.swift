//
//  AICredentialTests.swift
//  SwiftHablare
//
//  Tests for credential types and validation
//

import Foundation
import Testing
@testable import SwiftCompartido

struct AICredentialTests {
    // MARK: - AICredential Tests

    @Test func testCredentialInitialization() {
        let credential = AICredential(
            providerID: "openai",
            type: .apiKey,
            name: "OpenAI API Key",
            description: "Production API key"
        )

        #expect(credential.providerID == "openai")
        #expect(credential.type == .apiKey)
        #expect(credential.name == "OpenAI API Key")
        #expect(credential.description == "Production API key")
        #expect(credential.metadata.isEmpty)
    }

    @Test func testCredentialValidityWithoutExpiration() {
        let credential = AICredential(
            providerID: "anthropic",
            type: .apiKey,
            name: "Test Key",
            expiresAt: nil
        )

        #expect(credential.isValid)
        #expect(!credential.isExpired)
        #expect(credential.daysUntilExpiration == nil)
    }

    @Test func testCredentialValidityWithFutureExpiration() {
        let futureDate = Date().addingTimeInterval(86400 * 30) // 30 days
        let credential = AICredential(
            providerID: "elevenlabs",
            type: .apiKey,
            name: "Test Key",
            expiresAt: futureDate
        )

        #expect(credential.isValid)
        #expect(!credential.isExpired)
        #expect(credential.daysUntilExpiration != nil)
        #expect(credential.daysUntilExpiration! >= 29)
    }

    @Test func testCredentialExpiration() {
        let pastDate = Date().addingTimeInterval(-86400) // Yesterday
        let credential = AICredential(
            providerID: "openai",
            type: .apiKey,
            name: "Expired Key",
            expiresAt: pastDate
        )

        #expect(!credential.isValid)
        #expect(credential.isExpired)
        #expect(credential.daysUntilExpiration == nil)
    }

    @Test func testCredentialMetadata() {
        var credential = AICredential(
            providerID: "openai",
            type: .oauthToken,
            name: "OAuth Token",
            metadata: ["scope": "read write", "refresh_token": "xyz"]
        )

        #expect(credential.metadata["scope"] == "read write")
        #expect(credential.metadata["refresh_token"] == "xyz")

        credential.metadata["expires_in"] = "3600"
        #expect(credential.metadata.count == 3)
    }

    @Test func testCredentialCodable() throws {
        let original = AICredential(
            providerID: "anthropic",
            type: .apiKey,
            name: "Test Key",
            description: "Test description",
            expiresAt: Date(),
            metadata: ["key": "value"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AICredential.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.providerID == original.providerID)
        #expect(decoded.type == original.type)
        #expect(decoded.name == original.name)
        #expect(decoded.description == original.description)
        #expect(decoded.metadata == original.metadata)
    }

    // MARK: - SecureString Tests

    @Test func testSecureStringInitialization() {
        let secureString = SecureString("test-secret-value")
        #expect(secureString.value == "test-secret-value")
    }

    @Test func testSecureStringClear() {
        let secureString = SecureString("test-secret-value")
        #expect(secureString.value == "test-secret-value")

        secureString.clear()
        #expect(secureString.value == "")
    }

    @Test func testSecureStringDeinit() {
        var secureString: SecureString? = SecureString("test-secret-value")
        #expect(secureString != nil)

        secureString = nil
        // Test passes if no crash occurs
        #expect(secureString == nil)
    }

    // MARK: - AICredentialValidator Tests

    @Test func testValidateAPIKey_Empty() throws {
        #expect(throws: AICredentialError.self) {
            try AICredentialValidator.validateAPIKey("", for: "openai")
        }
    }

    @Test func testValidateAPIKey_TooShort() throws {
        do { _ = try AICredentialValidator.validateAPIKey("short", for: "openai"); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testValidateAPIKey_OpenAI_Valid() throws {
        _ = try AICredentialValidator.validateAPIKey("sk-1234567890abcdef", for: "openai")
        _ = try AICredentialValidator.validateAPIKey("sk-proj-1234567890abcdef", for: "openai")
    }

    @Test func testValidateAPIKey_OpenAI_Invalid() throws {
        do { _ = try AICredentialValidator.validateAPIKey("invalid-key", for: "openai"); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testValidateAPIKey_Anthropic_Valid() throws {
        _ = try AICredentialValidator.validateAPIKey("sk-ant-1234567890abcdef", for: "anthropic")
    }

    @Test func testValidateAPIKey_Anthropic_Invalid() throws {
        do { _ = try AICredentialValidator.validateAPIKey("sk-1234567890", for: "anthropic"); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testValidateAPIKey_ElevenLabs_Valid() throws {
        _ = try AICredentialValidator.validateAPIKey("0123456789abcdef0123456789abcdef", for: "elevenlabs")
        _ = try AICredentialValidator.validateAPIKey("ABCDEF1234567890ABCDEF1234567890", for: "elevenlabs")
    }

    @Test func testValidateAPIKey_ElevenLabs_Invalid() throws {
        // Too short
        do { _ = try AICredentialValidator.validateAPIKey("0123456789abcdef", for: "elevenlabs"); Issue.record("Expected error") } catch { /* Expected */ }

        // Too long
        do { _ = try AICredentialValidator.validateAPIKey("0123456789abcdef0123456789abcdef00", for: "elevenlabs"); Issue.record("Expected error") } catch { /* Expected */ }

        // Invalid characters
        do { _ = try AICredentialValidator.validateAPIKey("0123456789abcdefghij0123456789ab", for: "elevenlabs"); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testValidateAPIKey_UnknownProvider() throws {
        // Should accept any reasonable length for unknown providers
        _ = try AICredentialValidator.validateAPIKey("12345678", for: "unknown-provider")
        _ = try AICredentialValidator.validateAPIKey(String(repeating: "a", count: 100), for: "custom-provider")
    }

    @Test func testValidateAPIKey_UnknownProvider_TooLong() throws {
        let tooLong = String(repeating: "a", count: 1025)
        do { _ = try AICredentialValidator.validateAPIKey(tooLong, for: "custom-provider"); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testValidateAPIKey_Whitespace() throws {
        // Should handle leading/trailing whitespace
        _ = try AICredentialValidator.validateAPIKey("  sk-1234567890abcdef  ", for: "openai")
    }

    @Test func testValidateOAuthToken_Valid() throws {
        _ = try AICredentialValidator.validateOAuthToken("1234567890abcdef1234567890abcdef")
    }

    @Test func testValidateOAuthToken_Empty() throws {
        do { _ = try AICredentialValidator.validateOAuthToken(""); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testValidateOAuthToken_TooShort() throws {
        do { _ = try AICredentialValidator.validateOAuthToken("short"); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testValidateCertificate_Valid() throws {
        let validData = Data(repeating: 0x42, count: 200)
        _ = try AICredentialValidator.validateCertificate(validData)
    }

    @Test func testValidateCertificate_Empty() throws {
        do { _ = try AICredentialValidator.validateCertificate(Data()); Issue.record("Expected error") } catch { /* Expected */ }
    }

    @Test func testValidateCertificate_TooSmall() throws {
        let tooSmall = Data(repeating: 0x42, count: 50)
        do { _ = try AICredentialValidator.validateCertificate(tooSmall); Issue.record("Expected error") } catch { /* Expected */ }
    }

    // MARK: - AICredentialError Tests

    @Test func testCredentialErrorDescriptions() {
        let errors: [(AICredentialError, String)] = [
            (.invalidFormat("test"), "Invalid credential format: test"),
            (.expired, "Credential has expired"),
            (.notFound, "Credential not found"),
            (.alreadyExists, "Credential already exists"),
            (.validationFailed("test"), "Credential validation failed: test"),
            (.keychainError("test"), "Keychain error: test")
        ]

        for (error, expectedMessage) in errors {
            #expect(error.errorDescription == expectedMessage)
        }
    }
}
