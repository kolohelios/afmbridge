# AFMBridge API Documentation

This document provides detailed API documentation for AFMBridge endpoints.

## Base URL

```text
http://localhost:8080
```

Configure the base URL using environment variables `HOST` and `PORT`.

## Endpoints

### Health Check

#### GET /health

Returns the health status of the server.

#### Response

- **Status**: 200 OK
- **Body**: `OK` (plain text)

#### Example

```bash
curl http://localhost:8080/health
```

### Chat Completions

#### POST /v1/chat/completions

OpenAI-compatible chat completions endpoint. Generates a model response for the given conversation.

#### Request

##### Headers

- `Content-Type: application/json`
- `Authorization: Bearer <token>` (if authentication is enabled)

##### Body

| Field         | Type     | Required | Description                                  |
| ------------- | -------- | -------- | -------------------------------------------- |
| `model`       | string   | Yes      | Model identifier (e.g., "gpt-4o")            |
| `messages`    | array    | Yes      | Array of message objects                     |
| `stream`      | boolean  | No       | Enable streaming (SSE with text/event-stream) |
| `max_tokens`  | integer  | No       | Maximum tokens to generate (default: 1024)   |
| `temperature` | number   | No       | Sampling temperature 0.0-2.0 (default: 1.0)  |
| `tools`       | array    | No       | Array of tool definitions (Phase 3)          |
| `tool_choice` | string/object | No  | Control tool selection (Phase 3)             |

##### Message Object

| Field          | Type   | Required | Description                              |
| -------------- | ------ | -------- | ---------------------------------------- |
| `role`         | string | Yes      | Message role: "system", "user", "assistant", "tool" |
| `content`      | string | Conditional | Message content (required except for assistant with tool_calls) |
| `tool_calls`   | array  | No       | Tool calls made by assistant (Phase 3)   |
| `tool_call_id` | string | Conditional | ID of tool call this message responds to (required for role="tool") |
| `name`         | string | Conditional | Name of tool that produced this content (required for role="tool") |

#### Response

##### Success - 200 OK

| Field     | Type    | Description                        |
| --------- | ------- | ---------------------------------- |
| `id`      | string  | Unique completion ID               |
| `object`  | string  | Object type: "chat.completion"     |
| `created` | integer | Unix timestamp                     |
| `model`   | string  | Model used                         |
| `choices` | array   | Array of completion choices        |

##### Choice Object

| Field           | Type    | Description                        |
| --------------- | ------- | ---------------------------------- |
| `index`         | integer | Choice index (0-based)             |
| `message`       | object  | Generated message                  |
| `finish_reason` | string  | Reason for stopping: "stop", "tool_calls", etc. |

##### Error Responses

| Status | Reason                                  |
| ------ | --------------------------------------- |
| 400    | Bad Request (invalid JSON, invalid tool definition, no user message) |
| 401    | Unauthorized (invalid or missing API key) |
| 503    | Service Unavailable (model not available) |

#### Tool Calling (Phase 3)

AFMBridge supports OpenAI-compatible tool calling, enabling the model to request execution of
functions with structured arguments. Tool execution happens client-side following the OpenAI
pattern.

##### Tool Definition Schema

Tools are defined using JSON Schema to specify function signatures:

```json
{
  "type": "function",
  "function": {
    "name": "get_weather",
    "description": "Get current weather for a location",
    "parameters": {
      "type": "object",
      "properties": {
        "location": {
          "type": "string",
          "description": "City name"
        },
        "unit": {
          "type": "string",
          "enum": ["celsius", "fahrenheit"]
        }
      },
      "required": ["location"]
    }
  }
}
```

##### Tool Calling Flow

1. **Client sends request with tools** - Include tool definitions in `tools` array
2. **Model decides to use tools** - Returns `finish_reason: "tool_calls"` with tool call details
3. **Client executes tools** - Run the requested functions locally
4. **Client submits results** - Send new request with tool messages containing results
5. **Model generates final response** - Returns `finish_reason: "stop"` with answer

**Note:** When `stream: true` is set with tools, the server automatically falls back to
non-streaming responses, as Apple FoundationModels does not yet support streaming tool calls.

