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
            return try await handleToolResultSubmission(
                req: req, requestBody: requestBody, model: requestBody.model)
        }

        // Convert messages to translation service format
        // For now, unwrap content with empty string (Phase 3 will add full tool support)
        let messages = requestBody.messages.map { (role: $0.role, content: $0.content ?? "") }

        // Extract system instructions
        let systemInstructions = messageTranslator.extractSystemInstructions(from: messages)

        // Extract user prompt
        let userPrompt: String
        do { userPrompt = try messageTranslator.extractUserPrompt(from: messages) } catch let error
            as LLMError
        { throw mapLLMError(error) }

        // Handle streaming vs non-streaming
        if requestBody.stream == true {
            // Note: Streaming with tools is not yet supported by AFM
            // If tools are present, fall back to non-streaming response
            if let tools = requestBody.tools, !tools.isEmpty {
                return try await handleNonStreamingRequest(
                    req: req, requestBody: requestBody, userPrompt: userPrompt,
                    systemInstructions: systemInstructions, model: requestBody.model)
            }

            return try await handleStreamingRequest(
                req: req, userPrompt: userPrompt, systemInstructions: systemInstructions,
                model: requestBody.model)
        } else {
            return try await handleNonStreamingRequest(
                req: req, requestBody: requestBody, userPrompt: userPrompt,
                systemInstructions: systemInstructions, model: requestBody.model)
        }
    }

    /// Handle non-streaming chat completion
    private func handleNonStreamingRequest(
        req: Request, requestBody: ChatCompletionRequest, userPrompt: String,
        systemInstructions: String?, model: String
    ) async throws -> Response {

        // Check if tools are present in the request
        if let tools = requestBody.tools, !tools.isEmpty {
            return try await handleToolCallingRequest(
                req: req, requestBody: requestBody, userPrompt: userPrompt,
                systemInstructions: systemInstructions, model: model)
        }

        // Generate response
        let generatedContent: String
        do {
            generatedContent = try await llmProvider.respond(
                to: userPrompt, systemInstructions: systemInstructions)
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

        // Build response
        let responseBody = ChatCompletionResponse(
            id: "chatcmpl-\(UUID().uuidString)", object: "chat.completion",
            created: Int(Date().timeIntervalSince1970), model: model,
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

    /// Handle tool calling request
    private func handleToolCallingRequest(
        req: Request, requestBody: ChatCompletionRequest, userPrompt: String,
        systemInstructions: String?, model: String
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
                created: Int(Date().timeIntervalSince1970), model: model,
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
            created: Int(Date().timeIntervalSince1970), model: model,
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
        req: Request, requestBody: ChatCompletionRequest, model: String
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
            created: Int(Date().timeIntervalSince1970), model: model,
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
        req: Request, userPrompt: String, systemInstructions: String?, model: String
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
                    id: id, object: "chat.completion.chunk", created: created, model: model,
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
                        id: id, object: "chat.completion.chunk", created: created, model: model,
                        choices: [
                            ChatCompletionChunk.ChunkChoice(
                                index: 0, delta: Delta(role: nil, content: contentDelta),
                                finishReason: nil)
                        ])
                    try await writeSSEChunk(chunk, to: writer)
                }

                // Final chunk: finish_reason
                let finalChunk = ChatCompletionChunk(
                    id: id, object: "chat.completion.chunk", created: created, model: model,
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
