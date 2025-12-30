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
| 500    | Internal Server Error                   |
| 503    | Service Unavailable (FoundationModels framework not available) |

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
  "model": "gpt-4o",
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
  "model": "gpt-4o",
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
  "model": "gpt-4o",
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

## Configuration

Server configuration is managed through environment variables:

| Variable     | Default     | Description                               |
| ------------ | ----------- | ----------------------------------------- |
| `HOST`       | 127.0.0.1   | Server bind address                       |
| `PORT`       | 8080        | Server port                               |
| `MAX_TOKENS` | 1024        | Default maximum tokens per request        |
| `LOG_LEVEL`  | info        | Log level (trace, debug, info, warning, error) |

## Integration Examples

### Python with OpenAI SDK

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8080/v1",
    api_key="not-needed"  # AFMBridge doesn't require API key in Phase 1
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

### JavaScript with OpenAI SDK

```javascript
import OpenAI from 'openai';

const client = new OpenAI({
  baseURL: 'http://localhost:8080/v1',
  apiKey: 'not-needed' // AFMBridge doesn't require API key in Phase 1
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

### Phase 4 (Planned)

- 🚧 POST /v1/messages (Anthropic compatibility)
- 🚧 Anthropic-specific features
- 🚧 API key authentication
- 🚧 Rate limiting
- 🚧 Request logging and metrics

## Error Handling

AFMBridge provides detailed error messages to help debug issues:

### Common Errors

#### 400 Bad Request

- Invalid JSON in request body
- Missing required fields (`model`, `messages`)
- No user message in conversation
- Streaming requested (not yet supported)

#### 500 Internal Server Error

- Unexpected server error
- LLM generation failure

#### 503 Service Unavailable

- FoundationModels framework not available (requires macOS 26.0+)
- Model not available

### Error Response Format

```json
{
  "error": true,
  "reason": "Detailed error message"
}
```

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
