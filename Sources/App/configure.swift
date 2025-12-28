import Vapor

func configure(_ app: Application) async throws {
    // Configure server
    app.http.server.configuration.hostname = Environment.get("HOST") ?? "127.0.0.1"
    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8080

    // Register routes
    try routes(app)
}
