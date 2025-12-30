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

/// Integration tests for Phase 3 - Tool calling E2E flows
final class ToolCallingIntegrationTests: XCTestCase {

    // MARK: - Helper Methods

    /// Creates a configured Vapor application with mock tool-calling LLM provider
    private func makeTestApp(
        response: String = "Default response", toolCalls: [ToolCall]? = nil
    ) async throws -> Application {
        let app = try await Application.make(.testing)
        let mockProvider = IntegrationMockLLMProvider(response: response, toolCalls: toolCalls)
        try await configure(app, llmProvider: mockProvider)
        return app
    }

    // MARK: - Simple Tool Calling Tests

    func testToolCalling_withTools_returnsToolCalls() async throws {
        // Given: A mock provider that returns tool calls
        let toolCall = ToolCall(
            id: "call_123", name: "get_weather", arguments: "{\"location\":\"Boston\"}")
        let app = try await makeTestApp(
            response: "I need to check the weather", toolCalls: [toolCall])
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request with tools
        let request = ChatCompletionRequest(
            model: "gpt-4o",
            messages: [ChatMessage(role: "user", content: "What's the weather in Boston?")],
            stream: false, maxTokens: nil, temperature: nil,
            tools: [
                Tool(
                    function: FunctionDefinition(
                        name: "get_weather", description: "Get current weather",
                        parameters: JSONSchema(
                            type: "object",
                            properties: [
                                "location": [
                                    "type": .string("string"), "description": .string("City name"),
                                ]
                            ], required: ["location"])))
            ], toolChoice: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return 200 OK with tool calls
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(ChatCompletionResponse.self)
            XCTAssertEqual(response.choices.count, 1)
            XCTAssertEqual(response.choices[0].finishReason, "tool_calls")

            let returnedToolCalls = response.choices[0].message.toolCalls
            XCTAssertNotNil(returnedToolCalls)
            XCTAssertEqual(returnedToolCalls?.count, 1)
            XCTAssertEqual(returnedToolCalls?[0].id, "call_123")
            XCTAssertEqual(returnedToolCalls?[0].function.name, "get_weather")
        }
    }

    func testToolCalling_withoutTools_returnsNormalResponse() async throws {
        // Given: A mock provider that returns normal content
        let app = try await makeTestApp(response: "Hello! I'm doing well, thank you.")
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request without tools
        let request = ChatCompletionRequest(
            model: "gpt-4o", messages: [ChatMessage(role: "user", content: "How are you?")],
            stream: false, maxTokens: nil, temperature: nil, tools: nil, toolChoice: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return 200 OK with normal content
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(ChatCompletionResponse.self)
            XCTAssertEqual(response.choices.count, 1)
            XCTAssertEqual(response.choices[0].finishReason, "stop")
            XCTAssertEqual(response.choices[0].message.content, "Hello! I'm doing well, thank you.")
            XCTAssertNil(response.choices[0].message.toolCalls)
        }
    }

    func testToolCalling_withToolsButNoCallsMade_returnsFinalContent() async throws {
        // Given: A mock provider with tools available but returns content without calling them
        let app = try await makeTestApp(response: "The answer is 42", toolCalls: nil)
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request with tools
        let request = ChatCompletionRequest(
            model: "gpt-4o", messages: [ChatMessage(role: "user", content: "What is the answer?")],
            stream: false, maxTokens: nil, temperature: nil,
            tools: [
                Tool(
                    function: FunctionDefinition(
                        name: "calculate", description: "Perform calculation",
                        parameters: JSONSchema(type: "object")))
            ], toolChoice: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return final content without tool calls
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(ChatCompletionResponse.self)
            XCTAssertEqual(response.choices[0].finishReason, "stop")
            XCTAssertEqual(response.choices[0].message.content, "The answer is 42")
            XCTAssertNil(response.choices[0].message.toolCalls)
        }
    }

    // MARK: - Multi-turn Tool Calling Tests

