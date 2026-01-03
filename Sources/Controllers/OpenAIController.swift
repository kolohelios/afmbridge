import Configuration
import DTOs
import Foundation
import Models
import Services
import Vapor

/// Controller for OpenAI-compatible chat completions endpoint
public struct OpenAIController: RouteCollection, Sendable {
    private let llmProvider: LLMProvider
    private let messageTranslator: MessageTranslationService

    /// Initialize the controller with dependencies
    /// - Parameter llmProvider: The language model provider (e.g., FoundationModelService)
    public init(llmProvider: LLMProvider) {
        self.llmProvider = llmProvider
        self.messageTranslator = MessageTranslationService()
    }

    /// Register routes for this controller
    public func boot(routes: RoutesBuilder) throws {
        let openai = routes.grouped("v1")
        openai.post("chat", "completions", use: chatCompletions)
    }

    /// Handle chat completion requests
    /// - Parameter req: The Vapor request
    /// - Returns: ChatCompletionResponse for non-streaming, Response for streaming
    /// - Throws: Abort errors for invalid requests or LLM errors
    public func chatCompletions(req: Request) async throws -> Response {
        // Decode request
        let requestBody = try req.content.decode(ChatCompletionRequest.self)

        // Check if this is a tool result submission (continuation after tool execution)
        let hasToolMessages = requestBody.messages.contains { $0.role == "tool" }

        if hasToolMessages {
            // This is a continuation with tool results - handle multi-turn conversation
            return try await handleToolResultSubmission(req: req, requestBody: requestBody)
        }

        // Convert messages to translation service format
        // For now, unwrap content with empty string (Phase 3 will add full tool support)
        let messages = requestBody.messages.map { (role: $0.role, content: $0.content ?? "") }

        // Extract system instructions
        var systemInstructions = messageTranslator.extractSystemInstructions(from: messages)

        // Extract user prompt
        let userPrompt: String
        do { userPrompt = try messageTranslator.extractUserPrompt(from: messages) } catch let error
            as LLMError
        { throw mapLLMError(error) }

        // Optimize system instructions for autocomplete requests
        // Verbose instructions increase prompt size and slow down inference
        // The user prompt already provides sufficient context via "Code before/after cursor"
        if isAutocompleteRequest(messages: messages, stream: requestBody.stream) {
            systemInstructions = nil  // Remove system instructions entirely for autocomplete
        }

        // Handle streaming vs non-streaming
        if requestBody.stream == true {
            // Note: Streaming with tools is not yet supported by AFM
            // If tools are present, fall back to non-streaming response
            if let tools = requestBody.tools, !tools.isEmpty {
                return try await handleNonStreamingRequest(
                    req: req, requestBody: requestBody, userPrompt: userPrompt,
                    systemInstructions: systemInstructions)
            }

            return try await handleStreamingRequest(
                req: req, userPrompt: userPrompt, systemInstructions: systemInstructions)
        } else {
            return try await handleNonStreamingRequest(
                req: req, requestBody: requestBody, userPrompt: userPrompt,
                systemInstructions: systemInstructions)
        }
    }

    /// Handle non-streaming chat completion
    private func handleNonStreamingRequest(
        req: Request, requestBody: ChatCompletionRequest, userPrompt: String,
        systemInstructions: String?
    ) async throws -> Response {

        // Check if tools are present in the request
        if let tools = requestBody.tools, !tools.isEmpty {
            return try await handleToolCallingRequest(
                req: req, requestBody: requestBody, userPrompt: userPrompt,
                systemInstructions: systemInstructions)
        }

        // Convert messages for autocomplete detection
        let messages = requestBody.messages.map { (role: $0.role, content: $0.content ?? "") }
        let isAutocomplete = isAutocompleteRequest(messages: messages, stream: false)

        // Generate response
        // For autocomplete, use streaming internally for better performance (faster TTFT)
        // Collect all deltas and return the final result to maintain API compatibility
        let generatedContent: String
        do {
            if isAutocomplete {
                // Use internal streaming for autocomplete
                var accumulatedContent = ""
                let stream = try await llmProvider.streamRespond(
                    to: userPrompt, systemInstructions: systemInstructions)
                for try await delta in stream { accumulatedContent += delta }
                generatedContent = accumulatedContent
            } else {
                // Use standard non-streaming for other requests
                generatedContent = try await llmProvider.respond(
                    to: userPrompt, systemInstructions: systemInstructions)
            }
        } catch let error as LLMError {
            // Log error with context for debugging
            req.logger.error(
                "Non-streaming generation error",
                metadata: [
                    "error": .string("\(error)"), "prompt_length": .string("\(userPrompt.count)"),
                    "prompt_preview": .string(String(userPrompt.prefix(100))),
                    "has_system_instructions": .string("\(systemInstructions != nil)"),
                ])
            throw mapLLMError(error)
        }

        // Strip prefix for autocomplete requests
        // LLMs tend to repeat the "Code before cursor" prefix even when instructed not to
        // This makes completions unusable in Continue since it would duplicate existing code
        let finalContent: String
        if isAutocomplete, let userMessage = messages.first(where: { $0.role == "user" }),
            let prefix = extractPrefix(from: userMessage.content)
        {
            finalContent = stripPrefixIfNeeded(generatedContent, prefix: prefix)
        } else {
            finalContent = generatedContent
        }

        // Build response
        let responseBody = ChatCompletionResponse(
            id: "chatcmpl-\(UUID().uuidString)", object: "chat.completion",
            created: Int(Date().timeIntervalSince1970), model: ServerConfig.afmModelIdentifier,
            choices: [
                ChatCompletionResponse.Choice(
                    index: 0, message: ChatMessage(role: "assistant", content: finalContent),
                    finishReason: "stop")
            ])

        // Encode and return
        let response = Response(status: .ok)
        try response.content.encode(responseBody)
        return response
    }