#### Examples

##### Basic Request

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "user", "content": "What is the capital of France?"}
    ]
  }'
```

##### Basic Response

```json
{
  "id": "chatcmpl-a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
  "object": "chat.completion",
  "created": 1734678901,
  "model": "apple-afm-on-device",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "The capital of France is Paris."
      },
      "finish_reason": "stop"
    }
  ]
}
```

##### Request with System Message

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "system", "content": "You are a helpful geography tutor."},
      {"role": "user", "content": "What is the capital of France?"}
    ]
  }'
```

##### Request with Parameters

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "user", "content": "Write a haiku about programming"}
    ],
    "max_tokens": 50,
    "temperature": 0.7
  }'
```

##### Tool Calling Request

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "user", "content": "What is the weather in Boston?"}
    ],
    "tools": [
      {
        "type": "function",
        "function": {
          "name": "get_weather",
          "description": "Get current weather for a location",
          "parameters": {
            "type": "object",
            "properties": {
              "location": {"type": "string", "description": "City name"}
            },
            "required": ["location"]
          }
        }
      }
    ]
  }'
```

##### Tool Calling Response

```json
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "created": 1734678901,
  "model": "apple-afm-on-device",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "I'll check the weather for you.",
        "tool_calls": [
          {
            "id": "call_abc123",
            "type": "function",
            "function": {
              "name": "get_weather",
              "arguments": "{\"location\":\"Boston\"}"
            }
          }
        ]
      },
      "finish_reason": "tool_calls"
    }
  ]
}
```

##### Multi-Turn Tool Conversation

After receiving tool calls, execute them locally and submit results:

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "user", "content": "What is the weather in Boston?"},
      {
        "role": "assistant",
        "content": null,
        "tool_calls": [
          {
            "id": "call_abc123",
            "type": "function",
            "function": {
              "name": "get_weather",
              "arguments": "{\"location\":\"Boston\"}"
            }
          }
        ]
      },
      {
        "role": "tool",
        "tool_call_id": "call_abc123",
        "name": "get_weather",
        "content": "Temperature: 72°F, Conditions: Sunny"
      }
    ]
  }'
```

##### Final Response with Tool Results

```json
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "created": 1734678902,
  "model": "apple-afm-on-device",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "The weather in Boston is currently sunny with a temperature of 72°F."
      },
      "finish_reason": "stop"
    }
  ]
}
```

### Messages

#### POST /v1/messages

Anthropic-compatible messages endpoint. Generates a model response for the given conversation.

#### Request

##### Headers

- `Content-Type: application/json`
- `Authorization: Bearer <token>` (if authentication is enabled)

##### Body

| Field        | Type    | Required | Description                                   |
| ------------ | ------- | -------- | --------------------------------------------- |
| `model`      | string  | Yes      | Model identifier (e.g., "claude-opus-4-5-20251101") |
| `max_tokens` | integer | Yes      | Maximum tokens to generate                    |
| `messages`   | array   | Yes      | Array of message objects                      |
| `system`     | string  | No       | System prompt to set assistant behavior       |
| `stream`     | boolean | No       | Enable streaming (SSE with text/event-stream) |
| `temperature`| number  | No       | Sampling temperature 0.0-1.0 (default: 1.0)   |

##### Message Object

| Field     | Type   | Required | Description                          |
| --------- | ------ | -------- | ------------------------------------ |
| `role`    | string | Yes      | Message role: "user" or "assistant"  |
| `content` | string or array | Yes | Message content (string or content blocks) |

#### Response

##### Success - 200 OK

| Field        | Type    | Description                        |
| ------------ | ------- | ---------------------------------- |
| `id`         | string  | Unique message ID                  |
| `type`       | string  | Object type: "message"             |
| `role`       | string  | Always "assistant"                 |
| `model`      | string  | Model used                         |
| `content`    | array   | Array of content blocks            |
| `stop_reason`| string  | Reason for stopping: "end_turn", "max_tokens" |
| `usage`      | object  | Token usage statistics             |

##### Content Block Object

| Field  | Type   | Description           |
| ------ | ------ | --------------------- |
| `type` | string | Block type: "text"    |
| `text` | string | Generated text        |

##### Usage Object

| Field           | Type    | Description              |
| --------------- | ------- | ------------------------ |
| `input_tokens`  | integer | Number of input tokens   |
| `output_tokens` | integer | Number of output tokens  |

##### Error Responses

| Status | Reason                                  |
| ------ | --------------------------------------- |
| 400    | Bad Request (invalid JSON, no user message) |
| 401    | Unauthorized (invalid or missing API key) |
| 503    | Service Unavailable (model not available) |

#### Examples

##### Basic Message Request

```bash
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-opus-4-5-20251101",
    "max_tokens": 1024,
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'
```

##### Basic Message Response

```json
{
  "id": "msg-a1b2c3d4e5f6",
  "type": "message",
  "role": "assistant",
  "model": "claude-opus-4-5-20251101",
  "content": [
    {
      "type": "text",
      "text": "Hello! How can I assist you today?"
    }
  ],
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 10,
    "output_tokens": 12
  }
}
```

##### Message with System Parameter

```bash
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-opus-4-5-20251101",
    "max_tokens": 1024,
    "system": "You are a helpful assistant who speaks like a pirate.",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'
