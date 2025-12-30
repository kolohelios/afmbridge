import Foundation
import Models

#if canImport(FoundationModels)
    import FoundationModels
#endif

/// Factory for creating dynamic Tool instances from OpenAI tool definitions
@available(macOS 26.0, *) public actor ToolFactory {
    public init() {}

    /// Creates an AFM Tool instance from a ToolDefinition
    /// - Parameters:
    ///   - definition: The tool definition with name, description, and parameters
    ///   - executor: Callback to execute when the tool is called
    /// - Returns: A Tool instance conforming to AFM's Tool protocol
    public func createTool(
        from definition: ToolDefinition,
        executor: @escaping @Sendable (String) async throws -> String
    ) -> any Tool {
        #if canImport(FoundationModels)
            return DynamicTool(definition: definition, executor: executor)
        #else
            fatalError("FoundationModels framework not available")
        #endif
    }
}

/// Dynamic wrapper that conforms to AFM's Tool protocol
#if canImport(FoundationModels)
    @available(macOS 26.0, *) private struct DynamicTool: Tool, Sendable {
        typealias Arguments = String
        typealias Output = String

        let definition: ToolDefinition
        let executor: @Sendable (String) async throws -> String

        init(
            definition: ToolDefinition,
            executor: @escaping @Sendable (String) async throws -> String
        ) {
            self.definition = definition
            self.executor = executor
        }

        var name: String { definition.name }

        var description: String { definition.description }

        @available(macOS 26.0, *) var parameters: GenerationSchema {
            // Convert our JSONSchema to FoundationModels' GenerationSchema
            // Encode our schema as JSON and decode it as GenerationSchema
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(definition.parameters)
                let decoder = JSONDecoder()
                return try decoder.decode(GenerationSchema.self, from: jsonData)
            } catch {
                // Fallback to empty object schema if conversion fails
                let fallback = "{\"type\":\"object\",\"properties\":{}}"
                return try! JSONDecoder().decode(
                    GenerationSchema.self, from: fallback.data(using: .utf8)!)
            }
        }

        func call(arguments: String) async throws -> String { try await executor(arguments) }
    }
#endif
