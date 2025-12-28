import XCTest

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
}
