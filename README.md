# AFMBridge

**Apple Foundation Models Bridge** - OpenAI and Anthropic compatible REST API for Apple's
FoundationModels framework.

[![CI](https://github.com/kolohelios/afmbridge/actions/workflows/ci.yml/badge.svg)](https://github.com/kolohelios/afmbridge/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Overview

AFMBridge is a standalone Swift/Vapor REST API server that wraps Apple's FoundationModels framework
(macOS 26.0+) with industry-standard LLM APIs, enabling seamless integration with existing OpenAI
and Anthropic client libraries.

**Status:** 🚧 Phase 0 - Foundation Infrastructure (In Progress)

## Features (Planned)

- ✅ OpenAI Chat Completions API compatibility (`/v1/chat/completions`)
- ✅ Anthropic Messages API compatibility (`/v1/messages`)
- ✅ Server-Sent Events (SSE) streaming for real-time responses
- ✅ Reproducible builds with Nix flakes
- ✅ Docker containerization
- ✅ Optional API key authentication
- ✅ Structured logging
- ✅ Comprehensive test coverage (80%+ target)

## Requirements

- **macOS 26.0+** (for FoundationModels framework when available)
- **Apple Silicon** (M-series chips)
- **Nix** with flakes enabled (for development)
- **Swift 6.0+**

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
API_KEY=sk-secret         # Optional API key for authentication
MAX_TOKENS=2048           # Max tokens per request (default: 2048)
STREAMING_DELAY_MS=20     # Delay between stream chunks (default: 20ms)
LOG_LEVEL=info            # Log level: trace, debug, info, warning, error (default: info)
```

## API Usage (Coming Soon)

### OpenAI Compatible Endpoint

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Anthropic Compatible Endpoint

```bash
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Streaming

Add `"stream": true` to enable SSE streaming for either endpoint.

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

- [x] **Phase 0:** Project Foundation (In Progress)
  - [x] Nix build system
  - [x] Development tooling (just, SwiftLint, swift-format)
  - [x] CI/CD pipelines
  - [x] Documentation and standards
- [ ] **Phase 1:** MVP - Non-streaming OpenAI API
- [ ] **Phase 2:** Streaming Support
- [ ] **Phase 3:** Anthropic API Support
- [ ] **Phase 4:** Production Hardening

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
