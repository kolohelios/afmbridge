import DTOs
import Foundation
import Models
import Services
import Vapor

/// Controller for OpenAI-compatible chat completions endpoint
public struct OpenAIController: RouteCollection {
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
    /// - Returns: ChatCompletionResponse
    /// - Throws: Abort errors for invalid requests or LLM errors
    public func chatCompletions(req: Request) async throws -> ChatCompletionResponse {
        // Decode request
        let requestBody = try req.content.decode(ChatCompletionRequest.self)

        // Reject streaming requests (not supported in Phase 1)
        if requestBody.stream == true {
            throw Abort(.badRequest, reason: "Streaming not yet supported")
        }

        // Convert messages to translation service format
        let messages = requestBody.messages.map { (role: $0.role, content: $0.content) }

        // Extract system instructions
        let systemInstructions = messageTranslator.extractSystemInstructions(from: messages)

        // Extract user prompt and generate response
        let generatedContent: String
        do {
            let userPrompt = try messageTranslator.extractUserPrompt(from: messages)
            generatedContent = try await llmProvider.respond(
                to: userPrompt, systemInstructions: systemInstructions)
        } catch let error as LLMError {
            // Map LLM errors to HTTP errors
            throw mapLLMError(error)
        }

        // Build response
        let response = ChatCompletionResponse(
            id: "chatcmpl-\(UUID().uuidString)", object: "chat.completion",
            created: Int(Date().timeIntervalSince1970), model: requestBody.model,
            choices: [
                ChatCompletionResponse.Choice(
                    index: 0, message: ChatMessage(role: "assistant", content: generatedContent),
                    finishReason: "stop")
            ])

        return response
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
