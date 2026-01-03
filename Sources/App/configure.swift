import Configuration
import Middleware
import Services
import Vapor

func configure(
    _ app: Application, llmProvider: LLMProvider? = nil, config: ServerConfig? = nil
) async throws {
    // Load server configuration from environment or use provided config (for testing)
    let config = config ?? ServerConfig()

    // Configure logging
    app.logger.logLevel = config.logLevel

    // Configure middleware
    app.middleware = .init()
    app.middleware.use(APIErrorMiddleware())

    // Conditionally enable authentication if API key is configured
    if let apiKey = config.apiKey {
        app.logger.info("API key authentication enabled")
        app.middleware.use(AuthenticationMiddleware(apiKey: apiKey))
    } else {
        app.logger.warning("API key authentication disabled - no API_KEY environment variable set")
    }

    app.middleware.use(MetricsMiddleware())

    // Configure server
    app.http.server.configuration.hostname = config.hostname
    app.http.server.configuration.port = config.port

    // Register routes (optionally with test provider)
    try await routes(app, llmProvider: llmProvider)
}
