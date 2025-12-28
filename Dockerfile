# Multi-stage Dockerfile for AFMBridge
# Stage 1: Build with Nix
# Stage 2: Runtime image

# Stage 1: Builder
FROM nixos/nix:latest AS builder

# Enable flakes
RUN mkdir -p ~/.config/nix && \
    echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Copy source
WORKDIR /build
COPY . .

# Build with Nix
RUN nix build --no-sandbox

# Stage 2: Runtime
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libicu72 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy binary from builder
COPY --from=builder /build/result/bin/AFMBridge /usr/local/bin/AFMBridge

# Set environment variables
ENV HOST=0.0.0.0
ENV PORT=8080

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run as non-root user
RUN useradd -m -u 1000 afmbridge
USER afmbridge

# Start server
ENTRYPOINT ["/usr/local/bin/AFMBridge"]
