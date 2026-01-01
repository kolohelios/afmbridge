import Models
import Vapor

/// Server-sent event for streaming responses
public enum StreamEvent: Codable, Sendable {
    case messageStart(MessageStartEvent)
    case contentBlockStart(ContentBlockStartEvent)
    case contentBlockDelta(ContentBlockDeltaEvent)
    case contentBlockStop(ContentBlockStopEvent)
    case messageDelta(MessageDeltaEvent)
    case messageStop(MessageStopEvent)
    case ping(PingEvent)
    case error(ErrorEvent)

    enum CodingKeys: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "message_start":
            let event = try MessageStartEvent(from: decoder)
            self = .messageStart(event)
        case "content_block_start":
            let event = try ContentBlockStartEvent(from: decoder)
            self = .contentBlockStart(event)
        case "content_block_delta":
            let event = try ContentBlockDeltaEvent(from: decoder)
            self = .contentBlockDelta(event)
        case "content_block_stop":
            let event = try ContentBlockStopEvent(from: decoder)
            self = .contentBlockStop(event)
        case "message_delta":
            let event = try MessageDeltaEvent(from: decoder)
            self = .messageDelta(event)
        case "message_stop":
            let event = try MessageStopEvent(from: decoder)
            self = .messageStop(event)
        case "ping":
            let event = try PingEvent(from: decoder)
            self = .ping(event)
        case "error":
            let event = try ErrorEvent(from: decoder)
            self = .error(event)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Unknown stream event type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .messageStart(let event): try event.encode(to: encoder)
        case .contentBlockStart(let event): try event.encode(to: encoder)
        case .contentBlockDelta(let event): try event.encode(to: encoder)
        case .contentBlockStop(let event): try event.encode(to: encoder)
        case .messageDelta(let event): try event.encode(to: encoder)
        case .messageStop(let event): try event.encode(to: encoder)
        case .ping(let event): try event.encode(to: encoder)
        case .error(let event): try event.encode(to: encoder)
        }
    }
}

/// Event sent at the start of a message
public struct MessageStartEvent: Codable, Sendable {
    public let type: String = "message_start"
    public let message: MessageSnapshot

    public init(message: MessageSnapshot) { self.message = message }

    enum CodingKeys: String, CodingKey { case type, message }
}

/// Snapshot of a message (incomplete during streaming)
public struct MessageSnapshot: Codable, Sendable {
    public let id: String
    public let type: String = "message"
    public let role: String = "assistant"
    public let content: [ResponseContentBlock]
    public let model: String
    public let stopReason: StopReason?
    public let usage: Usage

    public init(
        id: String, content: [ResponseContentBlock], model: String, stopReason: StopReason?,
        usage: Usage
    ) {
        self.id = id
        self.content = content
        self.model = model
        self.stopReason = stopReason
        self.usage = usage
    }

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }
}

/// Event sent at the start of a content block
public struct ContentBlockStartEvent: Codable, Sendable {
    public let type: String = "content_block_start"
    public let index: Int
    public let contentBlock: ContentBlockStart

    public init(index: Int, contentBlock: ContentBlockStart) {
        self.index = index
        self.contentBlock = contentBlock
    }

    enum CodingKeys: String, CodingKey {
        case type, index
        case contentBlock = "content_block"
    }
}

/// Initial state of a content block
public struct ContentBlockStart: Codable, Sendable {
    public let type: String
    public let text: String?

    public init(type: String, text: String? = nil) {
        self.type = type
        self.text = text
    }
}

/// Event containing incremental content
public struct ContentBlockDeltaEvent: Codable, Sendable {
    public let type: String = "content_block_delta"
    public let index: Int
    public let delta: ContentDelta

    public init(index: Int, delta: ContentDelta) {
        self.index = index
        self.delta = delta
    }

    enum CodingKeys: String, CodingKey { case type, index, delta }
}

/// Incremental content update
public struct ContentDelta: Codable, Sendable {
    public let type: String
    public let text: String?
    public let partialJson: String?

    public init(type: String, text: String? = nil, partialJson: String? = nil) {
        self.type = type
        self.text = text
        self.partialJson = partialJson
    }

    enum CodingKeys: String, CodingKey {
        case type, text
        case partialJson = "partial_json"
    }
}

/// Event sent when a content block completes
public struct ContentBlockStopEvent: Codable, Sendable {
    public let type: String = "content_block_stop"
    public let index: Int

    public init(index: Int) { self.index = index }

    enum CodingKeys: String, CodingKey { case type, index }
}

/// Event containing message-level updates
public struct MessageDeltaEvent: Codable, Sendable {
    public let type: String = "message_delta"
    public let delta: MessageDelta
    public let usage: UsageDelta

    public init(delta: MessageDelta, usage: UsageDelta) {
        self.delta = delta
        self.usage = usage
    }

    enum CodingKeys: String, CodingKey { case type, delta, usage }
}

/// Message-level delta information
public struct MessageDelta: Codable, Sendable {
    public let stopReason: StopReason?
    public let stopSequence: String?

    public init(stopReason: StopReason?, stopSequence: String? = nil) {
        self.stopReason = stopReason
        self.stopSequence = stopSequence
    }

    enum CodingKeys: String, CodingKey {
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }
}

/// Incremental usage information
public struct UsageDelta: Codable, Sendable {
    public let outputTokens: Int

    public init(outputTokens: Int) { self.outputTokens = outputTokens }

    enum CodingKeys: String, CodingKey { case outputTokens = "output_tokens" }
}

/// Event sent when message generation completes
public struct MessageStopEvent: Codable, Sendable {
    public let type: String = "message_stop"

    public init() {}

    enum CodingKeys: String, CodingKey { case type }
}

/// Ping event to keep connection alive
public struct PingEvent: Codable, Sendable {
    public let type: String = "ping"

    public init() {}

    enum CodingKeys: String, CodingKey { case type }
}

/// Error event
public struct ErrorEvent: Codable, Sendable {
    public let type: String = "error"
    public let error: ErrorDetail

    public init(error: ErrorDetail) { self.error = error }

    enum CodingKeys: String, CodingKey { case type, error }
}

/// Error details
public struct ErrorDetail: Codable, Sendable {
    public let type: String
    public let message: String

    public init(type: String, message: String) {
        self.type = type
        self.message = message
    }
}
