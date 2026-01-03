import Foundation
import Vapor

/// OpenAI-compatible error response
public struct OpenAIErrorResponse: Content {
    /// The error object containing details
    public let error: OpenAIError

    public init(error: OpenAIError) { self.error = error }
}

/// OpenAI error details
public struct OpenAIError: Codable, Sendable {
    /// Human-readable error message
    public let message: String

    /// Error type (e.g., "invalid_request_error", "server_error")
    public let type: String

    /// The parameter that caused the error, if applicable
    public let param: String?

    /// Error code, if applicable
    public let code: String?

    public init(message: String, type: String, param: String? = nil, code: String? = nil) {
        self.message = message
        self.type = type
        self.param = param
        self.code = code
    }
}
