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

    // MARK: - Anthropic Tool Calling Support

    /// Extracts and categorizes tool blocks from Anthropic message content
    /// - Parameter content: Anthropic message content (string or blocks)
    /// - Returns: Tuple of text strings, tool use blocks, and tool result blocks
    public func extractToolBlocks(
        from content: Message.Content
    ) -> (text: [String], toolUse: [ToolUseBlock], toolResults: [ToolResultBlock]) {
        switch content {
        case .text(let text):
            // Simple text content - no tool blocks
            return (text: [text], toolUse: [], toolResults: [])

        case .blocks(let blocks):
            var textBlocks: [String] = []
            var toolUseBlocks: [ToolUseBlock] = []
            var toolResultBlocks: [ToolResultBlock] = []

            for block in blocks {
                switch block {
                case .text(let textBlock): textBlocks.append(textBlock.text)
                case .toolUse(let toolUseBlock): toolUseBlocks.append(toolUseBlock)
                case .toolResult(let toolResultBlock): toolResultBlocks.append(toolResultBlock)
                }
            }

            return (text: textBlocks, toolUse: toolUseBlocks, toolResults: toolResultBlocks)
        }
    }

    /// Converts Anthropic tool definition to internal ToolDefinition format
    /// - Parameter tool: Anthropic tool definition
    /// - Returns: Internal ToolDefinition for backend services
    public func convertAnthropicToolToDefinition(_ tool: AnthropicTool) -> ToolDefinition {
        return ToolDefinition(
            name: tool.name, description: tool.description ?? "", parameters: tool.inputSchema)
    }

    /// Checks if any message contains tool result blocks
    /// - Parameter messages: Array of Anthropic messages
    /// - Returns: True if tool results are present in any message
    public func hasToolResultsInMessages(_ messages: [Message]) -> Bool {
        for message in messages {
            let (_, _, toolResults) = extractToolBlocks(from: message.content)
            if !toolResults.isEmpty { return true }
        }
        return false
    }

    /// Builds conversation history string including tool calls and results
    /// - Parameter messages: Array of Anthropic messages with tool interactions
    /// - Returns: Formatted conversation string for the model
    public func buildToolResultHistory(from messages: [Message]) -> String {
        var conversationParts: [String] = []

        for message in messages {
            let (textBlocks, toolUseBlocks, toolResultBlocks) = extractToolBlocks(
                from: message.content)

            switch message.role {
            case "user":
                // User message - may contain tool results
                if !toolResultBlocks.isEmpty {
                    for toolResult in toolResultBlocks {
                        conversationParts.append(
                            "Tool '\(toolResult.toolUseId)' returned: \(toolResult.content)")
                    }
                } else if !textBlocks.isEmpty {
                    conversationParts.append("User: \(textBlocks.joined(separator: " "))")
                }

            case "assistant":
                // Assistant message - may contain tool calls
                if !toolUseBlocks.isEmpty {
                    let toolCallsDesc = toolUseBlocks.map { toolUse in
                        let inputDesc: String
                        do {
                            let inputData = try JSONEncoder().encode(toolUse.input)
                            inputDesc = String(data: inputData, encoding: .utf8) ?? "{}"
                        } catch { inputDesc = "{}" }
                        return "[\(toolUse.name)(\(inputDesc))]"
                    }.joined(separator: ", ")
                    conversationParts.append("Assistant called tools: \(toolCallsDesc)")
                } else if !textBlocks.isEmpty {
                    conversationParts.append("Assistant: \(textBlocks.joined(separator: " "))")
                }

            default:
                // Unknown role - skip
                break
            }
        }

        return conversationParts.joined(separator: "\n")
    }
}
