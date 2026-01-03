import Configuration
import DTOs
import Models
import NIOCore
import Vapor
import XCTVapor
import XCTest

@testable import App

/// Tests for AuthenticationMiddleware
final class AuthenticationMiddlewareTests: XCTestCase {

    // MARK: - Unit Tests

    func testAuthenticationMiddleware_validToken_allowsRequest() async throws {
        let app = try await Application.make(.testing)
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 8080, maxTokens: 1024, logLevel: .info,
            apiKey: "test-api-key")
        let mockProvider = MockLLMProvider(response: "Hello from OpenAI!")
        try await configure(app, llmProvider: mockProvider, config: config)

        defer { Task { try await app.asyncShutdown() } }

        // Create a valid request with Bearer token
        let request = ChatCompletionRequest(
            model: "gpt-4o", messages: [ChatMessage(role: "user", content: "Hello")], stream: nil,
            maxTokens: nil, temperature: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in
                req.headers.bearerAuthorization = BearerAuthorization(token: "test-api-key")
                try req.content.encode(request)
            }
        ) { res async throws in XCTAssertEqual(res.status, .ok) }
    }

    func testAuthenticationMiddleware_invalidToken_returnsUnauthorized() async throws {
        let app = try await Application.make(.testing)
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 8080, maxTokens: 1024, logLevel: .info,
            apiKey: "test-api-key")
        let mockProvider = MockLLMProvider(response: "Hello from OpenAI!")
        try await configure(app, llmProvider: mockProvider, config: config)

        defer { Task { try await app.asyncShutdown() } }

        let request = ChatCompletionRequest(
            model: "gpt-4o", messages: [ChatMessage(role: "user", content: "Hello")], stream: nil,
            maxTokens: nil, temperature: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in
                req.headers.bearerAuthorization = BearerAuthorization(token: "wrong-key")
                try req.content.encode(request)
            }
        ) { res async throws in
            XCTAssertEqual(res.status, .unauthorized)

            let errorResponse = try res.content.decode(OpenAIErrorResponse.self)
            XCTAssertEqual(errorResponse.error.type, "authentication_error")
            XCTAssertTrue(errorResponse.error.message.contains("Invalid API key"))
        }
    }

    func testAuthenticationMiddleware_missingToken_returnsUnauthorized() async throws {
        let app = try await Application.make(.testing)
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 8080, maxTokens: 1024, logLevel: .info,
            apiKey: "test-api-key")
        let mockProvider = MockLLMProvider(response: "Hello from OpenAI!")
        try await configure(app, llmProvider: mockProvider, config: config)

        defer { Task { try await app.asyncShutdown() } }

        let request = ChatCompletionRequest(
            model: "gpt-4o", messages: [ChatMessage(role: "user", content: "Hello")], stream: nil,
            maxTokens: nil, temperature: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in
                // No Authorization header
                try req.content.encode(request)
            }
        ) { res async throws in
            XCTAssertEqual(res.status, .unauthorized)

            let errorResponse = try res.content.decode(OpenAIErrorResponse.self)
            XCTAssertEqual(errorResponse.error.type, "authentication_error")
            XCTAssertTrue(errorResponse.error.message.contains("Missing Authorization header"))
        }
    }

    func testAuthenticationMiddleware_malformedHeader_returnsUnauthorized() async throws {
        let app = try await Application.make(.testing)
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 8080, maxTokens: 1024, logLevel: .info,
            apiKey: "test-api-key")
        let mockProvider = MockLLMProvider(response: "Hello from OpenAI!")
        try await configure(app, llmProvider: mockProvider, config: config)

        defer { Task { try await app.asyncShutdown() } }

        let request = ChatCompletionRequest(
            model: "gpt-4o", messages: [ChatMessage(role: "user", content: "Hello")], stream: nil,
            maxTokens: nil, temperature: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in
                req.headers.add(name: .authorization, value: "InvalidFormat")
                try req.content.encode(request)
            }
        ) { res async throws in
            XCTAssertEqual(res.status, .unauthorized)

            let errorResponse = try res.content.decode(OpenAIErrorResponse.self)
            XCTAssertEqual(errorResponse.error.type, "authentication_error")
            XCTAssertTrue(
                errorResponse.error.message.contains("Invalid Authorization header format"))
        }
    }

    // MARK: - Integration Tests

    func testAuthDisabled_allowsRequestWithoutToken() async throws {
        // Create app WITHOUT API key (auth disabled)
        let app = try await Application.make(.testing)
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 8080, maxTokens: 1024, logLevel: .info, apiKey: nil)
        let mockProvider = MockLLMProvider(response: "Hello from OpenAI!")
        try await configure(app, llmProvider: mockProvider, config: config)

        defer { Task { try await app.asyncShutdown() } }

        let request = ChatCompletionRequest(
            model: "gpt-4o", messages: [ChatMessage(role: "user", content: "Hello")], stream: nil,
            maxTokens: nil, temperature: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in
                // No Authorization header
                try req.content.encode(request)
            }
        ) { res async throws in
            // Should succeed without auth when API key is not configured
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testAuthEnabled_protectsOpenAIEndpoint() async throws {
        let app = try await Application.make(.testing)
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 8080, maxTokens: 1024, logLevel: .info,
            apiKey: "secret-key")
        let mockProvider = MockLLMProvider(response: "Hello from OpenAI!")
        try await configure(app, llmProvider: mockProvider, config: config)

        defer { Task { try await app.asyncShutdown() } }

        let request = ChatCompletionRequest(
            model: "gpt-4o", messages: [ChatMessage(role: "user", content: "Hello")], stream: nil,
            maxTokens: nil, temperature: nil)

        // Test without token
        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in XCTAssertEqual(res.status, .unauthorized) }

        // Test with valid token
        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in
                req.headers.bearerAuthorization = BearerAuthorization(token: "secret-key")
                try req.content.encode(request)
            }
        ) { res async throws in XCTAssertEqual(res.status, .ok) }
    }

    func testAuthEnabled_protectsAnthropicEndpoint() async throws {
        let app = try await Application.make(.testing)
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 8080, maxTokens: 1024, logLevel: .info,
            apiKey: "secret-key")
        let mockProvider = MockLLMProvider(response: "Hello from Anthropic!")
        try await configure(app, llmProvider: mockProvider, config: config)

        defer { Task { try await app.asyncShutdown() } }

        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello")])

        // Test without token
        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in XCTAssertEqual(res.status, .unauthorized) }

        // Test with valid token
        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in
                req.headers.bearerAuthorization = BearerAuthorization(token: "secret-key")
                try req.content.encode(request)
            }
        ) { res async throws in XCTAssertEqual(res.status, .ok) }
    }

    func testAuthEnabled_errorResponsesMatchAPIFormat() async throws {
        let app = try await Application.make(.testing)
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 8080, maxTokens: 1024, logLevel: .info,
            apiKey: "secret-key")
        let mockProvider = MockLLMProvider(response: "Hello!")
        try await configure(app, llmProvider: mockProvider, config: config)

        defer { Task { try await app.asyncShutdown() } }

        // Test OpenAI error format
        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: "{}")
            }
        ) { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
            let errorResponse = try res.content.decode(OpenAIErrorResponse.self)
            XCTAssertEqual(errorResponse.error.type, "authentication_error")
        }

        // Test Anthropic error format
        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: "{}")
            }
        ) { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
            let errorResponse = try res.content.decode(AnthropicErrorResponse.self)
            XCTAssertEqual(errorResponse.type, "error")
            XCTAssertEqual(errorResponse.error.type, "authentication_error")
        }
    }
}