```

##### Streaming Message Request

```bash
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-opus-4-5-20251101",
    "max_tokens": 1024,
    "messages": [
      {"role": "user", "content": "Write a haiku"}
    ],
    "stream": true
  }'
```

##### Streaming Events

When `stream: true`, the server returns Server-Sent Events with the following event sequence:

1. `message_start` - Message metadata with input token count
2. `content_block_start` - Start of text content block
3. `content_block_delta` - Streaming text deltas (multiple events)
4. `content_block_stop` - End of content block
5. `message_delta` - Final message metadata with stop reason
6. `message_stop` - Stream completion

Example streaming response:

```text
event: message_start
data: {"type":"message_start","message":{"id":"msg-...","type":"message","role":"assistant","model":"claude-opus-4-5-20251101","content":[],"stop_reason":null,"usage":{"input_tokens":29,"output_tokens":0}}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Code"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" flows"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":10}}

event: message_stop
data: {"type":"message_stop"}
```

## Authentication

API key authentication is **optional** and disabled by default. When enabled, all API requests must include
a Bearer token in the Authorization header.

### Enable Authentication

Set the `API_KEY` environment variable to enable Bearer token authentication:

```bash
API_KEY=your-secret-key just run
```

### Making Authenticated Requests

Include the Bearer token in the Authorization header:

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Authorization: Bearer your-secret-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Authentication Errors

When authentication is enabled and fails, the server returns a 401 Unauthorized error with the
appropriate error format (OpenAI or Anthropic depending on the endpoint).

## Configuration

Server configuration is managed through environment variables:

| Variable     | Default     | Description                               |
| ------------ | ----------- | ----------------------------------------- |
| `HOST`       | 127.0.0.1   | Server bind address                       |
| `PORT`       | 8080        | Server port                               |
| `MAX_TOKENS` | 1024        | Default maximum tokens per request        |
| `LOG_LEVEL`  | info        | Log level (trace, debug, info, warning, error) |
| `API_KEY`    | (none)      | Optional Bearer token for authentication  |

## Integration Examples

### Python with OpenAI SDK

```python
from openai import OpenAI

# Without authentication (default)
client = OpenAI(
    base_url="http://localhost:8080/v1",
    api_key="not-needed"  # API key not required if authentication disabled
)

# With authentication (if API_KEY is set)
client = OpenAI(
    base_url="http://localhost:8080/v1",
    api_key="your-secret-key"  # Must match API_KEY environment variable
)

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Hello!"}
    ]
)

print(response.choices[0].message.content)
```

### Python with Anthropic SDK

```python
from anthropic import Anthropic

# With authentication (if API_KEY is set)
client = Anthropic(
    base_url="http://localhost:8080",
    api_key="your-secret-key"  # Must match API_KEY environment variable
)

