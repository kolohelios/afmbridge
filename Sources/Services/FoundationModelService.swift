import Foundation
import Models

#if canImport(FoundationModels)
    import FoundationModels
#endif

/// Protocol for language model providers to enable testability
public protocol LLMProvider: Sendable {
    /// Generate a response for the given user prompt with optional system instructions
    /// - Parameters:
    ///   - userPrompt: The user's input message
    ///   - systemInstructions: Optional system-level instructions for the model
    /// - Returns: The model's text response
    /// - Throws: LLMError if generation fails
    func respond(to userPrompt: String, systemInstructions: String?) async throws -> String

    /// Stream a response for the given user prompt with optional system instructions
    /// - Parameters:
    ///   - userPrompt: The user's input message
    ///   - systemInstructions: Optional system-level instructions for the model
    /// - Returns: AsyncSequence of incremental content deltas
    /// - Throws: LLMError if generation fails
    func streamRespond(
        to userPrompt: String, systemInstructions: String?
    ) async throws -> AsyncThrowingStream<String, Error>

    /// Generate a response with tool calling support
    /// - Parameters:
    ///   - userPrompt: The user's input message
    ///   - tools: Array of tool definitions available to the model
    ///   - toolExecutors: Registry of tool executors for executing called tools
    ///   - systemInstructions: Optional system-level instructions
    /// - Returns: Tuple of (response content, tool calls made by the model)
    /// - Throws: LLMError if generation fails
    func respondWithTools(
        to userPrompt: String, tools: [ToolDefinition], toolExecutors: ToolRegistry,
        systemInstructions: String?
    ) async throws -> (content: String?, toolCalls: [ToolCall]?)
}

