# Contributing to AFMBridge

Thank you for your interest in contributing to AFMBridge
(Apple Foundation Models Bridge)!

## Development Setup

### Prerequisites

- macOS 26.0+ (for FoundationModels framework)
- Nix with flakes enabled

### Getting Started

```bash
# Clone the repository (using git)
git clone git@github.com:kolohelios/afmbridge.git
cd afmbridge

# Or using Jujutsu (recommended for stacked PRs)
jj git clone git@github.com:kolohelios/afmbridge.git
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

```text
feat(api): support streaming for better UX

OpenAI clients expect SSE streaming for real-time responses.
Implement word-level chunking with configurable delay to simulate
streaming behavior on top of FoundationModels' synchronous API.
```

```text
fix(auth): prevent bypass of API key validation

Authentication middleware was not checking empty Bearer tokens.
Add explicit validation for non-empty token strings before
comparing with configured API key.
```

```text
docs(readme): clarify macOS 26.0+ requirement

Users were confused about minimum macOS version needed.
Explicitly state that FoundationModels requires macOS 26.0+
and Apple Intelligence must be enabled.
```

```text
test(dto): ensure OpenAI response format compliance

OpenAI SDK validates response structure strictly.
Add tests for all required fields, proper nesting, and
JSON serialization to prevent runtime errors in clients.
```

```text
refactor(service): extract message translation logic

Translation code was duplicated across controllers.
Create MessageTranslationService to centralize OpenAI/Anthropic
format conversion, improving maintainability and testability.
```

**Bad Examples:**

```text
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

## AI Agent Contributors

If you're an AI agent (Claude Code, Cursor, GitHub Copilot, etc.) working on this project,
please see [AGENTS.md](AGENTS.md) for specific collaboration standards including:

- Version control with Jujutsu (jj)
- Atomic commit requirements
- Quality gate expectations
- Task management with beads
- Session completion checklist

## Getting Help

- **Issues**: Report bugs or request features on GitHub Issues
- **Documentation**: See `PLAN.md`, `README.md`, and `API.md`

## License

By contributing, you agree that your contributions will be licensed under
the MIT License.
