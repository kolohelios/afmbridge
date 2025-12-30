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
    func streamRespond(to userPrompt: String, systemInstructions: String?) async throws
        -> AsyncThrowingStream<String, Error>
}

/// Actor-based service wrapping Apple's LanguageModelSession
/// Provides thread-safe access to Foundation Models on macOS 26.0+
@available(macOS 26.0, *) public actor FoundationModelService: LLMProvider {
    private let modelIdentifier: String

    /// Initialize the service with a specific model identifier
    /// - Parameter modelIdentifier: The identifier of the language model to use
    public init(modelIdentifier: String = "default") { self.modelIdentifier = modelIdentifier }

    /// Generate a response using Apple's FoundationModels framework
    /// - Parameters:
    ///   - userPrompt: The user's input message
    ///   - systemInstructions: Optional system-level instructions for the model
    /// - Returns: The model's text response
    /// - Throws: LLMError if the model is unavailable or generation fails
    public func respond(to userPrompt: String, systemInstructions: String?) async throws -> String {
        #if canImport(FoundationModels)
            // Create language model session with optional system instructions
            let session: LanguageModelSession
            if let systemInstructions = systemInstructions {
                session = LanguageModelSession { systemInstructions }
            } else {
                session = LanguageModelSession()
            }

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
    public func streamRespond(to userPrompt: String, systemInstructions: String?) async throws
        -> AsyncThrowingStream<String, Error>
    {
        #if canImport(FoundationModels)
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        // Create language model session with optional system instructions
                        let session: LanguageModelSession
                        if let systemInstructions = systemInstructions {
                            session = LanguageModelSession { systemInstructions }
                        } else {
                            session = LanguageModelSession()
                        }

                        // Stream response and convert snapshots to deltas
                        var previousContent = ""
                        for try await snapshot in try await session.streamResponse(to: userPrompt) {
                            let currentContent = snapshot.content
                            let delta = String(currentContent.dropFirst(previousContent.count))
                            previousContent = currentContent

                            if !delta.isEmpty {
                                continuation.yield(delta)
                            }
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
}
