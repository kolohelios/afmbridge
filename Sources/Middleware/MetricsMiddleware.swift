import Foundation
import NIOCore
import Vapor

/// Middleware for logging request/response metrics including token counts and performance
public struct MetricsMiddleware: AsyncMiddleware {
    public init() {}

    public func respond(
        to request: Request, chainingTo next: any AsyncResponder
    ) async throws -> Response {
        let startTime = Date()
        let requestId = UUID().uuidString

        // Log incoming request
        let inputTokens = estimateTokens(from: request)
        request.logger.info(
            "Request started",
            metadata: [
                "request_id": .string(requestId), "method": .string(request.method.rawValue),
                "path": .string(request.url.path), "input_tokens": .string("\(inputTokens)"),
            ])

        // Get response
        let response = try await next.respond(to: request)

        // Check if this is a streaming response
        let isStreaming = response.headers.contentType?.subType == "event-stream"

        // Calculate metrics
        let setupDuration = Date().timeIntervalSince(startTime)

        if isStreaming {
            // For streaming, we can only measure setup time (TTFT will be measured in controller)
            request.logger.info(
                "Streaming started",
                metadata: [
                    "request_id": .string(requestId), "status": .string("\(response.status.code)"),
                    "setup_ms": .string(String(format: "%.2f", setupDuration * 1000)),
                    "input_tokens": .string("\(inputTokens)"),
                    "note": .string("output metrics tracked per-chunk in controller"),
                ])
        } else {
            // Calculate full metrics for non-streaming response
            let outputTokens = estimateTokens(from: response)
            let totalTokens = inputTokens + outputTokens
            let tokensPerSecond = setupDuration > 0 ? Int(Double(totalTokens) / setupDuration) : 0

            // Log completion with metrics
            request.logger.info(
                "Request completed",
                metadata: [
                    "request_id": .string(requestId), "status": .string("\(response.status.code)"),
                    "duration_ms": .string(String(format: "%.2f", setupDuration * 1000)),
                    "input_tokens": .string("\(inputTokens)"),
                    "output_tokens": .string("\(outputTokens)"),
                    "total_tokens": .string("\(totalTokens)"),
                    "tokens_per_second": .string("\(tokensPerSecond)"),
                ])
        }

        return response
    }

    /// Estimate token count from request body
    /// Rough approximation: ~4 characters per token for English text
    private func estimateTokens(from request: Request) -> Int {
        guard let body = request.body.string else { return 0 }
        return max(1, body.count / 4)
    }

    /// Estimate token count from response body (non-streaming only)
    private func estimateTokens(from response: Response) -> Int {
        guard let body = response.body.string else { return 0 }
        return max(1, body.count / 4)
    }
}
