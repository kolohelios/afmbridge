import Models
import XCTest

@testable import DTOs

/// Tests for Anthropic Messages API DTOs
final class AnthropicDTOTests: XCTestCase {

    // MARK: - MessageRequest Tests

    func testMessageRequest_minimalRequest() throws {
        let request = MessageRequest(
            model: "claude-opus-4-5-20251101", maxTokens: 1024,
            messages: [Message(role: "user", text: "Hello")])

        XCTAssertEqual(request.model, "claude-opus-4-5-20251101")
        XCTAssertEqual(request.maxTokens, 1024)
        XCTAssertEqual(request.messages.count, 1)
    }

    func testMessageRequest_encoding() throws {
        let request = MessageRequest(
            model: "claude-sonnet-4-5", maxTokens: 2048,
            messages: [Message(role: "user", text: "Test")], temperature: 0.7)

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["model"] as? String, "claude-sonnet-4-5")
        XCTAssertEqual(json?["max_tokens"] as? Int, 2048)
        XCTAssertEqual(json?["temperature"] as? Double, 0.7)
    }

    func testMessageRequest_decoding() throws {
        let json = """
            {
                "model": "claude-opus-4-5-20251101",
                "max_tokens": 1024,
                "messages": [
                    {
                        "role": "user",
                        "content": "Hello"
                    }
                ]
            }
            """

        let decoder = JSONDecoder()
        let request = try decoder.decode(MessageRequest.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(request.model, "claude-opus-4-5-20251101")
        XCTAssertEqual(request.maxTokens, 1024)
        XCTAssertEqual(request.messages.count, 1)
    }

    //MARK: - Message Tests

    func testMessage_textContent() throws {
        let message = Message(role: "user", text: "Hello")

        XCTAssertEqual(message.role, "user")
        if case .text(let text) = message.content {
            XCTAssertEqual(text, "Hello")
        } else {
            XCTFail("Expected text content")
        }
    }

    func testMessage_encodingSimpleText() throws {
        let message = Message(role: "user", text: "Test message")

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["role"] as? String, "user")
        XCTAssertEqual(json?["content"] as? String, "Test message")
    }

    // MARK: - MessageResponse Tests

    func testMessageResponse_encoding() throws {
        let response = MessageResponse(
            id: "msg_123", model: "claude-opus-4-5-20251101",
            content: [.text(ResponseTextBlock(text: "Hello!"))], stopReason: .endTurn,
            usage: Usage(inputTokens: 10, outputTokens: 5))

        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["type"] as? String, "message")
        XCTAssertEqual(json?["id"] as? String, "msg_123")
        XCTAssertEqual(json?["model"] as? String, "claude-opus-4-5-20251101")
        XCTAssertEqual(json?["role"] as? String, "assistant")
    }

    func testMessageResponse_decoding() throws {
        let json = """
            {
                "type": "message",
                "id": "msg_456",
                "model": "claude-opus-4-5-20251101",
                "role": "assistant",
                "content": [
                    {
                        "type": "text",
                        "text": "Hello!"
                    }
                ],
                "stop_reason": "end_turn",
                "usage": {
                    "input_tokens": 15,
                    "output_tokens": 10
                }
            }
            """

        let decoder = JSONDecoder()
        let response = try decoder.decode(MessageResponse.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(response.id, "msg_456")
        XCTAssertEqual(response.stopReason, .endTurn)
        XCTAssertEqual(response.usage.inputTokens, 15)
        XCTAssertEqual(response.usage.outputTokens, 10)
    }

    // MARK: - StopReason Tests

    func testStopReason_allCases() throws {
        XCTAssertEqual(StopReason.endTurn.rawValue, "end_turn")
        XCTAssertEqual(StopReason.maxTokens.rawValue, "max_tokens")
        XCTAssertEqual(StopReason.stopSequence.rawValue, "stop_sequence")
        XCTAssertEqual(StopReason.toolUse.rawValue, "tool_use")
    }

    // MARK: - StreamEvent Tests

    func testStreamEvent_messageStart() throws {
        let usage = Usage(inputTokens: 10, outputTokens: 0)
        let snapshot = MessageSnapshot(
            id: "msg_789", content: [], model: "claude-opus-4-5-20251101", stopReason: nil,
            usage: usage)
        let event = StreamEvent.messageStart(MessageStartEvent(message: snapshot))

        if case .messageStart(let startEvent) = event {
            XCTAssertEqual(startEvent.message.id, "msg_789")
            XCTAssertEqual(startEvent.message.usage.inputTokens, 10)
        } else {
            XCTFail("Expected messageStart event")
        }
    }

    func testStreamEvent_contentBlockDelta() throws {
        let delta = ContentDelta(type: "text_delta", text: "Hello", partialJson: nil)
        let event = StreamEvent.contentBlockDelta(ContentBlockDeltaEvent(index: 0, delta: delta))

        if case .contentBlockDelta(let deltaEvent) = event {
            XCTAssertEqual(deltaEvent.index, 0)
            XCTAssertEqual(deltaEvent.delta.text, "Hello")
        } else {
            XCTFail("Expected contentBlockDelta event")
        }
    }

    func testStreamEvent_messageStop() throws {
        let event = StreamEvent.messageStop(MessageStopEvent())

        if case .messageStop = event {
            // Success
        } else {
            XCTFail("Expected messageStop event")
        }
    }

    // MARK: - Tool Tests

    func testAnthropicTool_encoding() throws {
        let schema = JSONSchema(
            type: "object", properties: ["query": ["type": .string("string")]], required: ["query"])

        let tool = AnthropicTool(
            name: "search", description: "Search for information", inputSchema: schema)

        let encoder = JSONEncoder()
        let data = try encoder.encode(tool)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["name"] as? String, "search")
        XCTAssertEqual(json?["description"] as? String, "Search for information")
    }

    // MARK: - ToolChoice Tests

    func testToolChoice_auto() throws {
        let choice = AnthropicToolChoice.auto

        let encoder = JSONEncoder()
        let data = try encoder.encode(choice)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["type"] as? String, "auto")
    }

    func testToolChoice_tool() throws {
        let choice = AnthropicToolChoice.tool("search")

        let encoder = JSONEncoder()
        let data = try encoder.encode(choice)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["type"] as? String, "tool")
        XCTAssertEqual(json?["name"] as? String, "search")
    }
}
