import Vapor

/// Request structure for OpenAI-compatible chat completions endpoint
public struct ChatCompletionRequest: Content {
    /// The model to use for completion
    public let model: String

    /// List of messages in the conversation
    public let messages: [ChatMessage]

    /// Whether to stream the response
    public let stream: Bool?

    /// Maximum number of tokens to generate
    public let maxTokens: Int?

    /// Sampling temperature (0.0 to 2.0)
    public let temperature: Double?

    public init(
        model: String, messages: [ChatMessage], stream: Bool?, maxTokens: Int?, temperature: Double?
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.maxTokens = maxTokens
        self.temperature = temperature
    }

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case maxTokens = "max_tokens"
        case temperature
    }
}

/// A message in a chat conversation
public struct ChatMessage: Codable, Sendable {
    /// The role of the message sender (system, user, or assistant)
    public let role: String

    /// The content of the message
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}
