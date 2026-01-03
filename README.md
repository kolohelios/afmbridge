# AFMBridge

**Apple Foundation Models Bridge** - OpenAI and Anthropic compatible REST API for Apple's
FoundationModels framework.

[![CI](https://github.com/kolohelios/afmbridge/actions/workflows/ci.yml/badge.svg)](https://github.com/kolohelios/afmbridge/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Overview

AFMBridge is a standalone Swift/Vapor REST API server that wraps Apple's FoundationModels framework
(macOS 26.0+) with industry-standard LLM APIs, enabling seamless integration with existing OpenAI
and Anthropic client libraries.

**Status:** 🚧 Phase 4 - Anthropic API Support (In Progress)

## Features

### Phase 1 (Complete)

- ✅ OpenAI Chat Completions API compatibility (`/v1/chat/completions`)
- ✅ Non-streaming responses
- ✅ System message support
- ✅ Environment-based configuration
- ✅ Comprehensive test coverage (49 tests, 100% passing)
- ✅ Integration tests with Vapor
- ✅ Health check endpoint

### Phase 2 (Complete)

- ✅ Server-Sent Events (SSE) streaming for real-time responses
- ✅ True token-by-token streaming via FoundationModels AsyncSequence
- ✅ OpenAI-compatible streaming format with delta chunks
- ✅ Lower time-to-first-token for better UX

### Phase 3 (Complete)

- ✅ OpenAI-compatible tool calling with AFM's native Tool protocol
- ✅ Tool definition schema using JSON Schema
- ✅ Multi-turn conversation with client-side tool execution
- ✅ Streaming DTOs for tool calls (automatic fallback to non-streaming)
- ✅ Complete test coverage (100 tests, 100% passing)

### Phase 4 (In Progress)

- ✅ Anthropic Messages API compatibility (`/v1/messages`)
- ✅ Non-streaming message responses
- ✅ Server-Sent Events (SSE) streaming with Anthropic format
- ✅ System parameter support
- ✅ Content blocks support
- 🚧 Anthropic-compatible tool calling

### Phase 5 (In Progress)

- ✅ API key authentication (Bearer token)
- ✅ Error middleware with formatted error responses
- ✅ Request logging and metrics (MetricsMiddleware)
- ✅ 80% code coverage (208 tests passing)

### Infrastructure

- ✅ Reproducible builds with Nix flakes
- ✅ Docker containerization
- ✅ Structured logging
- ✅ Automated CI/CD with GitHub Actions

### Planned

- 🚧 Anthropic-compatible tool calling (Phase 4)
- 🚧 Rate limiting and request throttling (Phase 5)
- 🚧 Production documentation (Phase 5)

## Requirements

- **macOS 26.0+** (for FoundationModels framework when available)
- **Apple Silicon** (M-series chips)
- **Nix** with flakes enabled (for development)
- **Swift 6.0+**

## About Apple FoundationModels

This project wraps Apple's [FoundationModels framework](https://developer.apple.com/documentation/FoundationModels),
which provides on-device LLM inference for macOS 26.0+ (Tahoe) with Apple Intelligence.

**Key capabilities:**

- On-device inference with privacy protection (data never leaves your Mac)
- Works offline once models are downloaded
- Native Swift API with async/await support
- Streaming responses via `AsyncSequence`
- Free inference (no API costs)

**API Documentation:**

- [LanguageModelSession](https://developer.apple.com/documentation/foundationmodels/languagemodelsession) -
Main API for text generation
- [streamResponse()](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/streamresponse(options:prompt:))
\- Streaming API returning AsyncSequence
- [WWDC 2025: Meet the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/286/) -
Official introduction video

## Quick Start

### Using Nix (Recommended)

```bash
# Clone the repository
git clone https://github.com/kolohelios/afmbridge.git
cd afmbridge

# Enter development environment
nix develop

# Run the server
just run

# Or run with custom config
HOST=0.0.0.0 PORT=8080 just run
```

### Using Docker

```bash
# Build Docker image
just docker-build

# Run container
just docker-run
```

## Development

### Prerequisites

- Nix with flakes enabled
- direnv (optional but recommended)

### Setup

```bash
# Allow direnv (if using)
direnv allow

# Or manually enter development shell
nix develop

# Verify setup
just --list
```

### Development Commands

All development tasks are managed through `just`:

```bash
just format          # Auto-format Swift code and markdown docs
just lint            # Run SwiftLint and markdownlint
just test            # Run all tests with coverage
just build           # Build the project
just validate        # Run all quality checks (format + lint + test + build)
just docker-build    # Build Docker image
just docker-run      # Run Docker container
just clean           # Clean build artifacts
```

### Code Quality Standards

This project maintains high code quality through:

- **SwiftLint** - Swift code linting (120 char line length, max 40 line functions)
- **swift-format** - Consistent Swift code formatting (100 char wrapping, 4 space indent)
- **markdownlint** - Documentation linting (120 char line length)
- **Test Coverage** - Minimum 80% code coverage requirement
- **Conventional Commits** - All commits follow conventional commit format (max 70 chars)
- **Atomic Commits** - Each commit is self-contained and passes validation

### Workflow

1. Make changes in your working directory
2. Run `just validate` to ensure all quality checks pass
3. Commit with conventional commit message
4. Push and create pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines and
[AGENTS.md](AGENTS.md) for AI agent collaboration standards.

## Configuration

Configure the server with environment variables:

```bash
HOST=0.0.0.0              # Bind address (default: 127.0.0.1)
PORT=8080                 # Port number (default: 8080)
MAX_TOKENS=1024           # Max tokens per request (default: 1024)
LOG_LEVEL=info            # Log level: trace, debug, info, warning, error (default: info)
API_KEY=your-secret-key   # Optional: Enable Bearer token authentication (default: disabled)
```

### Authentication

API key authentication is **disabled by default**. To enable it, set the `API_KEY` environment variable:

```bash
API_KEY=your-secret-key just run
```

When enabled, all API requests must include a Bearer token in the Authorization header:

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Authorization: Bearer your-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o", "messages": [{"role": "user", "content": "Hello!"}]}'
```

If authentication fails, the server returns a 401 Unauthorized error with the appropriate error format
(OpenAI or Anthropic depending on the endpoint).

## API Usage

### Health Check

```bash
curl http://localhost:8080/health
# Returns: OK
```

### OpenAI Compatible Endpoint

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

**With system message:**

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Hello!"}
    ]
  }'
```

**Response format:**

```json
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "created": 1234567890,
  "model": "apple-afm-on-device",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Hello! How can I assist you today?"
      },
      "finish_reason": "stop"
    }
  ]
}
```

### Streaming Support (Phase 2 - Complete)

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Write a haiku"}],
    "stream": true
  }'
```

Returns Server-Sent Events with true token-by-token streaming using Apple's native
`LanguageModelSession.streamResponse()` API.

### Tool Calling Support (Phase 3 - Complete)

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "What is the weather in Boston?"}],
    "tools": [{
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get weather for a location",
        "parameters": {
          "type": "object",
          "properties": {
            "location": {"type": "string"}
          },
          "required": ["location"]
        }
      }
    }]
  }'
```

Returns tool calls with `finish_reason: "tool_calls"`. Client executes tools and submits results
in a follow-up request. See [API.md](API.md) for complete tool calling documentation.

### Anthropic Compatible Endpoint (Phase 4 - In Progress)

**Basic message:**

```bash
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-opus-4-5-20251101",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

**With system parameter:**

```bash
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-opus-4-5-20251101",
    "max_tokens": 1024,
    "system": "You are a helpful assistant.",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

**Response format:**

```json
{
  "id": "msg-...",
  "type": "message",
  "role": "assistant",
  "model": "apple-afm-on-device",
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

**Streaming support:**

```bash
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-opus-4-5-20251101",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Write a haiku"}],
    "stream": true
  }'