/// Actor-based service wrapping Apple's LanguageModelSession
/// Provides thread-safe access to Foundation Models on macOS 26.0+
@available(macOS 26.0, *) public actor FoundationModelService: LLMProvider {
    private let modelIdentifier: String
    private let toolFactory: ToolFactory

    // Session pool for concurrent requests (avoids queueing)
    // Pool size of 3 allows multiple simultaneous autocomplete requests
    private var sessionPool: [LanguageModelSession] = []
    private let maxPoolSize = 3

    // Track system instructions for pool sessions
    // For simplicity, pool only contains sessions without system instructions
    // Sessions with system instructions are created on-demand and not pooled
    private var cachedSystemInstructions: String?

    /// Initialize the service with a specific model identifier
    /// - Parameter modelIdentifier: The identifier of the language model to use
    public init(modelIdentifier: String = "default") {
        self.modelIdentifier = modelIdentifier
        self.toolFactory = ToolFactory()
    }

    /// Pre-warm session pool to eliminate first-request penalty
    /// Call this during app startup to prepare for concurrent autocomplete requests
    public func preWarm() {
        #if canImport(FoundationModels)
            // Pre-warm the pool with idle sessions (no system instructions)
            // This allows concurrent autocomplete requests without queueing
            while sessionPool.count < maxPoolSize {
                sessionPool.append(LanguageModelSession())
            }
            cachedSystemInstructions = nil
        #endif
    }

    /// Get or create a session with the specified system instructions
    /// Uses session pool for requests without system instructions (typical autocomplete)
    /// Creates on-demand sessions for requests with system instructions
    private func getSession(systemInstructions: String?) -> LanguageModelSession {
        #if canImport(FoundationModels)
            // Requests with system instructions get a dedicated session (not pooled)
            if let systemInstructions = systemInstructions {
                return LanguageModelSession { systemInstructions }
            }

            // For requests without system instructions (typical autocomplete):
            // Try to find an idle session from the pool
            if let idleSession = sessionPool.first(where: { !$0.isResponding }) {
                return idleSession
            }

            // All pool sessions are busy - create a new one
            let newSession = LanguageModelSession()

            // Add to pool if not yet at capacity
            if sessionPool.count < maxPoolSize {
                sessionPool.append(newSession)
            }

            return newSession
        #else
            fatalError("FoundationModels framework not available")
        #endif
    }

    /// Generate a response using Apple's FoundationModels framework
    /// - Parameters:
    ///   - userPrompt: The user's input message
    ///   - systemInstructions: Optional system-level instructions for the model
    /// - Returns: The model's text response
    /// - Throws: LLMError if the model is unavailable or generation fails
    public func respond(to userPrompt: String, systemInstructions: String?) async throws -> String {
        #if canImport(FoundationModels)
            // Get cached or new session
            let session = getSession(systemInstructions: systemInstructions)

            // Generate response
            do {
                let response = try await session.respond(to: userPrompt)
                return response.content
            } catch {
                // Handle safety/content filtering errors
                if error.localizedDescription.contains("filter")
                    || error.localizedDescription.contains("safety")
                {
                    throw LLMError.contentFiltered(error.localizedDescription)
                }

                // Handle other generation errors
                throw LLMError.modelNotAvailable("Generation failed: \(error.localizedDescription)")
            }
        #else
            // FATAL: FoundationModels framework not available
            // This service is useless without AFM - halt and catch fire
            fatalError(
                """
                FATAL: FoundationModels framework is not available.
                This application requires macOS 26.0+ with FoundationModels framework.
                Cannot continue without Apple Foundation Models support.
                """)
        #endif
    }

    /// Stream a response using Apple's FoundationModels framework
    /// Converts cumulative snapshots from streamResponse() to incremental deltas
    /// - Parameters:
    ///   - userPrompt: The user's input message
    ///   - systemInstructions: Optional system-level instructions for the model
    /// - Returns: AsyncThrowingStream of incremental content deltas
    /// - Throws: LLMError if the model is unavailable or generation fails
    public func streamRespond(
        to userPrompt: String, systemInstructions: String?
    ) async throws -> AsyncThrowingStream<String, Error> {
        #if canImport(FoundationModels)
            // Get cached or new session (must capture outside stream to access actor property)
            let session = getSession(systemInstructions: systemInstructions)

            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        // Stream response and convert snapshots to deltas
                        var previousContent = ""
                        for try await snapshot in try await session.streamResponse(to: userPrompt) {
                            let currentContent = snapshot.content
                            let delta = String(currentContent.dropFirst(previousContent.count))
                            previousContent = currentContent

                            if !delta.isEmpty { continuation.yield(delta) }
                        }

                        continuation.finish()
                    } catch {
                        // Handle safety/content filtering errors
                        if error.localizedDescription.contains("filter")
                            || error.localizedDescription.contains("safety")
                        {
                            continuation.finish(
                                throwing: LLMError.contentFiltered(error.localizedDescription))
                        } else {
                            continuation.finish(
                                throwing: LLMError.modelNotAvailable(
                                    "Streaming failed: \(error.localizedDescription)"))
                        }
                    }
                }
            }
        #else
            fatalError(
                """
                FATAL: FoundationModels framework is not available.
                This application requires macOS 26.0+ with FoundationModels framework.
                Cannot continue without Apple Foundation Models support.
                """)
        #endif
    }

    /// Generate a response with tool calling support
    /// - Parameters:
    ///   - userPrompt: The user's input message
    ///   - tools: Array of tool definitions available to the model
    ///   - toolExecutors: Registry of tool executors for executing called tools
    ///   - systemInstructions: Optional system-level instructions
    /// - Returns: Tuple of (response content, tool calls made by the model)
    /// - Throws: LLMError if generation fails
    public func respondWithTools(
        to userPrompt: String, tools: [ToolDefinition], toolExecutors: ToolRegistry,
        systemInstructions: String?
    ) async throws -> (content: String?, toolCalls: [ToolCall]?) {
        #if canImport(FoundationModels)
            // Create AFM Tool instances from definitions
            var afmTools: [any Tool] = []
            for toolDef in tools {
                let tool = await toolFactory.createTool(from: toolDef) { arguments in
                    // Execute the tool using the registry
                    try await toolExecutors.execute(tool: toolDef.name, arguments: arguments)
                }
                afmTools.append(tool)
            }

            // Get cached or new session
            let session = getSession(systemInstructions: systemInstructions)

            // Generate response with tools
            do {
                // For now, respond without tools and return empty tool calls
                // Full tool calling integration will be completed in ToolCallHandler
                let response = try await session.respond(to: userPrompt)

                // TODO: Extract tool calls from response when AFM supports it
                // For now, return content only
                return (content: response.content, toolCalls: nil)
            } catch {
                if error.localizedDescription.contains("filter")
                    || error.localizedDescription.contains("safety")
                {
                    throw LLMError.contentFiltered(error.localizedDescription)
                }
                throw LLMError.modelNotAvailable(
                    "Tool calling failed: \(error.localizedDescription)")
            }
        #else
            fatalError("FoundationModels framework not available")
        #endif
    }
}
