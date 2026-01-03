import Configuration
import DTOs
import Models
import NIOCore
import Vapor
import XCTVapor
import XCTest

@testable import App

/// Integration tests for APIErrorMiddleware
final class ErrorMiddlewareTests: XCTestCase {

    // MARK: - Helper Methods

    /// Creates a test application with APIErrorMiddleware registered
    private func makeTestApp() async throws -> Application {
        let app = try await Application.make(.testing)
        // Mock provider that throws errors for testing
        let mockProvider = MockLLMProvider(error: LLMError.modelNotAvailable("test-model"))
        try await configure(app, llmProvider: mockProvider)
        return app
    }

    // MARK: - OpenAI Error Format Tests

    func testOpenAI_invalidRequest_returnsFormattedError() async throws {
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // Send invalid JSON to trigger decoding error
        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: "{invalid json}")
            }
        ) { res async throws in
            XCTAssertEqual(res.status, .badRequest)

            let errorResponse = try res.content.decode(OpenAIErrorResponse.self)
            XCTAssertEqual(errorResponse.error.type, "invalid_request_error")
            XCTAssertFalse(errorResponse.error.message.isEmpty)
        }
    }

    func testOpenAI_emptyMessages_returnsFormattedError() async throws {
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        let request = ChatCompletionRequest(
            model: "gpt-4o", messages: [], stream: nil, maxTokens: nil, temperature: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            XCTAssertEqual(res.status, .badRequest)

            let errorResponse = try res.content.decode(OpenAIErrorResponse.self)
            XCTAssertEqual(errorResponse.error.type, "invalid_request_error")
            XCTAssertTrue(errorResponse.error.message.contains("message"))
        }
    }

    func testOpenAI_modelNotAvailable_returnsFormattedError() async throws {
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        let request = ChatCompletionRequest(
            model: "gpt-4o", messages: [ChatMessage(role: "user", content: "Hello")], stream: nil,
            maxTokens: nil, temperature: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            XCTAssertEqual(res.status, .serviceUnavailable)

            let errorResponse = try res.content.decode(OpenAIErrorResponse.self)
            XCTAssertEqual(errorResponse.error.type, "api_error")
            XCTAssertTrue(errorResponse.error.message.contains("test-model"))
        }
    }

    // MARK: - Anthropic Error Format Tests

    func testAnthropic_invalidRequest_returnsFormattedError() async throws {
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // Send invalid JSON to trigger decoding error
        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: "{invalid json}")
            }
        ) { res async throws in
            XCTAssertEqual(res.status, .badRequest)

            let errorResponse = try res.content.decode(AnthropicErrorResponse.self)
            XCTAssertEqual(errorResponse.type, "error")
            XCTAssertEqual(errorResponse.error.type, "invalid_request_error")
            XCTAssertFalse(errorResponse.error.message.isEmpty)
        }
    }

    func testAnthropic_emptyMessages_returnsFormattedError() async throws {
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024, messages: [])

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            XCTAssertEqual(res.status, .badRequest)

            let errorResponse = try res.content.decode(AnthropicErrorResponse.self)
            XCTAssertEqual(errorResponse.type, "error")
            XCTAssertEqual(errorResponse.error.type, "invalid_request_error")
            XCTAssertTrue(errorResponse.error.message.contains("message"))
        }
    }

    func testAnthropic_modelNotAvailable_returnsFormattedError() async throws {
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello")])

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            XCTAssertEqual(res.status, .serviceUnavailable)

            let errorResponse = try res.content.decode(AnthropicErrorResponse.self)
            XCTAssertEqual(errorResponse.type, "error")
            XCTAssertEqual(errorResponse.error.type, "api_error")
            XCTAssertTrue(errorResponse.error.message.contains("test-model"))
        }
    }

    // MARK: - Error Type Mapping Tests

    func testAPIErrorMiddleware_mapsLLMErrorsCorrectly() async throws {
        // Test different LLMError cases
        // Note: Controllers map LLMError to Abort, so middleware sees HTTP status codes
        let errorCases: [(LLMError, HTTPStatus, String)] = [
            (.modelNotAvailable("gpt-4"), .serviceUnavailable, "api_error"),
            (.frameworkNotAvailable, .serviceUnavailable, "api_error"),
            (.invalidMessageFormat("bad format"), .badRequest, "invalid_request_error"),
            (.contentFiltered("unsafe"), .badRequest, "invalid_request_error"),
        ]

        for (llmError, expectedStatus, expectedType) in errorCases {
            let app = try await Application.make(.testing)
            let mockProvider = MockLLMProvider(error: llmError)
            try await configure(app, llmProvider: mockProvider)
            defer { Task { try await app.asyncShutdown() } }

            let request = ChatCompletionRequest(
                model: "gpt-4o", messages: [ChatMessage(role: "user", content: "Test")],
                stream: nil, maxTokens: nil, temperature: nil)

            try await app.test(
                .POST, "v1/chat/completions",
                beforeRequest: { req async throws in try req.content.encode(request) }
            ) { res async throws in
                XCTAssertEqual(res.status, expectedStatus)

                let errorResponse = try res.content.decode(OpenAIErrorResponse.self)
                XCTAssertEqual(errorResponse.error.type, expectedType)
            }
        }
    }

    // MARK: - Content Type Tests

    func testErrorResponses_haveCorrectContentType() async throws {
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: "{}")
            }
        ) { res async in XCTAssertEqual(res.headers.contentType, .json) }
    }
}
