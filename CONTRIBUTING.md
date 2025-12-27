# Contributing to AFMBridge

Thank you for your interest in contributing to AFMBridge (Apple Foundation Models Bridge)!

## Development Setup

### Prerequisites

- macOS 26.0+ (for FoundationModels framework)
- Nix with flakes enabled

### Getting Started

```bash
# Clone the repository
git clone git@github.com:kolohelios/afmbridge.git
cd afmbridge

# Enter development environment (using direnv)
# direnv will automatically load when you cd into the directory

# Or manually enter the shell
nix develop

# Verify setup
just validate
```

## Development Commands

```bash
just format          # Auto-format code and docs
just lint            # Run linters
just test            # Run all tests with coverage
just build           # Build the project
just validate        # Run all quality checks
```

## Code Standards

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

**Format:** `<type>(<scope>): <subject>` (max 70 chars)

**The title should answer "why"** - focus on the motivation and intent.
The body (optional) can answer "what" and "how" - implementation details.

**Good Examples:**

```
feat(api): support streaming for better UX

OpenAI clients expect SSE streaming for real-time responses.
Implement word-level chunking with configurable delay to simulate
streaming behavior on top of FoundationModels' synchronous API.
```

```
fix(auth): prevent bypass of API key validation

Authentication middleware was not checking empty Bearer tokens.
Add explicit validation for non-empty token strings before
comparing with configured API key.
```

```
docs(readme): clarify macOS 26.0+ requirement

Users were confused about minimum macOS version needed.
Explicitly state that FoundationModels requires macOS 26.0+
and Apple Intelligence must be enabled.
```

```
test(dto): ensure OpenAI response format compliance

OpenAI SDK validates response structure strictly.
Add tests for all required fields, proper nesting, and
JSON serialization to prevent runtime errors in clients.
```

```
refactor(service): extract message translation logic

Translation code was duplicated across controllers.
Create MessageTranslationService to centralize OpenAI/Anthropic
format conversion, improving maintainability and testability.
```

**Bad Examples:**

```
fix: fix bug               # ❌ Doesn't explain why or what bug
feat: add code             # ❌ Too vague
update readme              # ❌ Missing type, doesn't explain why
feat(api): implement streaming using SSE with AsyncStream  # ❌ Describes "how", not "why"
```

### Quality Requirements

- All commits must pass `just validate`
- Maintain 80%+ code coverage
- Follow SwiftLint rules
- Format with swift-format
- Lint markdown documentation

## Testing

```bash
# Run all tests
just test

# Run specific test
swift test --filter TestName
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Make your changes with atomic commits
4. Run `just validate` to verify quality
5. Push and create a pull request
6. Ensure CI passes
7. Address review feedback

## Getting Help

- **Issues**: Report bugs or request features on GitHub Issues
- **Documentation**: See `PLAN.md`, `README.md`, and `API.md`

## License

By contributing, you agree that your contributions will be licensed under
the MIT License.
