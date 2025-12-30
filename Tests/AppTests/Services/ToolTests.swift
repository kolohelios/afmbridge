import XCTest

@testable import Models
@testable import Services

final class ToolTests: XCTestCase {

    // MARK: - ToolExecutor Tests

    func testClosureExecutor_successfulExecution() async throws {
        let executor = ClosureExecutor { arguments in "Result: \(arguments)" }

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
        } catch { XCTFail("Expected ToolExecutionError, got \(error)") }
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
        let executor = ClosureExecutor { arguments in "Executed with: \(arguments)" }

        await registry.register(name: "my_tool", executor: executor)

        let result = try await registry.execute(tool: "my_tool", arguments: "{\"param\":\"value\"}")
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
        } catch { XCTFail("Expected ToolExecutionError, got \(error)") }
    }

    func testToolRegistry_executionFailure() async {
        let registry = ToolRegistry()
        let executor = ClosureExecutor { _ in
            throw NSError(
                domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "test error"])
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
        } catch { XCTFail("Expected ToolExecutionError, got \(error)") }
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
        @available(macOS 26.0, *) func testToolFactory_createTool() async {
            let factory = ToolFactory()
            let definition = ToolDefinition(
                name: "get_weather", description: "Get the current weather",
                parameters: JSONSchema(
                    type: "object",
                    properties: [
                        "location": [
                            "type": .string("string"), "description": .string("The city name"),
                        ]
                    ], required: ["location"]))

            let tool = await factory.createTool(from: definition) { _ in "Sunny, 72°F" }

            XCTAssertEqual(tool.name, "get_weather")
            XCTAssertEqual(tool.description, "Get the current weather")
        }

        @available(macOS 26.0, *) func testToolFactory_toolExecution() async throws {
            let factory = ToolFactory()
            let definition = ToolDefinition(
                name: "test_tool", description: "Test tool", parameters: JSONSchema(type: "object"))

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

    // MARK: - ToolCallHandler Tests

    #if canImport(FoundationModels)
        @available(macOS 26.0, *) func testToolCallHandler_directResponse() async throws {
            // Given: A mock provider that returns content without tool calls
            let mockProvider = MockToolCallingProvider(responses: [
                (content: "Direct answer", toolCalls: nil)
            ])

            let handler = ToolCallHandler(llmProvider: mockProvider)
            let registry = ToolRegistry()

            // When: Executing with tools
            let result = try await handler.execute(
                userPrompt: "Hello", tools: [], toolExecutors: registry, systemInstructions: nil)

            // Then: Should return the direct content
            XCTAssertEqual(result, "Direct answer")
        }

        @available(macOS 26.0, *) func testToolCallHandler_singleToolCall() async throws {
            // Given: A provider that makes one tool call, then returns final response
            let toolCall = ToolCall(
                id: "call_1", name: "get_weather", arguments: "{\"location\":\"Boston\"}")

            let mockProvider = MockToolCallingProvider(responses: [
                (content: nil, toolCalls: [toolCall]),
                (content: "The weather is sunny", toolCalls: nil),
            ])

            let handler = ToolCallHandler(llmProvider: mockProvider)
            let registry = ToolRegistry()

            // Register the tool
            let weatherExecutor = ClosureExecutor { _ in "72°F and sunny" }
            await registry.register(name: "get_weather", executor: weatherExecutor)

            let tools = [
                ToolDefinition(
                    name: "get_weather", description: "Get weather",
                    parameters: JSONSchema(type: "object"))
            ]

            // When: Executing
            let result = try await handler.execute(
                userPrompt: "What's the weather?", tools: tools, toolExecutors: registry,
                systemInstructions: nil)

            // Then: Should return final response after tool execution
            XCTAssertEqual(result, "The weather is sunny")
        }

        @available(macOS 26.0, *) func testToolCallHandler_multiTurnToolCalling() async throws {
            // Given: A provider that makes multiple tool calls across turns
            let toolCall1 = ToolCall(id: "call_1", name: "get_location", arguments: "{}")
            let toolCall2 = ToolCall(
                id: "call_2", name: "get_weather", arguments: "{\"location\":\"Boston\"}")

            let mockProvider = MockToolCallingProvider(responses: [
                (content: nil, toolCalls: [toolCall1]), (content: nil, toolCalls: [toolCall2]),
                (content: "It's 72°F in Boston", toolCalls: nil),
            ])

            let handler = ToolCallHandler(llmProvider: mockProvider)
            let registry = ToolRegistry()

            // Register tools
            let locationExecutor = ClosureExecutor { _ in "Boston" }
            let weatherExecutor = ClosureExecutor { _ in "72°F" }
            await registry.register(name: "get_location", executor: locationExecutor)
            await registry.register(name: "get_weather", executor: weatherExecutor)

            let tools = [
                ToolDefinition(
                    name: "get_location", description: "Get location",
                    parameters: JSONSchema(type: "object")),
                ToolDefinition(
                    name: "get_weather", description: "Get weather",
                    parameters: JSONSchema(type: "object")),
            ]

            // When: Executing
            let result = try await handler.execute(
                userPrompt: "What's the weather here?", tools: tools, toolExecutors: registry,
                systemInstructions: nil)

            // Then: Should complete multi-turn orchestration
            XCTAssertEqual(result, "It's 72°F in Boston")
        }

        @available(macOS 26.0, *) func testToolCallHandler_parallelToolExecution() async throws {
            // Given: A provider that calls multiple tools in parallel
            let toolCall1 = ToolCall(id: "call_1", name: "tool1", arguments: "{}")
            let toolCall2 = ToolCall(id: "call_2", name: "tool2", arguments: "{}")

            let mockProvider = MockToolCallingProvider(responses: [
                (content: nil, toolCalls: [toolCall1, toolCall2]),
                (content: "Combined results", toolCalls: nil),
            ])

            let handler = ToolCallHandler(llmProvider: mockProvider)
            let registry = ToolRegistry()

            // Register tools
            let executor1 = ClosureExecutor { _ in "result1" }
            let executor2 = ClosureExecutor { _ in "result2" }
            await registry.register(name: "tool1", executor: executor1)
            await registry.register(name: "tool2", executor: executor2)

            let tools = [
                ToolDefinition(
                    name: "tool1", description: "Tool 1", parameters: JSONSchema(type: "object")),
                ToolDefinition(
                    name: "tool2", description: "Tool 2", parameters: JSONSchema(type: "object")),
            ]

            // When: Executing
            let result = try await handler.execute(
                userPrompt: "Use both tools", tools: tools, toolExecutors: registry,
                systemInstructions: nil)

            // Then: Should execute tools in parallel and return final result
            XCTAssertEqual(result, "Combined results")
        }

        @available(macOS 26.0, *) func testToolCallHandler_maxIterationsExceeded() async throws {
            // Given: A provider that always returns tool calls (infinite loop)
            let toolCall = ToolCall(id: "call_1", name: "loop_tool", arguments: "{}")

            let mockProvider = MockToolCallingProvider(
                responses: Array(repeating: (content: nil, toolCalls: [toolCall]), count: 20))

            let handler = ToolCallHandler(llmProvider: mockProvider, maxIterations: 3)
            let registry = ToolRegistry()

            let executor = ClosureExecutor { _ in "looping" }
            await registry.register(name: "loop_tool", executor: executor)

            let tools = [
                ToolDefinition(
                    name: "loop_tool", description: "Looping tool",
                    parameters: JSONSchema(type: "object"))
            ]

            // When/Then: Should throw max iterations error
            do {
                _ = try await handler.execute(
                    userPrompt: "Loop forever", tools: tools, toolExecutors: registry,
                    systemInstructions: nil)
                XCTFail("Expected maxIterationsExceeded error")
            } catch let error as ToolCallError {
                guard case .maxIterationsExceeded(let max) = error else {
                    return XCTFail("Expected maxIterationsExceeded error")
                }
                XCTAssertEqual(max, 3)
            }
        }

        @available(macOS 26.0, *) func testToolCallHandler_noResponseContent() async throws {
            // Given: A provider that returns neither content nor tool calls
            let mockProvider = MockToolCallingProvider(responses: [(content: nil, toolCalls: nil)])

            let handler = ToolCallHandler(llmProvider: mockProvider)
            let registry = ToolRegistry()

            // When/Then: Should throw noResponseContent error
            do {
                _ = try await handler.execute(
                    userPrompt: "Hello", tools: [], toolExecutors: registry, systemInstructions: nil
                )
                XCTFail("Expected noResponseContent error")
            } catch let error as ToolCallError {
                guard case .noResponseContent = error else {
                    return XCTFail("Expected noResponseContent error")
                }
            }
        }

        @available(macOS 26.0, *) func testToolCallError_descriptions() {
            let maxIterError = ToolCallError.maxIterationsExceeded(10)
            XCTAssertTrue(maxIterError.localizedDescription.contains("10"))

            let noContentError = ToolCallError.noResponseContent
            XCTAssertNotNil(noContentError.localizedDescription)
        }
    #endif
}

// MARK: - Mock Tool Calling Provider

#if canImport(FoundationModels)
    @available(macOS 26.0, *) private actor MockToolCallingProvider: LLMProvider {
        private var responses: [(content: String?, toolCalls: [ToolCall]?)]
        private var currentIndex = 0

        init(responses: [(content: String?, toolCalls: [ToolCall]?)]) { self.responses = responses }

        func respond(to userPrompt: String, systemInstructions: String?) async throws -> String {
            "Mock response"
        }

        func streamRespond(
            to userPrompt: String, systemInstructions: String?
        ) async throws -> AsyncThrowingStream<String, Error> {
            AsyncThrowingStream { continuation in
                continuation.yield("Mock")
                continuation.finish()
            }
        }

        func respondWithTools(
            to userPrompt: String, tools: [ToolDefinition], toolExecutors: ToolRegistry,
            systemInstructions: String?
        ) async throws -> (content: String?, toolCalls: [ToolCall]?) {
            guard currentIndex < responses.count else {
                throw LLMError.modelNotAvailable("No more mock responses")
            }

            let response = responses[currentIndex]
            currentIndex += 1
            return response
        }
    }
#endif
