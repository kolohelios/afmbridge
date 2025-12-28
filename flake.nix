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
        devTools = with pkgs; [
          # Swift toolchain
          swift
          swift-format
          swiftlint

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
          buildInputs = devTools;

          shellHook = ''
            echo "🚀 AFMBridge Development Environment"
            echo ""
            echo "Available commands:"
            echo "  just --list       Show all tasks"
            echo "  just validate     Run all quality checks"
            echo "  swift --version   Check Swift version"
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
