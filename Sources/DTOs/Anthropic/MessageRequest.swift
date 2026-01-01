import Models
import Vapor

/// Request structure for Anthropic Messages API
public struct MessageRequest: Content {
    /// The model to use (e.g., "claude-opus-4-5-20251101")
    public let model: String

    /// Maximum number of tokens to generate (required)
    public let maxTokens: Int

    /// Array of input messages
    public let messages: [Message]

    /// System prompt to provide context (optional)
    public let system: String?

    /// Sampling temperature (0.0 to 1.0, default: 1.0)
    public let temperature: Double?

    /// Top-p sampling parameter (0.0 to 1.0, default: 1.0)
    public let topP: Double?

    /// Top-k sampling parameter (advanced)
    public let topK: Int?

    /// Custom stop sequences
    public let stopSequences: [String]?

    /// Enable streaming responses
    public let stream: Bool?

    /// User metadata for tracking
    public let metadata: Metadata?

    /// Tools available for the model to use
    public let tools: [AnthropicTool]?

    /// Controls which tool is called
    public let toolChoice: AnthropicToolChoice?

    public init(
        model: String, maxTokens: Int, messages: [Message], system: String? = nil,
        temperature: Double? = nil, topP: Double? = nil, topK: Int? = nil,
        stopSequences: [String]? = nil, stream: Bool? = nil, metadata: Metadata? = nil,
        tools: [AnthropicTool]? = nil, toolChoice: AnthropicToolChoice? = nil
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.messages = messages
        self.system = system
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.stopSequences = stopSequences
        self.stream = stream
        self.metadata = metadata
        self.tools = tools
        self.toolChoice = toolChoice
    }

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case system
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case stopSequences = "stop_sequences"
        case stream
        case metadata
        case tools
        case toolChoice = "tool_choice"
    }
}

/// A message in the conversation
public struct Message: Codable, Sendable {
    /// Role of the message sender (user or assistant)
    public let role: String

    /// Content of the message (string or array of content blocks)
    public let content: Content

    public init(role: String, content: Content) {
        self.role = role
        self.content = content
    }

    /// Convenience initializer for simple text messages
    public init(role: String, text: String) {
        self.role = role
        self.content = .text(text)
    }

    /// Message content can be a simple string or array of content blocks
    public enum Content: Codable, Sendable {
        case text(String)
        case blocks([ContentBlock])

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let string = try? container.decode(String.self) {
                self = .text(string)
            } else if let blocks = try? container.decode([ContentBlock].self) {
                self = .blocks(blocks)
            } else {
                throw DecodingError.typeMismatch(
                    Content.self,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected String or [ContentBlock]"))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            switch self {
            case .text(let string): try container.encode(string)
            case .blocks(let blocks): try container.encode(blocks)
            }
        }
    }
}

/// Content block within a message
public enum ContentBlock: Codable, Sendable {
    case text(TextBlock)
    case toolUse(ToolUseBlock)
    case toolResult(ToolResultBlock)

    enum CodingKeys: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let block = try TextBlock(from: decoder)
            self = .text(block)
        case "tool_use":
            let block = try ToolUseBlock(from: decoder)
            self = .toolUse(block)
        case "tool_result":
            let block = try ToolResultBlock(from: decoder)
            self = .toolResult(block)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown content block type: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let block): try block.encode(to: encoder)
        case .toolUse(let block): try block.encode(to: encoder)
        case .toolResult(let block): try block.encode(to: encoder)
        }
    }
}

/// Text content block
public struct TextBlock: Codable, Sendable {
    public let type: String
    public let text: String

    public init(text: String) {
        self.type = "text"
        self.text = text
    }

    enum CodingKeys: String, CodingKey { case type, text }
}

/// Tool use block (model calling a tool)
public struct ToolUseBlock: Codable, Sendable {
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

/// Tool result block (result of tool execution)
public struct ToolResultBlock: Codable, Sendable {
    public let type: String
    public let toolUseId: String
    public let content: String

    public init(toolUseId: String, content: String) {
        self.type = "tool_result"
        self.toolUseId = toolUseId
        self.content = content
    }

    enum CodingKeys: String, CodingKey {
        case type
        case toolUseId = "tool_use_id"
        case content
    }
}

/// User metadata for tracking
public struct Metadata: Codable, Sendable {
    public let userId: String?

    public init(userId: String?) { self.userId = userId }

    enum CodingKeys: String, CodingKey { case userId = "user_id" }
}

/// Tool definition for Anthropic API
public struct AnthropicTool: Codable, Sendable {
    public let name: String
    public let description: String?
    public let inputSchema: JSONSchema

    public init(name: String, description: String? = nil, inputSchema: JSONSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
    }
}

/// Controls which tool is called by the model (Anthropic API)
public enum AnthropicToolChoice: Codable, Sendable, Equatable {
    /// Let the model decide whether to call a tool
    case auto

    /// The model must use one of the provided tools
    case any

    /// Force the model to use a specific tool
    case tool(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "auto": self = .auto
        case "any": self = .any
        case "tool":
            let name = try container.decode(String.self, forKey: .name)
            self = .tool(name)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Unknown tool_choice type: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .auto: try container.encode("auto", forKey: .type)
        case .any: try container.encode("any", forKey: .type)
        case .tool(let name):
            try container.encode("tool", forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }

    enum CodingKeys: String, CodingKey { case type, name }
}
