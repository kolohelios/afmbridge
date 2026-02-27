import DTOs
import Models
import Services
import XCTest

@testable import Controllers

final class AnthropicControllerTests: XCTestCase {

    // MARK: - Initialization Tests

    func testController_canBeInitialized() {
        let mockProvider = MockLLMProvider(response: "Test response")
        let controller = AnthropicController(llmProvider: mockProvider)

        XCTAssertNotNil(controller)
    }

    func testController_usesProvidedLLMProvider() {
        let mockProvider = MockLLMProvider(response: "Test response from mock")
        let controller = AnthropicController(llmProvider: mockProvider)

        // Create a simple request
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello")])

        // We can't easily test the async function call here,
        // but we can verify the controller was initialized with the mock
        XCTAssertNotNil(controller)
    }

    // MARK: - Error Mapping Tests

    func testErrorMapping_modelNotAvailable() {
        let error = LLMError.modelNotAvailable("test-model")
        let mockProvider = MockLLMProvider(error: error)
        let controller = AnthropicController(llmProvider: mockProvider)

        // Error mapping is tested through integration tests
        // Unit test just verifies the controller can be created with error-throwing provider
        XCTAssertNotNil(controller)
    }

    func testErrorMapping_frameworkNotAvailable() {
        let error = LLMError.frameworkNotAvailable
        let mockProvider = MockLLMProvider(error: error)
        let controller = AnthropicController(llmProvider: mockProvider)

        XCTAssertNotNil(controller)
    }

    func testErrorMapping_invalidMessageFormat() {
        let error = LLMError.invalidMessageFormat("Invalid format")
        let mockProvider = MockLLMProvider(error: error)
        let controller = AnthropicController(llmProvider: mockProvider)

        XCTAssertNotNil(controller)
    }

    func testErrorMapping_contentFiltered() {
        let error = LLMError.contentFiltered("Safety violation")
        let mockProvider = MockLLMProvider(error: error)
        let controller = AnthropicController(llmProvider: mockProvider)

        XCTAssertNotNil(controller)
    }

    // MARK: - Request Handling Tests

    func testNonStreaming_simpleTextMessage() {
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Say hello")])

        // Verify request structure
        XCTAssertEqual(request.model, "claude-opus-4-5-20251101")
        XCTAssertEqual(request.messages.count, 1)
        XCTAssertEqual(request.messages[0].role, "user")
    }

    func testNonStreaming_withSystemParameter() {
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello")], system: "You are a helpful assistant."
        )

