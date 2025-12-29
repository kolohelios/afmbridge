import Controllers
import Services
import Vapor

@available(macOS 26.0, *) func routes(_ app: Application) throws {
    // Health check endpoint
    app.get("health") { req async throws -> String in "OK" }

    // Initialize LLM provider
    let llmProvider = FoundationModelService()

    // Register OpenAI-compatible controller
    let openAIController = OpenAIController(llmProvider: llmProvider)
    try app.register(collection: openAIController)
}
