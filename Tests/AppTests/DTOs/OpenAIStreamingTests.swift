import XCTest

@testable import DTOs

final class OpenAIStreamingTests: XCTestCase {
    func testDeltaEncodingWithRole() throws {
        let delta = Delta(role: "assistant", content: nil)

        let encoder = JSONEncoder()
        let data = try encoder.encode(delta)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"role\":\"assistant\""))
        XCTAssertFalse(json.contains("\"content\""))
    }

    func testDeltaEncodingWithContent() throws {
        let delta = Delta(role: nil, content: "Hello")

        let encoder = JSONEncoder()
        let data = try encoder.encode(delta)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertFalse(json.contains("\"role\""))
        XCTAssertTrue(json.contains("\"content\":\"Hello\""))
    }

    func testDeltaEncodingWithBoth() throws {
        let delta = Delta(role: "assistant", content: "Hello")

        let encoder = JSONEncoder()
        let data = try encoder.encode(delta)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"role\":\"assistant\""))
        XCTAssertTrue(json.contains("\"content\":\"Hello\""))
    }

    func testChunkChoiceEncoding() throws {
        let delta = Delta(role: "assistant", content: "Hello")
        let choice = ChatCompletionChunk.ChunkChoice(index: 0, delta: delta, finishReason: nil)

        let encoder = JSONEncoder()
        let data = try encoder.encode(choice)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"index\":0"))
        XCTAssertTrue(json.contains("\"delta\""))
        XCTAssertTrue(json.contains("\"role\":\"assistant\""))
        XCTAssertTrue(json.contains("\"content\":\"Hello\""))
        // finishReason should be omitted when nil
        XCTAssertFalse(json.contains("\"finish_reason\""))
    }

    func testChunkChoiceEncodingWithFinishReason() throws {
        let delta = Delta(role: nil, content: nil)
        let choice = ChatCompletionChunk.ChunkChoice(index: 0, delta: delta, finishReason: "stop")

        let encoder = JSONEncoder()
        let data = try encoder.encode(choice)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"index\":0"))
        XCTAssertTrue(json.contains("\"finish_reason\":\"stop\""))
    }

    func testChatCompletionChunkEncoding() throws {
        let delta = Delta(role: "assistant", content: "Hello")
        let choice = ChatCompletionChunk.ChunkChoice(index: 0, delta: delta, finishReason: nil)
        let chunk = ChatCompletionChunk(
            id: "chatcmpl-123", object: "chat.completion.chunk", created: 1_677_652_288,
            model: "gpt-4", choices: [choice])

        let encoder = JSONEncoder()
        let data = try encoder.encode(chunk)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"id\":\"chatcmpl-123\""))
        XCTAssertTrue(json.contains("\"object\":\"chat.completion.chunk\""))
        XCTAssertTrue(json.contains("\"created\":1677652288"))
        XCTAssertTrue(json.contains("\"model\":\"gpt-4\""))
        XCTAssertTrue(json.contains("\"choices\""))
        XCTAssertTrue(json.contains("\"delta\""))
    }

    func testChatCompletionChunkRoundTrip() throws {
        let delta = Delta(role: "assistant", content: "Test streaming response")
        let choice = ChatCompletionChunk.ChunkChoice(index: 0, delta: delta, finishReason: nil)
        let original = ChatCompletionChunk(
            id: "test-id", object: "chat.completion.chunk", created: 1_234_567_890, model: "gpt-4",
            choices: [choice])

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ChatCompletionChunk.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.object, original.object)
        XCTAssertEqual(decoded.created, original.created)
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.choices.count, 1)
        XCTAssertEqual(decoded.choices[0].index, 0)
        XCTAssertEqual(decoded.choices[0].delta.role, "assistant")
        XCTAssertEqual(decoded.choices[0].delta.content, "Test streaming response")
        XCTAssertNil(decoded.choices[0].finishReason)
    }

    func testStreamingSequence() throws {
        // First chunk: role only
        let firstDelta = Delta(role: "assistant", content: nil)
        let firstChoice = ChatCompletionChunk.ChunkChoice(
            index: 0, delta: firstDelta, finishReason: nil)
        let firstChunk = ChatCompletionChunk(
            id: "chatcmpl-123", object: "chat.completion.chunk", created: 1_677_652_288,
            model: "gpt-4", choices: [firstChoice])

        // Middle chunk: content only
        let middleDelta = Delta(role: nil, content: "Hello")
        let middleChoice = ChatCompletionChunk.ChunkChoice(
            index: 0, delta: middleDelta, finishReason: nil)
        let middleChunk = ChatCompletionChunk(
            id: "chatcmpl-123", object: "chat.completion.chunk", created: 1_677_652_288,
            model: "gpt-4", choices: [middleChoice])

        // Final chunk: empty delta with finish_reason
        let finalDelta = Delta(role: nil, content: nil)
        let finalChoice = ChatCompletionChunk.ChunkChoice(
            index: 0, delta: finalDelta, finishReason: "stop")
        let finalChunk = ChatCompletionChunk(
            id: "chatcmpl-123", object: "chat.completion.chunk", created: 1_677_652_288,
            model: "gpt-4", choices: [finalChoice])

        let encoder = JSONEncoder()

        // Verify first chunk
        let firstData = try encoder.encode(firstChunk)
        let firstJson = String(data: firstData, encoding: .utf8)!
        XCTAssertTrue(firstJson.contains("\"role\":\"assistant\""))
        XCTAssertFalse(firstJson.contains("\"content\""))
        XCTAssertFalse(firstJson.contains("\"finish_reason\""))

        // Verify middle chunk
        let middleData = try encoder.encode(middleChunk)
        let middleJson = String(data: middleData, encoding: .utf8)!
        XCTAssertFalse(middleJson.contains("\"role\""))
        XCTAssertTrue(middleJson.contains("\"content\":\"Hello\""))
        XCTAssertFalse(middleJson.contains("\"finish_reason\""))

        // Verify final chunk
        let finalData = try encoder.encode(finalChunk)
        let finalJson = String(data: finalData, encoding: .utf8)!
        XCTAssertFalse(finalJson.contains("\"role\""))
        XCTAssertFalse(finalJson.contains("\"content\""))
        XCTAssertTrue(finalJson.contains("\"finish_reason\":\"stop\""))
    }

    // MARK: - Tool Calling Streaming Tests

    func testDeltaEncodingWithToolCalls() throws {
        let functionCall = DeltaFunctionCall(name: "get_weather", arguments: nil)
        let toolCall = DeltaToolCall(
            index: 0, id: "call_123", type: "function", function: functionCall)
        let delta = Delta(role: nil, content: nil, toolCalls: [toolCall])

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(delta)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"tool_calls\""))
        XCTAssertTrue(json.contains("\"index\":0"))
        XCTAssertTrue(json.contains("\"id\":\"call_123\""))
        XCTAssertTrue(json.contains("\"type\":\"function\""))
        XCTAssertTrue(json.contains("\"name\":\"get_weather\""))
    }

    func testDeltaFunctionCallEncoding() throws {
        let functionCall = DeltaFunctionCall(name: "get_weather", arguments: "{\"location\":")

        let encoder = JSONEncoder()
        let data = try encoder.encode(functionCall)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"name\":\"get_weather\""))
        XCTAssertTrue(json.contains("\"arguments\""))
    }

    func testDeltaFunctionCallWithOnlyArguments() throws {
        let functionCall = DeltaFunctionCall(name: nil, arguments: "\"Boston\"}")

        let encoder = JSONEncoder()
        let data = try encoder.encode(functionCall)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertFalse(json.contains("\"name\""))
        XCTAssertTrue(json.contains("\"arguments\""))
    }

    func testDeltaToolCallRoundTrip() throws {
        let functionCall = DeltaFunctionCall(name: "calculate", arguments: "{\"x\":5,\"y\":3}")
        let original = DeltaToolCall(
            index: 0, id: "call_abc123", type: "function", function: functionCall)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DeltaToolCall.self, from: data)

        XCTAssertEqual(decoded.index, 0)
        XCTAssertEqual(decoded.id, "call_abc123")
        XCTAssertEqual(decoded.type, "function")
        XCTAssertEqual(decoded.function?.name, "calculate")
        XCTAssertEqual(decoded.function?.arguments, "{\"x\":5,\"y\":3}")
    }

    func testStreamingToolCallSequence() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        // First chunk: role + tool call start (id, type, function name)
        let firstFunction = DeltaFunctionCall(name: "get_weather", arguments: nil)
        let firstToolCall = DeltaToolCall(
            index: 0, id: "call_123", type: "function", function: firstFunction)
        let firstDelta = Delta(role: "assistant", content: nil, toolCalls: [firstToolCall])
        let firstChoice = ChatCompletionChunk.ChunkChoice(
            index: 0, delta: firstDelta, finishReason: nil)
        let firstChunk = ChatCompletionChunk(
            id: "chatcmpl-123", object: "chat.completion.chunk", created: 1_677_652_288,
            model: "gpt-4", choices: [firstChoice])

        let firstData = try encoder.encode(firstChunk)
        let firstJson = String(data: firstData, encoding: .utf8)!
        XCTAssertTrue(firstJson.contains("\"role\":\"assistant\""))
        XCTAssertTrue(firstJson.contains("\"tool_calls\""))
        XCTAssertTrue(firstJson.contains("\"id\":\"call_123\""))
        XCTAssertTrue(firstJson.contains("\"name\":\"get_weather\""))

        // Middle chunk: incremental arguments
        let middleFunction = DeltaFunctionCall(name: nil, arguments: "{\"location\":")
        let middleToolCall = DeltaToolCall(index: 0, id: nil, type: nil, function: middleFunction)
        let middleDelta = Delta(role: nil, content: nil, toolCalls: [middleToolCall])
        let middleChoice = ChatCompletionChunk.ChunkChoice(
            index: 0, delta: middleDelta, finishReason: nil)
        let middleChunk = ChatCompletionChunk(
            id: "chatcmpl-123", object: "chat.completion.chunk", created: 1_677_652_288,
            model: "gpt-4", choices: [middleChoice])

        let middleData = try encoder.encode(middleChunk)
        let middleJson = String(data: middleData, encoding: .utf8)!
        XCTAssertTrue(middleJson.contains("\"arguments\""))

        // Final chunk: finish with tool_calls reason
        let finalDelta = Delta(role: nil, content: nil, toolCalls: nil)
        let finalChoice = ChatCompletionChunk.ChunkChoice(
            index: 0, delta: finalDelta, finishReason: "tool_calls")
        let finalChunk = ChatCompletionChunk(
            id: "chatcmpl-123", object: "chat.completion.chunk", created: 1_677_652_288,
            model: "gpt-4", choices: [finalChoice])

        let finalData = try encoder.encode(finalChunk)
        let finalJson = String(data: finalData, encoding: .utf8)!
        XCTAssertTrue(finalJson.contains("\"finish_reason\":\"tool_calls\""))
    }
}