    /// Handle tool calling request
    private func handleToolCallingRequest(
        req: Request, requestBody: ChatCompletionRequest, userPrompt: String,
        systemInstructions: String?
    ) async throws -> Response {
        // Convert OpenAI tools to our ToolDefinition format
        let toolDefinitions: [ToolDefinition] =
            requestBody.tools?.map { tool in
                ToolDefinition(
                    name: tool.function.name, description: tool.function.description ?? "",
                    parameters: tool.function.parameters ?? JSONSchema(type: "object"))
            } ?? []

        // Create tool registry (empty - client will execute tools)
        let toolRegistry = ToolRegistry()

        // Call LLM with tools (single turn - OpenAI pattern)
        let (content, toolCalls): (String?, [ToolCall]?)
        do {
            (content, toolCalls) = try await llmProvider.respondWithTools(
                to: userPrompt, tools: toolDefinitions, toolExecutors: toolRegistry,
                systemInstructions: systemInstructions)
        } catch let error as LLMError {
            // Log error with context for debugging
            req.logger.error(
                "Tool calling generation error",
                metadata: [
                    "error": .string("\(error)"), "prompt_length": .string("\(userPrompt.count)"),
                    "prompt_preview": .string(String(userPrompt.prefix(100))),
                    "tools_count": .string("\(toolDefinitions.count)"),
                ])
            throw mapLLMError(error)
        }

        // If model made tool calls, return them to client
        if let toolCalls = toolCalls, !toolCalls.isEmpty {
            let responseToolCalls = toolCalls.map { call in
                ResponseToolCall(
                    id: call.id, function: FunctionCall(name: call.name, arguments: call.arguments))
            }

            let responseBody = ChatCompletionResponse(
                id: "chatcmpl-\(UUID().uuidString)", object: "chat.completion",
                created: Int(Date().timeIntervalSince1970), model: ServerConfig.afmModelIdentifier,
                choices: [
                    ChatCompletionResponse.Choice(
                        index: 0,
                        message: ChatMessage(
                            role: "assistant", content: content, toolCalls: responseToolCalls),
                        finishReason: "tool_calls")
                ])

            let response = Response(status: .ok)
            try response.content.encode(responseBody)
            return response
        }

        // No tool calls - return final content
        let responseBody = ChatCompletionResponse(
            id: "chatcmpl-\(UUID().uuidString)", object: "chat.completion",
            created: Int(Date().timeIntervalSince1970), model: ServerConfig.afmModelIdentifier,
            choices: [
                ChatCompletionResponse.Choice(
                    index: 0, message: ChatMessage(role: "assistant", content: content ?? ""),
                    finishReason: "stop")
            ])

        let response = Response(status: .ok)
        try response.content.encode(responseBody)
        return response
    }

    /// Handle tool result submission (continuation after client executes tools)
    private func handleToolResultSubmission(
        req: Request, requestBody: ChatCompletionRequest
    ) async throws -> Response {
        // Extract system instructions
        let messages = requestBody.messages.map { (role: $0.role, content: $0.content ?? "") }
        let systemInstructions = messageTranslator.extractSystemInstructions(from: messages)

        // Build conversation history prompt from all messages
        var conversationParts: [String] = []

        for message in requestBody.messages {
            switch message.role {
            case "user":
                if let content = message.content { conversationParts.append("User: \(content)") }

            case "assistant":
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    // Assistant made tool calls
                    let toolCallsDesc = toolCalls.map {
                        "[\($0.function.name)(\($0.function.arguments))]"
                    }.joined(separator: ", ")
                    conversationParts.append("Assistant called tools: \(toolCallsDesc)")
                } else if let content = message.content {
                    // Assistant text response
                    conversationParts.append("Assistant: \(content)")
                }

            case "tool":
                // Tool result
                if let content = message.content, let name = message.name {
                    conversationParts.append("Tool '\(name)' returned: \(content)")
                }

            default: break
            }
        }

