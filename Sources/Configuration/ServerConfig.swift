import Vapor

/// Server configuration loaded from environment variables
public struct ServerConfig {
    /// Server hostname (default: "127.0.0.1")
    public let hostname: String

    /// Server port (default: 8080)
    public let port: Int

    /// Maximum tokens to generate per request (default: 1024)
    public let maxTokens: Int

    /// Log level (default: .info)
    public let logLevel: Logger.Level

    /// Initialize server configuration from environment variables
    public init() {
        self.hostname = Environment.get("HOST") ?? "127.0.0.1"
        self.port = Environment.get("PORT").flatMap(Int.init) ?? 8080
        self.maxTokens = Environment.get("MAX_TOKENS").flatMap(Int.init) ?? 1024
        self.logLevel = Environment.get("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) } ?? .info
    }

    /// Initialize with explicit values (useful for testing)
    public init(hostname: String, port: Int, maxTokens: Int, logLevel: Logger.Level) {
        self.hostname = hostname
        self.port = port
        self.maxTokens = maxTokens
        self.logLevel = logLevel
    }
}
