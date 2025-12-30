import XCTest

@testable import DTOs

final class OpenAITests: XCTestCase {
    func testChatCompletionRequestDecoding() throws {
        let json = """
            {
                "model": "gpt-4",
                "messages": [
                    {"role": "system", "content": "You are a helpful assistant."},
                    {"role": "user", "content": "Hello!"}
                ],
                "stream": false,
                "max_tokens": 100,
                "temperature": 0.7
            }
            """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let request = try decoder.decode(ChatCompletionRequest.self, from: data)

        XCTAssertEqual(request.model, "gpt-4")
        XCTAssertEqual(request.messages.count, 2)
        XCTAssertEqual(request.messages[0].role, "system")
        XCTAssertEqual(request.messages[0].content, "You are a helpful assistant.")
        XCTAssertEqual(request.messages[1].role, "user")
        XCTAssertEqual(request.messages[1].content, "Hello!")
        XCTAssertEqual(request.stream, false)
        XCTAssertEqual(request.maxTokens, 100)
        XCTAssertEqual(request.temperature, 0.7)
    }

    func testChatCompletionRequestDecodingMinimal() throws {
        let json = """
            {
                "model": "gpt-4",
                "messages": [
                    {"role": "user", "content": "Hello!"}
                ]
            }
            """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let request = try decoder.decode(ChatCompletionRequest.self, from: data)

        XCTAssertEqual(request.model, "gpt-4")
        XCTAssertEqual(request.messages.count, 1)
        XCTAssertNil(request.stream)
        XCTAssertNil(request.maxTokens)
        XCTAssertNil(request.temperature)
    }

