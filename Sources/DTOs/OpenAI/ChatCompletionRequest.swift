import Vapor

/// Request structure for OpenAI-compatible chat completions endpoint
struct ChatCompletionRequest: Content {
    /// The model to use for completion
    let model: String

    /// List of messages in the conversation
    let messages: [ChatMessage]

    /// Whether to stream the response
    let stream: Bool?

    /// Maximum number of tokens to generate
    let maxTokens: Int?

    /// Sampling temperature (0.0 to 2.0)
    let temperature: Double?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case maxTokens = "max_tokens"
        case temperature
    }
}

/// A message in a chat conversation
struct ChatMessage: Codable {
    /// The role of the message sender (system, user, or assistant)
    let role: String

    /// The content of the message
    let content: String
}
