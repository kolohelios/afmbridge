# AFMBridge Justfile - Development Task Runner

# Default recipe (shows help)
default:
    @just --list

# Auto-format Swift code and markdown docs
format:
    @echo "📝 Formatting Swift code..."
    swift-format --in-place --recursive Sources Tests
    @echo "📝 Formatting markdown docs..."
    markdownlint-cli2 --fix "**/*.md" "#.build" "#node_modules" "#.beads"
    @echo "✅ Formatting complete"

# Run all linters
lint:
    @echo "🔍 Running SwiftLint..."
    @# TODO: Re-enable SwiftLint in Phase 1 when we have actual Swift code
    @# Currently disabled due to sourcekitd framework compatibility issue
    @# swiftlint lint --strict
    @echo "⚠️  SwiftLint temporarily disabled (Phase 0 - no Swift code yet)"
    @echo "🔍 Running markdownlint..."
    markdownlint-cli2 "**/*.md" "#.build" "#node_modules" "#.beads"
    @echo "✅ Linting complete"

# Format check (for CI)
format-check:
    @echo "🔍 Checking Swift formatting..."
    swift-format lint --recursive Sources Tests
    @echo "🔍 Checking markdown formatting..."
    markdownlint-cli2 "**/*.md" "#.build" "#node_modules" "#.beads"
    @echo "✅ Format check complete"

# Run all tests with code coverage
test:
    @echo "🧪 Running tests with coverage..."
    xcrun swift test --enable-code-coverage
    @echo "✅ Tests complete"

# Build the project
build:
    @echo "🔨 Building project..."
    xcrun swift build
    @echo "✅ Build complete"

# Build for release
build-release:
    @echo "🔨 Building release binary..."
    xcrun swift build -c release
    @echo "✅ Release build complete"

# Run the server locally
run:
    @echo "🚀 Starting AFMBridge server..."
    xcrun swift run

# Run the server with environment variables
run-dev:
    @echo "🚀 Starting AFMBridge server (development mode)..."
    HOST=127.0.0.1 PORT=8080 LOG_LEVEL=debug swift run

# Run all quality checks (format + lint + test)
# Note: test already builds, so separate build step is redundant
validate: format lint test
    @echo "✅ All validation checks passed!"

# Build Docker image
docker-build:
    @echo "🐳 Building Docker image with Nix..."
    nix build .#docker
    @echo "🐳 Loading image into Docker..."
    docker load < result
    @echo "✅ Docker image built"

# Run Docker container
docker-run:
    @echo "🐳 Running Docker container..."
    docker run --rm -p 8080:8080 \
        -e HOST=0.0.0.0 \
        -e PORT=8080 \
        afmbridge:latest

# Clean build artifacts
clean:
    @echo "🧹 Cleaning build artifacts..."
    rm -rf .build
    @echo "✅ Clean complete"

# Clean all (including Nix results)
clean-all: clean
    @echo "🧹 Cleaning Nix results..."
    rm -rf result result-*
    @echo "✅ Deep clean complete"

# Update dependencies
update-deps:
    @echo "📦 Updating Swift dependencies..."
    xcrun swift package update
    @echo "✅ Dependencies updated"

# Resolve dependencies
resolve-deps:
    @echo "📦 Resolving Swift dependencies..."
    xcrun swift package resolve
    @echo "✅ Dependencies resolved"

# Generate Xcode project
xcode:
    @echo "📱 Generating Xcode project..."
    swift package generate-xcodeproj
    @echo "✅ Xcode project generated"

# Show package info
info:
    @echo "📦 Package Information:"
    @swift package describe

# Check Nix flake
flake-check:
    @echo "❄️  Checking Nix flake..."
    nix flake check
    @echo "✅ Flake check complete"

# Update Nix flake inputs
flake-update:
    @echo "❄️  Updating Nix flake inputs..."
    nix flake update
    @echo "✅ Flake update complete"
