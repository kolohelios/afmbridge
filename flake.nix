{
  description = "AFMBridge - Apple Foundation Models Bridge";

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

        # Development tools
        # NOTE: Swift toolchain is NOT included from Nix - use system Swift from Xcode
        # Reason: nixpkgs only has Swift 5.10, but we need Swift 6+
        # NOTE: swift-format and swiftlint are NOT included from Nix
        # Reason: They pull in apple-sdk-14.4 which conflicts with Swift 6
        # Install via: brew install swift-format swiftlint

        # Python with SDK packages
        pythonWithPackages = pkgs.python3.withPackages (ps: [
          ps.openai
          ps.anthropic
        ]);

        devTools = with pkgs; [
          # Task runner
          just

          # Markdown linting
          nodePackages.markdownlint-cli2

          # Docker for containerization
          docker

          # Git (for jj git interop)
          git

          # Direnv for automatic env loading
          direnv
        ];

      in
      {
        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = devTools ++ [ pythonWithPackages ];

          shellHook = ''
            # Override Nix SDK paths to use system Xcode SDK
            # Even though Swift isn't in devTools, other packages (like git's libcxx)
            # pull in apple-sdk which sets these variables and conflicts with Swift 6
            export SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
            export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

            # Unset Nix C/C++ compiler variables to prevent interference with Swift compilation
            # Swift Package Manager should use system toolchain, not Nix's C compiler wrapper
            unset NIX_CFLAGS_COMPILE
            unset NIX_LDFLAGS
            unset NIX_CC
            unset NIX_BINTOOLS

            # Point CC/CXX to system clang, not Nix's wrapper
            # This ensures Swift Package Manager uses the correct toolchain for C/C++ dependencies
            export CC=/usr/bin/clang
            export CXX=/usr/bin/clang++

            # Set PYTHONPATH to nix-provided packages (openai, anthropic)
            export PYTHONPATH="${pythonWithPackages}/${pythonWithPackages.sitePackages}:$PYTHONPATH"

            echo "🚀 AFMBridge Development Environment"
            echo ""
            echo "Prerequisites (install via Homebrew):"
            echo "  brew install swift-format swiftlint"
            echo ""
            echo "Available commands:"
            echo "  just --list       Show all tasks"
            echo "  just validate     Run all quality checks"
            echo "  swift --version   Check Swift version"
            echo ""
            echo "SDK Testing:"
            echo "  python3 Tests/SDKTests/test_openai_sdk.py"
            echo ""
            echo "Swift version:"
            swift --version
          '';

          # Set environment variables
          HOST = "127.0.0.1";
          PORT = "8080";
        };

        # Package outputs
        # TODO: Re-enable in Phase 1 when Swift code exists
        packages = {
          # Placeholder - will be the server binary in Phase 1
          default = pkgs.runCommand "afmbridge-placeholder" { } ''
            mkdir -p $out
            echo "Phase 0: Infrastructure only - no build artifacts yet" > $out/README
          '';
        };

        # Formatter
        formatter = pkgs.nixpkgs-fmt;

        # Checks
        checks = {
          build = self.packages.${system}.default;
        };
      }
    );
}
