import Controllers
import Services
import Vapor

func routes(_ app: Application, llmProvider: LLMProvider? = nil) throws {
    // Health check endpoint
    app.get("health") { req async throws -> String in "OK" }

    // Initialize LLM provider (use provided or create default)
    let provider: LLMProvider
    if let llmProvider = llmProvider {
        provider = llmProvider
    } else {
        if #available(macOS 26.0, *) {
            provider = FoundationModelService()
        } else {
            throw Abort(.serviceUnavailable, reason: "FoundationModels requires macOS 26.0+")
        }
    }

    // Register OpenAI-compatible controller
    let openAIController = OpenAIController(llmProvider: provider)
    try app.register(collection: openAIController)
}
