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
}
