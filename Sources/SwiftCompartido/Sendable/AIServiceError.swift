import Foundation

/// Comprehensive error types for AI service operations.
///
/// Provides detailed error information for debugging and user feedback.
/// All errors include descriptive messages and can be localized.
///
/// ## Topics
/// ### Configuration Errors
/// - ``configurationError(_:)``
/// - ``invalidAPIKey(_:)``
/// - ``missingCredentials(_:)``
///
/// ### Network Errors
/// - ``networkError(_:)``
/// - ``timeout(_:)``
/// - ``connectionFailed(_:)``
///
/// ### Provider Errors
/// - ``providerError(_:code:)``
/// - ``rateLimitExceeded(_:retryAfter:)``
/// - ``authenticationFailed(_:)``
/// - ``invalidRequest(_:)``
///
/// ### Data Errors
/// - ``validationError(_:)``
/// - ``unexpectedResponseFormat(_:)``
/// - ``dataConversionError(_:)``
///
/// ### Storage Errors
/// - ``persistenceError(_:)``
/// - ``modelNotFound(_:)``
///
/// ## Example
/// ```swift
/// do {
///     try await provider.generate(prompt: "test", parameters: [:], context: context)
/// } catch AIServiceError.configurationError(let message) {
///     print("Configuration issue: \(message)")
/// } catch AIServiceError.rateLimitExceeded(let message, let retryAfter) {
///     print("Rate limited. Retry after \(retryAfter ?? 0) seconds")
/// }
/// ```

public enum AIServiceError: Error, Sendable {
    // MARK: - Configuration Errors

    /// Provider configuration is invalid or incomplete.
    case configurationError(String)

    /// API key format is invalid or key is revoked.
    case invalidAPIKey(String)

    /// Required credentials are missing.
    case missingCredentials(String)

    // MARK: - Network Errors

    /// Network request failed.
    case networkError(String)

    /// Request timed out.
    case timeout(String)

    /// Could not establish connection to service.
    case connectionFailed(String)

    // MARK: - Provider Errors

    /// Provider-specific error occurred.
    ///
    /// - Parameters:
    ///   - message: Error description
    ///   - code: Optional provider-specific error code
    case providerError(String, code: String? = nil)

    /// Rate limit exceeded.
    ///
    /// - Parameters:
    ///   - message: Error description
    ///   - retryAfter: Seconds until rate limit resets (if known)
    case rateLimitExceeded(String, retryAfter: TimeInterval? = nil)

    /// Authentication failed (invalid API key, expired token, etc.).
    case authenticationFailed(String)

    /// Request format is invalid or parameters are incorrect.
    case invalidRequest(String)

    // MARK: - Data Errors

    /// Data validation failed.
    case validationError(String)

    /// Response format doesn't match expected structure.
    case unexpectedResponseFormat(String)

    /// Could not convert data to expected type.
    case dataConversionError(String)

    /// Could not bind value to model property.
    case dataBindingError(String)

    // MARK: - Storage Errors

    /// SwiftData persistence operation failed.
    case persistenceError(String)

    /// Referenced model could not be found.
    case modelNotFound(String)

    // MARK: - Operation Errors

    /// The requested operation is not supported.
    case unsupportedOperation(String)

    // MARK: - Error Information

    /// User-friendly error message.
    public var errorDescription: String {
        switch self {
        case .configurationError(let message),
             .invalidAPIKey(let message),
             .missingCredentials(let message),
             .networkError(let message),
             .timeout(let message),
             .connectionFailed(let message),
             .providerError(let message, _),
             .rateLimitExceeded(let message, _),
             .authenticationFailed(let message),
             .invalidRequest(let message),
             .validationError(let message),
             .unexpectedResponseFormat(let message),
             .dataConversionError(let message),
             .dataBindingError(let message),
             .persistenceError(let message),
             .modelNotFound(let message),
             .unsupportedOperation(let message):
            return message
        }
    }

