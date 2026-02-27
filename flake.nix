{
  description = "AFMBridge - Development tools wrapping system Swift";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = false;
          };
        };

        # Python with SDK packages for integration testing
        pythonWithPackages = pkgs.python3.withPackages (ps: [
          ps.openai
          ps.anthropic
        ]);

      in
      {
        # Development shell - wraps system Swift, provides dev tools
        # Uses mkShellNoCC to avoid Nix's C compiler wrapper and SDK
        devShells.default = pkgs.mkShellNoCC {
          packages = with pkgs; [
            # Task runner (pure Rust, no SDK dependencies)
            just

            # Markdown linting (pure Node.js, no SDK dependencies)
            nodePackages.markdownlint-cli2

            # Python SDK packages for integration tests
            pythonWithPackages

            # Note: Removed docker, git, direnv - these pull in clang/SDK
            # Install via Homebrew instead: brew install docker git direnv
          ];

          shellHook = ''
            # Force system toolchain paths (critical for Swift)
            export SDKROOT=$(xcrun --show-sdk-path 2>/dev/null || echo "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk")
            export DEVELOPER_DIR=$(xcode-select -p 2>/dev/null || echo "/Applications/Xcode.app/Contents/Developer")

            # Clear any Nix compiler variables
            unset NIX_CFLAGS_COMPILE NIX_LDFLAGS NIX_CC NIX_BINTOOLS

            # Ensure system tools come first
            export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

            # Add Homebrew (for swift-format, swiftlint, docker, git, direnv)
            export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

            # Set PYTHONPATH for SDK integration tests
            export PYTHONPATH="${pythonWithPackages}/${pythonWithPackages.sitePackages}:$PYTHONPATH"

            # Server defaults
            export HOST="127.0.0.1"
            export PORT="8080"

            echo "🚀 AFMBridge Development Environment"
            echo ""
            echo "Tools provided by Nix:"
            echo "  ✓ just              Task runner"
            echo "  ✓ markdownlint-cli2 Markdown linting"
            echo "  ✓ python3           SDK integration tests (openai, anthropic)"
            echo ""
            echo "Tools from Homebrew (install if missing):"
            echo "  brew install swift-format swiftlint docker git direnv"
            echo ""
            echo "Swift (system toolchain):"
            swift --version 2>/dev/null || echo "  ⚠ Swift not found - install Xcode"
            echo "  SDK: $SDKROOT"
            echo ""
            echo "Commands:"
            echo "  just --list    Show all tasks"
            echo "  just validate  Run all quality checks"
            echo "  just run       Start the server"
          '';
        };

        # Formatter for Nix files
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