        // Add final prompt asking for response based on tool results
        conversationParts.append(
            "Based on the tool results above, provide your final response to the user.")

        let fullPrompt = conversationParts.joined(separator: "\n")

        // Generate final response
        let generatedContent: String
        do {
            generatedContent = try await llmProvider.respond(
                to: fullPrompt, systemInstructions: systemInstructions)
        } catch let error as LLMError {
            // Log error with context for debugging
            req.logger.error(
                "Tool result response error",
                metadata: [
                    "error": .string("\(error)"), "prompt_length": .string("\(fullPrompt.count)"),
                    "prompt_preview": .string(String(fullPrompt.prefix(100))),
                    "message_count": .string("\(requestBody.messages.count)"),
                ])
            throw mapLLMError(error)
        }

        // Build response
        let responseBody = ChatCompletionResponse(
            id: "chatcmpl-\(UUID().uuidString)", object: "chat.completion",
            created: Int(Date().timeIntervalSince1970), model: ServerConfig.afmModelIdentifier,
            choices: [
                ChatCompletionResponse.Choice(
                    index: 0, message: ChatMessage(role: "assistant", content: generatedContent),
                    finishReason: "stop")
            ])

        // Encode and return
        let response = Response(status: .ok)
        try response.content.encode(responseBody)
        return response
    }

    /// Handle streaming chat completion with SSE
    private func handleStreamingRequest(
        req: Request, userPrompt: String, systemInstructions: String?
    ) async throws -> Response {
        let id = "chatcmpl-\(UUID().uuidString)"
        let created = Int(Date().timeIntervalSince1970)

        // Create SSE response
        let response = Response(status: .ok)
        response.headers.contentType = .init(type: "text", subType: "event-stream")
        response.headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
        response.headers.replaceOrAdd(name: .connection, value: "keep-alive")

        // Stream the response
        let provider = self.llmProvider
        response.body = .init(asyncStream: { writer in
            let streamStart = Date()
            var firstTokenTime: Date?
            var totalChars = 0

            do {
                // Get streaming response from LLM
                let stream = try await provider.streamRespond(
                    to: userPrompt, systemInstructions: systemInstructions)

                // First chunk: role only
                let firstChunk = ChatCompletionChunk(
                    id: id, object: "chat.completion.chunk", created: created,
                    model: ServerConfig.afmModelIdentifier,
                    choices: [
                        ChatCompletionChunk.ChunkChoice(
                            index: 0, delta: Delta(role: "assistant", content: nil),
                            finishReason: nil)
                    ])
                try await writeSSEChunk(firstChunk, to: writer)

                // Stream content chunks
                for try await contentDelta in stream {
                    // Track TTFT on first content chunk
                    if firstTokenTime == nil {
                        firstTokenTime = Date()
                        let ttft = firstTokenTime!.timeIntervalSince(streamStart)
                        req.logger.info(
                            "First token received",
                            metadata: ["ttft_ms": .string(String(format: "%.2f", ttft * 1000))])
                    }

                    totalChars += contentDelta.count

                    let chunk = ChatCompletionChunk(
                        id: id, object: "chat.completion.chunk", created: created,
                        model: ServerConfig.afmModelIdentifier,
                        choices: [
                            ChatCompletionChunk.ChunkChoice(
                                index: 0, delta: Delta(role: nil, content: contentDelta),
                                finishReason: nil)
                        ])
                    try await writeSSEChunk(chunk, to: writer)
                }

                // Final chunk: finish_reason
                let finalChunk = ChatCompletionChunk(
                    id: id, object: "chat.completion.chunk", created: created,
                    model: ServerConfig.afmModelIdentifier,
                    choices: [
                        ChatCompletionChunk.ChunkChoice(
                            index: 0, delta: Delta(role: nil, content: nil), finishReason: "stop")
                    ])
                try await writeSSEChunk(finalChunk, to: writer)

                // Send [DONE] marker
                _ = try await writer.write(.buffer(.init(string: "data: [DONE]\n\n")))

                // Log final streaming metrics
                let totalDuration = Date().timeIntervalSince(streamStart)
                let outputTokens = max(1, totalChars / 4)
                let tokensPerSecond =
                    totalDuration > 0 ? Int(Double(outputTokens) / totalDuration) : 0

                req.logger.info(
                    "Streaming completed",
                    metadata: [
                        "duration_ms": .string(String(format: "%.2f", totalDuration * 1000)),
                        "ttft_ms": .string(
                            String(
                                format: "%.2f",
                                (firstTokenTime?.timeIntervalSince(streamStart) ?? 0) * 1000)),
                        "output_tokens": .string("\(outputTokens)"),
                        "tokens_per_second": .string("\(tokensPerSecond)"),
                        "chars_streamed": .string("\(totalChars)"),
                    ])

                // Signal end of stream
                try await writer.write(.end)

            } catch let error as LLMError {
                // Log streaming error with context for debugging
                req.logger.error(
                    "Streaming error",
                    metadata: [
                        "error": .string("\(error)"),
                        "prompt_length": .string("\(userPrompt.count)"),
                        "prompt_preview": .string(String(userPrompt.prefix(100))),
                        "has_system_instructions": .string("\(systemInstructions != nil)"),
                    ])
                try? await writer.write(.end)
            } catch {
                req.logger.error(
                    "Unexpected streaming error",
                    metadata: [
                        "error": .string("\(error)"),
                        "prompt_length": .string("\(userPrompt.count)"),
                    ])
                try? await writer.write(.end)
            }
        })

        return response
    }

    /// Write a ChatCompletionChunk as SSE data
    private func writeSSEChunk(
        _ chunk: ChatCompletionChunk, to writer: any AsyncBodyStreamWriter
    ) async throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let jsonData = try encoder.encode(chunk)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        _ = try await writer.write(.buffer(.init(string: "data: \(jsonString)\n\n")))
    }

    /// Check if request matches autocomplete pattern
    /// Autocomplete requests have specific structure:
    /// - Single user message with "Code before cursor:" and "Code after cursor:"
    /// - Non-streaming
    private func isAutocompleteRequest(
        messages: [(role: String, content: String)], stream: Bool?
    ) -> Bool {
        // Must be non-streaming
        guard stream != true else { return false }

        // Must have exactly one user message (after filtering system messages)
        let userMessages = messages.filter { $0.role == "user" }
        guard userMessages.count == 1 else { return false }

        let content = userMessages[0].content
        return content.contains("Code before cursor:") && content.contains("Code after cursor:")
    }

    /// Extract prefix from autocomplete prompt
    /// Returns nil if pattern doesn't match
    private func extractPrefix(from content: String) -> String? {
        // Pattern: "Code before cursor:\n{prefix}\n\nCode after cursor:"
        guard let beforeRange = content.range(of: "Code before cursor:\n") else { return nil }

        let afterStart = content.index(beforeRange.upperBound, offsetBy: 0)
        guard let afterRange = content[afterStart...].range(of: "\n\nCode after cursor:") else {
            return nil
        }

        return String(content[afterStart..<afterRange.lowerBound])
    }

    /// Strip prefix from completion if it's an exact match
    /// Returns original content if no match or if stripping would remove everything
    private func stripPrefixIfNeeded(_ content: String, prefix: String) -> String {
        var workingContent = content

        // First, strip markdown code fences if present
        // AFM sometimes wraps code completions in ```language\n...\n```
        if workingContent.hasPrefix("```") {
            // Find first newline after opening fence
            if let firstNewline = workingContent.firstIndex(of: "\n") {
                let afterFence = workingContent.index(after: firstNewline)
                // Find closing fence
                if let closingFence = workingContent[afterFence...].range(of: "\n```") {
                    // Extract content between fences
                    workingContent = String(workingContent[afterFence..<closingFence.lowerBound])
                }
            }
        }

        // Try exact prefix match first
        if workingContent.hasPrefix(prefix) {
            let stripped = String(workingContent.dropFirst(prefix.count))
            return stripped.isEmpty ? workingContent : stripped
        }

        // If exact match fails, try finding overlap with suffix of prefix
        // LLMs often skip leading comments/whitespace but echo the actual code
        // Find the longest suffix of prefix that matches the start of content
        let prefixLines = prefix.split(separator: "\n", omittingEmptySubsequences: false)

        // Try progressively smaller suffixes of the prefix (skip leading lines)
        for skipCount in 0..<prefixLines.count {
            let suffix = prefixLines.dropFirst(skipCount).joined(separator: "\n")
            if !suffix.isEmpty && workingContent.hasPrefix(suffix) {
                let stripped = String(workingContent.dropFirst(suffix.count))
                // Only return stripped version if we found a meaningful overlap (at least 10 chars)
                if suffix.count >= 10 && !stripped.isEmpty { return stripped }
            }
        }

        // No overlap found - return content as-is
        return workingContent
    }

    /// Map LLMError to Abort error
    private func mapLLMError(_ error: LLMError) -> Abort {
        switch error {
        case .modelNotAvailable(let message): return Abort(.serviceUnavailable, reason: message)
        case .frameworkNotAvailable:
            return Abort(
                .serviceUnavailable,
                reason: "FoundationModels framework not available (requires macOS 26.0+)")
        case .invalidMessageFormat(let message): return Abort(.badRequest, reason: message)
        case .contentFiltered(let message):
            return Abort(.badRequest, reason: "Content filtered: \(message)")
        }
    }
}
