import Configuration
import Controllers
import DTOs
import Models
import NIOCore
import Services
import Vapor
import XCTVapor
import XCTest

@testable import App

/// Integration tests for Phase 1 - OpenAI API non-streaming support
final class Phase1IntegrationTests: XCTestCase {

    // MARK: - Helper Methods

    /// Creates a configured Vapor application with mock LLM provider for testing
    private func makeTestApp() async throws -> Application {
        let app = try await Application.make(.testing)
        let mockProvider = MockLLMProvider(response: "Test response from mock provider")
        try await configure(app, llmProvider: mockProvider)
        return app
    }

    // MARK: - Health Endpoint Tests

    func testHealthEndpoint_returnsOK() async throws {
        // Given: A configured Vapor application
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // When: Requesting the health endpoint
        try await app.test(.GET, "health") { res async in
            // Then: Should return 200 OK
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "OK")
        }
    }

    // MARK: - Chat Completions Endpoint Tests

    func testChatCompletions_withValidRequest_returnsResponse() async throws {
        // Given: A configured Vapor application
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a valid chat completion request
        let request = ChatCompletionRequest(
            model: "gpt-4o", messages: [ChatMessage(role: "user", content: "Hello, how are you?")],
            stream: nil, maxTokens: nil, temperature: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return 200 OK with valid response
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(ChatCompletionResponse.self)
            XCTAssertEqual(response.object, "chat.completion")
            XCTAssertEqual(response.model, "gpt-4o")
            XCTAssertEqual(response.choices.count, 1)
            XCTAssertEqual(response.choices[0].index, 0)
            XCTAssertEqual(response.choices[0].message.role, "assistant")
            XCTAssertFalse(response.choices[0].message.content.isEmpty)
            XCTAssertEqual(response.choices[0].finishReason, "stop")
        }
    }

    func testChatCompletions_withSystemMessage_includesInstructions() async throws {
        // Given: A configured Vapor application
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request with system message
        let request = ChatCompletionRequest(
            model: "gpt-4o",
            messages: [
                ChatMessage(role: "system", content: "You are a helpful assistant."),
                ChatMessage(role: "user", content: "Hello!"),
            ], stream: nil, maxTokens: nil, temperature: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return 200 OK
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(ChatCompletionResponse.self)
            XCTAssertEqual(response.choices.count, 1)
            XCTAssertFalse(response.choices[0].message.content.isEmpty)
        }
    }

    func testChatCompletions_withStreamingRequest_returnsSSE() async throws {
        // Given: A configured Vapor application
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a streaming request (supported in Phase 2)
        let request = ChatCompletionRequest(
            model: "gpt-4o", messages: [ChatMessage(role: "user", content: "Hello!")], stream: true,
            maxTokens: nil, temperature: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return 200 OK with SSE content type
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.contentType?.type, "text")
            XCTAssertEqual(res.headers.contentType?.subType, "event-stream")
            XCTAssertEqual(res.headers.cacheControl?.noCache, true)

            // Verify SSE formatted response
            let body = res.body.string
            XCTAssertTrue(body.contains("data: "))
            XCTAssertTrue(body.contains("[DONE]"))
        }
    }

    func testChatCompletions_withEmptyMessages_returns400() async throws {
        // Given: A configured Vapor application
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request with no user messages
        let request = ChatCompletionRequest(
            model: "gpt-4o",
            messages: [ChatMessage(role: "system", content: "You are a helpful assistant.")],
            stream: nil, maxTokens: nil, temperature: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return 400 Bad Request
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    func testChatCompletions_withInvalidJSON_returns400() async throws {
        // Given: A configured Vapor application
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending invalid JSON
        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: "{invalid json}")
            }
        ) { res async throws in
            // Then: Should return 400 Bad Request
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    // MARK: - Configuration Tests

    func testServerConfig_loadsFromEnvironment() async throws {
        // Given: Environment variables are set
        // When: Creating ServerConfig
        let config = ServerConfig()

        // Then: Should use values from environment or defaults
        XCTAssertNotNil(config.hostname)
        XCTAssertNotNil(config.port)
        XCTAssertNotNil(config.maxTokens)
        XCTAssertNotNil(config.logLevel)
    }
}
