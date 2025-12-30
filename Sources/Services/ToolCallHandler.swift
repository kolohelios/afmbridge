import Foundation
import Models

/// Orchestrates multi-turn tool calling with the language model
/// Handles the loop of: LLM → tool calls → tool execution → LLM → final response
@available(macOS 26.0, *) public actor ToolCallHandler {
    private let llmProvider: LLMProvider
    private let maxIterations: Int

    /// Initialize the handler
    /// - Parameters:
    ///   - llmProvider: The LLM provider to use for generation
    ///   - maxIterations: Maximum number of tool calling iterations (default: 10)
    public init(llmProvider: LLMProvider, maxIterations: Int = 10) {
        self.llmProvider = llmProvider
        self.maxIterations = maxIterations
    }

    /// Execute a tool calling request with multi-turn orchestration
    /// - Parameters:
    ///   - userPrompt: The user's input message
    ///   - tools: Available tool definitions
    ///   - toolExecutors: Registry of tool executors
    ///   - systemInstructions: Optional system-level instructions
    /// - Returns: The final response content after all tool calls are resolved
    /// - Throws: LLMError if generation fails or ToolCallError if orchestration fails
    public func execute(
        userPrompt: String, tools: [ToolDefinition], toolExecutors: ToolRegistry,
        systemInstructions: String?
    ) async throws -> String {
        var currentPrompt = userPrompt
        var conversationHistory: [(role: String, content: String)] = []
        var iterations = 0

        // Add initial user message to history
        conversationHistory.append((role: "user", content: userPrompt))

        while iterations < maxIterations {
            iterations += 1

            // Call LLM with tools
            let (content, toolCalls) = try await llmProvider.respondWithTools(
                to: currentPrompt, tools: tools, toolExecutors: toolExecutors,
                systemInstructions: systemInstructions)

            // If no tool calls, we have the final response
            guard let toolCalls = toolCalls, !toolCalls.isEmpty else {
                if let finalContent = content {
                    return finalContent
                } else {
                    throw ToolCallError.noResponseContent
                }
            }

            // Add assistant's tool calls to history
            if let content = content {
                conversationHistory.append((role: "assistant", content: content))
            }

            // Execute all tool calls in parallel
            let toolResults = try await executeToolCallsInParallel(
                toolCalls: toolCalls, toolExecutors: toolExecutors)

            // Add tool results to conversation history
            for result in toolResults {
                conversationHistory.append((role: "tool", content: result.output))
            }

            // Build next prompt with conversation history
            currentPrompt = buildPromptFromHistory(conversationHistory)
        }

        throw ToolCallError.maxIterationsExceeded(maxIterations)
    }

    /// Execute multiple tool calls in parallel
    /// - Parameters:
    ///   - toolCalls: The tool calls to execute
    ///   - toolExecutors: Registry of tool executors
    /// - Returns: Array of tool results
    /// - Throws: ToolExecutionError if any tool execution fails
    private func executeToolCallsInParallel(
        toolCalls: [ToolCall], toolExecutors: ToolRegistry
    ) async throws -> [ToolResult] {
        try await withThrowingTaskGroup(of: ToolResult.self) { group in
            // Start all tool executions in parallel
            for toolCall in toolCalls {
                group.addTask {
                    let output = try await toolExecutors.execute(
                        tool: toolCall.name, arguments: toolCall.arguments)
                    return ToolResult(toolCallId: toolCall.id, output: output)
                }
            }

            // Collect all results
            var results: [ToolResult] = []
            for try await result in group { results.append(result) }
            return results
        }
    }

    /// Build a prompt from conversation history
    /// - Parameter history: The conversation history
    /// - Returns: A formatted prompt string
    private func buildPromptFromHistory(_ history: [(role: String, content: String)]) -> String {
        history.map { "\($0.role): \($0.content)" }.joined(separator: "\n")
    }
}

/// Errors that can occur during tool calling orchestration
public enum ToolCallError: Error, LocalizedError {
    case maxIterationsExceeded(Int)
    case noResponseContent

    public var errorDescription: String? {
        switch self {
        case .maxIterationsExceeded(let max):
            return "Tool calling exceeded maximum iterations (\(max))"
        case .noResponseContent: return "LLM returned no content and no tool calls"
        }
    }
}
