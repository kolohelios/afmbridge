import Foundation
import Vapor

/// Anthropic-compatible error response
public struct AnthropicErrorResponse: Content {
    /// Always "error" for error responses
    public let type: String

    /// The error details
    public let error: AnthropicError

    public init(error: AnthropicError) {
        self.type = "error"
        self.error = error
    }
}

/// Anthropic error details
public struct AnthropicError: Codable, Sendable {
    /// Error type (e.g., "invalid_request_error", "api_error")
    public let type: String

    /// Human-readable error message
    public let message: String

    public init(type: String, message: String) {
        self.type = type
        self.message = message
    }
}
