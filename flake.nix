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

            # Add Homebrew to PATH for swift-format and swiftlint
            # These tools are installed via Homebrew (not Nix) to avoid Swift 6 conflicts
            # Add both ARM (/opt/homebrew) and Intel (/usr/local) locations
            export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

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
        packages = rec {
          # Main Swift binary - built with system Swift (not Nix Swift)
          # Reason: nixpkgs only has Swift 5.10, we need Swift 6+
          default = pkgs.stdenv.mkDerivation {
            pname = "afmbridge";
            version = "0.1.0";
            src = ./.;

            # Use system Swift from Xcode (macOS) or system package (Linux)
            # No buildInputs - rely on PATH having swift available
            nativeBuildInputs = [ ];

            buildPhase = ''
              export HOME=$TMPDIR

              # Use system Swift from Xcode (not Nix Swift 5.10)
              export PATH="/usr/bin:$PATH"
              export SDKROOT=$(xcrun --show-sdk-path)
              export DEVELOPER_DIR=$(xcode-select -p)

              swift build -c release --disable-sandbox
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp .build/release/AFMBridge $out/bin/
            '';

            meta = {
              description = "AFMBridge - OpenAI/Anthropic API bridge for Apple Foundation Models";
              platforms = [ "aarch64-darwin" "x86_64-darwin" ];  # macOS only
            };
          };

          # Docker image - builds a lightweight image with the binary
          # Note: This image is macOS-only (requires FoundationModels framework)
          docker = pkgs.dockerTools.buildLayeredImage {
            name = "afmbridge";
            tag = "latest";
            contents = [ default ];
            config = {
              Cmd = [ "${default}/bin/AFMBridge" ];
              ExposedPorts = {
                "8080/tcp" = {};
              };
              Env = [
                "HOST=0.0.0.0"
                "PORT=8080"
              ];
            };
          };
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
