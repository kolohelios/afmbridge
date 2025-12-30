import Foundation
import Models

/// Protocol for executing tools
public protocol ToolExecutor: Sendable {
    /// Executes a tool with the given JSON-encoded arguments
    /// - Parameter arguments: JSON string containing the tool arguments
    /// - Returns: JSON string containing the tool result
    /// - Throws: Error if execution fails
    func execute(arguments: String) async throws -> String
}

/// Registry for managing available tools and their executors
public actor ToolRegistry {
    private var executors: [String: ToolExecutor] = [:]

    public init() {}

    /// Registers a tool executor with the given name
    /// - Parameters:
    ///   - name: The name of the tool
    ///   - executor: The executor to handle tool calls
    public func register(name: String, executor: ToolExecutor) { executors[name] = executor }

    /// Unregisters a tool executor
    /// - Parameter name: The name of the tool to unregister
    public func unregister(name: String) { executors.removeValue(forKey: name) }

    /// Retrieves the executor for a given tool name
    /// - Parameter name: The name of the tool
    /// - Returns: The executor if registered, nil otherwise
    public func executor(for name: String) -> ToolExecutor? { executors[name] }

    /// Executes a tool by name with the given arguments
    /// - Parameters:
    ///   - name: The name of the tool to execute
    ///   - arguments: JSON string containing the arguments
    /// - Returns: JSON string containing the result
    /// - Throws: ToolExecutionError if the tool is not found or execution fails
    public func execute(tool name: String, arguments: String) async throws -> String {
        guard let executor = executors[name] else { throw ToolExecutionError.toolNotFound(name) }

        do { return try await executor.execute(arguments: arguments) } catch {
            throw ToolExecutionError.executionFailed(name, error)
        }
    }

    /// Returns all registered tool names
    public func registeredTools() -> [String] { Array(executors.keys) }

    /// Checks if a tool is registered
    /// - Parameter name: The name of the tool
    /// - Returns: True if the tool is registered
    public func isRegistered(name: String) -> Bool { executors[name] != nil }
}

/// Errors that can occur during tool execution
public enum ToolExecutionError: Error, CustomStringConvertible {
    case toolNotFound(String)
    case executionFailed(String, Error)
    case invalidArguments(String)

    public var description: String {
        switch self {
        case .toolNotFound(let name): return "Tool not found: \(name)"
        case .executionFailed(let name, let error):
            return "Tool execution failed for '\(name)': \(error.localizedDescription)"
        case .invalidArguments(let message): return "Invalid arguments: \(message)"
        }
    }
}

/// Simple closure-based executor for testing and simple use cases
public struct ClosureExecutor: ToolExecutor {
    private let closure: @Sendable (String) async throws -> String

    public init(closure: @escaping @Sendable (String) async throws -> String) {
        self.closure = closure
    }

    public func execute(arguments: String) async throws -> String { try await closure(arguments) }
}
