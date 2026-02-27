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

/// Integration tests for Anthropic tool calling support
final class AnthropicToolCallingIntegrationTests: XCTestCase {

    // MARK: - Helper Methods

    /// Creates a configured Vapor application with mock LLM provider for testing
    private func makeTestApp(
        response: String? = nil, toolCalls: [ToolCall]? = nil
    ) async throws -> Application {
        let app = try await Application.make(.testing)
        let mockProvider = MockLLMProvider(
            response: response ?? "Test response", toolCalls: toolCalls)
        try await configure(app, llmProvider: mockProvider)
        return app
    }

    // MARK: - Tool Calling Request Tests

    func testToolCalling_withTools_returnsToolUseBlocks() async throws {
        // Given: A configured app with mock that returns tool calls
        let toolCall = ToolCall(
            id: "toolu_123", name: "get_weather", arguments: "{\"location\":\"Boston\"}")
        let app = try await makeTestApp(response: "Let me check", toolCalls: [toolCall])
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request with tool definitions
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "What's the weather in Boston?")],
            tools: [
                AnthropicTool(
                    name: "get_weather", description: "Get current weather",
                    inputSchema: JSONSchema(
                        type: "object", properties: ["location": ["type": .string("string")]],
                        required: ["location"]))
            ])

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return 200 OK with tool_use blocks
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(MessageResponse.self)
            XCTAssertEqual(response.stopReason, .toolUse)
            XCTAssertEqual(response.content.count, 2)

            // Verify text block
            if case .text(let textBlock) = response.content[0] {
                XCTAssertEqual(textBlock.text, "Let me check")
            } else {
                XCTFail("Expected text content block")
            }

            // Verify tool_use block
            if case .toolUse(let toolUseBlock) = response.content[1] {
                XCTAssertEqual(toolUseBlock.id, "toolu_123")
                XCTAssertEqual(toolUseBlock.name, "get_weather")
                XCTAssertNotNil(toolUseBlock.input["location"])
            } else {
                XCTFail("Expected tool_use content block")
            }
        }
    }

    func testToolCalling_multipleTools_returnsMultipleToolUseBlocks() async throws {
        // Given: A configured app with mock that returns multiple tool calls
        let toolCalls = [
            ToolCall(id: "toolu_1", name: "get_weather", arguments: "{\"location\":\"NYC\"}"),
            ToolCall(id: "toolu_2", name: "get_temperature", arguments: "{\"unit\":\"celsius\"}"),
        ]
        let app = try await makeTestApp(response: nil, toolCalls: toolCalls)
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request with multiple tool definitions
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Check NYC weather")],
            tools: [
                AnthropicTool(
                    name: "get_weather", description: "Get weather",
                    inputSchema: JSONSchema(type: "object")),
                AnthropicTool(
                    name: "get_temperature", description: "Get temperature",
                    inputSchema: JSONSchema(type: "object")),
            ])

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return tool_use blocks for both tools
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(MessageResponse.self)
            XCTAssertEqual(response.stopReason, .toolUse)

            // Count tool_use blocks
            let toolUseBlocks = response.content.compactMap { block -> ResponseToolUseBlock? in
                if case .toolUse(let toolUse) = block { return toolUse }
                return nil
            }

            XCTAssertEqual(toolUseBlocks.count, 2)
            XCTAssertEqual(toolUseBlocks[0].id, "toolu_1")
            XCTAssertEqual(toolUseBlocks[1].id, "toolu_2")
        }
    }

    func testToolCalling_noToolCalls_returnsFinalResponse() async throws {
        // Given: A configured app with mock that returns no tool calls
        let app = try await makeTestApp(response: "I can help without tools", toolCalls: nil)
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request with tools but model doesn't call them
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello")],
            tools: [
                AnthropicTool(
                    name: "test_tool", description: "Test", inputSchema: JSONSchema(type: "object"))
            ])

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return final response with end_turn
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(MessageResponse.self)
            XCTAssertEqual(response.stopReason, .endTurn)
            XCTAssertEqual(response.content.count, 1)

            if case .text(let textBlock) = response.content[0] {
                XCTAssertEqual(textBlock.text, "I can help without tools")
            } else {
                XCTFail("Expected text content block")
            }
        }
    }

    func testToolCalling_emptyToolsArray_ignoresToolCalling() async throws {
        // Given: A configured app with standard response
        let app = try await makeTestApp(response: "Regular response")
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request with empty tools array
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello")], tools: [])

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should handle as regular request
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(MessageResponse.self)
            XCTAssertEqual(response.stopReason, .endTurn)
        }
    }

    // MARK: - Tool Result Submission Tests

    func testToolCalling_toolResultSubmission_returnsFinalResponse() async throws {
        // Given: A configured app
        let app = try await makeTestApp(response: "The weather in Boston is 72°F and sunny!")
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a conversation with tool results
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [
                Message(role: "user", text: "What's the weather in Boston?"),
                Message(
                    role: "assistant",
                    content: .blocks([
                        .text(TextBlock(text: "Let me check")),
                        .toolUse(
                            ToolUseBlock(
                                id: "toolu_123", name: "get_weather",
                                input: ["location": .string("Boston")])),
                    ])),
                Message(
                    role: "user",
                    content: .blocks([
                        .toolResult(
                            ToolResultBlock(toolUseId: "toolu_123", content: "72°F and sunny"))
                    ])),
            ])

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return final response incorporating tool results
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(MessageResponse.self)
            XCTAssertEqual(response.stopReason, .endTurn)
            XCTAssertEqual(response.content.count, 1)

            if case .text(let textBlock) = response.content[0] {
                XCTAssertTrue(textBlock.text.contains("72°F"))
            } else {
                XCTFail("Expected text content block")
            }
        }
    }

    func testToolCalling_multipleToolResults_processesAll() async throws {
        // Given: A configured app
        let app = try await makeTestApp(response: "Processed all tool results")
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a conversation with multiple tool results
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [
                Message(role: "user", text: "Check multiple things"),
                Message(
                    role: "assistant",
                    content: .blocks([
                        .toolUse(
                            ToolUseBlock(
                                id: "toolu_1", name: "tool_a", input: ["param": .string("val1")])),
                        .toolUse(
                            ToolUseBlock(
                                id: "toolu_2", name: "tool_b", input: ["param": .string("val2")])),
                    ])),
                Message(
                    role: "user",
                    content: .blocks([
                        .toolResult(ToolResultBlock(toolUseId: "toolu_1", content: "Result 1")),
                        .toolResult(ToolResultBlock(toolUseId: "toolu_2", content: "Result 2")),
                    ])),
            ])

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should return final response
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(MessageResponse.self)
            XCTAssertEqual(response.stopReason, .endTurn)
        }
    }

    // MARK: - Tool Choice Tests

    func testToolCalling_toolChoiceAuto_allowsModelDecision() async throws {
        // Given: A configured app
        let toolCall = ToolCall(id: "toolu_123", name: "test_tool", arguments: "{}")
        let app = try await makeTestApp(toolCalls: [toolCall])
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request with tool_choice: auto
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Test")],
            tools: [
                AnthropicTool(
                    name: "test_tool", description: "Test", inputSchema: JSONSchema(type: "object"))
            ], toolChoice: .auto)

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should handle request successfully
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testToolCalling_toolChoiceSpecific_requestsSpecificTool() async throws {
        // Given: A configured app
        let toolCall = ToolCall(id: "toolu_123", name: "specific_tool", arguments: "{}")
        let app = try await makeTestApp(toolCalls: [toolCall])
        defer { Task { try await app.asyncShutdown() } }

        // When: Sending a request with specific tool choice
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Test")],
            tools: [
                AnthropicTool(
                    name: "specific_tool", description: "Test",
                    inputSchema: JSONSchema(type: "object"))
            ], toolChoice: .tool("specific_tool"))

        try await app.test(
            .POST, "v1/messages",
            beforeRequest: { req async throws in try req.content.encode(request) }
        ) { res async throws in
            // Then: Should handle request successfully
            XCTAssertEqual(res.status, .ok)
        }
    }
}
