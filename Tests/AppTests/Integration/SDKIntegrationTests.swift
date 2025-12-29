import Foundation
import XCTest

/// SDK Integration Tests - OpenAI and Anthropic SDK compatibility
///
/// These tests verify that official Python SDKs can successfully communicate with AFMBridge.
/// They require:
/// - macOS 26.0+ with FoundationModels framework
/// - Python 3.8+ with openai and anthropic packages installed
/// - AFMBridge server running locally
///
/// Tests are automatically skipped in CI or when requirements aren't met.
@available(macOS 14.0, *) final class SDKIntegrationTests: XCTestCase {

    // MARK: - Setup

    override class func setUp() {
        super.setUp()
        // Check if we should skip all SDK tests
        if !canRunSDKTests() {
            print("⚠️  Skipping SDK integration tests")
            print("   Missing: Python openai package")
            print("   Install: pip install openai anthropic")
            print("   Or use: nix develop (includes packages)")
        }
    }

    // MARK: - Helper Methods

    /// Check if SDK integration tests can run
    private static func canRunSDKTests() -> Bool {
        // Check macOS version (requires 26.0+ for FoundationModels)
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        if osVersion.majorVersion < 26 { return false }

        // Check if Python is available
        let pythonCheck = runCommand("/usr/bin/env", arguments: ["python3", "--version"])
        if !pythonCheck.success { return false }

        // Check if openai package is installed
        let openaiCheck = runCommand("/usr/bin/env", arguments: ["python3", "-c", "import openai"])
        if !openaiCheck.success { return false }

        return true
    }

    /// Run a shell command and return result
    private static func runCommand(
        _ command: String, arguments: [String] = [], environment: [String: String]? = nil
    ) -> (success: Bool, output: String) {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        if let env = environment {
            var processEnv = ProcessInfo.processInfo.environment
            processEnv.merge(env) { _, new in new }
            process.environment = processEnv
        }

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            return (process.terminationStatus == 0, output)
        } catch { return (false, error.localizedDescription) }
    }

    /// Run Python SDK test script
    private func runPythonSDKTest(script: String) throws {
        guard Self.canRunSDKTests() else {
            throw XCTSkip("SDK integration tests require macOS 26.0+ and local environment")
        }

        // Locate test script relative to current file
        // #file is Tests/AppTests/Integration/SDKIntegrationTests.swift
        let currentFileURL = URL(fileURLWithPath: #filePath)
        let packageRoot = currentFileURL.deletingLastPathComponent()  // Tests/AppTests/Integration
            .deletingLastPathComponent()  // Tests/AppTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
        let scriptPath = packageRoot.appendingPathComponent("Tests").appendingPathComponent(
            "SDKTests"
        ).appendingPathComponent(script).path

        // Verify script exists
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: scriptPath),
            "SDK test script not found: \(scriptPath)")

        // Run the Python test script
        let result = Self.runCommand(
            "/usr/bin/env", arguments: ["python3", scriptPath],
            environment: ["AFMBRIDGE_URL": "http://localhost:8080"])

        // Assert test passed
        XCTAssertTrue(
            result.success,
            """
            SDK test failed: \(script)
            Output: \(result.output)
            """)

        print("SDK test passed: \(script)")
        print(result.output)
    }

    // MARK: - OpenAI SDK Tests

    func testOpenAISDK_compatibility() throws { try runPythonSDKTest(script: "test_openai_sdk.py") }

    // MARK: - Anthropic SDK Tests (Phase 3+)

    // Uncomment when Anthropic controller is implemented
    // func testAnthropicSDK_compatibility() throws {
    //     try runPythonSDKTest(script: "test_anthropic_sdk.py")
    // }
}
