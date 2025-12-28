import Vapor

func routes(_ app: Application) throws {
    // Health check endpoint
    app.get("health") { req async throws -> String in "OK" }
}