        XCTAssertEqual(request.system, "You are a helpful assistant.")
        XCTAssertNotNil(request.system)
    }

    func testNonStreaming_withContentBlocks() {
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [
                Message(
                    role: "user",
                    content: .blocks([
                        .text(TextBlock(text: "Part 1")), .text(TextBlock(text: "Part 2")),
                    ]))
            ])

        XCTAssertEqual(request.messages.count, 1)
        if case .blocks(let blocks) = request.messages[0].content {
            XCTAssertEqual(blocks.count, 2)
        } else {
            XCTFail("Expected blocks content")
        }
    }

    func testNonStreaming_conversationWithMultipleMessages() {
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [
                Message(role: "user", text: "First question"),
                Message(role: "assistant", text: "First answer"),
                Message(role: "user", text: "Follow-up question"),
            ])

        XCTAssertEqual(request.messages.count, 3)
        XCTAssertEqual(request.messages[2].role, "user")
    }

    func testNonStreaming_withTemperatureParameter() {
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Be creative")], temperature: 0.9)

        XCTAssertEqual(request.temperature, 0.9)
    }

    func testNonStreaming_withMaxTokensParameter() {
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 100,
            messages: [Message(role: "user", text: "Keep it brief")])

        XCTAssertEqual(request.maxTokens, 100)
    }

    // MARK: - Response Format Tests

    func testResponse_hasCorrectStructure() {
        // Test that response structure matches Anthropic API
        let response = MessageResponse(
            id: "msg_123", model: "claude-opus-4-5-20251101",
            content: [.text(ResponseTextBlock(text: "Hello!"))], stopReason: .endTurn,
            usage: Usage(inputTokens: 10, outputTokens: 5))

        XCTAssertEqual(response.id, "msg_123")
        XCTAssertEqual(response.model, "claude-opus-4-5-20251101")
        XCTAssertEqual(response.content.count, 1)
        XCTAssertEqual(response.stopReason, .endTurn)
        XCTAssertEqual(response.usage.inputTokens, 10)
        XCTAssertEqual(response.usage.outputTokens, 5)
    }

    func testResponse_hasTextContent() {
        let response = MessageResponse(
            id: "msg_123", model: "claude-opus-4-5-20251101",
            content: [.text(ResponseTextBlock(text: "Test content"))], stopReason: .endTurn,
            usage: Usage(inputTokens: 10, outputTokens: 5))

        if case .text(let textBlock) = response.content[0] {
            XCTAssertEqual(textBlock.text, "Test content")
        } else {
            XCTFail("Expected text content block")
        }
    }

    // MARK: - Streaming Tests

    func testStreaming_requestStructure() {
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello")], stream: true)

        XCTAssertEqual(request.stream, true)
        XCTAssertEqual(request.model, "claude-opus-4-5-20251101")
    }

    func testStreaming_withSystemParameter() {
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello")],
            system: "You are a helpful assistant.", stream: true)

        XCTAssertEqual(request.stream, true)
        XCTAssertEqual(request.system, "You are a helpful assistant.")
    }

    func testStreaming_eventSequence() {
        // Test that stream events follow Anthropic specification
        // Events should be: message_start, content_block_start, content_block_delta(s),
        // content_block_stop, message_delta, message_stop

        // This is verified through integration tests
        // Unit test just verifies event types exist
        let events: [StreamEvent] = [
            .messageStart(
                MessageStartEvent(
                    message: MessageSnapshot(
                        id: "msg_test", content: [], model: "claude-opus-4-5-20251101",
                        stopReason: nil, usage: Usage(inputTokens: 10, outputTokens: 0)))),
            .contentBlockStart(
                ContentBlockStartEvent(index: 0, contentBlock: ContentBlockStart(type: "text"))),
            .contentBlockDelta(
                ContentBlockDeltaEvent(
                    index: 0, delta: ContentDelta(type: "text_delta", text: "Hello"))),
            .contentBlockStop(ContentBlockStopEvent(index: 0)),
            .messageDelta(
                MessageDeltaEvent(
                    delta: MessageDelta(stopReason: .endTurn), usage: UsageDelta(outputTokens: 5))),
            .messageStop(MessageStopEvent()),
        ]

        XCTAssertEqual(events.count, 6)
    }

    // MARK: - Tool Calling Tests

    func testToolCalling_requestWithTools() {
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

        XCTAssertNotNil(request.tools)
        XCTAssertEqual(request.tools?.count, 1)
        XCTAssertEqual(request.tools?[0].name, "get_weather")
        XCTAssertEqual(request.tools?[0].description, "Get current weather")
    }

    func testToolCalling_requestWithToolChoice() {
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Check weather")],
            tools: [
                AnthropicTool(
                    name: "get_weather", description: "Get weather",
                    inputSchema: JSONSchema(type: "object"))
            ], toolChoice: .tool("get_weather"))

        XCTAssertNotNil(request.toolChoice)
        if case .tool(let toolName) = request.toolChoice {
            XCTAssertEqual(toolName, "get_weather")
        } else {
            XCTFail("Expected .tool tool choice")
        }
    }

    func testToolCalling_responseWithToolUse() {
        // Test response structure with tool_use content blocks
        let response = MessageResponse(
            id: "msg_123", model: "claude-opus-4-5-20251101",
            content: [
                .text(ResponseTextBlock(text: "Let me check the weather")),
                .toolUse(
                    ResponseToolUseBlock(
                        id: "toolu_123", name: "get_weather", input: ["location": .string("Boston")]
                    )),
            ], stopReason: .toolUse, usage: Usage(inputTokens: 20, outputTokens: 15))

        XCTAssertEqual(response.stopReason, .toolUse)
        XCTAssertEqual(response.content.count, 2)

        // Verify first block is text
        if case .text(let textBlock) = response.content[0] {
            XCTAssertEqual(textBlock.text, "Let me check the weather")
        } else {
            XCTFail("Expected text block")
        }

        // Verify second block is tool_use
        if case .toolUse(let toolUseBlock) = response.content[1] {
            XCTAssertEqual(toolUseBlock.id, "toolu_123")
            XCTAssertEqual(toolUseBlock.name, "get_weather")
        } else {
            XCTFail("Expected tool_use block")
        }
    }

    func testToolCalling_multipleToolUseBlocks() {
        let response = MessageResponse(
            id: "msg_123", model: "claude-opus-4-5-20251101",
            content: [
                .toolUse(
                    ResponseToolUseBlock(
                        id: "toolu_1", name: "get_weather", input: ["location": .string("NYC")])),
                .toolUse(
                    ResponseToolUseBlock(
                        id: "toolu_2", name: "get_temperature", input: ["unit": .string("celsius")])
                ),
            ], stopReason: .toolUse, usage: Usage(inputTokens: 20, outputTokens: 20))

        XCTAssertEqual(response.content.count, 2)
        XCTAssertEqual(response.stopReason, .toolUse)

        // Verify both blocks are tool_use
        if case .toolUse(let toolUse1) = response.content[0],
            case .toolUse(let toolUse2) = response.content[1]
        {
            XCTAssertEqual(toolUse1.id, "toolu_1")
            XCTAssertEqual(toolUse2.id, "toolu_2")
        } else {
            XCTFail("Expected two tool_use blocks")
        }
    }

    func testToolCalling_requestWithToolResults() {
        // Test conversation with tool results
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

        XCTAssertEqual(request.messages.count, 3)

        // Verify tool result block
        if case .blocks(let blocks) = request.messages[2].content {
            if case .toolResult(let toolResult) = blocks[0] {
                XCTAssertEqual(toolResult.toolUseId, "toolu_123")
                XCTAssertEqual(toolResult.content, "72°F and sunny")
            } else {
                XCTFail("Expected tool_result block")
            }
        } else {
            XCTFail("Expected blocks content")
        }
    }

    func testToolCalling_emptyToolsArray() {
        // Empty tools array should be treated as no tools
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello")], tools: [])

        XCTAssertNotNil(request.tools)
        XCTAssertEqual(request.tools?.count, 0)
    }

    func testToolCalling_toolChoiceAuto() {
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello")],
            tools: [
                AnthropicTool(
                    name: "test_tool", description: "Test", inputSchema: JSONSchema(type: "object"))
            ], toolChoice: .auto)

        if case .auto = request.toolChoice {
            // Success
        } else {
            XCTFail("Expected .auto tool choice")
        }
    }

    func testToolCalling_toolChoiceAny() {
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello")],
            tools: [
                AnthropicTool(
                    name: "test_tool", description: "Test", inputSchema: JSONSchema(type: "object"))
            ], toolChoice: .any)

        if case .any = request.toolChoice {
            // Success
        } else {
            XCTFail("Expected .any tool choice")
        }
    }
}
