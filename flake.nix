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
        packages = {
          # Default package (the server binary)
          default = pkgs.stdenv.mkDerivation {
            pname = "afmbridge";
            version = "0.1.0";

            src = ./.;

            buildInputs = [ pkgs.swift ];

            buildPhase = ''
              swift build -c release
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp .build/release/AFMBridge $out/bin/
            '';

            meta = with pkgs.lib; {
              description = "Apple Foundation Models Bridge - OpenAI & Anthropic compatible API";
              homepage = "https://github.com/kolohelios/afmbridge";
              license = licenses.mit;
              platforms = platforms.darwin;
            };
          };

          # Docker image
          docker = pkgs.dockerTools.buildLayeredImage {
            name = "afmbridge";
            tag = "latest";

            contents = [ self.packages.${system}.default ];

            config = {
              Cmd = [ "/bin/AFMBridge" ];
              ExposedPorts = {
                "8080/tcp" = { };
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
