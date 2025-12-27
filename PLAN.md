# Implementation Plan: AFMBridge - Apple Foundation Models Bridge

## Overview

Create a standalone open-source Swift/Vapor REST API server that wraps
Apple's FoundationModels framework (macOS 26.0+) with OpenAI-compatible
and Anthropic-compatible APIs, supporting multiple streaming modes.

**Project Name:** `afmbridge` (Apple Foundation Models Bridge)

**License:** MIT

**Build System:** Nix flakes

**Task Runner:** just (Justfile)

**VCS:** Jujutsu (jj)

## Project Structure

Create new standalone project: `afmbridge/`

```text
afmbridge/
├── PLAN.md                              # This implementation plan
├── AGENTS.md                            # Agent/AI collaboration standards
├── CLAUDE.md -> AGENTS.md               # Symlink for Claude Code
├── Package.swift                        # Swift Package, Vapor 4.x, macOS 26.0+
├── flake.nix                            # Nix flake for reproducible builds
├── flake.lock                           # Locked Nix dependencies
├── .envrc                               # direnv for automatic env loading
├── Justfile                             # Task runner (format, lint, test, build, etc.)
├── Dockerfile                           # Multi-stage Docker build
├── .dockerignore                        # Docker ignore patterns
├── .swiftlint.yml                       # SwiftLint configuration
├── .swift-format                        # swift-format configuration
├── .markdownlint.json                   # Markdown linting for docs
├── .github/
│   └── workflows/
│       ├── ci.yml                       # GitHub Actions CI (lint, test, build)
│       ├── release.yml                  # Release workflow (Docker + binary)
│       └── pr-stack.yml                 # PR stack validation
├── LICENSE                              # MIT License
├── .jj/                                 # Jujutsu VCS directory
├── Sources/
│   ├── App/
│   │   ├── main.swift                  # Entry point
│   │   ├── configure.swift             # Vapor config
│   │   └── routes.swift                # Route registration
│   ├── Controllers/
│   │   ├── OpenAIController.swift      # /v1/chat/completions
│   │   └── AnthropicController.swift   # /v1/messages
│   ├── DTOs/
│   │   ├── OpenAI/
│   │   │   ├── ChatCompletionRequest.swift
│   │   │   ├── ChatCompletionResponse.swift
│   │   │   └── ChatCompletionChunk.swift
│   │   └── Anthropic/
│   │       ├── MessageRequest.swift
│   │       ├── MessageResponse.swift
│   │       └── StreamEvent.swift
│   ├── Services/
│   │   ├── FoundationModelService.swift      # Wraps LanguageModelSession
│   │   ├── MessageTranslationService.swift   # Format conversion
│   │   └── StreamingService.swift            # SSE/chunked streaming
│   ├── Middleware/
│   │   ├── AuthenticationMiddleware.swift    # Optional API key
│   │   └── ErrorMiddleware.swift             # Error handling
│   └── Configuration/
│       └── ServerConfig.swift                # Env vars, settings
├── Tests/
│   └── AppTests/
└── README.md
```text

## Development Workflow & Best Practices

### Jujutsu (jj) VCS Workflow

Using jujutsu instead of git for version control:

```bash
# Initialize repository
jj init --git afmbridge
cd afmbridge

# Create changes (auto-commits)
# ... make changes ...
jj describe -m "feat(init): add initial project structure"

# Create PR stack
jj new -m "feat(dto): add OpenAI DTOs"
# ... make changes ...
jj new -m "feat(controller): add OpenAIController"
# ... make changes ...

# Rebase on main before creating PRs
jj rebase -d main

# Push PR stack to GitHub
jj git push --all
```text

### Conventional Commits

