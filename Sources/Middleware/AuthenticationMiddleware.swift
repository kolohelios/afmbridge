import Configuration
import Vapor

/// Middleware for validating Bearer token authentication
public struct AuthenticationMiddleware: AsyncMiddleware {
    private let apiKey: String

    public init(apiKey: String) { self.apiKey = apiKey }

    public func respond(
        to request: Request, chainingTo next: any AsyncResponder
    ) async throws -> Response {
        // Extract Authorization header
        guard let authHeader = request.headers[.authorization].first else {
            throw Abort(.unauthorized, reason: "Missing Authorization header")
        }

        // Validate Bearer token format
        let components = authHeader.split(separator: " ", maxSplits: 1)
        guard components.count == 2, components[0].lowercased() == "bearer" else {
            throw Abort(.unauthorized, reason: "Invalid Authorization header format")
        }

        let token = String(components[1])

        // Validate token matches configured API key
        guard token == apiKey else { throw Abort(.unauthorized, reason: "Invalid API key") }

        // Token is valid, continue with request
        return try await next.respond(to: request)
    }
}
