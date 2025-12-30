import Foundation

/// Represents a tool definition that can be used by the language model
public struct ToolDefinition: Codable, Sendable, Equatable {
    /// The name of the tool/function
    public let name: String

    /// A description of what the tool does
    public let description: String

    /// JSON Schema describing the tool's parameters
    public let parameters: JSONSchema

    public init(name: String, description: String, parameters: JSONSchema) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Represents a tool call made by the language model
public struct ToolCall: Codable, Sendable, Equatable {
    /// Unique identifier for this tool call
    public let id: String

    /// The name of the tool being called
    public let name: String

    /// JSON-encoded arguments for the tool
    public let arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// Represents the result of executing a tool
public struct ToolResult: Codable, Sendable, Equatable {
    /// The ID of the tool call this result corresponds to
    public let toolCallId: String

    /// The output from executing the tool
    public let output: String

    public init(toolCallId: String, output: String) {
        self.toolCallId = toolCallId
        self.output = output
    }

    enum CodingKeys: String, CodingKey {
        case toolCallId = "tool_call_id"
        case output
    }
}

/// JSON Schema representation for tool parameters
/// This is stored as a flexible dictionary to avoid recursive type issues
/// and to support the full flexibility of JSON Schema
public struct JSONSchema: Codable, Sendable, Equatable {
    /// The raw schema dictionary
    public let schema: [String: SchemaValue]

    public init(schema: [String: SchemaValue]) {
        self.schema = schema
    }

    /// Convenience initializer for common object schemas
    public init(
        type: String, properties: [String: [String: SchemaValue]]? = nil, required: [String]? = nil
    ) {
        var schema: [String: SchemaValue] = ["type": .string(type)]

        if let properties = properties {
            schema["properties"] = .object(properties.mapValues { .object($0) })
        }

        if let required = required {
            schema["required"] = .array(required.map { .string($0) })
        }

        self.schema = schema
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.schema = try container.decode([String: SchemaValue].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(schema)
    }
}

/// Represents a value in a JSON Schema
/// This enum allows us to represent nested JSON structures without recursive value types
public indirect enum SchemaValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([SchemaValue])
    case object([String: SchemaValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([SchemaValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: SchemaValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.typeMismatch(
                SchemaValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath, debugDescription: "Invalid JSON value"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
