//
//  AICredentialTests.swift
//  SwiftHablare
//
//  Tests for credential types and validation
//

import XCTest
@testable import SwiftCompartido

final class AICredentialTests: XCTestCase {
    // MARK: - AICredential Tests

    func testCredentialInitialization() {
        let credential = AICredential(
            providerID: "openai",
            type: .apiKey,
            name: "OpenAI API Key",
            description: "Production API key"
        )

        XCTAssertEqual(credential.providerID, "openai")
        XCTAssertEqual(credential.type, .apiKey)
        XCTAssertEqual(credential.name, "OpenAI API Key")
        XCTAssertEqual(credential.description, "Production API key")
        XCTAssertTrue(credential.metadata.isEmpty)
    }

    func testCredentialValidityWithoutExpiration() {
        let credential = AICredential(
            providerID: "anthropic",
            type: .apiKey,
            name: "Test Key",
            expiresAt: nil
        )

        XCTAssertTrue(credential.isValid)
        XCTAssertFalse(credential.isExpired)
        XCTAssertNil(credential.daysUntilExpiration)
    }

    func testCredentialValidityWithFutureExpiration() {
        let futureDate = Date().addingTimeInterval(86400 * 30) // 30 days
        let credential = AICredential(
            providerID: "elevenlabs",
            type: .apiKey,
            name: "Test Key",
            expiresAt: futureDate
        )

        XCTAssertTrue(credential.isValid)
        XCTAssertFalse(credential.isExpired)
        XCTAssertNotNil(credential.daysUntilExpiration)
        XCTAssertGreaterThanOrEqual(credential.daysUntilExpiration!, 29)
    }

    func testCredentialExpiration() {
        let pastDate = Date().addingTimeInterval(-86400) // Yesterday
        let credential = AICredential(
            providerID: "openai",
            type: .apiKey,
            name: "Expired Key",
            expiresAt: pastDate
        )

        XCTAssertFalse(credential.isValid)
        XCTAssertTrue(credential.isExpired)
        XCTAssertNil(credential.daysUntilExpiration)
    }

    func testCredentialMetadata() {
        var credential = AICredential(
            providerID: "openai",
            type: .oauthToken,
            name: "OAuth Token",
            metadata: ["scope": "read write", "refresh_token": "xyz"]
        )

        XCTAssertEqual(credential.metadata["scope"], "read write")
        XCTAssertEqual(credential.metadata["refresh_token"], "xyz")

        credential.metadata["expires_in"] = "3600"
        XCTAssertEqual(credential.metadata.count, 3)
    }

