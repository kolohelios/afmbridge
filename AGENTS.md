# AI Agent Collaboration Standards

This document defines standards for AI agents (Claude Code, Cursor, GitHub Copilot,
etc.) working on the AFMBridge project. Following these guidelines ensures consistent
code quality and maintainable commits.

## CRITICAL: Version Control

**This project uses Jujutsu (jj), NOT git.**

- ✅ ALWAYS use `jj` commands for version control operations
- ❌ NEVER use `git` commands directly (git checkout, git commit, git branch, etc.)
- ℹ️ Jujutsu manages git as a backend, but you interact only through `jj`

If you find yourself about to type a git command, STOP and use the equivalent `jj` command instead.

## Commit Standards

### Conventional Commits

All commits MUST follow [Conventional Commits](https://www.conventionalcommits.org/):

**Format:** `<type>(<scope>): <subject>`

**Maximum length:** 70 characters for the title

**The title should answer "why"** - focus on the motivation and intent behind the change.
The body (optional) can answer "what" and "how" with implementation details.

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Build/tooling
- `build`: Nix/build system changes
- `ci`: CI/CD changes

**Examples:**

```text
feat(api): support streaming for better UX
fix(auth): prevent bypass of API key validation
docs(readme): clarify macOS 26.0+ requirement
test(dto): ensure OpenAI response format compliance
build(nix): add Swift 6.0+ toolchain
ci(github): add code coverage reporting
```

### Atomic Commits

Each commit MUST be:

- **Self-contained**: Passes `just validate` (format + lint + test + build)
- **Single-purpose**: One logical change per commit
- **Reviewable**: Easy to understand in isolation
- **Revertible**: Can be safely reverted without breaking the build

### What NOT to do

- Do not batch multiple unrelated changes into one commit
- Do not create commits that break the build
- Do not use vague commit messages ("fix bug", "update code")
- Do not describe implementation details in the title (save for body)

## Code Quality Requirements

### Before Every Commit

Run the validation suite:

```bash
just validate
```

This runs:

1. `just format` - Auto-format Swift code and markdown docs
2. `just lint` - Run SwiftLint and markdownlint
3. `just test` - Run all tests with coverage report
4. `just build` - Verify the project builds successfully

**All checks MUST pass** before committing.

### Swift Code Standards

**SwiftLint rules** (see `.swiftlint.yml`):

- Line length: 120 characters maximum
- Function length: 40 lines maximum
- Type body length: 300 lines maximum
- Cyclomatic complexity: 10 maximum
- Force unwrapping: Warning (avoid `!` operator)
- Trailing whitespace: Error

**swift-format rules** (see `.swift-format`):

- Indentation: 4 spaces (no tabs)
- Line wrapping: 100 characters
- Consistent spacing around operators
- Organized imports (Foundation, Vapor, then local)

### Testing Requirements

- Unit tests for all services
- Integration tests for controllers
- Code coverage target: **80% minimum**
- All tests must pass before commit
- Use mock protocols for external dependencies

### Documentation Standards

- Markdown linting with markdownlint (see `.markdownlint.json`)
- Line length: 120 characters
- Consistent list styles
- No trailing punctuation in headers
- Update documentation when changing behavior

## Development Workflow

### Environment Setup

```bash
# Enter Nix development environment
cd afmbridge
nix develop

# Or use direnv for automatic loading
direnv allow
```

### Making Changes

1. Make changes in working directory
2. Run `just validate` to verify quality
3. Commit with conventional commit message
4. Repeat for next logical change

### Task Runner

Use `just` for all development tasks:

```bash
just format          # Auto-format code and docs
just lint            # Run SwiftLint and markdownlint
just test            # Run all tests with coverage
just build           # Build the project
just validate        # Run format + lint + test + build
just docker-build    # Build Docker image
just docker-run      # Run Docker container
just clean           # Clean build artifacts
```

### Version Control with Jujutsu

This project uses **jujutsu (jj)** instead of git:

```bash
# Create changes (auto-commits in working directory)
# ... make changes ...
jj describe -m "type(scope): description"

# Create PR stack
jj new -m "feat(dto): add OpenAI DTOs"
# ... make changes ...
jj new -m "feat(controller): add OpenAIController"
# ... make changes ...

# Rebase on main before creating PRs
jj rebase -d main

# Push PR stack to GitHub
jj git push --all
```

**Key principles:**

- Each change should be atomic and pass validation
- Use `jj describe` to write commit messages that explain "why"
- Create stacked changes for related features
- Rebase before pushing to keep history clean

## PR Stack Guidelines

When creating pull requests:

1. **Stack related changes**: Group logically related commits into a PR
2. **Each PR should**:
   - Focus on one feature or fix
   - Pass all CI checks
   - Have clear description of why the change is needed
   - Include tests for new functionality
3. **PR descriptions should**:
   - Explain the motivation (why)
   - Reference related issues
   - Note any breaking changes
   - Include testing instructions

## CI/CD Expectations

### Continuous Integration

All PRs must pass CI checks (`.github/workflows/ci.yml`):

- ✅ SwiftLint passes (no errors)
- ✅ swift-format check passes (no formatting issues)
- ✅ markdownlint passes (docs are clean)
- ✅ All tests pass
- ✅ Code coverage >= 80%
- ✅ Build succeeds
- ✅ Docker image builds

### Commit Validation

PR stack workflow (`.github/workflows/pr-stack.yml`) validates:

- ✅ All commits follow conventional commit format
- ✅ Each commit passes `just validate` individually
- ✅ No merge commits in the stack
- ✅ Commit messages are properly formatted (max 70 chars)

### Release Workflow

Releases are automated (`.github/workflows/release.yml`):

- Triggered on version tags (`v*.*.*`)
- Builds macOS binary with Nix
- Builds and pushes Docker image to GHCR
- Creates GitHub release with artifacts

## Agent Checklist

When working as an AI agent on this project:

- [ ] Read `PLAN.md` to understand the implementation phases
- [ ] Follow the commit sequence defined in the plan
- [ ] Run `just validate` before every commit
- [ ] Write conventional commit messages (max 70 chars)
- [ ] Ensure each commit is atomic and self-contained
- [ ] Update tests when adding new functionality
- [ ] Update documentation when changing behavior
- [ ] Verify 80%+ code coverage is maintained
- [ ] Check that Swift code follows lint and format rules
- [ ] Check that markdown docs are linted
- [ ] Use the project's patterns (async/await, protocols for testability)

## Questions?

See also:

- `PLAN.md` - Complete implementation plan and phases
- `CONTRIBUTING.md` - Human contributor guidelines
- `README.md` - Project overview and quick start
- `API.md` - API specification (created in Phase 4)

---

**Remember**: Quality over speed. Every commit should be production-ready.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `jj git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:

   ```bash
   jj git fetch  # Update from remote
   bd sync       # Sync beads issues
   jj git push --all  # Push all bookmarks to remote
   jj log -r 'mine()' --limit 5  # Verify pushed changes
   ```

5. **Clean up** - Abandon unused changes, prune remote bookmarks
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**

- Work is NOT complete until `jj git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
- ALWAYS use `jj` commands, NEVER use `git` directly
