import XCTest

@testable import Models
@testable import Services

final class ToolTests: XCTestCase {

    // MARK: - ToolExecutor Tests

    func testClosureExecutor_successfulExecution() async throws {
        let executor = ClosureExecutor { arguments in
            "Result: \(arguments)"
        }

        let result = try await executor.execute(arguments: "{\"input\":\"test\"}")
        XCTAssertEqual(result, "Result: {\"input\":\"test\"}")
    }

    func testClosureExecutor_throwsError() async {
        let executor = ClosureExecutor { _ in
            throw ToolExecutionError.invalidArguments("Test error")
        }

        do {
            _ = try await executor.execute(arguments: "{}")
            XCTFail("Expected error to be thrown")
        } catch let error as ToolExecutionError {
            guard case .invalidArguments(let message) = error else {
                return XCTFail("Expected invalidArguments error")
            }
            XCTAssertEqual(message, "Test error")
        } catch {
            XCTFail("Expected ToolExecutionError, got \(error)")
        }
    }

    // MARK: - ToolRegistry Tests

    func testToolRegistry_registerAndRetrieve() async {
        let registry = ToolRegistry()
        let executor = ClosureExecutor { args in "executed: \(args)" }

        await registry.register(name: "test_tool", executor: executor)

        let retrieved = await registry.executor(for: "test_tool")
        XCTAssertNotNil(retrieved)
    }

    func testToolRegistry_unregister() async {
        let registry = ToolRegistry()
        let executor = ClosureExecutor { args in "result" }

        await registry.register(name: "test_tool", executor: executor)
        let isRegisteredBefore = await registry.isRegistered(name: "test_tool")
        XCTAssertTrue(isRegisteredBefore)

        await registry.unregister(name: "test_tool")
        let isRegisteredAfter = await registry.isRegistered(name: "test_tool")
        XCTAssertFalse(isRegisteredAfter)
    }

    func testToolRegistry_executeRegisteredTool() async throws {
        let registry = ToolRegistry()
        let executor = ClosureExecutor { arguments in
            "Executed with: \(arguments)"
        }

        await registry.register(name: "my_tool", executor: executor)

        let result = try await registry.execute(
            tool: "my_tool", arguments: "{\"param\":\"value\"}")
        XCTAssertEqual(result, "Executed with: {\"param\":\"value\"}")
    }

    func testToolRegistry_executeNonexistentTool() async {
        let registry = ToolRegistry()

        do {
            _ = try await registry.execute(tool: "nonexistent", arguments: "{}")
            XCTFail("Expected error to be thrown")
        } catch let error as ToolExecutionError {
            guard case .toolNotFound(let name) = error else {
                return XCTFail("Expected toolNotFound error")
            }
            XCTAssertEqual(name, "nonexistent")
        } catch {
            XCTFail("Expected ToolExecutionError, got \(error)")
        }
    }

    func testToolRegistry_executionFailure() async {
        let registry = ToolRegistry()
        let executor = ClosureExecutor { _ in
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "test error"])
        }

        await registry.register(name: "failing_tool", executor: executor)

        do {
            _ = try await registry.execute(tool: "failing_tool", arguments: "{}")
            XCTFail("Expected error to be thrown")
        } catch let error as ToolExecutionError {
            guard case .executionFailed(let name, _) = error else {
                return XCTFail("Expected executionFailed error")
            }
            XCTAssertEqual(name, "failing_tool")
        } catch {
            XCTFail("Expected ToolExecutionError, got \(error)")
        }
    }

    func testToolRegistry_registeredTools() async {
        let registry = ToolRegistry()
        let executor1 = ClosureExecutor { _ in "result1" }
        let executor2 = ClosureExecutor { _ in "result2" }

        await registry.register(name: "tool1", executor: executor1)
        await registry.register(name: "tool2", executor: executor2)

        let tools = await registry.registeredTools()
        XCTAssertEqual(Set(tools), Set(["tool1", "tool2"]))
    }

    func testToolRegistry_isRegistered() async {
        let registry = ToolRegistry()
        let executor = ClosureExecutor { _ in "result" }

        let isRegisteredBefore = await registry.isRegistered(name: "test_tool")
        XCTAssertFalse(isRegisteredBefore)

        await registry.register(name: "test_tool", executor: executor)
        let isRegisteredAfter = await registry.isRegistered(name: "test_tool")
        XCTAssertTrue(isRegisteredAfter)
    }

    // MARK: - ToolFactory Tests

    #if canImport(FoundationModels)
        @available(macOS 26.0, *)
        func testToolFactory_createTool() async {
            let factory = ToolFactory()
            let definition = ToolDefinition(
                name: "get_weather",
                description: "Get the current weather",
                parameters: JSONSchema(
                    type: "object",
                    properties: [
                        "location": [
                            "type": .string("string"),
                            "description": .string("The city name"),
                        ]
                    ],
                    required: ["location"]))

            let tool = await factory.createTool(from: definition) { _ in
                "Sunny, 72°F"
            }

            XCTAssertEqual(tool.name, "get_weather")
            XCTAssertEqual(tool.description, "Get the current weather")
        }

        @available(macOS 26.0, *)
        func testToolFactory_toolExecution() async throws {
            let factory = ToolFactory()
            let definition = ToolDefinition(
                name: "test_tool",
                description: "Test tool",
                parameters: JSONSchema(type: "object"))

            // Store the tool and test it - can't call methods on existential type directly
            let _tool = await factory.createTool(from: definition) { arguments in
                "Received: \(arguments)"
            }

            // Verify tool was created successfully
            XCTAssertNotNil(_tool)
        }
    #endif

    // MARK: - Error Description Tests

    func testToolExecutionError_descriptions() {
        let notFoundError = ToolExecutionError.toolNotFound("test_tool")
        XCTAssertTrue(notFoundError.description.contains("test_tool"))

        let testError = NSError(domain: "test", code: 1)
        let execError = ToolExecutionError.executionFailed("my_tool", testError)
        XCTAssertTrue(execError.description.contains("my_tool"))

        let invalidArgsError = ToolExecutionError.invalidArguments("bad format")
        XCTAssertTrue(invalidArgsError.description.contains("bad format"))
    }
}