    func testToolCalling_multiTurnConversation_returnsFinalResponse() async throws {
        // Given: A mock provider that returns final response based on tool results
        let app = try await makeTestApp(response: "It's sunny and 72°F in Boston today!")
        defer { Task { try await app.asyncShutdown() } }

        // When: Submitting tool results in a multi-turn conversation
        let request = ChatCompletionRequest(
            model: "gpt-4o",
            messages: [
                ChatMessage(role: "user", content: "What's the weather in Boston?"),
                ChatMessage(
                    role: "assistant", content: nil,
                    toolCalls: [
                        ResponseToolCall(
                            id: "call_123",
                            function: FunctionCall(
                                name: "get_weather", arguments: "{\"location\":\"Boston\"}"))
                    ]),
                ChatMessage(
                    role: "tool", content: "Temperature: 72°F, Conditions: Sunny", toolCalls: nil,
                    toolCallId: "call_123", name: "get_weather"),
            ], stream: false, maxTokens: nil, temperature: nil, tools: nil, toolChoice: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return final response incorporating tool results
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(ChatCompletionResponse.self)
            XCTAssertEqual(response.choices[0].finishReason, "stop")
            XCTAssertNotNil(response.choices[0].message.content)
            XCTAssertTrue(
                response.choices[0].message.content?.contains("72") ?? false,
                "Response should include temperature from tool result")
        }
    }

    // MARK: - Streaming with Tools Tests

    func testToolCalling_streamingWithTools_fallsBackToNonStreaming() async throws {
        // Given: A mock provider with tools
        let toolCall = ToolCall(id: "call_abc", name: "calculate", arguments: "{\"x\":5,\"y\":3}")
        let app = try await makeTestApp(response: "Let me calculate that", toolCalls: [toolCall])
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a streaming request with tools
        let request = ChatCompletionRequest(
            model: "gpt-4o", messages: [ChatMessage(role: "user", content: "What is 5 + 3?")],
            stream: true, maxTokens: nil, temperature: nil,
            tools: [
                Tool(
                    function: FunctionDefinition(
                        name: "calculate", description: "Perform math",
                        parameters: JSONSchema(type: "object")))
            ], toolChoice: nil)

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should fall back to non-streaming and return tool calls
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.contentType, .json)  // Not SSE

            let response = try res.content.decode(ChatCompletionResponse.self)
            XCTAssertEqual(response.choices[0].finishReason, "tool_calls")
            XCTAssertNotNil(response.choices[0].message.toolCalls)
        }
    }

    // MARK: - Error Handling Tests

    func testToolCalling_withInvalidToolDefinition_returnsError() async throws {
        // Given: A configured application
        let app = try await makeTestApp()
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request with malformed JSON
        let invalidJSON = "{\"model\":\"gpt-4o\",\"messages\":[],\"tools\":[{\"invalid\":true}]}"

        try await app.test(
            .POST, "v1/chat/completions",
            beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: invalidJSON)
            }
        ) { res async throws in
            // Then: Should return 400 Bad Request
            XCTAssertEqual(res.status, .badRequest)
        }
    }
}

// MARK: - Mock Tool Calling Provider

/// Mock LLM provider that supports tool calling for integration tests
final class IntegrationMockLLMProvider: LLMProvider, @unchecked Sendable {
    private let response: String
    private let toolCalls: [ToolCall]?

    init(response: String, toolCalls: [ToolCall]?) {
        self.response = response
        self.toolCalls = toolCalls
    }

    func respond(to userPrompt: String, systemInstructions: String?) async throws -> String {
        response
    }

    func streamRespond(
        to userPrompt: String, systemInstructions: String?
    ) async throws -> AsyncThrowingStream<String, Error> {
        let capturedResponse = self.response

        return AsyncThrowingStream { continuation in
            Task {
                let chunkSize = max(1, capturedResponse.count / 5)
                var index = capturedResponse.startIndex

                while index < capturedResponse.endIndex {
                    let nextIndex =
                        capturedResponse.index(
                            index, offsetBy: chunkSize, limitedBy: capturedResponse.endIndex)
                        ?? capturedResponse.endIndex
                    let chunk = String(capturedResponse[index..<nextIndex])
                    continuation.yield(chunk)
                    index = nextIndex

                    try? await Task.sleep(nanoseconds: 10_000_000)
                }

                continuation.finish()
            }
        }
    }

    func respondWithTools(
        to userPrompt: String, tools: [ToolDefinition], toolExecutors: ToolRegistry,
        systemInstructions: String?
    ) async throws -> (content: String?, toolCalls: [ToolCall]?) {
        (content: response, toolCalls: toolCalls)
    }
}
