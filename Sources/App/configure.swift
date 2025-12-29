import Configuration
import Services
import Vapor

func configure(_ app: Application, llmProvider: LLMProvider? = nil) async throws {
    // Load server configuration from environment
    let config = ServerConfig()

    // Configure logging
    app.logger.logLevel = config.logLevel

    // Configure middleware
    app.middleware = .init()
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.middleware.use(RouteLoggingMiddleware(logLevel: .info))

    // Configure server
    app.http.server.configuration.hostname = config.hostname
    app.http.server.configuration.port = config.port

    // Register routes (optionally with test provider)
    try routes(app, llmProvider: llmProvider)
}

/// Middleware to log incoming requests
struct RouteLoggingMiddleware: AsyncMiddleware {
    let logLevel: Logger.Level

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        request.logger.log(level: logLevel, "\(request.method) \(request.url.path)")
        return try await next.respond(to: request)
    }
}
