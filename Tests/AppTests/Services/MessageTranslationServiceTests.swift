import XCTest

@testable import DTOs
@testable import Models
@testable import Services

final class MessageTranslationServiceTests: XCTestCase {
    var service: MessageTranslationService!

    override func setUp() {
        super.setUp()
        service = MessageTranslationService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - System Instructions Extraction Tests

    func testExtractSystemInstructions_singleSystemMessage() {
        let messages: [(role: String, content: String)] = [
            (role: "system", content: "You are a helpful assistant."),
            (role: "user", content: "Hello"),
        ]

        let result = service.extractSystemInstructions(from: messages)

        XCTAssertEqual(result, "You are a helpful assistant.")
    }

    func testExtractSystemInstructions_multipleSystemMessages() {
        let messages: [(role: String, content: String)] = [
            (role: "system", content: "You are a helpful assistant."),
            (role: "system", content: "Be concise and clear."), (role: "user", content: "Hello"),
        ]

        let result = service.extractSystemInstructions(from: messages)

        XCTAssertEqual(result, "You are a helpful assistant.\n\nBe concise and clear.")
    }

    func testExtractSystemInstructions_noSystemMessages() {
        let messages: [(role: String, content: String)] = [
            (role: "user", content: "Hello"), (role: "assistant", content: "Hi there!"),
        ]

        let result = service.extractSystemInstructions(from: messages)

        XCTAssertNil(result)
    }

    func testExtractSystemInstructions_emptyMessages() {
        let messages: [(role: String, content: String)] = []

        let result = service.extractSystemInstructions(from: messages)

        XCTAssertNil(result)
    }

    // MARK: - Conversation History Formatting Tests

    func testFormatConversationHistory_singleUserMessage() throws {
        let messages: [(role: String, content: String)] = [
            (role: "user", content: "What is the weather today?")
        ]

        let result = try service.formatConversationHistory(from: messages)

        XCTAssertEqual(result, "What is the weather today?")
    }

    func testFormatConversationHistory_withSystemAndUserMessages() throws {
        let messages: [(role: String, content: String)] = [
            (role: "system", content: "You are a weather assistant."),
            (role: "user", content: "What is the weather today?"),
        ]

        let result = try service.formatConversationHistory(from: messages)

        // System messages should be filtered out
        XCTAssertEqual(result, "What is the weather today?")
    }

    func testFormatConversationHistory_userAssistantConversation() throws {
        let messages: [(role: String, content: String)] = [
            (role: "user", content: "Hello"), (role: "assistant", content: "Hi there!"),
            (role: "user", content: "How are you?"),
        ]

        let result = try service.formatConversationHistory(from: messages)

        // Currently returns just the last user message
        XCTAssertEqual(result, "How are you?")
    }

    func testFormatConversationHistory_throwsOnEmptyConversation() {
        let messages: [(role: String, content: String)] = []

        XCTAssertThrowsError(try service.formatConversationHistory(from: messages)) { error in
            guard case LLMError.invalidMessageFormat(let message) = error else {
                return XCTFail("Expected LLMError.invalidMessageFormat")
            }
            XCTAssertTrue(message.contains("at least one user message"))
        }
    }

    func testFormatConversationHistory_throwsOnLastMessageNotFromUser() {
        let messages: [(role: String, content: String)] = [
            (role: "user", content: "Hello"), (role: "assistant", content: "Hi there!"),
        ]

        XCTAssertThrowsError(try service.formatConversationHistory(from: messages)) { error in
            guard case LLMError.invalidMessageFormat(let message) = error else {
                return XCTFail("Expected LLMError.invalidMessageFormat")
            }
            XCTAssertTrue(message.contains("Last message must be from user"))
        }
    }

    func testFormatConversationHistory_throwsOnOnlySystemMessages() {
        let messages: [(role: String, content: String)] = [
            (role: "system", content: "You are a helpful assistant.")
        ]

        XCTAssertThrowsError(try service.formatConversationHistory(from: messages)) { error in
            guard case LLMError.invalidMessageFormat(let message) = error else {
                return XCTFail("Expected LLMError.invalidMessageFormat")
            }
            XCTAssertTrue(message.contains("at least one user message"))
        }
    }

    // MARK: - User Prompt Extraction Tests

    func testExtractUserPrompt_singleUserMessage() throws {
        let messages: [(role: String, content: String)] = [
            (role: "user", content: "Tell me a joke")
        ]

        let result = try service.extractUserPrompt(from: messages)

        XCTAssertEqual(result, "Tell me a joke")
    }

    func testExtractUserPrompt_withSystemMessage() throws {
        let messages: [(role: String, content: String)] = [
            (role: "system", content: "You are a comedian."),
            (role: "user", content: "Tell me a joke"),
        ]

        let result = try service.extractUserPrompt(from: messages)

        XCTAssertEqual(result, "Tell me a joke")
    }

    func testExtractUserPrompt_multipleUserMessages() throws {
        let messages: [(role: String, content: String)] = [
            (role: "user", content: "Hello"), (role: "assistant", content: "Hi!"),
            (role: "user", content: "Tell me a joke"),
        ]

        let result = try service.extractUserPrompt(from: messages)

        // Should return the last user message
        XCTAssertEqual(result, "Tell me a joke")
    }

    func testExtractUserPrompt_throwsOnNoUserMessage() {
        let messages: [(role: String, content: String)] = [
            (role: "system", content: "You are a helpful assistant."),
            (role: "assistant", content: "Hello!"),
        ]

        XCTAssertThrowsError(try service.extractUserPrompt(from: messages)) { error in
            guard case LLMError.invalidMessageFormat(let message) = error else {
                return XCTFail("Expected LLMError.invalidMessageFormat")
            }
            XCTAssertTrue(message.contains("No user message found"))
        }
    }

    func testExtractUserPrompt_throwsOnEmptyMessages() {
        let messages: [(role: String, content: String)] = []

        XCTAssertThrowsError(try service.extractUserPrompt(from: messages)) { error in
            guard case LLMError.invalidMessageFormat = error else {
                return XCTFail("Expected LLMError.invalidMessageFormat")
            }
        }
    }

    // MARK: - Anthropic Message Translation Tests

    func testExtractTextContent_simpleText() {
        let content = Message.Content.text("Hello, world!")

        let result = service.extractTextContent(from: content)

        XCTAssertEqual(result, "Hello, world!")
    }

    func testExtractTextContent_textBlocks() {
        let blocks: [ContentBlock] = [
            .text(TextBlock(text: "First paragraph")), .text(TextBlock(text: "Second paragraph")),
        ]
        let content = Message.Content.blocks(blocks)

        let result = service.extractTextContent(from: content)

        XCTAssertEqual(result, "First paragraph\n\nSecond paragraph")
    }

    func testExtractTextContent_mixedBlocks() {
        let blocks: [ContentBlock] = [
            .text(TextBlock(text: "User question")),
            .toolResult(ToolResultBlock(toolUseId: "tool_123", content: "Tool result")),
            .text(TextBlock(text: "Follow up")),
        ]
        let content = Message.Content.blocks(blocks)

        let result = service.extractTextContent(from: content)

        // Should extract only text blocks
        XCTAssertEqual(result, "User question\n\nFollow up")
    }

    func testExtractTextContent_emptyBlocks() {
        let blocks: [ContentBlock] = []
        let content = Message.Content.blocks(blocks)

        let result = service.extractTextContent(from: content)

        XCTAssertEqual(result, "")
    }

    func testConvertAnthropicMessages_simpleText() {
        let messages = [
            Message(role: "user", text: "Hello"), Message(role: "assistant", text: "Hi there!"),
        ]

        let result = service.convertAnthropicMessages(messages)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].role, "user")
        XCTAssertEqual(result[0].content, "Hello")
        XCTAssertEqual(result[1].role, "assistant")
        XCTAssertEqual(result[1].content, "Hi there!")
    }

    func testConvertAnthropicMessages_withBlocks() {
        let messages = [
            Message(role: "user", text: "What's the weather?"),
            Message(
                role: "assistant",
                content: .blocks([
                    .text(TextBlock(text: "Let me check")),
                    .toolUse(
                        ToolUseBlock(
                            id: "tool_123", name: "get_weather", input: ["location": .string("NYC")]
                        )),
                ])),
        ]

        let result = service.convertAnthropicMessages(messages)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].content, "What's the weather?")
        XCTAssertEqual(result[1].content, "Let me check")  // Only text extracted
    }

    func testExtractAnthropicSystemInstructions_withSystemParameter() {
        let system = "You are a helpful assistant."
        let messages = [Message(role: "user", text: "Hello")]

        let result = service.extractAnthropicSystemInstructions(
            systemParameter: system, messages: messages)

        XCTAssertEqual(result, "You are a helpful assistant.")
    }

    func testExtractAnthropicSystemInstructions_noSystemParameter() {
        let messages = [Message(role: "user", text: "Hello")]

        let result = service.extractAnthropicSystemInstructions(
            systemParameter: nil, messages: messages)

        XCTAssertNil(result)
    }

    func testFormatAnthropicConversationHistory_singleMessage() throws {
        let messages = [Message(role: "user", text: "What is AI?")]

        let result = try service.formatAnthropicConversationHistory(from: messages)

        XCTAssertEqual(result, "What is AI?")
    }

    func testFormatAnthropicConversationHistory_conversation() throws {
        let messages = [
            Message(role: "user", text: "Hello"), Message(role: "assistant", text: "Hi there!"),
            Message(role: "user", text: "How are you?"),
        ]

        let result = try service.formatAnthropicConversationHistory(from: messages)

        // Currently returns just the last user message
        XCTAssertEqual(result, "How are you?")
    }

    func testFormatAnthropicConversationHistory_withBlocks() throws {
        let messages = [
            Message(
                role: "user",
                content: .blocks([
                    .text(TextBlock(text: "Question 1")), .text(TextBlock(text: "Question 2")),
                ]))
        ]

        let result = try service.formatAnthropicConversationHistory(from: messages)

        XCTAssertEqual(result, "Question 1\n\nQuestion 2")
    }

    func testFormatAnthropicConversationHistory_throwsOnLastMessageNotUser() {
        let messages = [
            Message(role: "user", text: "Hello"), Message(role: "assistant", text: "Hi!"),
        ]

        XCTAssertThrowsError(try service.formatAnthropicConversationHistory(from: messages)) {
            error in
            guard case LLMError.invalidMessageFormat(let message) = error else {
                return XCTFail("Expected LLMError.invalidMessageFormat")
            }
            XCTAssertTrue(message.contains("Last message must be from user"))
        }
    }

    func testExtractAnthropicUserPrompt_simpleText() throws {
        let messages = [Message(role: "user", text: "Tell me a story")]

        let result = try service.extractAnthropicUserPrompt(from: messages)

        XCTAssertEqual(result, "Tell me a story")
    }

    func testExtractAnthropicUserPrompt_withBlocks() throws {
        let messages = [
            Message(
                role: "user",
                content: .blocks([
                    .text(TextBlock(text: "Part 1")), .text(TextBlock(text: "Part 2")),
                ]))
        ]

        let result = try service.extractAnthropicUserPrompt(from: messages)

        XCTAssertEqual(result, "Part 1\n\nPart 2")
    }

    func testExtractAnthropicUserPrompt_multipleMessages() throws {
        let messages = [
            Message(role: "user", text: "First question"),
            Message(role: "assistant", text: "First answer"),
            Message(role: "user", text: "Second question"),
        ]

        let result = try service.extractAnthropicUserPrompt(from: messages)

        // Should return the last user message
        XCTAssertEqual(result, "Second question")
    }

    func testExtractAnthropicUserPrompt_throwsOnNoUserMessage() {
        let messages = [Message(role: "assistant", text: "Hello!")]

        XCTAssertThrowsError(try service.extractAnthropicUserPrompt(from: messages)) { error in
            guard case LLMError.invalidMessageFormat(let message) = error else {
                return XCTFail("Expected LLMError.invalidMessageFormat")
            }
            XCTAssertTrue(message.contains("No user message found"))
        }
    }

    func testExtractAnthropicUserPrompt_throwsOnEmptyMessages() {
        let messages: [Message] = []

        XCTAssertThrowsError(try service.extractAnthropicUserPrompt(from: messages)) { error in
            guard case LLMError.invalidMessageFormat = error else {
                return XCTFail("Expected LLMError.invalidMessageFormat")
            }
        }
    }
}
