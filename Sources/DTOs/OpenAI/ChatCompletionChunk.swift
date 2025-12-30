import Vapor

/// Response structure for OpenAI-compatible streaming chat completions
/// Sent as Server-Sent Events (SSE) with "data: " prefix
public struct ChatCompletionChunk: Content {
    /// Unique identifier for this completion
    public let id: String

    /// Object type (always "chat.completion.chunk")
    public let object: String

    /// Unix timestamp of when the chunk was created
    public let created: Int

    /// The model used for completion
    public let model: String

    /// List of chunk choices (streaming deltas)
    public let choices: [ChunkChoice]

    public init(id: String, object: String, created: Int, model: String, choices: [ChunkChoice]) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
    }

    /// A streaming completion choice containing incremental deltas
    public struct ChunkChoice: Codable, Sendable {
        /// Index of this choice in the list
        public let index: Int

        /// Incremental update to the message (delta from previous chunk)
        public let delta: Delta

        /// Reason the model stopped generating tokens (null until final chunk)
        public let finishReason: String?

        public init(index: Int, delta: Delta, finishReason: String?) {
            self.index = index
            self.delta = delta
            self.finishReason = finishReason
        }

        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }
    }
}

/// Incremental message delta for streaming responses
/// Unlike ChatMessage, fields are optional since each chunk contains partial updates
public struct Delta: Codable, Sendable {
    /// The role of the message sender (only present in first chunk)
    public let role: String?

    /// Incremental content to append to the message
    public let content: String?

    public init(role: String?, content: String?) {
        self.role = role
        self.content = content
    }
}
