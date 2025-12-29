import Vapor

let app = try await Application.make(.detect())

do {
    if #available(macOS 26.0, *) {
        try await configure(app)
        try await app.execute()
    } else {
        app.logger.critical("AFMBridge requires macOS 26.0+ (FoundationModels framework)")
        try await app.asyncShutdown()
        throw Abort(.serviceUnavailable, reason: "macOS 26.0+ required")
    }
} catch {
    app.logger.report(error: error)
    try? await app.asyncShutdown()
    throw error
}