message = client.messages.create(
    model="claude-opus-4-5-20251101",
    max_tokens=1024,
    messages=[
        {"role": "user", "content": "Hello!"}
    ]
)

print(message.content[0].text)
```

### JavaScript with OpenAI SDK

```javascript
import OpenAI from 'openai';

// Without authentication (default)
const client = new OpenAI({
  baseURL: 'http://localhost:8080/v1',
  apiKey: 'not-needed' // API key not required if authentication disabled
});

// With authentication (if API_KEY is set)
const client = new OpenAI({
  baseURL: 'http://localhost:8080/v1',
  apiKey: 'your-secret-key' // Must match API_KEY environment variable
});

const response = await client.chat.completions.create({
  model: 'gpt-4o',
  messages: [
    { role: 'system', content: 'You are a helpful assistant.' },
    { role: 'user', content: 'Hello!' }
  ]
});

console.log(response.choices[0].message.content);
```

### cURL

```bash
#!/bin/bash
API_URL="http://localhost:8080/v1/chat/completions"

curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "user", "content": "Hello, world!"}
    ]
  }' | jq
```

## Phase Roadmap

### Phase 1 (Complete)

- ✅ POST /v1/chat/completions (non-streaming)
- ✅ GET /health
- ✅ System message support
- ✅ Error handling and validation

### Phase 2 (Complete)

- ✅ Server-Sent Events (SSE) streaming
- ✅ Streaming response chunks
- ✅ True token-by-token streaming via FoundationModels AsyncSequence

### Phase 3 (Complete)

- ✅ OpenAI-compatible tool calling
- ✅ Tool definition schema with JSON Schema
- ✅ Multi-turn conversation with tool results
- ✅ Streaming DTOs for tool calls (falls back to non-streaming)
- ✅ Client-side tool execution pattern

### Phase 4 (In Progress)

- ✅ POST /v1/messages (Anthropic compatibility)
- ✅ Anthropic Messages API with streaming support
- ✅ API key authentication
- ✅ Error middleware with formatted responses
- ✅ Request logging and metrics
- 🚧 Anthropic-compatible tool calling

### Phase 5 (In Progress)

- ✅ API key authentication
- ✅ Request logging and metrics
- ✅ 80% code coverage (208 tests)
- 🚧 Rate limiting
- 🚧 Production documentation

## Error Handling

AFMBridge provides detailed, API-specific error messages to help debug issues.

### Error Response Formats

Errors are returned in the format matching the endpoint being called:

#### OpenAI Format (`/v1/chat/completions`)

```json
{
  "error": {
    "message": "No user message found in conversation",
    "type": "invalid_request_error",
    "param": null,
    "code": null
  }
}
```

#### Anthropic Format (`/v1/messages`)

```json
{
  "type": "error",
  "error": {
    "type": "invalid_request_error",
    "message": "Invalid message format: No user message found in conversation"
  }
}
```

### Common Error Types

#### invalid_request_error (400 Bad Request)

- Invalid JSON in request body
- Missing required fields (`model`, `messages`, `max_tokens`)
- No user message in conversation
- Invalid message format

#### authentication_error (401 Unauthorized)

- Missing Authorization header (when authentication is enabled)
- Invalid Authorization header format
- Invalid API key

#### api_error (503 Service Unavailable)

- FoundationModels framework not available (requires macOS 26.0+)
- Model not available
- LLM generation failure

## Best Practices

1. **Include System Messages**: Use system messages to set the behavior and context for the assistant
2. **Handle Errors Gracefully**: Check response status codes and handle errors appropriately
3. **Set Appropriate Limits**: Use `max_tokens` to control response length
4. **Monitor Logs**: Check server logs for detailed error information (configured via `LOG_LEVEL`)
5. **Use Health Checks**: Monitor the `/health` endpoint for server availability

## Support

For issues, questions, or contributions:

- GitHub Issues: <https://github.com/kolohelios/afmbridge/issues>
- Documentation: See [README.md](README.md) and [PLAN.md](PLAN.md)
- Contributing: See [CONTRIBUTING.md](CONTRIBUTING.md)
