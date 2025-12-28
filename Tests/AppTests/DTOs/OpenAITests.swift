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
}
