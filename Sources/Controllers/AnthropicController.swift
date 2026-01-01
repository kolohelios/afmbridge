import DTOs
import Foundation
import Models
import Services
import Vapor

/// Controller for Anthropic Messages API endpoint
public struct AnthropicController: RouteCollection, Sendable {
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
        let anthropic = routes.grouped("v1")
        anthropic.post("messages", use: createMessage)
    }

    /// Handle message creation requests
    /// - Parameter req: The Vapor request
    /// - Returns: MessageResponse for non-streaming, Response for streaming
    /// - Throws: Abort errors for invalid requests or LLM errors
    public func createMessage(req: Request) async throws -> Response {
        // Decode request
        let requestBody = try req.content.decode(MessageRequest.self)

        // Extract system instructions from separate parameter
        let systemInstructions = messageTranslator.extractAnthropicSystemInstructions(
            systemParameter: requestBody.system, messages: requestBody.messages)

        // Extract user prompt
        let userPrompt: String
        do {
            userPrompt = try messageTranslator.extractAnthropicUserPrompt(
                from: requestBody.messages)
        } catch let error as LLMError { throw mapLLMError(error) }

        // Handle streaming vs non-streaming
        if requestBody.stream == true {
            return try await handleStreamingRequest(
                req: req, requestBody: requestBody, userPrompt: userPrompt,
                systemInstructions: systemInstructions)
        } else {
            return try await handleNonStreamingRequest(
                req: req, requestBody: requestBody, userPrompt: userPrompt,
                systemInstructions: systemInstructions)
        }
    }

    /// Handle non-streaming message creation
    private func handleNonStreamingRequest(
        req: Request, requestBody: MessageRequest, userPrompt: String, systemInstructions: String?
    ) async throws -> Response {
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
        let responseBody = MessageResponse(
            id: "msg_\(UUID().uuidString)", model: requestBody.model,
            content: [.text(ResponseTextBlock(text: generatedContent))], stopReason: .endTurn,
            usage: Usage(
                inputTokens: estimateTokens(userPrompt + (systemInstructions ?? "")),
                outputTokens: estimateTokens(generatedContent)))

        // Encode and return
        let response = Response(status: .ok)
        try response.content.encode(responseBody)
        return response
    }

    /// Handle streaming message creation with SSE
    private func handleStreamingRequest(
        req: Request, requestBody: MessageRequest, userPrompt: String,
        systemInstructions: String?
    ) async throws -> Response {
        let id = "msg_\(UUID().uuidString)"

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
            let contentIndex = 0

            do {
                // Get streaming response from LLM
                let stream = try await provider.streamRespond(
                    to: userPrompt, systemInstructions: systemInstructions)

                // Event 1: message_start
                let messageStartEvent = StreamEvent.messageStart(
                    MessageStartEvent(
                        message: MessageSnapshot(
                            id: id, content: [], model: requestBody.model, stopReason: nil,
                            usage: Usage(
                                inputTokens: self.estimateTokens(
                                    userPrompt + (systemInstructions ?? "")), outputTokens: 0))))
                try await self.writeAnthropicSSE(messageStartEvent, eventName: "message_start", to: writer)

                // Event 2: content_block_start
                let blockStartEvent = StreamEvent.contentBlockStart(
                    ContentBlockStartEvent(
                        index: contentIndex, contentBlock: ContentBlockStart(type: "text", text: "")))
                try await self.writeAnthropicSSE(blockStartEvent, eventName: "content_block_start", to: writer)

                // Event 3: content_block_delta (multiple)
                var accumulatedText = ""
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
                    accumulatedText += contentDelta

                    let deltaEvent = StreamEvent.contentBlockDelta(
                        ContentBlockDeltaEvent(
                            index: contentIndex,
                            delta: ContentDelta(type: "text_delta", text: contentDelta)))
                    try await self.writeAnthropicSSE(deltaEvent, eventName: "content_block_delta", to: writer)
                }

                // Event 4: content_block_stop
                let blockStopEvent = StreamEvent.contentBlockStop(
                    ContentBlockStopEvent(index: contentIndex))
                try await self.writeAnthropicSSE(blockStopEvent, eventName: "content_block_stop", to: writer)

                // Event 5: message_delta
                let messageDeltaEvent = StreamEvent.messageDelta(
                    MessageDeltaEvent(
                        delta: MessageDelta(stopReason: .endTurn),
                        usage: UsageDelta(outputTokens: self.estimateTokens(accumulatedText))))
                try await self.writeAnthropicSSE(messageDeltaEvent, eventName: "message_delta", to: writer)

                // Event 6: message_stop
                let messageStopEvent = StreamEvent.messageStop(MessageStopEvent())
                try await self.writeAnthropicSSE(messageStopEvent, eventName: "message_stop", to: writer)

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

                // Send error event
                let errorEvent = StreamEvent.error(
                    ErrorEvent(error: ErrorDetail(type: "error", message: error.localizedDescription)))
                try? await self.writeAnthropicSSE(errorEvent, eventName: "error", to: writer)
                try? await writer.write(.end)
            } catch {
                req.logger.error(
                    "Unexpected streaming error",
                    metadata: [
                        "error": .string("\(error)"), "prompt_length": .string("\(userPrompt.count)"),
                    ])
                try? await writer.write(.end)
            }
        })

        return response
    }

    /// Write an Anthropic StreamEvent as named SSE data
    private func writeAnthropicSSE(
        _ event: StreamEvent, eventName: String, to writer: any AsyncBodyStreamWriter
    ) async throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let jsonData = try encoder.encode(event)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        _ = try await writer.write(.buffer(.init(string: "event: \(eventName)\ndata: \(jsonString)\n\n")))
    }

    /// Map LLM errors to appropriate HTTP errors
    private func mapLLMError(_ error: LLMError) -> Abort {
        switch error {
        case .modelNotAvailable(let model):
            return Abort(.serviceUnavailable, reason: "Model \(model) is not available")
        case .frameworkNotAvailable:
            return Abort(
                .serviceUnavailable,
                reason: "Apple Intelligence framework is not available (requires macOS 26.0+)")
        case .invalidMessageFormat(let message):
            return Abort(.badRequest, reason: "Invalid message format: \(message)")
        case .contentFiltered(let reason):
            return Abort(.badRequest, reason: "Content filtered: \(reason)")
        }
    }

    /// Estimate token count for usage reporting
    /// This is a rough approximation: ~4 characters per token
    private func estimateTokens(_ text: String) -> Int { return max(1, text.count / 4) }
}
