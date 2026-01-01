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

/// Integration tests for Anthropic Messages API support
final class AnthropicIntegrationTests: XCTestCase {

    // MARK: - Helper Methods

    /// Creates a configured Vapor application with mock LLM provider for testing
    private func makeTestApp() async throws -> Application {
        let app = try await Application.make(.testing)
        let mockProvider = MockLLMProvider(response: "Test response from Anthropic-compatible API")
        try await configure(app, llmProvider: mockProvider)
        return app
    }

    // MARK: - Non-Streaming Tests

    func testMessages_withValidRequest_returnsResponse() async throws {
        // Given: A configured Vapor application
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a valid message request
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello, how are you?")])

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return 200 OK with valid response
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(MessageResponse.self)
            XCTAssertEqual(response.type, "message")
            XCTAssertEqual(response.model, "claude-opus-4-5-20251101")
            XCTAssertEqual(response.role, "assistant")
            XCTAssertEqual(response.content.count, 1)
            XCTAssertEqual(response.stopReason, .endTurn)
            XCTAssertGreaterThan(response.usage.inputTokens, 0)
            XCTAssertGreaterThan(response.usage.outputTokens, 0)

            // Verify content is text block
            if case .text(let textBlock) = response.content[0] {
                XCTAssertFalse(textBlock.text.isEmpty)
            } else {
                XCTFail("Expected text content block")
            }
        }
    }

    func testMessages_withSystemParameter_includesInstructions() async throws {
        // Given: A configured Vapor application
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request with system parameter
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello!")],
            system: "You are a helpful assistant.")

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return 200 OK
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(MessageResponse.self)
            XCTAssertEqual(response.content.count, 1)
            if case .text(let textBlock) = response.content[0] {
                XCTAssertFalse(textBlock.text.isEmpty)
            } else {
                XCTFail("Expected text content block")
            }
        }
    }

    func testMessages_withContentBlocks_returnsResponse() async throws {
        // Given: A configured Vapor application
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request with content blocks
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [
                Message(
                    role: "user",
                    content: .blocks([
                        .text(TextBlock(text: "First part")), .text(TextBlock(text: "Second part")),
                    ]))
            ])

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return 200 OK
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(MessageResponse.self)
            XCTAssertEqual(response.content.count, 1)
        }
    }

    func testMessages_withEmptyMessages_returns400() async throws {
        // Given: A configured Vapor application
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request with no messages
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024, messages: [])

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async in
            // Then: Should return 400 Bad Request
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    func testMessages_withInvalidJSON_returns400() async throws {
        // Given: A configured Vapor application
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending invalid JSON
        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: "{invalid json}")
            }
        ) { res async in
            // Then: Should return 400 Bad Request
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    // MARK: - Streaming Tests

    func testMessages_withStreamingRequest_returnsSSE() async throws {
        // Given: A configured Vapor application
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a streaming request
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello!")], stream: true)

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return 200 OK with SSE headers
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.contentType?.type, "text")
            XCTAssertEqual(res.headers.contentType?.subType, "event-stream")
            XCTAssertEqual(res.headers.cacheControl?.noCache, true)

            // Verify SSE data format
            let bodyString = res.body.string
            XCTAssertTrue(bodyString.contains("event: message_start"))
            XCTAssertTrue(bodyString.contains("event: content_block_start"))
            XCTAssertTrue(bodyString.contains("event: content_block_delta"))
            XCTAssertTrue(bodyString.contains("event: content_block_stop"))
            XCTAssertTrue(bodyString.contains("event: message_delta"))
            XCTAssertTrue(bodyString.contains("event: message_stop"))
        }
    }

    func testMessages_streamingEventSequence() async throws {
        // Given: A configured Vapor application
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a streaming request
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Count to 5")], stream: true)

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should have proper event sequence
            let bodyString = res.body.string

            // Events should appear in order
            let messageStartIndex = bodyString.range(of: "event: message_start")?.lowerBound
            let blockStartIndex = bodyString.range(of: "event: content_block_start")?.lowerBound
            let deltaIndex = bodyString.range(of: "event: content_block_delta")?.lowerBound
            let blockStopIndex = bodyString.range(of: "event: content_block_stop")?.lowerBound
            let messageDeltaIndex = bodyString.range(of: "event: message_delta")?.lowerBound
            let messageStopIndex = bodyString.range(of: "event: message_stop")?.lowerBound

            XCTAssertNotNil(messageStartIndex)
            XCTAssertNotNil(blockStartIndex)
            XCTAssertNotNil(deltaIndex)
            XCTAssertNotNil(blockStopIndex)
            XCTAssertNotNil(messageDeltaIndex)
            XCTAssertNotNil(messageStopIndex)

            // Verify order
            if let ms = messageStartIndex, let bs = blockStartIndex, let d = deltaIndex,
                let bstop = blockStopIndex, let md = messageDeltaIndex, let mstop = messageStopIndex
            {
                XCTAssertLessThan(ms, bs)
                XCTAssertLessThan(bs, d)
                XCTAssertLessThan(d, bstop)
                XCTAssertLessThan(bstop, md)
                XCTAssertLessThan(md, mstop)
            }
        }
    }

    // MARK: - Configuration Tests

    func testServerConfig_loadsFromEnvironment() {
        let config = ServerConfig()
        XCTAssertNotNil(config.hostname)
        XCTAssertNotNil(config.port)
    }
}
