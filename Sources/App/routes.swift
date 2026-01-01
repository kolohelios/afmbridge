import Controllers
import Services
import Vapor

func routes(_ app: Application, llmProvider: LLMProvider? = nil) async throws {
    // Health check endpoint
    app.get("health") { req async throws -> String in "OK" }

    // Initialize LLM provider (use provided or create default)
    let provider: LLMProvider
    if let llmProvider = llmProvider {
        provider = llmProvider
    } else {
        if #available(macOS 26.0, *) {
            let service = FoundationModelService()
            // Pre-warm session to eliminate first-request penalty
            await service.preWarm()
            provider = service
        } else {
            throw Abort(.serviceUnavailable, reason: "FoundationModels requires macOS 26.0+")
        }
    }

    // Register OpenAI-compatible controller
    let openAIController = OpenAIController(llmProvider: provider)
    try app.register(collection: openAIController)

    // Register Anthropic-compatible controller
    let anthropicController = AnthropicController(llmProvider: provider)
    try app.register(collection: anthropicController)
}
