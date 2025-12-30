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

    /// Incremental tool calls (for streaming tool call responses)
    public let toolCalls: [DeltaToolCall]?

    public init(role: String?, content: String?, toolCalls: [DeltaToolCall]? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
    }

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
    }
}

/// Incremental tool call delta for streaming
public struct DeltaToolCall: Codable, Sendable {
    /// Index of this tool call in the array
    public let index: Int

    /// Unique identifier for this tool call (present in first chunk)
    public let id: String?

    /// The type of tool (present in first chunk)
    public let type: String?

    /// Incremental function call data
    public let function: DeltaFunctionCall?

    public init(
        index: Int, id: String? = nil, type: String? = nil, function: DeltaFunctionCall? = nil
    ) {
        self.index = index
        self.id = id
        self.type = type
        self.function = function
    }
}

/// Incremental function call delta for streaming
public struct DeltaFunctionCall: Codable, Sendable {
    /// The name of the function (present in first chunk)
    public let name: String?

    /// Incremental arguments to append (JSON string fragment)
    public let arguments: String?

    public init(name: String? = nil, arguments: String? = nil) {
        self.name = name
        self.arguments = arguments
    }
}