```

Returns Server-Sent Events with Anthropic's 6-event streaming format:

1. `message_start` - Message metadata with input token count
2. `content_block_start` - Start of text content block
3. `content_block_delta` - Streaming text deltas (multiple events)
4. `content_block_stop` - End of content block
5. `message_delta` - Final message metadata with stop reason
6. `message_stop` - Stream completion

## Architecture

Built with:

- **Swift 6.0** - Modern, safe, and fast
- **Vapor 4.x** - Web framework for server implementation
- **Nix Flakes** - Reproducible development and deployment
- **Just** - Command runner for development tasks
- **Jujutsu (jj)** - Version control with native PR stacking

See [PLAN.md](PLAN.md) for the complete implementation roadmap.

## Project Structure

```text
afmbridge/
├── Sources/
│   ├── App/              # Application entry point
│   ├── Controllers/      # HTTP request handlers
│   ├── DTOs/             # Data Transfer Objects (OpenAI & Anthropic)
│   ├── Services/         # Business logic and LLM integration
│   ├── Models/           # Domain models and errors
│   ├── Middleware/       # Request/response processing
│   └── Configuration/    # Server configuration
├── Tests/                # Unit and integration tests
├── .github/workflows/    # CI/CD pipelines
├── Package.swift         # Swift package manifest
├── flake.nix             # Nix flake for reproducible builds
├── Justfile              # Development task runner
└── Dockerfile            # Multi-stage Docker build
```

## Roadmap

- [x] **Phase 0:** Project Foundation (Complete)
  - [x] Nix build system
  - [x] Development tooling (just, SwiftLint, swift-format)
  - [x] CI/CD pipelines
  - [x] Documentation and standards
- [x] **Phase 1:** MVP - Non-streaming OpenAI API (Complete)
  - [x] OpenAI DTOs (request/response)
  - [x] FoundationModelService (AFM wrapper)
  - [x] MessageTranslationService (OpenAI to AFM)
  - [x] OpenAIController (HTTP endpoint)
  - [x] ServerConfig (environment variables)
  - [x] Integration tests and documentation
- [x] **Phase 2:** Streaming Support (Complete)
  - [x] Server-Sent Events (SSE) implementation
  - [x] Streaming DTOs and chunked responses
  - [x] True token-by-token streaming via AFM AsyncSequence
  - [x] Streaming integration tests
- [x] **Phase 3:** Tool Calling Support (Complete)
  - [x] OpenAI-compatible tool calling DTOs
  - [x] Tool definition schema with JSON Schema
  - [x] Multi-turn conversation with tool results
  - [x] Client-side tool execution pattern
  - [x] Comprehensive tool calling tests (100 total tests)
- [ ] **Phase 4:** Anthropic API Support (In Progress)
  - [x] Anthropic Messages API DTOs
  - [x] Non-streaming message support
  - [x] Server-Sent Events streaming with Anthropic format
  - [x] System parameter and content blocks
  - [x] Integration tests for Anthropic API
  - [x] Error middleware with formatted responses
  - [ ] Anthropic-compatible tool calling
- [ ] **Phase 5:** Production Hardening (In Progress)
  - [x] API key authentication (Bearer token)
  - [x] Error middleware with formatted error responses
  - [x] Request logging and metrics (MetricsMiddleware)
  - [x] 80% code coverage (208 tests passing)
  - [ ] Rate limiting and request throttling
  - [ ] Production documentation

See [PLAN.md](PLAN.md) for detailed phase breakdown.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

For AI agents working on this project, see [AGENTS.md](AGENTS.md) for collaboration standards.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Vapor](https://vapor.codes/) web framework
- Reproducible builds powered by [Nix](https://nixos.org/)
- Task automation with [just](https://github.com/casey/just)
- Version control with [jujutsu](https://github.com/martinvonz/jj)
