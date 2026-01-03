import DTOs
import Models
import Vapor

/// Middleware that catches errors and formats them according to the API format
public struct APIErrorMiddleware: AsyncMiddleware {
    public init() {}

    public func respond(
        to request: Request, chainingTo next: any AsyncResponder
    ) async throws -> Response {
        do { return try await next.respond(to: request) } catch {
            return handleError(error, for: request)
        }
    }

    private func handleError(_ error: Error, for request: Request) -> Response {
        let path = request.url.path

        // Determine if this is an Anthropic or OpenAI endpoint
        let isAnthropicEndpoint = path.contains("/v1/messages")

        // Extract HTTP status and message from error
        let (status, message, errorType) = extractErrorDetails(from: error)

        // Log the error
        request.logger.error(
            "Request error",
            metadata: [
                "error": .string("\(error)"), "status": .string("\(status.code)"),
                "path": .string(path),
            ])

        // Format error response based on API
        let response = Response(status: status)
        response.headers.contentType = .json

        do {
            if isAnthropicEndpoint {
                let errorResponse = AnthropicErrorResponse(
                    error: AnthropicError(type: errorType, message: message))
                try response.content.encode(errorResponse)
            } else {
                let errorResponse = OpenAIErrorResponse(
                    error: OpenAIError(message: message, type: errorType))
                try response.content.encode(errorResponse)
            }
        } catch {
            // Fallback to plain text if encoding fails
            response.body = .init(string: message)
        }

        return response
    }

    private func extractErrorDetails(from error: Error) -> (HTTPStatus, String, String) {
        // Handle Vapor Abort errors
        if let abort = error as? Abort {
            let errorType = mapStatusToErrorType(abort.status)
            return (abort.status, abort.reason, errorType)
        }

        // Handle LLM-specific errors
        if let llmError = error as? LLMError { return mapLLMError(llmError) }

        // Handle validation errors
        if error is DecodingError {
            return (.badRequest, "Invalid request format", "invalid_request_error")
        }

        // Generic server error
        return (.internalServerError, "Internal server error", "api_error")
    }

    private func mapLLMError(_ error: LLMError) -> (HTTPStatus, String, String) {
        switch error {
        case .modelNotAvailable(let model):
            return (.serviceUnavailable, "Model \(model) is not available", "model_not_available")
        case .frameworkNotAvailable:
            return (
                .serviceUnavailable,
                "Apple Intelligence framework is not available (requires macOS 26.0+)",
                "framework_not_available"
            )
        case .invalidMessageFormat(let message):
            return (.badRequest, "Invalid message format: \(message)", "invalid_request_error")
        case .contentFiltered(let reason):
            return (.badRequest, "Content filtered: \(reason)", "content_filter_error")
        }
    }

    private func mapStatusToErrorType(_ status: HTTPStatus) -> String {
        switch status {
        case .badRequest: return "invalid_request_error"
        case .unauthorized: return "authentication_error"
        case .forbidden: return "permission_error"
        case .notFound: return "not_found_error"
        case .tooManyRequests: return "rate_limit_error"
        case .internalServerError, .serviceUnavailable: return "api_error"
        default: return "api_error"
        }
    }
}