    func testChatCompletionResponseEncoding() throws {
        let message = ChatMessage(role: "assistant", content: "Hello! How can I help you?")
        let choice = ChatCompletionResponse.Choice(index: 0, message: message, finishReason: "stop")
        let response = ChatCompletionResponse(
            id: "chatcmpl-123", object: "chat.completion", created: 1_677_652_288, model: "gpt-4",
            choices: [choice])

        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"id\":\"chatcmpl-123\""))
        XCTAssertTrue(json.contains("\"object\":\"chat.completion\""))
        XCTAssertTrue(json.contains("\"created\":1677652288"))
        XCTAssertTrue(json.contains("\"model\":\"gpt-4\""))
        XCTAssertTrue(json.contains("\"role\":\"assistant\""))
        XCTAssertTrue(json.contains("\"content\":\"Hello! How can I help you?\""))
        XCTAssertTrue(json.contains("\"finish_reason\":\"stop\""))
    }

    func testChatCompletionResponseRoundTrip() throws {
        let message = ChatMessage(role: "assistant", content: "Test response")
        let choice = ChatCompletionResponse.Choice(index: 0, message: message, finishReason: "stop")
        let original = ChatCompletionResponse(
            id: "test-id", object: "chat.completion", created: 1_234_567_890, model: "gpt-4",
            choices: [choice])

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ChatCompletionResponse.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.object, original.object)
        XCTAssertEqual(decoded.created, original.created)
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.choices.count, 1)
        XCTAssertEqual(decoded.choices[0].index, 0)
        XCTAssertEqual(decoded.choices[0].message.role, "assistant")
        XCTAssertEqual(decoded.choices[0].message.content, "Test response")
        XCTAssertEqual(decoded.choices[0].finishReason, "stop")
    }

    // MARK: - Tool Calling Tests

    func testToolDefinitionDecoding() throws {
        let json = """
            {
                "type": "function",
                "function": {
                    "name": "get_weather",
                    "description": "Get the current weather in a location",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "location": {
                                "type": "string",
                                "description": "The city and state, e.g. San Francisco, CA"
                            },
                            "unit": {
                                "type": "string",
                                "enum": ["celsius", "fahrenheit"]
                            }
                        },
                        "required": ["location"]
                    }
                }
            }
            """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let tool = try decoder.decode(Tool.self, from: data)

        XCTAssertEqual(tool.type, "function")
        XCTAssertEqual(tool.function.name, "get_weather")
        XCTAssertEqual(tool.function.description, "Get the current weather in a location")
        XCTAssertNotNil(tool.function.parameters)
    }

    func testChatCompletionRequestWithTools() throws {
        let json = """
            {
                "model": "gpt-4",
                "messages": [
                    {"role": "user", "content": "What's the weather in Boston?"}
                ],
                "tools": [
                    {
                        "type": "function",
                        "function": {
                            "name": "get_weather",
                            "description": "Get weather",
                            "parameters": {
                                "type": "object",
                                "properties": {
                                    "location": {"type": "string"}
                                },
                                "required": ["location"]
                            }
                        }
                    }
                ],
                "tool_choice": "auto"
            }
            """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let request = try decoder.decode(ChatCompletionRequest.self, from: data)

        XCTAssertEqual(request.model, "gpt-4")
        XCTAssertEqual(request.messages.count, 1)
        XCTAssertNotNil(request.tools)
        XCTAssertEqual(request.tools?.count, 1)
        XCTAssertEqual(request.tools?[0].function.name, "get_weather")
        XCTAssertEqual(request.toolChoice, .auto)
    }

    func testToolChoiceAuto() throws {
        let json = "\"auto\""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let toolChoice = try decoder.decode(ToolChoice.self, from: data)

        XCTAssertEqual(toolChoice, .auto)
    }

    func testToolChoiceNone() throws {
        let json = "\"none\""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let toolChoice = try decoder.decode(ToolChoice.self, from: data)

        XCTAssertEqual(toolChoice, .none)
    }

    func testToolChoiceRequired() throws {
        let json = "\"required\""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let toolChoice = try decoder.decode(ToolChoice.self, from: data)

        XCTAssertEqual(toolChoice, .required)
    }

    func testToolCallResponse() throws {
        let functionCall = FunctionCall(
            name: "get_weather", arguments: "{\"location\":\"Boston, MA\"}")
        let toolCall = ResponseToolCall(id: "call_123", function: functionCall)
        let message = ChatMessage(role: "assistant", content: nil, toolCalls: [toolCall])
        let choice = ChatCompletionResponse.Choice(
            index: 0, message: message, finishReason: "tool_calls")
        let response = ChatCompletionResponse(
            id: "chatcmpl-123", object: "chat.completion", created: 1_677_652_288, model: "gpt-4",
            choices: [choice])

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"tool_calls\""))
        XCTAssertTrue(json.contains("\"call_123\""))
        XCTAssertTrue(json.contains("\"get_weather\""))
        XCTAssertTrue(json.contains("\"finish_reason\":\"tool_calls\""))
    }

    func testToolCallResponseRoundTrip() throws {
        let functionCall = FunctionCall(
            name: "get_weather", arguments: "{\"location\":\"Boston, MA\",\"unit\":\"fahrenheit\"}")
        let toolCall = ResponseToolCall(id: "call_456", function: functionCall)
        let message = ChatMessage(role: "assistant", content: nil, toolCalls: [toolCall])
        let choice = ChatCompletionResponse.Choice(
            index: 0, message: message, finishReason: "tool_calls")
        let original = ChatCompletionResponse(
            id: "chatcmpl-789", object: "chat.completion", created: 1_677_652_288, model: "gpt-4",
            choices: [choice])

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ChatCompletionResponse.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.choices.count, 1)
        XCTAssertEqual(decoded.choices[0].message.role, "assistant")
        XCTAssertNil(decoded.choices[0].message.content)
        XCTAssertEqual(decoded.choices[0].message.toolCalls?.count, 1)
        XCTAssertEqual(decoded.choices[0].message.toolCalls?[0].id, "call_456")
        XCTAssertEqual(decoded.choices[0].message.toolCalls?[0].function.name, "get_weather")
        XCTAssertEqual(decoded.choices[0].finishReason, "tool_calls")
    }

    func testToolMessageWithResult() throws {
        let json = """
            {
                "role": "tool",
                "content": "The weather in Boston is 72°F and sunny.",
                "tool_call_id": "call_123",
                "name": "get_weather"
            }
            """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let message = try decoder.decode(ChatMessage.self, from: data)

        XCTAssertEqual(message.role, "tool")
        XCTAssertEqual(message.content, "The weather in Boston is 72°F and sunny.")
        XCTAssertEqual(message.toolCallId, "call_123")
        XCTAssertEqual(message.name, "get_weather")
    }
}