All commits must follow
[Conventional Commits](https://www.conventionalcommits.org/):

**Format:** `<type>(<scope>): <subject>` (max 70 chars)

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Build/tooling
- `build`: Nix/build changes

**Examples:**

```text
feat(server): add OpenAI chat completions endpoint
build(nix): configure Swift package in flake
chore(just): add format and lint tasks
docs(agents): add AI collaboration standards
```text

### Atomic Commits

Each commit should be:

- **Self-contained:** Passes `just validate`
- **Single-purpose:** One logical change
- **Reviewable:** Easy to understand
- **Revertible:** Can be safely reverted

### Code Quality Standards

#### SwiftLint

Rules to enforce:

- Line length: 120 characters
- Function length: 40 lines
- Type body length: 300 lines
- Cyclomatic complexity: 10
- Force unwrapping: Warning
- Trailing whitespace: Error

#### swift-format

- Indentation: 4 spaces
- Line wrapping: 100 characters
- Consistent spacing around operators
- Organized imports

#### Testing Requirements

- Unit tests for all services
- Integration tests for controllers
- Code coverage target: 80%
- Tests must pass before commit

#### Just Tasks

Justfile provides all development tasks:

```bash
just format          # Auto-format code and docs
just lint            # Run SwiftLint and markdownlint
just test            # Run all tests with coverage
just build           # Build the project
just validate        # Run format + lint + test + build
just docker-build    # Build Docker image
just docker-run      # Run Docker container
just clean           # Clean build artifacts
```text

### Development Workflow with jj

1. Make changes in working directory
2. Run `just validate` to verify quality
3. Describe changes: `jj describe -m "type(scope): description"`
4. Create new change for next feature: `jj new -m "type(scope): next feature"`
5. Before PR: `jj rebase -d main`
6. Push PR stack: `jj git push --all`
7. CI validates: lint, format, tests, build, Docker

## Implementation Phases

### Phase 0: Project Foundation

**Goal:** Set up project infrastructure, build system, and development environment

#### 0.1 Repository and Plan

**Commit 1:** `docs(plan): add implementation plan`

- Initialize jujutsu repository: `jj init --git afmbridge`
- Create `PLAN.md` (this document)
- Test: `jj status` shows clean state

**Commit 2:** `docs(agents): add AI collaboration standards`

- Create `AGENTS.md` with:
  - Commit standards (conventional commits, atomic commits)
  - Code quality requirements (lint, format, test)
  - Development workflow (jj, just, Nix)
  - PR stack guidelines
  - CI/CD expectations
- Create symlink: `ln -s AGENTS.md CLAUDE.md`
- Test: Files exist and symlink works

#### 0.2 Nix Build System

**Commit 3:** `build(nix): add Nix flake for reproducible builds`

- Create `flake.nix`:
  - Swift 6.0+ toolchain
  - Vapor dependencies
  - Build outputs: binary and Docker image
  - Development shell with: swift, swiftlint, swift-format, just
- Create `flake.lock`
- Test: `nix flake check` passes

**Commit 4:** `build(direnv): add direnv configuration`

- Create `.envrc` with `use flake`
- Enable automatic environment loading
- Test: `direnv allow` works

#### 0.3 Task Runner

**Commit 5:** `chore(just): add Justfile with development tasks`

- Create `Justfile` with recipes:
  - `format`: Run swift-format and markdownlint --fix
  - `lint`: Run swiftlint and markdownlint
  - `test`: Run swift test with code coverage
  - `build`: Run swift build
  - `validate`: Run format + lint + test + build
  - `docker-build`: Build Docker image
  - `docker-run`: Run Docker container
  - `clean`: Clean build artifacts
- Test: `just --list` shows all tasks

**Commit 6:** `build(docker): add multi-stage Dockerfile`

- Create `Dockerfile`:
  - Stage 1: Build binary with Nix
  - Stage 2: Runtime image with minimal dependencies
  - EXPOSE 8080
  - ENTRYPOINT for server binary
- Create `.dockerignore`
- Test: `docker build -t afmbridge .` succeeds

#### 0.4 Code Quality

**Commit 7:** `chore(swift): add SwiftLint configuration`

- Create `.swiftlint.yml` with rules:
  - Line length: 120
  - Function length: 40
  - Type body length: 300
  - Cyclomatic complexity: 10
  - Force unwrapping: warning
  - Trailing whitespace: error
- Test: `swiftlint` runs (no files yet)

**Commit 8:** `chore(swift): add swift-format configuration`

- Create `.swift-format`:
  - Indentation: 4 spaces
  - Line length: 100
  - Organize imports
- Test: `swift-format --version` works

**Commit 9:** `chore(docs): add markdownlint configuration`

- Create `.markdownlint.json`:
  - Line length: 120
  - Consistent list styles
  - No trailing punctuation in headers
- Test: `markdownlint *.md` runs

#### 0.5 Swift Package

**Commit 10:** `build(swift): initialize Swift package with Vapor`

- Create `Package.swift`:
  - Platform: macOS 26.0+
  - Dependencies: Vapor 4.x
  - Products: executable "AFMBridge"
  - Targets: App, Controllers, DTOs, Services, Middleware, Configuration
- Create basic directory structure (Sources/, Tests/)
- Run `swift package resolve`
- Test: `swift build` succeeds (empty targets)

#### 0.6 CI/CD

**Commit 11:** `ci(github): add GitHub Actions workflow`

- Create `.github/workflows/ci.yml`:
  - Setup Nix with cachix
  - Run `just validate` (format + lint + test + build)
  - Check code coverage >= 80%
  - Build Docker image
  - Upload artifacts (binary, Docker)
- Test: Workflow syntax is valid

**Commit 12:** `ci(github): add release workflow`

- Create `.github/workflows/release.yml`:
  - Trigger on tags (v*.*.*)
  - Build binary for macOS
  - Build and push Docker image to GHCR
  - Create GitHub release with artifacts
- Test: Workflow syntax is valid

**Commit 13:** `ci(github): add PR stack validation`

- Create `.github/workflows/pr-stack.yml`:
  - Validate all commits in stack
  - Check conventional commit format
  - Ensure each commit passes `just validate`
  - Verify no merge commits
- Test: Workflow syntax is valid

#### 0.7 Documentation

**Commit 14:** `docs(license): add MIT license`

- Create `LICENSE` file
- Test: License is valid MIT format

**Commit 15:** `docs(readme): add initial README`

- Create `README.md` with:
  - Project description
  - Features (coming soon)
  - Requirements
  - Quick start (placeholder)
  - Development setup with Nix/devenv
  - Just commands reference
- Test: `markdownlint README.md` passes

**Phase 0 Deliverable:** Complete project infrastructure

- Total commits: 15
- Nix build system ready
- Development environment configured
- CI/CD pipelines ready
- All tooling in place

---

### Phase 1: MVP - Non-Streaming OpenAI API

**Goal:** Working server with basic OpenAI chat completions (non-streaming)

**Commits:** 16-35 (20 commits)

**Note:** Add 15 to all commit numbers below (Phase 0 uses 1-15)

#### 1.1 Error Types & Models

**Commit 16:** `feat(errors): add LLMError enum with error cases`

- Create `Sources/Models/LLMError.swift`
- Define error cases: modelNotAvailable, frameworkNotAvailable, invalidMessageFormat, contentFiltered
- Implement `LocalizedError` protocol
- Test: Compiles successfully

#### 1.2 OpenAI DTOs

**Commit 17:** `feat(dto): add OpenAI ChatCompletionRequest model`

- Create `Sources/DTOs/OpenAI/ChatCompletionRequest.swift`
- Define: `model`, `messages`, `stream`, `max_tokens`, `temperature`
- Define nested `ChatMessage` struct
- Conform to `Content` (Vapor)
- Test: Model decodes from JSON correctly

**Commit 7:** `feat(dto): add OpenAI ChatCompletionResponse model`

- Create `Sources/DTOs/OpenAI/ChatCompletionResponse.swift`
- Define: `id`, `object`, `created`, `model`, `choices`
- Define nested `Choice` and `ChatMessage` structs
- Conform to `Content`
- Test: Model encodes to JSON correctly

**Commit 8:** `test(dto): add unit tests for OpenAI DTOs`

- Create `Tests/AppTests/DTOs/OpenAITests.swift`
- Test request decoding from JSON
- Test response encoding to JSON
- Test: All DTO tests pass

#### 1.3 Message Translation Service

**Commit 9:** `feat(service): add MessageTranslationService`

- Create `Sources/Services/MessageTranslationService.swift`
- Implement `translateToFoundationModels(messages:)` method
- Extract system messages → system prompt
- Convert user/assistant messages → conversation prompt format
- Test: Builds successfully

**Commit 10:** `test(service): add MessageTranslationService tests`

- Create `Tests/AppTests/Services/MessageTranslationServiceTests.swift`
- Test system message extraction
- Test conversation formatting
- Test multi-turn conversations
- Test: All translation tests pass

#### 1.4 FoundationModelService

**Commit 11:** `feat(service): add FoundationModelService wrapper`

- Create `Sources/Services/FoundationModelService.swift`
- Implement `actor FoundationModelService`
- Implement `respond(to:)` method using `LanguageModelSession`
- Add availability checks
- Add error handling for safety filters
- Pattern based on existing FoundationModels usage
- Test: Builds successfully (runtime test requires macOS 26.0+)

**Commit 12:** `test(service): add FoundationModelService tests`

- Create `Tests/AppTests/Services/FoundationModelServiceTests.swift`
- Add mock protocol `LLMProvider` for testability
- Test error cases (model not available)
- Test: All service tests pass

#### 1.5 OpenAI Controller

**Commit 13:** `feat(controller): add OpenAIController with non-streaming`

- Create `Sources/Controllers/OpenAIController.swift`
- Implement `chatCompletions(req:)` method
- Handle non-streaming requests only (stream == false or nil)
- Integrate FoundationModelService
- Generate response with proper format
- Test: Builds successfully

**Commit 14:** `test(controller): add OpenAIController tests`

- Create `Tests/AppTests/Controllers/OpenAIControllerTests.swift`
- Test request handling
- Test response format
- Use mock LLMProvider
- Test: All controller tests pass

#### 1.6 Vapor Application Setup

**Commit 15:** `feat(app): add Vapor main entry point`

- Create `Sources/App/main.swift`
- Implement `@main` entrypoint
- Set up Application lifecycle
- Test: `swift run` starts without errors

**Commit 16:** `feat(app): add configure function`

- Create `Sources/App/configure.swift`
- Set up middleware
- Configure logging
- Test: App configures successfully

**Commit 17:** `feat(routes): add OpenAI routes`

- Create `Sources/App/routes.swift`
- Add `/v1/chat/completions` POST endpoint
- Add `/health` GET endpoint
- Wire up OpenAIController
- Test: Routes register successfully

#### 1.7 Configuration

**Commit 18:** `feat(config): add ServerConfig with environment vars`

- Create `Sources/Configuration/ServerConfig.swift`
- Load from environment: HOST, PORT, MAX_TOKENS
- Provide sensible defaults
- Test: Config loads correctly

#### 1.8 Integration Testing

**Commit 19:** `test(integration): add end-to-end OpenAI API test`

- Create `Tests/AppTests/Integration/E2ETests.swift`
- Test full request/response flow
- Use TestApplication
- Test: E2E test passes

**Commit 20:** `docs(readme): add usage examples and API documentation`

- Update `README.md` with:
  - Installation instructions
  - Running the server
  - API examples (curl)
  - Configuration options
- Test: Documentation is clear and accurate

**Phase 1 Deliverable:** Working OpenAI-compatible API with non-streaming responses

- Total commits in phase: 20 (commits 16-35)
- All tests passing (`just validate`)
- Fully documented
- Linted and formatted

---

### Phase 2: Streaming Support

**Goal:** Add SSE streaming for OpenAI endpoint

**Commits:** 36-43 (8 commits)

**Note:** Add 35 to commit numbers in original plan (commits were 21-28, now 36-43)

#### 2.1 Chunk DTO

**Commit 21:** `feat(dto): add ChatCompletionChunk model for streaming`

- Create `Sources/DTOs/OpenAI/ChatCompletionChunk.swift`
- Define: `id`, `object`, `created`, `model`, `choices`
- Define nested `ChunkChoice` with `delta` and `finish_reason`
- Define `Delta` with optional `role` and `content`
- Conform to `Content`
- Test: Model encodes to JSON correctly

**Commit 22:** `test(dto): add ChatCompletionChunk tests`

- Create tests in `Tests/AppTests/DTOs/OpenAITests.swift`
- Test chunk encoding
- Test delta format
- Test: All chunk tests pass

#### 2.2 Streaming Service

**Commit 23:** `feat(service): add StreamingService for chunk simulation`

- Create `Sources/Services/StreamingService.swift`
- Implement `simulateChunks(_ fullResponse:, id:)` method
- Split response into word-level chunks
- Create initial role chunk
- Create content chunks
- Create final chunk with finish_reason
- Test: Builds successfully

**Commit 24:** `test(service): add StreamingService tests`

- Create `Tests/AppTests/Services/StreamingServiceTests.swift`
- Test chunk generation from full response
- Test chunk ordering (role → content → finish)
- Test: All streaming tests pass

#### 2.3 SSE Response Handler

**Commit 25:** `feat(controller): add SSE streaming to OpenAIController`

- Update `Sources/Controllers/OpenAIController.swift`
- Implement `streamChatCompletion(req:request:)` method
- Set SSE headers (`text/event-stream`, `no-cache`)
- Create `AsyncStream<ByteBuffer>` for chunks
- Send chunks with configurable delay
- Send `[DONE]` marker at end
- Update `chatCompletions` to route streaming requests
- Test: Builds successfully

**Commit 26:** `feat(config): add STREAMING_DELAY_MS to ServerConfig`

- Update `Sources/Configuration/ServerConfig.swift`
- Add `streamingDelayMs` property (default: 20)
- Load from `STREAMING_DELAY_MS` environment variable
- Test: Config loads with streaming delay

#### 2.4 Testing

**Commit 27:** `test(integration): add streaming E2E test`

- Update `Tests/AppTests/Integration/E2ETests.swift`
- Test SSE streaming response format
- Test chunk ordering
- Test `[DONE]` marker
- Test: Streaming E2E test passes

**Commit 28:** `docs(readme): add streaming examples and documentation`

- Update `README.md` with:
  - Streaming API examples
  - SSE format explanation
  - Configuration for STREAMING_DELAY_MS
- Test: Documentation is accurate

**Phase 2 Deliverable:** OpenAI endpoint with both streaming and non-streaming modes

- Total commits in phase: 8 (commits 36-43)
- All tests passing (`just validate`)
- Streaming fully functional

---

### Phase 3: Anthropic Support

**Goal:** Add Anthropic Messages API compatibility

**Commits:** 44-58 (15 commits)

**Note:** Add 43 to commit numbers in original plan (commits were 29-43, now 44-58)

#### 3.1 Anthropic DTOs

**Commit 29:** `feat(dto): add Anthropic MessageRequest model`

- Create `Sources/DTOs/Anthropic/MessageRequest.swift`
- Define: `model`, `messages`, `max_tokens` (required), `stream`, `system`, `temperature`
- Define nested `Message` struct (role, content)
- Conform to `Content`
- Test: Model decodes from JSON correctly

**Commit 30:** `feat(dto): add Anthropic MessageResponse model`

- Create `Sources/DTOs/Anthropic/MessageResponse.swift`
- Define: `id`, `type`, `role`, `content`, `model`, `stop_reason`
- Define `ContentBlock` struct with type and text
- Conform to `Content`
- Test: Model encodes to JSON correctly

**Commit 31:** `feat(dto): add Anthropic StreamEvent models`

- Create `Sources/DTOs/Anthropic/StreamEvent.swift`
- Define `StreamEventType` enum
- Define event structures for each type (message_start, content_block_delta, etc.)
- Conform to `Content`
- Test: Models encode correctly

**Commit 32:** `test(dto): add unit tests for Anthropic DTOs`

- Create `Tests/AppTests/DTOs/AnthropicTests.swift`
- Test request decoding
- Test response encoding
- Test stream event formatting
- Test: All Anthropic DTO tests pass

#### 3.2 Message Translation (Anthropic)

**Commit 33:** `feat(service): add Anthropic message translation`

- Update `Sources/Services/MessageTranslationService.swift`
- Add `translateAnthropicToFoundationModels(messages:system:)` method
- Handle separate system parameter
- Convert user/assistant messages
- Test: Builds successfully

**Commit 34:** `test(service): add Anthropic translation tests`

- Update `Tests/AppTests/Services/MessageTranslationServiceTests.swift`
- Test Anthropic format conversion
- Test system prompt handling
- Test: Translation tests pass

#### 3.3 FoundationModelService (Anthropic)

**Commit 35:** `feat(service): add Anthropic support to FoundationModelService`

- Update `Sources/Services/Services/FoundationModelService.swift`
- Add `respond(to: MessageRequest)` method
- Use translation service for format conversion
- Test: Builds successfully

#### 3.4 Anthropic Controller

**Commit 36:** `feat(controller): add AnthropicController with non-streaming`

- Create `Sources/Controllers/AnthropicController.swift`
- Implement `messages(req:)` method
- Handle non-streaming requests
- Generate MessageResponse with content blocks
- Test: Builds successfully

**Commit 37:** `test(controller): add AnthropicController tests`

- Create `Tests/AppTests/Controllers/AnthropicControllerTests.swift`
- Test request handling
- Test response format with content blocks
- Use mock LLMProvider
- Test: All controller tests pass

#### 3.5 Anthropic Streaming

**Commit 38:** `feat(service): add Anthropic streaming to StreamingService`

- Update `Sources/Services/StreamingService.swift`
- Add `simulateAnthropicEvents(_ fullResponse:, id:)` method
- Generate named SSE events (message_start, content_block_delta, etc.)
- Follow Anthropic event sequence
- Test: Builds successfully

**Commit 39:** `feat(controller): add Anthropic SSE streaming`

- Update `Sources/Controllers/AnthropicController.swift`
- Implement `streamMessages(req:request:)` method
- Set SSE headers with named events
- Send Anthropic-formatted event stream
- Update `messages` to route streaming requests
- Test: Builds successfully

**Commit 40:** `test(service): add Anthropic streaming tests`

- Update `Tests/AppTests/Services/StreamingServiceTests.swift`
- Test Anthropic event generation
- Test event ordering and format
- Test: Streaming tests pass

#### 3.6 Routes

**Commit 41:** `feat(routes): add Anthropic /v1/messages endpoint`

- Update `Sources/App/routes.swift`
- Add `/v1/messages` POST route
- Wire up AnthropicController
- Test: Routes register successfully

#### 3.7 Testing

**Commit 42:** `test(integration): add Anthropic E2E tests`

- Update `Tests/AppTests/Integration/E2ETests.swift`
- Test Anthropic non-streaming requests
- Test Anthropic streaming with named events
- Test: E2E tests pass

**Commit 43:** `docs(readme): add Anthropic API documentation`

- Update `README.md` with:
  - Anthropic API examples
  - Named SSE events explanation
  - API compatibility notes
- Test: Documentation is accurate

**Phase 3 Deliverable:** Full compatibility with both OpenAI and Anthropic APIs

- Total commits in phase: 15 (commits 44-58)
- All tests passing (`just validate`)
- Both APIs fully functional

---

### Phase 4: Production Hardening

**Goal:** Production-ready features

**Commits:** 59-75 (17 commits)

**Note:** Add 58 to commit numbers in original plan (commits were 44-60, now 59-75)

#### 4.1 Error Response Models

**Commit 44:** `feat(dto): add error response models`

- Create `Sources/DTOs/ErrorResponse.swift`
- Define OpenAI/Anthropic compatible error format
- Define `ErrorDetail` with message, type, code
- Conform to `Content`
- Test: Error models encode correctly

#### 4.2 Error Middleware

**Commit 45:** `feat(middleware): add ErrorMiddleware for error handling`

- Create `Sources/Middleware/ErrorMiddleware.swift`
- Map `LLMError` cases to HTTP status codes
- Format errors in API-compatible structure
- Handle generic errors
- Test: Builds successfully

**Commit 46:** `test(middleware): add ErrorMiddleware tests`

- Create `Tests/AppTests/Middleware/ErrorMiddlewareTests.swift`
- Test each error type mapping
- Test response format
- Test: All error handling tests pass

**Commit 47:** `feat(app): register ErrorMiddleware in configure`

- Update `Sources/App/configure.swift`
- Add ErrorMiddleware to middleware stack
- Test: Error handling works E2E

#### 4.3 Authentication Middleware

**Commit 48:** `feat(middleware): add optional API key authentication`

- Create `Sources/Middleware/AuthenticationMiddleware.swift`
- Check Authorization header for Bearer token
- Return 401 if auth enabled and invalid/missing
- Skip auth if API_KEY not set
- Test: Builds successfully

**Commit 49:** `test(middleware): add AuthenticationMiddleware tests`

- Create `Tests/AppTests/Middleware/AuthenticationMiddlewareTests.swift`
- Test valid API key
- Test invalid API key
- Test missing API key
- Test auth disabled
- Test: All auth tests pass

**Commit 50:** `feat(config): add API_KEY to ServerConfig`

- Update `Sources/Configuration/ServerConfig.swift`
- Add `apiKey` optional property
- Load from `API_KEY` environment variable
- Test: Config loads correctly

**Commit 51:** `feat(app): conditionally enable authentication`

- Update `Sources/App/configure.swift`
- Add AuthenticationMiddleware if API_KEY is set
- Test: Auth works when enabled

#### 4.4 Request/Response Logging

**Commit 52:** `feat(middleware): add request logging middleware`

- Create `Sources/Middleware/LoggingMiddleware.swift`
- Log request: method, path, headers
- Log response: status, duration
- Use structured logging (swift-log)
- Test: Builds successfully

**Commit 53:** `feat(app): register LoggingMiddleware`

- Update `Sources/App/configure.swift`
- Add LoggingMiddleware to middleware stack
- Configure log level from environment
- Test: Logging works E2E

#### 4.5 Code Coverage & Quality

**Commit 54:** `test(coverage): ensure 80% code coverage target`

- Run `swift test --enable-code-coverage`
- Add missing tests to reach 80% coverage
- Document coverage in README
- Test: Coverage >= 80%

**Commit 55:** `chore(lint): run SwiftLint and fix all warnings`

- Run `swiftlint` across codebase
- Fix all warnings and errors
- Ensure compliance with .swiftlint.yml
- Test: `swiftlint` passes with no errors

**Commit 56:** `style(format): run swift-format on all files`

- Run `swift-format` across codebase
- Fix formatting inconsistencies
- Test: All files formatted consistently

#### 4.6 Documentation

**Commit 57:** `docs(readme): add comprehensive README documentation`

- Update `README.md` with complete documentation:
  - Project description and features
  - Requirements (macOS 26.0+, Apple Silicon)
  - Installation instructions
  - Configuration guide (all env vars)
  - API usage examples (both APIs, streaming/non-streaming)
  - Client library examples (Python, JavaScript)
  - Limitations and known issues
  - Contributing guidelines
  - License information
- Test: Documentation is complete and accurate

**Commit 58:** `docs(api): add API.md with full API specification`

- Create `API.md` with:
  - OpenAI endpoint documentation
  - Anthropic endpoint documentation
  - Request/response schemas
  - Error responses
  - SSE format details
- Test: API docs are accurate

**Commit 59:** `docs(contrib): add CONTRIBUTING.md`

- Create `CONTRIBUTING.md` with:
  - Development setup
  - Code style guidelines
  - Testing requirements
  - Commit message format
  - PR process
- Test: Contributing guide is clear

#### 4.7 CI/CD Finalization

**Commit 60:** `chore(ci): finalize GitHub Actions workflow`

- Update `.github/workflows/ci.yml`
- Add all quality gates: lint, format-check, test, build
- Add code coverage reporting
- Fail on warnings
- Test: CI workflow runs successfully

**Phase 4 Deliverable:** Production-ready server

- Total commits in phase: 17 (commits 59-75)
- 80%+ code coverage
- All quality checks passing (`just validate`)
- Docker and binary artifacts ready
- Fully documented
- Ready for open-source release

---

## Key Technical Decisions

### 1. Simulated Streaming

**Trade-off:** FoundationModels doesn't support streaming → simulate by chunking complete response
**Rationale:** Provides API compatibility while accepting latency trade-off
**Implementation:** Word-level chunking with configurable delay (20ms default)

### 2. Stateless Conversations

**Trade-off:** No server-side session management → clients send full history
**Rationale:** Simplifies server, aligns with LanguageModelSession's one-shot design
**Future:** Can add optional session management later

### 3. Parameter Support

**Trade-off:** Accept OpenAI/Anthropic parameters but may not honor all
**Rationale:** API compatibility vs. Foundation Models limitations
**Implementation:** Log unsupported parameters, document which are honored

### 4. Protocol-Based Architecture

**Rationale:** Enables testing without FoundationModels, future backend swapping
```swift
protocol LLMProvider {
    func respond(to request: ChatCompletionRequest) async throws -> String
}
```text

## Testing Strategy

### Manual Testing

```bash
# OpenAI non-streaming
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"Hello"}]}'

# OpenAI streaming
curl -N -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"Count to 10"}],"stream":true}'

# Anthropic non-streaming
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-3-5-sonnet","max_tokens":1024,"messages":[{"role":"user","content":"Hello"}]}'

# Anthropic streaming
curl -N -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-3-5-sonnet","max_tokens":1024,"messages":[{"role":"user","content":"Hello"}],"stream":true}'
```text

### Client Library Testing

- Python OpenAI SDK
- Python Anthropic SDK
- JavaScript/TypeScript fetch

## Deployment

### Development with Nix

```bash
# Enter development environment
cd afmbridge
nix develop  # or use devenv shell

# Run the server
just build
just run
```text

### Production Build

```bash
# Build with Nix
nix build

# Run binary
./result/bin/AFMBridge
```text

### Docker

```bash
# Build Docker image
just docker-build

# Run Docker container
just docker-run

# Or with docker directly
docker run -p 8080:8080 -e HOST=0.0.0.0 afmbridge
```text

### Environment Variables

```bash
HOST=0.0.0.0
PORT=8080
API_KEY=sk-secret           # Optional
MAX_TOKENS=2048
STREAMING_DELAY_MS=20
LOG_LEVEL=info
```text

## Summary

This plan provides a complete roadmap for building **AFMBridge** (Apple Foundation Models Bridge), an open-source Swift/Vapor REST API server that exposes Apple's FoundationModels framework through industry-standard LLM APIs.

**Key Features:**

- ✅ OpenAI Chat Completions API compatibility
- ✅ Anthropic Messages API compatibility
- ✅ Server-Sent Events (SSE) streaming
- ✅ Nix build system with reproducible builds
- ✅ Docker and binary artifacts
- ✅ Just task runner for development
- ✅ Jujutsu (jj) for version control with PR stacks
- ✅ Atomic commits following Conventional Commits (70 char max)
- ✅ Comprehensive testing (80%+ coverage)
- ✅ Production-ready (auth, logging, error handling)
- ✅ CI/CD with GitHub Actions
- ✅ Fully documented and linted (code + docs)
- ✅ AGENTS.md for AI collaboration standards

**Total Commits:** 75 atomic commits across 5 phases (0-4)

- Phase 0: Project Foundation (15 commits)
- Phase 1: MVP OpenAI API (20 commits)
- Phase 2: Streaming Support (8 commits)
- Phase 3: Anthropic Support (15 commits)
- Phase 4: Production Hardening (17 commits)

**Build System:** Nix flakes
**Task Runner:** just (Justfile)
**VCS:** Jujutsu (jj) with PR stacks
**Artifacts:** Docker image + macOS binary

## Success Criteria

✅ OpenAI Python SDK can connect and chat
✅ Anthropic Python SDK can connect and chat
✅ Streaming works (SSE format correct)
✅ Error handling returns proper status codes
✅ Tests pass
✅ Documentation complete
