import Vapor

let app = try await Application.make(.detect())

do {
    try await configure(app)
    try await app.execute()
} catch {
    app.logger.report(error: error)
    try? await app.asyncShutdown()
    throw error
}
