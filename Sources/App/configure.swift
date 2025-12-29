import Vapor

@available(macOS 26.0, *) func configure(_ app: Application) async throws {
    // Configure logging
    app.logger.logLevel =
        Environment.get("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) } ?? .info

    // Configure middleware
    app.middleware = .init()
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.middleware.use(RouteLoggingMiddleware(logLevel: .info))

    // Configure server
    app.http.server.configuration.hostname = Environment.get("HOST") ?? "127.0.0.1"
    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8080

    // Register routes
    try routes(app)
}

/// Middleware to log incoming requests
struct RouteLoggingMiddleware: AsyncMiddleware {
    let logLevel: Logger.Level

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        request.logger.log(level: logLevel, "\(request.method) \(request.url.path)")
        return try await next.respond(to: request)
    }
}
