import DTOs
import Foundation
import Models

/// Service for translating between OpenAI/Anthropic message formats and Apple FoundationModels format
public struct MessageTranslationService: Sendable {
    public init() {}

    /// Extracts system instructions from OpenAI messages
    /// - Parameter messages: Array of OpenAI messages
    /// - Returns: Combined system instructions as a single string, or nil if no system messages
    public func extractSystemInstructions(
        from messages: [(role: String, content: String)]
    ) -> String? {
        let systemMessages = messages.filter { $0.role == "system" }.map { $0.content }

        guard !systemMessages.isEmpty else { return nil }

        return systemMessages.joined(separator: "\n\n")
    }

    /// Converts OpenAI conversation messages to a format suitable for FoundationModels
    /// - Parameter messages: Array of OpenAI messages
    /// - Returns: Formatted conversation string for the model
    /// - Throws: LLMError.invalidMessageFormat if conversation format is invalid
    public func formatConversationHistory(
        from messages: [(role: String, content: String)]
    ) throws -> String {
        // Filter out system messages - they're handled separately
        let conversationMessages = messages.filter { $0.role != "system" }

        guard !conversationMessages.isEmpty else {
            throw LLMError.invalidMessageFormat(
                "Conversation must contain at least one user message")
        }

        // Validate alternating user/assistant pattern (if there's history)
        if conversationMessages.count > 1 {
            for (index, message) in conversationMessages.enumerated() {
                let expectedRole = index % 2 == 0 ? "user" : "assistant"
                guard message.role == expectedRole || message.role == "user" else {
                    throw LLMError.invalidMessageFormat(
                        "Messages must alternate between user and assistant")
                }
            }
        }

        // Last message should always be from user
        guard conversationMessages.last?.role == "user" else {
            throw LLMError.invalidMessageFormat("Last message must be from user")
        }

        // Format conversation history as a string
        // For now, we'll return just the last user message
        // TODO: In Phase 2, implement full conversation history formatting
        return conversationMessages.last!.content
    }

    /// Extracts the latest user prompt from OpenAI messages
    /// - Parameter messages: Array of OpenAI messages
    /// - Returns: The content of the last user message
    /// - Throws: LLMError.invalidMessageFormat if no user message found
    public func extractUserPrompt(from messages: [(role: String, content: String)]) throws -> String
    {
        guard let lastUserMessage = messages.last(where: { $0.role == "user" }) else {
            throw LLMError.invalidMessageFormat("No user message found in conversation")
        }

        return lastUserMessage.content
    }

    // MARK: - Anthropic Message Translation

    /// Extracts text content from Anthropic Message.Content
    /// - Parameter content: Anthropic message content (string or blocks)
    /// - Returns: Extracted text content as a string
    public func extractTextContent(from content: Message.Content) -> String {
        switch content {
        case .text(let text): return text
        case .blocks(let blocks):
            // Combine text from all text blocks, ignore tool use/result blocks
            return blocks.compactMap { block -> String? in
                if case .text(let textBlock) = block { return textBlock.text }
                return nil
            }.joined(separator: "\n\n")
        }
    }

    /// Converts Anthropic messages to simple tuples for internal processing
    /// - Parameter messages: Array of Anthropic messages
    /// - Returns: Array of (role, content) tuples with text extracted
    public func convertAnthropicMessages(_ messages: [Message]) -> [(role: String, content: String)]
    {
        return messages.map { message in
            (role: message.role, content: extractTextContent(from: message.content))
        }
    }

    /// Extracts system instructions from Anthropic request
    /// - Parameters:
    ///   - systemParameter: Optional system parameter from request
    ///   - messages: Array of Anthropic messages (should not contain system role)
    /// - Returns: System instructions string, or nil if not provided
    public func extractAnthropicSystemInstructions(
        systemParameter: String?, messages: [Message]
    ) -> String? {
        // Anthropic API uses a separate system parameter
        // System messages should not be in the messages array
        return systemParameter
    }

    /// Formats Anthropic conversation history for FoundationModels
    /// - Parameter messages: Array of Anthropic messages
    /// - Returns: Formatted conversation string for the model
    /// - Throws: LLMError.invalidMessageFormat if conversation format is invalid
    public func formatAnthropicConversationHistory(from messages: [Message]) throws -> String {
        // Convert to simple tuples and reuse existing OpenAI logic
        let simplifiedMessages = convertAnthropicMessages(messages)
        return try formatConversationHistory(from: simplifiedMessages)
    }

    /// Extracts the latest user prompt from Anthropic messages
    /// - Parameter messages: Array of Anthropic messages
    /// - Returns: The content of the last user message
    /// - Throws: LLMError.invalidMessageFormat if no user message found
    public func extractAnthropicUserPrompt(from messages: [Message]) throws -> String {
        guard let lastUserMessage = messages.last(where: { $0.role == "user" }) else {
            throw LLMError.invalidMessageFormat("No user message found in conversation")
        }

        return extractTextContent(from: lastUserMessage.content)
    }
}
