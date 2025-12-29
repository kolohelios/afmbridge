import Configuration
import Logging
import XCTest

final class ServerConfigTests: XCTestCase {

    // MARK: - Default Values Tests

    func testServerConfig_defaultHostname() {
        // Given: No HOST environment variable
        // When: Creating ServerConfig with defaults
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 8080, maxTokens: 1024, logLevel: .info)

        // Then: Should use default hostname
        XCTAssertEqual(config.hostname, "127.0.0.1")
    }

    func testServerConfig_defaultPort() {
        // Given: No PORT environment variable
        // When: Creating ServerConfig with defaults
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 8080, maxTokens: 1024, logLevel: .info)

        // Then: Should use default port
        XCTAssertEqual(config.port, 8080)
    }

    func testServerConfig_defaultMaxTokens() {
        // Given: No MAX_TOKENS environment variable
        // When: Creating ServerConfig with defaults
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 8080, maxTokens: 1024, logLevel: .info)

        // Then: Should use default max tokens
        XCTAssertEqual(config.maxTokens, 1024)
    }

    func testServerConfig_defaultLogLevel() {
        // Given: No LOG_LEVEL environment variable
        // When: Creating ServerConfig with defaults
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 8080, maxTokens: 1024, logLevel: .info)

        // Then: Should use default log level
        XCTAssertEqual(config.logLevel, .info)
    }

    // MARK: - Custom Values Tests

    func testServerConfig_customHostname() {
        // Given: Custom hostname
        // When: Creating ServerConfig with custom value
        let config = ServerConfig(hostname: "0.0.0.0", port: 8080, maxTokens: 1024, logLevel: .info)

        // Then: Should use custom hostname
        XCTAssertEqual(config.hostname, "0.0.0.0")
    }

    func testServerConfig_customPort() {
        // Given: Custom port
        // When: Creating ServerConfig with custom value
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 3000, maxTokens: 1024, logLevel: .info)

        // Then: Should use custom port
        XCTAssertEqual(config.port, 3000)
    }

    func testServerConfig_customMaxTokens() {
        // Given: Custom max tokens
        // When: Creating ServerConfig with custom value
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 8080, maxTokens: 2048, logLevel: .info)

        // Then: Should use custom max tokens
        XCTAssertEqual(config.maxTokens, 2048)
    }

    func testServerConfig_customLogLevel() {
        // Given: Custom log level
        // When: Creating ServerConfig with custom value
        let config = ServerConfig(
            hostname: "127.0.0.1", port: 8080, maxTokens: 1024, logLevel: .debug)

        // Then: Should use custom log level
        XCTAssertEqual(config.logLevel, .debug)
    }

    // MARK: - Initialization Tests

    func testServerConfig_canBeInitializedWithDefaults() {
        // When: Creating ServerConfig with default initializer
        let config = ServerConfig()

        // Then: Should initialize successfully
        XCTAssertNotNil(config)
        XCTAssertEqual(config.hostname, "127.0.0.1")
        XCTAssertEqual(config.port, 8080)
        XCTAssertEqual(config.maxTokens, 1024)
        XCTAssertEqual(config.logLevel, .info)
    }

    func testServerConfig_canBeInitializedWithCustomValues() {
        // When: Creating ServerConfig with custom values
        let config = ServerConfig(
            hostname: "0.0.0.0", port: 3000, maxTokens: 2048, logLevel: .trace)

        // Then: Should initialize with custom values
        XCTAssertNotNil(config)
        XCTAssertEqual(config.hostname, "0.0.0.0")
        XCTAssertEqual(config.port, 3000)
        XCTAssertEqual(config.maxTokens, 2048)
        XCTAssertEqual(config.logLevel, .trace)
    }
}
