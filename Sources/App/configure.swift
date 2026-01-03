import Configuration
import Middleware
import Services
import Vapor

func configure(_ app: Application, llmProvider: LLMProvider? = nil) async throws {
    // Load server configuration from environment
    let config = ServerConfig()

    // Configure logging
    app.logger.logLevel = config.logLevel

    // Configure middleware
    app.middleware = .init()
    app.middleware.use(APIErrorMiddleware())
    app.middleware.use(MetricsMiddleware())

    // Configure server
    app.http.server.configuration.hostname = config.hostname
    app.http.server.configuration.port = config.port

    // Register routes (optionally with test provider)
    try await routes(app, llmProvider: llmProvider)
}
