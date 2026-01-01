import Models
import Vapor

/// Response structure for Anthropic Messages API
public struct MessageResponse: Content {
    /// Response type (always "message")
    public let type: String

    /// Unique identifier for this message
    public let id: String

    /// Model that generated the response
    public let model: String

    /// Role of the responder (always "assistant")
    public let role: String

    /// Array of content blocks in the response
    public let content: [ResponseContentBlock]

    /// Reason why the model stopped generating
    public let stopReason: StopReason?

    /// The stop sequence that triggered stopping (if applicable)
    public let stopSequence: String?

    /// Token usage information
    public let usage: Usage

    public init(
        type: String = "message", id: String, model: String, role: String = "assistant",
        content: [ResponseContentBlock], stopReason: StopReason?, stopSequence: String? = nil,
        usage: Usage
    ) {
        self.type = type
        self.id = id
        self.model = model
        self.role = role
        self.content = content
        self.stopReason = stopReason
        self.stopSequence = stopSequence
        self.usage = usage
    }

    enum CodingKeys: String, CodingKey {
        case type, id, model, role, content
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
}

/// Content block in a response
public enum ResponseContentBlock: Codable, Sendable {
    case text(ResponseTextBlock)
    case toolUse(ResponseToolUseBlock)

    enum CodingKeys: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let block = try ResponseTextBlock(from: decoder)
            self = .text(block)
        case "tool_use":
            let block = try ResponseToolUseBlock(from: decoder)
            self = .toolUse(block)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown response content block type: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let block): try block.encode(to: encoder)
        case .toolUse(let block): try block.encode(to: encoder)
        }
    }
}

/// Text content block in response
public struct ResponseTextBlock: Codable, Sendable {
    public let type: String
    public let text: String

    public init(text: String) {
        self.type = "text"
        self.text = text
    }

    enum CodingKeys: String, CodingKey { case type, text }
}

/// Tool use block in response (model requesting to call a tool)
public struct ResponseToolUseBlock: Codable, Sendable {
    public let type: String
    public let id: String
    public let name: String
    public let input: [String: SchemaValue]

    public init(id: String, name: String, input: [String: SchemaValue]) {
        self.type = "tool_use"
        self.id = id
        self.name = name
        self.input = input
    }

    enum CodingKeys: String, CodingKey { case type, id, name, input }
}

/// Reason why the model stopped generating
public enum StopReason: String, Codable, Sendable {
    /// Natural end of turn
    case endTurn = "end_turn"

    /// Maximum tokens reached
    case maxTokens = "max_tokens"

    /// Custom stop sequence encountered
    case stopSequence = "stop_sequence"

    /// Model wants to use a tool
    case toolUse = "tool_use"
}

/// Token usage information
public struct Usage: Codable, Sendable {
    /// Number of input tokens consumed
    public let inputTokens: Int

    /// Number of output tokens generated
    public let outputTokens: Int

    /// Tokens used for cache creation (if prompt caching enabled)
    public let cacheCreationInputTokens: Int?

    /// Tokens read from cache (if prompt caching enabled)
    public let cacheReadInputTokens: Int?

    public init(
        inputTokens: Int, outputTokens: Int, cacheCreationInputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}
