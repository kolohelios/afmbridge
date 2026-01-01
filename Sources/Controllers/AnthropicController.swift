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
            // Streaming will be implemented in the next phase
            throw Abort(
                .notImplemented, reason: "Streaming support not yet implemented for Anthropic API")
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