    func testCredentialCodable() throws {
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

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.providerID, original.providerID)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertEqual(decoded.metadata, original.metadata)
    }

    // MARK: - SecureString Tests

    func testSecureStringInitialization() {
        let secureString = SecureString("test-secret-value")
        XCTAssertEqual(secureString.value, "test-secret-value")
    }

    func testSecureStringClear() {
        let secureString = SecureString("test-secret-value")
        XCTAssertEqual(secureString.value, "test-secret-value")

        secureString.clear()
        XCTAssertEqual(secureString.value, "")
    }

    func testSecureStringDeinit() {
        var secureString: SecureString? = SecureString("test-secret-value")
        XCTAssertNotNil(secureString)

        secureString = nil
        // Test passes if no crash occurs
        XCTAssertNil(secureString)
    }

    // MARK: - AICredentialValidator Tests

    func testValidateAPIKey_Empty() {
        XCTAssertThrowsError(try AICredentialValidator.validateAPIKey("", for: "openai")) { error in
            guard case AICredentialError.invalidFormat(let message) = error else {
                XCTFail("Expected invalidFormat error")
                return
            }
            XCTAssertTrue(message.contains("empty"))
        }
    }

    func testValidateAPIKey_TooShort() {
        XCTAssertThrowsError(try AICredentialValidator.validateAPIKey("short", for: "openai")) { error in
            guard case AICredentialError.invalidFormat(let message) = error else {
                XCTFail("Expected invalidFormat error")
                return
            }
            XCTAssertTrue(message.contains("8 characters"))
        }
    }

    func testValidateAPIKey_OpenAI_Valid() {
        XCTAssertNoThrow(try AICredentialValidator.validateAPIKey("sk-1234567890abcdef", for: "openai"))
        XCTAssertNoThrow(try AICredentialValidator.validateAPIKey("sk-proj-1234567890abcdef", for: "openai"))
    }

    func testValidateAPIKey_OpenAI_Invalid() {
        XCTAssertThrowsError(try AICredentialValidator.validateAPIKey("invalid-key", for: "openai")) { error in
            guard case AICredentialError.invalidFormat(let message) = error else {
                XCTFail("Expected invalidFormat error")
                return
            }
            XCTAssertTrue(message.contains("sk-"))
        }
    }

    func testValidateAPIKey_Anthropic_Valid() {
        XCTAssertNoThrow(try AICredentialValidator.validateAPIKey("sk-ant-1234567890abcdef", for: "anthropic"))
    }

    func testValidateAPIKey_Anthropic_Invalid() {
        XCTAssertThrowsError(try AICredentialValidator.validateAPIKey("sk-1234567890", for: "anthropic")) { error in
            guard case AICredentialError.invalidFormat(let message) = error else {
                XCTFail("Expected invalidFormat error")
                return
            }
            XCTAssertTrue(message.contains("sk-ant-"))
        }
    }

    func testValidateAPIKey_ElevenLabs_Valid() {
        XCTAssertNoThrow(try AICredentialValidator.validateAPIKey("0123456789abcdef0123456789abcdef", for: "elevenlabs"))
        XCTAssertNoThrow(try AICredentialValidator.validateAPIKey("ABCDEF1234567890ABCDEF1234567890", for: "elevenlabs"))
    }

    func testValidateAPIKey_ElevenLabs_Invalid() {
        // Too short
        XCTAssertThrowsError(try AICredentialValidator.validateAPIKey("0123456789abcdef", for: "elevenlabs"))

        // Too long
        XCTAssertThrowsError(try AICredentialValidator.validateAPIKey("0123456789abcdef0123456789abcdef00", for: "elevenlabs"))

        // Invalid characters
        XCTAssertThrowsError(try AICredentialValidator.validateAPIKey("0123456789abcdefghij0123456789ab", for: "elevenlabs"))
    }

    func testValidateAPIKey_UnknownProvider() {
        // Should accept any reasonable length for unknown providers
        XCTAssertNoThrow(try AICredentialValidator.validateAPIKey("12345678", for: "unknown-provider"))
        XCTAssertNoThrow(try AICredentialValidator.validateAPIKey(String(repeating: "a", count: 100), for: "custom-provider"))
    }

    func testValidateAPIKey_UnknownProvider_TooLong() {
        let tooLong = String(repeating: "a", count: 1025)
        XCTAssertThrowsError(try AICredentialValidator.validateAPIKey(tooLong, for: "custom-provider"))
    }

    func testValidateAPIKey_Whitespace() {
        // Should handle leading/trailing whitespace
        XCTAssertNoThrow(try AICredentialValidator.validateAPIKey("  sk-1234567890abcdef  ", for: "openai"))
    }

    func testValidateOAuthToken_Valid() {
        XCTAssertNoThrow(try AICredentialValidator.validateOAuthToken("1234567890abcdef1234567890abcdef"))
    }

    func testValidateOAuthToken_Empty() {
        XCTAssertThrowsError(try AICredentialValidator.validateOAuthToken("")) { error in
            guard case AICredentialError.invalidFormat(let message) = error else {
                XCTFail("Expected invalidFormat error")
                return
            }
            XCTAssertTrue(message.contains("empty"))
        }
    }

    func testValidateOAuthToken_TooShort() {
        XCTAssertThrowsError(try AICredentialValidator.validateOAuthToken("short")) { error in
            guard case AICredentialError.invalidFormat(let message) = error else {
                XCTFail("Expected invalidFormat error")
                return
            }
            XCTAssertTrue(message.contains("16 characters"))
        }
    }

    func testValidateCertificate_Valid() {
        let validData = Data(repeating: 0x42, count: 200)
        XCTAssertNoThrow(try AICredentialValidator.validateCertificate(validData))
    }

    func testValidateCertificate_Empty() {
        XCTAssertThrowsError(try AICredentialValidator.validateCertificate(Data())) { error in
            guard case AICredentialError.invalidFormat(let message) = error else {
                XCTFail("Expected invalidFormat error")
                return
            }
            XCTAssertTrue(message.contains("empty"))
        }
    }

    func testValidateCertificate_TooSmall() {
        let tooSmall = Data(repeating: 0x42, count: 50)
        XCTAssertThrowsError(try AICredentialValidator.validateCertificate(tooSmall)) { error in
            guard case AICredentialError.invalidFormat(let message) = error else {
                XCTFail("Expected invalidFormat error")
                return
            }
            XCTAssertTrue(message.contains("too small"))
        }
    }

    // MARK: - AICredentialError Tests

    func testCredentialErrorDescriptions() {
        let errors: [(AICredentialError, String)] = [
            (.invalidFormat("test"), "Invalid credential format: test"),
            (.expired, "Credential has expired"),
            (.notFound, "Credential not found"),
            (.alreadyExists, "Credential already exists"),
            (.validationFailed("test"), "Credential validation failed: test"),
            (.keychainError("test"), "Keychain error: test")
        ]

        for (error, expectedMessage) in errors {
            XCTAssertEqual(error.errorDescription, expectedMessage)
        }
    }
}
