import Models
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

    /// List of tools the model can call
    public let tools: [Tool]?

    /// Controls which (if any) tool is called by the model
    public let toolChoice: ToolChoice?

    public init(
        model: String, messages: [ChatMessage], stream: Bool?, maxTokens: Int?, temperature: Double?,
        tools: [Tool]? = nil, toolChoice: ToolChoice? = nil
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.tools = tools
        self.toolChoice = toolChoice
    }

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case maxTokens = "max_tokens"
        case temperature
        case tools
        case toolChoice = "tool_choice"
    }
}

/// A message in a chat conversation
public struct ChatMessage: Codable, Sendable {
    /// The role of the message sender (system, user, assistant, or tool)
    public let role: String

    /// The content of the message (optional for tool calls)
    public let content: String?

    /// Tool calls made by the assistant (only for assistant messages)
    public let toolCalls: [ResponseToolCall]?

    /// ID of the tool call this message is responding to (only for tool messages)
    public let toolCallId: String?

    /// Name of the function (only for tool messages)
    public let name: String?

    public init(
        role: String, content: String?, toolCalls: [ResponseToolCall]? = nil,
        toolCallId: String? = nil, name: String? = nil
    ) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.name = name
    }

    /// Convenience initializer for simple text messages
    public init(role: String, content: String) {
        self.role = role
        self.content = content
        self.toolCalls = nil
        self.toolCallId = nil
        self.name = nil
    }

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
        case name
    }
}

/// A tool that the model can call
public struct Tool: Codable, Sendable {
    /// The type of tool (currently only "function" is supported)
    public let type: String

    /// The function definition
    public let function: FunctionDefinition

    public init(type: String = "function", function: FunctionDefinition) {
        self.type = type
        self.function = function
    }
}

/// Definition of a function that can be called
public struct FunctionDefinition: Codable, Sendable {
    /// The name of the function
    public let name: String

    /// A description of what the function does
    public let description: String?

    /// JSON Schema describing the function's parameters
    public let parameters: JSONSchema?

    public init(name: String, description: String? = nil, parameters: JSONSchema? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Controls which (if any) tool is called by the model
public enum ToolChoice: Codable, Sendable, Equatable {
    /// Let the model decide whether to call a function
    case auto

    /// The model will not call any functions
    case none

    /// The model must call one or more functions
    case required

    /// Forces the model to call a specific function
    case function(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            switch string {
            case "auto": self = .auto
            case "none": self = .none
            case "required": self = .required
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Invalid tool_choice string: \(string)"))
            }
        } else if let object = try? container.decode([String: [String: String]].self),
            let type = object["type"],
            let function = type["name"]
        {
            self = .function(function)
        } else {
            throw DecodingError.typeMismatch(
                ToolChoice.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid tool_choice format"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .auto: try container.encode("auto")
        case .none: try container.encode("none")
        case .required: try container.encode("required")
        case .function(let name):
            try container.encode(["type": ["function": ["name": name]]])
        }
    }
}

/// A tool call made by the model in a response
public struct ResponseToolCall: Codable, Sendable {
    /// Unique identifier for this tool call
    public let id: String

    /// The type of tool (currently only "function" is supported)
    public let type: String

    /// The function being called
    public let function: FunctionCall

    public init(id: String, type: String = "function", function: FunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// Details of a function call in a response
public struct FunctionCall: Codable, Sendable {
    /// The name of the function being called
    public let name: String

    /// JSON-encoded arguments for the function
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}