    /// Error category for logging and analytics.
    public var category: ErrorCategory {
        switch self {
        case .configurationError, .invalidAPIKey, .missingCredentials:
            return .configuration
        case .networkError, .timeout, .connectionFailed:
            return .network
        case .providerError, .rateLimitExceeded, .authenticationFailed, .invalidRequest:
            return .provider
        case .validationError, .unexpectedResponseFormat, .dataConversionError, .dataBindingError:
            return .data
        case .persistenceError, .modelNotFound:
            return .storage
        case .unsupportedOperation:
            return .operation
        }
    }

    /// Whether this error is recoverable with retry.
    public var isRecoverable: Bool {
        switch self {
        case .timeout, .connectionFailed, .networkError, .rateLimitExceeded:
            return true
        case .configurationError, .invalidAPIKey, .missingCredentials,
             .authenticationFailed, .invalidRequest, .validationError,
             .unexpectedResponseFormat, .dataConversionError, .dataBindingError,
             .persistenceError, .modelNotFound, .providerError, .unsupportedOperation:
            return false
        }
    }

    /// Suggested retry delay in seconds (for recoverable errors).
    public var retryDelay: TimeInterval? {
        switch self {
        case .rateLimitExceeded(_, let retryAfter):
            return retryAfter
        case .timeout, .connectionFailed:
            return 5.0 // 5 second default retry
        case .networkError:
            return 2.0 // 2 second default retry
        default:
            return nil
        }
    }
}

/// Error category for classification.

public enum ErrorCategory: String, Sendable {
    case configuration
    case network
    case provider
    case data
    case storage
    case operation
}

// MARK: - LocalizedError Conformance


extension AIServiceError: LocalizedError {
    public var localizedDescription: String {
        errorDescription
    }

    public var failureReason: String? {
        switch self {
        case .configurationError:
            return "Provider is not properly configured"
        case .invalidAPIKey:
            return "API key is invalid or has been revoked"
        case .missingCredentials:
            return "Required credentials are not available"
        case .networkError:
            return "Network request failed"
        case .timeout:
            return "Request timed out"
        case .connectionFailed:
            return "Could not connect to service"
        case .providerError:
            return "Service provider returned an error"
        case .rateLimitExceeded:
            return "API rate limit has been exceeded"
        case .authenticationFailed:
            return "Authentication with service failed"
        case .invalidRequest:
            return "Request format or parameters are invalid"
        case .validationError:
            return "Data validation failed"
        case .unexpectedResponseFormat:
            return "Response format is unexpected"
        case .dataConversionError:
            return "Could not convert data to expected type"
        case .dataBindingError:
            return "Could not bind data to model property"
        case .persistenceError:
            return "Database operation failed"
        case .modelNotFound:
            return "Referenced model does not exist"
        case .unsupportedOperation:
            return "Operation is not supported"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .configurationError, .invalidAPIKey, .missingCredentials:
            return "Check your provider configuration and API key in settings"
        case .networkError, .connectionFailed:
            return "Check your internet connection and try again"
        case .timeout:
            return "The request is taking longer than expected. Try again or use a shorter prompt"
        case .rateLimitExceeded(_, let retryAfter):
            if let delay = retryAfter {
                return "Wait \(Int(delay)) seconds before trying again"
            }
            return "Wait a moment before trying again"
        case .authenticationFailed:
            return "Verify your API key is correct and has not expired"
        case .invalidRequest:
            return "Check your request parameters and try again"
        case .validationError, .dataConversionError, .dataBindingError:
            return "Verify the data format matches requirements"
        case .unexpectedResponseFormat:
            return "The service may have changed. Check for framework updates"
        case .persistenceError:
            return "Check available storage space and try again"
        case .modelNotFound:
            return "Ensure the model exists in the database"
        case .providerError:
            return "Check the service status and your configuration"
        case .unsupportedOperation:
            return "This operation is not yet implemented"
        }
    }
}

// MARK: - CustomStringConvertible


extension AIServiceError: CustomStringConvertible {
    public var description: String {
        "AIServiceError.\(category.rawValue): \(errorDescription)"
    }
}
